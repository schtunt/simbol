# vim: tw=0:ts=4:sw=4:et:ft=bash

#. Core -={
declare -ig g_COUNTER; let g_COUNTER=2
#. testCoreUnsupportedAssociativeArrayAssignments -={
function testCoreUnsupportedAssociativeArrayAssignments() {
    local vetted
    vetted="$(git grep -E '^[^#]*[a-zA-Z0-9]+\+=\( *\['|grep -v ^lib/libsh/libsimbol/sanity.sh)"
    assertEquals "${FUNCNAME[0]}/0" "" "${vetted}"
}
#. }=-
#. testCoreGlobalArithmeticFailure -={
function testCoreGlobalArithmeticFailure() {
    core:global g.num 1024
    local -i v; let v=$(core:global g.num)
    assertEquals "${FUNCNAME?}/1.1" 1024 $v

    core:global g.num += 'JOKER'
    assertFalse "${FUNCNAME?}/1.2" $?

    let v=$(core:global g.num)
    assertEquals "${FUNCNAME?}/1.3" 1024 $v
}
#. }=-
#. testCoreGlobalArithmeticSuccess -={
function testCoreGlobalArithmeticSuccess() {
    core:global g.str 'BATMAN'

    core:global g.num 1024
    local -i v; let v=$(core:global g.num)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" 1024 $v

    core:global g.num += 1024
    let v=$(core:global g.num)
    assertEquals "${FUNCNAME?}/2" 2048 $v
}
#. }=-
#. testCoreGlobalAtomicity -={
function testCoreGlobalAtomicity() {
    #. Generating subshells is easy...
    #.
    #.    function f() { cat; eval 'echo ${BASHPID}:${BASH_SUBSHELL}'; }
    #.
    #. Then call `f|(f|(f|f|)|f)` or something.  Here we use this to test
    #. atomicity.

    local -i v=2048
    core:global g.variable $v

    core:global g.variable += 512 | (
        core:global g.variable += 32
    )

    core:global g.variable += 8
    let v=$(core:global g.variable)

    assertEquals "${FUNCNAME?}/1" 2600 $v
}
#. }=-
#. testCoreMockEnv -={
function testCoreMockEnv() {
    #shellcheck disable=SC2016
    assertTrue "${FUNCNAME?}/0" '[ ${#SIMBOL_USER_MOCKENV} -gt 0 ]'
}
#. }=-
#. testCoreMockWrite -={
function testCoreMockWrite() {
    # Test creation of a mock context
    mock:write <<!
        declare -A BATMAN=( [k1]="0xDEADBEEF" )
!
    local -i size
    let size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}.default")
    #shellcheck disable=SC2016
    assertTrue "${FUNCNAME?}/2.1" '[ ${size} -gt 0 ]'

    grep -q 'BATMAN' "${SIMBOL_USER_MOCKENV?}.default"
    assertTrue "${FUNCNAME?}/2.2.1" $?

    grep -q 'JOKER' "${SIMBOL_USER_MOCKENV?}.default"
    assertFalse "${FUNCNAME?}/2.2.2" $?

    grep -q '0xDEADBEEF' "${SIMBOL_USER_MOCKENV?}.default"
    assertTrue "${FUNCNAME?}/2.2.3" $?

    let size=$(wc -l <"${SIMBOL_USER_MOCKENV?}.default")
    assertEquals "${FUNCNAME?}/2.2.4" 1 ${size}

    mock:write <<!
        declare -A JOKER=( [k1]="0xDEADBEEF" )
