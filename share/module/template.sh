# vim: tw=0:ts=4:sw=4:et:ft=bash

core:import util

:<<[core:docstring]
The module does X, Y and Z
[core:docstring]

function :template:funk:cached() { echo 3; }
function :template:funk() {
  core:raise_bad_fn_call_unless $# in 2

  #local l_CACHE_SIG="optional-custom-sinature-hash:template:funk/$3";
  #local -i l_CACHE_TTL=0
  g_CACHE_OUT "$*" || {
    local -i e; let e=CODE_FAILURE
    echo "*** main function logic ***"
    e=$?
    core:return $e
  } > "${g_CACHE_FILE?}"; g_CACHE_IN; return $?
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
function template:funk:cachefile() { echo "$1"; }
function template:funk:cached() { echo 10; }
function template:funk:usage() { echo "<mandatory> [<optional:default>]"; }
function template:funk() {
    local -i e; let e=CODE_DEFAULT
    [ $# -le 1 ] || return $e

    local mandatory=${1}
    local optional="${2:-default}"
    if :template:funk "${mandatory}" "${optional}"; then
        let e=CODE_SUCCESS
        theme HAS_PASSED
    else
        let e=CODE_FAILURE
        theme HAS_FAILED
    fi

    return $e
}
