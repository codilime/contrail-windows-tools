stage('Preparation') {
    node('builder') {
        deleteDir()
        git branch: 'jfbuild', url: 'https://github.com/codilime/contrail-windows-tools/'
        stash name: "CIScripts", includes: "CIScripts/**"

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
        env.VS_SETUP_ENV_SCRIPT_PATH = "C:/Program Files (x86)/Microsoft Visual C++ Build Tools/vcbuildtools.bat"
        env.BUILD_IN_RELEASE_MODE = "true"
        env.SIGNTOOL_PATH = "C:/Program Files (x86)/Windows Kits/10/bin/x64/signtool.exe"
        env.CERT_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/codilime.com-selfsigned-cert.pfx"
        env.CERT_PASSWORD_FILE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/certp.txt"

        env.GOPATH = pwd()

        powershell script: './CIScripts/Build.ps1'
        stash name: "WinArt", includes: "output/**/*"
    }
}

def SpawnedTestbedVMNames = ''

stage('Provision') {
    node('master') {
        sh 'echo "Tu będzie ansible"'
        // set $SpawnedTestbedVMNames here
    }
}
stage('Deploy') {
    node('tester') {
        deleteDir()
        unstash "CIScripts"
        //unstash "WinArt"

        env.TESTBED_HOSTNAMES = SpawnedTestbedVMNames
        env.ARTIFACTS_DIR = "output"

        powershell script: './CIScripts//Deploy.ps1'
    }
}
stage('Test') {
    node('tester') {
        deleteDir()
        unstash "CIScripts"

        env.TESTBED_HOSTNAMES = SpawnedTestbedVMNames
        env.ARTIFACTS_DIR = "output"

        powershell script: './CIScripts/Test.ps1'
    }
}
stage('Cleanup') {
    node('master') {
        sh 'echo "Tu będzie cleanup środowiska"'
        cleanWs()
    }
}
