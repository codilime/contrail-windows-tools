if ($Env:ENABLE_TRACE -eq $true) {
    Set-PSDebug -Trace 1
}

# Refresh Path and PSModulePath
$Env:PSModulePath = [System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Stop script on error
$ErrorActionPreference = "Stop"

Write-Host "Sourcing VS environment variables"
Invoke-BatchFile "$Env:VS_SETUP_ENV_SCRIPT_PATH"

Write-Host "Cloning repositories"
class Repo {
    [string] $Url;
    [string] $Branch;
    [string] $Dir;

    Repo ([string] $Url, [string] $Branch, [string] $Dir) {
        $this.Url = $Url
        $this.Branch = $Branch
        $this.Dir = $Dir
    }
}

$DefaultBranch = "windows"
$Repos = @(
    [Repo]::new($Env:TOOLS_REPO_URL, $Env:TOOLS_BRANCH, "tools/build/"),
    [Repo]::new($Env:SANDESH_BRANCH, $Env:SANDESH_REPO_URL, "tools/sandesh/"),
    [Repo]::new($Env:GENERATEDS_BRANCH, $Env:GENERATEDS_REPO_URL, "tools/generateDS/"),
    [Repo]::new($Env:VROUTER_BRANCH, $Env:VROUTER_REPO_URL, "vrouter/"),
    [Repo]::new($Env:WINDOWSSTUBS_BRANCH, $Env:WINDOWSSTUBS_REPO_URL, "windows/")
)

git clone -b $Env:CONTROLLER_BRANCH $Env:CONTROLLER_REPO_URL controller/
if ($LASTEXITCODE -ne 0) {
    throw "Cloning from " + $Env:CONTROLLER_REPO_URL + " failed"
}

$Repos.ForEach({
    # If there is custom branch specified, try to clone this branch only
    if ($_.Branch -ne $DefaultBranch) {
        git clone -b $_.Branch $_.Url $_.Dir
        if ($LASTEXITCODE -ne 0) {
            throw "Cloning from " + $_.Url + " failed"
        }

        continue
    }

    # Try to clone from controller branch, then from default
    git clone -b $Env:CONTROLLER_BRANCH $_.Url $_.Dir
    if ($LASTEXITCODE -ne 0) {
        git clone -b $DefaultBranch $_.Url $_.Dir
        if ($LASTEXITCODE -ne 0) {
            throw "Cloning from " + $_.Url + " failed"
        }
    }
})

Write-Host "Copying third-party dependencies"
New-Item -ItemType Directory ./third_party
Copy-Item -Recurse "$Env:THIRD_PARTY_CACHE_PATH\agent\*" third_party/
Copy-Item -Recurse "$Env:THIRD_PARTY_CACHE_PATH\common\*" third_party/

Copy-Item tools/build/SConstruct ./

Write-Host "Building Agent, MSI and API"
scons contrail-vrouter-agent contrail-vrouter-agent.msi controller/src/vnsw/contrail_vrouter_api:sdist
