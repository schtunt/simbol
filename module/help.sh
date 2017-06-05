# vim: tw=0:ts=4:sw=4:et:ft=bash
:<<[core:docstring]
Core help module
[core:docstring]

#. Help -={

#. help:all -={
function help:all() {
    local -i e; let e=CODE_DEFAULT

    if [ $# -eq 0 ]; then
        local _profile
        #shellcheck disable=SC2034
        for _profile in USER_MODULES CORE_MODULES; do
            #. Initialize the ${profile} variable
            eval "$(::core:dereference.eval _profile)"
            local module
            #shellcheck disable=SC2154
            for module in "${!profile[@]}"; do
                :core:usage ${module}
            done
            echo
        done
        e=${CODE_SUCCESS?}
    fi

    return $e
}
#. }=-
#. help:module -={
function help:module:usage() { echo "<module> [<function>]"; }
function help:module() {
    local -i e; let e=CODE_DEFAULT

    if [ $# -eq 1 ]; then
        :core:usage ${1}
        e=$?
    elif [ $# -eq 2 ]; then
        if core:softimport ${1}; then
            :core:usage ${1} ${2} --long
            e=$?
        else
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. }=-
