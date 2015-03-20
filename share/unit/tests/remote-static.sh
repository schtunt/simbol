# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util

function testCoreRemoteImport() {
    core:softimport remote
    assertTrue 0.0 $?
}

#. Remote -={

#. testCoreRemoteSshproxystrInternal DEPRECATED -={
#function testCoreRemoteSshproxystrInternal() {
#    core:import remote
#
#    :remote:sshproxystr _ >${stdoutF?} 2>${stderrF?}
#    assertFalse 1.1 $?
#}
#. }=-
#. testCoreRemoteSshproxyoptsInternal DEPRECATED -={
#function testCoreRemoteSshproxyoptsInternal() {
#    core:import remote
#
#    :remote:sshproxyopts _ >${stdoutF?} 2>${stderrF?}
#    assertFalse 1.1 $?
#}
#. }=-
#. testCoreRemoteSshproxycmdInternal DEPRECATED -={
#function testCoreRemoteSshproxycmdInternal() {
#    core:import remote
#
#    :remote:sshproxycmd _ >${stdoutF?} 2>${stderrF?}
#    assertFalse 1.1 $?
#}
#. }=-
#. testCoreRemoteConnectInternal -={
function testCoreRemoteConnectInternal() {
    core:import remote

    local hn1 hn2
    hn1=$(hostname -f)
    hn2=$(:remote:connect _ host-8c.unit-tests.mgmt.simbol -- hostname -f)
    assertTrue   1.1 $?
    assertEquals 1.2 "${hn1}" "${hn2}"
}
#. }=-
#. testCoreRemoteConnectPublic -={
function testCoreRemoteConnectPublic() {
    core:import remote

    local hn1 hn2
    hn1=$(hostname -f)
    hn2=$(core:wrapper remote connect -T _ host-8c.unit-tests.mgmt.simbol -- hostname -f)
    assertTrue   1.1 $?
    assertEquals 1.2 "${hn1}" "${hn2}"
}
#. }=-
#. testCoreRemoteCopyPublic -={
function testCoreRemoteCopyPublic() {
    core:import remote

    #. Remote File to Directory
    rm -f ${SIMBOL_USER_CACHE}/hosts
    core:wrapper remote copy -T _ host-8c.unit-tests.mgmt.simbol:/etc/hosts ${SIMBOL_USER_CACHE}/ >${stdoutF?} 2>${stderrF?}
    assertTrue 1.1 $?
    [ -f ${SIMBOL_USER_CACHE}/hosts ]
    assertTrue 1.2 $?
    local same
    same=$(
        md5sum /etc/hosts ${SIMBOL_USER_CACHE}/hosts |
        awk '{print$1}' |
        sort -u |
        wc -l
    )
    assertEquals 1.3 1 ${same}

    #. Remote File to File
    rm -f ${SIMBOL_USER_CACHE}/hosts.explicit
    core:wrapper remote copy -T _ host-8c.unit-tests.mgmt.simbol:/etc/hosts ${SIMBOL_USER_CACHE}/hosts.explicit >${stdoutF?} 2>${stderrF?}
    assertTrue 2.1 $?
    [ -f ${SIMBOL_USER_CACHE}/hosts.explicit ]
    assertTrue 2.2 $?

    #. Remote File to Remote File
    core:wrapper remote copy -T _ host-8a.unit-tests.mgmt.simbol:/etc/hosts host-8f.unit-tests.mgmt.simbol:/tmp/8a-hosts >${stdoutF?} 2>${stderrF?}
    assertTrue 3.1 $?

    #. Remote Directory to Remote Directory
    core:wrapper remote copy -T _ host-8a.unit-tests.mgmt.simbol:/etc/rc.d/ host-8f.unit-tests.mgmt.simbol:/tmp/8a-rc.d/ >${stdoutF?} 2>${stderrF?}
    assertTrue 4.1 $?

    #. Remote Directory to Directory
    rm -rf /tmp/8a-rc.d/
    core:wrapper remote copy -T _ host-8a.unit-tests.mgmt.simbol:/etc/rc.d/ /tmp/8a-rc.d/ >${stdoutF?} 2>${stderrF?}
    assertTrue 5.1 $?

    #. Directory to Remote Directory
    core:wrapper remote copy -T _ /etc/rc.d/ host-8f.unit-tests.mgmt.simbol:/tmp/test-rc.d/ >${stdoutF?} 2>${stderrF?}
    assertTrue 6.1 $?
}
#. }=-
#. testCoreRemoteSudoInternal -={
function testCoreRemoteSudoInternal() {
    core:import remote

    local who
    who=$(:remote:sudo _ host-8f.api whoami)
    assertTrue   1.1 $?
    assertEquals 1.2 "root" "${who}"
}
#. }=-
#. testCoreRemoteSudoPublic -={
function testCoreRemoteSudoPublic() {
    core:import remote

    local who
    who=$(core:wrapper remote sudo -T _ host-8f.api whoami)
    assertTrue   1.1 $?
    assertEquals 1.2 "root" "${who}"
}
#. }=-
#. testCoreRemoteMonPublic -={
function testCoreRemoteMonPublic() {
    cat ~/.ssh/authorized_keys
    ssh host-8.simbol.org hostname

    simbol rb install
    assertTrue 1.1 $?

    simbol hgd save myhgd /host-8./
    assertTrue 1.2 $?

    eval $(ssh-add)

    core:import remote
    core:wrapper remote mon myhgd -- hostname
    assertTrue 1.3 $?
}
#. }=-

#testCoreRemoteClusterPublic
#testCoreRemoteTmuxPrivate
#testCoreRemoteTmuxPublic
#testCoreRemotePipewrapPrivate
#testCoreRemotePipewrapPrivate
#testCoreRemoteSerialmonPrivate
#. }=-
