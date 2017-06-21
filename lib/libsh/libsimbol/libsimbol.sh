# vim: tw=0:ts=4:sw=4:et:ft=bash
#shellcheck disable=SC2166

# shellcheck source=lib/libsh/libsimbol/constants.sh
source ~/.simbol/.scm/lib/libsh/libsimbol/constants.sh

unset  CDPATH

#. Site Engine -={
#. 1.1  Date/Time and Basics -={
let NOW=$(date --utc +%s)
export NOW
#. FIXME: Mac OS X needs this instead:
#. FIXME: export NOW=$(date -u +%s)
#. }=-
#. 1.3  ShUnit2 -={
export SHUNIT2=${SIMBOL_USER_VAR_LIBEXEC}/shunit2
#. }=-
#. 1.4  ShFlags -={
export SHFLAGS="${SIMBOL_USER_VAR_LIBSH}/shflags"
# shellcheck disable=SC1090
source "${SHFLAGS?}"

function core:decl_shflags.eval() {
    #requires shellcheck's `disable=SC2086,SC2154' in caller
    core:raise_bad_fn_call_unless $# gt 1

    local key_type=$1
    case "${key_type}" in
        bool|int)
            for key in "${@:2}"; do
                cat <<-!EVAL
                    local -i ${key};
                    let ${key}=FLAGS_${key};
                    unset FLAGS_${key};
				!EVAL
            done
        ;;
        str|float)
            for key in "${@:2}"; do
                cat <<-!EVAL
                    local -i ${key};
                    ${key}="\${FLAGS_${key}}";
                    unset FLAGS_${key};
				!EVAL
            done
        ;;
        *) core:raise EXCEPTION_BAD_FN_CALL "Invalid type \`${key_type}'" ;;
    esac
}
#. }=-
#. 1.6  Core Utilities -={
function core:len() {
    eval "local -a _$1=( \"\${$1[@]:+\${$1[@]}}\" ); echo \${#_$1[@]}"
}

function :core:age() {
    local -i e; let e=CODE_FAILURE

    local -i elapsed=-1

    local filename="$1"
    if [ -e "${filename}" ]; then
        local -i changed; let changed=$(stat -c %Y "${filename}")
        local -i now; let now=$(date +%s)
        let elapsed=now-changed
        e=${CODE_SUCCESS}
    fi

    echo ${elapsed}

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

    core:raise_bad_fn_call_unless $# in 1 2 3

    local context
    local key
    IFS='.' read -r context key <<< "${1}"

    local -i e; let e=CODE_FAILURE

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
                    globalstore="$(:core:cachefile "${context}" "${key}")"
                    if [ $? -eq ${CODE_SUCCESS?} ]; then
                        cat "${globalstore}"
                        e=$?
                    fi
                ;;
                2)
                    local value="${2}"
                    globalstore="$(:core:cachefile "${context}" "${key}")"
                    printf "%s" "${value}" > "${globalstore}"
                    e=$?
                ;;
                3)
                    local oper="${2}"
                    local -i amendment
                    set +u
                    # shellcheck disable=SC2034
                    let amendment=$3 2>/dev/null
                    e=$?
                    set -u
                    if [ $e -eq ${CODE_SUCCESS?} ]; then
                        globalstore="$(:core:cachefile "${context}" "${key}")"
                        if [ $? -eq ${CODE_SUCCESS?} ]; then
                            local -i current
                            if let current=$(cat "${globalstore}"); then
                                if [ $? -eq ${CODE_SUCCESS?} ]; then
                                    # shellcheck disable=SC1105,SC2086
                                    (( current ${oper} amendment ))
                                    echo ${current} > "${globalstore}"
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
#. 1.8  User/Profile Configuration -={
declare -g -A CORE_MODULES=(
    [tutorial]=1   [help]=1
    [unit]=1       [util]=1      [hgd]=1       [git]=1
                   [net]=1       [tunnel]=1    [remote]=1
    [xplm]=1       [rb]=1        [py]=1        [pl]=1
    [gpg]=1        [vault]=1     [cpf]=1
    [ng]=0         [ldap]=0
)

declare -gA USER_MODULES

declare -g  USER_LOG_LEVEL=INFO

# ssh's `-n' breaks remote:copy (rsync via rsync)
declare -ga g_SSH_OPTS=()
if grep -qw -- -E <( ssh 2>&1 ); then
    #. Log to file if supported
    g_SSH_OPTS+=( '-E' "${SIMBOL_USER_VAR?}/log/ssh.log" )
fi

g_SSH_CONF=${SIMBOL_USER_ETC?}/ssh.conf
[ ! -e "${g_SSH_CONF}" ] || g_SSH_OPTS+=( '-F' "${g_SSH_CONF}" )
#. Defaults and User-Overridables -={
declare -gi USER_CPF_INDENT_SIZE=0; export USER_CPF_INDENT_SIZE
declare -g  USER_CPF_INDENT_STR='UNSET'; export USER_CPF_INDENT_STR
declare -gA USER_HGD_RESOLVERS; export USER_HGD_RESOLVERS
declare -gA USER_MON_CMDGRPREMOTE; export USER_MON_CMDGRPREMOTE
declare -gA USER_MON_CMDGRPLOCAL; export USER_MON_CMDGRPLOCAL

# shellcheck source=share/examples/simbol.conf
source ${SIMBOL_USER_ETC?}/simbol.conf

# shellcheck source=share/examples/dot.simbolrc
test ! -f ~/.simbolrc || source ~/.simbolrc
: "${USER_FULLNAME?}"
: "${USER_USERNAME?}"
: "${USER_EMAIL?}"

#. GLOBAL_OPTS 1/4 -={
declare -i g_HELP; let g_HELP=FALSE
declare -i g_VERBOSE; let g_VERBOSE=FALSE
declare -i g_DEBUG; let g_DEBUG=FALSE
declare -i g_CACHED; let g_CACHED=TRUE
declare -i g_LDAPHOST; let g_LDAPHOST=-1
declare g_FORMAT="ansi"
declare g_DUMP
#. }=-

