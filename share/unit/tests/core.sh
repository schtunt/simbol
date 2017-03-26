# vim: tw=0:ts=4:sw=4:et:ft=bash

declare -g counter=2
function coreCacheTester() {
    local -i e

    local l_CACHE_SIG='cache-test'
    local -i l_CACHE_TTL=$1

    core:global g.counter ${counter}
    counter=$(core:global g.counter)
    case $2 in
        up)
          g_CACHE_OUT || {
            core:global g.counter $((counter+=100))
            e=$?
          } > ${g_CACHE_FILE?}; g_CACHE_IN; e=$?
        ;;
        down)
          g_CACHE_OUT || {
            core:global g.counter $((counter-=10))
            e=$?
          } > ${g_CACHE_FILE?}; g_CACHE_IN; e=$?
        ;;
        jump)
          g_CACHE_OUT || {
            core:global g.counter $((counter+=1000))
            e=$?
          } > ${g_CACHE_FILE?}; g_CACHE_IN; e=$?
        ;;
    esac

    counter=$(core:global g.counter)

    return $e
}

function testCoreUnsupportedAssociativeArrayAssignments() {
    local vetted
    vetted="$(md5sum <(git grep -E '[a-zA-Z0-9]+\+=\( *\['))"
    assertEquals '0.0.1' '09a2684a0023bdd670ad455efbd74d8e' "${vetted%% *}"
}

function testCoreGlobalArithmeticFailure() {
    core:global g.num 1024
    local -i v=$(core:global g.num)
    assertEquals "${FUNCNAME?}/1.1" 1024 $v

    core:global g.num += 'JOKER'
    assertFalse "${FUNCNAME?}/1.2" $?

    v=$(core:global g.num)
    assertEquals "${FUNCNAME?}/1.3" 1024 $v
}

function testCoreGlobalArithmeticSuccess() {
    core:global g.str 'BATMAN'

    core:global g.num 1024
    local -i v=0
    v=$(core:global g.num)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1" 1024 $v

    core:global g.num += 1024
    v=$(core:global g.num)
    assertEquals "${FUNCNAME?}/1" 2048 $v
}

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
    v=$(core:global g.variable)

    assertEquals "${FUNCNAME?}/1" 2600 $v
}

function testCoreMockEnv() {
    assertTrue "${FUNCNAME?}/0" '[ ${#SIMBOL_USER_MOCKENV} -gt 0 ]'

    local -i size

    ::core:mock_writer clear
    assertTrue "${FUNCNAME?}/1.1" $?
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}")
    assertEquals "${FUNCNAME?}/1.2" 0 ${size}

    ::core:mock_writer set <<!
        declare -A BATMAN=( [k1]="0xDEADBEEF" )
!
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}")
    assertTrue "${FUNCNAME?}/2.1" '[ ${size} -gt 0 ]'
    grep -q 'BATMAN' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/2.2.1" $?
    grep -q 'JOKER' "${SIMBOL_USER_MOCKENV?}"
    assertFalse "${FUNCNAME?}/2.2.2" $?
    grep -q '0xDEADBEEF' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/2.2.3" $?
    size=$(cat "${SIMBOL_USER_MOCKENV?}"|wc -l)
    assertEquals "${FUNCNAME?}/2.2.4" 1 ${size}

    ::core:mock_writer append <<!
        declare -A JOKER=( [k1]="0xDEADBEEF" )
!
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}")
    assertTrue "${FUNCNAME?}/3.1" '[ ${size} -gt 0 ]'
    grep -q 'BATMAN' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/3.2.1" $?
    grep -q 'JOKER' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/3.2.2" $?
    grep -q '0xDEADBEEF' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/3.2.3" $?
    size=$(cat "${SIMBOL_USER_MOCKENV?}"|wc -l)
    assertEquals "${FUNCNAME?}/3.2.4" 2 ${size}

    ::core:mock_writer clear
    assertTrue "${FUNCNAME?}/4.1" $?
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}")
    assertEquals "${FUNCNAME?}/4.2" 0 ${size}
}

function testCoreMockWriter() {
    assertTrue "${FUNCNAME?}/0" '[ ${#SIMBOL_USER_MOCKENV} -gt 0 ]'

    local -i size

    ::core:mock_writer clear
    assertTrue "${FUNCNAME?}/1.1" $?
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}")
    assertEquals "${FUNCNAME?}/1.2" 0 ${size}

    ::core:mock_writer set <<!
        declare -A BATMAN=( [k1]="0xDEADBEEF" )
