# Build builds all Windows Compute components.

Param ([Parameter(Mandatory = $false)] [string] $DriverRepoURL      =$Env:DRIVER_REPO_URL,
       [Parameter(Mandatory = $false)] [string] $DriverBranch       =$Env:DRIVER_BRANCH,
       [Parameter(Mandatory = $false)] [string] $ToolsRepoURL       =$Env:TOOLS_REPO_URL,
       [Parameter(Mandatory = $false)] [string] $ToolsBranch        =$Env:TOOLS_BRANCH,
       [Parameter(Mandatory = $false)] [string] $SandeshRepoURL     =$Env:SANDESH_REPO_URL,
       [Parameter(Mandatory = $false)] [string] $SandeshRepoURL     =$Env:SANDESH_BRANCH,
       [Parameter(Mandatory = $false)] [string] $GenerateDSRepoURL  =$Env:GENERATEDS_REPO_URL,
       [Parameter(Mandatory = $false)] [string] $GenerateDSRepoURL  =$Env:GENERATEDS_BRANCH,
       [Parameter(Mandatory = $false)] [string] $VRouterRepoURL     =$Env:VROUTER_REPO_URL,
       [Parameter(Mandatory = $false)] [string] $VRouterRepoURL     =$Env:VROUTER_BRANCH,
       [Parameter(Mandatory = $false)] [string] $WindowsStubsRepoURL=$Env:WINDOWSSTUBS_REPO_URL,
       [Parameter(Mandatory = $false)] [string] $WindowsStubsRepoURL=$Env:WINDOWSSTUBS_BRANCH,
       [Parameter(Mandatory = $false)] [string] $ControllerRepoURL  =$Env:CONTROLLER_REPO_URL,
       [Parameter(Mandatory = $false)] [string] $ControllerRepoURL  =$Env:CONTROLLER_BRANCH,

       [Parameter(Mandatory = $false)] [string] $ThirdPartyCachePath    =$Env:THIRD_PARTY_CACHE_PATH,
       [Parameter(Mandatory = $false)] [string] $DriverSrcPath          =$Env:DRIVER_SRC_PATH,
       [Parameter(Mandatory = $false)] [string] $VSSetupEnvScriptPath   =$Env:VS_SETUP_ENV_SCRIPT_PATH,

       [Parameter(Mandatory = $false)] [string] $IsReleaseMode  =$Env:BUILD_IN_RELEASE_MODE,

       [Parameter(Mandatory = $false)] [string] $SigntoolPath       =$Env:SIGNTOOL_PATH,
       [Parameter(Mandatory = $false)] [string] $CertPath           =$Env:CERT_PATH,
       [Parameter(Mandatory = $false)] [string] $CertPasswordPath   =$Env:CERT_PASSWORD_FILE_PATH)

. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Build\BuildFunctions.ps1

$Repos = @(
    [Repo]::new($DriverRepoURL, $DriverBranch, "src/github.com/codilime/contrail-windows-docker", "master"),
    [Repo]::new($ToolsRepoURL, $ToolsBranch, "tools/build/", "windows"),
    [Repo]::new($SandeshRepoURL, $SandeshBranch, "tools/sandesh/", "windows"),
    [Repo]::new($GenerateDSRepoURL, $GenerateDSBranch, "tools/generateDS/", "windows"),
    [Repo]::new($VRouterRepoURL, $VRouterBranch, "vrouter/", "windows"),
    [Repo]::new($WindowsStubsRepoURL, $WindowsStubsBranch, "windows/", "windows"),
    [Repo]::new($ControllerRepoURL, $ControllerBranch, "controller/", "windows3.1")
)

$Job = [Job]::new("Build")

Clone-Repos -Repos $Repos
Prepare-BuildEnvironment -ThirdPartyCache $ThirdPartyCachePath `
                         -VSSetupEnvScriptPath $VSSetupEnvScriptPath

$ReleaseMode = [bool]::Parse($IsReleaseMode)

$DockerDriverOutputDir = "output/docker_driver"
$vRouterOutputDir = "output/vrouter"
$AgentOutputDir = "output/agent"

New-Item -ItemType directory -Path $DockerDriverOutputDir
New-Item -ItemType directory -Path $vRouterOutputDir
New-Item -ItemType directory -Path $AgentOutputDir

Invoke-DockerDriverBuild -DriverSrcPath $DriverSrcPath `
                         -SigntoolPath $SigntoolPath `
                         -CertPath $CertPath `
                         -CertPasswordFilePath $CertPasswordPath `
                         -OutputPath $DockerDriverOutputDir

Invoke-ExtensionBuild -ThirdPartyCache $ThirdPartyCachePath `
                      -SigntoolPath $SigntoolPath `
                      -CertPath $CertPath `
                      -CertPasswordFilePath $CertPasswordPath `
                      -ReleaseMode $ReleaseMode `
                      -OutputPath $vRouterOutputDir

Invoke-AgentBuild -ThirdPartyCache $ThirdPartyCachePath `
                  -SigntoolPath $SigntoolPath `
                  -CertPath $CertPath `
                  -CertPasswordFilePath $CertPasswordPath `
                  -ReleaseMode $ReleaseMode `
                  -OutputPath $AgentOutputDir

$Job.Done()
