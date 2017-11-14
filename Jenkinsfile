stage('Preparation') {
    node('builder') {
        deleteDir()
        git branch: 'jfbuild', url: 'https://github.com/codilime/contrail-windows-tools/'

        dir('CIScripts') {
            env.DRIVER_REPO_URL = "https://github.com/codilime/contrail-windows-docker"
            env.DRIVER_BRANCH = "master"
            env.TOOLS_REPO_URL = "https://github.com/codilime/contrail-build"
            env.TOOLS_BRANCH = "windows"
            env.SANDESH_REPO_URL = "https://github.com/codilime/contrail-sandesh"
            env.SANDESH_BRANCH = "windows"
            env.GENERATEDS_REPO_URL = "https://github.com/codilime/contrail-generateDS"
            env.GENERATEDS_BRANCH = "windows"
            env.VROUTER_REPO_URL = "https://github.com/codilime/contrail-vrouter"
            env.VROUTER_BRANCH = "windows"
            env.WINDOWSSTUBS_REPO_URL = "https://github.com/codilime/contrail-windowsstubs"
            env.WINDOWSSTUBS_BRANCH = "windows"
            env.CONTROLLER_REPO_URL = "https://github.com/codilime/contrail-controller"
            env.CONTROLLER_BRANCH = "windows3.1"
            env.THIRD_PARTY_CACHE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/"
            env.DRIVER_SRC_PATH = "github.com/codilime/contrail-windows-docker"
            env.VS_SETUP_ENV_SCRIPT_PATH = "C:/ewdk/Program Files/Microsoft Visual Studio 14.0/vc/bin/amd64/vcvars64.bat"
            env.BUILD_IN_RELEASE_MODE = "true"
            env.SIGNTOOL_PATH = "C:/ewdk/Program Files/Windows Kits/10/bin/x64/signtool.exe"
            env.CERT_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/codilime.com-selfsigned-cert.pfx"
            env.CERT_PASSWORD_FILE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/certp.txt"

            powershell script: './Build.ps1'
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
        deleteDir()
        git branch: 'jfbuild', url: 'https://github.com/codilime/contrail-windows-tools/'
        dir('CIScripts') {
        }
    }
}
stage('Cleanup') {
    node('master') {
        sh 'echo "Tu będzie cleanup środowiska"'
        cleanWs()
    }
}