!
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}")
    assertTrue "${FUNCNAME?}/2.1" '[ ${size} -gt 0 ]'
    grep -q 'BATMAN' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/2.2.1" $?
    grep -q 'JOKER' "${SIMBOL_USER_MOCKENV?}"
    assertFalse "${FUNCNAME?}/2.2.2" $?
    grep -q '0xDEADBEEF' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/2.2.3" $?
    size=$(cat "${SIMBOL_USER_MOCKENV?}"|wc -l)
    assertEquals "${FUNCNAME?}/2.2.4" 1 ${size}

    ::core:mock_writer append <<!
        declare -A JOKER=( [k1]="0xDEADBEEF" )
!
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}")
    assertTrue "${FUNCNAME?}/3.1" '[ ${size} -gt 0 ]'
    grep -q 'BATMAN' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/3.2.1" $?
    grep -q 'JOKER' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/3.2.2" $?
    grep -q '0xDEADBEEF' "${SIMBOL_USER_MOCKENV?}"
    assertTrue "${FUNCNAME?}/3.2.3" $?
    size=$(cat "${SIMBOL_USER_MOCKENV?}"|wc -l)
    assertEquals "${FUNCNAME?}/3.2.4" 2 ${size}

    ::core:mock_writer clear
    assertTrue "${FUNCNAME?}/4.1" $?
    size=$(stat --printf '%s\n' "${SIMBOL_USER_MOCKENV?}")
    assertEquals "${FUNCNAME?}/4.2" 0 ${size}
}

function testCoreMockStartStop() {
    rm -f ${SIMBOL_USER_MOCKENV?}

    target_type="$(type -t whoami)"
    assertEquals "${FUNCNAME?}/1.1" 'file' "${target_type}"
    core:mock whoami 'echo "BATMAN"'

    [ -e ${SIMBOL_USER_MOCKENV?} ]
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qFw BATMAN ${SIMBOL_USER_MOCKENV?}
    assertTrue "${FUNCNAME?}/1.3" $?

    target_type="$(type -t whoami)"
    assertEquals "${FUNCNAME?}/1.4" 'file' "${target_type}"

    core:mockery start

    target_type="$(type -t whoami)"
    assertEquals "${FUNCNAME?}/1.5" 'function' "${target_type}"

    core:unmock whoami

    target_type="$(type -t whoami)"
    assertEquals "${FUNCNAME?}/1.6" 'file' "${target_type}"

    [ -e ${SIMBOL_USER_MOCKENV?} ]
    assertTrue "${FUNCNAME?}/1.7" $?

    core:mockery stop
    local -i size=$(stat --printf "%s" ${SIMBOL_USER_MOCKENV?})
    assertEquals "${FUNCNAME?}/1.8" 0 ${size}
}

function testCoreMockExecutable() {
    local target_type

    target_type="$(type -t ls)"
    assertEquals "${FUNCNAME?}/1.1" 'file' "${target_type}"
    core:mock ls 'echo Boom!'

    core:mockery start

    target_type="$(type -t ls)"
    assertEquals "${FUNCNAME?}/1.2" 'function' "${target_type}"

    core:unmock ls

    target_type="$(type -t ls)"
    assertEquals "${FUNCNAME?}/1.3" 'file' "${target_type}"

    core:mockery stop
    assertEquals "${FUNCNAME?}/1.3" 'file' "${target_type}"
}

function testCoreMockEnvString() {
    BATMAN='Unknown'

    core:mock BATMAN 'Bruce Wayne'
    assertEquals "${FUNCNAME?}/1" 'Unknown' "${BATMAN?}"

    core:mockery start
    assertEquals "${FUNCNAME?}/2" 'Bruce Wayne' "${BATMAN?}"

    core:unmock BATMAN
    assertEquals "${FUNCNAME?}/3" 'Unknown' "${BATMAN?}"

    core:mockery stop
    assertEquals "${FUNCNAME?}/3" 'Unknown' "${BATMAN?}"
}

function testCoreMockEnvArray() {
    JOKER=( 'Unknown' )

    core:mock JOKER "( 'Red' 'Hood' )"
    assertEquals "${FUNCNAME?}/1.1" 1 "${#JOKER[@]}"
    assertEquals "${FUNCNAME?}/1.2" 'Unknown' "${JOKER[0]}"

    core:mockery start

    assertEquals "${FUNCNAME?}/2.1" 2 "${#JOKER[@]}"
    assertEquals "${FUNCNAME?}/2.2" 'Red' "${JOKER[0]}"
    assertEquals "${FUNCNAME?}/2.3" 'Hood' "${JOKER[1]}"

    core:unmock JOKER
    assertEquals "${FUNCNAME?}/3.1" 1 "${#JOKER[@]}"
    assertEquals "${FUNCNAME?}/3.2" 'Unknown' "${JOKER[0]}"

    core:mockery stop
    assertEquals "${FUNCNAME?}/4.1" 1 "${#JOKER[@]}"
    assertEquals "${FUNCNAME?}/4.2" 'Unknown' "${JOKER[0]}"
}


