. $PSScriptRoot\Common.ps1

function Deploy-Legacy {
    Param ([Parameter(Mandatory = $true)] [int] $VMsNeeded,
           [Parameter(Mandatory = $true)] [bool] $IsReleaseMode)

    $Job.PushStep("Deploying using Legacy method")

    $VIServerAccessData = [VIServerAccessData] @{
        Username = $Env:VISERVER_USERNAME;
        Password = $Env:VISERVER_PASSWORD;
        Server = $Env:VISERVER_ADDRESS;
    }

    $VMCreationSettings = [NewVMCreationSettings] @{
        ResourcePoolName = $Env:CI_RESOURCE_POOL_NAME;
        TemplateName = $Env:CI_TEMPLATE_NAME;
        CustomizationSpecName = $Env:CI_CUSTOMIZATION_SPEC_NAME;
        DatastoresList = $Env:CI_DATASTORES.Split(",");
        NewVMLocation = $Env:CI_VM_LOCATION;
    }

    $MaxWaitVMMinutes = $Env:MAX_WAIT_VM_MINUTES
    $DumpFilesLocation = $Env:DUMP_FILES_LOCATION
    $DumpFilesBaseName = ($Env:JOB_BASE_NAME + "_" + $Env:BUILD_NUMBER)

    $VMBaseName = Get-SanitizedOrGeneratedVMName -VMName $Env:VM_NAME -RandomNamePrefix "Core-"x
    $VMNames = [System.Collections.ArrayList] @()
    for ($i = 0; $i -lt $VMsNeeded; $i++) {
        $VMNames += $VMBaseName + "-" + $i.ToString()
    }

    Write-Host "Starting Testbeds:"
    $VMNames.ForEach({ Write-Host $_ })

    $VMCredentials = Get-VMCreds()

    if ($IsReleaseMode) {
        $Sessions = New-TestbedVMs -VMNames $VMNames -InstallArtifacts $true -VIServerAccessData $VIServerAccessData `
            -VMCreationSettings $VMCreationSettings -VMCredentials $VMCredentials -ArtifactsDir $ArtifactsDir `
            -DumpFilesLocation $DumpFilesLocation -DumpFilesBaseName $DumpFilesBaseName -MaxWaitVMMinutes $MaxWaitVMMinutes
    } else {
        $Sessions = New-TestbedVMs -VMNames $VMNames -InstallArtifacts $true -VIServerAccessData $VIServerAccessData `
            -VMCreationSettings $VMCreationSettings -VMCredentials $VMCredentials -ArtifactsDir $ArtifactsDir `
            -DumpFilesLocation $DumpFilesLocation -DumpFilesBaseName $DumpFilesBaseName -MaxWaitVMMinutes $MaxWaitVMMinutes `
            -CopyMsvcDebugDlls -MsvcDebugDllsDir $Env:MSVC_DEBUG_DLLS_DIR
    }

    Write-Host "Started Testbeds:"
    $Sessions.ForEach({ Write-Host $_.ComputerName })

    $Job.PopStep()

    return $Sessions, $VMNames
}

function Teardown-Legacy {
    Param ([Parameter(Mandatory = $true)] [int] $VMNames)

    $Job.Step("Teardown using Legacy method", {
        $VIServerAccessData = [VIServerAccessData] @{
            Username = $Env:VISERVER_USERNAME;
            Password = $Env:VISERVER_PASSWORD;
            Server = $Env:VISERVER_ADDRESS;
        }

        Remove-TestbedVMs -VMNames $VMNames -VIServerAccessData $VIServerAccessData
    })
}