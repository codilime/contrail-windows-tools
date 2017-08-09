$Env:GOPATH=pwd

New-Item -ItemType Directory ./bin
Push-Location bin

Write-Host "Installing test runner"
go get -u -v github.com/onsi/ginkgo/ginkgo

Write-Host "Building driver"
go get -u -v $Env:DRIVER_SRC_PATH

$srcPath = "$Env:GOPATH/src/$Env:DRIVER_SRC_PATH"
Write-Host $srcPath

Write-Host "Precompiling tests"
$modules = @("driver", "controller", "hns", "hnsManager")
$modules.ForEach({
    .\ginkgo.exe build $srcPath/$_
    Move-Item $srcPath/$_/$_.test ./
})

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

Pop-Location
