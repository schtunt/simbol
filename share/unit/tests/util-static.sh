# vim: tw=0:ts=4:sw=4:et:ft=bash

function testCoreUtilImport() {
    core:softimport util
    assertEquals 0 $?
}

function testCoreUtilUndelimitInternal() {
    core:import util

    local -a array=( b a d b a b e )
    :util:join , array >${stdoutF?} 2>${stderrF?}
    assertTrue ':util:join.0' $?
    assertEquals ':util:join.1' $(cat ${stdoutF}) 'b,a,d,b,a,b,e'
}

function testCoreUtilJoinInternal() {
    core:import util

    local -a string="b${SIMBOL_DELIM}a${SIMBOL_DELIM}d${SIMBOL_DELIM}b${SIMBOL_DELIM}a${SIMBOL_DELIM}b${SIMBOL_DELIM}e"
    echo "${string}" | :util:undelimit >${stdoutF?} 2>${stderrF?}
    assertTrue ':util:undelimit.0' $?
    assertEquals ':util:undelimit.1' "$(cat ${stdoutF})" "$(cat <<!
b
a
d
b
a
b
e
!
)"
}

function testCoreUtilZipInternal() {
    core:import util

    local -a k=( {a..d} )
    local -a v=( {A..D} )
    :util:zip.eval k v >${stdoutF?} 2>${stderrF?}
    assertTrue ':util:zip.eval.0' $?
    assertEquals ':util:zip.eval.1' "$(cat ${stdoutF})" "(
[a]=A
[b]=B
[c]=C
[d]=D
)"
}

function testCoreUtilAnsi2htmlInternal() {
    core:import util

    for fgbg in 38 48 ; do #Foreground/Background
        for color in {0..256} ; do #Colors
            #Display the color
            echo -en "\e[${fgbg};5;${color}m ${color}\t\e[0m"
            #Display 10 colors per lines
            if [ $((($color + 1) % 10)) == 0 ] ; then
                echo #New line
            fi
        done
        echo #New line
    done | :util:ansi2html >${stdoutF?} 2>${stderrF?}
    #. TODO: Validate html syntax
}
