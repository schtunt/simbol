# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import net
core:import tunnel

#. Tunnel -={
function tunnelOneTimeSetUp() {
    : pass
}

function tunnelSetUp() {
    case ${g_MODE?} in
        prime)
            : pass
        ;;
        execute)
            export g_PID=0
        ;;
        *)
            exit 127
        ;;
    esac
}

function tunnelTearDown() {
    : pass
}

function tunnelOneTimeTearDown() {
    : pass
}

#. testCoreTunnelStartPublic -={
function testCoreTunnelStartPublic() {
    core:wrapper tunnel start host-8c.unit-tests.mgmt.simbol >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreTunnelStartInternal -={
function testCoreTunnelStartInternal() {
    :tunnel:start host-8c.unit-tests.mgmt.simbol 22
    assertFalse "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreTunnelStartPublic -={
function testCoreTunnelStartPublic() {
    core:wrapper tunnel start host-8c.unit-tests.mgmt.simbol >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreTunnelCreateInternal -={
function testCoreTunnelCreateInternal() {
    :net:localportping 8000
    assertFalse "${FUNCNAME?}/1" $?

    :tunnel:create host-8c.unit-tests.mgmt.simbol localhost 8000 localhost 22
    assertTrue "${FUNCNAME?}/2" $?

    :net:localportping 8000
    assertTrue "${FUNCNAME?}/3" $?

    :tunnel:create host-8c.unit-tests.mgmt.simbol localhost 8000 localhost 22
    assertFalse "${FUNCNAME?}/4" $?
}
#. }=-
#. testCoreTunnelCreatePublic -={
function testCoreTunnelCreatePublic() {
    core:wrapper tunnel create host-8c.unit-tests.mgmt.simbol\
        -l localhost 8000 -r localhost 22 >"${stdoutF?}" 2>"${stderrF?}"
    assertFalse "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreTunnelStatusPublic -={
function testCoreTunnelStatusPublic() {
    core:wrapper tunnel status host-8c.unit-tests.mgmt.simbol >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/0" $?
}
#. }=-
#. testCoreTunnelPidInternal -={
function testCoreTunnelPidInternal() {
    local g_PID; let g_PID=$(:tunnel:pid host-8c.unit-tests.mgmt.simbol)
    assertTrue "${FUNCNAME?}/1" $?

    (( g_PID > 0 ))
    assertTrue "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreTunnelListInternal -={
function testCoreTunnelListInternal() {
    local -i pid; let pid=${g_PID}
    local -i ports; let ports=$(:tunnel:list ${g_PID})
    assertTrue "${FUNCNAME?}/1" $?

    (( ports == 8000 ))
    assertTrue "${FUNCNAME?}/2" $?
}

#. }=-
#. testCoreTunnelStopInternal -={
function testCoreTunnelStopInternal() {
    local -i pid; pid=$(:tunnel:stop host-8c.unit-tests.mgmt.simbol)
    assertTrue "${FUNCNAME?}/0" $?

    (( pid == g_PID ))
    assertTrue "${FUNCNAME?}/1" $?

    let pid=$(:tunnel:stop host-8c.unit-tests.mgmt.simbol)
    assertFalse "${FUNCNAME?}/2" $?

    (( pid == 0 ))
    assertTrue "${FUNCNAME?}/3" $?
}
#. }=-
#. testCoreTunnelStopPublic -={
function testCoreTunnelStopPublic() {
    core:wrapper tunnel stop host-8c.unit-tests.mgmt.simbol >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
}
#. }=-
#. }=-