# shellcheck disable=SC1094 source=module/cpf.sh
source ${SIMBOL_CORE_MOD?}/cpf.sh
function cpf() { cpf:printf "$@"; return $?; }

[ ${USER_CPF_INDENT_SIZE} -ne 0 ] || USER_CPF_INDENT_SIZE=2
[ "${USER_CPF_INDENT_STR}" != 'UNSET' ] || USER_CPF_INDENT_STR="$(cpf "%{@comment: \\___}")"
#. }=-

#. }=-
#. 1.9  Logging -={
declare -A SIMBOL_LOG_NAMES=(
    [EMERG]=0 [ALERT]=1 [CRIT]=2 [ERR]=3
    [WARNING]=4 [NOTICE]=5 [INFO]=6 [DEBUG]=7
)
function core:log() {
    local code=${1}
    local -i level
    case ${code} in
        EMERG|ALERT|CRIT|ERR|WARNING|NOTICE|INFO|DEBUG)
            let level=SIMBOL_LOG_NAMES[code]
        ;;
        *)
            core:raise EXCEPTION_BAD_FN_CALL "Unknown code \`${code}'"
        ;;
    esac

    if [ "${g_MODULE:-NilOrNotSet}" != 'NilOrNotSet' ]; then
        caller="${g_MODULE?}"
        [ ${#g_FUNCTION} -eq 0 ] || caller+=":${g_FUNCTION?}"
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

    #shellcheck disable=SC2086
    if [ ${SIMBOL_LOG_NAMES[${USER_LOG_LEVEL?}]} -ge ${level} ]; then
        local ts; ts="$(date +"${SIMBOL_DATE_FORMAT?}")"

        local msg; msg="$(printf "%s; %5d; %8s[%24s];" "${ts}" "${$--1}" "${code}" "${caller}")"
        [ -e "${SIMBOL_LOG?}" ] || touch "${SIMBOL_LOG?}"
        if [ -f "${SIMBOL_LOG?}" ]; then
            chmod 600 "${SIMBOL_LOG?}"
            echo "${msg} ${*:2}" >> "${SIMBOL_LOG?}"
        fi
        #printf "%s; %5d; %8s[%24s]; $@\n" "${ts}" "$$" "${code}" "$(sed -e 's/ /<-/g' <<< ${FUNCNAME[@]})" >> ${WMII_LOG}
    fi
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
    core:raise_bad_fn_call_unless $# in 1

    local -i e=9

    local module="$1"
    local modulepath="${1//.//}.sh"
    local ouch="${SIMBOL_USER_VAR_TMP}/softimport.${module}.ouch"
    if [ "${g_SIMBOL_IMPORTED_EXIT[${module}]:-NilOrNotSet}" == 'NilOrNotSet' ]; then
        if [ ${USER_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f "${SIMBOL_USER_MOD}/${modulepath}" ]; then
                #shellcheck disable=SC1090
                if ( set -x; source "${SIMBOL_USER_MOD}/${modulepath}"; exit $? ) >& "${ouch}"; then
                    source "${SIMBOL_USER_MOD}/${modulepath}"
                    rm -f "${ouch}"
                    let e=CODE_IMPORT_GOOOD
                else
                    let e=CODE_IMPORT_ERROR
                fi
            else
                e=${CODE_IMPORT_UNDEF?}
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f "${SIMBOL_CORE_MOD}/${modulepath}" ]; then
                #shellcheck disable=SC1090
                if ( set -x; source "${SIMBOL_CORE_MOD}/${modulepath}"; exit $? ) >& "${ouch}"; then
                    source "${SIMBOL_CORE_MOD}/${modulepath}"
                    rm -f "${ouch}"
                    e=${CODE_IMPORT_GOOOD?}
                else
                    e=${CODE_IMPORT_ERROR?}
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
    core:raise_bad_fn_call_unless $# gt 0
    local -i e; let e=CODE_SUCCESS

    local module
    for module in "$@"; do
        if ! core:softimport "${module}"; then
            core:raise_on_failed_softimport "${module}"
        fi
    done

    return $e
}

function core:imported() {
    core:raise_bad_fn_call_unless $# eq 1
    local -i e; let e=CODE_FAILURE

    local module=$1
    if [ ! -z "${g_SIMBOL_IMPORTED_EXIT[${module}]}" ]; then
        e=${g_SIMBOL_IMPORTED_EXIT[${module}]}
    else
        core:raise EXCEPTION_SHOULD_NOT_GET_HERE
    fi

    return $e
}

function core:module_path() {
    core:raise_bad_fn_call_unless $# eq 1
    local -i e; let e=CODE_SUCCESS

    local path
    local module="$1"

    if [ -e "${SIMBOL_CORE_MOD?}/${module//\./\/}.sh" ]; then
        path="${SIMBOL_SCM?}/module"
    elif [ -e "${SIMBOL_USER_MOD?}/${module//\./\/}.sh" ]; then
        path="${SIMBOL_USER_MOD?}"
    else
        core:raise EXCEPTION_SHOULD_NOT_GET_HERE\
            "No such module found: \`${module}'"
    fi

    echo "${path}"
    return $e
}

function core:module_enabled() {
    core:raise_bad_fn_call_unless $# eq 1
    local -i enabled; let enabled=FALSE

    local module="$1"

    if [ -e "${SIMBOL_CORE_MOD?}/${module//\./\/}.sh" ]; then
        [ ${CORE_MODULES[${module}]} -eq 0 ] || let enabled=TRUE
    elif [ -e "${SIMBOL_USER_MOD?}/${module//\./\/}.sh" ]; then
        [ ${USER_MODULES[${module}]} -eq 0 ] || let enabled=TRUE
    else
        core:raise EXCEPTION_SHOULD_NOT_GET_HERE\
            "No such module found: \`${module}'"
    fi

    return ${enabled}
}

function core:modules() {
    local -i e; let e=CODE_FAILURE

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
            let enabled=2
        elif [ ${CORE_MODULES[${module}]-9} -eq 1 ]; then
            let enabled=1
        fi

        if [ ${enabled} -eq 2 -a -f "${SIMBOL_USER_MOD}/${module//\./\/}.sh" ]; then
            echo "${module}"
            let e=CODE_SUCCESS
        elif [ ${enabled} -eq 1 -a -f "${SIMBOL_CORE_MOD}/${module//\./\/}.sh" ]; then
            echo "${module}"
            let e=CODE_SUCCESS
        fi

        if [ "${module//./}" == "${module}" ]; then
            #. It's a module with submodules
            if [ ${enabled} -eq 2 -a -d "${SIMBOL_USER_MOD}/${module}" ]; then
                for submodule in $(find "${SIMBOL_USER_MOD}/${module}" -type f -name '*.sh' -printf "%f\n" | cut -d. -f1); do
                    submodule="${module}.${submodule}"
                    if [ ${USER_MODULES[${submodule}]-9} -eq 1 ]; then
                        echo "${submodule}"
                    elif [ ${CORE_MODULES[${submodule}]-9} -eq 1 ]; then
                        echo "${submodule}"
                    fi
                done
                let e=CODE_SUCCESS
            elif [ ${enabled} -eq 1 -a -d "${SIMBOL_CORE_MOD}/${module}" ]; then
                for submodule in $(find "${SIMBOL_CORE_MOD}/${module}" -type f -name '*.sh' -printf "%f\n" | cut -d. -f1); do
                    submodule="${module}.${submodule}"
                    if [ ${USER_MODULES[${submodule}]-9} -eq 1 ]; then
                        echo "${submodule}"
                    elif [ ${CORE_MODULES[${submodule}]-9} -eq 1 ]; then
                        echo "${submodule}"
                    fi
                done
                let e=CODE_SUCCESS
            fi
        fi
    done

    [ $# -eq 1 ] || e=0
    return $e
}

function core:docstring() {
    local -i e; let e=CODE_FAILURE

    if [ $# -eq 1 ]; then
        local module=$1
        local modulepath=${1//./\/}.sh

        e=2 #. No such module
        if [ ${USER_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f "${SIMBOL_USER_MOD}/${modulepath}" ]; then
                sed -ne "/^:<<\\[${FUNCNAME[0]}\\]/,/\\[${FUNCNAME[0]}\\]/{n;p;q}"\
                    "${SIMBOL_USER_MOD}/${modulepath}"
                let e=$?
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f "${SIMBOL_CORE_MOD}/${modulepath}" ]; then
                sed -ne "/^:<<\\[${FUNCNAME[0]}\\]/,/\\[${FUNCNAME[0]}\\]/{n;p;q}"\
                    "${SIMBOL_CORE_MOD}/${modulepath}"
                let e=$?
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 0 -o ${USER_MODULES[${module}]-9} -eq 0 ]; then
            let e=CODE_FAILURE #. Disabled
        fi
    fi

    return $e
}

function :core:requires() {
    local -i e; let e=CODE_FAILURE

    if [ $# -eq 1 ]; then
        e=${CODE_SUCCESS}

        if grep -q '/' <<< "$1"; then
            [ -e "${1}" ] || e=2
        elif ! which "${1}" >& /dev/null; then
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
    local -i e; let e=CODE_SUCCESS

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
    case $#:$1 in
        1:*)
            required="$1"
            if ! :core:requires "${required}"; then
                core:log NOTICE "${caller} missing required executable ${required}"
                let e=CODE_FAILURE
            fi
        ;;
        *:ALL)
            let e=CODE_SUCCESS
            for required in "${@:2}"; do
                if ! :core:requires "${required}"; then
                    let e=CODE_FAILURE
                    core:log NOTICE "${caller} missing required executable ${required}"
                    break
                fi
            done
        ;;
        *:ANY)
            let e=CODE_FAILURE
            for required in "${@:2}"; do
                if :core:requires "${required}"; then
                    let e=CODE_SUCCESS
                    break
                fi
            done
            if [ $e -ne ${CODE_SUCCESS} ]; then
                core:log NOTICE "${caller} missing ANY of required executable ${*:2}"
            fi
        ;;
        *:PERL)
            local plid=pl
            core:softimport xplm
            if [ $? -eq ${CODE_IMPORT_GOOOD?} ]; then
                #cpf:printf "Installing missing required %{@lang:perl} module %{@pkg:${required}}..."
                for required in "${@:2}"; do
                    if ! :xplm:requires ${plid} ${required}; then
                        core:log NOTICE "${caller} missing required perl module ${required}"
                        if ! :xplm:install ${plid} ${required}; then
                            core:log ERR "${caller} installation of perl module ${required} FAILED"
                            let e=CODE_FAILURE
                        fi
                    fi
                done
            else
                let e=CODE_FAILURE
            fi
        ;;
        *:PYTHON)
            local plid=py
            core:softimport xplm
            if [ $? -eq ${CODE_IMPORT_GOOOD?} ]; then
                #cpf:printf "Installing missing required %{@lang:python} module %{@pkg:${required}}..."
                for required in "${@:2}"; do
                    if ! :xplm:requires ${plid} ${required}; then
                        core:log NOTICE "${caller} installing required python module ${required}"
                        if ! :xplm:install ${plid} ${required}; then
                            core:log ERR "${caller} installation of python module ${required} FAILED"
                            let e=CODE_FAILURE
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
                for required in "${@:2}"; do
                    if ! :xplm:requires ${plid} ${required}; then
                        core:log NOTICE "${caller} installing required ruby module ${required}"
                        if ! :xplm:install ${plid} ${required}; then
                            core:log ERR "${caller} installation of ruby module ${required} FAILED"
                            let e=CODE_FAILURE
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
                for required in "${@:2}"; do
                    if ! :vault:read "${SIMBOL_USER_ETC}/simbol.vault" "${required}"; then
                        core:log NOTICE "${caller} missing required secret ${required}"
                        let e=CODE_FAILURE
                    fi
                done
            fi
        ;;
        *:ENV)
            for required in "${@:2}"; do
                if [ "${!required:-NilOrNotSet}" == 'NilOrNotSet' ]; then
                    core:log NOTICE "${caller} missing required environment variable ${required}"
                    e=${CODE_FAILURE}
                    break
                fi
            done
        ;;
        *) core:raise EXCEPTION_BAD_FN_CALL "Invalid token \`$#:$1'";;
    esac

    (( e == CODE_SUCCESS )) && return $e || exit $e
}
#. }=-
#. 1.12 Caching -={
#. 0 means cache forever (default)
#. >0 indeicates TTL in seconds
declare -g g_CACHE_TTL=0

