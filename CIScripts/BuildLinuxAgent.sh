git clone https://github.com/michal-clapinski/vrouter-vagrant
cd vrouter-vagrant
vagrant up
vagrant ssh
cd contrail-vrouter
scons -Q vrouter
exit $?
