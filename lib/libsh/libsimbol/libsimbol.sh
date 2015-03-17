# vim: tw=0:ts=4:sw=4:et:ft=bash

#. Site Engine -={
export SIMBOL_VERSION=v0.30.1
#. 1.1  Date/Time and Basics -={
export NOW=$(date --utc +%s)
#. FIXME: Mac OS X needs this instead:
#. FIXME: export NOW=$(date -u +%s)
#. }=-
#. 1.2  Paths -={
: ${SIMBOL_PROFILE?}
export SIMBOL_SIMBOL_BASENAME=$(basename $0)

export SIMBOL_SCM=$(readlink ~/.simbol/.scm)

export SIMBOL_CORE=$(readlink ~/.simbol/.scm)
export SIMBOL_CORE_MOD=${SIMBOL_CORE}/module
export SIMBOL_CORE_LIBEXEC=${SIMBOL_CORE}/libexec
export SIMBOL_CORE_BIN=${SIMBOL_CORE}/bin
export SIMBOL_CORE_LIB=${SIMBOL_CORE}/lib
export SIMBOL_CORE_LIBPY=${SIMBOL_CORE}/lib/libpy
export SIMBOL_CORE_LIBJS=${SIMBOL_CORE}/lib/libjs
export SIMBOL_CORE_LIBSH=${SIMBOL_CORE}/lib/libsh
export SIMBOL_UNIT=${SIMBOL_CORE}/share/unit
export SIMBOL_UNIT_TESTS=${SIMBOL_CORE}/share/unit/tests
export SIMBOL_UNIT_FILES=${SIMBOL_CORE}/share/unit/tests

export SIMBOL_USER=${HOME}/.simbol
export SIMBOL_USER_VAR=${SIMBOL_USER}/var
export SIMBOL_USER_RUN=${SIMBOL_USER}/var/run
export SIMBOL_USER_SCM=${SIMBOL_USER}/var/scm
export SIMBOL_USER_CACHE=${SIMBOL_USER}/var/cache
export SIMBOL_USER_ETC=${SIMBOL_USER}/etc
export SIMBOL_USER_LOG=${SIMBOL_USER}/var/log/simbol.log
export SIMBOL_USER_TMP=${SIMBOL_USER}/var/tmp
export SIMBOL_USER_MOD=${SIMBOL_USER}/module
export SIMBOL_USER_LIB=${SIMBOL_USER}/var/lib
export SIMBOL_USER_LIBSH=${SIMBOL_USER}/var/lib/libsh
export SIMBOL_USER_LIBPY=${SIMBOL_USER}/var/lib/libpy
export SIMBOL_USER_LIBEXEC=${SIMBOL_USER}/var/libexec

#. Site's PATH
PATH+=:${SIMBOL_CORE_LIBEXEC}
PATH+=:${SIMBOL_USER_LIBEXEC}
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
PYTHONPATH+=:${SIMBOL_USER_LIBPY}
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

#. shunit2 and shflags
export SHUNIT2=${SIMBOL_USER_LIBEXEC}/shunit2
export SHFLAGS=${SIMBOL_USER_LIBSH}/shflags
source ${SHFLAGS?}
#. }=-
#. 1.3  Core Configuration -={
unset  CDPATH
export SIMBOL_DEADMAN=${SIMBOL_USER_CACHE}/deadman
export SIMBOL_IN_COLOR=1
export SIMBOL_DATE_FORMAT="%x-%X"
source ${SIMBOL_CORE_MOD?}/cpf.sh
PS4="+${COLORS[r]}\${BASH_SOURCE}${COLORS[N]}"
PS4+=":${COLORS[g]}\${LINENO}${COLORS[N]}"
PS4+="[${COLORS[m]}\${FUNCNAME}()${COLORS[N]}]"
PS4+="${COLORS[y]} >>> ${COLORS[N]}"
#. }=-
#. 1.4  User/Profile Configuration -={
declare -g -A CORE_MODULES=(
    [tutorial]=0   [help]=1
    [unit]=1       [util]=1      [hgd]=1       [git]=1
    [dns]=1        [net]=1       [tunnel]=1    [remote]=1
    [xplm]=1       [rb]=1        [py]=1        [pl]=1
    [gpg]=1        [vault]=1
    [ng]=0         [ldap]=0      [mongo]=0
    [softlayer]=0
)

