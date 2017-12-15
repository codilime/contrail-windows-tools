class NetworkConfiguration {
    [string] $Name;
    [string[]] $Subnets;
}

class TenantConfiguration {
    [string] $Name;
    [string] $DefaultNetworkName;
    [NetworkConfiguration] $SingleSubnetNetwork;
    [NetworkConfiguration] $MultipleSubnetsNetwork;
    [NetworkConfiguration] $NetworkWithPolicy1;
    [NetworkConfiguration] $NetworkWithPolicy2;
}

class DockerDriverConfiguration {
    [string] $Username;
    [string] $Password;
    [string] $AuthUrl;
    [TenantConfiguration] $TenantConfiguration;

    [Object]ShallowCopy() {
        return $this.MemberwiseClone()
    }
}

class TestConfiguration {
    [DockerDriverConfiguration] $DockerDriverConfiguration;
    [string] $ControllerIP;
    [int] $ControllerRestPort
    [string] $ControllerHostUsername;
    [string] $ControllerHostPassword;
    [string] $AdapterName;
    [string] $VHostName;
    [string] $VMSwitchName;
    [string] $ForwardingExtensionName;
    [string] $AgentConfigFilePath;
    [string] $LinuxVirtualMachineIp;

    [Object]ShallowCopy() {
        return $this.MemberwiseClone()
    }
}

$MAX_WAIT_TIME_FOR_AGENT_IN_SECONDS = 60
$TIME_BETWEEN_AGENT_CHECKS_IN_SECONDS = 2

function Stop-ProcessIfExists {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ProcessName)

    Invoke-Command -Session $Session -ScriptBlock {
        $Proc = Get-Process $Using:ProcessName -ErrorAction SilentlyContinue
        if ($Proc) {
            $Proc | Stop-Process -Force
        }
    }
}

function Test-IsProcessRunning {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $ProcessName)

    $Proc = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-Process $Using:ProcessName -ErrorAction SilentlyContinue)
    }

    return $(if ($Proc) { $true } else { $false })
}

function Enable-VRouterExtension {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName,
           [Parameter(Mandatory = $false)] [string] $ContainerNetworkName = "testnet")

    Write-Host "Enabling Extension"

    Invoke-Command -Session $Session -ScriptBlock {
        New-ContainerNetwork -Mode Transparent -NetworkAdapterName $Using:AdapterName -Name $Using:ContainerNetworkName | Out-Null
        Enable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName | Out-Null
    }
}

function Disable-VRouterExtension {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName)

    Write-Host "Disabling Extension"

    Invoke-Command -Session $Session -ScriptBlock {
        Disable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue | Out-Null
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $Using:AdapterName | Remove-ContainerNetwork -Force
    }
}

function Test-IsVRouterExtensionEnabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName)

    $Ext = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue)
    }

    return $($Ext.Enabled -and $Ext.Running)
}

function Enable-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [string] $ControllerIP,
           [Parameter(Mandatory = $true)] [DockerDriverConfiguration] $Configuration,
           [Parameter(Mandatory = $false)] [int] $WaitTime = 60)

    Write-Host "Enabling Docker Driver"

    $TenantName = $Configuration.TenantConfiguration.Name

    Invoke-Command -Session $Session -ScriptBlock {

        $LogDir = "$Env:ProgramData/ContrailDockerDriver"

        if (Test-Path $LogDir) {
            Push-Location $LogDir

            if (Test-Path log.txt) {
                Move-Item -Force log.txt log.old.txt
            }

            Pop-Location
        }

        # Nested ScriptBlock variable passing workaround
        $AdapterName = $Using:AdapterName
        $ControllerIP = $Using:ControllerIP
        $Configuration = $Using:Configuration
        $TenantName = $Using:TenantName

        Start-Job -ScriptBlock {
            Param ($Cfg, $ControllerIP, $Tenant, $Adapter)

            $Env:OS_USERNAME = $Cfg.Username
            $Env:OS_PASSWORD = $Cfg.Password
            $Env:OS_AUTH_URL = $Cfg.AuthUrl
            $Env:OS_TENANT_NAME = $Tenant

            & "C:\Program Files\Juniper Networks\contrail-windows-docker.exe" -forceAsInteractive -controllerIP $ControllerIP -adapter "$Adapter" -vswitchName "Layered <adapter>" -logLevel "Debug"
        } -ArgumentList $Configuration, $ControllerIP, $TenantName, $AdapterName | Out-Null
    }

    Start-Sleep -s $WaitTime
}

function Disable-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Disabling Docker Driver"

    Stop-ProcessIfExists -Session $Session -ProcessName "contrail-windows-docker"

    Invoke-Command -Session $Session -ScriptBlock {
        Stop-Service docker | Out-Null
        Get-NetNat | Remove-NetNat -Confirm:$false
        Get-ContainerNetwork | Remove-ContainerNetwork -Force
        Start-Service docker | Out-Null
    }
}

