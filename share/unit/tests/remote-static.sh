# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util

function remoteSetUp() {
    core:softimport remote
    assertTrue 'testCoreRemoteImport/1' $?
}

#. Remote -={
#. testCoreRemoteConnectPasswordlessInternal -={
function testCoreRemoteConnectPasswordlessInternal() {
    mock:write <<-!MOCK
        function dig() {
            $(which dig) -p 5353 @localhost "$@"
            return $?
        }
	!MOCK

    cat <<-!DNSMASQ > /tmp/hosts.mocked
        127.0.0.1 batman.gotham.com
        127.6.6.6 jester.gotham.com
	!DNSMASQ

    local hn="batman.gotham.com"
    local user=$(id -un)

    # First run will run into a host key validation prompt; so here we first
    # force the acception of the host key to make the next run successful.
    ssh ${g_SSH_OPTS?} -o StrictHostKeyChecking=no ${user}@${hn} --\
        whoami #>${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qF "$(whoami)" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.2" $?

    # g_SSH_OPTS contains -E which sends log messages to a file
    #grep -qE "^Warning: Permanently added '${hn}'" "${stderrF?}"
    #assertTrue "${FUNCNAME?}/1.3" $?

    :remote:connect:passwordless ${hn}
    assertTrue "${FUNCNAME?}/2" $?

    :remote:connect:passwordless ${user}@${hn}
    assertTrue "${FUNCNAME?}/3" $?

    :remote:connect:passwordless hostdoesnotexist
    assertFalse "${FUNCNAME?}/4" $?

    :remote:connect:passwordless userdoesnotexist@${hn}
    assertFalse "${FUNCNAME?}/5" $?
}
#. }=-
#. testCoreRemoteConnectInternal -={
function testCoreRemoteConnectInternal() {
    local hn1 hn2
    hn1=$(hostname -f)
    hn2=$(:remote:connect _ host-8c.unit-tests.mgmt.simbol -- hostname -f)
    assertTrue   "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "${hn1}" "${hn2}"
}
#. }=-
#. testCoreRemoteConnectPublic -={
function testCoreRemoteConnectPublic() {
    local hn1 hn2
    hn1="$(hostname -f)"
    hn2="$(core:wrapper remote connect -T _ host-8c.unit-tests.mgmt.simbol -- hostname -f)"
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "${hn1}" "${hn2}"
}
#. }=-
#. testCoreRemoteCopyPublic -={
function testCoreRemoteCopyPublic() {
    #. TODO: Split each section here into separate tests!

    #. Remote File to Directory
    rm -f "${SIMBOL_USER_VAR_CACHE?}/hosts"

    # FIXME: This is broken -={
    #core:wrapper remote copy -T _\
    #    host-8c.unit-tests.mgmt.simbol:/etc/hosts\
    #    ${SIMBOL_USER_VAR_CACHE?}
    #FIXME: Enabled once fixed -={
    #/\
    #>${stdoutF?} 2>${stderrF?}
    #assertTrue 'remote:copy/1.1' $?
    #[ -f ${SIMBOL_USER_VAR_CACHE?}/hosts ]
    #assertTrue 'remote:copy/1.2' $?
    #local -i same=$(
    #    md5sum /etc/hosts ${SIMBOL_USER_VAR_CACHE?}/hosts |
    #    awk '{print$1}' |
    #    sort -u |
    #    wc -l
    #)
    #assertEquals "${FUNCNAME?}/1" 1 ${same}
    #FIXME: }=-
    #. }=-

    #. Remote File to File
    rm -f ${SIMBOL_USER_VAR_CACHE}/hosts.explicit
    core:wrapper remote copy -T _\
        host-8c.unit-tests.mgmt.simbol:/etc/hosts\
        ${SIMBOL_USER_VAR_CACHE}/hosts.explicit\
    >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.1" $?

    [ -f ${SIMBOL_USER_VAR_CACHE}/hosts.explicit ]
    assertTrue "${FUNCNAME?}/2.2" $?

    #. Remote File to Remote File
    core:wrapper remote copy -T _\
        host-89.unit-tests.mgmt.simbol:/etc/hosts\
        host-8f.unit-tests.mgmt.simbol:/tmp/89-hosts\
    >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/3" $?

    #. Remote Directory to Remote Directory
    core:wrapper remote copy -T _\
        host-89.unit-tests.mgmt.simbol:/etc/rc.d/\
        host-8f.unit-tests.mgmt.simbol:/tmp/89-rc.d/\
    >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/4" $?

    #. Remote Directory to Directory
    rm -rf /tmp/89-rc.d/
    core:wrapper remote copy -T _\
        host-89.unit-tests.mgmt.simbol:/etc/rc.d/\
        /tmp/89-rc.d/\
    >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/5" $?

    #. Directory to Remote Directory
    core:wrapper remote copy -T _\
        /etc/rc.d/\
        host-8f.unit-tests.mgmt.simbol:/tmp/test-rc.d/\
    >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreRemoteSudoInternal -={
function testCoreRemoteSudoInternal() {
    local who
    who=$(:remote:sudo _ host-8f.api whoami)
    assertTrue   "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "root" "${who}"
}
#. }=-
#. testCoreRemoteSudoPublic -={
function testCoreRemoteSudoPublic() {
    local who
    who=$(core:wrapper remote sudo -T _ host-8f.api whoami)
    assertTrue   "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "root" "${who}"
}
#. }=-
#. testCoreRemoteTmuxPrivate -={
function testCoreRemoteTmuxPrivate() {
    mock:write <<!
function tmux() { echo "\$*"; }
function cpf() { :; }
!

    mock:wrapper remote ::tmux _ s '|(#10.0.0.0/29)' >${stdoutF?} 2>${stderrF?}

    local -i count
    count=$(grep -cE '10\.0\.0\.' ${stdoutF?})
    assertEquals "${FUNCNAME?}/1.1" 6 ${count}

    count=$(grep -cFw 'new-session' ${stdoutF?})
    assertEquals "${FUNCNAME?}/1.2" 1 ${count}

    count=$(grep -cFw 'attach-session' ${stdoutF?})
    assertEquals "${FUNCNAME?}/1.3" 1 ${count}

    count=$(grep -cFw 'kill-session' ${stdoutF?})
    assertEquals "${FUNCNAME?}/1.4" 1 ${count}

    mock:clear
}
#. }=-
#. testCoreRemoteMonIpcPublic -={
function testCoreRemoteMonIpcPublic() {
    local hostname="$(hostname)"
    core:wrapper remote mon '|(#127.0.0.1)' -- hostname >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qFw "${hostname}" ${stdoutF?}
    assertTrue "${FUNCNAME?}/1.2" $?
}
#. }=-
#. testCoreRemoteSsh_threadIpcPrivate -={
function testCoreRemoteSsh_threadIpcPrivate() {
    local hn=$(hostname -f)

    ::remote:thread:setup
    assertTrue "${FUNCNAME?}/1.1" $?

    ::remote:ssh_thread.ipc 1 1 "${hn}" echo '0xDEADBEEF'
    assertTrue "${FUNCNAME?}/1.2" $?

    local hcs
    while ! read -u 4 -d $'\0' hcs; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.1" "${hn}" "${hcs}"

    local stdout
    while ! read -u 4 -d $'\0' stdout; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.2" '0xDEADBEEF' "${stdout}"

    local stderr
    while ! read -u 4 -d $'\0' stderr; do sleep 0.1; done
    #assertEquals "${FUNCNAME?}/1.3.3" '0xDEADBEEF' "${stderr}"

    local ee
    while ! read -u 4 -d $'\0' ee; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.4" 0 "${ee}"

    local metadata_raw
    while ! read -u 4 -d $'\0' metadata_raw; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.5" "tries=1;" "${metadata_raw}"

    ::remote:thread:teardown
    assertTrue "${FUNCNAME?}/1.4" $?
}
#. }=-

#testCoreRemoteClusterPublic
#testCoreRemoteTmuxPublic
#testCoreRemotePipewrapEvalPrivate
#testCoreRemoteSerialmonPrivate
#testCoreRemoteSerialmonInternal
#testCoreRemoteMonInternal
#. }=-
