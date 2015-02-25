# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
AWS Cloud Formation
[core:docstring]

#. AWS Cloud Formation -={

core:requires PYTHON boto
core:requires PYTHON awscli
core:requires PYTHON dateutils
core:requires PYTHON jmespath
core:requires PYTHON docutils
core:requires PYTHON rsa

core:import util
core:import py
core:import net

#. aws.cf:exec -={
function :aws.cf:exec() {
    local -i e=${CODE_FAILURE?}

    if [ $# -gt 0 ]; then
        py:run aws cloudformation "${@}"
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. aws.cf:main -={
function aws.cf:main:usage() { echo "create <stack-name> <ami-id> <keyname>"; }
function aws.cf:main() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -gt 1 ]; then
        subcmd=$1
        case ${subcmd}:$# in
            create:4)
                local stack="$2"
                local ami="$3"
                local keyname="$4"
                local config="${SIMBOL_USER_TMP?}/cloudformation-${stack}.json"
                jq ".Resources.MyEc2Instance.Properties={\
                    \"ImageId\":\"${ami}\",\
                    \"KeyName\":\"${keyname}\"\
                }" ${SIMBOL_CORE_LIBJS?}/cloudformation.json > "${config}"
                ::aws:cmd cloudformation -- create-stack\
                    --stack-name "${stack}" --template-body "file://${config}"
            ;;
        esac
    fi

    return $e
}
#. }=-

#. }=-
