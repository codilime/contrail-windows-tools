# vrouter-vagrant

Vagrant for building contrail.

Create key ~/.ssh/other_keys/vms_key

    vagrant up
    vagrant ssh
    cd contrail-vrouter
    scons

You can clean SConscript from Openstack stuff for faster build.
