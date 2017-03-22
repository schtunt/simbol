# vim: tw=0:ts=4:sw=4:et:ft=bash

function hgdTearDown() {
    core:bashenv clear
    assertTrue ${FUNCNAME?} $?
}

function hgdSetUp() {
    core:bashenv clear
    assertTrue ${FUNCNAME?} $?
}

function testCoreHgdImport() {
    core:softimport hgd
    assertTrue 0x0 $?
}

function testCoreHgdSavePublic() {
    core:import hgd
    local session=${FUNCNAME?}

    core:wrapper hgd save -T _ ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertTrue "${FUNCNAME?}/1.2" $?

    core:wrapper hgd list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.0/list" $?
    assertEquals "${FUNCNAME?}/2.1/list" 1 $(wc -l < ${stdoutF?})
}
function testCoreHgdListPublic() {
    core:import hgd
    local session=${FUNCNAME?}

    core:wrapper hgd save -T _ ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1/save" $?

    core:wrapper hgd list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.1" $?
    assertEquals "${FUNCNAME?}/2.2" 1 $(wc -l < ${stdoutF?})
}
function testCoreHgdRenamePublic() {
    core:import hgd
    local session=${FUNCNAME?}

    core:wrapper hgd save -T _ ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1/save" $?

    core:wrapper hgd rename ${session} ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.1" $?
    grep -qE "\<${session}Renamed\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertTrue "${FUNCNAME?}/2.2" $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertFalse "${FUNCNAME?}/2.3" $?

    core:wrapper hgd rename ${session}Renamed ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/3.1" $?

    core:wrapper hgd list ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/4.1/list" $?
    assertEquals "${FUNCNAME?}/4.2/list" 1 $(wc -l < ${stdoutF?})

    core:wrapper hgd list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/5.1/list" $?
    assertEquals "${FUNCNAME?}/5.2/list" 1 $(wc -l < ${stdoutF?})
}
function testCoreHgdDeletePublic() {
    core:import hgd
    local session=${FUNCNAME?}

    core:wrapper hgd save -T _ ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1/save" $?

    core:wrapper hgd delete ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.2" $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertFalse "${FUNCNAME?}/2.2" $?

    core:wrapper hgd delete ${session} >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/3.1" $?
}
function test_1_CoreHgdResolvePrivate() {
    core:import hgd
    local session="SessionA"

    core:bashenv set <<!
        declare -A USER_HGD_RESOLVERS=( [lower]="echo '%s' | tr 'A-Z' 'a-z'" )
!
    core:wrapper hgd save -T _ ${session} '|(%lower=ABC,%lower=abc)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    core:wrapper hgd resolve -T _ ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qE "\<abc\>" ${stdoutF?}
    assertTrue "${FUNCNAME?}/1.3" $?

    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertTrue "${FUNCNAME?}/1.4" $?
}
function test_2_CoreHgdResolvePrivate() {
    core:import hgd
    local session="SessionB"

    cat <<! > /tmp/ssh_known_hosts
1.1.1.1 ssh-rsa AAAABCD
1.2.3.4 ssh-rsa AAAACDE
!
    core:bashenv set <<!
        SSH_KNOWN_HOSTS=/tmp/ssh_known_hosts
!

    core:wrapper hgd save -T _ ${session?} '/^1\.1\..*/' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    core:wrapper hgd resolve -T _ ${session?} >${stdoutF?} 2>${stderrF?}
    assertEquals "${FUNCNAME?}/1.2" 1 $(wc -l < ${stdoutF?})

    grep -qFw "1.1.1.1" ${SIMBOL_USER_ETC?}/hgd.conf
    assertTrue "${FUNCNAME?}/1.3" $?

    grep -qFw "1.2.3.4" ${SIMBOL_USER_ETC?}/hgd.conf
    assertFalse "${FUNCNAME?}/1.4" $?

    core:wrapper hgd save -T _ ${session?} '/^1\..*/' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.1" $?

    core:wrapper hgd resolve -T _ '/^1.*/' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.2" $?
    assertEquals "${FUNCNAME?}/2.2.2" 2 $(wc -l < ${stdoutF?})

    grep -qFw "1.1.1.1" ${SIMBOL_USER_ETC?}/hgd.conf
    assertTrue "${FUNCNAME?}/2.3" $?

    grep -qFw "1.2.3.4" ${SIMBOL_USER_ETC?}/hgd.conf
    assertTrue "${FUNCNAME?}/2.4" $?
}
function testCoreHgdSaveInternal() { return 0; }
function testCoreHgdListInternal() { return 0; }
function testCoreHgdRenameInternal() { return 0; }
function testCoreHgdDeleteInternal() { return 0; }
function testCoreHgdMultiInternal() {
    core:import hgd

    local session=${FUNCNAME?}
    :hgd:save _ ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertTrue "${FUNCNAME?}/1" $?

    :hgd:list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?
    assertEquals "${FUNCNAME?}/1" 1 $(wc -l < ${stdoutF?})

    :hgd:rename ${session} ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?
    grep -qE "\<${session}Renamed\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertTrue "${FUNCNAME?}/1" $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertFalse "${FUNCNAME?}/2" $?
    :hgd:rename ${session}Renamed ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/3" $?

    :hgd:list ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/2" $?
    :hgd:list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/3" $?
    assertEquals "${FUNCNAME?}/4" 1 $(wc -l < ${stdoutF?})

    :hgd:delete ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC?}/hgd.conf
    assertFalse "${FUNCNAME?}/1" $?
    :hgd:delete ${session} >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/2" $?
}

function testPySetsAND() {
    cat <<! | sets '&(nucky,rothstein,waxy)' >${stdoutF?} 2>${stderrF?}
nucky
aaa
bbb
ccc
ddd

rothstein
bbb
ccc
ddd
eee

waxy
ccc
ddd
eee
fff
!
    if assertEquals 0 $?; then
        assertEquals "ccc ddd" "$(cat ${stdoutF})"
    fi
}

function testPySetsOR() {
    cat <<! | sets '|(nucky,rothstein,waxy)' >${stdoutF?} 2>${stderrF?}
nucky
aaa
bbb
ccc
ddd

rothstein
bbb
ccc
ddd
eee

waxy
ccc
ddd
eee
fff
!
    if assertEquals 0 $?; then
        assertEquals "aaa bbb eee fff ccc ddd" "$(cat ${stdoutF})"
    fi
}

function testPySetsDIFF() {
    cat <<! | sets '!(nucky,rothstein)' >${stdoutF?} 2>${stderrF?}
nucky
aaa
bbb
ccc
ddd

rothstein
ccc
ddd
eee
fff
!
    if assertEquals 0 $?; then
        assertEquals "aaa bbb" "$(cat ${stdoutF})"
    fi
}
