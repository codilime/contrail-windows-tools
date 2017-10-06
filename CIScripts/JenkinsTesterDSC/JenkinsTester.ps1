Configuration JenkinsTester {
    param(
        [Parameter(Mandatory=$true)][string[]]$MachineName
    )

    Import-DscResource -ModuleName PsDesiredStateConfiguration
    Import-DscResource -ModuleName cChoco
    Import-DscResource -ModuleName PowerShellModule

    Node $MachineName {
        WindowsFeature NetFrameworkCore {
            Ensure    = "Present"
            Name      = "NET-Framework-Core"
        }

        cChocoInstaller installChoco {
            InstallDir = "C:\ProgramData\chocolatey"
            DependsOn = "[WindowsFeature]NetFrameworkCore"
        }

        cChocoPackageInstaller installJava {
            Name = "javaruntime"
            DependsOn = "[cChocoInstaller]installChoco"
        }

        cChocoPackageInstaller installChrome {
            Name = "googlechrome"
            DependsOn = "[cChocoInstaller]installChoco"
        }

        cChocoPackageInstaller installGit {
            Name = "git"
            DependsOn = "[cChocoInstaller]installChoco"
        }

        PSModuleResource PowerCli {
            Ensure = "Present"
            Module_Name = "VMware.PowerCLI"
        }

        Script disableVMwareCEIP {
            SetScript = {
                Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false
            }
            TestScript = {
                (Get-PowerCLIConfiguration -Scope AllUsers).ParticipateInCEIP -eq $false
            }
            GetScript = { @{ Result = "" } }
        }

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }
    }
}
