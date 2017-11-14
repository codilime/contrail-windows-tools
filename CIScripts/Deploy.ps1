# Deploy installs required artifacts onto already provisioned machines.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Deploy\Deployment.ps1

$Job = [Job]::new("Deploy")

# TODO: get IPs from Env
$Creds = Get-VMCreds
$ArtifactsDir = $Env:ARTIFACTS_DIR

if($Env:VM_NAMES) {
    $TestbedVMNames = $Env:VM_NAMES.Split(",")
    $Sessions = New-RemoteSessions -VMNames $TestbedVMNames -Credentials $Creds
    Deploy-Testbeds -Sessions $Sessions -ArtifactsDir $Env:ARTIFACTS_DIR
}

$Job.Done()
