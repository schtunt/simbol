# vim: tw=0:ts=4:sw=4:et:ft=bash

#. Site Engine -={
export SIMBOL_VERSION=1.0-rc1

#. 1.1  Date/Time and Basics -={
export NOW=$(date --utc +%s)
#. FIXME: Mac OS X needs this instead:
#. FIXME: export NOW=$(date -u +%s)
#. }=-
#. 1.2  Paths -={
: ${SIMBOL_PROFILE?}
export SIMBOL_BASENAME=$(basename -- $0)

export SIMBOL_CORE=$(readlink ~/.simbol/.scm)
export SIMBOL_CORE_BIN=${SIMBOL_CORE}/bin
export SIMBOL_CORE_LIB=${SIMBOL_CORE}/lib
export SIMBOL_CORE_LIBEXEC=${SIMBOL_CORE}/libexec
export SIMBOL_CORE_LIBJS=${SIMBOL_CORE}/lib/libjs
export SIMBOL_CORE_LIBPY=${SIMBOL_CORE}/lib/libpy
export SIMBOL_CORE_LIBSH=${SIMBOL_CORE}/lib/libsh
export SIMBOL_CORE_MOD=${SIMBOL_CORE}/module

export SIMBOL_SCM=$(readlink ~/.simbol/.scm)

export SIMBOL_UNIT=${SIMBOL_CORE}/share/unit
export SIMBOL_UNIT_TESTS=${SIMBOL_CORE}/share/unit/tests

export SIMBOL_USER=${HOME}/.simbol
export SIMBOL_USER_ETC=${SIMBOL_USER}/etc
export SIMBOL_USER_LIB=${SIMBOL_USER}/lib
export SIMBOL_USER_LIBEXEC=${SIMBOL_USER}/libexec
export SIMBOL_USER_MOD=${SIMBOL_USER}/module
export SIMBOL_USER_VAR=${SIMBOL_USER}/var
export SIMBOL_USER_VAR_CACHE=${SIMBOL_USER}/var/cache
export SIMBOL_USER_VAR_LIB=${SIMBOL_USER}/var/lib
export SIMBOL_USER_VAR_LIBEXEC=${SIMBOL_USER}/var/libexec
export SIMBOL_USER_VAR_LIBPY=${SIMBOL_USER}/var/lib/libpy
export SIMBOL_USER_VAR_LIBSH=${SIMBOL_USER}/var/lib/libsh
export SIMBOL_USER_VAR_LOG=${SIMBOL_USER}/var/log
export SIMBOL_USER_VAR_RUN=${SIMBOL_USER}/var/run
export SIMBOL_USER_MOCKENV=${SIMBOL_USER_VAR_RUN}/.mockenv
export SIMBOL_USER_VAR_SCM=${SIMBOL_USER}/var/scm
export SIMBOL_USER_VAR_TMP=${SIMBOL_USER}/var/tmp

export SIMBOL_LOG="${SIMBOL_USER_VAR_LOG}/simbol.log"

#. Site's PATH
PATH+=:${SIMBOL_CORE_LIBEXEC}
PATH+=:${SIMBOL_USER_VAR_LIBEXEC}
export PATH

export RBENV_VERSION=${RBENV_VERSION:-2.1.1}
#. Ruby -={
#. rbenv
RBENV_ROOT=${SIMBOL_USER_VAR}/rbenv
export RBENV_ROOT RBENV_VERSION
#. }=-

export PYENV_VERSION=${PYENV_VERSION:-3.4.0}
#. Python -={
PYTHONPATH+=:${SIMBOL_CORE_LIBPY}
PYTHONPATH+=:${SIMBOL_USER_VAR_LIBPY}
export PYTHONPATH

#. pyenv
PYENV_ROOT=${SIMBOL_USER_VAR}/pyenv
export PYENV_ROOT PYENV_VERSION
#. }=-

export PLENV_VERSION=${PLENV_VERSION:-5.18.2}
#. Perl -={
#. plenv
PLENV_ROOT=${SIMBOL_USER_VAR}/plenv
export PLENV_ROOT PLENV_VERSION
#. }=-
#. }=-
#. 1.3  ShUnit2 -={
export SHUNIT2=${SIMBOL_USER_VAR_LIBEXEC}/shunit2
#. }=-
#. 1.4  ShFlags -={
export SHFLAGS=${SIMBOL_USER_VAR_LIBSH}/shflags
# shellcheck disable=SC1090
source ${SHFLAGS?}

function core:bool.eval() {
    core:raise_bad_fn_call $# 1

    cat <<-!EVAL
        local -i $1;
        let $1=\${FLAGS_$1};
        unset FLAGS_$1;
	!EVAL
}
#. }=-
#. 1.5  Core Configuration -={
unset  CDPATH
export SIMBOL_DEADMAN=${SIMBOL_USER_VAR_CACHE}/deadman

declare -rig FD_STDIN=0
export FD_STDIN

declare -rig FD_STDOUT=1
export FD_STDOUT

declare -rig FD_STDERR=2
export FD_STDERR

export SIMBOL_DATE_FORMAT="%x-%X"

#. }=-
#. 1.6  Core Utilities -={
function core:len() {
    eval "local -a _$1=( \"\${$1[@]:+\${$1[@]}}\" ); echo \${#_$1[@]}"
}

function :core:age() {
    local -i e=${CODE_FAILURE}

    local filename="$1"
    if [ -e ${filename} ]; then
        local -i changed=$(stat -c %Y "${filename}")
        local -i now=$(date +%s)
        local -i elapsed
        let elapsed=now-changed
        echo ${elapsed}
        e=${CODE_SUCCESS}
    fi

    return ${e}
}

function core:global() {
    #. Usage:
    #.     core:global <context>.<key>                  (read value from store)
    #.     core:global <context>.<key> <value>          (write value to store)
    #.     core:global <context>.<key> <oper> <value>   (amend value in store)
    #.
    #. For the last case, the supported operators are math operators available
    #. to use via `let', for instance:
    #.
    #.     core:global g.delta += 4
    #.
    #. Obviously the latter case only supports integer types.

    [ $# -ge 1 -o $# -le 3 ] || core:raise EXCEPTION_BAD_FN_CALL

    local -i e=${CODE_FAILURE?}

    local context
    local key
    local globalstore

    local lockfile="${SIMBOL_USER_VAR_RUN?}/.core-global.lock.$$"
    while true; do
        if ( set -o noclobber; true > "${lockfile}" ) 2>/dev/null; then
            # shellcheck disable=SC2064
            trap "\
                SIMBOL_TRAP_ECODE=\$?;\
                rm -f \"${lockfile}\";\
                exit \${SIMBOL_TRAP_ECODE?};\
            " INT TERM EXIT

            case $# in
                1)
                    IFS='.' read -r context key <<< "${1}"
                    globalstore="$(:core:cachefile "${context}" "${key}")"
                    if [ $? -eq ${CODE_SUCCESS?} ]; then
                        cat ${globalstore}
                        e=$?
                    fi
                ;;
                2)
                    IFS='.' read -r context key <<< "${1}"
                    local value="${2}"
                    globalstore="$(:core:cachefile "${context}" "${key}")"
                    printf "%s" "${value}" > ${globalstore}
                    e=$?
                ;;
                3)
                    IFS='.' read -r context key <<< "${1}"
                    local oper="${2}"
                    local -i amendment
                    set -u; let amendment=$3 2>/dev/null; e=$?; set +u
                    if [ $e -eq ${CODE_SUCCESS?} ]; then
                        globalstore="$(:core:cachefile "${context}" "${key}")"
                        if [ $? -eq ${CODE_SUCCESS?} ]; then
                            local -i current
                            let current=$(cat ${globalstore})
                            if [ $? -eq ${CODE_SUCCESS?} ]; then
                                local -i amendment
                                # shellcheck disable=SC2034
                                let amendment=${3} 2>/dev/null
                                if [ $? -eq ${CODE_SUCCESS?} ]; then
                                    # shellcheck disable=SC1105
                                    ((current ${oper} amendment))
                                    echo ${current} > ${globalstore}
                                    e=$?
                                fi
                            fi
                        fi
                    fi
                ;;
            esac

            rm -f "$lockfile"
            break
        else
            sleep 0.1
        fi
    done

    return $e
}


