
. $PSScriptRoot\Common.ps1

# Source Job monitoring classes
. $PSScriptRoot\Job.ps1
$Job = [Job]::new("Deploy and test")

. $PSScriptRoot\VMUtils.ps1
. $PSScriptRoot\RunTests.ps1

$ArtifactsDir = $Env:ARTIFACTS_DIR

# TODO: for now.
$Env:SHOULD_RUN_TESTS = $true
$Env:DEPLOY_METHOD = "Legacy"

$TestbedSessions = $null
$TestbedVMNames = $null

if($Env:DEPLOY_METHOD == "Legacy") {
    . $PSScriptRoot\Deployment\LegacyDeploy.ps1
    $TestbedSessions, $TestbedVMNames = Deploy-Legacy -VMsNeeded 2 -IsReleaseMode $ReleaseModeBuild
} else if($Env:DEPLOY_METHOD == "Ansible") {
    . $PSScriptRoot\Deployment\AnsibleDeploy.ps1
    $IPs = Deploy-Ansible
    # TODO ^^^^^^^^^^^^^^
    $TestbedSessions = New-RemoteSessions -VMNames $IPs -Credentials $Creds
    Provision-Testbeds -Sessions $TestbedSessions -ArtifactsDir $ArtifactsDir
}

if($Env:SHOULD_RUN_TESTS) {
    Run-Tests -Sessions $TestbedSessions -ArtifactsDir $ArtifactsDir
} else {
    Write-Output "Won't run tests."
}

if($Env:DEPLOY_METHOD == "Legacy") {
    . $PSScriptRoot\Deployment\LegacyDeploy.ps1
    Teardown-Legacy -VMNames $TestbedVMNames
}

$Job.Done()
