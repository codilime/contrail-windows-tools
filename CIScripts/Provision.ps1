# Provision spawns testbeds using PowerCLI from prepared templates.

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Provision\ProvisionPowerCLI.ps1

$Job = [Job]::new("Provision")

# TODO: $IsReleaseMode
$IsReleaseMode = $false # false for now

$TestbedSessions, $TestbedVMNames = Provision-PowerCLI -VMsNeeded 2 -IsReleaseMode $IsReleaseMode

$Job.Done()
