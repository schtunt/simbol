# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Auxiliary Git helper module
[core:docstring]

#.  Git -={
core:requires git
core:import git.fs

#. git.flow:explorebranch -={
function :git.flow:explorebranch() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 3 ]; then
        local gitbasedir="$1"
        local gitrelpath="$2"
        local branch="$3"

        cd ${gitbasedir}

        local gfdb
        gfdb=$(git config gitflow.branch.develop)
        if [ $? -eq 0 ]; then
            local -a gffbs=( $(:git.fs:branchildren ${branch}))
            local gfdbsha1=$(git rev-parse ${gfdb})

            local gffbsha1
            local gffb
            for gffb in ${gffbs[@]}; do
                gffbsha1=$(git merge-base ${gfdb} ${gffb})
                if [ ${gffbsha1} == ${gfdbsha1} ]; then
                    cpf "%s %s\n" ${gffb} "+$(git rev-list ${gfdb}..${gffb}|wc -l)"
                else
                    cpf "%s %s\n" ${gffb} "-$(git rev-list ${gffb}..${gfdb}|wc -l)"
                fi
            done

            e=${CODE_SUCCESS?}
        fi
    fi

    return $e
}
#. }=-
#. git.flow:list -={
function git.flow:list:usage() { echo "[<git-path:pwd>] <branch-prefix>"; }
function git.flow:list() {
    e=${CODE_DEFAULT?}

    local branch
    local cwd
    case $# in
        1)
            cwd=$(pwd)
            branch="${1}"
            e=${CODE_SUCCESS?}
        ;;
        2)
            cwd=${1}
            branch="${2}"
            e=${CODE_SUCCESS?}
        ;;
    esac

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        local data
        data=$(:git.fs:basedir ${cwd})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            read gitbasedir gitrelpath <<< "${data}"

            local gfdb
            gfdb=$(git config gitflow.branch.develop)
            if [ $? -eq 0 ]; then
                local gffb
                local delta
                while read -a datum; do
                    gffb=${datum[0]}
                    delta=${datum[1]}
                    cpf "%{@hash:%s}->%{c:%s}..." $(git rev-parse ${gffb}) ${gffb}
                    if [ ${delta:0:1} == '+' ]; then
                        theme HAS_PASSED ${delta}
                    elif [ ${delta:0:1} == '-' ]; then
                        theme HAS_FAILED ${delta}
                    else
                        theme HAS_FAILED ${delta}
                    fi
                done < <(:git.flow:explorebranch ${gitbasedir} ${gitrelpath} ${branch})
            else
                theme ERR_USAGE "Not a git-flow repository:${cwd}"
                e=${CODE_FAILURE?}
            fi
        else
            theme ERR_USAGE "Not a git repository:${cwd}"
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