mkdir -p "${SIMBOL_USER_VAR_CACHE?}"
chmod 3770 "${SIMBOL_USER_VAR_CACHE?}" 2>/dev/null

#. Keep track if cache was used globally
declare g_CACHE_USED="${SIMBOL_USER_VAR_CACHE?}/.cache_used"
rm -f "${g_CACHE_USED?}"

#shellcheck disable=SC2086
function core:return() { return $1; }

function g_CACHE_OUT() {
    : "${l_CACHE_SIG:="${FUNCNAME[1]}"}"
    local key="$*"
    g_CACHE_FILE="$(:core:cachefile "${l_CACHE_SIG}" "${key}")"
    :core:cached "${g_CACHE_FILE}"
    return $?
}

function g_CACHE_IN() {
    local -i e=$?

    cat "${g_CACHE_FILE?}"

    if [ $e -ne ${CODE_SUCCESS?} ]; then
        rm -f "${g_CACHE_FILE?}"
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
same result almost all the time, for example a dns query *might* be a good
candidate, whereas date is a bad candidate.
!

function :core:cachefile() {
    core:raise_bad_fn_call_unless $# in 1 2

    #. Constructs and prints a cachefile path
    local effective_format="${g_FORMAT?}"

    local cachefile="${SIMBOL_USER_VAR_CACHE?}"

    if [ $# -eq 2 ]; then
        #. Automaticly named cachefile...
        local modfn="$1"
        local effective_format=${g_FORMAT?}
        if [ ${g_FORMAT?} == "ansi" ] && [[ ${modfn} =~ ^: ]] ; then
            effective_format='text'
        fi

        cachefile+=/${1//:/=}
        cachefile+=+d${g_DEBUG?}
        cachefile+=+v${g_VERBOSE?}
        cachefile+=+$(md5sum <<< "$2"|cut -b -32);

        #DEBUG: echo "XXX $# // $1 // $2 -> $cachefile XXX" >&2
    elif [ $# -eq 1 ]; then
        #. Hand-picked signature from caller...

        cachefile+=/
        cachefile+=+${g_VERBOSE?}
        cachefile+=+${1}
        effective_format='sig'
    fi

    cachefile+=".${effective_format}"
    echo "${cachefile}"

    #. Return code is 0 if the files exists, and 1 otherwise
    local -i e; let e=CODE_FAILURE
    [ ! -r "${cachefile}" ] || let e=CODE_SUCCESS

    return $e
}

function :core:cache() {
    core:raise_bad_fn_call_unless $# eq 1
    local -i e; let e=CODE_FAILURE

    local cachefile="$1"

    :> "${cachefile}"
    chmod 600 "${cachefile}"
    tee -a "${cachefile}"

    let e=CODE_SUCCESS

    return $e
}

function :core:cached() {
    core:raise_bad_fn_call_unless $# eq 1

    : ${g_CACHED?}
    : "${g_CACHE_USED?}"
    local -i e; let e=CODE_FAILURE

    if [ ${g_CACHED} -eq ${TRUE?} ]; then
        #. TTL < 0 means don't cache
        #. TTL of 0 means cache forever
        #. TTL > 0 means to cache for TTL seconds

        local cachefile="$1"
        local -i ttl; let ttl=${l_CACHE_TTL:-${g_CACHE_TTL?}}
        if [ ${ttl} -ge 0 ]; then
            #. Don't use `let' here: `age' can return 0, and using `let' would
            #. render $? to be non-zero; SC2086 below is therefore required.
            local -i age; age=$(:core:age "${cachefile}")
            if [ $? -eq ${CODE_SUCCESS?} ]; then
                #shellcheck disable=SC2086
                if [ ${ttl} -gt 0 ] && [ ${age} -ge ${ttl} ] || [ ${age} -eq -1 ]; then
                    #. Cache Miss (Expiry)
                    rm -f "${cachefile}"
                    let e=CODE_FAILURE
                    core:log DEBUG "Cache Miss: {ttl:${ttl}, age:${age}}"
                else
                    #. Cache Hit
                    echo "${cachefile}" >> "${g_CACHE_USED?}"
                    #cat ${cachefile}
                    core:log DEBUG "Cache Hit: {ttl:${ttl}, age:${age}}"
                    e=${CODE_SUCCESS?}
                fi
            else
                #. Cache Miss (No Cache)
                e=${CODE_FAILURE?}
            fi
        fi
    fi

    return $e
}
#. }=-
#. 1.13 Execution -={
: ${USER_USERNAME:=$(whoami)}

function ::core:execute:internal() {
    core:raise_bad_fn_call_unless $# ge 2

    local module="$1"
    local fn="$2"
    ":${module}:${fn}" "${@:3}"
    return $?
}

function ::core:execute:private() {
    core:raise_bad_fn_call_unless $# ge 2

    local module="$1"
    local fn="$2"
    "::${module}:${fn}" "${@:3}"
    return $?
}

function ::core:flags.eval() {
    local -i e; let e=CODE_FAILURE

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
            local _fn; _fn="$(:core:complete ${module} ${fn})"
            if [ "$(type -t "${module}:${_fn}:shflags")" == "function" ]; then
                #. shflags function defined, so let's use it...
                while read -r f_type f_long f_default f_desc f_short; do
                    DEFINE_"${f_type}" "${f_long}" "${f_default}" "${f_desc}" "${f_short}"
                    extra+=( FLAGS_${f_long} )
                done < <( "${module}:${_fn}:shflags" )
            fi
        fi
        cat <<!
declare -g module_22884db148f0ffb0d830ba431102b0b5="${module:-}"
declare -g fn_4d9d6c17eeae2754c9b49171261b93bd="${fn:-}"
!
    fi

    #. Process it all
    if FLAGS "${@}"; then #>& /dev/null
        #. GLOBAL_OPTS 3/4 -={
        eval "$(core:decl_shflags.eval bool help)"; g_HELP=${help?}
        eval "$(core:decl_shflags.eval bool verbose)"; g_VERBOSE=${verbose?}
        eval "$(core:decl_shflags.eval bool debug)"; g_DEBUG=${debug?}
        eval "$(core:decl_shflags.eval bool cached)"; g_CACHED=${cached?}

        if grep -qw -- -E <<< "${g_SSH_OPTS[*]}"; then
            case ${g_DEBUG?}:${g_VERBOSE?} in
                ${FALSE?}:0) g_SSH_OPTS+=(  '-q' );;
                ${FALSE?}:1) g_SSH_OPTS+=(  '-v' );;
                ${TRUE?}:0) g_SSH_OPTS+=(  '-vv' );;
                ${TRUE?}:1) g_SSH_OPTS+=( '-vvv' );;
            esac
        fi

        #. Last amendment to g_SSH_OPTS
        g_SSH_OPTS+=( "${USER_SSH_OPTS[@]:+${USER_SSH_OPTS[@]}}" )

        #. Everything else is straight-forward:
        g_LDAPHOST=${FLAGS_ldaphost?}; unset FLAGS_ldaphost
        g_FORMAT=${FLAGS_format?}; unset FLAGS_format
        #. }=-

        cat <<!
#. GLOBAL_OPTS 4/4 -={
$(declare -p g_HELP g_VERBOSE g_DEBUG g_CACHED g_LDAPHOST g_FORMAT g_SSH_OPTS)
#. }=-
set -- ${FLAGS_ARGV?}
!
        let e=CODE_SUCCESS
    else
        cat <<!
g_DUMP="$(FLAGS "$@" 2>&1|sed -e '1,2 d' -e 's/^/    /')"
!
    fi

    local -i len; let len=$(core:len extra)
    if [ $e -eq ${CODE_SUCCESS} -a ${len} -gt 0 ]; then
        cat <<!
$(for key in "${extra[@]}"; do echo "${key}=\"${!key}\""; done)
!
    fi

    return $e
}

