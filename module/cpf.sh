# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Site's color printf module
[core:docstring]

#. The Color PrintF Module -={
: ${SIMBOL_IN_COLOR?}

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
    local -i e=9
    local profile=$1
    local module=$2
    cd ${SIMBOL_CORE?}
    if [ -e "${SIMBOL_USER_MOD?}/${module}" ]; then
        local path=$(readlink "${SIMBOL_USER_MOD?}/${module}")
        local amended=$(:core:git status --porcelain "${path}"|wc -l)
        [ ${PIPESTATUS[0]} -ne 0 ] || e=${amended}
    fi
    #cd ${OLDPWD?}

    return $e
}
function ::cpf:module_has_alerts() {
    local -i e=${CODE_FAILURE?}

    local profile=$1
    local module=$2
    if [ -e "${SIMBOL_USER_MOD?}/${module}" ]; then
        grep -qE "^function ${module}:[a-z0-9]+:alert()" "${SIMBOL_USER_MOD?}/${module}"
        [ $? -ne 0 ] || e=${CODE_SUCCESS?}
    fi

    return $e
}
function ::cpf:module() {
    local -r module=$1

    local -i enabled=1
    local -i alerts=0
    local -i amended=0
    local fmt
    if [ -e ${SIMBOL_CORE_MOD?}/${module} ]; then
        if ::cpf:module_has_alerts core ${module}; then
            alerts=1
            fmt="%{y}"
        else
            fmt="%{c}"
            ::cpf:module_is_modified core ${module}
            amended=$?
        fi
        enabled=${CORE_MODULES[${module}]}
    elif [ -e ${SIMBOL_USER_MOD?}/${module} ]; then
        if ::cpf:module_has_alerts ${SIMBOL_PROFILE?} ${module}; then
            alerts=1
            fmt="%{y}"
        else
            fmt="%{b}"
            ::cpf:module_is_modified ${SIMBOL_PROFILE?} ${module}
            amended=$?
        fi
        enabled=${USER_MODULES[${module}]}
    fi

    [ ${amended} -eq 0 ] || fmt+="%{ul}"
    [ ${enabled} -eq 0 ] || fmt+="%{bo}"

    cpf "${fmt}%s%{N}" ${module}
}
#. }=-
#. cpf:function -={
function ::cpf:function_has_alerts() {
    local -i e=${CODE_FAILURE?}

    local profile=$1
    local module=$2
    local fn=$3
    if [ -e "${SIMBOL_USER_MOD?}/${module}" ]; then
        grep -qE "^function ${module}:${fn}:alert()" "${SIMBOL_USER_MOD?}/${module}"
        [ $? -ne 0 ] || e=${CODE_SUCCESS?}
    fi

    return $e
}
function ::cpf:function() {
    local -r module=$1
    local -r fn=$2

    local -i enabled=1
    local -i alerts=0
    local -i amended=0
    local fmt
    if [ -e ${SIMBOL_CORE_MOD?}/${module//\./\/}.sh ]; then
        if ::cpf:function_has_alerts core ${module} ${fn}; then
            alerts=1
            fmt="%{y}"
        else
            fmt="%{g}"
            ::cpf:module_is_modified core ${module}
            amended=$?
        fi
        enabled=${CORE_MODULES[${module}]}
    elif [ -e ${SIMBOL_USER_MOD?}/${module//\./\/}.sh ]; then
        if ::cpf:function_has_alerts ${SIMBOL_PROFILE?} ${module} ${fn}; then
            alerts=1
            fmt="%{y}"
        else
            fmt="%{g}"
            ::cpf:module_is_modified ${SIMBOL_PROFILE?} ${module}
            amended=$?
        fi
        enabled=${USER_MODULES[${module}]}
    fi

    [ ${amended} -eq 0 ] || fmt+="%{ul}"
    [ ${enabled} -eq 0 ] || fmt+="%{bo}"

    cpf "${fmt}%s %{b:%s}%{N}" ${module} ${fn}
}
#. }=-

#. cpf:theme -={
function ::cpf:is_fmt() {
    grep -qE '%' <<<"$1"
    return $?
}

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
                    module) ::cpf:module ${arg};;
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
            *) core:raise EXCEPTION_BAD_FN_CALL "What is ${op}?";;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL "What is your problem?"
    fi
}
#. }=-
#. cpf -={
function cpf() {
    [ ${g_DEBUG} -eq 0 ] || set +x

    #. cpf "%{ul:%s}, %{r}%{bo:%s}, and %{st:%s}%{no}\n" underlined bold standard
    LC_ALL=C

    #echo "XXX FUNC CALL with ${#}" >&${FD_STDERR}

    if [ $# -ge 1 ]; then
        local fmtstr="$1"; shift
        local -a args=( "${@}" ) #. XXX "${@}" to preserve array size in tokens with spaces

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
                                #echo XXX _fmt $_fmt >&${FD_STDERR}
                                #echo XXX _arg $_arg >&${FD_STDERR}
                                #echo XXX _sym $_sym >&${FD_STDERR}
                                replacement=$(cpf "${_fmt}" "$_arg")
                                #echo XXX replacement is now \"${replacement}\" >&${FD_STDERR}
                            else
                                replacement=${_fmt}
                            fi
                            #echo XXX fmtstr="${fmtstr} minus ${arg} plus ${replacement}" >&${FD_STDERR}
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
                            #XXX echo xxxxxxxxxxxxx ${op} ${token} >&${FD_STDERR}
                            replacement="${COLORS[${op}]}${token}${COLORS[N]}"
                        fi
                        #XXX echo xxxxxxxxxxxxx replacing $arg with $replacement >&${FD_STDERR}
                        if ::cpf:is_fmt "${replacement}"; then
                            prefix+=( "" )
                        fi
                        #XXX echo yyyyyyyyyyyyy ${fmtstr} >&${FD_STDERR}
                        fmtstr="${fmtstr//${arg}/${replacement}}"
                        #XXX echo zzzzzzzzzzzzz ${fmtstr} >&${FD_STDERR}
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

        #echo "XXX fmt >>> ${fmtstr} <<<" >&${FD_STDERR}
        #echo "XXX arg ${#args[@]}: ${args[@]}" >&${FD_STDERR}
        #echo "XXX sym ${#prefix[@]}: ${prefix[@]}" >&${FD_STDERR}
        local -i substitutions=$(echo ${fmtstr}|sed -e 's/%{\([^}]*\)}/\1/g'|tr -c -d '%'|wc -c)
        #echo "XXX [ ${substitutions} == ${#args[@]} ]" >&${FD_STDERR}
        if [ ${substitutions} -eq ${#args[@]} ]; then
            if ! echo "${fmtstr}"|grep -qE '%{'; then
                local -i i
                for ((i=0; i<${#args[@]}; i++)); do
                    #echo "XXX pre-change arg $i  >>> ${args[$i]}" >&${FD_STDERR}
                    args[${i}]="${prefix[$i]}${args[${i}]}"
                    #echo "XXX post-chance arg $i >>> ${args[$i]}" >&${FD_STDERR}
                done
                #. XXX
                #echo format is "${fmtstr}" 2>&${FD_STDERR}
                #echo args are "${args[@]}" 2>&${FD_STDERR}
                printf "${fmtstr}" "${args[@]}"
            else
                echo "CPF Failure - still have %{ in the fmtstr!: ${fmtstr}" >&${FD_STDERR}
                exit 99
            fi
        else
            echo "CPF Failure: mismatched arguments for given format string ( ${substitutions} in fmtstr, ${#args[@]} arguments supplied )" >&${FD_STDERR}
            echo "Formatstr: \`${fmtstr}'" >&${FD_STDERR}
            echo "Arguments:" >&${FD_STDERR}
            printf " * \`%s'\n" "${args[@]}" >&${FD_STDERR}
            #exit 99
        fi
    else
        echo
    fi

    #echo "XXX FUNC RETN" >&${FD_STDERR}
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
