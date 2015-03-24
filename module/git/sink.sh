# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Auxiliary Git helper module
[core:docstring]

#.  Git -={
core:requires git
core:import git.fs

#. git.sink:objects -={
function git.sink:objects:usage() { echo "[<git-path:pwd>]"; }
function git.sink:objects() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 -o $# -eq 1 ]; then
        e=${CODE_FAILURE?}

        local cwd=$(pwd)
        local data
        data=$(:git.fs:basedir ${1:-${cwd}})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            read gitbasedir gitrelpath <<< "${data}"
            cd ${gitbasedir}

            local osha1
            local otype
            local -i osize

            for osha1 in $(:git.fs:objects ${gitbasedir}); do
                otype=$(git cat-file -t ${osha1})
                osize=$(git cat-file -s ${osha1})
                cpf "%{@hash:%s}->%{y:%s}->%{@int:%d}\n" ${osha1} ${otype} ${osize}
            done

            e=$?
        else
            theme ERR_USAGE "Not a git repository:${1:-${cwd}}"
        fi
    fi

    return $e
}
#. }=-
#. git.sink:playground -={
function ::git.sink:playground() {
    local -i e=${CODE_FAILURE?}

    if [ $# -ge 2 ]; then
        { git checkout -b $1 || git checkout $1; } 2>/dev/null

        for fN in ${@:2}; do
            echo ${fN} > ${fN}
            git add ${fN} >/dev/null
            git commit -q ${fN} -m "Add ${fN}"
            printf '.'
        done

        e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function git.sink:playground:usage() { echo "<git-repo-dir>"; }
function git.sink:playground() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        if [ ! -d $1 ]; then
            cpf "Creating git playground %{@path:$1}..."
            if mkdir -p $1 2>/dev/null; then
                cd $1

                git init -q
                echo $(basename ${1^^}) > .git/description
                ::git.sink:playground 'master'  m{A,B,C,D}
                ::git.sink:playground 'topic-a' a{E,F}
                ::git.sink:playground 'topic-b' b{G,H,I}
                ::git.sink:playground 'topic-a' a{J,K}
                ::git.sink:playground 'master'  m{L,M}
                ::git.sink:playground 'topic-b' b{N,O,P,Q,R}
                ::git.sink:playground 'master'  m{S,T,U,V}
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
#. git.sink:file -={
function git.sink:file:usage() { echo "<path-glob>"; }
function git.sink:file() {
    local -i e=${CODE_DEFAULT?}
    if [ $# -eq 1 ]; then
        read gitbasedir gitrelpath <<< $(:git.fs:basedir ${PWD?})
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
#. git.sink:rm -={
function git.sink:rm:help() {
    cat <<!
Completely remove a file from the repository, retrospectively (from history!)
!
}
function git.sink:rm:usage() { echo "<git-path-glob> [<git-path-glob> [...]]"; }
function git.sink:rm() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 1 ]; then
        e=${CODE_FAILURE?}

        for filename in "${@}"; do
            read gitbasedir gitrelpath <<< $(:git.fs:basedir ${1})
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
#. git.sink:commitall -={
function git.sink:commitall:usage() { echo "[<git-repo-dir>]"; }
function git.sink:commitall() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -le 1 ]; then
        local repo=${1:-${PWD?}}
        read gitbasedir gitrelpath <<< $(:git.fs:basedir ${repo})
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
#. git.sink:vacuum -={
function git.sink:vacuum:usage() { echo "[<git-repo-dir>]"; }
function git.sink:vacuum() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -le 1 ]; then
        local repo=${1:-${PWD?}}
        read gitbasedir gitrelpath <<< $(:git.fs:basedir ${repo})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            cd ${gitbasedir}
            rm -Rf .git/refs/original/ .git/logs/ >/dev/null 2>&1
            e=$?
            if [ $e -eq 0 ]; then
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

#. LEGACY?
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
#. git:server -={
function git:serve:usage() { echo "<iface> [<git-repo-dir>]"; }
function git:serve() {
    local -i e=${CODE_DEFAULT?}

    core:import net
    if [ $# -eq 1 -o $# -eq 2 ]; then
        local iface=$1
        local repo=${2:-${PWD?}}
        read gitbasedir gitrelpath <<< $(:git.fs:basedir ${repo})
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
