git clone https://github.com/michal-clapinski/vrouter-vagrant
cd vrouter-vagrant
vagrant up
vagrant ssh -c 'ls; cd contrail-vrouter; scons -Q vrouter; exit $?'
retcode=$?
vagrant halt
vagrant destroy -f
exit $retcode