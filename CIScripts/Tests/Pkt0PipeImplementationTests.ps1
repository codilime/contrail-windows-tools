function Test-Pkt0PipeImplementation {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    function Assert-ExtensionIsRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Running = Test-IsVRouterExtensionEnabled -Session $Session -VMSwitchName $TestConfiguration.VMSwitchName -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        if (!$Running) {
            throw "Extension is not running. EXPECTED: Extension is running"
        }
    }

    function Assert-ExtensionIsNotRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Running = Test-IsVRouterExtensionEnabled -Session $Session -VMSwitchName $TestConfiguration.VMSwitchName -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        if ($Running) {
            throw "Extension is running. EXPECTED: Extension is not running"
        }
    }

    function Test-StartingAgentWhenExtensionDisabled {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-StartingAgentWhenExtensionDisabled"

        Write-Host "======> Given Extension is not running"
        Assert-ExtensionIsNotRunning -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> Then Agent should crash when started"

        Write-Host "======> Cleanup"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "===> PASSED: Test-StartingAgentWhenExtensionDisabled"
    }

    function Test-StartingAgentWhenExtensionEnabled {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-StartingAgentWhenExtensionEnabled"

        Write-Host "======> Given Extension is running"
        Enable-VRouterExtension -Session $Session -AdapterName $TestConfiguration.AdapterName -VMSwitchName $TestConfiguration.VMSwitchName `
            -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> When Agent is started"

        Write-Host "======> Then Agent should work"

        Write-Host "======> Cleanup"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "===> PASSED: Test-StartingAgentWhenExtensionEnabled"
    }

    function Test-DisablingExtensionWhenAgentEnabled {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-DisablingExtensionWhenAgentEnabled"
        Enable-VRouterExtension -Session $Session -AdapterName $TestConfiguration.AdapterName -VMSwitchName $TestConfiguration.VMSwitchName `
            -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> Given Extension and Agent are running"

        Write-Host "======> When Extension is disabled"

        Write-Host "======> Then Agent should crash"

        Write-Host "======> Cleanup"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "===> PASSED: Test-DisablingExtensionWhenAgentEnabled"
    }

    function Test-ReenablingExtension {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-ReenablingExtension"

        Write-Host "======> Given Extension and Agent are running"
        Enable-VRouterExtension -Session $Session -AdapterName $TestConfiguration.AdapterName -VMSwitchName $TestConfiguration.VMSwitchName `
            -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "======> When Extension is disabled"

        Write-Host "======> When Extension is reenabled"

        Write-Host "======> Then Agent should not work"

        Write-Host "======> Cleanup"
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        Write-Host "===> PASSED: Test-ReenablingExtension"
    }

    Test-StartingAgentWhenExtensionDisabled -Session $Session -TestConfiguration $TestConfiguration
    Test-StartingAgentWhenExtensionEnabled -Session $Session -TestConfiguration $TestConfiguration
    Test-DisablingExtensionWhenAgentEnabled -Session $Session -TestConfiguration $TestConfiguration
    Test-ReenablingExtension -Session $Session -TestConfiguration $TestConfiguration
}
