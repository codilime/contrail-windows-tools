# parameters:
# TOOLS_BRANCH CONTROLLER_BRANCH VROUTER_BRANCH GENERATEDS_BRANCH SANDESH_BRANCH

# we need to somehow inject branches from upstream jenkins job into repo tool
# manifest.
# padre forgive me for this hack...
echo "
<manifest>
<remote name=\"github\" fetch=\"..\"/>

<default revision=\"windows\" remote=\"github\"/>

<project name=\"contrail-build\" revision=\"$1\" remote=\"github\" path=\"tools/build\">
  <copyfile src=\"SConstruct\" dest=\"SConstruct\"/>
</project>
<project name=\"contrail-controller\" revision=\"$2\" remote=\"github\" path=\"controller\"/>
<project name=\"contrail-vrouter\" revision=\"$3\" remote=\"github\" path=\"vrouter\"/>
<project name=\"contrail-generateDS\" revision=\"$4\" remote=\"github\" path=\"tools/generateds\"/>
<project name=\"contrail-sandesh\" revision=\"$5\" remote=\"github\" path=\"tools/sandesh\"/>

<project name=\"contrail-third-party\" remote=\"github\" path=\"third_party\"/>

</manifest>
" > multibranch_manifest.xml

vagrant halt
vagrant destroy -f
vagrant up
vagrant ssh -c 'ls; cd contrail-vrouter; scons -Q vrouter; exit $?'
retcode=$?
exit $retcode