# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Site's color printf module
[core:docstring]

#. The Color PrintF Module -={

: ${USER_CPF_INDENT_STR?}
: ${USER_CPF_INDENT_SIZE?}

: ${FD_STDOUT?}
: ${FD_STDERR?}

#declare -i ncolors=$(tput colors)
#if [ ${ncolors:=-2} -ge 8 ]; then
declare -A SIMBOL_ESCAPE_SEQUENCES_ON=(
    [N]="$(tput sgr0)"      [R]="$(tput rev)"

    [+ul]="$(tput smul)"    [-ul]="$(tput rmul)"
    [+st]="$(tput smso)"    [-st]="$(tput rmso)"
    [+bo]="$(tput bold)"    [-bo]="$(tput sgr0)"

    [+n]="$(tput setaf 0)"  [-n]="$(tput sgr0)"
    [+r]="$(tput setaf 1)"  [-r]="$(tput sgr0)"
    [+g]="$(tput setaf 2)"  [-g]="$(tput sgr0)"
    [+y]="$(tput setaf 3)"  [-y]="$(tput sgr0)"
    [+b]="$(tput setaf 4)"  [-b]="$(tput sgr0)"
    [+m]="$(tput setaf 5)"  [-m]="$(tput sgr0)"
    [+c]="$(tput setaf 6)"  [-c]="$(tput sgr0)"
    [+w]="$(tput setaf 7)"  [-w]="$(tput sgr0)"
)

declare -A SIMBOL_ESCAPE_SEQUENCES

function cpf:initialize() {
    [ ${g_DEBUG?} -eq ${FALSE?} ] || set +x

    local -i sic=$1

    if [ ${sic} -eq 1 ]; then
        for key in "${!SIMBOL_ESCAPE_SEQUENCES_ON[@]}"; do
            SIMBOL_ESCAPE_SEQUENCES[${key}]="${SIMBOL_ESCAPE_SEQUENCES_ON[${key}]}"
        done
    else
        for key in "${!SIMBOL_ESCAPE_SEQUENCES_ON[@]}"; do
            SIMBOL_ESCAPE_SEQUENCES[${key}]=
        done
    fi

    PS4="${SIMBOL_ESCAPE_SEQUENCES[+r]}\${BASH_SOURCE}${SIMBOL_ESCAPE_SEQUENCES[N]}"
    PS4+=":${SIMBOL_ESCAPE_SEQUENCES[+g]}\${LINENO}${SIMBOL_ESCAPE_SEQUENCES[N]}"
    PS4+="/${SIMBOL_ESCAPE_SEQUENCES[+b]}\${FUNCNAME}/ "
    export PS4

    [ ${g_DEBUG} -eq ${FALSE?} ] || set -x
}

declare -A SIMBOL_OUTPUT_THEME
SIMBOL_OUTPUT_THEME+=(
    [profile]='%{c:@%s}'
    [module]='%{b:%s}'
    [function]='%{c:%s}'
    [hgd]='%{m:%s}'

    [version]='%{+bo}v%{g:%s}%{-bo}'
    [path]='%{g:%s}'
    [user]='%{b:%s@}'
    [host]='%{y:@%s}'

    [int]='%{g:%s}'

    [pass]='%{g:%s}'
    [warn]='%{y:%s}'
    [fail]='%{r:%s}'
    [error]='%{r:%s}'
    [comment]='%{+n}%{bo:%s}%{-n}'

    [net]='%{c:#%s}'
    [port]='%{g:%s}'
    [ip]='%{m:#%s}'
)

