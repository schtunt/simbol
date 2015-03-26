# vim: tw=0:ts=4:sw=4:et:ft=bash

core:import util

:<<[core:docstring]
The module does X, Y and Z
[core:docstring]

function :template:funk:cached() { echo 3; }
function :template:funk() {
  #local l_CACHE_SIG="optional-custom-sinature-hash:template:funk/$3";
  #local -i l_CACHE_TTL=0
  g_CACHE_OUT "$*" || {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        echo "*** main function logic ***"
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi
  } > ${g_CACHE_FILE?}; g_CACHE_IN; return $?
}

function template:funk:alert() {
    cat <<!
TODO This is mynewfn, alas it does nothing interesting
WARN Well it does demonstrate the various alerts such as this warning
FIXME Critical issues can also be communicated in the same way
DEPR Once you deprecated a function, don't delete it, just add an alert
!
}
function template:funk:shflags() {
    cat <<!
boolean mybool false "some-bool-setting" b
!
}
function template:funk:help() {
    cat <<!
<mandatory> [<optional:default>]
!
}
function template:funk:cachefile() { echo $1; }
function template:funk:cached() { echo 10; }
function template:funk:usage() { echo "<mandatory> [<optional:default>]"; }
function template:funk() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -le 1 ]; then
        local mandatory=${1}
        local optional="${2:-default}"
        :template:funk "${mandatory}" "${optional}"
        if [ $e -eq ${CODE_SUCCESS?} ]; then
            theme HAS_PASSED
        else
            theme HAS_FAILED
        fi
    fi

    return $e
}
