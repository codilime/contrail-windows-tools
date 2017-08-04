git clone https://github.com/michal-clapinski/vrouter-vagrant
cd vrouter-vagrant
vagrant halt
vagrant destroy -f
vagrant up
vagrant ssh -c 'ls; cd contrail-vrouter; scons -Q vrouter; exit $?'
retcode=$?
exit $retcode