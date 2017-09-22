function Test-MultipleSubnetsSupport {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    function Join-ContainerNetworkNamePrefix {
        Param ([Parameter(Mandatory = $true)] [string] $Tenant,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        $Prefix = "{0}:{1}:{2}" -f @("Contrail", $Tenant, $Network)

        if ($Subnet) {
            $Prefix = "{0}:{1}" -f @($Prefix, $Subnet)
        }

        return $Prefix
    }

    function Get-SpecificTransparentContainerNetwork {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        $Networks = Invoke-Command -Session $Session -ScriptBlock {
            return $(Get-ContainerNetwork | Where-Object Mode -EQ "Transparent")
        }

        $ContainerNetworkPrefix = Join-ContainerNetworkNamePrefix `
            -Tenant $TestConfiguration.DockerDriverConfiguration.NetworkConfiguration.TenantName -Network $Network -Subnet $Subnet

        return $($Networks | Where-Object { $_.Name.StartsWith($ContainerNetworkPrefix) })
    }

    function Assert-NetworkExists {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration,
               [Parameter(Mandatory = $true)] [string] $Name,
               [Parameter(Mandatory = $true)] [string] $Network,
               [Parameter(Mandatory = $false)] [string] $Subnet)

        $Networks = Invoke-Command -Session $Session -ScriptBlock {
            $Networks = $(docker network ls --filter 'driver=Contrail')
            return $Networks[1..($Networks.length - 1)]
        }

        $Res = $Networks | Where-Object { $_.Split("", [System.StringSplitOptions]::RemoveEmptyEntries)[1] -eq $Name }
        if (!$Res) {
            throw "Network $Name not found in docker network list"
        }

        $Res = Get-SpecificTransparentContainerNetwork -Session $Session -TestConfiguration $TestConfiguration -Network $Network -Subnet $Subnet
        if (!$Res) {
            throw "Network $Name not found in container network list"
        }

        if ($Subnet -and ($Res.SubnetPrefix -ne $Subnet)) {
            throw "Invalid subnet: ${Res.SubnetPrefix}. Should be: $Subnet"
        }
    }

    function Test-SingleNetworkSingleSubnetDefault {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-SingleNetworkSingleSubnetDefault"

        # TODO: Implement

        Write-Host "===> PASSED: Test-SingleNetworkSingleSubnetDefault"
    }

    function Test-SingleNetworkSingleSubnetExplicit {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-SingleNetworkSingleSubnetExplicit"

        # TODO: Implement

        Write-Host "===> PASSED: Test-SingleNetworkSingleSubnetExplicit"
    }

    function Test-SingleNetworkSingleSubnetInvalid {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-SingleNetworkSingleSubnetInvalid"

        # TODO: Implement

        Write-Host "===> PASSED: Test-SingleNetworkSingleSubnetInvalid"
    }

    function Test-SingleNetworkMultipleSubnetsDefault {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsDefault"

        # TODO: Implement

        Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsDefault"
    }

    function Test-SingleNetworkMultipleSubnetsExplicitFirst {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsExplicitFirst"

        # TODO: Implement

        Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsExplicitFirst"
    }

    function Test-SingleNetworkMultipleSubnetsExplicitSecond {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsExplicitSecond"

        # TODO: Implement

        Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsExplicitSecond"
    }

    function Test-SingleNetworkMultipleSubnetsInvalid {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsInvalid"

        # TODO: Implement

        Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsInvalid"
    }

    function Test-SingleNetworkMultipleSubnetsAllSimultaneously {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-SingleNetworkMultipleSubnetsAllSimultaneously"

        # TODO: Implement

        Write-Host "===> PASSED: Test-SingleNetworkMultipleSubnetsAllSimultaneously"
    }

    function Test-MultipleNetworksMultipleSubnetsAllSimultaneously {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-MultipleNetworksMultipleSubnetsAllSimultaneously"

        # TODO: Implement

        Write-Host "===> PASSED: Test-MultipleNetworksMultipleSubnetsAllSimultaneously"
    }

    Test-SingleNetworkSingleSubnetDefault -Session $Session -TestConfiguration $TestConfiguration
    Test-SingleNetworkSingleSubnetExplicit -Session $Session -TestConfiguration $TestConfiguration
    Test-SingleNetworkSingleSubnetInvalid -Session $Session -TestConfiguration $TestConfiguration

    Test-SingleNetworkMultipleSubnetsDefault -Session $Session -TestConfiguration $TestConfiguration
    Test-SingleNetworkMultipleSubnetsExplicitFirst -Session $Session -TestConfiguration $TestConfiguration
    Test-SingleNetworkMultipleSubnetsExplicitSecond -Session $Session -TestConfiguration $TestConfiguration
    Test-SingleNetworkMultipleSubnetsInvalid -Session $Session -TestConfiguration $TestConfiguration

    Test-SingleNetworkMultipleSubnetsAllSimultaneously -Session $Session -TestConfiguration $TestConfiguration
    Test-MultipleNetworksMultipleSubnetsAllSimultaneously -Session $Session -TestConfiguration $TestConfiguration
}
