# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Site's color printf module
[core:docstring]

#. The Color PrintF Module -={
: ${SIMBOL_IN_COLOR?}

: ${USER_CPF_INDENT_STR?}
: ${USER_CPF_INDENT_SIZE?}

: ${FD_STDOUT?}
: ${FD_STDERR?}

#declare -i ncolors=$(tput colors)
#if [ ${ncolors:=-2} -ge 8 ]; then
declare -A COLORS=(
    [N]="$(tput sgr0)"      [R]="$(tput rev)"

    [+ul]="$(tput smul)"    [-ul]="$(tput rmul)"
    [+st]="$(tput smso)"    [-st]="$(tput rmso)"
    [+bo]="$(tput bold)"    [-bo]="$(tput sgr0)"

    [bl]="$(tput setaf 0)"  [wh]="$(tput setaf 7)"
    [r]="$(tput setaf 1)"   [g]="$(tput setaf 2)"
    [y]="$(tput setaf 3)"   [b]="$(tput setaf 4)"
    [m]="$(tput setaf 5)"   [c]="$(tput setaf 6)"
)

#. cpf:module -={
function ::cpf:module_is_modified() {
    local -i e=${FALSE?}

    local module_path="$1"
    local module=$2

    [ -x ${module_path} ] && cd "${module_path}" || core:raise EXCEPTION_SHOULD_NOT_GET_HERE
    local amended=$(git status --porcelain "${module}.sh"|wc -l)
    [ ${PIPESTATUS[0]} -eq ${CODE_SUCCESS?} ] || core:raise EXCEPTION_SHOULD_NOT_GET_HERE

    [ ${amended} -eq 0 ] || e=${TRUE?}

    return $e
}
function ::cpf:module_has_alerts() {
    local -i e=${CODE_FAILURE?}

    local module_path="$1"
    local module=$2

    grep -qE "^function ${module}:[a-z0-9]+:alert()" "${module_path}/${module}.sh" 2>/dev/null
    [ $? -ne 0 ] || e=${CODE_SUCCESS?}

    return $e
}
function ::cpf:module() {
    local -r module=$1

    local -i enabled="$(core:module_enabled "${module}")"
    if [ ${enabled} -eq ${TRUE?} ]; then
        local -i amended=${FALSE?}

        local module_path
        module_path="$(core:module_path "${module}")"
        local fmt=''
        if ::cpf:module_has_alerts "${module_path}" ${module}; then
            fmt+="%{y}"
        else
            fmt+="%{c}"
            ::cpf:module_is_modified "${module_path}" ${module}
            amended=$?
        fi

        [ ${amended} -eq ${FALSE?} ] || fmt+="%{+bo}"
        fmt+='%s'
        [ ${amended} -eq ${FALSE?} ] || fmt+="%{-bo}"

        cpf "${fmt}%{N}" "${module}"
    fi
}
#. }=-
#. cpf:function -={
function ::cpf:function_has_alerts() {
    local -i e=${CODE_FAILURE?}

    local module_path="$1"
    local module=$2
    local fn=$3

    grep -qE "^function ${module}:${fn}:alert()" "${module_path}/${module}.sh" 2> /dev/null
    [ $? -ne 0 ] || e=${CODE_SUCCESS?}

    return $e
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
        cpf " ${fmt}%{N}" ${fn}
    fi
}
#. }=-
#. cpf:indent -={
declare -gi CPF_INDENT=0
function -=[() { ((CPF_INDENT++)); }
function ]=-() { ((CPF_INDENT--)); }
function cpf:indent() {
    if [ ${CPF_INDENT} -gt 0 ]; then
        printf "%$((CPF_INDENT * USER_CPF_INDENT_SIZE))s" "${USER_CPF_INDENT_STR}"
    fi
}
#. cpfi -={
function cpfi() {
    cpf:indent
    cpf "$@"
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
                    info)                fmt="%{wh:${fmt}}";;
                    pass)                fmt="%{g:${fmt}}";;
                    note)                fmt="%{m:${fmt}}";;
                    link)                fmt="%{b:${fmt}}";;
                    loc)                 fmt="%{c:${fmt}}";;
                    tldid)               fmt="%{m:<${fmt}>}";;
                    netgroup)            fmt="%{c:${fmt}}";;
                    netgroup_empty)      fmt="%{+bo}%{bl:${fmt}}%{-bo}";;
                    netgroup_missing)    fmt="%{+bo}%{r:${fmt}}%{-bo}";;
                    netgroup_direct)     fmt="%{+bo}%{c:${fmt}}%{-bo}";;
                    netgroup_indirect)   fmt="%{c:${fmt}}";;
                    code)                fmt="%{c:${fmt}}";;
                    filer)               fmt="%{m:${fmt}}";;
                    timestamp)           fmt="%{g:${fmt}}";;
                    comment)             fmt="%{bl:${fmt}}";;
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
                    user)                fmt="%{m:${fmt}}";;
                    group)               fmt="%{m:${fmt}}";;
                    int)                 fmt="%{g:${fmt}}";;
                    version)             fmt="%{+bo}%{g:${fmt}}%{-bo}";;
                    fn)                  fmt="%{c:${fmt}}";;
                    mod)                 fmt="%{y:${fmt}}";;
                    pkg)                 fmt="%{p:${fmt}}";;
                    lang)                fmt="%{c:${fmt}}";;
                    path)                fmt="%{g:${fmt}}";;
                    bad_path)            fmt="%{r:${fmt}}";;
                    user)                fmt="%{y:${fmt}}";;
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
#. cpf -={
function cpf() {
    #. For `!' operators, use the literal value and not a placeholder `%s'; eg:
    #. Good: "%{!module:${module}}"
    #. Bad:  "%{!module:%s}" "${module}"

    [ ${g_DEBUG} -eq 0 ] || set +x

    #. cpf "%{ul:%s}, %{r}%{bo:%s}, and %{st:%s}%{no}\n" underlined bold standard
    LC_ALL=C

    if [ $# -ge 1 ]; then
        local fmtstr="$1"; shift
        local -a args=( "$@" )

        local -a prefix
        local fmtstr
        local replacement

        while read arg; do
            if [[ ${arg} =~ ^%\{([^:]+):([^}]*)}$ ]]; then
                op=${BASH_REMATCH[1]}
                token=${BASH_REMATCH[2]}
                replacement="${token}"

                #. Convert @theme to colorchar
                case ${op} in
                    !*) fmtstr=${fmtstr//${arg}/$(::cpf:theme "${op}" "${token}")};;
                    @*)
                        read _sym _fmt _arg <<< "$(::cpf:theme "${op}" "${token}")"
                        [ "$_sym" != '0' ] || _sym=
                        if [ ${SIMBOL_IN_COLOR?} -eq 1 ]; then
                            if ::cpf:is_fmt ${_fmt}; then
                                prefix+=( "${_sym}" )
                                replacement=$(cpf "${_fmt}" "$_arg")
                            else
                                replacement=${_fmt}
                            fi
                            fmtstr="${fmtstr//${arg}/${replacement}}"
                        else
                            replacement=${token}
                            if ::cpf:is_fmt ${replacement}; then
                                prefix+=( "${_sym}" )
                            fi
                            fmtstr="${fmtstr//${arg}/${replacement}}"
                        fi
                    ;;
                    rv|bl|wh|r|g|y|b|m|c)
                        if [ ${SIMBOL_IN_COLOR?} -eq 1 ]; then
                            replacement="${COLORS[${op}]}${token}${COLORS[N]}"
                        fi
                        if ::cpf:is_fmt "${replacement}"; then
                            prefix+=( "" )
                        fi
                        fmtstr="${fmtstr//${arg}/${replacement}}"
                    ;;
                    ul|st|bo)
                        if [ ${SIMBOL_IN_COLOR?} -eq 1 ]; then
                            replacement="${COLORS[+${op}]}${token}${COLORS[-${op}]}"
                        fi
                        if ::cpf:is_fmt ${replacement}; then
                            prefix+=( "" )
                        fi
                        fmtstr="${fmtstr//${arg}/${replacement}}"
                    ;;
                esac
            elif [[ ${arg} =~ ^%\{([^:]+)}$ ]]; then
                if [ ${SIMBOL_IN_COLOR?} -eq 1 ]; then
                    op="${BASH_REMATCH[1]}"
                    replacement="${COLORS[${op}]}"
                fi
                prefix+=( "" )
                fmtstr="${fmtstr//${arg}/${replacement}}"
            fi
        done < <(echo "${fmtstr}"|grep -oE '%{[^}]+}')

        local -i substitutions=$(echo ${fmtstr}|sed -e 's/%%//' -e 's/%{\([^}]*\)}/\1/g'|tr -c -d '%'|wc -c)
        if [ ${substitutions} -eq ${#args[@]} ]; then
            if ! echo "${fmtstr}"|grep -qE '%{'; then
                if [ $(core:len args) -gt 0 ]; then
                    local -i i
                    for ((i=0; i<${#args[@]}; i++)); do
                        args[$i]="${prefix[$i]}${args[$i]}"
                    done
                    printf "${fmtstr}" "${args[@]}"
                else
                    printf "${fmtstr}"
                fi
            else
                echo "CPF Failure: still have %{ in the fmtstr!: ${fmtstr}" >&${FD_STDERR}
                exit 99
            fi
        else
            echo "CPF Failure: mismatched arguments for given format string ( ${substitutions} in fmtstr, ${#args[@]} arguments supplied )" >&${FD_STDERR}
            echo " - Formatstr: \`${fmtstr}'" >&${FD_STDERR}
            if [ ${#args[@]} -gt 0 ]; then
                echo " - Arguments:" >&${FD_STDERR}
                printf " * \`%s'\n" "${args[@]}" >&${FD_STDERR}
            else
                echo " - Arguments: None" >&${FD_STDERR}
            fi
        fi
    else
        echo
    fi

    [ ${g_DEBUG} -eq 0 ] || set -x
}
#. }=-
#. theme -={
function theme() {
    if [ $# -gt 0 ]; then
        local dvc=${FD_STDOUT}
        local item=$1; shift
        local fmt
        case ${item} in
            HAS_PASSED)          fmt="%{g}PASS";;
            HAS_WARNED)          fmt="%{y}WARN";;
            HAS_FAILED)          fmt="%{r}FAIL";;
            HAS_AUTOED)
                case $1 in
                    0)           fmt="%{g}PASS"; shift;;
                    *)           fmt="%{r}FAIL"; shift;;
                esac
            ;;

            FALSE)               fmt="%{r}FALSE";;
            TRUE)                fmt="%{g}TRUE";;

            INFO)                fmt="%{wh}INFO"; dvc=${FD_STDERR};;
            NOTE)                fmt="%{wh}NOTE"; dvc=${FD_STDERR};;
            WARN)                fmt="%{y}WARN";  dvc=${FD_STDERR};;
            DEPR)                fmt="%{y}WARN";  dvc=${FD_STDERR};;
            ERR)                 fmt="%{r}ERROR"; dvc=${FD_STDERR};;
            ERR_USAGE)           fmt="%{r}USAGE ERROR"; dvc=${FD_STDERR};;
            EXCEPTION)           fmt="%{r}EXCEPTION"; dvc=${FD_STDERR};;

            TODO)                fmt="%{y}TODO"; dvc=${FD_STDERR};;
            FIXME)               fmt="%{r}FIXME"; dvc=${FD_STDERR};;

            ERR_INTERNAL)        fmt="%{r}INTERNAL ERROR"; dvc=${FD_STDERR};;
            ALERT)               fmt="%{r}ALERT"; dvc=${FD_STDERR};;

            *) core:raise EXCEPTION_BAD_FN_CALL 1
        esac

        case ${item} in
            [A-Z]*)
                [ $# -eq 0 ] || fmt+=" %{+bo}[%s]%{-bo}"
                fmt+="%{N}\n"
            ;;
        esac

        if [ ${SIMBOL_IN_COLOR?} -eq 1 ]; then
            cpf "${fmt}" "$@" >&${dvc}
        else
            cpf "${fmt}" "$@"
        fi
    else
        if [ ${SIMBOL_IN_COLOR?} -eq 1 ]; then
            echo >&${dvc}
        else
            echo
        fi
    fi
}
#. }=-
#. }=-