function :core:execute() {
    core:raise_bad_fn_call_unless $# ge 2
    local -i e; let e=CODE_USAGE_MODS

    declare -g g_MODULE=$1
    declare -g g_FUNCTION=$2

    if [ "$(type -t "${g_MODULE}:${g_FUNCTION}")" == "function" ]; then
        local -i sic
        case ${g_FORMAT} in
            html|email|ansi)
                [ -t 1 ]
                #shellcheck disable=SC2181
                let sic=$((~$?+2))
            ;;
            dot|text|png)
                let sic=0
            ;;
            *) core:raise EXCEPTION_SHOULD_NOT_GET_HERE "Format checks should have already taken place!";;
        esac

        cpf:initialize ${sic}
        "${g_MODULE}:${g_FUNCTION}" "${@:3}"
        let e=$?

        if [ ${sic} -eq 1 ]; then
            if [ "$(type -t "${g_MODULE}:${g_FUNCTION}:alert")" == "function" ]; then
                cpf:printf "%{r:ALERTS}%{@profile:%s} %{@g_MODULE:%s} %{@function:%s}:\n"\
                    "${SIMBOL_PROFILE?}" "${g_MODULE}" "${g_FUNCTION}"
                while read -ra line; do
                    local alert="${line[0]}"
                    theme "${alert}" "${line:1}"
                done < <( "${g_MODULE}:${g_FUNCTION}:alert" )
                cpf:printf
            fi

            #shellcheck disable=SC2086
            if [ -f "${g_CACHE_USED?}" -a ${g_VERBOSE?} -eq ${TRUE?} ]; then
                cpf:printf
                local age
                local cachefile
                cpf:printf "%{@comment:#. Cached Data} %{r:%s}\n" "-=["
                while read -r cachefile; do
                    let age=$(:core:age "${cachefile}")

                    case $(::core:cache:cachetype "${cachefile}") in
                        output)
                            cpf:printf "    %{b:%s} is %{@int:%ss} old..." "$(basename "${cachefile}")" "${age}"
                        ;;
                        file)
                            cpf:printf "    %{@path:%s} is %{@int:%ss} old..." "${cachefile}" "${age}"
                        ;;
                    esac
                    theme WARN "CACHED"
                done < "${g_CACHE_USED}"
                cpf:printf "%{@comment:#.} %{r:%s}\n" "]=-"
            fi
        fi

        if [ ${sic} -eq 1 -a $e -eq 0 -a ${SECONDS} -ge 30 ]; then
            theme INFO "Execution time was ${SECONDS} seconds"
        fi
    else
        theme ERR_INTERNAL "Function ${g_MODULE}:${g_FUNCTION} not defined!"
    fi

    return $e
}