!
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}.default")
    #shellcheck disable=SC2016
    assertTrue "${FUNCNAME?}/3.1" '[ ${size} -gt 0 ]'

    grep -q 'BATMAN' "${SIMBOL_USER_MOCKENV?}.default"
    assertTrue "${FUNCNAME?}/3.2.1" $?

    grep -q 'JOKER' "${SIMBOL_USER_MOCKENV?}.default"
    assertTrue "${FUNCNAME?}/3.2.2" $?

    grep -q '0xDEADBEEF' "${SIMBOL_USER_MOCKENV?}.default"
    assertTrue "${FUNCNAME?}/3.2.3" $?

    let size=$(wc -l < "${SIMBOL_USER_MOCKENV?}.default")
    assertEquals "${FUNCNAME?}/3.2.4" 2 ${size}

    mock:clear
}
#. }=-
#. testCoreMockDelete -={
function testCoreMockDelete() {
    # Test deletion for default context
    echo : > "${SIMBOL_USER_MOCKENV?}.default"

    mock:clear default

    local -i size

    test -e "${SIMBOL_USER_MOCKENV?}.default"
    assertTrue "${FUNCNAME?}/1.1" $?
    let size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}.default" 2>/dev/null)
    assertEquals "${FUNCNAME?}/1.2" 0 ${size}

    # Test deletion for custom context
    echo : >"${SIMBOL_USER_MOCKENV?}.a"
    echo : >"${SIMBOL_USER_MOCKENV?}.b"
    echo : >"${SIMBOL_USER_MOCKENV?}.custom"

    mock:clear custom

    test -e "${SIMBOL_USER_MOCKENV?}.a"
    assertTrue "${FUNCNAME?}/2.1.1" $?
    let size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}.a" 2>/dev/null)
    assertEquals "${FUNCNAME?}/2.1.2" 2 ${size}

    test -e "${SIMBOL_USER_MOCKENV?}.b"
    assertTrue "${FUNCNAME?}/2.2.1" $?
    let size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}.b" 2>/dev/null)
    assertEquals "${FUNCNAME?}/2.2.2" 2 ${size}

    test -e "${SIMBOL_USER_MOCKENV?}.custom"
    assertTrue "${FUNCNAME?}/2.3.1" $?
    let size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}.custom" 2>/dev/null)
    assertEquals "${FUNCNAME?}/2.3.2" 0 ${size}

    # Test deletion of all mock contexts
    echo : >"${SIMBOL_USER_MOCKENV?}.default"
    mock:clear

    test -e "${SIMBOL_USER_MOCKENV?}.default"
    assertTrue "${FUNCNAME?}/3.1.1" $?
    let size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}.default" 2>/dev/null)
    assertEquals "${FUNCNAME?}/3.1.2" 0 ${size}

    test -e "${SIMBOL_USER_MOCKENV?}.a"
    assertFalse "${FUNCNAME?}/3.2" $?
    test -e "${SIMBOL_USER_MOCKENV?}.b"
    assertFalse "${FUNCNAME?}/3.3" $?
    test -e "${SIMBOL_USER_MOCKENV?}.custom"
    assertFalse "${FUNCNAME?}/3.4" $?
}
#. }=-
#. exitWith -={
function exitWith() {
  g_CACHE_OUT "$*" || {
    local -i e; let e=$1
    date +%s.%N
    core:return $e
  } > "${g_CACHE_FILE?}"; g_CACHE_IN; return $?
}
#. }=-
#. testCoreCacheExitDoesNotCacheNegatives -={
function testCoreCacheExitDoesNotCacheNegatives() {
    local o1; o1=$(exitWith 11)
    assertEquals "${FUNCNAME?}/1.1.1" 11 $?
    assertNotEquals "${FUNCNAME?}/1.1.2" "" "${o1}"

    local o2; o2=$(exitWith 11)
    assertEquals "${FUNCNAME?}/1.2.1" 11 $?
    assertNotEquals "${FUNCNAME?}/1.2.2" "" "${o2}"

    #. Negative returns do not get cached...
    assertNotEquals "${FUNCNAME?}/1.3" "${o1}" "${o2}"

    #. Especially given a different input!
    local o3; o3=$(exitWith 22)
    assertEquals "${FUNCNAME?}/2.1" 22 $?
    assertNotEquals "${FUNCNAME?}/2.2" "${o1}" "${o3}"
}
#. }=-
#. testCoreCacheExitDoesCachePositives -={
function testCoreCacheExitDoesCachePositives() {
    #. Positive ones do...
    local o1; o1=$(exitWith 0)
    assertTrue "${FUNCNAME?}/2.1" $?

    local o2; o2=$(exitWith 0)
    assertTrue "${FUNCNAME?}/2.2" $?

    assertEquals "${FUNCNAME?}/2.3" "${o1}" "${o2}"
}
#. }=-
#. coreCacheTester -={
function coreCacheTester() {
    core:raise_bad_fn_call_unless $# in 3
    local -i e

    #shellcheck disable=SC2034
    local l_CACHE_SIG='cache-test'

    #shellcheck disable=SC2034
    local -i l_CACHE_TTL=$1
    local op=$2
    local -i delta; let delta=$3

    core:global g.counter ${g_COUNTER}
    let g_COUNTER=$(core:global g.counter)

    case ${op} in
        up)
          g_CACHE_OUT || {
            core:global g.counter $((g_COUNTER+=delta))
            core:return $?
          } >"${g_CACHE_FILE?}"; g_CACHE_IN; let e=$?
        ;;
        down)
          g_CACHE_OUT || {
            core:global g.counter $((g_COUNTER-=delta))
            core:return $?
          } >"${g_CACHE_FILE?}"; g_CACHE_IN; let e=$?
        ;;
    esac

    let g_COUNTER=$(core:global g.counter)

    return $e
}
#. }=-
#. testCoreCache -={
function testCoreCache() {
    # The while loop in this function waits for the current second to expire;
    # with this logic.

    let g_COUNTER=g_COUNTER
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" 2 ${g_COUNTER}

    local -i hit
    local -i ttl; let ttl=1

    sleep $((ttl-1)); while (( 1$(date +%N) > 1100000000 )); do : noop; done
    coreCacheTester ${ttl} up 100
    assertEquals "${FUNCNAME?}/2" 102 ${g_COUNTER}
    for hit in {1..3}; do
        coreCacheTester ${ttl} up ${RANDOM}
        assertEquals "${FUNCNAME?}/2.${hit}.1" 102 ${g_COUNTER}
        coreCacheTester ${ttl} down ${RANDOM}
        assertEquals "${FUNCNAME?}/2.${hit}.2" 102 ${g_COUNTER}
    done

    sleep $((ttl-1)); while (( 1$(date +%N) > 1100000000 )); do : noop; done
    coreCacheTester ${ttl} up 1000
    assertEquals "${FUNCNAME?}/3" 1102 ${g_COUNTER}
    for hit in {1..3}; do
        coreCacheTester ${ttl} up ${RANDOM}
        assertEquals "${FUNCNAME?}/3.${hit}.1" 1102 ${g_COUNTER}
        coreCacheTester ${ttl} down ${RANDOM}
        assertEquals "${FUNCNAME?}/3.${hit}.2" 1102 ${g_COUNTER}
    done

    sleep $((ttl-1)); while (( 1$(date +%N) > 1100000000 )); do : noop; done
    coreCacheTester ${ttl} down 10
    assertEquals "${FUNCNAME?}/4" 1092 ${g_COUNTER}
    for hit in {1..3}; do
        coreCacheTester ${ttl} down ${RANDOM}
        assertEquals "${FUNCNAME?}/4.${hit}.1" 1092 ${g_COUNTER}
        coreCacheTester ${ttl} up ${RANDOM}
        assertEquals "${FUNCNAME?}/4.${hit}.2" 1092 ${g_COUNTER}
    done
}
#. }=-
#. }=-
