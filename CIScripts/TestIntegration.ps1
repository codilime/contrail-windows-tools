. $PSScriptRoot\InitializeCIScript.ps1

# # Source Job monitoring classes
. $PSScriptRoot\Job.ps1
$Job = [Job]::new("Test-integration")

# Sourcing VM management functions
. $PSScriptRoot\VMUtils.ps1

# Setting all variables needed for New-TestbedVMs from Environment
. $PSScriptRoot\SetCommonVariablesForNewVMsFromEnv.ps1

# There are always 2 VMs created for running all tests
$VMsNeeded = 2

$VMBaseName = Get-SanitizedOrGeneratedVMName -VMName $Env:VM_NAME -RandomNamePrefix "Core-"
$VMNames = [System.Collections.ArrayList] @()
for ($i = 0; $i -lt $VMsNeeded; $i++) {
    $VMNames += $VMBaseName + "-" + $i.ToString()
}

Write-Host "Starting Testbeds:"
$VMNames.ForEach({ Write-Host $_ })

$Sessions = New-TestbedVMs -VMNames $VMNames -InstallArtifacts $true -PowerCLIScriptPath $PowerCLIScriptPath `
    -VIServerAccessData $VIServerAccessData -VMCreationSettings $VMCreationSettings -VMCredentials $VMCredentials `
    -ArtifactsDir $ArtifactsDir -DumpFilesLocation $DumpFilesLocation -DumpFilesBaseName $DumpFilesBaseName -MaxWaitVMMinutes $MaxWaitVMMinutes

Write-Host "Started Testbeds:"
$Sessions.ForEach({ Write-Host $_.ComputerName })

# Sourcing test functions
. $PSScriptRoot\Tests\Tests.ps1

$DockerNetworkConfiguration = [DockerNetworkConfiguration] @{
    TenantName = $Env:DOCKER_NETWORK_TENANT_NAME;
    NetworkName = $Env:DOCKER_NETWORK_NAME;
}

$DockerDriverConfiguration = [DockerDriverConfiguration] @{
    Username = $Env:DOCKER_DRIVER_USERNAME;
    Password = $Env:DOCKER_DRIVER_PASSWORD;
    AuthUrl = $Env:DOCKER_DRIVER_AUTH_URL;
    NetworkConfiguration = $DockerNetworkConfiguration;
}

$TestConfiguration = [TestConfiguration] @{
    ControllerIP = $Env:CONTROLLER_IP;
    ControllerHostUsername = $Env:CONTROLLER_HOST_USERNAME;
    ControllerHostPassword = $Env:CONTROLLER_HOST_PASSWORD;
    AdapterName = $Env:ADAPTER_NAME;
    VMSwitchName = "Layered " + $Env:ADAPTER_NAME;
    VHostName = "vEthernet (HNSTransparent)"
    ForwardingExtensionName = $Env:FORWARDING_EXTENSION_NAME;
    AgentConfigFilePath = "C:\Program Files\Juniper Networks\Agent\contrail-vrouter-agent.conf";
    AgentSampleConfigFilePath = "C:\Program Files\Juniper Networks\Agent\contrail-vrouter-agent.conf.sample";
    DockerDriverConfiguration = $DockerDriverConfiguration;
}

$SNATConfiguration = [SNATConfiguration] @{
    EndhostIP = $Env:SNAT_ENDHOST_IP;
    VethIP = $Env:SNAT_VETH_IP;
    GatewayIP = $Env:SNAT_GATEWAY_IP;
    ContainerGatewayIP = $Env:SNAT_CONTAINER_GATEWAY_IP;
    EndhostUsername = $Env:SNAT_ENDHOST_USERNAME;
    EndhostPassword = $Env:SNAT_ENDHOST_PASSWORD;
    DiskDir = $Env:SNAT_DISK_DIR;
    DiskFileName = $Env:SNAT_DISK_FILE_NAME;
    VMDir = $Env:SNAT_VM_DIR;
}

Test-Agent -Session $Sessions[0] -TestConfiguration $TestConfiguration
Test-ExtensionLongLeak -Session $Sessions[0] -TestDurationHours $Env:LEAK_TEST_DURATION -TestConfiguration $TestConfiguration
Test-MultiEnableDisableExtension -Session $Sessions[0] -EnableDisableCount $Env:MULTI_ENABLE_DISABLE_EXTENSION_COUNT -TestConfiguration $TestConfiguration
Test-VTestScenarios -Session $Sessions[0] -TestConfiguration $TestConfiguration
Test-TCPCommunication -Session $Sessions[0] -TestConfiguration $TestConfiguration
Test-ICMPoMPLSoGRE -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
Test-TCPoMPLSoGRE -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
# TODO: Uncomment after JW-1129
# Test-SNAT -Session $Sessions[0] -SNATConfiguration $SNATConfiguration -TestConfiguration $TestConfiguration
Test-VRouterAgentIntegration -Session1 $Sessions[0] -Session2 $Sessions[1] -TestConfiguration $TestConfiguration
Test-ComputeControllerIntegration -Session $Sessions[0] -TestConfiguration $TestConfiguration
if($Env:RUN_DRIVER_TESTS -eq "1") {
    Test-DockerDriver -Session $Sessions[0] -TestConfiguration $TestConfiguration
}

Write-Host "Removing VMs..."
Remove-TestbedVMs -VMNames $VMNames -PowerCLIScriptPath $PowerCLIScriptPath -VIServerAccessData $VIServerAccessData

$Job.Done()
