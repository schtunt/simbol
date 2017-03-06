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
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 -o $# -eq 2 ]; then
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
                    ${virtenv} shell ${version}
                    e=$?
                #else
                #    theme ERR "Please install ${plid} first via \`xplm install ${plid}' first"
                fi
            ;;
            *)
                core:raise EXCEPTION_BAD_FN_CALL
            ;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#.  :xplm:requires -={
function :xplm:requires() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local plid="${1}"
        local required="${2}"
        case ${plid} in
            py)
                if ::xplm:loadvirtenv ${plid}; then
                    python -c "import ${required}" 2>/dev/null
                    [ $? -ne 0 ] || e=${CODE_SUCCESS?}
                fi
            ;;
            rb)
                if ::xplm:loadvirtenv ${plid}; then
                    ruby -e "require '${required//-/\/}'" 2>/dev/null
                    [ $? -ne 0 ] || e=${CODE_SUCCESS?}
                fi
            ;;
            pl)
                if ::xplm:loadvirtenv ${plid}; then
                    perl -M${required} -e ';' 2>/dev/null
                    [ $? -ne 0 ] || e=${CODE_SUCCESS?}
                fi
            ;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#.   xplm:versions -={
function :xplm:versions() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local plid="${1}"
        local virtenv="${plid}env"
        e=${CODE_SUCCESS?}
        case ${plid} in
            rb|py|pl)
                if which ${virtenv} &>/dev/null; then
                    ${virtenv} versions 2>/dev/null | sed "s/^/${plid} /"
                else
                    echo "${plid}   0.0.0"
                fi
            ;;
            *)
                e=${CODE_FAILURE?}
            ;;
        esac

        e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function xplm:versions:usage() { echo "<plid>"; }
function xplm:versions() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            rb|py|pl)
                :xplm:versions ${plid}
                e=$?
            ;;
        esac
    elif [ $# -eq 0 ]; then
        e=${CODE_SUCCESS?}
        for plid in ${!g_PROLANG_ROOT[@]}; do
            if ! :xplm:versions ${plid}; then
                e=${CODE_FAILURE?}
            fi
        done
    fi

    return $e
}
#. }=-
#.   xplm:list -={
function :xplm:list() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            py)
                if ::xplm:loadvirtenv ${plid}; then
                    pip list | sed 's/^/py /'
                    e=${PIPESTATUS[0]}
                fi
            ;;
            rb)
                if ::xplm:loadvirtenv ${plid}; then
                    gem list --local | sed 's/^/rb /'
                    e=${PIPESTATUS[0]}
                fi
            ;;
            pl)
                if ::xplm:loadvirtenv ${plid}; then
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
                    e=${PIPESTATUS[0]}
                fi
            ;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function xplm:list:usage() { echo "[<plid>]"; }
function xplm:list() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -le 1 ]; then
        local -A prolangs=( [py]=0 [pl]=0 [rb]=0 )
        for plid in "${@}"; do
            case "${plid}" in
                py) prolangs[${plid}]=1;;
                pl) prolangs[${plid}]=1;;
                rb) prolangs[${plid}]=1;;
                *) e=${CODE_FAILURE?};;
            esac
        done

        if [ $e -ne ${CODE_FAILURE?} ]; then
            for plid in ${!prolangs[@]}; do
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
    fi

    return $e
}
#. }=-
#.   xplm:search -={
function :xplm:search() {
    local -i e=${CODE_FAILURE?}

    if [ $# -gt 1 ]; then
        local plid="${1}"
        case ${plid} in
            py)
                if ::xplm:loadvirtenv ${plid}; then
                    pip search "${@:2}" | cat
                    e=${PIPESTATUS[0]}
                fi
            ;;
            rb)
                if ::xplm:loadvirtenv ${plid}; then
                    gem search "${@:2}" | cat
                    e=${PIPESTATUS[0]}
                fi
            ;;
            pl)
                if ::xplm:loadvirtenv ${plid}; then
                    e=${CODE_NOTIMPL?}
                fi
            ;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function xplm:search:usage() { echo "<plid> <search-str>"; }
