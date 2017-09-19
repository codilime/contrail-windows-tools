$Accel = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
$Accel::add("PSSessionT","System.Management.Automation.Runspaces.PSSession")

function Test-ComputeControllerIntegration {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $ComputeSession,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\CommonTestCode.ps1

    function Get-SSHHostname {
        Param([Parameter(Mandatory = $true)] [SSH.SshSession] $Session)
        $Result = Invoke-SSHCommand -Session $Session.SessionId -Command "hostname"
        return $Result.Output
    }

    function Get-PSHostname {
        Param([Parameter(Mandatory = $true)] [PSSessionT] $Session)
        return Invoke-Command -Session $Session -ScriptBlock { hostname }
    }

    function Test-ComputeInRedis {
        Param ([Parameter(Mandatory = $true)] [string] $ComputeHostname,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $AnalyticsSession)
        $Result = Invoke-SSHCommand -Session $AnalyticsSession.SessionId -Command 'for line in $(echo "keys *" | redis-cli); do { echo "lrange $line 0 1000" | redis-cli; } done'
        if ($ComputeHostname -notin $Result.Output) {
            return $false
        }
        return $true
    }

    function Assert-ComputeInRedis {
        Param ([Parameter(Mandatory = $true)] [string] $ComputeHostname,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $AnalyticsSession)

        if(!(Test-ComputeInRedis -ComputeHostname $ComputeHostname -AnalyticsSession $AnalyticsSession)) {
            throw "$ComputeHostname not found anywhere in redis! EXPECTED: it's in redis."
        }
    }

    function Assert-ComputeNotInRedis {
        Param ([Parameter(Mandatory = $true)] [string] $ComputeHostname,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $AnalyticsSession)

        if(Test-ComputeInRedis -ComputeHostname $ComputeHostname -AnalyticsSession $AnalyticsSession) {
            throw "$ComputeHostname found in redis! EXPECTED: it's not in redis."
        }
    }

    function Connect-ToController {
        Param ([Parameter(Mandatory = $true)] [string] $IP,
               [Parameter(Mandatory = $true)] [string] $Username,
               [Parameter(Mandatory = $true)] [string] $Password)
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $Credentials = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)
        return New-SSHSession -IPAddress $IP -Credential $Credentials -AcceptKey
    }

    function Test-ComputeNodeAppearsInAnalytics {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $AnalyticsSession,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-ComputeNodeAppearsInAnalytics"
            $ComputeHostname = Get-PSHostname -Session $Session
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given our compute node is not in redis"
            Assert-ComputeNotInRedis -ComputeHostname $ComputeHostname -AnalyticsSession $AnalyticsSession

            Write-Host "======> When all compute services are started"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Then our compute node appears in redis after a while"
            Start-Sleep -Seconds 15
            Assert-ComputeInRedis -ComputeHostname $ComputeHostname -AnalyticsSession $AnalyticsSession
        })
    }

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        $ControllerSession = Connect-ToController -Username "ubuntu" -Password "ubuntu" -IP $TestConfiguration.DockerDriverConfiguration.ControllerIP 
        
        Test-ComputeNodeAppearsInAnalytics -AnalyticsSession $ControllerSession -Session $ComputeSession -TestConfiguration $TestConfiguration

        # Test cleanup
        Clear-TestConfiguration -Session $ComputeSession -TestConfiguration $TestConfiguration
    })

}
