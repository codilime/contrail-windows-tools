Write-Host "Copying third-party dependencies"
New-Item -ItemType Directory ./third_party
Copy-Item -Recurse "$Env:THIRD_PARTY_CACHE_PATH\agent\*" third_party/
Copy-Item -Recurse "$Env:THIRD_PARTY_CACHE_PATH\common\*" third_party/
Copy-Item -Recurse "$Env:THIRD_PARTY_CACHE_PATH\extension\*" third_party\
Copy-Item -Recurse third_party\cmocka vrouter\test\

Copy-Item tools/build/SConstruct ./

$cerp = Get-Content $Env:CERT_PASSWORD_FILE_PATH

Write-Host "Building Agent, MSI, API, Extension and Utils"
scons contrail-vrouter-agent contrail-vrouter-agent.msi controller/src/vnsw/contrail_vrouter_api:sdist vrouter
if ($LASTEXITCODE -ne 0) {
    throw "Building Contrail failed"
}

$vRouterMSI = "build\debug\vrouter\extension\vRouter.msi"
$utilsMSI = "build\debug\vrouter\utils\utils.msi"

Write-Host "Signing MSIs"
& "$Env:SIGNTOOL_PATH" sign /f "$Env:CERT_PATH" /p $cerp $utilsMSI
if ($LASTEXITCODE -ne 0) {
    throw "Signing utilsMSI failed"
}

& "$Env:SIGNTOOL_PATH" sign /f "$Env:CERT_PATH" /p $cerp $vRouterMSI
if ($LASTEXITCODE -ne 0) {
    throw "Signing vRouterMSI failed"
}
