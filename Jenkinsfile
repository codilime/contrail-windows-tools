stage('Preparation') {
    node('builder') {
        deleteDir()
        git branch: 'jfbuild', url: 'https://github.com/codilime/contrail-windows-tools/'
        dir('CIScripts') {

            powershell script: '''
            ./Build.ps1 `
                -DriverRepoURL "https://github.com/codilime/contrail-windows-docker" `
                -DriverBranch "master" `
                -ToolsRepoURL "https://github.com/codilime/contrail-build" `
                -ToolsBranch "windows" `
                -SandeshRepoURL "https://github.com/codilime/contrail-sandesh" `
                -SandeshBranch "windows" `
                -GenerateDSRepoURL "https://github.com/codilime/contrail-generateDS" `
                -GenerateDSBranch "windows" `
                -VRouterRepoURL "https://github.com/codilime/contrail-vrouter" `
                -VRouterBranch "windows" `
                -WindowsStubsRepoURL "https://github.com/codilime/contrail-windowsstubs" `
                -WindowsStubsBranch "windows" `
                -ControllerRepoURL "https://github.com/codilime/contrail-controller" `
                -ControllerBranch "windows3.1" `
                -ThirdPartyCachePath "C:/BUILD_DEPENDENCIES/third_party_cache/" `
                -DriverSrcPath "github.com/codilime/contrail-windows-docker" `
                -VSSetupEnvScriptPath "C:/ewdk/Program Files/Microsoft Visual Studio 14.0/vc/bin/amd64/vcvars64.bat" ` 
                -IsReleaseMode "$True" `
                -SigntoolPath "C:/ewdk/Program Files/Windows Kits/10/bin/x64/signtool.exe" `
                -CertPath "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/codilime.com-selfsigned-cert.pfx" `
                -CertPasswordPath "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/certp.txt" 
            '''
        }

    }
}
stage('Provision') {
    node('master') {
        sh 'echo "Tu będzie ansible"'
    }
}
stage('Deploy') {
    node('tester') {
        bat 'echo "Tu będzie deploy"'
    }
}
stage('Test') {
    node('tester') {
        bat 'echo "Tu będzie test"'
    }
}
stage('Cleanup') {
    node('master') {
        sh 'echo "Tu będzie cleanup środowiska"'
        cleanWs()
    }
}