function xplm:search() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -gt 1 ]; then
        local plid="$1"
        case "${plid}" in
            py|pl|rb)
                :xplm:search ${plid} "${@:2}"
                e=$?
            ;;
            *)
                theme HAS_FAILED "Unknown/unsupported language ${plid}"
                e=${CODE_FAILURE?}
            ;;
        esac
    fi

    return $e
}
#. }=-
#.   xplm:install -={
function :xplm:install() {
    local -i e=${CODE_FAILURE?}

    if [ $# -gt 1 ]; then
        local plid="${1}"
        local virtenv="${plid}env"
        case ${plid} in
            py)
                if ::xplm:loadvirtenv ${plid}; then
                    pip install --upgrade -q "${@:2}" \
                        >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                    e=$?
                fi
            ;;
            rb)
                if ::xplm:loadvirtenv ${plid}; then
                    gem install -q "${@:2}" \
                        >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                    e=$?
                fi
            ;;
            pl)
                if ::xplm:loadvirtenv ${plid}; then
                    cpanm ${@:2} \
                        >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                    e=$?
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

        if ! ::xplm:loadvirtenv ${plid}; then
            #. Before Install -={
            case ${plid} in
                rb)
                    mkdir -p ${RBENV_ROOT?}
                    echo .gems > ${RBENV_ROOT?}/.rbenv-gemsets

                    #. rbenv.git
                    local xplenv="git://github.com/sstephenson/rbenv.git"
                    if [ ! -e ${SIMBOL_USER_SCM?}/${virtenv}.git ]; then
                        git clone -q ${xplenv} ${SIMBOL_USER_SCM?}/${virtenv}.git
                    fi
                    ln -sf ${SIMBOL_USER_SCM?}/${virtenv}.git/bin/${virtenv}\
                        ${SIMBOL_USER_LIBEXEC?}/${virtenv}

                    #. rbenv->build
                    mkdir -p ${RBENV_ROOT?}/plugins
                    local build="git://github.com/sstephenson/ruby-build.git"
                    if [ ! -e ${SIMBOL_USER_SCM?}/${virtenv}-build.git ]; then
                        git clone -q ${build} ${SIMBOL_USER_SCM?}/${virtenv}-build.git
                    fi
                    ln -sf ${SIMBOL_USER_SCM?}/${virtenv}-build.git\
                        ${RBENV_ROOT?}/plugins/${virtenv}-build

                    local bundler="git://github.com/carsomyr/rbenv-bundler.git"
                    if [ ! -e ${SIMBOL_USER_SCM?}/${virtenv}-bundler.git ]; then
                        git clone -q ${build} ${SIMBOL_USER_SCM?}/${virtenv}-bundler.git
                    fi
                    ln -sf ${SIMBOL_USER_SCM?}/${virtenv}-bundler.git\
                        ${RBENV_ROOT?}/plugins/${virtenv}-bundler
                ;;
                py)
                    #. Note that pyenv ships with pyenv-build, but we need to
                    #. get pyenv-virtualenv
                    mkdir -p ${PYENV_ROOT?}

                    #. pyenv.git
                    local xplenv="git://github.com/yyuu/pyenv.git"
                    if [ ! -e ${SIMBOL_USER_SCM?}/${virtenv}.git ]; then
                        git clone -q ${xplenv} ${SIMBOL_USER_SCM?}/${virtenv}.git
                    fi
                    ln -sf ${SIMBOL_USER_SCM?}/${virtenv}.git/bin/${virtenv}\
                        ${SIMBOL_USER_LIBEXEC?}/${virtenv}

                    #. pyenv->build
                    mkdir -p ${PYENV_ROOT?}/plugins
                    ln -sf ${SIMBOL_USER_SCM?}/${virtenv}.git/plugins/python-build\
                        ${PYENV_ROOT?}/plugins/${virtenv}-build

                    #. pyenv->virtualenv
                    local virtualenv="git://github.com/yyuu/pyenv-virtualenv.git"
                    if [ ! -e ${SIMBOL_USER_SCM?}/${virtenv}-virtualenv.git ]; then
                        git clone -q ${virtualenv} ${SIMBOL_USER_SCM?}/${virtenv}-virtualenv.git
                    fi
                    ln -sf ${SIMBOL_USER_SCM?}/${virtenv}-virtualenv.git\
                        ${PYENV_ROOT?}/plugins/${virtenv}-virtualenv
                ;;
                pl)
                    #. plenv
                    mkdir -p ${PLENV_ROOT?}
                    mkdir -p ${PERL_CPANM_HOME?}

                    #. plenv.git
                    local xplenv="git://github.com/tokuhirom/plenv.git"
                    if [ ! -e ${SIMBOL_USER_SCM?}/${virtenv}.git ]; then
                        git clone -q ${xplenv} ${SIMBOL_USER_SCM?}/${virtenv}.git
                    fi
                    ln -sf ${SIMBOL_USER_SCM?}/${virtenv}.git/bin/${virtenv}\
                        ${SIMBOL_USER_LIBEXEC?}/${virtenv}

                    #. plenv->build
                    mkdir -p ${PLENV_ROOT?}/plugins
                    local build="git://github.com/tokuhirom/Perl-Build.git"
                    if [ ! -e ${SIMBOL_USER_SCM?}/${virtenv}-build.git ]; then
                        git clone -q ${build} ${SIMBOL_USER_SCM?}/${virtenv}-build.git
                    fi
                    ln -sf ${SIMBOL_USER_SCM?}/${virtenv}-build.git\
                        ${PLENV_ROOT?}/plugins/${virtenv}-build
                ;;
            esac
            #. }=-

            case ${plid} in
                rb)
                    curl -fsSL https://gist.github.com/mislav/a18b9d7f0dc5b9efc162.txt |
                        ${virtenv} install --patch ${g_PROLANG_VERSION[${plid}]}\
                            >${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                    e=$?
                    ${virtenv} rehash
                ;;
                py|pl)
                    ${virtenv} install ${g_PROLANG_VERSION[${plid}]}\
                        >${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                    e=$?

                    ${virtenv} rehash
                ;;
                *) core:raise EXCEPTION_BAD_FN_CALL ;;
            esac

            #. After Install -={
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                eval "$(${virtenv} init -)"
                case ${plid} in
                    pl)
                        plenv install-cpanm >${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                        cpanm Devel::REPL >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                        cpanm Lexical::Persistence >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                        cpanm Data::Dump::Streamer >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                        cpanm PPI >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                        cpanm Term::ReadLine >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                        cpanm Term::ReadKey >>${SIMBOL_USER}/var/log/${virtenv}.log 2>&1
                        e=$?
                    ;;
                esac
            fi
            #. }=-
        else
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function xplm:install:usage() { echo "<plid> [<pkg> [<pkg> [...]]]"; }
function xplm:install() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -gt 1 ]; then
        local plid="$1"
        case "${plid}" in
            py|pl|rb)
                :xplm:install ${plid} "${@:2}"
                e=$?
            ;;
            *)
                theme HAS_FAILED "Unknown/unsupported language ${plid}"
                e=${CODE_FAILURE?}
            ;;
        esac
    elif [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            rb|py|pl)
                cpf "Installing %{y:%s}: %{r:%s-%s}..."\
                    "${plid}"\
                    "${g_PROLANG[${plid}]}" "${g_PROLANG_VERSION[${plid}]}"
                :xplm:install ${plid}
                e=$?
                theme HAS_AUTOED $e
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
    local -i e=${CODE_FAILURE?}
    if [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            rb|py|pl)
                local virtenv="${plid}env"
                rm -f ${SIMBOL_USER_LIBEXEC?}/${virtenv}
                rm -rf ${SIMBOL_USER_VAR}/${virtenv}

                #. Unnecessary VCS purge...
                rm -rf ${SIMBOL_USER_SCM}/${virtenv}*

                e=${CODE_SUCCESS?}
            ;;
            *)
                core:raise EXCEPTION_BAD_FN_CALL
            ;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function xplm:purge:usage() { echo "<plid>"; }
