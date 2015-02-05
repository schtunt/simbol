# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import net

function testCoreTunnelImport() {
    core:softimport tunnel
    assertEquals 0 $?
}

function tunnelTearDown() {
    : noop
    #sudo rm -rf ~root/.ssh
    #rm -rf ~/.ssh/id_rsa.pub
    #rm -rf ~/.ssh/id_rsa
}

function tunnelSetUp() {
    case ${g_MODE?} in
        prime)
            : noop
        ;;
        execute)
            export g_PID=0
        ;;
        *)
            exit 127
        ;;
    esac
}

function test_1_0_CoreTunnelStartPublic() {
    core:import tunnel

    core:wrapper tunnel start host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}

function test_1_1_CoreTunnelStartInternal() {
    core:import tunnel

    :tunnel:start host-8c.unit-tests.mgmt.simbol 22
    assertEquals "0x2" ${CODE_E01?} $?
}

function test_1_2_CoreTunnelStartPublic() {
    core:import tunnel

    core:wrapper tunnel start host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}

function test_1_3_CoreTunnelCreateInternal() {
    core:import tunnel

    :net:localportping 8000
    assertFalse "0x1" $?

    :tunnel:create - host-8c.unit-tests.mgmt.simbol localhost 8000 localhost 22
    assertTrue "0x2" $?

    :net:localportping 8000
    assertTrue "0x3" $?

    :tunnel:create - host-8c.unit-tests.mgmt.simbol localhost 8000 localhost 22
    assertEquals "0x4" ${CODE_E01?} $?
}

function test_1_4_CoreTunnelCreatePublic() {
    core:import tunnel

    core:wrapper tunnel create host-8c.unit-tests.mgmt.simbol\
        -l localhost 8000 -r localhost 22 >${stdoutF?} 2>${stderrF?}
    assertEquals "0x4" ${CODE_E01?} $?
}

function test_1_5_CoreTunnelStatusPublic() {
    core:import tunnel

    core:wrapper tunnel status host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x0" $?
}

function test_1_6_CoreTunnelPidInternal() {
    core:import tunnel

    g_PID=$(:tunnel:pid host-8c.unit-tests.mgmt.simbol)
    assertTrue "0x1" $?

    [ ${g_PID} -gt 0 ]
    assertTrue "0x1" $?
}

function test_1_7_CoreTunnelListInternal() {
    core:import tunnel

    local ports
    ports=$(:tunnel:list ${g_PID})
    assertTrue "0x1" $?

    [ ${ports} -eq 8000 ]
    assertTrue "0x2" $?
}

function test_1_8_CoreTunnelStopInternal() {
    core:import tunnel

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
    core:import tunnel

    core:wrapper tunnel stop host-8c.unit-tests.mgmt.simbol >${stdoutF?} 2>${stderrF?}
    assertTrue "0x1" $?
}
