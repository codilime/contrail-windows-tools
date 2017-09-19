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

    function Connect-ToController {
        Param ([Parameter(Mandatory = $true)] [string] $IP,
               [Parameter(Mandatory = $true)] [string] $Username,
               [Parameter(Mandatory = $true)] [string] $Password)
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $Credentials = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)
        return New-SSHSession -IPAddress $IP -Credential $Credentials -AcceptKey
    }

    function Test-ComputeInDnsAgentList {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)
        $Out = Invoke-RestMethod "$DnsIP:8092/Snh_ShowAgentList?"
        $OurNode = $Out.DnsAgentListResponse.agent.list.AgentData.peer | Where-Object "#text" -Like "$ComputeHostname*"
        if($OurNode) { 
            return $true
        }
        return $false
    }

    function Assert-ComputeInInDnsAgentList {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)

        if(!(Test-ComputeInDnsAgentList -DnsIP $DnsIP -ComputeHostname $ComputeHostname)) {
            throw "$ComputeHostname not found anywhere in DnsAgentList! EXPECTED: it's in DnsAgentList."
        }
    }

    function Assert-ComputeNotInInDnsAgentList {
        Param ([Parameter(Mandatory = $true)] [string] $DnsIP,
               [Parameter(Mandatory = $true)] [string] $ComputeHostname)

        if(Test-ComputeInDnsAgentList -DnsIP $DnsIP -ComputeHostname $ComputeHostname) {
            throw "$ComputeHostname found in DnsAgentList! EXPECTED: it's not in DnsAgentList."
        }
    }

    function Test-ComputeNodeAppearsInDnsAgentList {
        Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
               [Parameter(Mandatory = $true)] [SSH.SshSession] $DnsIP,
               [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

        $Job.StepQuiet($MyInvocation.MyCommand.Name, {
            Write-Host "===> Running: Test-ComputeNodeAppearsInDnsAgentList"
            $ComputeHostname = Get-PSHostname -Session $Session
            Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Given our compute node is not in DnsAgentList"
            Assert-ComputeNotInDnsAgentList -ComputeHostname $ComputeHostname -DnsSession $DnsSession

            Write-Host "======> When all compute services are started"
            Initialize-ComputeServices -Session $Session -TestConfiguration $TestConfiguration

            Write-Host "======> Then our compute node appears in DnsAgentList after a while"
            Start-Sleep -Seconds 5
            Assert-ComputeInDnsAgentList -ComputeHostname $ComputeHostname -DnsSession $DnsSession
        })
    }


    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        Test-ComputeNodeAppearsInDnsAgentList -DnsIP $TestConfiguration.DockerDriverConfiguration.ControllerIP -Session $ComputeSession -TestConfiguration $TestConfiguration

        # Test cleanup
        Clear-TestConfiguration -Session $ComputeSession -TestConfiguration $TestConfiguration
    })

}
