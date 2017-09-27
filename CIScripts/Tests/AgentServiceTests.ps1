function Test-AgentService {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\CommonTestCode.ps1
    
    $WAIT_TIME_FOR_AGENT_SERVICE_IN_SECONDS = 30

    #
    # Private functions of Test-AgentService
    #

    function Install-Agent {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        Invoke-Command -Session $Session -ScriptBlock {
            Write-Host "Installing Agent"
            Start-Process msiexec.exe -ArgumentList @("/i", "C:\Artifacts\contrail-vrouter-agent.msi", "/quiet") -Wait

            # Refresh Path
            $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        }

        Start-Sleep -s $WAIT_TIME_FOR_AGENT_SERVICE_IN_SECONDS
    }

    function Uninstall-Agent {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        Invoke-Command -Session $Session -ScriptBlock {
            Write-Host "Unistalling Agent"
            Start-Process msiexec.exe -ArgumentList @("/x", "C:\Artifacts\contrail-vrouter-agent.msi", "/quiet") -Wait

            # Refresh Path
            $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        }

        Start-Sleep -s $WAIT_TIME_FOR_AGENT_SERVICE_IN_SECONDS
    }

    function Enable-AgentService {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        Invoke-Command -Session $Session -ScriptBlock {
            Start-Service ContrailAgent | Out-Null
        }
    }

    function Disable-AgentService {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        Invoke-Command -Session $Session -ScriptBlock {
            Stop-Service ContrailAgent | Out-Null
        }
    }

    function Test-IsAgentServiceRegistered {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $Service = Invoke-Command -Session $Session -ScriptBlock {
            return $(if (Get-Service "ContrailAgent" -ErrorAction SilentlyContinue) { $true } else { $false }) 
        }
        Write-Host $Service
        return $Service        
    }
    function Assert-IsAgentServiceRegistered {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $Res = Test-IsAgentServiceRegistered -Session $Session
        if (!$Res) {
            throw "Agent service is not registered. EXPECTED: Agent service registered"
        }
    }

    function Assert-IsAgentServiceUnregistered {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $Res = Test-IsAgentServiceRegistered -Session $Session
        if ($Res) {
            throw "Agent service is registered. EXPECTED: Agent service unregistered"
        }
    }

    function Assert-IsAgentServiceEnabled {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $Service = Invoke-Command -Session $Session -ScriptBlock {
            return $(Get-Service "ContrailAgent" -ErrorAction SilentlyContinue)
        }
        if (!$Service) {
            throw "Agent service is not registered. EXPECTED: Agent service registered"
        }
        if ($Service.Status -eq "Stopped") {
            throw "Agent service is stopped. EXPECTED: Agent service running"
        }
    }

    function Assert-IsAgentServiceDisabled {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session)

        $Service = Invoke-Command -Session $Session -ScriptBlock {
            return $(Get-Service "ContrailAgent" -ErrorAction SilentlyContinue)
        }
        if (!$Service) {
            throw "Agent service is not registered. EXPECTED: Agent service registered"
        }
        if ($Service.Status -eq "Running") {
            throw "Agent service is running. EXPECTED: Agent service stopped"
        }
    }

    #
    # Tests definitions
    #

    function Test-AgentServiceIsRegisteredAfterInstall {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-AgentServiceIsRegisteredAfterInstall"

        Write-Host "======> Given clean environment"
        #Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        #Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Uninstall-Agent -Session $Session
        Assert-IsAgentServiceUnregistered -Session $Session

        Write-Host "======> When Agent is installed via MSI"
        Install-Agent -Session $Session

        Write-Host "======> Then Agent is registered as a service"
        Assert-IsAgentServiceRegistered -Session $Session

        Write-Host "===> PASSED: Test-AgentServiceIsRegisteredAfterInstall"
    }

    function Test-AgentServiceIsDisabledAfterInstall {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-AgentServiceIsDisabledAfterInstall"

        Write-Host "======> Given clean environment"
        #Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        #Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Uninstall-Agent -Session $Session
        Assert-IsAgentServiceUnregistered -Session $Session

        Write-Host "======> When Agent is installed via MSI"
        Install-Agent -Session $Session

        Write-Host "======> Then Agent is disabled"
        Assert-IsAgentServiceDisabled -Session $Session

        Write-Host "===> PASSED: Test-AgentServiceIsDisabledAfterInstall"
    }

    function Test-AgentServiceIsUnregisteredAfterUninstall {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-AgentServiceIsUnregisteredAfterUninstall"

        Write-Host "======> Given Agent is installed"
        #Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        #Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Install-Agent -Session $Session
        Assert-IsAgentServiceRegistered -Session $Session

        Write-Host "======> When Agent is uninstalled"
        Uninstall-Agent -Session $Session

        Write-Host "======> Then Agent is unregistered"
        Assert-IsAgentServiceUnregistered -Session $Session

        Write-Host "===> PASSED: Test-AgentServiceIsUnregisteredAfterUninstall"
    }

    function Test-AgentServiceEnabling {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-AgentServiceEnabling"

        Write-Host "======> Given Agent is installed"
        #Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        #Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Install-Agent -Session $Session
        Assert-IsAgentServiceRegistered -Session $Session

        Write-Host "======> When Agent is enabled"
        Enable-AgentService -Session $Session

        Write-Host "======> Then Agent state is equal to ENABLE after a while"
        Start-Sleep -s $WAIT_TIME_FOR_AGENT_SERVICE_IN_SECONDS
        Assert-IsAgentServiceEnabled -Session $Session

        Write-Host "===> PASSED: Test-AgentServiceEnabling"
    }

    function Test-AgentServiceDisabling {
        Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        Write-Host "===> Running: Test-AgentServiceDisabling"

        Write-Host "======> Given Agent is installed"
        #Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        #Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Install-Agent -Session $Session
        Assert-IsAgentServiceRegistered -Session $Session

        Write-Host "======> When Agent is disabled"
        Disable-AgentService -Session $Session

        Write-Host "======> Then Agent state is equal to DISABLE after a while"
        Start-Sleep -s $WAIT_TIME_FOR_AGENT_SERVICE_IN_SECONDS
        Assert-IsAgentServiceDisabled -Session $Session

        Write-Host "===> PASSED: Test-AgentServiceDisabling"
    }

    Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
    Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

    New-AgentConfigFile -Session $Session -TestConfiguration $TestConfiguration

    Test-AgentServiceIsRegisteredAfterInstall -Session $Session -TestConfiguration $TestConfiguration
    Test-AgentServiceIsDisabledAfterInstall -Session $Session -TestConfiguration $TestConfiguration
    Test-AgentServiceIsUnregisteredAfterUninstall -Session $Session -TestConfiguration $TestConfiguration
    Test-AgentServiceEnabling -Session $Session -TestConfiguration $TestConfiguration
    Test-AgentServiceDisabling -Session $Session -TestConfiguration $TestConfiguration

    # Test cleanup
    Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
}
