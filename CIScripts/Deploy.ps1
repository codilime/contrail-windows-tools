# Deploy installs required artifacts onto already provisioned machines.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Common\VMUtils.ps1
. $PSScriptRoot\Deploy\Deployment.ps1

$Job = [Job]::new("Deploy")

# TODO: get IPs from Env
$Creds = Get-VMCreds
$ArtifactsDir = $Env:ARTIFACTS_DIR

if($Env:TESTBED_HOSTNAMES) {
    $Testbeds = $Env:TESTBED_HOSTNAMES.Split(",")
    $Sessions = New-RemoteSessions -VMNames $Testbeds -Credentials $Creds
    Deploy-Testbeds -Sessions $Sessions -ArtifactsDir $Env:ARTIFACTS_DIR
}

$Job.Done()
