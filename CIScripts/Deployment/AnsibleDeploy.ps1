
. $PSScriptRoot\Common.ps1

function Deploy-Ansible {
    Param ([Parameter(Mandatory = $true)] [int] $VMsNeeded)
    $Job.Step("Deploying using Ansible", {
        # TODO
    })
}
