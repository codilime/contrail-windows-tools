. $PSScriptRoot\..\Common\DeferExcept.ps1

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

function Clone-Repos {
    Param ([Parameter(Mandatory = $true, HelpMessage = "List of repos to clone")] [Repo[]] $Repos)

    $Job.Step("Cloning repositories", {
        $CustomBranches = @($Repos.Where({ $_.Branch -ne $_.DefaultBranch }) |
                            Select-Object -ExpandProperty Branch -Unique)
        $Repos.ForEach({
            # If there is only one unique custom branch provided, at first try to use it for all repos.
            # Otherwise, use branch specific for this repo.
            $CustomMultiBranch = $(if ($CustomBranches.Count -eq 1) { $CustomBranches[0] } else { $_.Branch })

            Write-Host $("Cloning " +  $_.Url + " from branch: " + $CustomMultiBranch)

            # We must use -q (quiet) flag here, since git clone prints to stderr and tries to do some real-time
            # command line magic (like updating cloning progress). Powershell command in Jenkinsfile
            # can't handle it and throws a Write-ErrorException.
            try {
                DeferExcept({
                    git clone -q -b $CustomMultiBranch $_.Url $_.Dir
                })
            } finally {
                if ($LASTEXITCODE -ne 0) {
                    Write-Host $("Cloning " +  $_.Url + " from branch: " + $_.Branch)
                    DeferExcept({
                        git clone -q -b $_.Branch $_.Url $_.Dir
                    })

                    if ($LASTEXITCODE -ne 0) {
                        throw "Cloning from " + $_.Url + " failed"
                    }
                }
            }

        })
    })
}

function Prepare-BuildEnvironment {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache)
    $Job.Step("Copying common third-party dependencies", {
        New-Item -ItemType Directory .\third_party
        Get-ChildItem "$ThirdPartyCache\common" -Directory |
            Where-Object{$_.Name -notlike "boost*"} |
            Copy-Item -Destination third_party\ -Recurse -Force
    })

    $Job.Step("Symlinking boost", {
        New-Item -Path "third_party\boost_1_62_0" -ItemType SymbolicLink -Value "$ThirdPartyCache\boost_1_62_0"
    })

    $Job.Step("Copying SConstruct from tools\build", {
        Copy-Item tools\build\SConstruct .
    })
}

