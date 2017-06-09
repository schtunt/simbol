# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
The eXternal Programming (scripting) Language Module manager.

This modules handles Python, Ruby, and Perl modules in simbol's sandboxed virtual
environment.
[core:docstring]

#. XPLM -={
core:import util

declare -gA g_PROLANG
g_PROLANG=(
    [rb]=ruby
    [py]=python
    [pl]=perl
)

declare -gA g_PROLANG_VERSION
g_PROLANG_VERSION=(
    [rb]=${RBENV_VERSION?}
    [py]=${PYENV_VERSION?}
    [pl]=${PLENV_VERSION?}
)

declare -gA g_PROLANG_ROOT
g_PROLANG_ROOT=(
    [rb]=${RBENV_ROOT?}
    [py]=${PYENV_ROOT?}
    [pl]=${PLENV_ROOT?}
)

declare -gA g_PROLANG_VCS
g_PROLANG_VCS=(
    [rb]='rbenv.git,ruby-build.git'
    [py]='pyenv.git,pyenv-virtualenv.git'
    [pl]='perl-build.git,plenv.git'
)

#. ::xplm:loadvirtenv -={
function ::xplm:loadvirtenv() {
    core:raise_bad_fn_call_unless $# in 1 2
    core:raise_bad_fn_call_unless "$1" in pl py rb

    local -i e; let e=CODE_FAILURE

    case $1 in
        rb)
            unset GEM_PATH
            unset GEM_HOME
            export RBENV_GEMSET_FILE="${RBENV_ROOT?}/.rbenv-gemsets"
        ;;
        pl)
            export PERL_CPANM_HOME="${PLENV_ROOT?}/.cpanm"
            export PERL_CPANM_OPT="--prompt --reinstall"
        ;;
    esac

    case $1 in
        rb|py|pl)
            local plid="${1}"
            local version="${2-${g_PROLANG_VERSION[${plid}]}}"
            local virtenv="${plid}env"
            local interpreter="${SIMBOL_USER_VAR}/${virtenv}/shims/${g_PROLANG[${plid}]}"

            if [ -x "${interpreter}" ]; then
                eval "$(${virtenv} init -)" >/dev/null 2>&1
                #if [ $1 == "rb" ]; then
                #    PATH+=":$(ruby -e 'puts Gem.dir')/bin"
                #fi
                ${virtenv} rehash
                ${virtenv} shell "${version}"
                let e=$?
            #else
            #    theme ERR "Please install ${plid} first via \`xplm install ${plid}' first"
            fi
        ;;
    esac

    return $e
}
#. }=-
#.  :xplm:requires -={
function :xplm:requires() {
    core:raise_bad_fn_call_unless $# in 2

    local -i e; let e=CODE_FAILURE

    local plid="${1}"
    local required="${2}"
    case ${plid} in
        py)
            if ::xplm:loadvirtenv "${plid}"; then
                python -c "import ${required}" 2>/dev/null &&
                    let e=CODE_SUCCESS
            fi
        ;;
        rb)
            if ::xplm:loadvirtenv "${plid}"; then
                ruby -e "require '${required//-/\/}'" 2>/dev/null &&
                    let e=CODE_SUCCESS
            fi
        ;;
        pl)
            if ::xplm:loadvirtenv "${plid}"; then
                perl -M$"{required}" -e ';' 2>/dev/null &&
                    let e=CODE_SUCCESS
            fi
        ;;
    esac

    return $e
}
#. }=-
#.   xplm:versions -={
function :xplm:versions() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e; let e=CODE_FAILURE

    local plid="${1}"
    local virtenv="${plid}env"
    e=${CODE_SUCCESS?}
    case ${plid} in
        rb|py|pl)
            if which "${virtenv}" &>/dev/null; then
                ${virtenv} versions 2>/dev/null | sed "s/^/${plid} /"
            else
                echo "${plid}   0.0.0"
            fi
        ;;
        *)
            e=${CODE_FAILURE?}
        ;;
    esac

    let e=CODE_SUCCESS

    return $e
}