function core:cd() {
    cd "${1:-}" || core:raise EXCEPTION_PERMANENT_ERROR "No such directory \`$1'"
}

function :core:git() {
    core:cd "${SIMBOL_SCM?}"
    git "$@"
    return $?
}

function ::core:dereference.eval() {
    core:raise_bad_fn_call_unless $# eq 1

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

#shellcheck disable=SC2086
function :core:functions() {
    core:raise_bad_fn_call_unless $# eq 2

    local -i e; let e=CODE_FAILURE
    local fn_type=$1
    local module=$2
    case ${fn_type} in
        public)
            declare -F |
                awk -F'[ ]' '$3~/^'${module}':/{print$3}' |
                awk -F ':+' '{print$2}' |
                sort -u
            let e=CODE_SUCCESS
        ;;
        private)
            declare -F |
                awk -F'[ ]' '$3~/^:'${module}':/{print$3}' |
                awk -F ':+' '{print$3}' |
                sort -u
            let e=CODE_SUCCESS
        ;;
        internal)
            declare -F |
                awk -F'[ ]' '$3~/^::'${module}':/{print$3}' |
                awk -F ':+' '{print$3}' |
                sort -u
            let e=CODE_SUCCESS
        ;;
        *)
            core:raise EXCEPTION_BAD_FN_CALL "Unknown function type \`${fn_type}'"
        ;;
    esac

    return $e
}
function :core:usage() {
#. FIXME: The caching here is unaware of -O|--options that are eaten up by
#. FIXME: shflags before this function is called, and so caching becomes
#. FIXME: destructive.  Additionally, it breaks the --long help which never
#. FIXME: displays anymore once this is enabled.
# g_CACHE_OUT "$*" || {
    local mode=${3---short}
    [ $# -eq 2 ] && mode=${3---long}

    if [ ${#FUNCNAME[@]} -lt 4 ]; then
        cpf:printf "%{+bo}%{n:simbol}%{-bo} %{@version:%s}, %{w:bash framework}\n" ${SIMBOL_VERSION?}
        cpf:printf "Using %{@path:%s} %{@version:%s}" "${BASH}" "${BASH_VERSION}"
        if [ "${SIMBOL_SHELL:-NilOrNotSet}" == "NilOrNotSet" ]; then
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
            eval "$(::core:dereference.eval profile)" #. Will create ${profile} array
            for module in "${!profile[@]}"; do (
                local docstring; docstring="$(core:docstring ${module})"
                core:softimport ${module}
                local -i ie=$?
                local -a fn_public
                local -a fn_private
                if [ $ie -eq ${CODE_IMPORT_ADMIN?} ]; then
                    #shellcheck disable=SC2106
                    continue
                elif [ $ie -eq ${CODE_IMPORT_GOOOD?} ]; then
                    fn_public=( $(:core:functions public ${module}) )
                    #shellcheck disable=SC2034
                    fn_private=( $(:core:functions private ${module}) )
                    if [ ${#fn_public[@]} -gt 0 ]; then
                        cpf:printf "    "
                    else
                        cpf:printf "%{y:!   }"
                    fi
                else
                    cpf:printf "%{r:!!! }"
                fi

                cpf:printf "%{n:%s} %{@module:%s} %{+bo}%{@int:%s}%{-bo}/%{@int:%s}"\
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
        local module="$1"
        core:softimport "${module}"
        local -i ie=$?
        if [ $ie -eq ${CODE_IMPORT_GOOOD?} ]; then
            if [ "${g_ONCE_WHOAMI:-NilOrNotSet}" == "NilOrNotSet" ]; then
                cpf:printf "${usage_prefix} %{@module:${module}}\n"
                declare -g g_ONCE_WHOAMI="IKnowWhoIAm"
            fi
            for module in $(core:modules "${module}"); do
                core:softimport "${module}"
                if [ $? -eq ${CODE_SUCCESS?} ]; then
                    local -a fns=( $(:core:functions public "${module}") )
                    local fn
                    for fn in "${fns[@]}"; do
                        local usage_fn="${module}:${fn}:usage"
                        local usagestr
                        if [ "$(type -t "${usage_fn}")" == "function" ]; then
                            while read -r usagestr; do
                                cpf:printf "    %{n:%s} %{@module:%s} %{@function:%s} %{c:%s}\n"\
                                    "${SIMBOL_BASENAME?}" "${module}" "${fn}" "${usagestr}"
                            done < <( ${usage_fn} )
                        else
                            usagestr="(no-args)"
                            cpf:printf "    %{n:%s} %{@module:%s} %{@function:%s} %{n:%s}\n"\
                                "${SIMBOL_BASENAME?}" "${module}" "${fn}" "${usagestr}"
                        fi
                    done
                fi
            done

            #shellcheck disable=SC2086
            if [ ${g_VERBOSE?} -eq ${TRUE?} -a ${#FUNCNAME[@]} -lt 4 ]; then
                cpf:printf "\n%{@module:${module}} %{g:changelog}\n"
                local modfile="${SIMBOL_USER_MOD?}/${module}"
                [ -f "${modfile}" ] || modfile="${SIMBOL_CORE_MOD?}/${module}"
                core:cd "${SIMBOL_CORE?}"
                :core:git --no-pager\
                    log --follow --all --format=format:"    |___%C(bold blue)%h%C(reset) %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold white)— %an%C(reset)%C(bold yellow)%d%C(reset)"\
                    --abbrev-commit --date=relative -- "${modfile}"
                core:cd "${OLDPWD?}"
                echo
            fi
            echo
        fi
    elif [ $# -ge 2 ]; then
        local module="$1"
        local fn="$2"
        cpf:printf "${usage_prefix} %{@module:%s} %{@function:%s}\n"\
            "${module}" "${fn}"

        local usage_fn="${module}:${fn}:usage"
        if [ "$(type -t "${usage_fn}")" == "function" ]; then
            local usagestr
            while read -r usagestr; do
                cpf:printf "    %{n:%s} %{@module:%s} %{@function:%s} %{c:%s}\n"\
                    "${SIMBOL_BASENAME?}" "${module}" "${fn}" "${usagestr}"
            done < <(${usage_fn})
        else
            cpf:printf "    %{n:%s} %{@module:%s} %{@function:%s} %{n:%s}\n"\
                "${SIMBOL_BASENAME?}" "${module}" "${fn}" "{no-args}"
        fi

        case ${mode} in
            --short) : pass ;;
            --long)
                local usage_l="${module}:${fn}:help"
                local -i i=0
                if [ "$(type -t "${usage_l}")" == "function" ]; then
                    cpf:printf
                    local indent=""
                    local line
                    while read -r line; do
                        cpf:printf "%{c:%s}\n" "${indent}${line}"
                        [ $i -eq 0 ] && indent+="    "
                        ((i++))
                    done <<< "$(${usage_l})"
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
    local fn="$2"
    if [ "${fn}" != '-' ]; then
        if declare -F "${modulestr}:${fn}" >/dev/null; then
            echo "${fn}"
        else
            for afn in $(declare -F|awk -F'[ :]' '$3~/^'"${modulestr}"'$/{print$4}'|sort -n); do
                eval "local ${prefix}${afn//./_}=1"
            done
            set +u
            local -a completed=( $(eval echo "\${!${prefix}${fn//./_}*}") )
            if echo "${completed[*]}" | grep -qE "\<${prefix}${fn//./_}\>"; then
                echo "${fn}"
            else
                echo "${completed[*]//${prefix}/}"
            fi
            set -u
        fi
    fi
}

function core:wrapper() {
    if [ -e "${SIMBOL_DEADMAN?}" ]; then
        theme HAS_FAILED "CRITICAL ERROR; ABORTING!" >&2
        exit 1
    fi

    local -i e; let e=CODE_USAGE_MODS

    local setdata
    setdata="$(::core:flags.eval "${@}")"
    local -i e_flags=$?
    core:log DEBUG "core:flags.eval() returned ${e_flags}"

    #. NOTE: This sets module, fn, $@, etc.
    eval "${setdata}" #. -={
    local module="${module_22884db148f0ffb0d830ba431102b0b5?}"
    local fn="${fn_4d9d6c17eeae2754c9b49171261b93bd?}"
    #. }=-
    core:log DEBUG "core:wrapper(module=${module}, fn=${fn}, argv=( $* ))"

    #shellcheck disable=SC2086
    (( g_DEBUG != TRUE )) || cpf:initialize 1

    local regex=':+[a-z0-9]+(:[a-z0-9]+) |*'

    core:softimport "${module}"
    case $?/${module?}/${fn?} in
        ${CODE_IMPORT_UNSET?}/-/-)                                                                                           let e=CODE_USAGE_MODS ;;
        ${CODE_IMPORT_GOOOD?}/*/-)                                                                                           let e=CODE_USAGE_MOD  ;;
        ${CODE_IMPORT_GOOOD?}/*/::*) ::core:execute:private  "${module}" "${fn:2}" "${@}" 2>&1 | grep --color -E "${regex}"; let e=PIPESTATUS[0]   ;;
        ${CODE_IMPORT_GOOOD?}/*/:*)  ::core:execute:internal "${module}" "${fn:1}" "${@}" 2>&1 | grep --color -E "${regex}"; let e=PIPESTATUS[0]   ;;
        ${CODE_IMPORT_GOOOD?}/*/*)
            local -a completed=( $(:core:complete "${module}" "${fn}") )

            local -A supported_formats=( [html]=1 [email]=1 [ansi]=1 [text]=1 [dot]=0 )
            local format
            if format="$(type -t "${module}:${fn}:formats")"; then
                if [ "${format}" == "function" ]; then
                    for format in $( "${module}:${fn}:formats" ); do
                        supported_formats[${format}]=2
                    done
                fi
            fi

            #shellcheck disable=SC2086
            case ${#completed[@]}:${e_flags}:${g_FORMAT?}:${supported_formats[${g_FORMAT}]:-NilOrNotSet} in
                1:${CODE_SUCCESS?}:email:*)
                    :core:execute "${module}" "${fn}" "$@" 2>&1 |
                        grep --color -E "${regex}" |
                        ${SIMBOL_CORE_LIBEXEC}/ansi2html |
                        mail\
                            -a "Content-type: text/html"\
                            -s "Site Report [${module} ${fn} $*]"\
                            ${USER_EMAIL}
                    e=${PIPESTATUS[3]}
                ;;
                1:${CODE_SUCCESS?}:html:*)
                    :core:execute "${module}" "${fn}" "$@" 2>&1 |
                        grep --color -E "${regex}" |
                        ${SIMBOL_CORE_LIBEXEC}/ansi2html
                    e=${PIPESTATUS[2]}
                ;;
                1:${CODE_SUCCESS?}:*:NilOrNotSet)
                    theme ERR_USAGE "That is not a supported format."
                    e=${CODE_FAILURE?}
                ;;
                1:${CODE_SUCCESS?}:*:0)
                    theme ERR_USAGE "This function does not support that format."
                    e=${CODE_FAILURE?}
                ;;
                1:${CODE_SUCCESS?}:*:*)
                    [ ${g_DEBUG} -eq ${FALSE?} ] || set -x
                    :core:execute "${module}" "${fn}" "$@"
                    e=$?
                    [ ${g_DEBUG} -eq ${FALSE?} ] || set +x
                ;;
                1:*:*:*)
                    e=${CODE_USAGE_FN_LONG?}
                ;;
            esac


            if [ ${#completed[@]} -eq 1 ]; then
                if [ $e -eq ${CODE_NOTIMPL?} ]; then
                    theme ERR_USAGE "This function has not yet been implemented."
                fi
            elif [ ${#completed[@]} -gt 1 ]; then
                theme ERR_USAGE "Did you mean one of the following:"
                for acfn in "${completed[@]}"; do
                    echo "    ${SIMBOL_BASENAME?} ${module} ${acfn}"
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
        ${CODE_USAGE_SHORT?})   :core:usage "${module}" ;;
        ${CODE_USAGE_MOD?})     :core:usage "${module}" ;;
        ${CODE_USAGE_FN_LONG?}) :core:usage "${module}" "${fn}" ;;
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
# TODO: Move the comments below into the RAISE array -={
#shellcheck disable=SC2034
EXCEPTION_NOT_IMPLEMENTED=124        #. Sorry, not implemented (developer sloth)
#shellcheck disable=SC2034
EXCEPTION_PERMANENT_ERROR=125        #. Can get here, but can't be handled (user error)
#shellcheck disable=SC2034
EXCEPTION_SHOULD_NOT_GET_HERE=126    #. Should not ever get here (developer error)
#shellcheck disable=SC2034
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

function core:compare() {
    local -i n1; let n1=$1
    local op="$2"
    local -i n2; let n2=$3
    eval "[ ${n1} -${op} ${n2} ]"
    return $?
}

function core:in() {
    local argv="$1"
    local -a expected=( ${*:2} )
    local exp
    for exp in ${expected[@]}; do
        #shellcheck disable=SC2086
        if [ "${exp}" == "${argv}" ]; then
            return ${CODE_SUCCESS?}
        fi
    done

    return ${CODE_FAILURE?}
}

function core:raise_bad_fn_call_unless() {
    local argv="$1"
    local op="$2"
    case "${op}:$#" in
        'in':*)
            local -a expected=( ${@:3} )
            #shellcheck disable=SC2086
            if ! core:in ${argv} ${expected[*]}; then
                core:raise EXCEPTION_BAD_FN_CALL\
                    "Expected one of ( ${expected[*]} ) arguments, received \`${argv}'"
            fi
        ;;
        eq:3|lt:3|gt:3|ge:3|le:3)
            local -i expected; let expected=$3
            #shellcheck disable=SC2086
            if ! core:compare ${argv} ${op} ${expected}; then
                local -i limit; let limit=expected
                core:raise EXCEPTION_BAD_FN_CALL\
                    "Expected \$# -${op} ${limit}, received \`${argv}'"
            fi
        ;;
    esac
}

