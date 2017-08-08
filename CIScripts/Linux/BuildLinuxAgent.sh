# This script
# - generates repo tool manifest that uses branches specified in parameters
# - launches a Linux Virtualbox VM using Vagrant
# - checkouts proper branches
# - builds vRouter Agent
# parameters:
# TOOLS_BRANCH CONTROLLER_BRANCH VROUTER_BRANCH GENERATEDS_BRANCH SANDESH_BRANCH

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