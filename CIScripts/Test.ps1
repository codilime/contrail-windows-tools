. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Test\TestRunner.ps1

$Job = [Job]::new("Test")

echo $Env:VM_USERNAME
$Creds = Get-VMCreds
$TestbedVMNames = $Env:VM_NAMES.Split(",")
$Sessions = New-RemoteSessions -VMNames $TestbedVMNames -Credentials $Creds

if($Sessions) {
    Run-Tests -Sessions $Sessions
}

$Job.Done()
