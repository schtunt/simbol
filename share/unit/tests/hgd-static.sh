# vim: tw=0:ts=4:sw=4:et:ft=bash

function testCoreHgdImport() {
    core:softimport hgd
    assertTrue 0x0 $?
}

function testCoreHgdSavePublic() { return 0; }
function testCoreHgdListPublic() { return 0; }
function testCoreHgdRenamePublic() { return 0; }
function testCoreHgdDeletePublic() { return 0; }
function testCoreHgdMultiPublic() {
    core:import hgd

    local session=${FUNCNAME}
    core:wrapper hgd save -T _ ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:save.0' $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC}/hgd.conf
    assertTrue 'hgd:save.1' $?

    core:wrapper hgd list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:list.0' $?
    assertEquals 'hgd:list.1' $(cat ${stdoutF?}|wc -l) 1

    core:wrapper hgd rename ${session} ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:renamed.0' $?
    grep -qE "\<${session}Renamed\>" ${SIMBOL_USER_ETC}/hgd.conf
    assertTrue 'hgd:renamed.1' $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC}/hgd.conf
    assertFalse 'hgd:renamed.2' $?
    core:wrapper hgd rename ${session}Renamed ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:renamed.3' $?

    core:wrapper hgd list ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertFalse 'hgd:list.2' $?
    core:wrapper hgd list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:list.3' $?
    assertEquals 'hgd:list.4' $(cat ${stdoutF?}|wc -l) 1

    core:wrapper hgd delete ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:delete.0' $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC}/hgd.conf
    assertFalse 'hgd:delete.1' $?
    core:wrapper hgd delete ${session} >${stdoutF?} 2>${stderrF?}
    assertFalse 'hgd:delete.2' $?
}

function testCoreHgdSaveInternal() { return 0; }
function testCoreHgdListInternal() { return 0; }
function testCoreHgdRenameInternal() { return 0; }
function testCoreHgdDeleteInternal() { return 0; }
function testCoreHgdMultiInternal() {
    core:import hgd

    local session=${FUNCNAME}
    :hgd:save _ ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:save.0' $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC}/hgd.conf
    assertTrue 'hgd:save.1' $?

    :hgd:list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:list.0' $?
    assertEquals 'hgd:list.1' $(cat ${stdoutF?}|wc -l) 1

    :hgd:rename ${session} ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:renamed.0' $?
    grep -qE "\<${session}Renamed\>" ${SIMBOL_USER_ETC}/hgd.conf
    assertTrue 'hgd:renamed.1' $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC}/hgd.conf
    assertFalse 'hgd:renamed.2' $?
    :hgd:rename ${session}Renamed ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:renamed.3' $?

    :hgd:list ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertFalse 'hgd:list.2' $?
    :hgd:list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:list.3' $?
    assertEquals 'hgd:list.4' $(cat ${stdoutF?}|wc -l) 1

    :hgd:delete ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue 'hgd:delete.0' $?
    grep -qE "\<${session}\>" ${SIMBOL_USER_ETC}/hgd.conf
    assertFalse 'hgd:delete.1' $?
    :hgd:delete ${session} >${stdoutF?} 2>${stderrF?}
    assertFalse 'hgd:delete.2' $?
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
