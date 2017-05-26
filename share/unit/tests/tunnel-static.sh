# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import net
core:import tunnel

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

function test_1_0_CoreTunnelStartPublic() {
    core:wrapper tunnel start host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}

function test_1_1_CoreTunnelStartInternal() {
    :tunnel:start host-8c.unit-tests.mgmt.simbol 22
    assertEquals "0x2" ${CODE_E01?} $?
}

function test_1_2_CoreTunnelStartPublic() {
    core:wrapper tunnel start host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}

function test_1_3_CoreTunnelCreateInternal() {
    :net:localportping 8000
    assertFalse "0x1" $?

    :tunnel:create host-8c.unit-tests.mgmt.simbol localhost 8000 localhost 22
    assertTrue "0x2" $?

    :net:localportping 8000
    assertTrue "0x3" $?

    :tunnel:create host-8c.unit-tests.mgmt.simbol localhost 8000 localhost 22
    assertEquals "0x4" ${CODE_E01?} $?
}

function test_1_4_CoreTunnelCreatePublic() {
    core:wrapper tunnel create host-8c.unit-tests.mgmt.simbol\
        -l localhost 8000 -r localhost 22 >${stdoutF?} 2>${stderrF?}
    assertEquals "0x4" ${CODE_E01?} $?
}

function test_1_5_CoreTunnelStatusPublic() {
    core:wrapper tunnel status host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x0" $?
}

function test_1_6_CoreTunnelPidInternal() {
    g_PID=$(:tunnel:pid host-8c.unit-tests.mgmt.simbol)
    assertTrue "0x1" $?

    [ ${g_PID} -gt 0 ]
    assertTrue "0x1" $?
}

function test_1_7_CoreTunnelListInternal() {
    local ports
    ports=$(:tunnel:list ${g_PID})
    assertTrue "0x1" $?

    [ ${ports} -eq 8000 ]
    assertTrue "0x2" $?
}

function test_1_8_CoreTunnelStopInternal() {
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

function test_1_9_CoreTunnelStopPublic() {
    core:wrapper tunnel stop host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}
