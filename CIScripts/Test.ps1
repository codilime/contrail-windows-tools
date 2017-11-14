. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Test\TestRunner.ps1

$Job = [Job]::new("Test")

$Creds = Get-VMCreds

if($Env:VM_NAMES) {
    $TestbedVMNames = $Env:VM_NAMES.Split(",")
    $Sessions = New-RemoteSessions -VMNames $TestbedVMNames -Credentials $Creds
    Run-Tests -Sessions $Sessions
}

$Job.Done()
