# Launches a Vagrant VM and builds vRouter Agent.
# Run this script from the directory that contains Vagrantfile.

if [ "$#" -ne 5 ]; then
    echo "Usage: TOOLS_BRANCH CONTROLLER_BRANCH VROUTER_BRANCH GENERATEDS_BRANCH SANDESH_BRANCH"
    exit 1
fi

set -e

if [ ! -d ".vagrant" ]; then
    echo " !!! WARNING:"
    echo ".vagrant directory not found! This may cause cleanup issues!!!"
    echo "see if any old virtualbox processes are running just in case:"
    ps aux | grep virtualbox
    echo "continuing..."
fi

vagrant halt
vagrant destroy -f
vagrant up
vagrant ssh -c "
ls
cd contrail-vrouter
pushd controller
  git checkout $2
popd
pushd tools
  pushd build
    git checkout $1
  popd
  pushd generateds
    git checkout $4
  popd
  pushd sandesh
    git checkout $5
  popd
popd
pushd vrouter
  git checkout $3
popd
scons vrouter"
