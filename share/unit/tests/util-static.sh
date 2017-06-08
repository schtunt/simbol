# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util

#. Util -={
function utilOneTimeSetUp() {
    : pass
}

function utilSetUp() {
    : pass
}

function utilTearDown() {
    : pass
}

function utilOneTimeTearDown() {
    : pass
}

#. testCoreUtilUndelimitInternal -={
function testCoreUtilUndelimitInternal() {
    # shellcheck disable=SC2034
    local -a array=( b a d b a b e )
    :util:join , array >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" 'b,a,d,b,a,b,e' "$(cat "${stdoutF}")"
}
#. }=-
#. testCoreUtilJoinInternal -={
function testCoreUtilJoinInternal() {
    local string="b${SIMBOL_DELIM?}a${SIMBOL_DELIM?}d${SIMBOL_DELIM?}"
    string+="b${SIMBOL_DELIM?}a${SIMBOL_DELIM?}b${SIMBOL_DELIM?}e"
    echo "${string}" | :util:undelimit >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "$(cat <<!
b
a
d
b
a
b
e
!
)" "$(cat "${stdoutF?}")"
}
#. }=-
#. testCoreUtilJoinInternalWithDelim -={
function testCoreUtilJoinInternalWithDelim() {
    local string="b,a,d,b,a,b,e"
    echo "${string}" | :util:undelimit , >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/1" "$(cat <<!
b
a
d
b
a
b
e
!
)" "$(cat "${stdoutF?}")"
}
#. }=-
#. testCoreUtilZipEvalInternal -={
function testCoreUtilZipEvalInternal() {
    # shellcheck disable=SC2034
    local -a k=( {a..d} )

    # shellcheck disable=SC2034
    local -a v=( {A..D} )

    :util:zip.eval k v >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "(
[a]=A
[b]=B
[c]=C
[d]=D
)" "$(cat "${stdoutF?}")"
}
#. }=-
#. testCoreUtilAnsi2htmlInternal -={
function testCoreUtilAnsi2htmlInternal() {
    local -i fgbg
    local -i color
    for fgbg in 38 48; do #Foreground/Background
        for color in {0..256}; do #Colors
            #Display the color
            echo -ne "\e[${fgbg};5;${color}m ${color}\t\e[0m"

            #Display 10 colors per lines
            if (( ((color + 1) % 10) == 0 )); then
                echo #New line
            fi
        done

        echo #New line
    done | :util:ansi2html >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    #. TODO: Validate html syntax
}
#. }=-
#. testCoreUtilLockfileInternal -={
function testCoreUtilLockfileInternal() {
    local lf; lf=$(mock:wrapper util :lockfile 111 222)
    assertTrue "${FUNCNAME?}/1.1" $?

    local ex; ex="${SIMBOL_USER_VAR_TMP?}/lock.111.222.sct"
    assertEquals "${FUNCNAME?}/1.2" "${ex}" "${lf}"
}
#. }=-
#. testCoreUtilLockInternal -={
function testCoreUtilLockInternal() {
    local lf="${SIMBOL_USER_VAR_TMP?}/lock.222.111.sct"
    rm -rf "${lf}"

    mock:wrapper util :lock on 111 222
    assertTrue "${FUNCNAME?}/1.1" $?

    test -d "${lf}"
    assertTrue "${FUNCNAME?}/1.2" $?

    mock:wrapper util :lock off 111 222
    assertTrue "${FUNCNAME?}/2.1" $?

    test -d "${lf}"
    assertFalse "${FUNCNAME?}/2.2" $?
}
#. }=-
#. }=-