function testCoreMockEnvArrayDeclared() {
    declare -a BATMAN=( 'Unknown' )

    core:mock BATMAN "( 'Bruce' 'Wayne' )"
    assertEquals "${FUNCNAME?}/1.1" 1 "${#BATMAN[@]}"
    assertEquals "${FUNCNAME?}/1.2" 'Unknown' "${BATMAN[0]}"

    core:mockery start

    assertEquals "${FUNCNAME?}/2.1" 2 "${#BATMAN[@]}"
    assertEquals "${FUNCNAME?}/2.2" 'Bruce' "${BATMAN[0]}"
    assertEquals "${FUNCNAME?}/2.3" 'Wayne' "${BATMAN[1]}"

    core:unmock BATMAN
    assertEquals "${FUNCNAME?}/3.1" 1 "${#BATMAN[@]}"
    assertEquals "${FUNCNAME?}/3.2" 'Unknown' "${BATMAN[0]}"

    core:mockery stop
    assertEquals "${FUNCNAME?}/4.1" 1 "${#BATMAN[@]}"
    assertEquals "${FUNCNAME?}/4.2" 'Unknown' "${BATMAN[0]}"
}

function testCoreMockEnvAssoc() {
    declare -A FIGHTERS
    FIGHTERS=( ['Ryu']='left' ['Ken']='right' )

    core:mock FIGHTERS "( ['Vega']='left' ['Bison']='right' ['ShengLong']='top' )"
    assertEquals "${FUNCNAME?}/1.1" 2 "${#FIGHTERS[@]}"
    assertEquals "${FUNCNAME?}/1.2" 'left' "${FIGHTERS['Ryu']}"
    assertEquals "${FUNCNAME?}/1.3" 'right' "${FIGHTERS['Ken']}"

    core:mockery start

    assertEquals "${FUNCNAME?}/2.1" 3 "${#FIGHTERS[@]}"
    assertEquals "${FUNCNAME?}/2.2" 'left' "${FIGHTERS['Vega']}"
    assertEquals "${FUNCNAME?}/2.3" 'right' "${FIGHTERS['Bison']}"
    assertEquals "${FUNCNAME?}/2.4" 'top' "${FIGHTERS['ShengLong']}"

    core:unmock FIGHTERS
    assertEquals "${FUNCNAME?}/3.1" 2 "${#FIGHTERS[@]}"
    assertEquals "${FUNCNAME?}/3.2" 'left' "${FIGHTERS['Ryu']}"
    assertEquals "${FUNCNAME?}/3.3" 'right' "${FIGHTERS['Ken']}"

    core:mockery stop
    assertEquals "${FUNCNAME?}/4.1" 2 "${#FIGHTERS[@]}"
    assertEquals "${FUNCNAME?}/4.2" 'left' "${FIGHTERS['Ryu']}"
    assertEquals "${FUNCNAME?}/4.3" 'right' "${FIGHTERS['Ken']}"
}

function exitWith() {
  g_CACHE_OUT || {
    md5sum <<< "$(date +%N)" | cut -b 1-32
    core:return $1
  } > ${g_CACHE_FILE?}; g_CACHE_IN; return $?
}

function testCoreCacheExit() {
    #. Negative returns do not get cached...
    for i in {1..2}; do
        exitWith 1
        assertEquals "0.1.1.$i" 1 $?

        exitWith 9
        assertEquals "0.1.2.$i" 9 $?

        exitWith 99
        assertEquals "0.1.3.$i" 99 $?
    done

    #. Positive ones do...
    local o1
    o1="$(exitWith 0)"
    assertTrue "0.2.1" $?

    local o2
    o2=$(exitWith 0)
    assertTrue "0.2.2.1" $?
    assertEquals "0.2.2.2" "${o1}" "${o2}"

    local o3
    o3=$(exitWith 0)
    assertTrue "0.2.3.1" $?
    assertEquals "0.2.3.2" "${o1}" "${o3}"
}

function testCoreCache() {
    local -i hit

    assertEquals '0.1.1' 2 $counter

    for hit in {1..3}; do
        coreCacheTester 3 up
        assertEquals "0.2.${hit}.1" 102 $counter
        coreCacheTester 3 down
        assertEquals "0.2.${hit}.2" 102 $counter
    done
    sleep 2

    coreCacheTester 1 jump
    assertEquals "0.3" 1102 $counter
    for hit in {1..3}; do
        coreCacheTester 3 up
        assertEquals "0.3.${hit}.1" 1102 $counter
        coreCacheTester 3 down
        assertEquals "0.3.${hit}.2" 1102 $counter
    done
    sleep 4

    for hit in {1..3}; do
        coreCacheTester 3 down
        assertEquals "0.4.${hit}.1" 1092 $counter
        coreCacheTester 3 up
        assertEquals "0.4.${hit}.2" 1092 $counter
    done
}