function core:raise_on_failed_softimport() {
    core:raise_bad_fn_call_unless $# eq 1

    local module="$1"
    local ouch="${SIMBOL_USER_VAR_TMP}/softimport.${module}.ouch"
    if [ -e "${ouch}" ]; then
        cat "${ouch}"

        core:raise EXCEPTION_PERMANENT_ERROR "Module softimport failure for \`${module}'"
    fi
}

function core:raise() {
    : !!! CRITICAL FAILURE !!!
    :>"${SIMBOL_DEADMAN?}"

    local -i e; let e=$1

    if [[ $- =~ x ]]; then
        : !!! Exiting raise function early as we are being traced !!!
    else
        cpf:printf "%{+r}EXCEPTION%{bo:[%s->%s]}: %s%{-r}\n" "$e" "$1" "${RAISE[$e]-[UNKNOWN EXCEPTION:$e]}" >&2
        [ $# -lt 2 ] || cpf:printf "\n%{+r}  !!! %{bo:%s}%{-r}\n\n" "${@:2}" >&2

        cpf:printf "%{+r}EXCEPTION%{bo:[Traceback]}%{-r}:\n" >&2
        if [ "${g_MODULE:-NilOrNotSet}" != 'NilOrNotSet' ]; then
            if [ "${g_FUNCTION:-NilOrNotSet}" != 'NilOrNotSet' ]; then
                cpf:printf "Function %{c:${g_MODULE}:${g_FUNCTION}()}\n" 1>&2
                echo "Critical failure in function ${g_MODULE}:${g_FUNCTION}()" >> "${SIMBOL_DEADMAN?}"
            else
                cpf:printf "g_MODULE %{c:${g_MODULE}}\n" 1>&2
                echo "Critical failure in g_MODULE ${g_MODULE}" >> "${SIMBOL_DEADMAN?}"
            fi
        else
            echo "Critical failure in file ${0}" >> "${SIMBOL_DEADMAN?}"
        fi

        -=-
        -=[
            local fn mf code
            local -i i ln frames
            let frames=${#BASH_LINENO[@]}
            #. ((frames-2)): skips main, the last element in the arrays
            for ((i=frames-2; i>=0; i--)); do
                fn="${FUNCNAME[i+1]}()"
                mf="${BASH_SOURCE[i+1]}"
                let ln=${BASH_LINENO[i]}
                cpfi "%{@function:%s}@%{@path:%s}:%{@int:%s}\n"\
                    "${fn}" "${mf}" ${ln} 1>&2
                -=[
                    code="$(sed -n "${ln}{s/^ *//;s/%/%%/g;p}" "${mf}")"
                    cpfi "[ %{@code:%s} ]\n" "${code}" 1>&2
                ]=-
            done
        ]=-
    fi

    exit $e
}
#. }=-
#. 1.15 Mocking -={
function mock:path() {
    core:raise_bad_fn_call_unless $# in 0 1
    local context="${1:-default}"
    echo "${SIMBOL_USER_MOCKENV?}.${context}"
    return $?
}

function mock:write() {
    core:raise_bad_fn_call_unless $# in 0 1
    local context="${1:-default}"
    cat >>"$(mock:path "${context}")"
    return $?
}

function mock:save() {
    core:raise_bad_fn_call_unless $# in 0 1 2

    local -i e; let e=CODE_FAILURE
    local context="${1:-default}"
    local savefile="/tmp/mock-${context}-${2:-$$}.sh"
    if cp "${SIMBOL_USER_MOCKENV?}.${context}" "${savefile}"; then
        let e=CODE_SUCCESS
        echo "${savefile}"
    fi

    return $e
}

function mock:clear() {
    core:raise_bad_fn_call_unless $# in 0 1

    local -i e

    if [ $# -eq 0 ]; then
        set +f; rm -f "${SIMBOL_USER_MOCKENV?}".*; set -f
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
    core:raise_bad_fn_call_unless $# in 0 1

    local context="${1:-default}"
    touch "${SIMBOL_USER_MOCKENV?}.${context}"
    ln -sf "${SIMBOL_USER_MOCKENV?}.${context}" "${SIMBOL_USER_MOCKENV?}"
    return $?
}

function mock:wrapper() {
    function closure() {
        if [ ! -r "${SIMBOL_USER_MOCKENV?}" ]; then
            mock:context default
        fi
        if [ -r "${SIMBOL_USER_MOCKENV?}" ]; then
            #shellcheck disable=SC1090
            source "${SIMBOL_USER_MOCKENV?}"
        fi

        core:wrapper "$@"
        local -i _e=$?

        unset closure
        return $_e
    }

    closure "$@"
    return $?
}
#. }=-
#. }=-
