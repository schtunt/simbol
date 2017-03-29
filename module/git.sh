# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Auxiliary Git helper module
[core:docstring]

#.  Git -={
core:requires git

#. git:basedir -={
function :git:basedir() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local cwd="$(pwd)"
        local filename="${1}"

        [ "${filename:0:1}" == '/' ] || filename="${cwd}/${filename}"

        local found=0
        local gitbasedir=$(readlink -m "${filename}")
        while [ ${found} -eq 0 -a "${gitbasedir}" != "/" ]; do
            if [ -d "${gitbasedir}/.git" ]; then
                found=1
            else
                gitbasedir=$(readlink -m "${gitbasedir}/..")
            fi
        done
        if [ ${found} -eq 1 ]; then
            echo ${gitbasedir} ${filename/${gitbasedir}\//./}
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. git:size -={
function git:size:usage() { echo "[<git-path:pwd>]"; }
function git:size() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 -o $# -eq 1 ]; then
        e=${CODE_FAILURE?}

        local cwd=$(pwd)
        local data
        data=$(:git:basedir ${1:-${cwd}})
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
#. git:usage -={
function git:usage:usage() { echo "[<git-path:pwd>]"; }
function git:usage() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 -o $# -eq 1 ]; then
        e=${CODE_FAILURE?}

        local cwd=$(pwd)
        read gitbasedir gitrelpath <<< $(:git:basedir ${1:-${cwd}})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            cd ${gitbasedir}
            if [ -d .git/objects/pack ]; then
                while read sha1 obj size; do
                    cpf "%{y:%-6s %8s} %{@hash:%s}" "${obj}" "${size}" "${sha1}"
                    read sha1 path <<< $(git rev-list --objects --all | grep ${sha1})
                    if [ -e "${path}" ]; then
                        cpf " %{@path:%s}" "${path}"
                    else
                        cpf " %{@bad_path:%s}" "${path}"
                        in_pack_only=$(git log -- "${path}")
                        if [ "${in_pack_only:-NilOrNotSet}" == 'NilOrNotSet' ]; then
                            cpf " [%{@warn:PACK_ONLY}]"
                        fi
                    fi
                    echo
                done < <(
                    git verify-pack -v .git/objects/pack/pack-*.idx\
                        | grep -E '^[a-f0-9]{40}'\
                        | sort -k 3 -n\
                        | tail -n 64\
                        | awk '{print$1,$2,$3}'\
                )
                e=$?
                if [ -d .git/refs/original/ -o -d .git/logs/ ]; then
                    theme NOTE "You should run git:vacuum to reflect recent changes"
                fi
            else
                theme ERR_USAGE "Error: could not chdir to ${1}"
                e=${CODE_FAILURE?}
            fi
        else
            theme ERR_USAGE "Error: that path is not within a git repository."
            e=${CODE_FAILURE?}
        fi
    fi
    return $e
}
#. }=-
#. git:rm -={
function git:rm:usage() { echo "<git-path-glob> [<git-path-glob> [...]]"; }
function git:rm() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 1 ]; then
        e=${CODE_FAILURE?}

        local cwd=$(pwd)
        for filename in "${@}"; do
            read gitbasedir gitrelpath <<< $(:git:basedir ${1})
            if [ $? -eq ${CODE_SUCCESS?} ]; then
                cd ${gitbasedir}

                git filter-branch\
                    --force\
                    --index-filter "git rm -rf --cached --ignore-unmatch ${gitrelpath}" \
                    --prune-empty --tag-name-filter cat -- --all

                e=${CODE_SUCCESS?}
            fi
        done
    fi

    return $e
}
#. }=-
#. git:vacuum -={
function git:vacuum:usage() { echo "<git-repo-dir>"; }
function git:vacuum() {
    local -i e=${CODE_DEFAULT?}
    if [ $# -eq 1 ]; then
        if pushd $1 >/dev/null 2>&1; then
            rm -Rf .git/refs/original/ .git/logs/
            e=$?
            if [ $e -eq 0 ]; then
                rm -Rf .git/refs/original/ .git/logs/
                git filter-branch --prune-empty
                git reflog expire --expire=now --all --expire-unreachable=${CODE_SUCCESS?}
                git gc --aggressive --prune=now
                git repack -a -d -f --depth=250 --window=250
                git prune --expire=${CODE_SUCCESS?} --progress
            fi
        else
            theme ERR_USAGE "Error: could not chdir to ${1}"
            e=${CODE_FAILURE?}
        fi
    fi
    return $e
}
#. }=-
#. git:file -={
function git:file:usage() { echo "<path-glob>"; }
function git:file() {
    local -i e=${CODE_DEFAULT?}
    if [ $# -eq 1 ]; then
        read gitbasedir gitrelpath <<< $(:git:basedir ${PWD?})
        if [ $? -eq 0 ]; then
            local sha1
            for sha1 in $(git log --pretty=format:'%h'); do
                if git diff-tree --no-commit-id --name-only -r ${sha1} | grep -qE "${1}"; then
                    printf '%s [ ' ${sha1}
                    git diff-tree --no-commit-id --name-only -r ${sha1} | tr '\n' ' '
                    git log -1 --pretty=format:'] -- %s' ${sha1}
                    echo
                fi
            done | grep --color '\[.*\] --';
            e=${CODE_SUCCESS?}
        else
            theme ERR_USAGE "Error: This is not a git repository"
            e=${CODE_FAILURE?}
        fi
    fi
    return $e
}
#. }=-
#. git:rebasesearchstr -={
function git:rebasesearchstr:usage() { echo "<file-path>"; }
function git:rebasesearchstr() {
    local -i e=${CODE_DEFAULT?}
    if [ $# -eq 1 ]; then
        local file="$1"
        local -a sha1s=( $(git:file "${file}"|awk '{print$1}' ) )
        local sha1search=$(echo ${sha1s[@]}|sed -e 's/ /\\\|/g')
        echo ":%s/^pick \\(${sha1search}\\)/f    \\1/"
        e=${CODE_SUCCESS?}
    fi
    return $e
}
#. }=-
#. git:reauthor -={
function git:reauthor:usage() { echo "<git-commit-sha1> \"Full Name <email@address.com>\""; }
function git:reauthor() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 2 ]; then
        local sha1=$1
        local new="$2"
        git rebase -i ${sha1}^
        e=${CODE_SUCCESS?}
        while [ $e -eq 0 ]; do
            git commit --amend --author="$new" --reuse-message=HEAD
            git rebase --continue
            e=$?
        done
        e=${CODE_SUCCESS?}
    fi

    return $e
}
#. }=-
#. git:split -={
function git:split:usage() { echo "<git-commit-sha1>"; }
function git:split() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local sha1=$1
        git rebase -i ${sha1}^
        e=${CODE_SUCCESS?}
        while [ $e -eq 0 ]; do
            git reset --mixed HEAD^
            for file in $(git status --porcelain|awk '{print$2}'); do
                git add ${file}
                git commit ${file} -m "... ${file}"
            done
            git rebase --continue
            e=$?
        done
        e=${CODE_SUCCESS?}
    fi

    return $e
}
#. }=-
#. git:commitall -={
function git:commitall() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 -o $# -eq 1 ]; then
        local repo=${1:-${PWD?}}
        read gitbasedir gitrelpath <<< $(:git:basedir ${repo})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            cd ${gitbasedir}
            local file
            for file in $(git status --porcelain ${gitrelpath}|awk '{print$2}'); do
                git add ${file}
                git commit ${file} -m "... ${file}"
            done
            e=${CODE_SUCCESS?}
        else
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. git:server -={
function git:serve:usage() { echo "<iface> [<git-repo-dir>]"; }
function git:serve() {
    local -i e=${CODE_DEFAULT?}

    core:import net
    if [ $# -eq 1 -o $# -eq 2 ]; then
        local iface=$1
        local repo=${2:-${PWD?}}
        read gitbasedir gitrelpath <<< $(:git:basedir ${repo})
        if [ $? -eq 0 ]; then
            local ip=$(:net:i2s ${iface})
            theme INFO "Serving ${gitbasedir} on git://${ip}:9418/ (${iface})"
            git daemon --verbose --listen=${ip} --reuseaddr --export-all --base-path=${gitbasedir}/.git/
            e=$?
        else
            theme ERR_USAGE "Error: This is not a git repository"
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. git:mkci -={
function ::git:mkci() {
    { git checkout -b $1 || git checkout $1; } 2>/dev/null
    shift 1
    for fN in $@; do
        echo ${fN} > ${fN}
        git add ${fN} >/dev/null
        git commit -q ${fN} -m "Add ${fN}"
        printf '.'
    done
}
#. }=-
#. git:playground -={
function git:playground:usage() { echo "<git-repo-dir>"; }
function git:playground() {
    local -i e=${CODE_DEFAULT?}
    if [ $# -eq 1 ]; then

        if [ ! -d $1 ]; then
            cpf "Creating git playground %{@path:$1}..."
            if mkdir -p $1 2>/dev/null; then
                cd $1

                git init -q
                echo $(basename ${1^^}) > .git/description
                ::git:mkci 'master'  m{A,B,C,D}
                ::git:mkci 'topic-a' a{E,F}
                ::git:mkci 'topic-b' b{G,H,I}
                ::git:mkci 'topic-a' a{J,K}
                ::git:mkci 'master'  m{L,M}
                ::git:mkci 'topic-b' b{N,O,P,Q,R}
                ::git:mkci 'master'  m{S,T,U,V}
                for fN in n{W,X,Y,Z}; do
                    echo ${fN^^} > ${fN}
                done
                e=${CODE_SUCCESS?}
                theme HAS_PASSED
            else
                theme ERR_USAGE "Directory $1 already exists; cowardly refusing to create playground."
                e=${CODE_FAILURE?}
            fi

            #git log --graph --all
        else
            theme ERR_USAGE "Directory $1 already exists; cowardly refusing to create playground."
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. git:gource -={
function git:gource:usage() { echo "<git-repo-dir>"; }
function git:gource() {
    core:requires gource

    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ] && [ -d $1 ] || [ $# -eq 0 ]; then
        gource --multi-sampling -s 3 --dont-stop ${1:-${SITE_CORE?}}
        if [ $? -eq 0 ]; then
            e=${CODE_SUCCESS?}
        fi
    fi

    return $e
}
#. }=-
#. git:remail -={
function git:remail:usage() { echo "<old-name> <new-name> <new-mail>"; }
function git:remail() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 3 ]; then
        local fullname="$1"
        local newname="$2"
        local newmail="$3"

        git filter-branch --commit-filter "
if [ \"\$GIT_COMMITTER_NAME\" = \"${fullname}\" ];
then
        GIT_COMMITTER_NAME=\"${newname}\";
        GIT_AUTHOR_NAME=\"${newname}\";
        GIT_COMMITTER_EMAIL=\"${newmail}\";
        GIT_AUTHOR_EMAIL=\"${newmail}\";
        git commit-tree \"\$@\";
else
        git commit-tree \"\$@\";
fi" HEAD
        e=$?
    fi

    return $e
}
#. }=-
#. Debugging/Academic -={
function _:git:add:usage() { echo "<git-repo-dir> <file>"; }
function _:git:add() {
    local -i e=${CODE_DEFAULT?}
    if [ $# -eq 2 ]; then
        if pushd $1 >/dev/null 2>&1; then
            local file=$2
            if [ -e "${file}" ]; then
                #. Method 1
                #. - add the file into the database, and remember it's hash
                local sha1=$(git hash-object -w ${file})
                #. - next update the index, use --cacheinfo because you're
                #.   adding a file already in the database
                local mode=${CODE_FAILURE?}00644 #. 100755, 120000
                git update-index --add --cacheinfo ${mode} ${sha1} ${file}
                #. Method 2 - add the file and index it in one hit
                #git update-index --add ${file}
                git write-tree
                e=$?
            fi
        fi
    fi
    return $e
}

function _:git:rf:usage() { echo "<git-repo-dir> <new-branch-name> <branch-point-sha1>"; }
function _:git:rf() {
    local -i e=${CODE_DEFAULT?}
    if [ $# -eq 3 ]; then
        if pushd $1 >/dev/null 2>&1; then
            local branch=$2
            local sha1=$3
            git update-ref refs/heads/${branch} ${sha1}
            e=$?
        fi
    fi
    return $e
}

function _:git:rf:usage() { echo "<git-repo-dir> <file-hash>"; }
function _:git:rf() {
    local -i e=${CODE_DEFAULT?}
    if [ $# -eq 2 ]; then
        if pushd $1 >/dev/null 2>&1; then
            local sha1=$2
            git cat-file -p ${sha1}
            e=$?
        fi
    fi
    return $e
}
#. }=-
#. }=-
