stage('Preparation') {
    node('builder') {
        deleteDir()
        git branch: 'jfbuild', url: 'https://github.com/codilime/contrail-windows-tools/'
        stash name: "CIScripts", includes: "CIScripts/**"
    }
}

stage('Build') {
    node('builder') {
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
        env.BUILD_ONLY = "1"
        env.BUILD_IN_RELEASE_MODE = "false"
        env.SIGNTOOL_PATH = "C:/Program Files (x86)/Windows Kits/10/bin/x64/signtool.exe"
        env.CERT_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/codilime.com-selfsigned-cert.pfx"
        env.CERT_PASSWORD_FILE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/certp.txt"

        env.MSBUILD = "C:/Program Files (x86)/MSBuild/14.0/Bin/MSBuild.exe"
        env.GOPATH = pwd()

        powershell script: './CIScripts/Build.ps1'
        stash name: "WinArt", includes: "output/**/*"
        stash name: "buildLogs", includes: "logs/**"
    }
}

def SpawnedTestbedVMNames = ''

stage('Provision') {
    node('ansible') {
        sh 'echo "TODO use ansible for provisioning"'
        // set $SpawnedTestbedVMNames here
    }
}

stage('Deploy') {
    node('tester') {
        deleteDir()
        unstash "CIScripts"
        // unstash "WinArt"

        env.TESTBED_HOSTNAMES = SpawnedTestbedVMNames
        env.ARTIFACTS_DIR = "output"

        // powershell script: './CIScripts//Deploy.ps1'
    }
}

stage('Test') {
    node('tester') {
        deleteDir()
        unstash "CIScripts"

        // env.TESTBED_HOSTNAMES = SpawnedTestbedVMNames
        // env.ARTIFACTS_DIR = "output"

        // powershell script: './CIScripts/Test.ps1'
    }
}

stage('Post-build') {
    node('master') {
        // cleanWs()
        sh 'echo "TODO environment cleanup"'
        // unstash "buildLogs"
        // TODO correct flags for rsync
        sh "echo rsync logs/ logs.opencontrail.org:${JOB_NAME}/${BUILD_ID}"
        // cleanWS{}
    }
}