declare -gA USER_MODULES=( )
declare -gA USER_IFACE
declare -ga USER_TLDIDS_REQUIRED
declare -g  USER_TLDID_DEFAULT
declare -gA USER_TLDS
declare -gA USER_MON_CMDGRPREMOTE
declare -gA USER_MON_CMDGRPLOCAL
declare -g  USER_LOG_LEVEL=INFO
source ${SIMBOL_USER_ETC}/simbol.conf

test ! -f ~/.simbolrc || source ~/.simbolrc
: ${USER_TLDS[@]?}
: ${USER_FULLNAME?}
: ${USER_USERNAME?}
: ${USER_EMAIL?}

#. GLOBAL_OPTS 1/4 -={
declare -i g_HELP=0
declare -i g_VERBOSE=0
declare -i g_DEBUG=0
declare -i g_CACHED=1
declare -i g_LDAPHOST=-1
declare g_FORMAT=ansi
declare g_TLDID=${USER_TLDID_DEFAULT:-_}
#. }=-

declare g_DUMP
declare -g g_SSH_OPT
g_SSH_OPTS="-q"
g_SSH_CONF=${SIMBOL_USER_ETC?}/${SIMBOL_USER_SSH_CONF:-ssh.conf}
if [ -e "${g_SSH_CONF}" ]; then
    g_SSH_OPTS+=" -F ${g_SSH_CONF}"
fi
#. }=-
#. 1.7  Error Code Constants -={
true
TRUE=$?
CODE_SUCCESS=${TRUE?}

false
FALSE=$?
CODE_FAILURE=${FALSE?}

CODE_NOTIMPL=2

