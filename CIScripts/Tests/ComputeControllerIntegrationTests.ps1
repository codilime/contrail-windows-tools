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

    function Test-ComputeInCassandra {
        Param ([Parameter(Mandatory = $true)] [string] $ComputeHostname,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $DiscoverySession)
        $Hostname = Get-SSHHostname -Session $DiscoverySession
        $Query = 'select column1,column2 from \"DISCOVERY_SERVER\".discovery;'
        $Result = Invoke-SSHCommand -Session $DiscoverySession.SessionId -Command "cqlsh $Hostname -u cassandra -p cassandra -e $Query | grep $ComputeHostname"
        if ($ComputeHostname -notin $Result.Output) {
            return $false
        }
        return $true
    }

    function Assert-ComputeInCassandra {
        Param ([Parameter(Mandatory = $true)] [string] $ComputeHostname,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $DiscoverySession)

        if(!(Test-ComputeInCassandra -ComputeHostname $ComputeHostname -DiscoverySession $DiscoverySession)) {
            throw "$ComputeHostname not found anywhere in Cassandra! EXPECTED: it's in Cassandra."
        }
    }

    function Assert-ComputeNotInCassandra {
        Param ([Parameter(Mandatory = $true)] [string] $ComputeHostname,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $DiscoverySession)

        if(Test-ComputeInCassandra -ComputeHostname $ComputeHostname -DiscoverySession $DiscoverySession) {
            throw "$ComputeHostname found in Cassandra! EXPECTED: it's not in Cassandra."
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

    function Test-ComputeNodeAppearsInDiscovery {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $DiscoverySession,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-ComputeNodeAppearsInDiscovery"
            $ComputeHostname = Get-PSHostname -Session $Session
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given our compute node is not in Cassandra"
            Assert-ComputeNotInCassandra -ComputeHostname $ComputeHostname -DiscoverySession $DiscoverySession

            Write-Host "======> When all compute services are started"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Then our compute node appears in Cassandra after a while"
            Start-Sleep -Seconds 5
            Assert-ComputeInCassandra -ComputeHostname $ComputeHostname -DiscoverySession $DiscoverySession
        })
    }

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        $ControllerSession = Connect-ToController -Username "ubuntu" -Password "ubuntu" -IP $TestConfiguration.DockerDriverConfiguration.ControllerIP 
        
        Test-ComputeNodeAppearsInDiscovery -DiscoverySession $ControllerSession -Session $ComputeSession -TestConfiguration $TestConfiguration

        # Test cleanup
        Clear-TestConfiguration -Session $ComputeSession -TestConfiguration $TestConfiguration
    })

}
