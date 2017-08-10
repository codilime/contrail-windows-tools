. $PSScriptRoot\InitializeCIScript.ps1
. $PSScriptRoot\BuildFunctions.ps1

$Repos = @(
    [Repo]::new($Env:DRIVER_REPO_URL, $Env:DRIVER_BRANCH, "src/github.com/codilime/contrail-windows-docker" ,"master")
)

Clone-Repos -Repos $Repos

Build-DockerDriver -DriverSrcPath $Env:DRIVER_SRC_PATH -SigntoolPath $Env:SIGNTOOL_PATH -CertPath $Env:CERT_PATH, -CertPasswordFilePath $Env:CERT_PASSWORD_FILE_PATH
