# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import hgd

#. HGD -={

function hgdOneTimeSetUp() {
    declare -g g_HGD_CACHE_MOCK="${SIMBOL_USER_VAR_TMP?}/hgd.conf"
}

function hgdSetUp() {
    mock:write <<- !MOCK
        declare -g g_HGD_CACHE="${g_HGD_CACHE_MOCK?}"
	!MOCK
}

function hgdTearDown() {
    rm -f ${g_HGD_CACHE_MOCK?}
    mock:clear
}

function hgdOneTimeTearDown() {
    rm -f ${g_HGD_CACHE_MOCK?}
}

#. testCoreHgdSavePublic -={
function testCoreHgdSavePublic() {
    local session=${FUNCNAME?}

    mock:wrapper hgd save ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?
    grep -qE "\<${session}\>" ${g_HGD_CACHE_MOCK?}
    assertTrue "${FUNCNAME?}/1.2" $?

    mock:wrapper hgd list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.0/list" $?
    local -i c; let c=$(wc -l < ${stdoutF?})
    assertEquals "${FUNCNAME?}/2.1/list" 1 $c
}
#. }=-
#. testCoreHgdListPublic -={
function testCoreHgdListPublic() {
    local session=${FUNCNAME?}

    mock:wrapper hgd save ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1/save" $?

    mock:wrapper hgd list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.1" $?
    local -i c; let c=$(wc -l < ${stdoutF?})
    assertEquals "${FUNCNAME?}/2.2" 1 $c
}
#. }=-
#. testCoreHgdRenamePublic -={
function testCoreHgdRenamePublic() {
    local session=${FUNCNAME?}

    mock:wrapper hgd save ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1/save" $?

    mock:wrapper hgd rename ${session} ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.1" $?
    grep -qE "\<${session}Renamed\>" ${g_HGD_CACHE_MOCK?}
    assertTrue "${FUNCNAME?}/2.2" $?
    grep -qE "\<${session}\>" ${g_HGD_CACHE_MOCK?}
    assertFalse "${FUNCNAME?}/2.3" $?

    mock:wrapper hgd rename ${session}Renamed ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/3.1" $?

    local -i c

    mock:wrapper hgd list ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/4.1/list" $?
    let c=$(wc -l < ${stdoutF?})
    assertEquals "${FUNCNAME?}/4.2/list" 1 $c

    mock:wrapper hgd list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/5.1/list" $?
    let c=$(wc -l < ${stdoutF?})
    assertEquals "${FUNCNAME?}/5.2/list" 1 $c
}
#. }=-
#. testCoreHgdDeletePublic -={
function testCoreHgdDeletePublic() {
    local session=${FUNCNAME?}

    mock:wrapper hgd save ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1/save" $?

    mock:wrapper hgd delete ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.2" $?
    grep -qE "\<${session}\>" ${g_HGD_CACHE_MOCK?}
    assertFalse "${FUNCNAME?}/2.2" $?

    mock:wrapper hgd delete ${session} >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/3.1" $?
}
#. }=-
#. testCoreHgdResolvePrivate -={
function testCoreHgdResolvePrivate() {
    local session="SessionA"

    mock:write <<!
declare -A USER_HGD_RESOLVERS=( [lower]="echo '%s' | tr 'A-Z' 'a-z'" )
!

    mock:wrapper hgd save ${session} '|(%lower=ABC,%lower=abc)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    mock:wrapper hgd resolve ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qE "\<abc\>" ${stdoutF?}
    assertTrue "${FUNCNAME?}/1.3" $?

    grep -qE "\<${session}\>" ${g_HGD_CACHE_MOCK?}
    assertTrue "${FUNCNAME?}/1.4" $?
}
#. }=-
#. testCoreHgdResolvePrivateKnownHosts -={
function testCoreHgdResolvePrivateKnownHosts() {
    local session="SessionB"

    cat <<! > /tmp/ssh_known_hosts
1.1.1.1 ssh-rsa AAAABCD
1.2.3.4 ssh-rsa AAAACDE
!
    mock:write <<!
SSH_KNOWN_HOSTS=/tmp/ssh_known_hosts
!

    mock:wrapper hgd save ${session?} '/^1\.1\..*/' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    local -i c

    mock:wrapper hgd resolve ${session?} >${stdoutF?} 2>${stderrF?}
    let c=$(wc -l < ${stdoutF?})
    assertEquals "${FUNCNAME?}/1.2" 1 $c

    grep -qFw "1.1.1.1" ${g_HGD_CACHE_MOCK?}
    assertTrue "${FUNCNAME?}/1.3" $?

    grep -qFw "1.2.3.4" ${g_HGD_CACHE_MOCK?}
    assertFalse "${FUNCNAME?}/1.4" $?

    mock:wrapper hgd save ${session?} '/^1\..*/' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.1" $?

    mock:wrapper hgd resolve '/^1\..*/' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2.2" $?
    let c=$(wc -l < ${stdoutF?})
    assertEquals "${FUNCNAME?}/2.2.2" 2 $c

    grep -qFw "1.1.1.1" ${g_HGD_CACHE_MOCK?}
    assertTrue "${FUNCNAME?}/2.3" $?

    grep -qFw "1.2.3.4" ${g_HGD_CACHE_MOCK?}
    assertTrue "${FUNCNAME?}/2.4" $?
}
#. }=-
#. testCoreHgdSaveInternal -={
function testCoreHgdSaveInternal() { return 0; }
#. }=-
#. testCoreHgdListInternal -={
function testCoreHgdListInternal() { return 0; }
#. }=-
#. testCoreHgdRenameInternal -={
function testCoreHgdRenameInternal() { return 0; }
#. }=-
#. testCoreHgdDeleteInternal -={
function testCoreHgdDeleteInternal() { return 0; }
#. }=-
#. testCoreHgdMultiInternal -={
function testCoreHgdMultiInternal() {
    local session=${FUNCNAME?}
    mock:wrapper hgd :save ${session} '|(#10.1.2.3/29)' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1" $?
    grep -qE "\<${session}\>" ${g_HGD_CACHE_MOCK?}
    assertTrue "${FUNCNAME?}/1.1" $?

    local -i c

    mock:wrapper hgd :list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2" $?
    let c=$(wc -l < ${stdoutF?})
    assertEquals "${FUNCNAME?}/2.1" 1 $c

    mock:wrapper hgd :rename ${session} ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/3" $?
    grep -qE "\<${session}Renamed\>" ${g_HGD_CACHE_MOCK?}
    assertTrue "${FUNCNAME?}/3.1" $?
    grep -qE "\<${session}\>" ${g_HGD_CACHE_MOCK?}
    assertFalse "${FUNCNAME?}/3,2" $?
    mock:wrapper hgd :rename ${session}Renamed ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/3.3" $?

    mock:wrapper hgd :list ${session}Renamed >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/4" $?
    mock:wrapper hgd :list ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/4.1" $?
    let c=$(wc -l < ${stdoutF?})
    assertEquals "${FUNCNAME?}/4.2" 1 $c

    mock:wrapper hgd :delete ${session} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/5" $?
    grep -qE "\<${session}\>" ${g_HGD_CACHE_MOCK?}
    assertFalse "${FUNCNAME?}/5.1" $?
    mock:wrapper hgd :delete ${session} >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/5.2" $?
}
#. }=-
#. testPySetsAND -={
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
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "ccc ddd" "$(cat ${stdoutF})"
}
#. }=-
#. testPySetsOR -={
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
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" \
        "aaa bbb eee fff ccc ddd" "$(cat ${stdoutF})"
}
#. }=-
#. testPySetsDIFF -={
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
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "aaa bbb" "$(cat ${stdoutF})"
}
#. }=-
