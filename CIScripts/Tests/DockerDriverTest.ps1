function Test-DockerDriver {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    Write-Host "Running Docker Driver test."

    $TestFailed = $false
    $TestsPath = "C:\Program Files\Juniper Networks\"

    $TestFiles = @("controller", "hns", "hnsManager", "driver")
    foreach ($TestFile in $TestFiles) {
        $TestFilePath = ".\" + $TestFile + ".test.exe"
        $Command = @($TestFilePath, "--ginkgo.noisyPendings", "--ginkgo.failFast", "--ginkgo.progress", "--ginkgo.v", "--ginkgo.trace")
        if ($TestFilePath -ne "controller") {
            $Command += ("--netAdapter=" + $TestConfiguration.AdapterName)
        }
        $Command = $Command -join " "

        $Res = Invoke-Command -Session $Session -ScriptBlock {
            Push-Location $Using:TestsPath

            Invoke-Expression -Command $Using:Command | Write-Host
            $Res = $LASTEXITCODE

            Pop-Location

            return $Res
        }

        if ($Res -ne 0) {
            $TestFailed = $true
            break
        }
    }

    $TestFiles.ForEach({
        Copy-Item -FromSession $Session -Path ($TestsPath + $_ + "_junit.xml")
    })

    if ($TestFailed -eq $true) {
        throw "Docker Driver test failed."
    }

    Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

    Write-Host "Success"
}