function xplm:versions:usage() { echo "<plid>"; }
function xplm:versions() {
    local -i e; let e=CODE_DEFAULT

    if [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            rb|py|pl)
                :xplm:versions "${plid}"
                let e=$?
            ;;
        esac
    elif [ $# -eq 0 ]; then
        let e=CODE_SUCCESS
        for plid in "${!g_PROLANG_ROOT[@]}"; do
            if ! :xplm:versions "${plid}"; then
                let e=CODE_FAILURE
            fi
        done
    fi

    return $e
}
#. }=-
#.   xplm:list -={
function :xplm:list() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e; let e=CODE_FAILURE

    local plid="${1}"
    case ${plid} in
        py)
            if ::xplm:loadvirtenv "${plid}"; then
                pip list | sed 's/^/py /'
                let e=PIPESTATUS[0]
            fi
        ;;
        rb)
            if ::xplm:loadvirtenv "${plid}"; then
                gem list --local | sed 's/^/rb /'
                let e=PIPESTATUS[0]
            fi
        ;;
        pl)
            if ::xplm:loadvirtenv "${plid}"; then
                perl <(
cat <<!
#!/usr/bin/env perl -w
use ExtUtils::Installed;
my \$installed = ExtUtils::Installed->new();
my @modules = \$installed->modules();
foreach \$module (@modules) {
    printf("%s (%s)\n", \$module, \$installed->version(\$module));
}
!
) | sed 's/^/pl /'
                let e=PIPESTATUS[0]
            fi
        ;;
    esac

    return $e
}

function xplm:list:usage() { echo "[<plid>]"; }
function xplm:list() {
    local -i e; let e=CODE_DEFAULT
    [ $# -le 1 ] || return $e

    local -A prolangs=( [py]=0 [pl]=0 [rb]=0 )
    for plid in "${@}"; do
        case "${plid}" in
            py) prolangs[${plid}]=1;;
            pl) prolangs[${plid}]=1;;
            rb) prolangs[${plid}]=1;;
            *) e=${CODE_FAILURE?};;
        esac
    done

    #shellcheck disable=SC2086
    if [ $e -ne ${CODE_FAILURE?} ]; then
        for plid in "${!prolangs[@]}"; do
            if [[ $# -eq 0 || ${prolangs[${plid}]} -eq 1 ]]; then
            cpf "Package listing for %{y:%s}->%{r:%s-%s}...\n"\
                "${plid}"\
                "${g_PROLANG[${plid}]}" "${g_PROLANG_VERSION[${plid}]}"
                :xplm:list ${plid}
                e=$?
            fi
        done
    else
        theme HAS_FAILED "Unknown/unsupported language ${plid}"
    fi

    return $e
}
#. }=-
#.   xplm:search -={
function :xplm:search() {
    core:raise_bad_fn_call_unless $# gt 1

    local -i e; let e=CODE_FAILURE
    local plid="${1}"
    case ${plid} in
        py)
            if ::xplm:loadvirtenv "${plid}"; then
                pip search "${@:2}" | cat
                let e=PIPESTATUS[0]
            fi
        ;;
        rb)
            if ::xplm:loadvirtenv "${plid}"; then
                gem search "${@:2}" | cat
                let e=PIPESTATUS[0]
            fi
        ;;
        pl)
            if ::xplm:loadvirtenv "${plid}"; then
                let e=CODE_NOTIMPL
            fi
        ;;
    esac

    return $e
}

