function Test-MultiEnableDisableExtension {
    Param ([Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
           [Parameter(Mandatory = $true)] [int] $EnableDisableCount,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    Write-Host "Running Multi Enable-Disable Extension Test ($EnableDisableCount times)..."

    foreach ($I in 1..$EnableDisableCount) {
        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Start-Sleep -s 1

        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Start-Sleep -s 1
    }

    Write-Host "Success!"
}
