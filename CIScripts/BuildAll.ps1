. $PSScriptRoot\InitializeCIScript.ps1
. $PSScriptRoot\BuildFunctions.ps1
. $PSScriptRoot\Job.ps1

$ToolsAllowBranchOverride = $true

# Additional logic for builds triggered from Gerrit
if (Test-Path Env:GERRIT_CHANGE_ID)  {

    #$Env:DRIVER_REPO_URL =
    #$Env:WINDOWSSTUBS_REPO_URL =
    $Env:TOOLS_REPO_URL = "https://$Env:GERRIT_HOST/Juniper/contrail-build"
    $Env:SANDESH_REPO_URL = "https://$Env:GERRIT_HOST/Juniper/contrail-sandesh"
    $Env:GENERATEDS_REPO_URL = "https://$Env:GERRIT_HOST/Juniper/contrail-generateDS"
    $Env:VROUTER_REPO_URL = "https://$Env:GERRIT_HOST/Juniper/contrail-vrouter"
    $Env:CONTROLLER_REPO_URL = "https://$Env:GERRIT_HOST/Juniper/contrail-controller"

    if ($Env:GERRIT_PROJECT.StartsWith('Juniper/')) {
        $Env:PROJECT = $Env:GERRIT_PROJECT.split('/')[1]
    } else {
        $Env:PROJECT = $Env:GERRIT_PROJECT
    }

    if ($Env:PROJECT -eq "contrail-controller") {
        $Env:CONTROLLER_BRANCH = $Env:GERRIT_BRANCH
    } elseif ($Env:PROJECT -eq "contrail-vrouter") {
        $Env:CONTROLLER_BRANCH = $Env:GERRIT_BRANCH
    } elseif ($Env:PROJECT -eq "contrail-sandesh") {
        $Env:SANDESH_BRANCH = $Env:GERRIT_BRANCH
    } elseif ($Env:PROJECT -eq "contrail-build") {
        $Env:TOOLS_BRANCH = $Env:GERRIT_BRANCH
    }
    # always use the windows branch for the contrail-tools repo when running from Gerrit
    $ToolsAllowBranchOverride = $true
}

$repo_map = @{
    "contrail-controller" = "controller";
    "contrail-sandesh" = "tools/sandesh";
    "contrail-build" = "tools/build";
    "contrail-vrouter" = "vrouter";
    "contrail-generateDS" = "tools/generateDS"
}

$Repos = @(
    [Repo]::new($Env:DRIVER_REPO_URL, $Env:DRIVER_BRANCH, "src/github.com/codilime/contrail-windows-docker", "master"),
    [Repo]::new($Env:TOOLS_REPO_URL, $Env:TOOLS_BRANCH, "tools/build/", "windows", $ToolsAllowBranchOverride),
    [Repo]::new($Env:SANDESH_REPO_URL, $Env:SANDESH_BRANCH, "tools/sandesh/", "windows"),
    [Repo]::new($Env:GENERATEDS_REPO_URL, $Env:GENERATEDS_BRANCH, "tools/generateDS/", "windows"),
    [Repo]::new($Env:VROUTER_REPO_URL, $Env:VROUTER_BRANCH, "vrouter/", "windows"),
    [Repo]::new($Env:WINDOWSSTUBS_REPO_URL, $Env:WINDOWSSTUBS_BRANCH, "windows/", "windows"),
    [Repo]::new($Env:CONTROLLER_REPO_URL, $Env:CONTROLLER_BRANCH, "controller/", "windows3.1")
)

$Job = [Job]::new("Build-all")

Copy-Repos -Repos $Repos

# Additional logic for builds triggered from Gerrit
# merge the patchset and exit on merge failure
if (Test-Path Env:GERRIT_CHANGE_ID) {
    Write-Output "Running Gerrit-trigger patchset merging..."
    pushd $repo_map[$Env:PROJECT]
    git fetch origin $Env:GERRIT_REFSPEC
    git config user.email "you@example.com"
    git config --global user.name "Your Name"
    git merge FETCH_HEAD
    if ($LastExitCode -ne 0) {
        Write-Output "Patchset merging failed."
        Exit 1
    }
    popd
}

Invoke-ContrailCommonActions -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH -VSSetupEnvScriptPath $Env:VS_SETUP_ENV_SCRIPT_PATH

$ReleaseMode = [bool]::Parse($Env:BUILD_IN_RELEASE_MODE)

$DockerDriverOutputDir = "output/docker_driver"
$vRouterOutputDir = "output/vrouter"
$AgentOutputDir = "output/agent"

New-Item -ItemType directory -Path $DockerDriverOutputDir
New-Item -ItemType directory -Path $vRouterOutputDir
New-Item -ItemType directory -Path $AgentOutputDir

Invoke-DockerDriverBuild -DriverSrcPath $Env:DRIVER_SRC_PATH -SigntoolPath $Env:SIGNTOOL_PATH -CertPath $Env:CERT_PATH -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH -OutputPath $DockerDriverOutputDir
Invoke-ExtensionBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH -SigntoolPath $Env:SIGNTOOL_PATH -CertPath $Env:CERT_PATH -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH -ReleaseMode $ReleaseMode -OutputPath $vRouterOutputDir
Invoke-AgentBuild -ThirdPartyCache $Env:THIRD_PARTY_CACHE_PATH -SigntoolPath $Env:SIGNTOOL_PATH -CertPath $Env:CERT_PATH -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH -ReleaseMode $ReleaseMode -OutputPath $AgentOutputDir

$Job.Done()
