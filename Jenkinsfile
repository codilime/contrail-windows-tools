def ansibleConfig = evaluate readTrusted('jenkinsfiles/library/createAnsibleCfg.groovy')

stage('Preparation') {
    node('builder') {
        deleteDir()

        // Use the same repo and branch as was used to checkout Jenkinsfile:
        checkout scm

        // If not using `Pipeline script from SCM`, specify the branch manually:
        // git branch: 'master', url: 'https://github.com/codilime/contrail-windows-tools/'

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
        stage('Provision - prepare environment') {
            def buildNumber = env.BUILD_NUMBER as int
            def testenvName = "winci_$buildNumber"
            def nTestenvs = 15
            def vlanNumber = (buildNumber % nTestEnvs) + 1
            def vlanId = "VLAN_$vlanNumber"

            withCredentials([usernamePassword(credentialsId: 'b5d73edd-96c2-467d-8b97-bf52c0ec946a', passwordVariable: 'VC_PASSWORD', usernameVariable: 'VC_USERNAME')]) {
                def vmwareVmVars = """
                    # Common testenv vars
                    testenv_name: $testenvName
                    testenv_folder: WINCI
                    vm_inventory_file: $WORKSPACE/vminfo.{{ testenv_name }}

                    # Testenv block
                    wintestbed_template: Template-testbed
                    controller_template: template-contrail-controller-3.1.1.0-45
                    testenv_block:
                        controller:
                            template: "{{ controller_template }}"
                            nodes:
                            - name: "{{ testenv_name }}-controller"
                        wintb:
                            template: "{{ wintestbed_template }}"
                            netmask: 255.255.0.0
                            nodes:
                              - name: "{{ testenv_name }}-wintb01"
                                ip: 172.16.0.2
                              - name: "{{ testenv_name }}-wintb02"
                                ip: 172.16.0.3

                    # Common vCenter infra connection parameters
                    vcenter_hostname: ci-vc.englab.juniper.net
                    vcenter_user: $VC_USERNAME
                    vcenter_password: $VC_PASSWORD
                    validate_certs: false
                    datacenter_name: CI-DC
                    cluster_name: WinCI

                    # Common network parameters
                    vlan_id: $vlanId
                    portgroup_mgmt: "VLAN_501_Management"
                    portgroup_contrail: "VLAN_{{ vlan_id }}_{{ testenv_name }}"
                    netmask_mgmt: 255.255.255.0
                    netmask_contrail: 255.255.0.0
                    gateway_mgmt: 10.84.12.254
                    dns_servers: [ 10.84.5.100, 172.21.200.60 ]
                    domain: englab.juniper.net
                """.stripIndent()

                git branch: 'ansible-provisioning', url: 'git@github.com:codilime/juniper-windows-internal.git'
                script {
                    ansibleConfig.create(env.ANSIBLE_VAULT_KEY_FILE)
                }
                writeFile file: 'vmware-vm.vars', text: vmwareVmVars
            }
        }
        stage('Provision - run ansible') {
            ansiblePlaybook extras: '-e @vm.vars', inventory: 'inventory.vmware', playbook: 'vmware-deploy-testenv.yml', sudoUser: 'ubuntu'
        }
        stage('Provision - set $SpawnedTestbedVMNames') {
            SpawnedTestbedVMNames = "$testenvName-wintb01,$testenvName-wintb02"
        }
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
