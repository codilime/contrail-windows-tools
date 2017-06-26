if ($Env:ENABLE_TRACE -eq $true) {
    Set-PSDebug -Trace 1
}

# Refresh Path
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Stop script on error
$ErrorActionPreference = "Stop"

$Env:GOPATH=pwd

New-Item -ItemType Directory ./bin
Set-Location bin

Write-Host "Installing test runner"
go get -u -v github.com/onsi/ginkgo/ginkgo

Write-Host "Building driver"
go build -v $Env:DRIVER_SRC_PATH

$srcPath = "$Env:GOPATH/src/$Env:DRIVER_SRC_PATH"
Write-Host $srcPath

Write-Host "Precompiling tests"
.\ginkgo.exe build $srcPath/driver
.\ginkgo.exe build $srcPath/controller
.\ginkgo.exe build $srcPath/hns
.\ginkgo.exe build $srcPath/hnsManager

Move-Item $srcPath/driver/driver.test ./
Move-Item $srcPath/controller/controller.test ./
Move-Item $srcPath/hns/hns.test ./
Move-Item $srcPath/hnsManager/hnsManager.test ./

Write-Host "Copying Agent API python script"
Copy-Item $srcPath/scripts/agent_api.py ./

Write-Host "Intalling MSI builder"
go get -u -v github.com/mh-cbon/go-msi

Write-Host "Building MSI"
Push-Location $srcPath
& "$Env:GOPATH/bin/go-msi" make --msi installer.msi --arch x64 --version 0.1 --src template --out $pwd/gomsi
Pop-Location

Move-Item $srcPath/installer.msi ./

$cerp = Get-Content $Env:CERT_PASSWORD_FILE_PATH
& $Env:SIGNTOOL_PATH sign /f $Env:CERT_PATH /p $cerp installer.msi