function Set-MSISignature {
    Param ([Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $MSIPath)
    $Job.Step("Signing MSI", {
        $cerp = Get-Content $CertPasswordFilePath
        DeferExcept({
            & $SigntoolPath sign /f $CertPath /p $cerp $MSIPath
        })
        if ($LASTEXITCODE -ne 0) {
            throw "Signing $MSIPath failed"
        }
    })
}

function Invoke-DockerDriverBuild {
    Param ([Parameter(Mandatory = $true)] [string] $DriverSrcPath,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $true)] [string] $LogsPath)

    $Job.PushStep("Docker driver build")
    $GoPath = $Env:GOPATH
    if (-not $GoPath) {
        $GoPath = pwd
        $Env:GOPATH = $GoPath
    }
    $srcPath = "$GoPath/src/$DriverSrcPath"

    New-Item -ItemType Directory ./bin

    $Job.Step("Installing dependency management tool for Go ", {
        DeferExcept({
            go get -u -v github.com/golang/dep/cmd/dep
        })
    })

    Push-Location $srcPath
    $Job.Step("Fetch third party packages ", {
        DeferExcept({
            & "$GoPath\bin\dep.exe" ensure -v
        })
    })
    Pop-Location

    $Job.Step("Contrail-go-api source code generation", {
        DeferExcept({
            python tools/generateds/generateDS.py -q -f `
                                                  -o $srcPath/vendor/github.com/Juniper/contrail-go-api/types/ `
                                                  -g golang-api controller/src/schema/vnc_cfg.xsd
        })
    })

    Push-Location bin

    $Job.Step("Installing test runner", {
        DeferExcept({
            go get -u -v github.com/onsi/ginkgo/ginkgo
        })
    })

    $Job.Step("Building driver", {
        DeferExcept({
            go build -v $DriverSrcPath
        })
    })

    $Job.Step("Precompiling tests", {
        $modules = @("driver", "controller", "hns", "hnsManager")
        $modules.ForEach({
            DeferExcept({
                .\ginkgo.exe build $srcPath/$_
            })
            Move-Item $srcPath/$_/$_.test ./
        })
    })

    $Job.Step("Copying Agent API python script", {
        Copy-Item $srcPath/scripts/agent_api.py ./
    })

    $Job.Step("Intalling MSI builder", {
        DeferExcept({
            go get -u -v github.com/mh-cbon/go-msi
        })
    })

    $Job.Step("Building MSI", {
        Push-Location $srcPath
        DeferExcept({
            & "$GoPath/bin/go-msi" make --msi docker-driver.msi --arch x64 --version 0.1 `
                                        --src template --out $pwd/gomsi
        })
        Pop-Location

        Move-Item $srcPath/docker-driver.msi ./
    })

    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath "docker-driver.msi"

    Pop-Location

    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item bin/* $OutputPath
    })

    $Job.PopStep()
}

function Invoke-ExtensionBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $true)] [string] $LogsPath,
           [Parameter(Mandatory = $false)] [bool] $ReleaseMode = $false)

    $Job.PushStep("Extension build")

    $Job.Step("Copying Extension dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\extension\*" third_party\
        Copy-Item -Recurse third_party\cmocka vrouter\test\
    })

    $BuildMode = $(if ($ReleaseMode) { "production" } else { "debug" })

    $Job.Step("Building Extension and Utils", {
        $BuildModeOption = "--optimization=" + $BuildMode
        DeferExcept({
            $Env:cerp = Get-Content $CertPasswordFilePath
            scons $BuildModeOption vrouter | Tee-Object -FilePath $LogsDir/vrouter_build.log
        })
        if ($LASTEXITCODE -ne 0) {
            throw "Building vRouter solution failed"
        }
    })

    $vRouterRoot = "build\{0}\vrouter" -f $BuildMode
    $vRouterMSI = "$vRouterRoot\extension\vRouter.msi"
    $utilsMSI = "$vRouterRoot\utils\utils.msi"
    $vTestPath = "$vRouterRoot\utils\vtest\"

    Write-Host "Signing utilsMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $utilsMSI

    Write-Host "Signing vRouterMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $vRouterMSI

    $Job.Step("Copying artifacts to $OutputPath", {
        Copy-Item $utilsMSI $OutputPath -Recurse -Container
        Copy-Item $vRouterMSI $OutputPath -Recurse -Container
        Copy-Item $CertPath $OutputPath -Recurse -Container
        Copy-Item $vTestPath "$OutputPath\utils\vtest" -Recurse -Container
    })

    $Job.PopStep()
}

function Test-IfGTestOutputSuggestsThatAllTestsHavePassed {
    Param ([Parameter(Mandatory = $true)] [Object[]] $TestOutput)
    $NumberOfTests = -1
    Foreach ($Line in $TestOutput) {
        if ($Line -match "\[==========\] (?<HowManyTests>[\d]+) test[s]? from [\d]+ test [\w]* ran[.]*") {
            $NumberOfTests = $matches.HowManyTests
        }
        if ($Line -match "\[  PASSED  \] (?<HowManyTestsHavePassed>[\d]+) test[.]*" -and $NumberOfTests -ge 0) {
            return $($matches.HowManyTestsHavePassed -eq $NumberOfTests)
        }
    }
    return $False
}

function Run-Test {
    Param ([Parameter(Mandatory = $true)] [String] $TestExecutable)
    Write-Host "===> Agent tests: running $TestExecutable..."
    $Res = Invoke-Command -ScriptBlock {
        $ErrorActionPreference = "SilentlyContinue"
        $TestOutput = Invoke-Expression $TestExecutable
        $TestOutput.ForEach({ Write-Host $_ })

        # This is a workaround for the following bug:
        # https://bugs.launchpad.net/opencontrail/+bug/1714205
        # Even if all tests actually pass, test executables can sometimes
        # return non-zero exit code.
        # TODO: It should be removed once the bug is fixed (JW-1110).
        $SeemsLegitimate = Test-IfGTestOutputSuggestsThatAllTestsHavePassed -TestOutput $TestOutput
        if($LASTEXITCODE -eq 0 -or $SeemsLegitimate) {
            return 0
        } else {
            return $LASTEXITCODE
        }
    }

    if ($Res -eq 0) {
        Write-Host "        Succeeded."
    } else {
        Write-Host "        Failed (exit code: $Res)."
    }
    return $Res
}

function Invoke-AgentBuild {
    Param ([Parameter(Mandatory = $true)] [string] $ThirdPartyCache,
           [Parameter(Mandatory = $true)] [string] $SigntoolPath,
           [Parameter(Mandatory = $true)] [string] $CertPath,
           [Parameter(Mandatory = $true)] [string] $CertPasswordFilePath,
           [Parameter(Mandatory = $true)] [string] $OutputPath,
           [Parameter(Mandatory = $true)] [string] $LogsPath,
           [Parameter(Mandatory = $false)] [bool] $ReleaseMode = $false)

    $Job.PushStep("Agent build")

    $Job.Step("Copying Agent dependencies", {
        Copy-Item -Recurse "$ThirdPartyCache\agent\*" third_party/
    })

    $BuildMode = $(if ($ReleaseMode) { "production" } else { "debug" })
    $BuildModeOption = "--optimization=" + $BuildMode

    $Job.Step("Building API", {
        DeferExcept({
            scons $BuildModeOption controller/src/vnsw/contrail_vrouter_api:sdist | Tee-Object -FilePath $LogsDir/build_api.log
        })
        if ($LASTEXITCODE -ne 0) {
            throw "Building API failed"
        }
    })

    $Job.Step("Building contrail-vrouter-agent.exe, .msi and tests", {
        $Tests = @(
            "agent:test_ksync",
            "src/ksync:ksync_test",
            "src/dns:dns_bind_test",
            "src/dns:dns_config_test",
            "src/dns:dns_mgr_test",
            "controller/src/schema:test",
            "src/xml:xml_test",
            "controller/src/xmpp:test",
            "src/base:libtask_test",
            "src/base:bitset_test",
            "src/base:index_allocator_test",
            "src/base:dependency_test",
            "src/base:label_block_test",
            "src/base:queue_task_test",
            "src/base:subset_test",
            "src/base:patricia_test",
            "src/base:boost_US_test"

            # oper
            "agent:test_agent_sandesh",
            "agent:test_config_manager",
            "agent:test_intf",
            "agent:test_intf_policy",
            "agent:test_find_scale",
            "agent:test_logical_intf",
            "agent:test_vrf_assign",
            "agent:test_inet_interface",
            "agent:test_aap6",
            "agent:test_ipv6",
            "agent:test_forwarding_class",
            "agent:test_qos_config",
            "agent:test_oper_xml",
            "agent:ifmap_dependency_manager_test",
            "agent:test_physical_devices"
        )

        $TestsString = ""
        if ($Tests.count -gt 0) {
            $TestsString = $Tests -join " "
        }
        $AgentAndTestsBuildCommand = "scons -j 4 {0} contrail-vrouter-agent.msi {1}" `
                                     -f "$BuildModeOption", "$TestsString"
        DeferExcept({
            Invoke-Expression $AgentAndTestsBuildCommand | Tee-Object -FilePath $LogsDir/build_agent_and_tests.log
        })

        if ($LASTEXITCODE -ne 0) {
            throw "Building Agent and tests failed"
        }
    })

    $rootBuildDir = "build\$BuildMode"

    $Job.Step("Running tests", {
        $backupPath = $Env:Path
        $Env:Path += ";" + $(Get-Location).Path + "\build\bin"

        # Those env vars are used by agent tests for determining timeout's threshold
        # They were copied from Linux unit test job
        $Env:TASK_UTIL_WAIT_TIME = 10000
        $Env:TASK_UTIL_RETRY_COUNT = 6000

        $TestsFolders = @(
            "base\test",
            "dns\test",
            "ksync\test",
            "schema\test",
            "vnsw\agent\cmn\test",
            "vnsw\agent\oper\test",
            "vnsw\agent\test",
            "xml\test",
            "xmpp\test"
        ) | % { "$rootBuildDir\$_" }

        $AgentExecutables = Get-ChildItem -Recurse $TestsFolders | Where-Object {$_.Name -match '.*\.exe$'}
        Foreach ($TestExecutable in $AgentExecutables) {
            $TestRes = Run-Test -TestExecutable $TestExecutable.FullName
            if ($TestRes -ne 0) {
                throw "Running agent tests failed"
            }
        }

        $Env:Path = $backupPath
    })

    $agentMSI = "$rootBuildDir\vnsw\agent\contrail\contrail-vrouter-agent.msi"

    Write-Host "Signing agentMSI"
    Set-MSISignature -SigntoolPath $SigntoolPath `
                     -CertPath $CertPath `
                     -CertPasswordFilePath $CertPasswordFilePath `
                     -MSIPath $agentMSI

    $Job.Step("Copying artifacts to $OutputPath", {
        $vRouterApiPath = "build\noarch\contrail-vrouter-api\dist\contrail-vrouter-api-1.0.tar.gz"
        $testInisPath = "controller\src\vnsw\agent\test"
        $libxmlPath = "build\bin\libxml2.dll"

        Copy-Item $vRouterApiPath $OutputPath -Recurse -Container
        Copy-Item $agentMSI $OutputPath -Recurse -Container
        Copy-Item -Path $testInisPath -Include "*.ini" -Destination $OutputPath
        Copy-Item $libxmlPath $OutputPath -Recurse -Container

        # This copies all test executables
        Copy-Item -Path $rootBuildDir -Recurse -Include "*.exe" -Destination $OutputPath -Container
    })

    $Job.PopStep()
}

