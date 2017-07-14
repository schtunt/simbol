# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Core utilities module
[core:docstring]

#. Utilities -={
#. Timeout -={
#. Optional long help message
function util:timeout:help() {
    cat <<EOF

    [-t timeout] [-i interval] [-d delay] command
    Execute a command with a time-out.
    Upon time-out expiration SIGTERM (15) is sent to the process. If SIGTERM
    signal is blocked, then the subsequent SIGKILL (9) terminates it.

    -t timeout
        Number of seconds to wait for command completion.
        Default value: $DEFAULT_TIMEOUT seconds.

    -i interval
        Interval between checks if the process is still alive.
        Positive integer, default value: $DEFAULT_INTERVAL seconds.

    -d delay
        Delay between posting the SIGTERM signal and destroying the
        process by SIGKILL. Default value: $DEFAULT_DELAY seconds.

    Note that Bash does not support floating point arithmetic
    (sleep does), therefore all delay/time values must be integers.
EOF
}

function util:timeout:usage() { echo "[-t|--timeout <timeout>] [-i|--interval <interval>] [-d|--delay <delay>]"; }

function util:timeout:shflags() {
    # Timeout.
    local -i DEFAULT_TIMEOUT=9
    # Interval between checks if the process is still alive.
    local -i DEFAULT_INTERVAL=1
    # Delay between posting the SIGTERM signal and destroying the process by SIGKILL.
    local -i DEFAULT_DELAY=1

    cat <<!
integer timeout ${DEFAULT_TIMEOUT?} <timeout> t
integer interval ${DEFAULT_INTERVAL?} <interval> i
integer delay ${DEFAULT_DELAY?} <delay> d
!
}

#shellcheck disable=SC2086,SC2154
function util:timeout() {
    local -i e; let e=CODE_DEFAULT
    [ $# -ge 1 ] || return $e

    eval "$(core:decl_shflags.eval int delay timeout interval)"
    (
        local -i t; let t=timeout
        while ((t > 0)); do
            sleep ${interval}
            kill -0 $$ || exit 0
            ((t -= interval))
        done

        # Be nice, post SIGTERM first.
        # The 'exit 0' below will be executed if any preceeding command fails.
        kill -s SIGTERM $$ && kill -0 $$ || exit 0
        sleep $delay
        kill -s SIGKILL $$
    ) 2>/dev/null &

    #shellcheck disable=SC2093
    exec "$@"
}
#. }=-
#. Date -={
function :util:date_i2s() {
    local -i e; let e=CODE_FAILURE
    core:raise_bad_fn_call_unless $# eq 1

    #. Convert seconds to datestamp
    date --utc --date "1970-01-01 $1 sec" "+%Y%m%d%H%M%S"
    e=$?
    #. FIXME: Mac OS X needs this line instead:
    #. FIXME: date -u -j "010112001970.$1" "+%Y%m%d%H%M%S"

    return $e
}

function :util:date_s2i() {
    core:raise_bad_fn_call_unless $# in 1 2
    local -i e; let e=CODE_FAILURE

    if [ $# -eq 1 ]; then
        local YYYY=${1:0:4}
        local mm=${1:4:2}
        local dd=${1:6:2}
        local HH=${1:8:2}
        local MM=${1:10:2}
        local SS=${1:12:2}

        #. Convert datestamp to seconds
        date --utc --date "${YYYY?}-${mm}-${dd} ${HH?}:${MM?}:${SS?}" "+%s"
        let e=$?
    elif [ $# -eq 2 ]; then
        date --utc --date "${1} ${2}" "+%s"
        let e=$?
    fi

    return $e
}

function :util:time_i2s() {
    core:raise_bad_fn_call_unless $# eq 1
    local -i e; let e=CODE_SUCCESS

    local -i secs=$1

    local -i days
    (( days = secs / 86400 ))
    (( secs %= 86400 ))

    local -i hours
    (( hours = secs / 3600 ))
    (( secs %= 3600 ))

    local -i mins
    (( mins = secs / 60 ))
    (( secs %= 60 ))

    [ ${days} -eq 0 ] || printf "%s" "${days} days, "
    printf "%02d:%02d:%02d\n" ${hours} ${mins} ${secs}

    return $e
}
#. }=-
#. Stat -={
function :util:statmode() {
    local -i e; let e=CODE_FAILURE
    [ $# -eq 1 ] || return $e

    local filepath="$1"
    [ -e "${filepath}" ] || return $e

    stat --printf '%a' "${filepath}"
    e=$?

    return $e
}
#. }=-
#. Lock -={
function :util:lockfile() {
    core:raise_bad_fn_call_unless $# in 2
    local -i e; let e=CODE_SUCCESS

    local -i lid; let lid=$1
    local -i pid; let pid=$2
    printf "${SIMBOL_USER_VAR_TMP?}/lock.%d.%d.sct" ${lid} ${pid}

    return $e
}

function :util:lock() {
    core:raise_bad_fn_call_unless $# in 3
    local -i e; let e=CODE_SUCCESS

    local action=$1
    local -i lid; let lid=$2
    local -i pid; let pid=$3

    local lockdir; lockdir="$(:util:lockfile ${pid} ${lid})"
    case ${action} in
        on)
            while ! mkdir "${lockdir}" &>/dev/null; do
                sleep 0.1
            done
        ;;
        off)
            rmdir "${lockdir}" >&/dev/null
            let e=$?
        ;;
    esac

    return $e
}
#. }=-
#. Misc -={
function :util:listify() {
    core:raise_bad_fn_call_unless $# ge 2

    # shellcheck disable=SC2162
    IFS="$1" read -a s <<< "${*:2}"
    local -i e=$?

    echo "${s[@]}"

    return $e
}

function :util:uniq() {
    core:raise_bad_fn_call_unless $# gt 0

    tr ' ' '\n' <<< "${*}" | sort -u | tr '\n' ' '
    return $?
}

function :util:dups() {
    core:raise_bad_fn_call_unless $# in 0

    while read -r line; do
        echo "${line}"
    done |
    sort -n |
    awk 'BEGIN{last=0};$1~/uidNumber/{if(last==$2){print$2};last=$2}' |
    sort -u

    return $?
}

function :util:undelimit() {
    core:raise_bad_fn_call_unless $# in 0 1

    tr "${1:-${SIMBOL_DELIM?}}" "\n"
    return $?
}

function :util:join() {
    #. Usage: array=( a b c ); :util:join $delim array
    core:raise_bad_fn_call_unless $# in 2 3

    local -i e; let e=CODE_FAILURE

    local -i len; let len=$(core:len "$2")
    case ${len}:$# in
        0:3)
            if (( $3 > len )); then
                core:raise EXCEPTION_USER_ERROR\
                    "Array overrun \${$2[*]:$3} when array length is only ${len}"
            else
                let e=CODE_SUCCESS
            fi
        ;;
        *:3)
            if (( $3 <= len )); then
                local IFS=$1
                eval "printf \"\${${2}[*]:${3}}\""
                let e=$?
            else
                core:raise EXCEPTION_USER_ERROR\
                    "Array overrun \${$2[*]:$3} when array length is only ${len}"
            fi
        ;;
        0:2)
            let e=CODE_SUCCESS
        ;;
        *:2)
            local IFS=$1
            eval "echo -n \"\${${2}[*]}\""
            let e=$?
        ;;
        *:*)
            core:raise EXCEPTION_SHOULD_NOT_GET_HERE
        ;;
    esac

    return $e
}

