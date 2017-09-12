class Repo {
    [string] $Url;
    [string] $Branch;
    [string] $Dir;
    [string] $DefaultBranch;

    Repo ([string] $Url, [string] $Branch, [string] $Dir, [string] $DefaultBranch) {
        $this.Url = $Url
        $this.Branch = $Branch
        $this.Dir = $Dir
        $this.DefaultBranch = $DefaultBranch
    }
}

function Copy-Repos {
    Param ([Parameter(Mandatory = $true, HelpMessage = "List of repos to clone")] [Repo[]] $Repos)
    
    $TimeLogger.LogAndMeasure("Cloning repositories", {
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
    })
}

function Invoke-ContrailCommonActions {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $VSSetupEnvScriptPath)
    $TimeLogger.LogAndMeasure("Sourcing VS environment variables", {
        Invoke-BatchFile "$VSSetupEnvScriptPath"
    })
    
    $TimeLogger.LogAndMeasure("Copying common third-party dependencies", {
        New-Item -ItemType Directory .\third_party
        Get-ChildItem "$ThirdPartyCache\common" -Directory |
            Where-Object{$_.Name -notlike "boost*"} |
            Copy-Item -Destination third_party\ -Recurse -Force
    })

    $TimeLogger.LogAndMeasure("Symlinking boost", {
        New-Item -Path "third_party\boost_1_62_0" -ItemType SymbolicLink -Value "$ThirdPartyCache\boost_1_62_0"
    })

    $TimeLogger.LogAndMeasure("Copying SConstruct from tools\build", {
        Copy-Item tools\build\SConstruct .
    })
}

function Set-MSISignature {
    Param ([Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $MSIPath)
    $TimeLogger.LogAndMeasure("Signing MSI", {
        $cerp = Get-Content $CertPasswordFilePath
        & $SigntoolPath sign /f $CertPath /p $cerp $MSIPath
        if ($LASTEXITCODE -ne 0) {
            throw "Signing $MSIPath failed"
        }
    })
}

function Invoke-DockerDriverBuild {
    Param ([Parameter(Mandatory = $true)] [string] $DriverSrcPath,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath)
    
    $TimeLogger.LogAndPush("Docker driver build")
    $Env:GOPATH=pwd
    $srcPath = "$Env:GOPATH/src/$DriverSrcPath"
    
    New-Item -ItemType Directory ./bin
    Push-Location bin

    $TimeLogger.LogAndMeasure("Installing test runner", {
        go get -u -v github.com/onsi/ginkgo/ginkgo
    })

    $TimeLogger.LogAndMeasure("Building driver", {
        go build -v $DriverSrcPath
    })

    $TimeLogger.LogAndMeasure("Precompiling tests", {
        $modules = @("driver", "controller", "hns", "hnsManager")
        $modules.ForEach({
            .\ginkgo.exe build $srcPath/$_
            Move-Item $srcPath/$_/$_.test ./
        })
    })

    $TimeLogger.LogAndMeasure("Copying Agent API python script", {
        Copy-Item $srcPath/scripts/agent_api.py ./
    })

    $TimeLogger.LogAndMeasure("Intalling MSI builder", {
        go get -u -v github.com/mh-cbon/go-msi
    })

    $TimeLogger.LogAndMeasure("Building MSI", {
        Push-Location $srcPath
        & "$Env:GOPATH/bin/go-msi" make --msi docker-driver.msi --arch x64 --version 0.1 --src template --out $pwd/gomsi
        Pop-Location

        Move-Item $srcPath/docker-driver.msi ./
    })
    
    Set-MSISignature -SigntoolPath $SigntoolPath -CertPath $CertPath -CertPasswordFilePath $CertPasswordFilePath -MSIPath "docker-driver.msi"

    Pop-Location

    $TimeLogger.Pop()
}

function Invoke-ExtensionBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath)

    $TimeLogger.LogAndPush("Extension build")

    $TimeLogger.LogAndMeasure("Copying Extension dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\extension\*" third_party\
        Copy-Item -Recurse third_party\cmocka vrouter\test\
    })

    
    $TimeLogger.LogAndMeasure("Building Extension and Utils", {
        scons vrouter
        if ($LASTEXITCODE -ne 0) {
            throw "Building vRouter solution failed"
        }
    })

    $vRouterMSI = "build\debug\vrouter\extension\vRouter.msi"
    $utilsMSI = "build\debug\vrouter\utils\utils.msi"
    
    Write-Host "Signing utilsMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath -CertPath $CertPath -CertPasswordFilePath $CertPasswordFilePath -MSIPath $utilsMSI
    
    Write-Host "Signing vRouterMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath -CertPath $CertPath -CertPasswordFilePath $CertPasswordFilePath -MSIPath $vRouterMSI

    $TimeLogger.Pop()
}

function Invoke-AgentBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache)

    $TimeLogger.LogAndPush("Agent build")

    $TimeLogger.LogAndMeasure("Copying Agent dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\agent\*" third_party/
    })

    $TimeLogger.LogAndMeasure("Building API", {
        scons controller/src/vnsw/contrail_vrouter_api:sdist
        if ($LASTEXITCODE -ne 0) {
            throw "Building API failed"
        }
    })

    $TimeLogger.LogAndMeasure("Building contrail-vrouter-agent.exe and .msi", {
        scons contrail-vrouter-agent.msi -j 4
        if ($LASTEXITCODE -ne 0) {
            throw "Building Agent failed"
        }
    })

    $TimeLogger.LogAndMeasure("Building tests", {
        $Tests = @()

        # TODO: Add other tests here once they are functional.
        $Tests = @("agent:test_ksync", "agent:test_vnswif", "src/ksync:ksync_test")

        $TestsString = ""
        if ($Tests.count -gt 0) {
            $TestsString = $Tests -join " "
        }
        $BuildCommand = "scons contrail-vrouter-agent.msi -j 4"
        $AgentAndTestsBuildCommand = "{0} {1}" -f "$BuildCommand", "$TestsString"
        Invoke-Expression $AgentAndTestsBuildCommand

        if ($LASTEXITCODE -ne 0) {
            throw "Building Agent and tests failed"
        }
    })

    $TimeLogger.Pop()
}

