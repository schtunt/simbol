# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Auxiliary Git helper module
[core:docstring]

#.  Git -={
core:requires git

#. :git:basedir -={
function :git:basedir() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e=${CODE_FAILURE?}

    local cwd; cwd="$(pwd)"
    local filename; filename="$(readlink -m "${1}")"

    [ "${filename:0:1}" == '/' ] || filename="${cwd}/${filename}"

    local gitbasedir; gitbasedir="$(readlink -m "${filename}")"

    local -i found=0
    while [ ${found} -eq 0 ] && [ "${gitbasedir}" != "/" ]; do
        if [ -d "${gitbasedir}/.git" ]; then
            found=1
        else
            gitbasedir=$(readlink -m "${gitbasedir}/..")
        fi
    done

    if [ ${found} -eq 1 ]; then
        echo "${gitbasedir} ${filename/${gitbasedir}\//./}"
        let e=${CODE_SUCCESS?}
    fi

    return $e
}
#. }=-
#. git:size -={
function git:size:usage() { echo "[<git-path:pwd>]"; }
function git:size() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -le 1 ] || return $e

    local cwd; cwd="$(pwd)"
    local data
    if data="$(:git:basedir "${1:-${cwd}}")"; then
        read -r gitbasedir gitrelpath <<< "${data}"
        if cd "${gitbasedir}"; then
            git l|wc -l|tr '\n' ' '
            du -sh .git|awk '{print $1}'
            git count-objects -v
            let e=$?
        fi
    else
        theme ERR_USAGE "Not a git repository:${1:-${cwd}}"
        let e=${CODE_FAILURE?}
    fi

    return $e
}
#. }=-
#. git:usage -={
function git:usage:usage() { echo "[<git-path:pwd>]"; }
function git:usage() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -le 1 ] || return $e

    let e=${CODE_FAILURE?}

    local cwd; cwd="$(pwd)"
    read -r gitbasedir gitrelpath <<< "$(:git:basedir "${1:-${cwd}}")"
    #shellcheck disable=SC2086
    if [ $? -eq ${CODE_SUCCESS?} ]; then
        if cd "${gitbasedir}"; then
            while read -r sha1 obj size; do
                cpf "%{y:%-6s %8s} %{@hash:%s}" "${obj}" "${size}" "${sha1}"
                read -r sha1 path <<< "$(git rev-list --objects --all | grep ${sha1})"
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
                #shellcheck disable=SC2026
                git verify-pack -v .git/objects/pack/pack-*.idx\
                    | grep -E "^[a-f0-9]{40}"\
                    | sort -k 3 -n\
                    | tail -n 64\
                    | awk '{print$1,$2,$3}'\
            )
            let e=$?
            if [ -d .git/refs/original/ ] || [ -d .git/logs/ ]; then
                theme NOTE "You should run git:vacuum to reflect recent changes"
            fi
        else
            theme ERR_USAGE "Error: could not chdir to ${1}"
            let e=${CODE_FAILURE?}
        fi
    else
        theme ERR_USAGE "Error: that path is not within a git repository."
        let e=${CODE_FAILURE?}
    fi

    return $e
}
#. }=-
#. git:rm -={
function git:rm:usage() { echo "<git-path-glob> [<git-path-glob> [...]]"; }
function git:rm() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -ge 1 ] || return $e

    let e=${CODE_FAILURE?}

    local cwd; cwd="$(pwd)"
    for filename in "${@}"; do
        read -r gitbasedir gitrelpath <<< "$(:git:basedir "${1}")"
        #shellcheck disable=SC2086
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            if cd "${gitbasedir}"; then
                git filter-branch\
                    --force\
                    --index-filter "git rm -rf --cached --ignore-unmatch ${gitrelpath}"\
                    --prune-empty --tag-name-filter cat -- --all

                let e=$?
            fi
        fi
    done

    return $e
}
#. }=-
#. git:vacuum -={
function git:vacuum:usage() { echo "<git-repo-dir>"; }
function git:vacuum() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -eq 1 ] || return $e

    local repo_dir="$1"
    if cd "${repo_dir}" >&/dev/null; then
        if rm -Rf .git/refs/original/ .git/logs/; then
            rm -Rf .git/refs/original/ .git/logs/
            git filter-branch --prune-empty
            #shellcheck disable=SC2086
            git reflog expire --expire=now --all --expire-unreachable=${CODE_SUCCESS?}
            git gc --aggressive --prune=now
            git repack -a -d -f --depth=250 --window=250
            #shellcheck disable=SC2086
            git prune --expire=${CODE_SUCCESS?} --progress
            let e=$?
        fi
    else
        theme ERR_USAGE "Error: could not chdir to \`${repo_dir}'"
        let e=${CODE_FAILURE?}
    fi

    return $e
}
#. }=-
#. git:file -={
function git:file:usage() { echo "<path-glob>"; }
function git:file() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -eq 1 ] || return $e

    local gitbasedir gitrelpath
    if read -r gitbasedir gitrelpath <<< "$(:git:basedir "${PWD?}")"; then
        local sha1
        for sha1 in $(git log --pretty=format:'%h'); do
            if git diff-tree --no-commit-id --name-only -r "${sha1}" | grep -qE "${1}"; then
                printf '%s [ ' "${sha1}"
                git diff-tree --no-commit-id --name-only -r "${sha1}" | tr '\n' ' '
                git log -1 --pretty=format:'] -- %s' "${sha1}"
                echo
            fi
        done | grep --color '\[.*\] --';
        let e=${CODE_SUCCESS?}
    else
        theme ERR_USAGE "Error: This is not a git repository"
        let e=${CODE_FAILURE?}
    fi

    return $e
}
#. }=-
#. git:rebasesearchstr -={
function git:rebasesearchstr:usage() { echo "<file-path>"; }
function git:rebasesearchstr() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -eq 1 ] || return $e

    local file="$1"
    local -a sha1s=( $(git:file "${file}"|awk '{print$1}' ) )
    local sha1search; sha1search="$(sed -e 's/ /\\\|/g' <<< "${sha1s[*]}")"
    echo ":%s/^pick \\(${sha1search}\\)/f    \\1/"
    let e=${CODE_SUCCESS?}

    return $e
}
#. }=-
#. git:reauthor -={
function git:reauthor:usage() { echo "<git-commit-sha1> \"Full Name <email@address.com>\""; }
function git:reauthor() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -eq 2 ] || return $e

    local sha1="$1"
    local new="$2"
    git rebase -i "${sha1}^"
    let e=$?
    #shellcheck disable=SC2086
    while [ $e -eq ${CODE_SUCCESS?} ]; do
        git commit --amend --author="$new" --reuse-message=HEAD
        git rebase --continue || let e=${CODE_FAILURE?}
    done

    return $e
}
#. }=-
#. git:split -={
function git:split:usage() { echo "<git-commit-sha1>"; }
function git:split() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -eq 1 ] || return $e

    local sha1="$1"
    git rebase -i "${sha1}^"
    let e=$?
    #shellcheck disable=SC2086
    while [ $e -eq ${CODE_SUCCESS?} ]; do
        git reset --mixed HEAD^
        for file in $(git status --porcelain|awk '{print$2}'); do
            git add "${file}"
            git commit "${file}" -m "... ${file}"
        done
        git rebase --continue || let e=${CODE_FAILURE?}
    done

    return $e
}
#. }=-
#. git:commitall -={
function git:commitall() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -le 1 ] || return $e

    let e=${CODE_FAILURE?}

    local repo="${1:-${PWD?}}"
    local gitbasedir gitrelpath
    if read -r gitbasedir gitrelpath <<< "$(:git:basedir "${repo}")"; then
        if cd "${gitbasedir}" >&/dev/null; then
            local file
            for file in $(git status --porcelain "${gitrelpath}"|awk '{print$2}'); do
                git add "${file}"
                git commit "${file}" -m "... ${file}"
            done

            let e=${CODE_SUCCESS?}
        fi
    fi

    return $e
}
#. }=-
#. git:server -={
function git:serve:usage() { echo "<iface> [<git-repo-dir>]"; }
function git:serve() {
    local -i e; let e=${CODE_DEFAULT?}
    #shellcheck disable=SC2166
    [ $# -eq 1 -o $# -eq 2 ] || return $e

    core:import net
    local iface="$1"
    local repo="${2:-${PWD?}}"
    local gitbasedir gitrelpath
    if read -r gitbasedir gitrelpath <<< "$(:git:basedir "${repo}")"; then
        local ip; ip=$(:net:i2s "${iface}")
        theme INFO "Serving ${gitbasedir} on git://${ip}:9418/ (${iface})"
        git daemon --verbose --listen="${ip}" --reuseaddr --export-all --base-path="${gitbasedir}/.git/"
        let e=$?
    else
        theme ERR_USAGE "Error: This is not a git repository"
        let e=${CODE_FAILURE?}
    fi

    return $e
}
#. }=-
#. ::git:mkci -={
function ::git:mkci() {
    core:raise_bad_fn_call_unless $# ge 2

    local -i e; let e=${CODE_SUCCESS?}

    local branch="$1"
    { git checkout -b "${branch}" || git checkout "${branch}"; } 2>/dev/null

    local fN
    for fN in "${@:2}"; do
        echo "${fN}" > "${fN}"
        git add "${fN}" >/dev/null
        git commit -q "${fN}" -m "Add ${fN}"
        printf '.'
    done

    return $e
}
#. }=-
#. git:playground -={
function git:playground:usage() { echo "<git-repo-dir>"; }
function git:playground() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -eq 1 ] || return $e

    if [ ! -d "$1" ]; then
        cpf "Creating git playground %{@path:$1}..."
        if mkdir -p "$1" 2>/dev/null && cd "$1"; then
            git init -q
            basename "${1^^})" > .git/description
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
            let e=${CODE_SUCCESS?}
            theme HAS_PASSED
        else
            theme ERR_USAGE "Directory $1 already exists; cowardly refusing to create playground."
            let e=${CODE_FAILURE?}
        fi

        #git log --graph --all
    else
        theme ERR_USAGE "Directory $1 already exists; cowardly refusing to create playground."
        let e=${CODE_FAILURE?}
    fi

    return $e
}
#. }=-
#. git:gource -={
function git:gource:usage() { echo "<git-repo-dir>"; }
function git:gource() {
    core:requires gource
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -le 1 ] || return $e

    local repo_dir="${1:-${SITE_CORE?}}"
    if [ -d "$1" ]; then
        gource --multi-sampling -s 3 --dont-stop "${repo_dir}"
        let e=$?
    fi

    return $e
}
#. }=-
#. git:remail -={
function git:remail:usage() { echo "<old-name> <new-name> <new-mail>"; }
function git:remail() {
    local -i e; let e=${CODE_DEFAULT?}
    [ $# -eq 3 ] || return $e

    local fullname="$1"
    local newname="$2"
    local newmail="$3"

    git filter-branch --commit-filter "
if [ \"\$GIT_COMMITTER_NAME\" = \"${fullname}\" ]; then
    GIT_COMMITTER_NAME=\"${newname}\";
    GIT_AUTHOR_NAME=\"${newname}\";
    GIT_COMMITTER_EMAIL=\"${newmail}\";
    GIT_AUTHOR_EMAIL=\"${newmail}\";
    git commit-tree \"\$@\";
else
    git commit-tree \"\$@\";
fi" HEAD
    let e=$?

    return $e
}
#. }=-

#. Debugging/Academic -={
function _:git:add:usage() { echo "<git-repo-dir> <file>"; }
function _:git:add() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 2 ]; then
        if cd "$1" >&/dev/null; then
            local file="$2"
            if [ -e "${file}" ]; then
                #. Method 1
                #. - add the file into the database, and remember it's hash
                local sha1; sha1="$(git hash-object -w "${file}")"
                #. - next update the index, use --cacheinfo because you're
                #.   adding a file already in the database
                local mode="100644" #. 100755, 120000
                git update-index --add --cacheinfo "${mode}" "${sha1}" "${file}"
                #. Method 2 - add the file and index it in one hit
                #git update-index --add ${file}
                git write-tree
                let e=$?
            fi
        fi
    fi

    return $e
}

function _:git:rf:usage() { echo "<git-repo-dir> <new-branch-name> <branch-point-sha1>"; }
function _:git:rf() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 3 ]; then
        if cd "$1" >&/dev/null; then
            local branch="$2"
            local sha1="$3"
            git update-ref "refs/heads/${branch}" "${sha1}"
            let e=$?
        fi
    fi

    return $e
}

function _:git:rf:usage() { echo "<git-repo-dir> <file-hash>"; }
function _:git:rf() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 2 ]; then
        if cd "$1" >&/dev/null; then
            local sha1="$2"
            git cat-file -p "${sha1}"
            let e=$?
        fi
    fi

    return $e
}
#. }=-
#. }=-
