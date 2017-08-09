if ($Env:ENABLE_TRACE -eq $true) {
    Set-PSDebug -Trace 1
}

# Refresh Path and PSModulePath
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$Env:PSModulePath = [System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine")

# Stop script on error
$ErrorActionPreference = "Stop"

Write-Host "Sourcing VS environment variables"
Invoke-BatchFile "$Env:VS_SETUP_ENV_SCRIPT_PATH"

Write-Host "Cloning repositories"
class Repo {
    [string] $Url;
    [string] $Branch;
    [string] $DefaultBranch;
    [string] $Dir;

    Repo ([string] $Url, [string] $Branch, [string] $Dir, [string] $DefaultBranch) {
        $this.Url = $Url
        $this.Branch = $Branch
        $this.Dir = $Dir
        $this.DefaultBranch = $DefaultBranch
    }
}

$Repos = @(
    [Repo]::new($Env:DRIVER_REPO_URL, $Env:DRIVER_REPO_BRANCH, "src/github.com/codilime/contrail-windows-docker" ,"master"),
    [Repo]::new($Env:TOOLS_REPO_URL, $Env:TOOLS_BRANCH, "tools/build/", "windows"),
    [Repo]::new($Env:SANDESH_REPO_URL, $Env:SANDESH_BRANCH, "tools/sandesh/", "windows"),
    [Repo]::new($Env:GENERATEDS_REPO_URL, $Env:GENERATEDS_BRANCH, "tools/generateDS/", "windows"),
    [Repo]::new($Env:VROUTER_REPO_URL, $Env:VROUTER_BRANCH, "vrouter/", "windows"),
    [Repo]::new($Env:WINDOWSSTUBS_REPO_URL, $Env:WINDOWSSTUBS_BRANCH, "windows/", "windows"),
    [Repo]::new($Env:CONTROLLER_REPO_URL, $Env:CONTROLLER_BRANCH, "controller/", "windows3.1")
)

$CustomBranches = @($Repos.Where({ $_.Branch -ne $_.DefaultBranch }) | Select-Object -ExpandProperty Branch -Unique)
$Repos.ForEach({
    # If there is only one unique custom branch provided, at first try to use it for all repos.
    # Otherwise, use branch specific for this repo.
    $CustomMultiBranch = $(if ($CustomBranches.Count -eq 1) { $CustomBranches[0] } else { $_.Branch })

    Write-Host $("Cloning " +  $_.Url + " from branch: " + $CustomMultiBranch)
    git clone -b $CustomMultiBranch $_.Url $_.Dir

    if ($LASTEXITCODE -ne 0) {
        Write-Host $("Cloning " +  $_.Url + " from branch: " + $_.Branch)
        git clone -b $_.Branch $_.Url $_.Dir

        if ($LASTEXITCODE -ne 0) {
            throw "Cloning from " + $_.Url + " failed"
        }
    }
})

& .\Tools\CIScripts\BuildDockerDriver.ps1
& .\Tools\CIScripts\BuildContrail.ps1