function xplm:purge() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            rb|py|pl)
                cpf "Purging %{y:%s}->%{r:%s-%s}..."\
                    "${plid}"\
                    "${g_PROLANG[${plid}]}" "${g_PROLANG_VERSION[${plid}]}"
                :xplm:purge ${plid}
                e=$?
            ;;
        esac
        theme HAS_AUTOED $e
    fi

    return $e
}
#. }=-
#.   xplm:selfupdate -={
function :xplm:selfupdate() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local plid="${1}"
        local virtenv="${plid}env"
        local xplmscm=${SIMBOL_USER_VAR}/scm
        local vcs
        e=${CODE_SUCCESS?}
        case ${plid} in
            rb|py|pl)
                local -a vcses
                IFS=, read -a vcses <<< "${g_PROLANG_VCS[${plid}]}"
                for vcs in ${vcses}; do
                    cd ${xplmscm}/${vcs} >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        if ! git pull >> ${SIMBOL_USER}/var/log/${virtenv}.log 2>&1; then
                            e=${CODE_FAILURE?}
                        fi
                    fi
                done
            ;;
            *)
                e=${CODE_FAILURE?}
            ;;
        esac

        e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function xplm:selfupdate:usage() { echo "<plid>"; }
function xplm:selfupdate() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            rb|py|pl)
                cpf "Updating %{y:%s} to the latest release..." "${plid}"
                :xplm:selfupdate ${plid}
                e=$?
                theme HAS_AUTOED $e
            ;;
        esac
    elif [ $# -eq 0 ]; then
        e=${CODE_SUCCESS?}
        for plid in ${!g_PROLANG_ROOT[@]}; do
            cpf "Updating %{y:%s} to the latest release..." "${plid}"
            if :xplm:selfupdate ${plid}; then
                theme HAS_PASSED
            else
                theme HAS_FAILED
                e=${CODE_FAILURE?}
            fi
        done
    fi

    return $e
}
#. }=-
#.   xplm:shell -={
function :xplm:shell() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local plid="${1}"
        local version="${2}"
        case ${plid} in
            rb|py|pl)
                if ::xplm:loadvirtenv "${plid}" "${version}"; then
                    echo "Ctrl-D to exit environment"
                    #cd ${g_PROLANG_ROOT[${plid}]}
                    bash --rcfile <(
                        cat <<!VIRTENV
                        unset PROMPT_COMMAND
                        export HISTFILE=~/.bash_history_${plid}
                        export PS1="simbol:${plid}-${version}> "
!VIRTENV
                    ) -i
                    e=$?
                fi
            ;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function xplm:shell:usage() { echo "<plid> [<version>]"; }
