function Test-DockerMultiTenancy {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
        [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\CommonTestCode.ps1
    . $PSScriptRoot\..\Job.ps1
    . $PSScriptRoot\..\ContrailUtils.ps1

    #
    # Private functions of Test-DockerMultiTenancy
    #

    class Network {
        [string] $TenantName
        [string] $Name;
        [string] $Uuid;
    }

    function Assert-IsContainerIpEqualToExpectedValue {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
            [Parameter(Mandatory = $true)] [string] $ContainerName,
            [Parameter(Mandatory = $true)] [string] $ExpectedIPAddress)

        $IPAddress = Invoke-Command -Session $Session -ScriptBlock {
            return $(docker exec $Using:ContainerName powershell "(Get-NetIpAddress -AddressFamily IPv4 | Where-Object IPAddress -NE 127.0.0.1).IPAddress")
        }

        if (!$IPAddress) {
            throw "IP Address not found"
        }

        if ($IPAddress -ne $ExpectedIPAddress) {
            throw "Container " + $ContainerName + " IP address = " + $IPAddress + " isn't equal to expected one = " + $ExpectedIPAddress
        }
    }

    function GetRandomNetworkName {
        return "testnetwork-" + -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 8 | % {[char]$_})
    }

    function SetUpNetworksForTenants {
        Param ([Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
            [Parameter(Mandatory = $true)] [String] $Authtoken,
            [Parameter(Mandatory = $true)] [String[]] $Tenants,
            [Parameter(Mandatory = $true)] [SubnetConfiguration] $SubnetConfig)

        $Networks = @()
        foreach ($Tenant in $Tenants) {
            $Network = [Network]::new()
            $Network.TenantName = $Tenant
            $Network.Name = GetRandomNetworkName
            $ContrailUrl = $TestConfiguration.ControllerIP + ":" + $TestConfiguration.ControllerRestPort
            $Network.Uuid = Add-ContrailVirtualNetwork -ContrailUrl $ContrailUrl `
                -AuthToken $Authtoken -TenantName $Tenant -NetworkName $Network.Name -SubnetConfig $SubnetConfig
            
            $Networks += $Network
        }

        return $Networks
    }

    function CleanUpNetworks {
        Param ([Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
            [Parameter(Mandatory = $true)] [Network[]] $Networks,
            [Parameter(Mandatory = $true)] [String] $Authtoken)

        ForEach ($Network in $Networks) {
            $ContrailUrl = $TestConfiguration.ControllerIP + ":" + $TestConfiguration.ControllerRestPort
            Remove-ContrailVirtualNetwork -ContrailUrl $ContrailUrl -AuthToken $Authtoken -NetworkUuid $Network.Uuid
        }
    }

    function Test-DifferentTenantsSameIp {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
            [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-DifferentTenantsSameIp"

        Write-Host "======> Given environment with networks for different tenants"
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        $ExpectedIPAddress = "10.0.0.100"
        $SubnetConfig = [SubnetConfiguration]::new("10.0.0.0", 24, "10.0.0.1", $ExpectedIPAddress, $ExpectedIPAddress)
        $ContrailCredentials = $TestConfiguration.DockerDriverConfiguration
        $Authtoken = Get-AccessTokenFromKeystone -AuthUrl $ContrailCredentials.AuthUrl -TenantName $ContrailCredentials.TenantConfiguration.Name `
            -Username $ContrailCredentials.Username -Password $ContrailCredentials.Password
        
        $Networks = SetUpNetworksForTenants -TestConfiguration $TestConfiguration -AuthToken $Authtoken -Tenants @("pm-1", "pm-2") `
            -SubnetConfig $SubnetConfig
        $Containers = @()
        $DockerNetworks = @()
        Try {
            Write-Host "======> When docker networks are created for each tenant"
            foreach ($Network in $Networks) {
                $DockerNetworks += New-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $Network.Name -TenantName $Network.TenantName `
                    -Network $Network.Name
            }

            Write-Host "======> When containers for each network are created and run"
            foreach ($Network in $DockerNetworks) {
                # Using the same container name as name of network
                $Containers += New-Container -Session $Session -NetworkName $Network
            }

            Write-Host "======> Then each container has same ip address"
            foreach ($Container in $Containers) {
                Assert-IsContainerIpEqualToExpectedValue -Session $Session -ContainerName $Container -ExpectedIPAddress $ExpectedIPAddress
            }
        }
        Finally {
            # Regardless result of test result clean up created networks and containers.
            # It is required to remove endpoints from Contrail before network clean up
            Write-Host "===> clean up"
            foreach ($Container in $Containers) {
                Remove-Container -Session $Session -Name $Container
            }

            foreach ($Network in $DockerNetworks) {
                Remove-DockerNetwork -Session $Session -TestConfiguration $TestConfiguration -Name $Network
            }

            CleanUpNetworks -TestConfiguration $TestConfiguration -AuthToken $Authtoken -Networks $Networks
        }

        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Write-Host "===> PASSED: Test-DifferentTenantsSameIp"
    }

    $DockerMultiTenancyTestsTimeTracker = [Job]::new("Test-DockerMultiTenancy")
    $DockerMultiTenancyTestsTimeTracker.StepQuiet("Test-DifferentTenantsSameIp", {
            Test-DifferentTenantsSameIp -Session $Session -TestConfiguration $TestConfiguration
        })

    $DockerMultiTenancyTestsTimeTracker.Done()
}