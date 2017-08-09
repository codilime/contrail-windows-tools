if ($Env:ENABLE_TRACE -eq $true) {
    Set-PSDebug -Trace 1
}

# Refresh Path
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Stop script on error
$ErrorActionPreference = "Stop"

& .\Tools\CIScripts\BuildDockerDriver.ps1
& .\Tools\CIScripts\BuildContrail.ps1