#. cpf:module -={
function ::cpf:module_is_modified() {
    local -i e=${FALSE?}

    local module_path="$1"
    local module=$2

    core:cd "${module_path}"
    local amended=$(git status --porcelain "${module}.sh"|wc -l)
    [ ${PIPESTATUS[0]} -eq ${CODE_SUCCESS?} ] || core:raise EXCEPTION_SHOULD_NOT_GET_HERE

    [ ${amended} -eq 0 ] || e=${TRUE?}

    return $e
}
function ::cpf:module_has_alerts() {
    core:raise_bad_fn_call_unless $# in 2

    local module_path="$1"
    local module="$2"

    grep -qE "^function ${module}:[a-z0-9]+:alert()" "${module_path}/${module}.sh" 2>/dev/null
    return $?
}
function ::cpf:module() {
    core:raise_bad_fn_call_unless $# in 1

    local -r module=$1
    local -i enabled="$(core:module_enabled "${module}")"
    [ ${enabled} -eq ${TRUE?} ] || return ${CODE_FAILURE?}

    local -i amended=${FALSE?}

    local module_path
    module_path="$(core:module_path "${module}")"
    local fmt
    if ::cpf:module_has_alerts "${module_path}" ${module}; then
        fmt="%{+y}"
    else
        fmt="%{+c}"
        ::cpf:module_is_modified "${module_path}" ${module}
        amended=$?
    fi

    if [ ${amended} -eq ${FALSE?} ]; then
        fmt+="%{+ul:%s}"
    else
        fmt+='%s'
    fi

    cpf:printf "${fmt}%{N}" "${module}"
}
#. }=-
#. cpf:function -={
function ::cpf:function_has_alerts() {
    core:raise_bad_fn_call_unless $# in 3

    local module_path="$1"
    local module="$2"
    local fn="$3"

    grep -qE "^function ${module}:${fn}:alert()" "${module_path}/${module}.sh" 2> /dev/null
    return $?
}
function ::cpf:function() {
    local -r module=$1
    local -r fn=$2

    local -i enabled="$(core:module_enabled "${module}")"
    if [ ${enabled} -eq ${TRUE?} ]; then
        local fmt=''

        local module_path="$(core:module_path "${module}")"
        ::cpf:function_has_alerts "${module_path}" ${module} ${fn}
        local has_alerts=$?

        fmt+="%{b}"
        [ ${has_alerts} -eq ${FALSE?} ] || fmt+="%{+bo}"
        fmt+='%s'
        [ ${has_alerts} -eq ${FALSE?} ] || fmt+="%{-bo}"

        ::cpf:module "${module}"
        cpf:printf " ${fmt}%{N}" ${fn}
    fi
}
#. }=-
#. cpf:indent -={
declare -gi CPF_INDENT; let CPF_INDENT=0
eval 'function -=[() { local -i e=$?;  ((CPF_INDENT++)); return $e; }'
eval 'function ]=-() { local -i e=$?; ((CPF_INDENT--)); return $e; }'
function cpf:indent() {
    [ ${CPF_INDENT?} -gt 0 ] || return

    printf\
        "%$((CPF_INDENT * USER_CPF_INDENT_SIZE + ${#USER_CPF_INDENT_STR}))s"\
        "${USER_CPF_INDENT_STR?}"
}
#. cpfi -={
function cpfi() {
    cpf:indent
    cpf:printf "$@"
}
#. }=-
#. }=-

#. TODO:
#. This might need more detailed checking
function ::cpf:is_fmt() {
    grep -qE '%.+' <<<"$1"
    return $?
}

