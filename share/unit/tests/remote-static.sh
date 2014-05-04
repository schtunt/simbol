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
#. testCoreRemoteCopyInternal -={
function testCoreRemoteCopyInternal() {
    core:import remote

    rm -f ${SIMBOL_USER_CACHE}/hosts

    :remote:copy _ host-8c.unit-tests.mgmt.simbol\
        /etc/hosts\
        ${SIMBOL_USER_CACHE}/hosts
    assertTrue 1.1 $?

    [ -f ${SIMBOL_USER_CACHE}/hosts ]
    assertTrue 1.2 $?

    if [ -f ${SIMBOL_USER_CACHE}/hosts ]; then
        local same
        same=$(
            md5sum /etc/hosts ${SIMBOL_USER_CACHE}/hosts |
            awk '{print$1}' |
            sort -u |
            wc -l
        )
        assertEquals 1.3 1 ${same}
    fi

    rm -f ${SIMBOL_USER_CACHE}/hosts
}
#. }=-
#. testCoreRemoteCopyPublic -={
function testCoreRemoteCopyPublic() {
    core:import remote

    rm -f ${SIMBOL_USER_CACHE}/hosts

    core:wrapper remote copy -T _ host-8c.unit-tests.mgmt.simbol\
        /etc/hosts ${SIMBOL_USER_CACHE}/hosts >${stdoutF?} 2>${stderrF?}
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

    rm -f ${SIMBOL_USER_CACHE}/hosts
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

#testCoreRemoteClusterPublic
#testCoreRemoteTmuxPrivate
#testCoreRemoteTmuxPublic
#testCoreRemoteMonPublic
#testCoreRemotePipewrapPrivate
#testCoreRemotePipewrapPrivate
#testCoreRemoteSerialmonPrivate
#. }=-