#. }=-
#. 1.7  Error Code Constants -={
true
TRUE=$?
CODE_SUCCESS=${TRUE?}

false
FALSE=$?
CODE_FAILURE=${FALSE?}

declare -gA SIMBOL_BOOL=(
    [false]=${FALSE?}
    [true]=${TRUE?}
)
export SIMBOL_BOOL

#. 64..127 Internal
CODE_NOTIMPL=64
CODE_DISABLED=66
CODE_USAGE_SHORT=90
CODE_USAGE_MODS=91
CODE_USAGE_MOD=92
CODE_USAGE_FN_GUESS=93
CODE_USAGE_FN_SHORT=94
CODE_USAGE_FN_LONG=95

#. 128..255 General Error Codes
CODE_E01=128
CODE_E02=129
CODE_E03=130
CODE_E04=131
CODE_E05=132
CODE_E06=133
CODE_E07=134
CODE_E08=135
CODE_E09=136

CODE_IMPORT_GOOOD=${CODE_SUCCESS} #. good module
CODE_IMPORT_ERROR=${CODE_E01}     #. invalid/bad module (can't source/parse)
CODE_IMPORT_ADMIN=${CODE_E02}     #. administratively disabled
CODE_IMPORT_UNDEF=${CODE_E03}     #. no such module
CODE_IMPORT_UNSET=${CODE_E04}     #. no module set

export SIMBOL_DELIM=$(printf "\x07")
export SIMBOL_DELOM=$(printf "\x08")

CODE_DEFAULT=${CODE_USAGE_FN_LONG?}
#. }=-
#. 1.8  User/Profile Configuration -={
declare -g -A CORE_MODULES=(
    [tutorial]=0   [help]=1
    [unit]=1       [util]=1      [hgd]=1       [git]=1
                   [net]=1       [tunnel]=1    [remote]=1
    [xplm]=1       [rb]=1        [py]=1        [pl]=1
    [gpg]=1        [vault]=1     [cpf]=1
    [ng]=0         [ldap]=0
)

declare -gA USER_MODULES
declare -gA USER_MON_CMDGRPREMOTE
declare -gA USER_MON_CMDGRPLOCAL
declare -g  USER_LOG_LEVEL=INFO


# -n breaks remote:copy (rsync via rsync)
#declare -g g_SSH_OPTS="-n"
declare -g g_SSH_OPTS=""
if grep -qw -- -E <( ssh 2>&1 ); then
    #. Log to file if supported
    g_SSH_OPTS+=" -E ${SIMBOL_USER_VAR?}/log/ssh.log"
fi

g_SSH_CONF=${SIMBOL_USER_ETC?}/ssh.conf
[ ! -e "${g_SSH_CONF}" ] || g_SSH_OPTS+=" -F ${g_SSH_CONF}"
#. Defaults and User-Overridables -={
declare -gi USER_CPF_INDENT_SIZE=0
declare -g  USER_CPF_INDENT_STR='UNSET'
[ -v USER_HGD_RESOLVERS[@] ] || declare -gA USER_HGD_RESOLVERS

source ${SIMBOL_USER_ETC}/simbol.conf

test ! -f ~/.simbolrc || source ~/.simbolrc
: ${USER_FULLNAME?}
: ${USER_USERNAME?}
: ${USER_EMAIL?}

#. GLOBAL_OPTS 1/4 -={
declare -i g_HELP=${FALSE?}
declare -i g_VERBOSE=${FALSE?}
declare -i g_DEBUG=${FALSE?}
declare -i g_CACHED=${TRUE?}
declare -i g_LDAPHOST=-1
declare g_FORMAT=ansi
declare g_DUMP
#. }=-

source ${SIMBOL_CORE_MOD?}/cpf.sh
function cpf() { cpf:printf "$@"; return $?; }

[ ${USER_CPF_INDENT_SIZE} -ne 0 ] || USER_CPF_INDENT_SIZE=2
[ ${USER_CPF_INDENT_STR} != 'UNSET' ] || USER_CPF_INDENT_STR="$(cpf "%{@comment: \\___}")"
#. }=-

