function Test-VRouterAgentIntegration {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    #
    # Private functions of Test-VRouterAgentIntegration
    #

    function Assert-ExtensionIsRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $isEnabled = Test-IsVRouterExtensionEnabled `
            -Session $Session `
            -VMSwitchName $TestConfiguration.VMSwitchName `
            -ForwardingExtensionName $TestConfiguration.ForwardingExtensionName
        if (!$isEnabled) {
            throw "Hyper-V Extension is not running. EXPECTED: Hyper-V Extension is running"
        }
    }

    function Assert-AgentIsRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        if (!(Test-IsVRouterAgentEnabled -Session $Session)) {
            throw "vRouter Agent is not running. EXPECTED: vRouter Agent is running"
        }
    }

    function Assert-AgentIsNotRunning {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        if (Test-IsVRouterAgentEnable -Session $Session) {
            throw "vRouter Agent is running. EXPECTED: vRouter Agent is not running"
        }
    }

    function Assert-NoVifs {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $vifOutput = Invoke-Command -Session $Session -ScriptBlock { vif.exe --list }
        if ($vifOutput -Match "vif") {
            throw "There are vifs registered in vRouter. EXPECTED: no vifs in vRouter"
        }
    }

    function Assert-IsPkt0Injected {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $vifOutput = Invoke-Command -Session $Session -ScriptBlock { vif.exe --list }
        $match = $($vifOutput -Match "Type:Agent")
        if (!$match) {
            throw "pkt0 interface is not injected. EXPECTED: pkt0 injected in vRouter"
        }
    }

    function Assert-IsOnlyOnePkt0Injected {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $vifOutput = Invoke-Command -Session $Session -ScriptBlock { vif.exe --list }
        $match = $($vifOutput -Match "Type:Agent")
        if (!$match) {
            throw "pkt0 interface is not injected. EXPECTED: pkt0 injected in vRouter"
        }
        if ($match.Count > 1) {
            throw "more than 1 pkt0 interfaces were injected. EXPECTED: only one pkt0 interface in vRouter"
        }
    }

    #
    # Tests definitions
    #

    function Test-InitialPkt0Injection {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        # Given Extension is running
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        # Given clean vRouter
        Assert-NoVifs -Session $Session

        # When Agent is started
        Enable-VRouterAgent -Session $Session
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds 15

        # Then pkt0 appears in vRouter
        Assert-IsPkt0Injected -Session $Session
    }

    function Test-Pkt0RemainsInjectedAfterAgentStops {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        # Given Extension is running
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Assert-ExtensionIsRunning -Session $Session -TestConfiguration $TestConfiguration

        # Given Agent is running
        Enable-VRouterAgent -Session $Session
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds 15

        # Given pkt0 is injected
        Test-IsPkt0Injected -Session $Session

        # When Agent is stopped
        Disable-VRouterAgent -Session $Session
        Assert-AgentIsNotRunning -Session $Session

        # Then pkt0 exists in vRouter
        Assert-IsPkt0Injected -Session $Session
    }

    function Test-OnePkt0ExistsAfterAgentIsRestarted {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        # Given Extension is running
        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        # Given Agent is running
        Enable-VRouterAgent -Session $Session
        Test-IsVRouterAgentEnable -Session $Session
        Start-Sleep -Seconds 15

        # Given pkt0 is injected
        Test-IsPkt0Injected -Session $Session

        # When Agent is restarted
        Disable-VRouterAgent -Session $Session
        Assert-AgentIsNotRunning -Session $Session
        Enable-VRouterAgent -Session $Session
        Assert-AgentIsRunning -Session $Session
        Start-Sleep -Seconds 15

        # Then pkt0 exists in vRouter
        Assert-IsOnlyOnePkt0Injected -Session $Session
    }

    Test-InitialPkt0Injection -Session $Session -TestConfiguration $TestConfiguration
    Test-Pkt0RemainsInjectedAfterAgentStops -Session $Session -TestConfiguration $TestConfiguration
    Test-OnePkt0ExistsAfterAgentIsRestarted -Session $Session -TestConfiguration $TestConfiguration
}
