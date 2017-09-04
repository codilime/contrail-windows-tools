# Enable all invoked commands tracing for debugging purposes
if ($Env:ENABLE_TRACE -eq $true) {
    Set-PSDebug -Trace 1
}

# Refresh Path
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$Env:PSModulePath
$Env:Path

# Stop script on error
$ErrorActionPreference = "Stop"