function Test-IsDockerDriverEnabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    function Test-IsDockerDriverListening {
        return Invoke-Command -Session $Session -ScriptBlock {
            return Test-Path //./pipe/Contrail
        }
    }

    function Test-IsDockerPluginRegistered {
        return Invoke-Command -Session $Session -ScriptBlock {
            return Test-Path $Env:ProgramData/docker/plugins/Contrail.spec
        }
    }

    function Test-IsDockerDriverProcessRunning {
        return Test-IsProcessRunning -Session $Session -ProcessName "contrail-windows-docker"
    }

    return (Test-IsDockerDriverListening) -And `
        (Test-IsDockerPluginRegistered) -And `
        (Test-IsDockerDriverProcessRunning)
}

function Enable-AgentService {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Invoke-Command -Session $Session -ScriptBlock {
        Write-Host "Starting Agent"
        Start-Service ContrailAgent | Out-Null
    }
}

function Disable-AgentService {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Invoke-Command -Session $Session -ScriptBlock {
        Write-Host "Stopping Agent"
        Stop-Service ContrailAgent -ErrorAction SilentlyContinue | Out-Null
    }
}

function Assert-IsAgentServiceEnabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    $MaxWaitTimeInSeconds = $MAX_WAIT_TIME_FOR_AGENT_IN_SECONDS
    $TimeBetweenChecksInSeconds = $TIME_BETWEEN_AGENT_CHECKS_IN_SECONDS
    $MaxNumberOfChecks = [Math]::Ceiling($MaxWaitTimeInSeconds / $TimeBetweenChecksInSeconds)

    for ($RetryNum = $MaxNumberOfChecks; $RetryNum -gt 0; $RetryNum--) {
        $Status = Invoke-Command -Session $Session -ScriptBlock {
            return $((Get-Service "ContrailAgent" -ErrorAction SilentlyContinue).Status)
        }
        if ($Status.Value -eq "Running") {
            return
        }

        Start-Sleep -s $TimeBetweenChecksInSeconds
    }

    throw "Agent service is not enabled. EXPECTED: Agent service is enabled"
}

function Assert-IsAgentServiceDisabled {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    $MaxWaitTimeInSeconds = $MAX_WAIT_TIME_FOR_AGENT_IN_SECONDS
    $TimeBetweenChecksInSeconds = $TIME_BETWEEN_AGENT_CHECKS_IN_SECONDS
    $MaxNumberOfChecks = [Math]::Ceiling($MaxWaitTimeInSeconds / $TimeBetweenChecksInSeconds)

    for ($RetryNum = $MaxNumberOfChecks; $RetryNum -gt 0; $RetryNum--) {
        $Status = Invoke-Command -Session $Session -ScriptBlock {
            return $((Get-Service "ContrailAgent" -ErrorAction SilentlyContinue).Status)
        }
        if ($Status.Value -eq "Stopped") {
            return
        }

        Start-Sleep -s $TimeBetweenChecksInSeconds
    }

    throw "Agent service is not disabled. EXPECTED: Agent service is disabled"
}

function Assert-AgentProcessCrashed {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $false)] [Int] $TimeoutSeconds = 60)

    $TimeBetweenChecksInSeconds = 2

    foreach ($i in 0..($TimeoutSeconds / $TimeBetweenChecksInSeconds)) {
        $Res = Invoke-Command -Session $Session -ScriptBlock {
            return $(Get-EventLog -LogName "System" -EntryType "Error" -Source "Service Control Manager" -Newest 10 | Where {$_.Message -match "The ContrailAgent service terminated unexpectedly" -AND $_.TimeGenerated -gt (Get-Date).AddSeconds(-5)})
        }

        if ($Res) {
            return
        }

        Start-Sleep -s $TimeBetweenChecksInSeconds
    }

    throw "Agent process didn't crash. EXPECTED: Agent process crashed"
}

function New-DockerNetwork {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
           [Parameter(Mandatory = $false)] [string] $Name,
           [Parameter(Mandatory = $false)] [string] $TenantName,
           [Parameter(Mandatory = $false)] [string] $Network,
           [Parameter(Mandatory = $false)] [string] $Subnet)

    $Configuration = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration

    if (!$Name) {
        $Name = $Configuration.DefaultNetworkName
    }

    if (!$Network) {
        $Network = $Configuration.DefaultNetworkName
    }

    if (!$TenantName) {
        $TenantName = $Configuration.Name
    }

    Write-Host "Creating network $Name"

    $NetworkID = Invoke-Command -Session $Session -ScriptBlock {
        if ($Using:Subnet) {
            return $(docker network create --ipam-driver windows --driver Contrail -o tenant=$Using:TenantName -o network=$Using:Network --subnet $Using:Subnet $Using:Name)
        }
        else {
            return $(docker network create --ipam-driver windows --driver Contrail -o tenant=$Using:TenantName -o network=$Using:Network $Using:Name)
        }
    }

    return $NetworkID
}

function Remove-AllUnusedDockerNetworks {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session)

    Write-Host "Removing all docker networks"

    Invoke-Command -Session $Session -ScriptBlock {
        docker network prune --force | Out-Null
    }
}