function xplm:shell() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 -o $# -eq 2 ]; then
        local plid="$1"
        local version="${2:-${g_PROLANG_VERSION[${plid}]}}"
        case "${plid}" in
            py|pl|rb)
                :xplm:shell "${plid}" "${version}"
                e=$?
            ;;
            *)
                theme HAS_FAILED "Unknown/unsupported language ${plid}"
                e=${CODE_FAILURE?}
            ;;
        esac
    fi

    return $e
}
#. }=-
#.   xplm:run -={
function :xplm:run() {
    local -i e=${CODE_FAILURE?}

    if [ $# -gt 2 ]; then
        local plid="${1}"
        local version="${2}"
        local cmd="${3}"
        local cmdfull="${@:3}"
        case ${plid} in
            rb|py|pl)
                if ::xplm:loadvirtenv "${plid}" "${version}"; then
                    if [ -f "${cmd}" ]; then
                        eval '${g_PROLANG[${plid}]} ${cmdfull}'
                        e=$?
                    else
                        eval '${cmdfull}'
                        e=$?
                    fi
                fi
            ;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function xplm:run:usage() { echo "<plid> <script>"; }
function xplm:run() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 2 ]; then
        local plid="$1"
        case "${plid}" in
            py|pl|rb)
                local script="${@:2}"
                local version="${g_PROLANG_VERSION[${plid}]}"
                :xplm:run "${plid}" "${version}" "${script}"
                e=$?
            ;;
            *)
                theme HAS_FAILED "Unknown/unsupported language ${plid}"
                e=${CODE_FAILURE?}
            ;;
        esac
    fi

    return $e
}
#. }=-
#.   xplm:repl -={
function :xplm:repl() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local plid="${1}"
        case ${plid} in
            py)
                ::xplm:loadvirtenv ${plid} && python
                e=$?
            ;;
            rb)
                ::xplm:loadvirtenv ${plid} && irb
                e=$?
            ;;
            pl)
                ::xplm:loadvirtenv ${plid} && re.pl
                e=$?
            ;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function xplm:repl:usage() { echo "<plid>"; }
function xplm:repl() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local plid="$1"
        case "${plid}" in
            py|pl|rb)
                :xplm:repl ${plid} "${@:2}"
                e=$?
            ;;
            *)
                theme HAS_FAILED "Unknown/unsupported language ${plid}"
                e=${CODE_FAILURE?}
            ;;
        esac
    fi

    return $e
}
#. }=-
#. }=-
