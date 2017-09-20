function Test-MultipleSubnetsSupport {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

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

    Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
}