function xplm:search:usage() { echo "<plid> <search-str>"; }
function xplm:search() {
    local -i e; let e=CODE_DEFAULT
    [ $# -gt 1 ] || return $e

    local plid="$1"
    case "${plid}" in
        py|pl|rb)
            :xplm:search "${plid}" "${@:2}"
            let e=$?
        ;;
        *)
            theme HAS_FAILED "Unknown/unsupported language ${plid}"
            let e=CODE_FAILURE
        ;;
    esac

    return $e
}
#. }=-
#.   xplm:install -={
function :xplm:install() {
    core:raise_bad_fn_call_unless $# ge 1
    core:raise_bad_fn_call_unless "$1" in pl py rb

    local -i e; let e=CODE_FAILURE
    if [ $# -gt 1 ]; then
        local plid="${1}"
        local virtenv="${plid}env"
        case ${plid} in
            py)
                if ::xplm:loadvirtenv "${plid}"; then
                    pip install --upgrade -q "${@:2}" \
                        >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                    let e=$?
                fi
            ;;
            rb)
                if ::xplm:loadvirtenv "${plid}"; then
                    gem install -q "${@:2}" \
                        >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                    let e=$?
                fi
            ;;
            pl)
                if ::xplm:loadvirtenv "${plid}"; then
                    cpanm "${@:2}" \
                        >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                    let e=$?
                fi
            ;;
        esac
    elif [ $# -eq 1 ]; then
        #. This is a lazy-installer as well as an initializer for the particular
        #. virtual environment requested; i.e., the first time it is called, it
        #. will install the language interpreter (ruby, python, perl) via rbenv,
        #. pyenv, plenv respectively.

        local plid="${1}"
        local virtenv="${plid}env"
        local interpreter=${SIMBOL_USER_VAR}/${virtenv}/shims/${g_PROLANG[${plid}]}

        if ! ::xplm:loadvirtenv "${plid}"; then
            #. Before Install -={
            case ${plid} in
                rb)
                    mkdir -p "${RBENV_ROOT?}"
                    echo .gems > "${RBENV_ROOT?}/.rbenv-gemsets"

                    local xplenv

                    #. rbenv.git
                    xplenv="git://github.com/sstephenson/rbenv.git"
                    if [ ! -e "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git" ]; then
                        git clone -q "${xplenv}" "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git"
                    fi
                    ln -sf "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git/bin/${virtenv}"\
                        "${SIMBOL_USER_VAR_LIBEXEC?}/${virtenv}"

                    #. rbenv->build
                    mkdir -p "${RBENV_ROOT?}/plugins"
                    xplenv="git://github.com/sstephenson/ruby-build.git"
                    if [ ! -e "${SIMBOL_USER_VAR_SCM?}/${virtenv}-build.git" ]; then
                        git clone -q ${xplenv} "${SIMBOL_USER_VAR_SCM?}/${virtenv}-build.git"
                    fi
                    ln -sf "${SIMBOL_USER_VAR_SCM?}/${virtenv}-build.git"\
                        "${RBENV_ROOT?}/plugins/${virtenv}-build"

                    xplenv="git://github.com/carsomyr/rbenv-bundler.git"
                    if [ ! -e "${SIMBOL_USER_VAR_SCM?}/${virtenv}-bundler.git" ]; then
                        git clone -q ${xplenv} "${SIMBOL_USER_VAR_SCM?}/${virtenv}-bundler.git"
                    fi
                    ln -sf "${SIMBOL_USER_VAR_SCM?}/${virtenv}-bundler.git"\
                        "${RBENV_ROOT?}/plugins/${virtenv}-bundler"
                ;;
                py)
                    #. Note that pyenv ships with pyenv-build, but we need to
                    #. get pyenv-virtualenv
                    mkdir -p "${PYENV_ROOT?}"

                    #. pyenv.git
                    local xplenv="git://github.com/yyuu/pyenv.git"
                    if [ ! -e "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git" ]; then
                        git clone -q ${xplenv} "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git"
                    fi
                    ln -sf "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git/bin/${virtenv}"\
                        "${SIMBOL_USER_VAR_LIBEXEC?}/${virtenv}"

                    #. pyenv->build
                    mkdir -p "${PYENV_ROOT?}/plugins"
                    ln -sf "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git/plugins/python-build"\
                        "${PYENV_ROOT?}/plugins/${virtenv}-build"

                    #. pyenv->virtualenv
                    local virtualenv="git://github.com/yyuu/pyenv-virtualenv.git"
                    if [ ! -e "${SIMBOL_USER_VAR_SCM?}/${virtenv}-virtualenv.git" ]; then
                        "git clone -q ${virtualenv} ${SIMBOL_USER_VAR_SCM?}/${virtenv}-virtualenv.git"
                    fi
                    ln -sf "${SIMBOL_USER_VAR_SCM?}/${virtenv}-virtualenv.git"\
                        "${PYENV_ROOT?}/plugins/${virtenv}-virtualenv"
                ;;
                pl)
                    #. plenv
                    mkdir -p "${PLENV_ROOT?}"
                    mkdir -p "${PERL_CPANM_HOME?}"

                    #. plenv.git
                    local xplenv="git://github.com/tokuhirom/plenv.git"
                    if [ ! -e "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git" ]; then
                        git clone -q ${xplenv} "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git"
                    fi
                    ln -sf "${SIMBOL_USER_VAR_SCM?}/${virtenv}.git/bin/${virtenv}"\
                        "${SIMBOL_USER_VAR_LIBEXEC?}/${virtenv}"

                    #. plenv->build
                    mkdir -p "${PLENV_ROOT?}/plugins"
                    local build="git://github.com/tokuhirom/Perl-Build.git"
                    if [ ! -e "${SIMBOL_USER_VAR_SCM?}/${virtenv}-build.git" ]; then
                        git clone -q ${build} "${SIMBOL_USER_VAR_SCM?}/${virtenv}-build.git"
                    fi
                    ln -sf "${SIMBOL_USER_VAR_SCM?}/${virtenv}-build.git"\
                        "${PLENV_ROOT?}/plugins/${virtenv}-build"
                ;;
            esac
            #. }=-

            case ${plid} in
                rb)
                    curl -fsSL https://gist.github.com/mislav/a18b9d7f0dc5b9efc162.txt |
                        ${virtenv} install --patch "${g_PROLANG_VERSION[${plid}]}"\
                            >"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                    let e=$?
                    ${virtenv} rehash
                ;;
                py|pl)
                    ${virtenv} install "${g_PROLANG_VERSION[${plid}]}"\
                        >"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                    let e=$?

                    ${virtenv} rehash
                ;;
            esac

            #. After Install -={
            #shellcheck disable=SC2086
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                eval "$(${virtenv} init -)"
                case ${plid} in
                    pl)
                        plenv install-cpanm >"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                        cpanm Devel::REPL >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                        cpanm Lexical::Persistence >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                        cpanm Data::Dump::Streamer >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                        cpanm PPI >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                        cpanm Term::ReadLine >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                        cpanm Term::ReadKey >>"${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1
                        let e=$?
                    ;;
                esac
            fi
            #. }=-
        else
            let e=CODE_SUCCESS
        fi
    fi

    return $e
}
function xplm:install:usage() { echo "<plid> [<pkg> [<pkg> [...]]]"; }
function xplm:install() {
    local -i e; let e=CODE_DEFAULT
    [ $# -ge 1 ] || return $e

    if [ $# -gt 1 ]; then
        local plid="$1"
        case ${plid} in
            py|pl|rb)
                :xplm:install "${plid}" "${@:2}"
                let e=$?
            ;;
            *)
                theme HAS_FAILED "Unknown/unsupported language ${plid}"
                let e=CODE_FAILURE
            ;;
        esac
    elif [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            rb|py|pl)
                cpf "Installing %{y:%s}: %{r:%s-%s}..."\
                    "${plid}"\
                    "${g_PROLANG[${plid}]}" "${g_PROLANG_VERSION[${plid}]}"
                :xplm:install "${plid}"
                let e=$?
                theme HAS_AUTOED $e
                #shellcheck disable=SC2086
                if [ $e -ne ${CODE_SUCCESS?} ]; then
                    local virtenv="${plid}env"
                    theme INFO "See ${SIMBOL_USER}/var/log/${virtenv}.log"
                fi
            ;;
        esac
    fi

    return $e
}
#. }=-
#.   xplm:purge -={
function :xplm:purge() {
    core:raise_bad_fn_call_unless $# eq 1
    core:raise_bad_fn_call_unless "$1" in pl py rb

    local -i e; let e=CODE_FAILURE

    local plid="${1}"
    case ${plid} in
        rb|py|pl)
            local virtenv="${plid}env"
            rm -rf "${SIMBOL_USER_VAR_LIBEXEC:?}/${virtenv}"
            rm -rf "${SIMBOL_USER_VAR:?}/${virtenv}"

            #. Unnecessary VCS purge...
            set +f; rm -rf "${SIMBOL_USER_VAR_SCM:?}/${virtenv}"*; set -f

            let e=CODE_SUCCESS
        ;;
    esac

    return $e
}

