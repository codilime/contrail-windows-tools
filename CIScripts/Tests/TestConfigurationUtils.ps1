class DockerNetworkConfiguration {
    [string] $TenantName;
    [string] $NetworkName;
}

class DockerDriverConfiguration {
    [string] $Username;
    [string] $Password;
    [string] $AuthUrl;
    [string] $ControllerIP;
    [DockerNetworkConfiguration] $NetworkConfiguration;
}

class TestConfiguration {
    [DockerDriverConfiguration] $DockerDriverConfiguration;
    [string] $AdapterName;
    [string] $VMSwitchName;
    [string] $ForwardingExtensionName;
}

function Enable-VRouterExtension {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName)

    Write-Host "Enabling Extension"

    Invoke-Command -Session $sess -ScriptBlock {
        New-ContainerNetwork -Mode Transparent -NetworkAdapterName $Using:AdapterName -Name test_network
        Enable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName | Out-Null
    }
}

function Disable-VRouterExtension {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName)

    Write-Host "Disabling Extension"

    Invoke-Command -Session $Session -ScriptBlock {
        Disable-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue | Out-Null
        Get-ContainerNetwork | Remove-ContainerNetwork -Force
    }
}

function Test-VRouterExtensionEnabled {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [string] $VMSwitchName,
           [Parameter(Mandatory = $true)] [string] $ForwardingExtensionName)

    $Ext = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-VMSwitchExtension -VMSwitchName $Using:VMSwitchName -Name $Using:ForwardingExtensionName -ErrorAction SilentlyContinue)
    }

    return $($Ext.Enabled -and $Ext.Running)
}

function Enable-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [string] $AdapterName,
           [Parameter(Mandatory = $true)] [DockerDriverConfiguration] $Configuration)

    Write-Host "Enabling Docker Driver"

    $TenantName = $Configuration.NetworkConfiguration.TenantName

    Invoke-Command -Session $Session -ScriptBlock {
        # Nested ScriptBlock variable passing workaround
        $AdapterName = $Using:AdapterName
        $Configuration = $Using:Configuration
        $TenantName = $Using:TenantName

        Start-Job -ScriptBlock {
            $Configuration = $Using:Configuration

            $Env:OS_USERNAME = $Configuration.Username
            $Env:OS_PASSWORD = $Configuration.Password
            $Env:OS_AUTH_URL = $Configuration.AuthUrl
            $Env:OS_TENANT_NAME = $Using:TenantName

            & "C:\Program Files\Juniper Networks\contrail-windows-docker.exe" -forceAsInteractive -controllerIP $Configuration.ControllerIP -adapter $Using:AdapterName -vswitchName "Layered <adapter>"
        } | Out-Null
    }

    Start-Sleep -s 30
}

function Disable-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

    Write-Host "Disabling Docker Driver"

    Invoke-Command -Session $Session -ScriptBlock {
        $Proc = Get-Process contrail-windows-docker -ErrorAction SilentlyContinue
        if ($Proc) {
            $Proc | Stop-Process -Force
        }

        Stop-Service docker | Out-Null
        Get-NetNat | Remove-NetNat -Confirm:$false
        Get-ContainerNetwork | Remove-ContainerNetwork -Force
        Start-Service docker | Out-Null
    }
}

function Test-DockerDriverEnabled {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

    $Proc = Invoke-Command -Session $Session -ScriptBlock {
        return $(Get-Process contrail-windows-docker -ErrorAction SilentlyContinue)
    }

    return $(if ($Proc) { $true } else { $false })
}

function New-DockerNetwork {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [DockerNetworkConfiguration] $Configuration)

    Write-Host "Creating network $($Configuration.NetworkName)"

    $NetworkID = Invoke-Command -Session $Session -ScriptBlock {
        $TenantName = ($Using:Configuration).TenantName
        $NetworkName = ($Using:Configuration).NetworkName
        return $(docker network create --ipam-driver windows --driver Contrail -o tenant=$TenantName -o network=$NetworkName $NetworkName)
    }

    return $NetworkID
}

function Remove-AllUnusedDockerNetworks {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

    Write-Host "Removing all docker networks"

    Invoke-Command -Session $Session -ScriptBlock {
        docker network prune --force | Out-Null
    }
}

function Initialize-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    Write-Host "Initializing Test Configuration"

    # DockerDriver automatically enables Extension, so there is no need to enable it manually
    Enable-DockerDriver -Session $Session -AdapterName $TestConfiguration.AdapterName -Configuration $TestConfiguration.DockerDriverConfiguration

    $Res = Test-VRouterExtensionEnabled -Session $Session -VMSwitchName $TestConfiguration.VMSwitchName -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
    if ($Res -ne $true) {
        throw "Extension was not enabled or is not running."
    }

    $Res = Test-DockerDriverEnabled -Session $Session
    if ($Res -ne $true) {
        throw "Docker driver was not enabled."
    }

    New-DockerNetwork -Session $Session -Configuration $TestConfiguration.DockerDriverConfiguration.NetworkConfiguration | Out-Null
}

function Clear-TestConfiguration {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    Write-Host "Cleaning up test configuration"

    Remove-AllUnusedDockerNetworks -Session $Session
    Disable-DockerDriver -Session $Session
    Disable-VRouterExtension -Session $Session -VMSwitchName $TestConfiguration.VMSwitchName -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
}
