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
    core:wrapper tunnel start host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}
#. }=-
#. testCoreTunnelStartInternal -={
function testCoreTunnelStartInternal() {
    :tunnel:start host-8c.unit-tests.mgmt.simbol 22
    assertEquals "0x2" ${CODE_E01?} $?
}
#. }=-
#. testCoreTunnelStartPublic -={
function testCoreTunnelStartPublic() {
    core:wrapper tunnel start host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}
#. }=-
#. testCoreTunnelCreateInternal -={
function testCoreTunnelCreateInternal() {
    :net:localportping 8000
    assertFalse "0x1" $?

    :tunnel:create host-8c.unit-tests.mgmt.simbol localhost 8000 localhost 22
    assertTrue "0x2" $?

    :net:localportping 8000
    assertTrue "0x3" $?

    :tunnel:create host-8c.unit-tests.mgmt.simbol localhost 8000 localhost 22
    assertEquals "0x4" ${CODE_E01?} $?
}
#. }=-
#. testCoreTunnelCreatePublic -={
function testCoreTunnelCreatePublic() {
    core:wrapper tunnel create host-8c.unit-tests.mgmt.simbol\
        -l localhost 8000 -r localhost 22 >${stdoutF?} 2>${stderrF?}
    assertEquals "0x4" ${CODE_E01?} $?
}
#. }=-
#. testCoreTunnelStatusPublic -={
function testCoreTunnelStatusPublic() {
    core:wrapper tunnel status host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x0" $?
}
#. }=-
#. testCoreTunnelPidInternal -={
function testCoreTunnelPidInternal() {
    g_PID=$(:tunnel:pid host-8c.unit-tests.mgmt.simbol)
    assertTrue "0x1" $?

    [ ${g_PID} -gt 0 ]
    assertTrue "0x1" $?
}
#. }=-
#. testCoreTunnelListInternal -={
function testCoreTunnelListInternal() {
    local ports
    ports=$(:tunnel:list ${g_PID})
    assertTrue "0x1" $?

    [ ${ports} -eq 8000 ]
    assertTrue "0x2" $?
}

#. }=-
#. testCoreTunnelStopInternal -={
function testCoreTunnelStopInternal() {
    local -i pid
    pid=$(:tunnel:stop host-8c.unit-tests.mgmt.simbol)
    assertTrue "0x0" $?

    [ ${pid} -eq ${g_PID} ]
    assertTrue "0x1" $?

    pid=$(:tunnel:stop host-8c.unit-tests.mgmt.simbol)
    assertFalse "0x2" $?

    [ ${pid} -eq 0 ]
    assertTrue "0x4" $?
}
#. }=-
#. testCoreTunnelStopPublic -={
function testCoreTunnelStopPublic() {
    core:wrapper tunnel stop host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}
#. }=-
#. }=-