function xplm:purge:usage() { echo "<plid>"; }
function xplm:purge() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 1 ] || return $e

    local plid="${1}"
    case ${plid} in
        rb|py|pl)
            cpf "Purging %{y:%s}->%{r:%s-%s}..."\
                "${plid}"\
                "${g_PROLANG[${plid}]}" "${g_PROLANG_VERSION[${plid}]}"
            :xplm:purge "${plid}"
            let e=$?
        ;;
    esac
    theme HAS_AUTOED $e

    return $e
}
#. }=-
#.   :xplm:selfupdate -={
function :xplm:selfupdate() {
    core:raise_bad_fn_call_unless $# eq 1

    local -i e; let e=CODE_SUCCESS

    local plid="${1}"
    local virtenv="${plid}env"
    local xplmscm="${SIMBOL_USER_VAR?}/scm"
    local vcs
    case ${plid} in
        rb|py|pl)
            local -a vcses
            IFS=, read -r -a vcses <<< "${g_PROLANG_VCS[${plid}]}"
            for vcs in ${vcses}; do
                if cd "${xplmscm}/${vcs}" >&/dev/null; then
                    if ! git pull >> "${SIMBOL_USER}/var/log/${virtenv}.log" 2>&1; then
                        let e=CODE_FAILURE
                    fi
                fi
            done
        ;;
        *)
            let e=CODE_FAILURE
        ;;
    esac

    return $e
}
function xplm:selfupdate:usage() { echo "<plid>"; }
function xplm:selfupdate() {
    local -i e; let e=CODE_DEFAULT

    if [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            rb|py|pl)
                cpf "Updating %{y:%s} to the latest release..." "${plid}"
                :xplm:selfupdate "${plid}"
                let e=$?
                theme HAS_AUTOED $e
            ;;
        esac
    elif [ $# -eq 0 ]; then
        let e=CODE_SUCCESS
        for plid in "${!g_PROLANG_ROOT[@]}"; do
            cpf "Updating %{y:%s} to the latest release..." "${plid}"
            if :xplm:selfupdate $"{plid}"; then
                theme HAS_PASSED
            else
                theme HAS_FAILED
                let e=CODE_FAILURE
            fi
        done
    fi

    return $e
}
#. }=-
#.   xplm:shell -={
function :xplm:shell() {
    core:raise_bad_fn_call_unless $# eq 2

    local -i e; let e=CODE_FAILURE

    local plid="${1}"
    local version="${2}"
    case ${plid} in
        rb|py|pl)
            if ::xplm:loadvirtenv "${plid}" "${version}"; then
                echo "Ctrl-D to exit environment"
                #cd ${g_PROLANG_ROOT[${plid}]}
                bash --rcfile <(
                    cat <<-!VIRTENV
                    unset PROMPT_COMMAND
                    export HISTFILE=~/.bash_history_${plid}
                    export PS1="simbol:${plid}-${version}> "
					!VIRTENV
                ) -i
                let e=$?
            fi
        ;;
    esac

    return $e
}
function xplm:shell:usage() { echo "<plid> [<version>]"; }
function xplm:shell() {
    local -i e; let e=CODE_DEFAULT
    #shellcheck disable=SC2166
    [ $# -eq 1 -o $# -eq 2 ] || return $e

    local plid="$1"
    local version="${2:-${g_PROLANG_VERSION[${plid}]}}"
    case "${plid}" in
        py|pl|rb)
            :xplm:shell "${plid}" "${version}"
            let e=$?
        ;;
        *)
            theme HAS_FAILED "Unknown/unsupported language ${plid}"
            let e=CODE_FAILURE
        ;;
    esac

    return $e
}
#. }=-
#.   xplm:run -={
function :xplm:run() {
    core:raise_bad_fn_call_unless $# gt 2
    core:raise_bad_fn_call_unless "$1" in pl py rb

    local -i e; let e=CODE_FAILURE

    local plid="${1}"
    local version="${2}"
    local cmd="${3}"
    local -a cmdfull=( "${@:3}" )
    case ${plid} in
        rb|py|pl)
            if ::xplm:loadvirtenv "${plid}" "${version}"; then
                if [ -f "${cmd}" ]; then
                    ${g_PROLANG[${plid}]} "${cmdfull[@]}"
                    let e=$?
                else
                    "${cmdfull[@]}"
                    let e=$?
                fi
            fi
        ;;
    esac

    return $e
}
function xplm:run:usage() { echo "<plid> <script>"; }
function xplm:run() {
    local -i e; let e=CODE_DEFAULT
    [ $# -ge 2 ] || return $e

    local plid="$1"
    case "${plid}" in
        py|pl|rb)
            local -a script=( "${@:2}" )
            local version="${g_PROLANG_VERSION[${plid}]}"
            :xplm:run "${plid}" "${version}" "${script[@]}"
            let e=$?
        ;;
        *)
            theme HAS_FAILED "Unknown/unsupported language ${plid}"
            let e=CODE_FAILURE
        ;;
    esac

    return $e
}
#. }=-
#.   xplm:repl -={
function :xplm:repl() {
    core:raise_bad_fn_call_unless $# eq 1
    local -i e; let e=CODE_FAILURE

    local plid="${1}"
    case ${plid} in
        py)
            ::xplm:loadvirtenv "${plid}" && python
            let e=$?
        ;;
        rb)
            ::xplm:loadvirtenv "${plid}" && irb
            let e=$?
        ;;
        pl)
            ::xplm:loadvirtenv "${plid}" && re.pl
            let e=$?
        ;;
    esac

    return $e
}
function xplm:repl:usage() { echo "<plid>"; }
function xplm:repl() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 1 ] || return $e

    local plid="$1"
    case "${plid}" in
        py|pl|rb)
            :xplm:repl "${plid}" "${@:2}"
            let e=$?
        ;;
        *)
            theme HAS_FAILED "Unknown/unsupported language ${plid}"
            let e=CODE_FAILURE
        ;;
    esac

    return $e
}
#. }=-
#. }=-