#. }=-
#. 1.9  Logging -={
declare -A SIMBOL_LOG_NAMES=(
    [EMERG]=0 [ALERT]=1 [CRIT]=2 [ERR]=3
    [WARNING]=4 [NOTICE]=5 [INFO]=6 [DEBUG]=7
)
declare -A SIMBOL_LOG_CODES=(
    [0]=EMERG [1]=ALERT [2]=CRIT [3]=ERR
    [4]=WARNING [5]=NOTICE [6]=INFO [7]=DEBUG
)
function core:log() {
    local code=${1}
    local -i level
    case ${code} in
        EMERG|ALERT|CRIT|ERR|WARNING|NOTICE|INFO|DEBUG)
            level=${SIMBOL_LOG_NAMES[${code}]}
        ;;
        *)
            code=EMERG
            level=${SIMBOL_LOG_NAMES[${code}]}
        ;;
    esac

    if [ ${module:-NilOrNotSet} != 'NilOrNotSet' ]; then
        caller=${module}
        [ ${#fn} -eq 0 ] || caller+=":${fn}"
    else
        local -i fi=0
        while true; do
            case ${FUNCNAME[${fi}]} in
                source|core:*|:core:*|::core:*) let fi++;;
                *) break;;
            esac
        done
        local caller=${FUNCNAME[${fi}]}
    fi

    if [ ${SIMBOL_LOG_NAMES[${USER_LOG_LEVEL?}]} -ge ${level} ]; then
        declare ts=$(date +"${SIMBOL_DATE_FORMAT?}")

        declare msg="$(printf "%s; %5d; %8s[%24s];" "${ts}" "${$--1}" "${code}" "${caller}")"
        [ -e "${SIMBOL_LOG?}" ] || touch "${SIMBOL_LOG?}"
        if [ -f "${SIMBOL_LOG?}" ]; then
            chmod 600 "${SIMBOL_LOG?}"
            echo "${msg} ${*:2}" >> "${SIMBOL_LOG?}"
        fi
        #printf "%s; %5d; %8s[%24s]; $@\n" "${ts}" "$$" "${code}" "$(sed -e 's/ /<-/g' <<< ${FUNCNAME[@]})" >> ${WMII_LOG}
    fi
}
#. }=-
#. 1.10 Sanity Checks / Validation -={
function validate_bash() {
    local -i e=${CODE_FAILURE?}

    local vv="${SIMBOL_USER_VAR_TMP?}/.simbol-bash-${BASH_VERSION}.verified"
    if [ -e "${vv}" ]; then
        e=${CODE_SUCCESS?}
    else
        e=${CODE_SUCCESS?}

        #. Associative Array Validation
        local -A aa

        #. Only supporting two style for updating associative array entries:
        # 1. foo=( [key]+=value )
        # 2. foo[key]=value
        # 3. foo[key]+=value
        aa[a]='A'
        [ ${#aa[@]} -eq 1 ] && [ "${aa[a]}" == 'A' ] || {
            e=2
            core:log CRIT "ValidationFailure: error code $e"
        }

        #. Avoid this style - `aa+=( ... )' - unless you know what you're doing.
        #
        # Only use this if the life-span of the variable is local, otherwise
        # if you do this on a variable that's controlled elsewhere, and the
        # mentioned keys already exist, the outcome could be one of two
        # things depending on the version of bash - the new assignment
        # values may clobber the existing ones, or they may append to them.
        aa+=( [b]='B' [c]='C' )
        [ ${#aa[@]} -eq 3 ] && [ "${aa[b]}" == 'B' ] && [ "${aa[c]}" == 'C' ] || {
            e=3
            core:log CRIT "ValidationFailure: error code $e"
        }

        aa[a]+='A'
        [ "${aa[a]}" == 'AA' ] || {
            e=4
            core:log CRIT "ValidationFailure: error code $e"
        }

        aa=( [w]='W' [x]='X' [y]='Y' [z]='Z' )
        [ ${#aa[@]} -eq 4 ] || {
            e=5
            core:log CRIT "ValidationFailure: error code $e"
        }

        #. Do not use the following as different version of bash will do
        # different things, and these are just ambiguous!
        # 2a. foo+=( [key]=value )
        # 2b. foo+=( [key]+=value )
        # 2c. foo=( [key]+=value )
        #
        # The output of the following should not match anything other than
        # some of the tests in this functioa body itself:
        #   git grep -E '[a-zA-Z0-9]+\+=\( *\['

        local buf="${SIMBOL_USER_VAR_TMP?}/.simbol-null-term-rw-test"
        local -a wstrs=( 11 'aa' 33 'stuff' ) #. TODO: \n, \r, etc.

        touch "${buf}"
        printf '%s\0' "${wstrs[@]}" >> "${buf}"

        local -a rstrs
        while read -d $'\0' y; do
            rstrs+=( "$y" )
        done < "${buf}"
        rm -f "${buf}"

        if [ "${rstrs[*]}" != "${wstrs[*]}" -o "${#rstrs[@]}" -ne "${#wstrs[@]}" ]; then
            e=6
            core:log CRIT "ValidationFailure: error code $e"
        fi
    fi

    #. Cache the Response
    [ $e -ne ${CODE_SUCCESS?} ] || touch "${vv}"

    return $e
}
#. }=-
#. 1.11 Modules -={
declare -A g_SIMBOL_IMPORTED_EXIT

function core:softimport() {
    #. 0: good module
    #. 1: invalid/bad module (can't source/parse)
    #. 2: administratively disabled
    #. 3: no such module defined
    #. 4: no module set
    core:raise_bad_fn_call $# 1

    local -i e=9

    local module="$1"
    local modulepath="${1//.//}.sh"
    local ouch="${SIMBOL_USER_VAR_TMP}/softimport.${module}.$$.ouch"
    if [ "${g_SIMBOL_IMPORTED_EXIT[${module}]:-NilOrNotSet}" == 'NilOrNotSet' ]; then
        if [ ${USER_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f ${SIMBOL_USER_MOD}/${modulepath} ]; then
                if source ${SIMBOL_USER_MOD}/${modulepath} >&${ouch}; then
                    e=${CODE_IMPORT_GOOOD?}
                    rm -f ${ouch}
                else
                    e=${CODE_IMPORT_ERROR?}
                fi
            else
                e=${CODE_IMPORT_UNDEF?}
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f ${SIMBOL_CORE_MOD}/${modulepath} ]; then
                if source ${SIMBOL_CORE_MOD}/${modulepath} >& ${ouch}; then
                    e=${CODE_IMPORT_GOOOD?}
                else
                    e=${CODE_IMPORT_ERROR?}
                    rm -f ${ouch}
                fi
            else
                e=${CODE_IMPORT_UNDEF?}
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 0 -o ${USER_MODULES[${module}]-9} -eq 0 ]; then
            #. Implicitly disabled
            e=${CODE_IMPORT_ADMIN?}
        elif [ "${module}" == "-" ]; then
            e=${CODE_IMPORT_UNSET?}
        else
            e=${CODE_IMPORT_UNDEF?}
        fi
        g_SIMBOL_IMPORTED_EXIT[${module}]=${e}
    else
        #. Import already attempted, reuse that result
        e=${g_SIMBOL_IMPORTED_EXIT[${module}]}
    fi

    return $e
}

function core:import() {
    local module
    for module in "$@"; do
        core:softimport "${module}"
        if [ $? -ne ${CODE_SUCCESS?} ]; then
            core:raise_on_failed_softimport "${module}"
            : break
        fi
    done

    return ${CODE_SUCCESS?}
}

function core:imported() {
    local -i e=${CODE_FAILURE}

    if [ $# -eq 1 ]; then
        local module=$1
        if [ ! -z "${g_SIMBOL_IMPORTED_EXIT[${module}]}" ]; then
            e=${g_SIMBOL_IMPORTED_EXIT[${module}]}
        else
            core:raise EXCEPTION_SHOULD_NOT_GET_HERE
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return ${e}
}

function core:module_path() {
    local -i e=${CODE_SUCCESS?}

    local path
    if [ $# -eq 1 ]; then
        local module="$1"

        if [ -e ${SIMBOL_CORE_MOD?}/${module//\./\/}.sh ]; then
            path=${SIMBOL_SCM?}/module
        elif [ -e ${SIMBOL_USER_MOD?}/${module//\./\/}.sh ]; then
            path=${SIMBOL_USER_MOD?}
        else
            core:raise EXCEPTION_SHOULD_NOT_GET_HERE\
                "No such module found: \`${module}'"
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    echo "${path}"
    return $e
}

function core:module_enabled() {
    local -i enabled=${FALSE?}

    if [ $# -eq 1 ]; then
        local module="$1"

        if [ -e ${SIMBOL_CORE_MOD?}/${module//\./\/}.sh ]; then
            [ ${CORE_MODULES[${module}]} -eq 0 ] || enabled=${TRUE?}
        elif [ -e ${SIMBOL_USER_MOD?}/${module//\./\/}.sh ]; then
            [ ${USER_MODULES[${module}]} -eq 0 ] || enabled=${TRUE?}
        else
            core:raise EXCEPTION_SHOULD_NOT_GET_HERE\
                "No such module found: \`${module}'"
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return ${enabled}
}

function core:modules() {
    local -i e=${CODE_FAILURE?}

    local -a modules
    if [ $# -eq 0 ]; then
        modules=( $(echo "${!CORE_MODULES[@]}" "${!USER_MODULES[@]}" | xargs -n 1 | uniq) )
    else
        modules=( "$@" )
    fi

    local module
    for module in "${modules[@]}"; do
        local -i enabled=0
        if [ ${USER_MODULES[${module}]-9} -eq 1 ]; then
            enabled=2
        elif [ ${CORE_MODULES[${module}]-9} -eq 1 ]; then
            enabled=1
        fi

        if [ ${enabled} -eq 2 -a -f ${SIMBOL_USER_MOD}/${module//\./\/}.sh ]; then
            echo ${module}
            e=${CODE_SUCCESS?}
        elif [ ${enabled} -eq 1 -a -f ${SIMBOL_CORE_MOD}/${module//\./\/}.sh ]; then
            echo ${module}
            e=${CODE_SUCCESS?}
        fi

        if [ ${module//./} == ${module} ]; then
            #. It's a module with submodules
            if [ ${enabled} -eq 2 -a -d ${SIMBOL_USER_MOD}/${module} ]; then
                for submodule in $(find ${SIMBOL_USER_MOD}/${module} -type f -name '*.sh' -printf "%f\n" | cut -d. -f1); do
                    submodule=${module}.${submodule}
                    if [ ${USER_MODULES[${submodule}]-9} -eq 1 ]; then
                        echo ${submodule}
                    elif [ ${CORE_MODULES[${submodule}]-9} -eq 1 ]; then
                        echo ${submodule}
                    fi
                done
                e=${CODE_SUCCESS?}
            elif [ ${enabled} -eq 1 -a -d ${SIMBOL_CORE_MOD}/${module} ]; then
                for submodule in $(find ${SIMBOL_CORE_MOD}/${module} -type f -name '*.sh' -printf "%f\n" | cut -d. -f1); do
                    submodule=${module}.${submodule}
                    if [ ${USER_MODULES[${submodule}]-9} -eq 1 ]; then
                        echo ${submodule}
                    elif [ ${CORE_MODULES[${submodule}]-9} -eq 1 ]; then
                        echo ${submodule}
                    fi
                done
                e=${CODE_SUCCESS?}
            fi
        fi
    done

    [ $# -eq 1 ] || e=0
    return $e
}

function core:docstring() {
    local -i e=${CODE_FAILURE}

    if [ $# -eq 1 ]; then
        local module=$1
        local modulepath=${1//./\/}.sh

        e=2 #. No such module
        if [ ${USER_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f ${SIMBOL_USER_MOD}/${modulepath} ]; then
                sed -ne '/^:<<\['${FUNCNAME}'\]/,/\['${FUNCNAME}'\]/{n;p;q}' ${SIMBOL_USER_MOD}/${modulepath}
                e=$?
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f ${SIMBOL_CORE_MOD}/${modulepath} ]; then
                sed -ne '/^:<<\['${FUNCNAME}'\]/,/\['${FUNCNAME}'\]/{n;p;q}' ${SIMBOL_CORE_MOD}/${modulepath}
                e=$?
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 0 -o ${USER_MODULES[${module}]-9} -eq 0 ]; then
            e=${CODE_FAILURE} #. Disabled
        fi
    fi

    return $e
}

function :core:requires() {
    local -i e=${CODE_FAILURE}

    if [ $# -eq 1 ]; then
        e=${CODE_SUCCESS}

        if echo "${1}"|grep -q '/'; then
            [ -e "${1}" ] || e=2
        elif ! which "${1}" > /dev/null 2>&1; then
            e=${CODE_FAILURE}
        fi
    fi

    return $e
}

function core:requires() {
    #. Usage examples:
    #.
    #.     core:requires awk
    #.     core:requires PERL LWP::Protocol::https
    local -i e=${CODE_SUCCESS}

    local caller
    case "${FUNCNAME[1]}" in
        source) caller=${FUNCNAME[2]};;
        *) caller=${FUNCNAME[1]};;
    esac
    #. TODO: Check if ${caller} is a valid/plausible executable name
    #local caller_is_mod=$(( ${USER_MODULES[${caller/:*/}]-0} + ${CORE_MODULES[${caller/:*/}]-0} ))
    #if [ ${caller_is_mod} -ne 0 ]; then
    #    core:raise EXCEPTION_MISSING_EXEC $1
    #fi

    local required;
    case $#:${1} in
        1:*)
            required="$1"
            if ! :core:requires ${required}; then
                core:log NOTICE "${caller} missing required executable ${required}"
                e=${CODE_FAILURE?}
            fi
        ;;
        *:ALL)
            e=${CODE_SUCCESS}
            for required in ${@:2}; do
                if ! :core:requires "${required}"; then
                    e=${CODE_FAILURE}
                    core:log NOTICE "${caller} missing required executable ${required}"
                    break
                fi
            done
        ;;
        *:ANY)
            e=${CODE_FAILURE}
            for required in ${@:2}; do
                if :core:requires "${required}"; then
                    e=${CODE_SUCCESS}
                    break
                fi
            done
            if [ $e -ne ${CODE_SUCCESS} ]; then
                core:log NOTICE "${caller} missing ANY of required executable ${@:2}"
            fi
        ;;
        *:PERL)
            local plid=pl
            core:softimport xplm
            if [ $? -eq ${CODE_IMPORT_GOOOD?} ]; then
                #cpf:printf "Installing missing required %{@lang:perl} module %{@pkg:${required}}..."
                for required in ${@:2}; do
                    if ! :xplm:requires ${plid} ${required}; then
                        core:log NOTICE "${caller} missing required perl module ${required}"
                        if ! :xplm:install ${plid} ${required}; then
                            core:log ERR "${caller} installation of perl module ${required} FAILED"
                            e=${CODE_FAILURE?}
                        fi
                    fi
                done
            else
                e=${CODE_FAILURE?}
            fi
        ;;
        *:PYTHON)
            local plid=py
            core:softimport xplm
            if [ $? -eq ${CODE_IMPORT_GOOOD?} ]; then
                #cpf:printf "Installing missing required %{@lang:python} module %{@pkg:${required}}..."
                for required in ${@:2}; do
                    if ! :xplm:requires ${plid} ${required}; then
                        core:log NOTICE "${caller} installing required python module ${required}"
                        if ! :xplm:install ${plid} ${required}; then
                            core:log ERR "${caller} installation of python module ${required} FAILED"
                            e=${CODE_FAILURE?}
                        fi
                    fi
                done
            else
                e=${CODE_FAILURE?}
            fi
        ;;
        *:RUBY)
            local plid=rb
            core:softimport xplm
            if [ $? -eq ${CODE_IMPORT_GOOOD?} ]; then
                #cpf:printf "Installing missing required %{@lang:ruby} module %{@pkg:${required}}..."
                for required in ${@:2}; do
                    if ! :xplm:requires ${plid} ${required}; then
                        core:log NOTICE "${caller} installing required ruby module ${required}"
                        if ! :xplm:install ${plid} ${required}; then
                            core:log ERR "${caller} installation of ruby module ${required} FAILED"
                            e=${CODE_FAILURE?}
                        fi
                    fi
                done
            else
                e=${CODE_FAILURE?}
            fi
        ;;
        *:VAULT)
            core:softimport vault
            if [ $? -eq ${CODE_IMPORT_GOOOD?} ]; then
                for required in ${@:2}; do
                    if ! :vault:read ${SIMBOL_USER_ETC}/simbol.vault ${required}; then
                        core:log NOTICE "${caller} missing required secret ${required}"
                        e=${CODE_FAILURE}
                    fi
                done
            fi
        ;;
        *:ENV)
            for required in ${@:2}; do
                if [ "${!required:-NilOrNotSet}" == 'NilOrNotSet' ]; then
                    core:log NOTICE "${caller} missing required environment variable ${required}"
                    e=${CODE_FAILURE}
                    break
                fi
            done
        ;;
        *) core:raise EXCEPTION_BAD_FN_CALL "${@}";;
    esac

    test $e -eq 0 && return $e || exit $e
    return $e
}
#. }=-
#. 1.12 Caching -={
#. 0 means cache forever (default)
#. >0 indeicates TTL in seconds
declare -g g_CACHE_TTL=0

mkdir -p ${SIMBOL_USER_VAR_CACHE?}
chmod 3770 ${SIMBOL_USER_VAR_CACHE?} 2>/dev/null

#. Keep track if cache was used globally
declare g_CACHE_USED=${SIMBOL_USER_VAR_CACHE?}/.cache_used
rm -f ${g_CACHE_USED?}

function core:return() { return $1; }

function g_CACHE_OUT() {
    : ${l_CACHE_SIG:="${FUNCNAME[1]}"}
    g_CACHE_FILE="$(:core:cachefile "${l_CACHE_SIG}" "$*")"
    :core:cached "${g_CACHE_FILE}"
    return $?
}

function g_CACHE_IN() {
    local -i e=$?

    sync

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        cat ${g_CACHE_FILE?}
    else
        rm -f ${g_CACHE_FILE?}
    fi

    #:core:cache "${g_CACHE_FILE}"

    return $e
}
:<<! USAGE:
Any function (private or internal only, do not try and cache-enable public
functions!) can be cache-enabled simply by insertin two lines; one right at
the start of the function, and one right at the end:

function <module>:<function>() {
  #. Optional...
  #local l_CACHE_SIG="optional-custom-sinature-hash:template:funk/\$3";

  #. vvv 1. Use cache and return or continue
  local -i l_CACHE_TTL=600; g_CACHE_OUT "\$*" || (
    local -i e=\${CODE_DEFAULT?}

    ...

    return \$e
  ) > \${g_CACHE_FILE}; g_CACHE_IN; return \$?
  #. ^^^ 2. Update cache if previous did not return
}
function :<module>:<function>() { #. Same as above...; }
function ::<module>:<function>() { #. Same as above...; }

Also take note of the indenting of 2 spaces, this makes it non-obstructive, so
you can maintain the usual 4-space indents, and insert these in and out as
you please.

Note that public functions that take local shflags will not allow caching,
and will generate an error.

Don't use this all over the place, only on computationally expensive code
or otherwise slow code (network latency) that is expected to also produce the
same result almost alll the time, for example dns might be a good candidate,
whereas remote code execution is probably a bad candidate.
!

function :core:cachefile() {
    #. Constructs and prints a cachefile path
    local effective_format="${g_FORMAT?}"

    local cachefile=${SIMBOL_USER_VAR_CACHE?}

    if [ $# -eq 2 ]; then
        #. Automaticly named cachefile...
        local modfn="$1"
        local effective_format=${g_FORMAT?}
        if [ ${g_FORMAT?} == "ansi" ] && [[ $1 =~ ^: ]] ; then
            effective_format='text'
        fi

        cachefile+=/${1//:/=}
        cachefile+=+${g_VERBOSE?}
        cachefile+=+$(md5sum <<< "$2"|cut -b -32);
    elif [ $# -eq 1 ]; then
        #. Hand-picked signature from caller...

        cachefile+=/
        cachefile+=+${g_VERBOSE?}
        cachefile+=+${1}
        effective_format='sig'
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    cachefile+=".${effective_format}"
    echo "${cachefile}"

    #. Return code is 0 if the files exists, and 1 otherwise
    local -i e=${CODE_FAILURE?}
    [ ! -r "${cachefile}" ] || e=${CODE_SUCCESS?}

    return $e
}

function :core:cache() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local cachefile="$1"

        :> ${cachefile}
        chmod 600 ${cachefile}
        tee -a ${cachefile}

        e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function :core:cached() {
    : ${g_CACHED?}
    : ${g_CACHE_USED?}
    local -i e=${CODE_FAILURE?}

    if [ ${g_CACHED} -eq 1 ]; then
        #. TTL < 0 means don't cache
        #. TTL of 0 means cache forever
        #. TTL > 0 means to cache for TTL seconds

        if [ $# -eq 1 ]; then
            local cachefile="$1"
            local -i ttl=${l_CACHE_TTL:-${g_CACHE_TTL?}}
            if [ ${ttl} -ge 0 ]; then
                local -i age
                age=$(:core:age ${cachefile})
                if [ $? -eq ${CODE_SUCCESS?} ]; then
                    if [ ${ttl} -gt 0 -a ${age} -ge ${ttl} ]; then
                        #. Cache Miss (Expiry)
                        rm -f ${cachefile}
                        e=${CODE_FAILURE?}
                        core:log DEBUG "Cache Miss: {ttl:${ttl}, age:${age}}"
                    else
                        #. Cache Hit
                        echo ${cachefile} >> ${g_CACHE_USED?}
                        #cat ${cachefile}
                        core:log DEBUG "Cache Hit: {ttl:${ttl}, age:${age}}"
                        e=${CODE_SUCCESS?}
                    fi
                else
                    #. Cache Miss (No Cache)
                    e=${CODE_FAILURE?}
                fi
            fi
        else
            core:raise EXCEPTION_BAD_FN_CALL
        fi
    fi

    return $e
}
#. }=-
#. 1.13 Execution -={
: ${USER_USERNAME:=$(whoami)}

function ::core:execute:internal() {
    local module=$1
    local fn=$2
    :${module}:${fn} "${@:3}"
    return $?
}

function ::core:execute:private() {
    local module=$1
    local fn=$2
    ::${module}:${fn} "${@:3}"
    return $?
}

function ::core:flags.eval() {
    local -i e=${CODE_FAILURE?}

    #. Extract the first 2 non-flag tokens as module and function
    #. All remaining tokens are added to the new argv array
    local -a argv
    local -i argc=0
    local module=-
    local fn=-

    local arg
    for arg in "${@}"; do
        if [ "${arg:0:1}" != '-' ]; then
            if [ "${module}" == "-" ]; then
                module="${arg?}"
            elif [ "${fn}" == "-" ]; then
                fn="${arg?}"
            else
                argv[${argc}]="${arg}"
                ((argc++))
            fi
        else
            argv[${argc}]="${arg}"
            ((argc++))
        fi
    done
    set -- "${argv[@]+${argv[@]}}"

    #. GLOBAL_OPTS 2/4: Our generic and global options -={
    DEFINE_boolean help     false            "<help>"                   H
    DEFINE_boolean verbose  false            "<verbose>"                V
    DEFINE_boolean debug    false            "<debug>"                  D
    DEFINE_boolean cached   true             "<use-cache>"              C
    DEFINE_integer ldaphost "${g_LDAPHOST}"  "<ldap-host-index>"        L
    DEFINE_string  format   "${g_FORMAT}"    "ansi|text|csv|html|email" F
    #. }=-

    #. Out module/function-specific options
    local -a extra
    if [ ${#module} -gt 0 ]; then
        core:softimport ${module}
        if [ $? -eq ${CODE_IMPORT_GOOOD?} ]; then
            local _fn="$(:core:complete ${module} ${fn})"
            if [ "$(type -t "${module}:${_fn}:shflags")" == "function" ]; then
                #. shflags function defined, so let's use it...
                while read f_type f_long f_default f_desc f_short; do
                    DEFINE_${f_type} "${f_long}" "${f_default}" "${f_desc}" "${f_short}"
                    extra+=( FLAGS_${f_long} )
                done < <( ${module}:${_fn}:shflags )
            fi
        fi
        cat <<!
declare -g module_22884db148f0ffb0d830ba431102b0b5=${module:-}
declare -g fn_4d9d6c17eeae2754c9b49171261b93bd=${fn:-}
!
    fi

    #. Process it all
    FLAGS "${@}" #>& /dev/null
    if [ $? -eq 0 ]; then
        #. GLOBAL_OPTS 3/4 -={
        eval "$(core:bool.eval help)"; g_HELP=${help?}
        eval "$(core:bool.eval verbose)"; g_VERBOSE=${verbose?}
        eval "$(core:bool.eval debug)"; g_DEBUG=${debug?}
        eval "$(core:bool.eval cached)"; g_CACHED=${cached?}

        if grep -qw -- -E <<< "${g_SSH_OPTS?}"; then
            case ${g_DEBUG?}:${g_VERBOSE?} in
                ${FALSE?}:0) g_SSH_OPTS+=" -q";;
                ${FALSE?}:1) g_SSH_OPTS+=" -v";;
                ${TRUE?}:0) g_SSH_OPTS+=" -vv";;
                ${TRUE?}:1) g_SSH_OPTS+=" -vvv";;
            esac
        fi

        #. Last amendment to g_SSH_OPTS
        g_SSH_OPTS+=" ${USER_SSH_OPTS:-}"

        #. Everything else is straight-forward:
        g_LDAPHOST=${FLAGS_ldaphost?}; unset FLAGS_ldaphost
        g_FORMAT=${FLAGS_format?}; unset FLAGS_format
        #. }=-

        cat <<!
#. GLOBAL_OPTS 4/4 -={
declare g_HELP=${g_HELP?}
declare g_VERBOSE=${g_VERBOSE?}
declare g_DEBUG=${g_DEBUG?}
declare g_CACHED=${g_CACHED?}
declare g_LDAPHOST=${g_LDAPHOST?}
declare g_FORMAT=${g_FORMAT?}
declare g_SSH_OPTS="${g_SSH_OPTS?}"
#. }=-
set -- ${FLAGS_ARGV?}
!
        e=${CODE_SUCCESS}
    else
        cat <<!
g_DUMP="$(FLAGS "$@" 2>&1|sed -e '1,2 d' -e 's/^/    /')"
!
    fi

    if [ $e -eq ${CODE_SUCCESS} -a $(core:len extra) -gt 0 ]; then
        cat <<!
$(for key in ${extra[@]}; do echo ${key}=${!key}; done)
!
    fi

    return $e
}

function :core:execute() {
    local -i e=${CODE_USAGE_MODS}

    local -i sic

    if [ $# -ge 1 ]; then
        e=${CODE_USAGE_MOD}

        if [ $# -ge 2 ]; then
            #. FIXME: Why do these need to be global?  I did try to change them
            #. FIXME: to locals, however all unit-tests (other than util) broke.
            declare -g module=$1
            declare -g fn=$2

            if [ "$(type -t ${module}:${fn})" == "function" ]; then
                case ${g_FORMAT} in
                    html|email|ansi) [ -t 1 ]; sic=$((~$?+2)) ;;
                    dot|text|png) sic=0 ;;
                    *) core:raise EXCEPTION_SHOULD_NOT_GET_HERE "Format checks should have already taken place!";;
                esac

                cpf:initialize ${sic}
                ${module}:${fn} "${@:3}"
                e=$?

                if [ ${sic} -eq 1 ]; then
                    if [ "$(type -t ${module}:${fn}:alert)" == "function" ]; then
                        cpf:printf "%{r:ALERTS}%{@profile:%s} %{@module:%s}:%{@function:%s}:\n"\
                            "${SIMBOL_PROFILE?}" "${module}" "${fn}"
                        while read -a line; do
                            local alert=${line[0]}
                            theme ${alert} "${line:1}"
                        done < <(${module}:${fn}:alert)
                        cpf:printf
                    fi

                    if [ -f ${g_CACHE_USED?} -a ${g_VERBOSE?} -eq 1 ]; then
                        cpf:printf
                        local age
                        local cachefile
                        cpf:printf "%{@comment:#. Cached Data} %{r:%s}\n" "-=["
                        while read cachefile; do
                            age=$(:core:age "${cachefile}")

                            case $(::core:cache:cachetype ${cachefile}) in
                                output)
                                    cpf:printf "    %{b:%s} is %{@int:%ss} old..." "$(basename ${cachefile})" "${age}"
                                ;;
                                file)
                                    cpf:printf "    %{@path:%s} is %{@int:%ss} old..." "${cachefile}" "${age}"
                                ;;
                            esac
                            theme WARN "CACHED"
                        done < ${g_CACHE_USED}
                        cpf:printf "%{@comment:#.} %{r:%s}\n" "]=-"
                    fi
                fi

                if [ ${sic} -eq 1 -a $e -eq 0 -a ${SECONDS} -ge 30 ]; then
                    theme INFO "Execution time was ${SECONDS} seconds"
                fi
            else
                theme ERR_INTERNAL "Function ${module}:${fn} not defined!"
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "Expected 1 or more arguments"
    fi

    return $e
}

function :core:git() {
    cd ${SIMBOL_SCM?}
    git "$@"
    return $?
}

function ::core:dereference.eval() {
    #. NOTE: you myst eval the output of this function!
    #. take $1, and make it equal to ${$1}
    #.
    #. If the variable starts with _, remove it in the new variable
    #. Input: _my_var=something; something=( A B C )
    #. Output: my_var=( A B C )
    if [ ! -t 1 ]; then
        echo "unset ${1}; eval \$(declare -p ${!1}|sed -e 's/declare -\([a-qs-zA-Z]*\)r*\([a-qs-zA-Z]*\) '${!1}'=\(.*\)/declare -\1\2 ${1#_}=\3/')";
    else
        core:raise EXCEPTION_BAD_FN_CALL \
            "This function must be called in a subshell, and evaled afterwards!"
    fi
}

function :core:functions() {
    local -i e=${CODE_FAILURE}
    if [ $# -eq 2 ]; then
        local fn_type=$1
        local module=$2
        case ${fn_type} in
            public)
                declare -F |
                    awk -F'[ ]' '$3~/^'${module}':/{print$3}' |
                    awk -F ':+' '{print$2}' |
                    sort -u
                e=${CODE_SUCCESS}
            ;;
            private)
                declare -F |
                    awk -F'[ ]' '$3~/^:'${module}':/{print$3}' |
                    awk -F ':+' '{print$3}' |
                    sort -u
                e=${CODE_SUCCESS}
            ;;
            internal)
                declare -F |
                    awk -F'[ ]' '$3~/^::'${module}':/{print$3}' |
                    awk -F ':+' '{print$3}' |
                    sort -u
                e=${CODE_SUCCESS}
            ;;
            *) core:raise EXCEPTION_BAD_FN_CALL;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function :core:usage() {
#. FIXME: The caching here is unaware of -O|--options that are eaten up by
#. FIXME: shflags before this function is called, and so caching becomes
#. FIXME: destructive.  Additionally, it breaks the --long help which never
#. FIXME: displays anymore once this is enabled.
# g_CACHE_OUT "$*" || {
    local module=${1:-NilOrNotSet}
    local fn=${2:-NilOrNotSet}
    local mode=${3---short}
    [ $# -eq 2 ] && mode=${3---long}

    if [ ${#FUNCNAME[@]} -lt 4 ]; then
        cpf:printf "%{+bo}%{n:simbol}%{-bo} %{@version:%s}, %{w:bash framework}\n" ${SIMBOL_VERSION?}
        cpf:printf "Using %{@path:%s} %{@version:%s}" "${BASH}" "${BASH_VERSION}"
        if [ ${#SIMBOL_SHELL} -eq 0 ]; then
            cpf:printf " %{@comment:(export SIMBOL_SHELL to override)}"
        else
            cpf:printf " %{r:(SIMBOL_SHELL override active)}"
        fi
        printf "\n\n"
    fi

    local usage_prefix="%{w:Usage} for %{@user:${USER_USERNAME}}@%{g:${SIMBOL_PROFILE}}"
    if [ $# -eq 0 ]; then
        #. Usage for simbol
        cpf:printf "${usage_prefix}\n"
        for profile in USER_MODULES CORE_MODULES; do
            cpf:printf "  %{g:${profile}}...\n"
            eval $(::core:dereference.eval profile) #. Will create ${profile} array
            for module in ${!profile[@]}; do (
                local docstring=$(core:docstring ${module})
                core:softimport ${module}
                local -i ie=$?
                if [ $ie -eq ${CODE_IMPORT_ADMIN?} ]; then
                    continue
                elif [ $ie -eq ${CODE_IMPORT_GOOOD?} ]; then
                    local -a fn_public=( $(:core:functions public ${module}) )
                    local -a fn_private=( $(:core:functions private ${module}) )
                    if [ ${#fn_public[@]} -gt 0 ]; then
                        cpf:printf "    "
                    else
                        cpf:printf "%{y:!   }"
                    fi
                else
                    cpf:printf "%{r:!!! }"
                fi

                cpf:printf "%{n:%s} %{@module:%s}:%{+bo}%{@int:%s}%{-bo}/%{@int:%s}"\
                    "${SIMBOL_BASENAME?}" "${module}"\
                    "$(core:len fn_public)" "$(core:len fn_private)"

                if [ $ie -eq ${CODE_IMPORT_GOOOD?} ]; then
                    cpf:printf "%{@comment:%s}\n" "${docstring:+; ${docstring}}"
                else
                    cpf:printf "; %{@error:Error loading module}\n"
                fi
            ); done | sort
        done
    elif [ $# -eq 1 ]; then
        core:softimport ${module}
        local -i ie=$?
        if [ $ie -eq ${CODE_IMPORT_GOOOD?} ]; then
            if [ ${g_ONCE_WHOAMI:-0} -eq 0 ]; then
                cpf:printf "${usage_prefix} %{@module:${module}}\n"
                g_ONCE_WHOAMI=1
            fi
            for module in $(core:modules ${module}); do
                core:softimport ${module}
                if [ $? -eq ${CODE_SUCCESS?} ]; then
                    local -a fns=( $(:core:functions public ${module}) )
                    for fn in ${fns[@]}; do
                        local usage_fn="${module}:${fn}:usage"
                        local usagestr
                        if [ "$(type -t ${usage_fn})" == "function" ]; then
                            while read usagestr; do
                                cpf:printf "    %{n:%s} %{@module:%s}:%{@function:%s} %{c:%s}\n"\
                                    "${SIMBOL_BASENAME?}" "${module}" "${fn}" "${usagestr}"
                            done < <( ${usage_fn} )
                        else
                            usagestr="{no-args}"
                            cpf:printf "    %{n:%s} %{@module:%s}:%{@function:%s} %{n:%s}\n"\
                                "${SIMBOL_BASENAME?}" "${module}" "${fn}" "${usagestr}"
                        fi
                    done
                fi
            done

            if [ ${g_VERBOSE?} -eq 1 -a ${#FUNCNAME[@]} -lt 4 ]; then
                cpf:printf "\n%{@module:${module}} %{g:changelog}\n"
                local modfile=${SIMBOL_USER_MOD}/${module}
                [ -f ${modfile} ] || modfile=${SIMBOL_CORE_MOD}/${module}
                cd ${SIMBOL_CORE}
                :core:git --no-pager\
                    log --follow --all --format=format:'    |___%C(bold blue)%h%C(reset) %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold white)— %an%C(reset)%C(bold yellow)%d%C(reset)'\
                    --abbrev-commit --date=relative -- "${modfile}"
                cd ${OLDPWD}
                echo
            fi
            echo
        fi
    elif [ $# -ge 2 ]; then
        cpf:printf "${usage_prefix} %{@module:%s}:%{@function:%s}\n"\
            "${module}" "${fn}"

        local usage_fn=${module}:${fn}:usage
        if [ "$(type -t $usage_fn)" == "function" ]; then
            while read usagestr; do
                cpf:printf "    %{n:%s} %{@module:%s}:%{@function:%s} %{c:%s}\n"\
                    "${SIMBOL_BASENAME?}" "${module}" "${fn}" "${usagestr}"
            done < <(${usage_fn})
        else
            cpf:printf "    %{n:%s} %{@module:%s}:%{@function:%s} %{n:%s}\n"\
                "${SIMBOL_BASENAME?}" "${module}" "${fn}" "{no-args}"
        fi

        case ${mode} in
            --short) : pass ;;
            --long)
                local usage_l="${module}:${fn}:help"
                local -i i=0
                if [ "$(type -t $usage_l)" == "function" ]; then
                    cpf:printf
                    local indent=""
                    while read line; do
                        cpf:printf "%{c:%s}\n" "${indent}${line}"
                        [ $i -eq 0 ] && indent+="    "
                        ((i++))
                    done <<< "`${usage_l}`"
                fi

                if [ "${g_DUMP:-NilOrNotSet}" != 'NilOrNotSet' ]; then
                    cpf:printf
                    cpf:printf "%{c:%s}\n" "Flags:"
                    echo "${g_DUMP}"
                fi
            ;;
        esac
    fi
# } > ${g_CACHE_FILE?}; g_CACHE_IN; return $?
}

function :core:complete() {
    local modulestr=$1
    local prefix="AC_${modulestr//./_}_"
    local fn=$2
    if [ "${fn}" != '-' ]; then
        local hit
        hit=$(declare -F ${modulestr}:${fn})
        if [ $? -eq 0 ]; then
            echo ${fn}
        else
            for afn in $(declare -F|awk -F'[ :]' '$3~/^'${modulestr}'$/{print$4}'|sort -n); do
                local ${prefix}${afn//./_}=1
            done
            set +u
            local -a completed=( $(eval echo "\${!${prefix}${fn//./_}*}") )
            if echo ${completed[@]} | grep -qE "\<${prefix}${fn//./_}\>"; then
                echo ${fn}
            else
                echo ${completed[@]//${prefix}/}
            fi
            set -u
        fi
    fi
}

function core:wrapper() {
    if [ -e ${SIMBOL_DEADMAN?} ]; then
        theme HAS_FAILED "CRITICAL ERROR; ABORTING!" >&2
        exit 1
    fi

    local -i e=${CODE_USAGE_MODS}

    local setdata
    setdata="$(::core:flags.eval "${@}")"
    local -i e_flags=$?
    core:log DEBUG "core:flags.eval() returned ${e_flags}"

    eval "${setdata}" #. -={
    #. NOTE: This sets module, fn, $@, etc.
    module=${module_22884db148f0ffb0d830ba431102b0b5?}
    fn=${fn_4d9d6c17eeae2754c9b49171261b93bd?}
    #. }=-
    core:log DEBUG "core:wrapper(module=${module}, fn=${fn}, argv=( $@ ))"
    [ ${g_DEBUG} -ne ${TRUE} ] || cpf:initialize 1

    local regex=':+[a-z0-9]+(:[a-z0-9]+) |*'

    core:softimport "${module}"
    case $?/${module?}/${fn?} in
        ${CODE_IMPORT_UNSET?}/-/-)                                                                                       e=${CODE_USAGE_MODS} ;;
        ${CODE_IMPORT_GOOOD?}/*/-)    :core:execute          ${module}                2>&1 | grep --color -E "${regex}"; e=${PIPESTATUS[0]}   ;;
        ${CODE_IMPORT_GOOOD?}/*/::*) ::core:execute:private  ${module} ${fn:2} "${@}" 2>&1 | grep --color -E "${regex}"; e=${PIPESTATUS[0]}   ;;
        ${CODE_IMPORT_GOOOD?}/*/:*)  ::core:execute:internal ${module} ${fn:1} "${@}" 2>&1 | grep --color -E "${regex}"; e=${PIPESTATUS[0]}   ;;
        ${CODE_IMPORT_GOOOD?}/*/*)
            local -a completed=( $(:core:complete ${module} ${fn}) )

            local -A supported_formats=( [html]=1 [email]=1 [ansi]=1 [text]=1 [dot]=0 )
            if [ "$(type -t ${module}:${fn}:formats)" == "function" ]; then
                for format in $( ${module}:${fn}:formats ); do
                    supported_formats[${format}]=2
                done
            fi

            if [ ${#completed[@]} -eq 1 ]; then
                fn=${completed}
                if [ ${e_flags} -eq ${CODE_SUCCESS} ]; then
                    if [ ${g_FORMAT?} == "email" ]; then
                        :core:execute ${module} ${completed} "${@}" 2>&1 |
                            grep --color -E "${regex}" |
                            ${SIMBOL_CORE_LIBEXEC}/ansi2html |
                            mail -a "Content-type: text/html" -s "Site Report [${module} ${completed} ${@}]" ${USER_EMAIL}
                        e=${PIPESTATUS[3]}
                    elif [ ${g_FORMAT?} == "html" ]; then
                        :core:execute ${module} ${completed} "${@}" 2>&1 |
                            grep --color -E "${regex}" |
                            ${SIMBOL_CORE_LIBEXEC}/ansi2html
                        e=${PIPESTATUS[2]}
                    elif [ "${supported_formats[${g_FORMAT}]:-NilOrNotSet}" == 'NilOrNotSet' ]; then
                        theme ERR_USAGE "That is not a supported format."
                        e=${CORE_FAILURE}
                    elif [ ${supported_formats[${g_FORMAT}]} -gt 0 ]; then
                        [ ${g_DEBUG} -eq ${FALSE?} ] || set -x
                        :core:execute ${module} ${completed} "${@}"
                        e=$?
                        [ ${g_DEBUG} -eq ${FALSE?} ] || set +x
                    else
                        theme ERR_USAGE "This function does not support that format."
                        e=${CORE_FAILURE}
                    fi

                    if [ $e -eq ${CODE_NOTIMPL?} ]; then
                        theme ERR_USAGE "This function has not yet been implemented."
                    fi
                else
                    e=${CODE_USAGE_FN_LONG?}
                fi
            elif [ ${#completed[@]} -gt 1 ]; then
                theme ERR_USAGE "Did you mean one of the following:"
                for acfn in ${completed[@]}; do
                    echo "    ${SIMBOL_BASENAME} ${module} ${acfn}"
                done
                e=${CODE_USAGE_FN_GUESS}
            else
                core:log ERR "${module}:${fn} not defined"
                theme ERR_USAGE "${module}:${fn} not defined"
                e=${CODE_USAGE_MOD}
            fi
        ;;
        ${CODE_IMPORT_UNDEF?}/-/-) e=${CODE_USAGE_MODS};;
        ${CODE_IMPORT_UNDEF?}/*/*)
            theme ERR_USAGE "Module ${module} has not been defined"
            e=${CODE_FAILURE}
        ;;
        ${CODE_IMPORT_ERROR?}/*/*)
            theme HAS_FAILED "Module ${module} has errors; see ${SIMBOL_LOG?}"
            e=${CODE_FAILURE}
        ;;
        ${CODE_IMPORT_ADMIN?}/*/*)
            theme ERR_USAGE "Module ${module} has been administratively disabled"
            e=${CODE_DISABLED}
        ;;
        */*/*)
            e=${CODE_FAILURE}
            core:raise EXCEPTION_BAD_FN_CALL "Check call/caller to/of \`core:softimport $*'"
        ;;
    esac

    case $e in
        ${CODE_USAGE_MODS?})    :core:usage ;;
        ${CODE_USAGE_SHORT?})   :core:usage ${module} ;;
        ${CODE_USAGE_MOD?})     :core:usage ${module} ;;
        ${CODE_USAGE_FN_LONG?}) :core:usage ${module} ${fn} ;;
        0) : noop;;
    esac

    return $e
}
#. }=-
#. 1.14 Exceptions -={
EXCEPTION=63
EXCEPTION_BAD_FN_CALL=64
EXCEPTION_BAD_FN_RETURN_CODE=65
EXCEPTION_MISSING_EXEC=70
EXCEPTION_BAD_MODULE=71
EXCEPTION_DEPRECATED=72
EXCEPTION_MISSING_PERL_MOD=80
EXCEPTION_MISSING_PYTHON_MOD=81
EXCEPTION_MISSING_USER=82
EXCEPTION_USER_ERROR=83
EXCEPTION_INVALID_FQDN=90
# TODO: Move the comments below into the RAISE array -={
EXCEPTION_NOT_IMPLEMENTED=124        #. Sorry, not implemented (developer sloth)
EXCEPTION_PERMANENT_ERROR=125        #. Can get here, but can't be handled (user error)
EXCEPTION_SHOULD_NOT_GET_HERE=126    #. Should not ever get here (developer error)
EXCEPTION_UNHANDLED=127              #. Should be handled, but isn't (developer sloth)
#. }=-
declare -A RAISE=(
    [${EXCEPTION_BAD_FN_CALL}]="Bad function call internally"
    [${EXCEPTION_BAD_FN_RETURN_CODE}]="Bad function return code internally"
    [${EXCEPTION_MISSING_EXEC}]="Required executable not found"
    [${EXCEPTION_MISSING_USER}]="Required user environment not set, or set to nil"
    [${EXCEPTION_BAD_MODULE}]="Bad module"
    [${EXCEPTION_USER_ERROR}]="User error"
    [${EXCEPTION_DEPRECATED}]="Deprecated function call"
    [${EXCEPTION_MISSING_PERL_MOD}]="Required perl module missing"
    [${EXCEPTION_MISSING_PYTHON_MOD}]="Required python module missing"
    [${EXCEPTION_SHOULD_NOT_GET_HERE}]="Process flow should never get here!"
)

function core:raise_bad_fn_call() {
    local -i received
    let received=$1

    local -i -a expected=( ${*:2} )

    local -i e=${CODE_FAILURE?}

    local -i exp
    for exp in ${expected[*]}; do
        if [ ${exp} -eq ${received} ]; then
            e=${CODE_SUCCESS?}
            break
        fi
    done

    if [ $e -ne ${CODE_SUCCESS?} ]; then
        core:raise EXCEPTION_BAD_FN_CALL\
            "Expected one of ( ${expected[*]} ) arguments but received \`${received}'"
    fi
}

function core:compare() {
    local -i n1; let n1=$1
    local op="$2"
    local -i n2; let n2=$3
    eval "[ ${n1} -${op} ${n2} ]"
    return $?
}

function core:raise_bad_fn_call_compare() {
    local -i received; let received=$1
    local op="$2"
    local -i limit; let limit=$3
    if ! core:compare "$@"; then
        core:raise EXCEPTION_BAD_FN_CALL\
            "Expected \$\# -${op} ${limit}, received \`[${reveived}]'"
    fi
}

function core:raise_on_failed_softimport() {
    local module="$1"
    core:raise_bad_fn_call $# 1

    local ouch="${SIMBOL_USER_VAR_TMP}/softimport.${module}.$$.ouch"
    if [ -e "${ouch}" ]; then
        cat "${ouch}"

        core:raise EXCEPTION_PERMANENT_ERROR "Module soft import failure for \`${module}'"
    fi
}

function core:raise() {
    : !!! CRITICAL FAILURE !!!
    : >${SIMBOL_DEADMAN?}

    local -i e=$1

    if [[ $- =~ x ]]; then
        : !!! Exiting raise function early as we are being traced !!!
    else
        cpf:printf "%{+r}EXCEPTION%{bo:[%s->%s]}: %s%{-r}:\n" "${e}" "$1" "${RAISE[$e]-[UNKNOWN EXCEPTION:$e]}" >&2
        cpf:printf "\n%{+r}  !!! %{bo:%s}%{-r}\n\n" "${@:2}" >&2

        cpf:printf "%{+r}EXCEPTION%{bo:[Traceback]}%{-r}:\n" >&2
        if [ ${#module} -gt 0 ]; then
            if [ ${#fn} -gt 0 ]; then
                cpf:printf "Function %{c:${module}:${fn}()}" 1>&2
                echo "Critical failure in function ${module}:${fn}()" >> ${SIMBOL_DEADMAN?}
            else
                cpf:printf "Module %{c:${module}}" 1>&2
                echo "Critical failure in module ${module}" >> ${SIMBOL_DEADMAN?}
            fi
        else
            cpf:printf "File %{@path:$0}" 1>&2
            echo "Critical failure in file ${0}" >> ${SIMBOL_DEADMAN?}
        fi

        cpf:printf " %{r:failed with exception} %{g:$e}; %{c:traceback}:\n" 1>&2
        local i=0
        local code
        local -i frames=${#BASH_LINENO[@]}
        #. ((frames-2)): skips main, the last one in arrays
        for ((i=frames-2; i>=0; i--)); do
            cpf:printf "  File %{g:%s}, line %{g:%s}, in %{r:%s}\n" \
                "${BASH_SOURCE[i+1]}" "${BASH_LINENO[i]}" "${FUNCNAME[i+1]}()" 1>&2

            # Grab the source code of the line
            code=$(sed -n "${BASH_LINENO[i]}{s/^ *//;s/%/%%/g;p}" "${BASH_SOURCE[i+1]}")
            cpf:printf "    %{w:>>>} %{c:%s}\n" "${code}" 1>&2
        done
    fi

    exit $e
}
#. }=-
#. 1.15 Mocking -={
function mock:write() {
    core:raise_bad_fn_call $# 0 1
    local context="${1:-default}"
    cat >>${SIMBOL_USER_MOCKENV?}.${context}
    return $?
}

function mock:save() {
    core:raise_bad_fn_call $# 0 1 2

    local -i e=${CODE_FAILURE?}
    local context="${1:-default}"
    local savefile="/tmp/mock-${context}-${2:-$$}.sh"
    if cp "${SIMBOL_USER_MOCKENV?}.${context}" "${savefile}"; then
        let e=${CODE_SUCCESS?}
        echo "${savefile}"
    fi

    return $e
}

function mock:clear() {
    core:raise_bad_fn_call $# 0 1

    local -i e

    if [ $# -eq 0 ]; then
        rm -f "${SIMBOL_USER_MOCKENV?}".*
        mock:context
        let e=$?
    elif [ $# -eq 1 ]; then
        local context="${1:-default}"
        truncate --size 0 "${SIMBOL_USER_MOCKENV?}.${context}"
        let e=$?
    fi

    return $e
}

function mock:context() {
    core:raise_bad_fn_call $# 0 1

    local context="${1:-default}"
    touch "${SIMBOL_USER_MOCKENV?}.${context}"
    ln -sf "${SIMBOL_USER_MOCKENV?}.${context}" "${SIMBOL_USER_MOCKENV?}"
    return $?
}

function mock:wrapper() {
    local -i e=${CODE_FAILURE?}

    local closure
    function closure() {
        if [ ! -r "${SIMBOL_USER_MOCKENV?}" ]; then
            mock:context default
        fi
        if [ -r "${SIMBOL_USER_MOCKENV?}" ]; then
            source "${SIMBOL_USER_MOCKENV?}"
        fi

        core:wrapper "${@}"
        local -i _e=$?

        unset closure
        return $_e
    }

    local data
    data="$(closure "${@}")"
    e=$?

    echo "${data}"

    return $e
}
#. }=-
#. }=-