function :util:zip.eval() {
    #. Usage: k=(a b c); v=(x y z); eval a=( $(zip.eval k v) )

    core:raise_bad_fn_call_unless $# in 2
    local -i size; let size=$(eval "echo \${#$1[@]}")
    local -i i=0
    echo '('
    while [ $i -lt ${size} ]; do
        eval echo "[\${$1[$i]}]=\${$2[$i]}"
        ((i++))
    done
    echo ')'

    return $?
}


function :util:is_int() {
    core:raise_bad_fn_call_unless $# in 1
    [[ $1 =~ ^-?[0-9]+$ ]]
    return $?
}

#function :util:cphash() {
#    local assoc_array_string=$(local -p $2)
#    eval "local -A $1=${assoc_array_string#*=}"
#    echo eval $(local -p $1)
#}
#
#function :util:locald() {
#    local -pA|awk 'BEGIN{e='${CODE_FAILURE?}'};$0~/local .*'$1'=/{e='${CODE_SUCCESS?}'};END{exit(e)}'
#    return $?
#}
#. }=-
#. ANSI2HTML -={
function :util:ansi2html() {
    "${SIMBOL_CORE_LIBEXEC?}/ansi2html"
    return $?
}
#. }=-
#. Markdown Scaffolding -={
function :util:markdown() {
    core:raise_bad_fn_call_unless $# gt 0
    local -i e; let e=CODE_FAILURE

    if read -rt 0 -N 0; then
        local op=$1
        shift

        {
            case ${op} in
                h1) printf "# %s\n\n" "$@";;
                h2) printf "# %s\n\n" "$@";;
                h3) printf "# %s\n\n" "$@";;
                h4) printf "# %s\n\n" "$@";;
                h5) printf "# %s\n\n" "$@";;
                h6) printf "# %s\n\n" "$@";;
            esac
            cat
            echo "###### vim:syntax=markdown"
        } | vimcat
        let e=$?
    fi

    return $e
}
#. }=-
#. Set Operations -={
#function :util:sets_explode() {
#    for item in $(eval echo \${$1[@]}); do
#        echo ${item}
#    done | sort
#}
#
#function :util:sets_set_union() {
#    sort -um <( explode $1) <(explode $2)
#}
#
#function :util:sets_set_intersect() {
#    comm -12 <(explode $1) <(explode $2)
#}
#
#function :util:sets_set_complement() {
#    comm -23 <(explode $1) <(explode $2)
#}
#
#function :util:sets_set_symdiff() {
#    sd=( $(comm -3 <(explode $1) <(explode $2)) )
#    explode sd
#}
#. }=-
#. }=-