#. cpf:theme -={
function ::cpf:theme() {
    local e=1

    if [ $# -eq 2 ]; then
        local op=${1:0:1}
        local th=${1:1:${#1}}
        local arg="${2}"
        local fmt="%s"
        case ${op} in
            !)
                case ${th} in
                    module) ::cpf:module "${arg}";;
                    function)
                        IFS=: read -r module fn <<< "${arg}"
                        ::cpf:function ${module} ${fn}
                    ;;
                    *) core:raise EXCEPTION_BAD_FN_CALL 2;;
                esac
            ;;
            @)
                local symbol=
                case ${th} in
                    netgroup)            symbol='+';;
                    netgroup_empty)      symbol='+';;
                    netgroup_missing)    symbol='+';;
                    netgroup_direct)     symbol='+';;
                    netgroup_indirect)   symbol='+';;
                    filer)               symbol='@';;
                    host)                symbol='@';;
                    host_bad)            symbol='@';;
                    ip)                  symbol='#';;
                    group)               symbol='%';;
                esac

                #. If a symbol is defined
                if [ ${#symbol} -gt 0 ]; then
                    #. If the argument is a literal, for example %{@host:myhost}, and NOT %{@host:%s}
                    if ! ::cpf:is_fmt "${arg}"; then
                        #. Add the symbol in now, and unset the symbol variable back to null
                        arg="${symbol}${arg}"
                    fi
                else
                    symbol='0'
                fi

                case ${th} in
                    err|crit|fail)       fmt="%{r:${fmt}}";;
                    warn)                fmt="%{y:${fmt}}";;
                    info)                fmt="%{w:${fmt}}";;
                    pass)                fmt="%{g:${fmt}}";;
                    note)                fmt="%{m:${fmt}}";;
                    link)                fmt="%{b:${fmt}}";;
                    loc)                 fmt="%{c:${fmt}}";;
                    netgroup)            fmt="%{c:${fmt}}";;
                    netgroup_empty)      fmt="%{+bo}%{n:${fmt}}%{-bo}";;
                    netgroup_missing)    fmt="%{+bo}%{r:${fmt}}%{-bo}";;
                    netgroup_direct)     fmt="%{+bo}%{c:${fmt}}%{-bo}";;
                    netgroup_indirect)   fmt="%{c:${fmt}}";;
                    code)                fmt="%{c:${fmt}}";;
                    filer)               fmt="%{m:${fmt}}";;
                    timestamp)           fmt="%{g:${fmt}}";;
                    comment)             fmt="%{n:${fmt}}";;
                    query)               fmt="%{m:${fmt}}";;
                    profile)             fmt="%{y:${fmt}}";;
                    hash)                fmt="%{b:${fmt}}";;
                    fqdn)                fmt="%{y:${fmt}}";;
                    host)                fmt="%{y:${fmt}}";;
                    service)             fmt="%{r:${fmt}}";;
                    port)                fmt="%{g:${fmt}}";;
                    host_bad)            fmt="%{r:${fmt}}";;
                    ip)                  fmt="%{b:${fmt}}";;
                    cmd)                 fmt="%{c:${fmt}}";;
                    subnet)              fmt="%{c:${fmt}}";;
                    hgd)                 fmt="%{+bo}%{m:${fmt}}%{-bo}";;
                    group)               fmt="%{m:${fmt}}";;
                    int)                 fmt="%{g:${fmt}}";;
                    fn)                  fmt="%{c:${fmt}}";;
                    mod)                 fmt="%{y:${fmt}}";;
                    pkg)                 fmt="%{p:${fmt}}";;
                    lang)                fmt="%{c:${fmt}}";;
                    bad_path)            fmt="%{r:${fmt}}";;
                    key)                 fmt="%{y:${fmt}}";;
                    val)                 fmt="%{g:${fmt}}";;
                    *)                   core:raise EXCEPTION_BAD_FN_CALL "What is ${th}?";;
                esac

                echo "${symbol}" "${fmt}" "${arg}"
            ;;
            *) core:raise EXCEPTION_BAD_FN_CALL "Unknown operator \`%s'" "${op}";;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL "What is your problem?"
    fi
}
#. }=-
#. cpf:printf -={
function cpf:printf() {
    [ ${g_DEBUG?} -eq ${FALSE?} ] || set +x
    if [ $# -eq 0 ]; then
        echo
        return ${CODE_SUCCESS?}
    fi

    local -i len; let len=$(core:len SIMBOL_ESCAPE_SEQUENCES)
    if [ ${len} -eq 0 ]; then
        [ -t 1 ]
        #shellcheck disable=SC2181
        cpf:initialize $((~$?+2))
    fi

    LC_ALL=C

    local buffer=''
    local context='&'
    local -a stack=()
    local stacksize=0
    local output=''

    while IFS= read -rn1 char; do
        case "${char}/${context}/${stacksize}" in
            %/%/*)
                output+='%%'
                context='&'
            ;;
            %/\&/*)
                context='%'
            ;;
            '{'/%/*)
                context='~'
                ((stacksize++))
            ;;
            */%/*)
                context='&'
                output+="%${char}"
            ;;
            [-+@]/~/*)
                context="${char}"
            ;;
            '}'/-/*)
                ((stacksize--))
                [ ${stack[-1]} == ${buffer} ] || exit 1
                buffer=
                output+="${SIMBOL_ESCAPE_SEQUENCES[-${stack[-1]}]}"
                #shellcheck disable=SC2184
                unset stack[-1]
                context='&'
            ;;
            '}'/+/*)
                ((stacksize--))
                stack+=( "${buffer}" )
                output+="${SIMBOL_ESCAPE_SEQUENCES[+${stack[-1]}]}"
                buffer=
                context='&'
            ;;
            '}'/[:~]/*)
                output+="${buffer}"
                buffer=

                output+="${SIMBOL_ESCAPE_SEQUENCES[-${stack[-1]}]}"
                #shellcheck disable=SC2184
                unset stack[-1]
                ((stacksize--))

                for ((i=${#stack[@]}; i>0; --i)); do
                    output+="${SIMBOL_ESCAPE_SEQUENCES[+${stack[$i-1]}]}"
                done

                context='&'
            ;;
            '}'/\&/*)
                output+="${char}"
            ;;
            '}'/@/*)
                local -i len; let len=$(core:len stack)
                [ ${len} -gt 0 ] ||
                    core:raise EXCEPTION_SHOULD_NOT_GET_HERE\
                        "Unexpected empty stack; buffer=${buffer}"

                fmt="${stack[-1]}"
                #shellcheck disable=SC2184
                unset stack[-1]
                ((stacksize--))

                output+="$(cpf:printf "${fmt}" "${buffer}")"
                buffer=

                for ((i=${#stack[@]}; i>0; --i)); do
                    output+="${SIMBOL_ESCAPE_SEQUENCES[+${stack[$i-1]}]}"
                done

                context='&'
            ;;
            :/~/[1-9]*)
                output+="${SIMBOL_ESCAPE_SEQUENCES[+${buffer}]}"
                stack+=( $buffer )
                buffer=
                context=':'
            ;;
            :/@/[1-9]*)
                grep -qFw "${buffer}" <<< "${!SIMBOL_OUTPUT_THEME[*]}" ||
                    core:raise EXCEPTION_BAD_FN_CALL "No such theme \`${buffer}'"
                stack+=( "${SIMBOL_OUTPUT_THEME[${buffer}]}" )
                buffer=
            ;;
            */[-+~@]/*)
                buffer+=${char}
            ;;
            */*/*)
                output+=${char}
            ;;
        esac
    done <<< "${1}"

    if [ ${#stack[@]} -ne 0 -o ${stacksize} -ne 0 ]; then
        e=${CODE_FAILURE?}
    else
#echo "# DEBUG: ${output} ${*:2} / stack: ${stack[@]+${stack[@]}} / buffer: $buffer" >&2
        eval "printf -- \"${output}\" \"\${@:2}\""
    fi

    [ ${g_DEBUG} -eq ${FALSE?} ] || set -x
}
#. }=-
#. theme -={
function theme() {
    local -i e=$?

    [ $# -gt 0 ] | return $e

    local dvc=${FD_STDOUT}
    local item="$1"
    local s
    local c
    case ${item}:${2:--} in
        HAS_PASSED:*)        c='g'; s='PASS';;
        HAS_AUTOED:0)        c='g'; s='PASS';;
        HAS_WARNED:*)        c='y'; s='WARN';;
        HAS_FAILED:*)        c='r'; s='FAIL';;
        HAS_AUTOED:[1-9]*)   c='r'; s='FAIL';;

        TRUE:*)         c='g'; s='TRUE';;
        FALSE:*)        c='r'; s='FALSE';;

        INFO:*)         c='w'; s='INFO';           dvc=${FD_STDERR};;
        NOTE:*)         c='w'; s='NOTE';           dvc=${FD_STDERR};;
        WARN:*)         c='y'; s='WARN';           dvc=${FD_STDERR};;
        DEPR:*)         c='y'; s='DEPRECATED';     dvc=${FD_STDERR};;
        ERR:*)          c='r'; s='ERROR';          dvc=${FD_STDERR};;
        ALERT:*)        c='r'; s='ALERT';          dvc=${FD_STDERR};;
        ERR_USAGE:*)    c='r'; s='USAGE ERROR';    dvc=${FD_STDERR};;
        EXCEPTION:*)    c='r'; s='EXCEPTION';      dvc=${FD_STDERR};;
        ERR_INTERNAL:*) c='r'; s='INTERNAL ERROR'; dvc=${FD_STDERR};;

        TODO:*)         c='y'; s='TODO';           dvc=${FD_STDERR};;
        FIXME:*)        c='r'; s='FIXME';          dvc=${FD_STDERR};;

        *:*) core:raise EXCEPTION_BAD_FN_CALL 1
    esac

    if [ $# -eq 1 ]; then
        cpf:printf "%{+$c}$s%{-$c}\n" >&${dvc}
    else
        cpf:printf "%{+$c}$s %{bo:[%s]}%{-$c}\n" "${@:2}" >&${dvc}
    fi

    return $e
}
#. }=-
#. }=-
