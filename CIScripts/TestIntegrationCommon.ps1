. $PSScriptRoot\InitializeCIScript.ps1
. $PSScriptRoot\Common.ps1
. $PSScriptRoot\VMUtils.ps1
. $PSScriptRoot\RunTests.ps1
. $PSScriptRoot\Job.ps1
$Job = [Job]::new("Deploy and test")

$ArtifactsDir = $Env:ARTIFACTS_DIR

# TODO: We will have a single script with multiple pipelines. This variable will be
# set to different values in different pipelines (deploy-devenv vs test-integration)
$Env:SHOULD_RUN_TESTS = $true

# TODO: remove when jenkins jobs are updated
$Env:DEPLOY_METHOD = "Legacy"

$TestbedSessions = $null
$TestbedVMNames = $null

if($Env:DEPLOY_METHOD -eq "Legacy") {
    . $PSScriptRoot\Deployment\LegacyDeploy.ps1
    $TestbedSessions, $TestbedVMNames = Deploy-Legacy -VMsNeeded 2 -IsReleaseMode $ReleaseModeBuild
} elseif($Env:DEPLOY_METHOD -eq "Ansible") {
    . $PSScriptRoot\Deployment\AnsibleDeploy.ps1
    $IPs = Deploy-Ansible
    $TestbedSessions = New-RemoteSessions -VMNames $IPs -Credentials $Creds
    Provision-Testbeds -Sessions $TestbedSessions -ArtifactsDir $ArtifactsDir
} else {
    throw "Unsupported deploy method. Must be either Legacy or Ansible."
}

if($Env:SHOULD_RUN_TESTS) {
    Run-Tests -Sessions $TestbedSessions
} else {
    Write-Output "Won't run tests."
}

if($Env:DEPLOY_METHOD -eq "Legacy") {
    . $PSScriptRoot\Deployment\LegacyDeploy.ps1
    Teardown-Legacy -VMNames $TestbedVMNames
} elseif($Env:DEPLOY_METHOD -eq "Ansible") {
    . $PSScriptRoot\Deployment\AnsibleDeploy.ps1
    Teardown-Ansible
}

$Job.Done()
