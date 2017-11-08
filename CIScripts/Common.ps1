$Accel = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
$Accel::add("PSSessionT", "System.Management.Automation.Runspaces.PSSession")

function Get-VMCreds() {
    $VMUsername = $Env:VM_USERNAME
    $VMPassword = $Env:VM_PASSWORD | ConvertTo-SecureString -AsPlainText -Force
    return New-Object System.Management.Automation.PSCredential($VMUsername, $VMPassword)
}
