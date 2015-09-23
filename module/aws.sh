# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
AWS CLI
[core:docstring]

#. AWS Cloud Formation -={

core:requires PYTHON boto
core:requires PYTHON awscli
core:requires PYTHON dateutils
core:requires PYTHON jmespath
core:requires PYTHON docutils
core:requires PYTHON rsa

core:import py

#. aws:cli -={
function aws:cli() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -gt 0 ]; then
        py:run aws "${@}" | jq .
        if [ $? -eq 0 ]; then
            e=${CODE_SUCCESS?}
        else
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. aws:selfcheck -={
function aws:selfcheck() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 ]; then
        e=${CODE_SUCCESS?}

        cpf "Dependency check..."
        local dep
        for dep in boto awscli dateutils jmespath docutils rsa; do
            if :xplm:requires py ${dep}; then
                cpf '.'
            else
                cpf '![%s]' "${dep}"
                e=${CODE_FAILURE?}
            fi
        done
        cpf '...'

        theme HAS_AUTOED $e
    fi
}
#. }=-

#. }=-