function Initialize-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
           [Parameter(Mandatory = $false)] [bool] $NoNetwork = $false)

    Write-Host "Initializing Test Configuration"

    $NRetries = 3;
    foreach ($i in 1..$NRetries) {
        # DockerDriver automatically enables Extension, so there is no need to enable it manually
        Enable-DockerDriver -Session $Session -AdapterName $TestConfiguration.AdapterName -ControllerIP $TestConfiguration.ControllerIP -Configuration $TestConfiguration.DockerDriverConfiguration -WaitTime 0

        $WaitForSeconds = $i * 600 / $NRetries;
        $SleepTimeBetweenChecks = 10;
        $MaxNumberOfChecks = $WaitForSeconds / $SleepTimeBetweenChecks

        # Wait for DockerDriver to start
        $Res = $false
        for ($RetryNum = $MaxNumberOfChecks; $RetryNum -gt 0; $RetryNum--) {
            $Res = Test-IsDockerDriverEnabled -Session $Session
            if ($Res -eq $true) {
                break;
            }

            Start-Sleep -s $SleepTimeBetweenChecks
        }

        if ($Res -ne $true) {
            if ($i -eq $NRetries) {
                throw "Docker driver was not enabled."
            } else {
                Write-Host "Docker driver was not enabled, retrying."
            }
        } else {
            break;
        }
    }

    if (!$NoNetwork) {
        New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration | Out-Null
    }
}

function Clear-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    Write-Host "Cleaning up test configuration"

    Remove-AllUnusedDockerNetworks -Session $Session
    Disable-AgentService -Session $Session
    Disable-DockerDriver -Session $Session
    Disable-VRouterExtension -Session $Session -AdapterName $TestConfiguration.AdapterName `
        -VMSwitchName $TestConfiguration.VMSwitchName -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
}

function New-AgentConfigFile {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    # Gather information about testbed's network adapters
    $HNSTransparentAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $TestConfiguration.VHostName

    $PhysicalAdapter = Get-RemoteNetAdapterInformation `
            -Session $Session `
            -AdapterName $TestConfiguration.AdapterName

    # Prepare parameters for script block
    $ControllerIP = $TestConfiguration.ControllerIP
    $VHostIfName = $HNSTransparentAdapter.ifName
    $VHostIfIndex = $HNSTransparentAdapter.ifIndex

    # NOTE: $TEST_NETWORK_GATEWAY is not set here,
    # so it's equivalent to $VHostGatewayIP = ""
    # TODO: Needs fixing for JW-1262
    $VHostGatewayIP = $TEST_NETWORK_GATEWAY
    $PhysIfName = $PhysicalAdapter.ifName

    $AgentConfigFilePath = $TestConfiguration.AgentConfigFilePath

    Invoke-Command -Session $Session -ScriptBlock {
        $ControllerIP = $Using:ControllerIP
        $VHostIfName = $Using:VHostIfName
        $VHostIfIndex = $Using:VHostIfIndex
        $PhysIfName = $Using:PhysIfName

        $VHostIP = (Get-NetIPAddress -ifIndex $VHostIfIndex -AddressFamily IPv4).IPAddress
        $VHostGatewayIP = $Using:VHostGatewayIP

        $ConfigFileContent = @"
[DEFAULT]
platform=windows

[CONTROL-NODE]
server=$ControllerIP

[DISCOVERY]
server=$ControllerIP

[VIRTUAL-HOST-INTERFACE]
name=$VHostIfName
ip=$VHostIP/24
gateway=$VHostGatewayIP
physical_interface=$PhysIfName
"@

        # Save file with prepared config
        [System.IO.File]::WriteAllText($Using:AgentConfigFilePath, $ConfigFileContent)
    }
}

function Initialize-ComputeServices {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $false)] [Boolean] $NoNetwork = $false)

        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration -NoNetwork $NoNetwork
        New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration
        Enable-AgentService -Session $Session
}

function Remove-DockerNetwork {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
           [Parameter(Mandatory = $false)] [string] $Name)

    if (!$Name) {
        $Name = $TestConfiguration.DockerDriverConfiguration.TenantConfiguration.DefaultNetworkName
    }

    Invoke-Command -Session $Session -ScriptBlock {
        docker network rm $Using:Name | Out-Null
    }
}

function New-Container {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [string] $NetworkName,
           [Parameter(Mandatory = $false)] [string] $Name)

    $ContainerID = Invoke-Command -Session $Session -ScriptBlock {
        if ($Using:Name) {
            return $(docker run --name $Using:Name --network $Using:NetworkName -id microsoft/nanoserver powershell)
        }
        else {
            return $(docker run --network $Using:NetworkName -id microsoft/nanoserver powershell)
        }
    }

    return $ContainerID
}

function Remove-Container {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $false)] [string] $NameOrId)

    Invoke-Command -Session $Session -ScriptBlock {
        docker rm -f $Using:NameOrId | Out-Null
    }
}
