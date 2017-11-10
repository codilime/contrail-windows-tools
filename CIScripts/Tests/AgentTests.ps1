$DefineTestIfGTestOutputSuggestsThatAllTestsHavePassed = {
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
}

function Run-Test {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [String] $TestExecutable)
    Write-Host "===> Agent tests: running $TestExecutable..."
    $Res = Invoke-Command -Session $Session -ScriptBlock {
        $Res = Invoke-Command -ScriptBlock {
            $ErrorActionPreference = "SilentlyContinue"
            Set-Location C:\Artifacts
            $TestOutput = Invoke-Expression "C:\Artifacts\$using:TestExecutable --config C:\Artifacts\vnswa_cfg.ini"
            Write-Host $TestOutput

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

        return $Res
    }
    if ($Res -eq 0) {
        Write-Host "        Succeeded."
    } else {
        Write-Host "        Failed (exit code: $Res)."
    }
    return $Res
}

function Test-Agent {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        Write-Host "===> Agent tests: setting up an environment."
        $Res = Invoke-Command -Session $Session -ScriptBlock {
            $env:Path += ";C:\Program Files\Juniper Networks\Agent"
        }
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Invoke-Command -Session $Session -ScriptBlock $DefineTestIfGTestOutputSuggestsThatAllTestsHavePassed
        Invoke-Command -Session $Session -ScriptBlock {
            $TestConfiguration = $Using:TestConfiguration

            # Those env vars are used by agent tests for determining timeout's threshold
            # They were copied from Linux unit test job
            $Env:TASK_UTIL_WAIT_TIME = 10000
            $Env:TASK_UTIL_RETRY_COUNT = 6000

            $ConfigurationFile = "C:\Artifacts\vnswa_cfg.ini"
            $Configuration = Get-Content $ConfigurationFile
            $VirtualInterfaceName = (Get-NetAdapter -Name $TestConfiguration.VHostName).IfName
            $PhysicalInterfaceName = (Get-NetAdapter -Name $TestConfiguration.AdapterName).IfName
            $Configuration = $Configuration -replace "name=.*", "name=$VirtualInterfaceName"
            $Configuration = $Configuration -replace "physical_interface=.*", "physical_interface=$PhysicalInterfaceName"
            Set-Content $ConfigurationFile $Configuration
        }

        $Res = 0
        $AgentTextExecutables = Get-ChildItem .\output\agent | Where-Object {$_.Name -match '^[\W\w]*test[\W\w]*.exe$'}
        $AgentTextExecutables += Get-ChildItem .\output\agent | Where-Object {$_.Name -match '^ifmap_[\W\w]*.exe$'}
        $AgentTextExecutables = $AgentTextExecutables | Select -Unique

        Foreach ($TestExecutable in $AgentTextExecutables) {
            $TestRes = Run-Test -Session $Session -TestExecutable $TestExecutable
            if ($TestRes -ne 0) {
                $Res = 1
            }
        }

        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration | Out-Null
        Write-Host "===> Agent tests: environment has been cleaned up."
        if ($Res -eq 0) {
            Write-Host "===> Agent tests: all tests succeeded."
        } else {
            Throw "===> Agent tests: some tests failed."
        }
    })
}
