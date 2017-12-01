# Additional logic for builds triggered from Gerrit

. $PSScriptRoot\..\Common\DeferExcept.ps1

function Set-GerritEnvVars {
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

function Merge-GerritPatchset {
    # merge the patchset and exit on merge failure

    $MapRepoToDirectory = @{
        "contrail-controller" = "controller";
        "contrail-sandesh" = "tools/sandesh";
        "contrail-build" = "tools/build";
        "contrail-vrouter" = "vrouter";
        "contrail-generateDS" = "tools/generateDS"
    }

    Write-Output "Running Gerrit-trigger patchset merging..."
    Push-Location $MapRepoToDirectory[$Env:PROJECT]
    DeferExcept({
        git fetch -q origin $Env:GERRIT_REFSPEC
    })
    DeferExcept({
        git config user.email "you@example.com"
    })
    DeferExcept({
        git config --global user.name "Your Name"
    })
    DeferExcept({
        git merge FETCH_HEAD
    })
    if ($LastExitCode -ne 0) {
        Write-Output "Patchset merging failed."
        Exit 1
    }
    Pop-Location
}