#. 64..127 Internal
CODE_USER_MAX=63
CODE_DISABLED=64
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
#. 1.8  Logging -={
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

    if [ ${#module} -gt 0 ]; then
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

        declare msg=$(printf "%s; %5d; %8s[%24s];" "${ts}" "${$--1}" "${code}" "${caller}")
        [ -e ${SIMBOL_USER_LOG?} ] || touch ${SIMBOL_USER_LOG?}
        if [ -f ${SIMBOL_USER_LOG} ]; then
            chmod 600 ${SIMBOL_USER_LOG?}
            echo "${msg} ${*:2}" >> ${SIMBOL_USER_LOG?}
        fi
        #printf "%s; %5d; %8s[%24s]; $@\n" "${ts}" "$$" "${code}" "$(sed -e 's/ /<-/g' <<< ${FUNCNAME[@]})" >> ${WMII_LOG}
    fi
}
#. }=-
#. 1.9  Modules -={
declare -A g_SIMBOL_IMPORTED_EXIT

function core:softimport() {
    #. 0: good module
    #. 1: invalid/bad module (can't source/parse)
    #. 2: administratively disabled
    #. 3: no such module defined
    #. 4: no module set
    local -i e=9

    if [ $# -eq 1 ]; then
        local module=$1
        local modulepath=${1//./\/}
        if [ -z "${g_SIMBOL_IMPORTED_EXIT[${module}]}" ]; then
            if [ ${USER_MODULES[${module}]-9} -eq 1 ]; then
                if [ -f ${SIMBOL_USER_MOD}/${modulepath}.sh ]; then
                    if source ${SIMBOL_USER_MOD}/${modulepath}.sh >/tmp/simbol.${module}.ouch 2>&1; then
                        e=${CODE_IMPORT_GOOOD?}
                    else
                        e=${CODE_IMPORT_ERROR?}
                    fi
                    rm -f /tmp/simbol.${module}.ouch
                else
                    e=${CODE_IMPORT_UNDEF?}
                fi
            elif [ ${CORE_MODULES[${module}]-9} -eq 1 ]; then
                if [ -f ${SIMBOL_CORE_MOD}/${modulepath}.sh ]; then
                    if source ${SIMBOL_CORE_MOD}/${modulepath}.sh >/tmp/simbol.${module}.ouch 2>&1; then
                        e=${CODE_IMPORT_GOOOD?}
                    else
                        e=${CODE_IMPORT_ERROR?}
                    fi
                    rm -f /tmp/simbol.${module}.ouch
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
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function core:import() {
    core:softimport $@
    local -i e=$?
    #. Don't raise an exception; that will break softimport too, just exit
    [ $e -eq ${CODE_SUCCESS} ] || exit 99 #core:raise EXCEPTION_BAD_MODULE

    return $e
}

function core:imported() {
    local -i e=${CODE_FAILURE}

    if [ $# -eq 1 ]; then
        local module=$1
        e=${g_SIMBOL_IMPORTED_EXIT[${module}]}
        [ ${#e} -gt 0 ] || e=-1
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return ${e}
}

function core:docstring() {
    local -i e=${CODE_FAILURE}

    if [ $# -eq 1 ]; then
        local module=$1
        local modulepath=${1//./\/}

        e=2 #. No such module
        if [ ${USER_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f ${SIMBOL_USER_MOD}/${modulepath}.sh ]; then
                sed -ne '/^:<<\['${FUNCNAME}'\]/,/\['${FUNCNAME}'\]/{n;p;q}' ${SIMBOL_USER_MOD}/${modulepath}.sh
                e=$?
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 1 ]; then
            if [ -f ${SIMBOL_CORE_MOD}/${modulepath}.sh ]; then
                sed -ne '/^:<<\['${FUNCNAME}'\]/,/\['${FUNCNAME}'\]/{n;p;q}' ${SIMBOL_CORE_MOD}/${modulepath}.sh
                e=$?
            fi
        elif [ ${CORE_MODULES[${module}]-9} -eq 0 -o ${USER_MODULES[${module}]-9} -eq 0 ]; then
            e=${CODE_FAILURE} #. Disabled
        fi
        g_SIMBOL_IMPORTED_EXIT[${module}]=$e
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
                #cpf "Installing missing required %{@lang:perl} module %{@pkg:${required}}..."
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
                #cpf "Installing missing required %{@lang:python} module %{@pkg:${required}}..."
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
                #cpf "Installing missing required %{@lang:ruby} module %{@pkg:${required}}..."
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
                if [ -z "${!required}" ]; then
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
#. 1.10 Caching -={
#. 0 means cache forever (default)
#. >0 indeicates TTL in seconds
declare -g g_CACHE_TTL=0

mkdir -p ${SIMBOL_USER_CACHE?}
chmod 3770 ${SIMBOL_USER_CACHE?} 2>/dev/null

#. Keep track if cache was used globally
declare g_CACHE_USED=${SIMBOL_USER_CACHE}/.cache_used
rm -f ${g_CACHE_USED}

CACHE_OUT='eval :core:cached "${*}" && return ${CODE_SUCCESS}'
CACHE_IN='eval :core:cache "${*}"'
CACHE_EXIT='eval return ${PIPESTATUS[0]}'
:<<! USAGE:
Any function (private or internal only, do not try and cache-enable public
functions!) can be cache-enabled simply by insertin two lines; one right at
the start of the function, and one right at the end:

function <module>:<function>() {
  #. vvv 1. Use cache and return or continue
  ${CACHE_OUT}; {

    ...

  } | ${CACHE_IN}; ${CACHE_EXIT}
  #. ^^^ 2. Update cache if previous did not return
}
function :<module>:<function>() { #. Same as above...; }
function ::<module>:<function>() { #. Same as above...; }

Also take note of the indenting of 2 spaces, this makes it non-obstructive, so
you can maintain the usual 4-space indents, and insert these in and out as
you please.

Note that public functions that take local shflags will not allow caching,
and will generate an error.

Finally, the default cache time is g_CACHE_TTL minutes, but this can be
modified for each function by creating the auxiliary function:

function :[:]<module>:<function>:cached() { echo 3600; }

The value echoed will be the replacement TTL.

Don't use this all over the place, only on computationally expensive code
or otherwise slow code (network latency) that is expected to also produce the
same result almost alll the time, for example dns might be a good candidate,
whereas remote code execution is probably a bad candidate.
!

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

function :core:cache:file() {
    local -i e=${CODE_FAILURE}

    local modfn="$1"
    local cachefile
    if [ "$(type -t ${modfn}:cachefile)" == "function" ]; then
        #. File-Cached...
        shift 1
        cachefile=$(${modfn}:cachefile "${@}")
    else
        #. Output-Cached...
        local effective_format=${g_FORMAT}
        if [[ $1 =~ ^: ]] && [ ${g_FORMAT} == "ansi" ]; then
            effective_format=text
        fi

        cachefile=${SIMBOL_USER_CACHE}/${1//:/=}
        cachefile+=+${g_TLDID}
        cachefile+=+${g_VERBOSE}
        cachefile+=+$(echo -ne "${2}"|md5sum|awk '{print$1}')
        cachefile+=.${effective_format}
    fi

    echo "${cachefile}"

    e=${CODE_SUCCESS}
    return $e
}

function :core:cache:age() {
    local -i e=${CODE_FAILURE}

    local cachefile=$(:core:cache:file "${@}")

    :core:age "${cachefile}"
    e=$?

    return $e
}

function ::core:cache:cachetype() {
    local -i e=${CODE_FAILURE}

    if [ $# -eq 1 ]; then
        local cachefile=$1
        local cachetype=file

        if [ "${cachefile:0:1}" == '/' ]; then
            if [ "${cachefile//${SIMBOL_USER_CACHE}/}" != "${cachefile}" ]; then
                cachetype=output
            fi
            e=${CODE_SUCCESS}
        else
            core:raise EXCEPTION_SHOULD_NOT_GET_HERE
        fi
    fi

    echo "${cachetype}"
    return $e
}

function :core:cache() {
    local -i e=${CODE_FAILURE}

    if [ $# -eq 1 ]; then
        local modfn=${FUNCNAME[1]}
        local argv="$1"
        local cachefile=$(:core:cache:file "${modfn}" "${argv}")

        #. If it's a output-cached file..
        case $(::core:cache:cachetype ${cachefile}) in
            output)
                :> ${cachefile}
                chmod 600 ${cachefile}
                while IFS= read line; do
                    echo "${line}" >> ${cachefile}
                done

                if [ -s ${cachefile} ]; then
                    cat ${cachefile}
                else
                    rm -f ${cachefile}
                fi
            ;;
            file)
                : PASS
            ;;
        esac

        local -i e=${CODE_SUCCESS}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function :core:cached() {
    #. TTL of 0 means cache forever
    #. TTL > 0 means to cache for TTL seconds
    local -i e=${CODE_FAILURE}
    if [ $# -eq 1 ]; then
        if [ ${g_CACHED} -eq 1 ]; then
            local modfn=${FUNCNAME[1]}
            if [ "$(type -t ${modfn}:shflags)" != "function" ]; then
                local -i ttl=0
                [ "$(type -t ${modfn}:cached)" == "function" ] &&
                    ttl=$(${modfn}:cached) ||
                        ttl=${g_CACHE_TTL}
                local argv="$1"
                local cachefile=$(:core:cache:file "${modfn}" "${argv}")
                local -i age
                age=$(:core:age ${cachefile})
                if [ $? -eq ${CODE_SUCCESS} ]; then
                    if [ ${ttl} -gt 0 -a ${age} -ge ${ttl} ]; then
                        rm -f ${cachefile}
                    else
                        case $(::core:cache:cachetype ${cachefile}) in
                            output)
                                cat ${cachefile}
                                echo ${cachefile} >> ${g_CACHE_USED}
                                e=${CODE_SUCCESS}
                            ;;
                            file)
                                e=${CODE_SUCCESS}
                            ;;
                        esac
                    fi
                fi
            else
                theme ERR "Caching functions that take local shflags not supported." >&2
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. 1.11 Execution -={
: ${USER_USERNAME:=$(whoami)}

function core:tld() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local tldid="$1"
        local tld

        if [ "${tldid}" == '_' ]; then
            tld="${USER_TLDS[${tldid}]}"
            e=${CODE_SUCCESS?}
        elif echo ${!USER_TLDS[@]} | grep -qE "\<${tldid}\>"; then
            tld="${USER_TLDS[${tldid}]}"
            e=${CODE_SUCCESS?}
        fi

        [ $e -ne ${CODE_SUCCESS?} ] || echo "${tld}"
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

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
                argv[${argc}]="${arg?}"
                ((argc++))
            fi
        else
            argv[${argc}]="${arg}"
            ((argc++))
        fi
    done
    set -- "${argv[@]}"

    #. GLOBAL_OPTS 2/4: Our generic and global options -={
    DEFINE_boolean help     false            "<help>"                   H
    DEFINE_boolean verbose  false            "<verbose>"                V
    DEFINE_boolean debug    false            "<debug>"                  D
    DEFINE_boolean cached   true             "<use-cache>"              C
    DEFINE_integer ldaphost "${g_LDAPHOST}"  "<ldap-host-index>"        L
    DEFINE_string  format   "${g_FORMAT}"    "ansi|text|csv|html|email" F
    DEFINE_string  tldid    "${g_TLDID}"     "<top-level-domain-id>"    T
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
declare -g module=${module:-}
declare -g fn=${fn:-}
!
    fi

    #. Process it all
    FLAGS "${@}" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        #. GLOBAL_OPTS 3/4 -={
        FLAGS_HELP="simbol ${module} ${fn} [<flags>]"
        #. Booleans get inverted:
        let g_HELP=~${FLAGS_help?}+2; unset FLAGS_help
        let g_VERBOSE=~${FLAGS_verbose?}+2; unset FLAGS_verbose
        let g_DEBUG=~${FLAGS_debug?}+2; unset FLAGS_debug
        let g_CACHED=~${FLAGS_cached?}+2; unset FLAGS_cached
        #. Everything else is straight-forward:
        g_LDAPHOST=${FLAGS_ldaphost?}; unset FLAGS_ldaphost
        g_FORMAT=${FLAGS_format?}; unset FLAGS_format
        g_TLDID=${FLAGS_tldid?}; unset FLAGS_tldid
        #. }=-

        if [[ ${#USER_IFACE[${g_TLDID}]} -eq 0 ]]; then
            core:log ERR "USER_IFACE[${g_TLDID}] has not been defined!"
        fi

        if [[ ${#g_TLDID} -eq 0 || ${g_TLDID} == '_' || ${#USER_IFACE[${g_TLDID}]} -gt 0 ]]; then
            cat <<!
#. GLOBAL_OPTS 4/4 -={
declare g_HELP=${g_HELP?}
declare g_VERBOSE=${g_VERBOSE?}
declare g_DEBUG=${g_DEBUG?}
declare g_CACHED=${g_CACHED?}
declare g_LDAPHOST=${g_LDAPHOST?}
declare g_FORMAT=${g_FORMAT?}
declare g_TLDID=${g_TLDID?}
#. }=-
set -- ${FLAGS_ARGV?}
!
            e=${CODE_SUCCESS}
        fi
    else
        cat <<!
g_DUMP="$(FLAGS "${@}" 2>&1|sed -e '1,2 d' -e 's/^/    /')"
!
    fi

    if [ $e -eq ${CODE_SUCCESS} ]; then
        cat <<!
$(for key in ${extra[@]}; do echo ${key}=${!key}; done)
!
    fi

    return $e
}

function :core:execute() {
    local -i e=${CODE_USAGE_MODS}

    if [ $# -ge 1 ]; then
        e=${CODE_USAGE_MOD}

        if [ $# -ge 2 ]; then
            #. FIXME: Why do these need to be global?  I did try to change them
            #. FIXME: to locals, however all unit-tests (other than util) broke.
            declare -g module=$1
            declare -g fn=$2

            if [ "$(type -t ${module}:${fn})" == "function" ]; then
                case ${g_FORMAT} in
                    dot|text|png)    SIMBOL_IN_COLOR=0 ${module}:${fn} "${@:3}";;
                    html|email)      SIMBOL_IN_COLOR=1 ${module}:${fn} "${@:3}";;
                    ansi)
                        if [ -t 1 ]; then
                            SIMBOL_IN_COLOR=1 ${module}:${fn} "${@:3}"
                        else
                            SIMBOL_IN_COLOR=0 ${module}:${fn} "${@:3}"
                        fi
                    ;;
                    *) core:raise EXCEPTION_SHOULD_NOT_GET_HERE "Format checks should have already taken place!";;
                esac
                e=$?

                if [ ${SIMBOL_IN_COLOR} -eq 1 ]; then
                    if [ "$(type -t ${module}:${fn}:alert)" == "function" ]; then
                        cpf "%{r:ALERTS}%{bl:@}%{g:${SIMBOL_PROFILE}} %{!function:${module} ${fn}}:\n"
                        while read line; do
                            set ${line}
                            local alert=$1
                            shift
                            theme ${alert} "${*}"
                        done < <(${module}:${fn}:alert)
                        cpf
                    fi

                    if [ -f ${g_CACHE_USED?} -a ${g_VERBOSE?} -eq 1 ]; then
                        cpf
                        local age
                        local cachefile
                        cpf "%{@comment:#. Cached Data} %{r:%s}\n" "-=["
                        while read cachefile; do
                            age=$(:core:age "${cachefile}")

                            case $(::core:cache:cachetype ${cachefile}) in
                                output)
                                    cpf "    %{b:%s} is %{@int:%ss} old..." "$(basename ${cachefile})" "${age}"
                                ;;
                                file)
                                    cpf "    %{@path:%s} is %{@int:%ss} old..." "${cachefile}" "${age}"
                                ;;
                            esac
                            theme WARN "CACHED"
                        done < ${g_CACHE_USED}
                        cpf "%{@comment:#.} %{r:%s}\n" "]=-"
                    fi
                fi
            else
                theme ERR_INTERNAL "Function ${module}:${fn} not defined!"
            fi
        fi
    fi

    if [ ${SIMBOL_IN_COLOR} -eq 1 -a $e -eq 0 -a ${SECONDS} -ge 30 ]; then
        theme INFO "Execution time was ${SECONDS} seconds"
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
function :core:usage:cached() { echo 0; }
function :core:usage() {
  ${CACHE_OUT?}; {
    local module=$1
    local fn=$2
    local mode=${3---short}
    [ $# -eq 2 ] && mode=${3---long}

    if [ ${#FUNCNAME[@]} -lt 4 ]; then
        cpf "%{+bo}%{bl:simbol}%{-bo} %{@version:%s}, %{wh:bash framework}\n" ${SIMBOL_VERSION?}
        cpf "Using %{@path:%s} %{@version:%s}" "${BASH}" "${BASH_VERSION}"
        if [ ${#SIMBOL_SHELL} -eq 0 ]; then
            cpf " %{@comment:(export SIMBOL_SHELL to override)}"
        else
            cpf " %{r:(SIMBOL_SHELL override active)}"
        fi
        printf "\n\n"
    fi

    local usage_prefix="%{wh:Usage} for %{@user:${USER_USERNAME}}@%{g:${SIMBOL_PROFILE}}"
    if [ $# -eq 0 ]; then
        #. Usage for simbol
        cpf "${usage_prefix}\n"
        for profile in USER_MODULES CORE_MODULES; do
            cpf "  %{g:${profile}}...\n"
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
                        cpf "    "
                    else
                        cpf "%{y:!   }"
                    fi
                else
                    cpf "%{r:!!! }"
                fi

                cpf "%{bl:%s} %{!module:%s}:%{+bo}%{@int:%s}%{-bo}/%{@int:%s}"\
                    "${SIMBOL_BASENAME}" "${module}"\
                    "${#fn_public[@]}" "${#fn_private[@]}"

                if [ $ie -eq ${CODE_IMPORT_GOOOD?} ]; then
                    cpf "%{@comment:%s}\n" "${docstring:+; ${docstring}}"
                else
                    cpf "; %{@warn:This module has not been set-up for use}\n"
                fi
            ); done | sort
        done
    elif [ $# -eq 1 ]; then
        core:softimport ${module}
        local -i ie=$?
        if [ $ie -eq ${CODE_IMPORT_GOOOD?} ]; then
            if [ ${g_ONCE_WHOAMI:-0} -eq 0 ]; then
                cpf "${usage_prefix} %{!module:${module}}\n"
                g_ONCE_WHOAMI=1
            fi

            local -a fns=( $(:core:functions public ${module}) )
            for fn in ${fns[@]}; do
                local usage_fn="${module}:${fn}:usage"
                local usagestr="{no-args}"
                if [ "$(type -t ${usage_fn})" == "function" ]; then
                    usagestr="$(${usage_fn})"
                    cpf "    %{bl:${SIMBOL_BASENAME}} %{!function:${module}:${fn}} %{c:%s}\n" "${usagestr}"
                else
                    cpf "    %{bl:${SIMBOL_BASENAME}} %{!function:${module}:${fn}} %{bl:%s}\n" "${usagestr}"
                fi
            done

            if [ ${g_VERBOSE?} -eq 1 -a ${#FUNCNAME[@]} -lt 4 ]; then
                cpf "\n%{!module:${module}} %{g:changelog}\n"
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
        cpf "${usage_prefix} %{!function:${module}:${fn}}\n"
        cpf "    %{bl:${SIMBOL_BASENAME}} %{!function:${module}:${fn}} "

        local usage_s=${module}:${fn}:usage
        if [ "$(type -t $usage_s)" == "function" ]; then
            cpf "%{c:%s}\n" "$(${usage_s})"
        else
            cpf "%{bl:%s}\n" "{no-args}"
        fi

        case ${mode} in
            --short) : pass ;;
            --long)
                local usage_l=${module}:${fn}:help
                local -i i=0
                if [ "$(type -t $usage_l)" == "function" ]; then
                    cpf
                    local indent=""
                    while read line; do
                        cpf "%{c:%s}\n" "${indent}${line}"
                        [ $i -eq 0 ] && indent+="    "
                        ((i++))
                    done <<< "`${usage_l}`"
                fi

                if [ ${#g_DUMP} -gt 0 ]; then
                    cpf
                    cpf "%{c:%s}\n" "Flags:"
                    echo "${g_DUMP}"
                fi
            ;;
        esac
    fi
  } | ${CACHE_IN?}; ${CACHE_EXIT?}
}

function :core:complete() {
    local module=$1
    local fn=$2
    if [ "${fn}" != '-' ]; then
        local hit
        hit=$(declare -F ${module}:${fn})
        if [ $? -eq 0 ]; then
            echo ${fn}
        else
            for afn in $(declare -F|awk -F'[ :]' '$3~/^'${module}'$/{print$4}'|sort -n); do
                local AC_${module//./_}_${afn}=1
            done
            local -a completed=( $(eval echo "\${!AC_${module//./_}_${fn}*}") )
            if echo ${completed[@]} | grep -qE "\<AC_${module//./_}_${fn}\>"; then
                echo ${fn}
            else
                echo ${completed[@]//AC_${module//./_}_/}
            fi
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
    setdata=$(::core:flags.eval "${@}")
    local -i e_flags=$?
    core:log DEBUG "core:flags.eval() returned ${e_flags}"

    eval "${setdata}" #. NOTE: This sets module, fn, $@, etc.
    : ${module?}
    : ${fn?}
    core:log DEBUG "core:wrapper(module=${module}, fn=${fn}, argv=( $@ ))"

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
                    elif [ -z "${supported_formats[${g_FORMAT}]}" ]; then
                        theme ERR_USAGE "That is not a supported format."
                        e=${CORE_FAILURE}
                    elif [ ${supported_formats[${g_FORMAT}]} -gt 0 ]; then
                        [ ${g_DEBUG} -eq 0 ] || set -x
                        :core:execute ${module} ${completed} "${@}"
                        e=$?
                        [ ${g_DEBUG} -eq 0 ] || set +x
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
            theme HAS_FAILED "Module ${module} has errors; see ${SIMBOL_USER_LOG}"
            e=${CODE_FAILURE}
        ;;
        ${CODE_IMPORT_ADMIN?}/*/*)
            theme ERR_USAGE "Module ${module} has been administratively disabled"
            e=${CODE_DISABLED}
        ;;
        */*/*)
            e=${CODE_FAILURE}
            core:raise EXCEPTION_BAD_FN_CALL "Check call/caller to/of \`core:softimport ${@}'"
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
#. 1.12 Exceptions -={
EXCEPTION=63
EXCEPTION_BAD_FN_CALL=64
EXCEPTION_BAD_FN_RETURN_CODE=65
EXCEPTION_MISSING_EXEC=70
EXCEPTION_BAD_MODULE=71
EXCEPTION_DEPRECATED=72
EXCEPTION_MISSING_PERL_MOD=80
EXCEPTION_MISSING_PYTHON_MOD=81
EXCEPTION_MISSING_USER=82
EXCEPTION_INVALID_FQDN=90
EXCEPTION_SHOULD_NOT_GET_HERE=125
EXCEPTION_NOT_IMPLEMENTED=126
EXCEPTION_UNHANDLED=127
declare -A RAISE=(
    [${EXCEPTION_BAD_FN_CALL}]="Bad function call internally"
    [${EXCEPTION_BAD_FN_RETURN_CODE}]="Bad function return code internally"
    [${EXCEPTION_MISSING_EXEC}]="Required executable not found"
    [${EXCEPTION_MISSING_USER}]="Required user environment not set, or set to nil"
    [${EXCEPTION_BAD_MODULE}]="Bad module"
    [${EXCEPTION_DEPRECATED}]="Deprecated function call"
    [${EXCEPTION_MISSING_PERL_MOD}]="Required perl module missing"
    [${EXCEPTION_MISSING_PYTHON_MOD}]="Required python module missing"
    [${EXCEPTION_SHOULD_NOT_GET_HERE}]="Process flow should never get here"
)
function core:raise() {
    : !!! CRITICAL FAILURE !!!
    (
        cpf " %{r:failed with exception} %{g:$e}; %{c:traceback}:\n"
        local i=0
        local -i frames=${#BASH_LINENO[@]}
        #. ((frames-2)): skips main, the last one in arrays
        for ((i=frames-2; i>=0; i--)); do
            cpf "  File %{g:${BASH_SOURCE[i+1]}}, line %{g:${BASH_LINENO[i]}}, in %{r:${FUNCNAME[i+1]}()}\n"
            # Grab the source code of the line
            local code=$(sed -n "${BASH_LINENO[i]}{s/^ *//;p}" "${BASH_SOURCE[i+1]}")
            cpf "    %{wh:>>>} %{c}${code}%{N}\n"
        done
    ) > ${SIMBOL_DEADMAN?}

    local -i e=$1

    if [[ $- =~ x ]]; then
        : !!! Exiting raise function early as we are being traced !!!
    else
        cpf "%{r}EXCEPTION%{+bo}[%s->%s]%{-bo}: %s%{N}:\n" "${e}" "$1" "${RAISE[$e]-[UNKNOWN EXCEPTION:$e]}" >&2

        if [ ${#module} -gt 0 ]; then
            if [ ${#fn} -gt 0 ]; then
                cpf "Function %{c:${module}:${fn}()}" 1>&2
                echo "Critical failure in function ${module}:${fn}()" >> ${SIMBOL_DEADMAN?}
            else
                cpf "Module %{c:${module}}" 1>&2
                echo "Critical failure in module ${module}" >> ${SIMBOL_DEADMAN?}
            fi
        else
            cpf "File %{@path:$0}" 1>&2
            echo "Critical failure in file ${0}" >> ${SIMBOL_DEADMAN?}
        fi

        cpf " %{r:failed with exception} %{g:$e}; %{c:traceback}:\n" 1>&2
        local i=0
        local -i frames=${#BASH_LINENO[@]}
        #. ((frames-2)): skips main, the last one in arrays
        for ((i=frames-2; i>=0; i--)); do
            cpf "  File %{g:${BASH_SOURCE[i+1]}}, line %{g:${BASH_LINENO[i]}}, in %{r:${FUNCNAME[i+1]}()}\n" 1>&2
            # Grab the source code of the line
            local code=$(sed -n "${BASH_LINENO[i]}{s/^ *//;p}" "${BASH_SOURCE[i+1]}")
            cpf "    %{wh:>>>} %{c}${code}%{N}\n" 1>&2
        done
    fi

    exit $e
}
#. }=-
#. }=-
