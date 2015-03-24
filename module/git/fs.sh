# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Git FS module that uses the .git/ directory exclusively
[core:docstring]

#. Git Filesystem Tasks -={

#. git.fs:basedir -={
function :git.fs:basedir() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local filename="${1}"

        if [ "${filename:0:1}" != '/' ]; then
            local cwd="$(pwd)"
            filename="$(readlink -m "${cwd}/${filename}")"
        else
            filename="$(readlink -m "${filename}")"
        fi

        local found=0
        local gitbasedir="${filename}"
        while [ ${found} -eq 0 -a "${gitbasedir}" != "/" ]; do
            if [ -d "${gitbasedir}/.git" ]; then
                found=1
                filename=.$(readlink -m  "${filename/${gitbasedir/./}}")
                e=${CODE_SUCCESS?}
            else
                gitbasedir=$(readlink -m "${gitbasedir}/..")
            fi
        done

        if [ $e -eq ${CODE_SUCCESS?} ]; then
            echo "${gitbasedir}" "${filename}"
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. git.fs:objects -={
function :git.fs:objects() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local gitbasedir="${1}"
        if [ -d ${gitbasedir}/.git/objects/ ]; then
            find ${gitbasedir}/.git/objects/ -type f -printf '%h%f\n' |
                cut -c $((${#gitbasedir}+15))- |
                grep -E '^[a-f0-9]{40}$'
            e=${PIPESTATUS[0]}
        else
            core:log ALERT "No such directory \`${gitbasedir}/.git/objects/'"
            core:raise EXCEPTION_BAD_FN_CALL
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. git.fs:branchildren -={
function :git.fs:branchildren() {
    if [ $# -eq 1 ]; then
        local parent="$1"
        (
            [ ! -d .git/refs/heads/${parent} ] ||
                find .git/refs/heads/${parent}/ -type f -printf '%h/%f\n'
            [ ! -f .git/packed-refs ] ||
                awk '$2~/refs\/heads\/'${parent}'/{printf(".git/%s\n",$2)}' .git/packed-refs
        ) | sort -u | cut -c17-
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi
}
#. }=-
#. git.fs:size -={
function git.fs:size:usage() { echo "[<git-path:pwd>]"; }
function git.fs:size() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 -o $# -eq 1 ]; then
        e=${CODE_FAILURE?}

        local cwd=$(pwd)
        local data
        data=$(:git.fs:basedir ${1:-${cwd}})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            read gitbasedir gitrelpath <<< "${data}"
            cd ${gitbasedir}
            git l|wc -l|tr '\n' ' '
            du -sh .git|awk '{print $1}'
            git count-objects -v
            e=$?
        else
            theme ERR_USAGE "Not a git repository:${1:-${cwd}}"
        fi
    fi

    return $e
}
#. }=-
#. git.fs:usage -={
function git.fs:usage:usage() { echo "[<git-path:pwd>]"; }
function git.fs:usage() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 -o $# -eq 1 ]; then
        e=${CODE_FAILURE?}

        local cwd=$(pwd)
        read gitbasedir gitrelpath <<< $(:git.fs:basedir ${1:-${cwd}})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            cd ${gitbasedir}

            #. Process .git/objects/pack
            if [ -d .git/objects/pack ]; then
                while read sha1 obj size; do
                    cpf "%{y:%-6s} %{@int:%8s} %{@hash:%s}" "${obj}" "${size}" "${sha1}"
                    read sha1 path <<< $(git rev-list --objects --all | grep ${sha1})
                    if [ -e "${path}" ]; then
                        cpf " %{@path:%s}" "${path}"
                    else
                        cpf " %{@bad_path:%s}" "${path}"
                        [ ! -z "$(git log -- "${path}")" ] || cpf " [%{@warn:PACK_ONLY}]"
                    fi
                    echo
                done < <(
                    git verify-pack -v .git/objects/pack/pack-*.idx\
                        | grep -E '^[a-f0-9]{40}'\
                        | sort -k 3 -n\
                        | awk '{print$1,$2,$3}'\
                )
                e=$?
                if [ -d .git/refs/original/ -o -d .git/logs/ ]; then
                    theme NOTE "You should run git.sink:vacuum to reflect recent changes"
                fi
            fi

            #. Process .git/objects/
            #. TODO: find .git/objects/ -type f -printf '%f\n'|grep -E '[a-f0-9]{32}'
        else
            theme ERR_USAGE "Error: that path is not within a git repository."
            e=${CODE_FAILURE?}
        fi
    fi
    return $e
}
#. }=-

#. }=-
