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

function testCoreGlobal() {
    local -i v=0

    core:global g.variable 1024

    v=$(core:global g.variable)
    assertEquals "0.1" 1024 $v

    core:global g.variable $(($v+1024))
    v=$(core:global g.variable)
    assertEquals "0.1" 2048 $v

    core:global g.variable $(($v+1024)) | {
        v=$(core:global g.variable)
        core:global g.variable $(($v+1024))
    }

    v=$(core:global g.variable)
    assertEquals "0.1" 4096 $v
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
