# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
SSH Tunnelling
[core:docstring]

#. Tunneling Module -={
core:import net
core:import util

core:requires ssh
core:requires netstat

#shellcheck disable=SC2086
: ${SIMBOL_USER_SSH_CONTROLPATH:=${SIMBOL_USER_VAR_RUN?}/simbol-ssh-mux@prd.proxy.sock}

#. tunnel:status -={
function :tunnel:pid() {
    #. XXX - Not using $1?
    core:raise_bad_fn_call_unless $# eq 1

    local -i e; let e=CODE_FAILURE

    if [ -e "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
        local raw
        #shellcheck disable=SC2086,SC2154
        raw=$(
            ssh ${g_SSH_OPTS[*]} -o ControlMaster=no\
                -S "${SIMBOL_USER_SSH_CONTROLPATH}" -O check NULL 2>&1 |
                tr -d '\r\n'
        )
        let e=$?

        if (( e == CODE_SUCCESS )); then
            #shellcheck disable=SC2001
            echo "${raw}" | sed -e 's/Master running (pid=\(.*\))$/\1/'
        fi
    else
        let e=CODE_SUCCESS #. No tunnel
    fi

    return $e
}
function tunnel:status() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 0 ] || return $e

    cpf "Checking ssh control master..."

    local -i pid; let pid=$(:tunnel:pid)
    let e=$?

    #shellcheck disable=SC2086
    if [ $e -eq ${CODE_SUCCESS?} ]; then
        theme HAS_AUTOED $e "${pid:-NO_TUNNEL}"

        while read -r line; do
            #shellcheck disable=SC2034
            IFS='[: ]' read -r lh1 lport lh2 rport rhost <<< "${line}"
            cpf "Tunnel from %{@int:${lport}} to %{@host:${rhost}}:%{@int:${rport}}\n"
        done < <(
            ps -fC ssh |
                awk '$0~/ssh\.conf/{print$0}' |
                grep -oE 'localhost:[^ ]+ .*'
        )
    fi

    return $e
}
#. }=-
#. tunnel:start -={
#. XXX do not $(:tunnel:start) - it hangs !?!?!
function :tunnel:start() {
    core:raise_bad_fn_call_unless $# eq 2

    local -i e; let e=CODE_FAILURE

    local -i pid
    local -r hcs=$1
    local -ir port; let port=$2
    if [ -S "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
        let pid=$(:tunnel:pid "${hcs}")
        (( $? != CODE_SUCCESS )) || let e=CODE_E01
    else
        #shellcheck disable=SC2086
        if ssh ${g_SSH_OPTS[*]} -n -fNS "${SIMBOL_USER_SSH_CONTROLPATH}" -p ${port} ${USER_USERNAME}@${hcs}; then
            let pid=$(:tunnel:pid ${hcs})
            #TODO: let will return 0 if pid is assigned 0
            let e=$?
        fi
    fi

    return $e
}

function tunnel:start:usage() { echo "<hcs> [<port:22>]"; }
function tunnel:start() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 2 ] || return $e

    local -r hcs=$1
    local -ri port; let port=${2:-22}
    cpf "Starting ssh control master to %{@host:%s}:%{@port:%s}..." "${hcs}" ${port}
    local -i pid
    if [ -S "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
        pid=$(:tunnel:pid "${hcs}")
        let e=CODE_SUCCESS
        theme HAS_WARNED "ALREADY_RUNNING:${pid}"
    else
        if :tunnel:start "${hcs}" ${port}; then
            let pid=$(:tunnel:pid "${hcs}")
            let e=$?
        fi
        theme HAS_AUTOED $e ${pid}
    fi

    return $e
}



#. }=-
#. tunnel:stop -={
function :tunnel:stop() {
    core:raise_bad_fn_call_unless $# eq 1

    local -i e; let e=CODE_FAILURE

    local -i pid; let pid=0
    if [ -e "${SIMBOL_USER_SSH_CONTROLPATH?}" ]; then
        local -r hcs="$1"
        let pid=$(:tunnel:pid "${hcs}")
        if (( $? == CODE_SUCCESS )); then
            #shellcheck disable=SC2086
            ssh ${g_SSH_OPTS[*]} -no ControlMaster=no\
                -fNS "${SIMBOL_USER_SSH_CONTROLPATH?}" "${hcs}" -O stop 2>&/dev/null
            e=$?
        fi
    else
        let e=CODE_FAILURE
    fi

    echo ${pid}

    return $e
}

function tunnel:stop:usage() { echo "<hcs>"; }
function tunnel:stop() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 1 ] || return $e

    local -r hcs="${1}"
    cpf "Stopping ssh control master to %{@host:${hcs}}..."

    if [ -e "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
        local -i pid; let pid=$(:tunnel:stop "${hcs}")
        let e=$?
        theme HAS_AUTOED $e ${pid}
    else
        let e=CODE_SUCCESS
        theme HAS_WARNED "NOT_RUNNING"
    fi

    return $e
}
#. }=-
#. tunnel:create -={
function :tunnel:create() {
    local -i e; let e=CODE_FAILURE
    core:raise_bad_fn_call_unless $# ge 5

    local laddr="${1}"
    local -i lport; let lport=$2
    local raddr="$3"
    local rport; let rport=$4
    local -a hcss=( "${@:5}" )
    #. TODO/FIXME
    #. first hcs gets -f, but all may as well have it
    #. last hcs gets -N only
    #. all get -L
    if [ -S "${SIMBOL_USER_SSH_CONTROLPATH?}" ]; then
        if ! :net:localportping ${lport}; then
            local -a cmd
            local hcsn
            for ((i=0; i<${#hcss[@]}; i++)); do
                hcsn="${hcss[i]}"
                if [ 0 -eq $((${#hcss[@]}-1)) ]; then
                    cmd+=( "ssh ${g_SSH_OPTS[*]} -fNL" )
                elif [ $i -eq 0 ]; then
                    cmd+=( "ssh ${g_SSH_OPTS[*]} -fL" )
                elif [ $i -eq $((${#hcss[@]}-1)) ]; then
                    cmd+=( "ssh -NL" )
                else
                    cmd+=( "ssh -fL" )
                fi
                cmd+=( "${laddr}:${lport}:${raddr}:${rport} ${hcsn}" )
            done
            echo "${cmd[@]}"
            eval '${cmd[@]}'
            let e=$?
        else
            let e=CODE_E01
        fi
    else
        let e=CODE_E02
    fi

    return $e
}

function tunnel:create:shflags() {
    cat <<!
string local  localhost "local-addr"  l
string remote localhost "remote-addr" r
!
}
function tunnel:create:usage() {
    echo "[-l|--local-addr <local-addr>] <local-port> [-r|--remote-addr <remote-addr>] <remote-port> <hcs> [<hcs> [...]]";
}
function tunnel:create() {
    local -i e; let e=CODE_DEFAULT
    [ $# -ge 3 ] || return $e

    local raddr=${FLAGS_remote:-localhost}; unset FLAGS_remote
    local laddr=${FLAGS_local:-localhost};  unset FLAGS_local

    local -i lport; let lport=$1
    local -i rport; let rport=$2
    local -a hcss=( "${@:3}" )
    local pid
    pid=$(:tunnel:pid)
    e=$?
    #if [ ${e} -eq ${CODE_SUCCESS?} -a ${#pid} -gt 0 ]; then
    #    if :tunnel:start ${hcs} ${port}; then
    #        pid=$(:tunnel:pid ${hcs} ${port})
    #        e=$?
    #    fi
    #fi

    cpf "Creating ssh tunnel %{@host:${hcs}} ["
    if (( e == CODE_SUCCESS )) && [ ${#pid} -gt 0 ]; then
        cpf "%{@ip:${laddr?}}:%{@int:${lport}}"
        cpf "%{r:<--->}"
        cpf "%{@ip:${raddr?}}:%{@int:${rport}}"
        cpf "] ..."
        :tunnel:create "${laddr}" ${lport} "${raddr}" ${rport} "${hcss[@]}"
        let e=$?
        if (( e != CODE_E01 )); then
            theme HAS_AUTOED $e
        else
            theme HAS_FAILED "${lport}:PORT_USED"
        fi
    else
        cpf "!!!] ..."
        theme HAS_FAILED
    fi

    return $e
}
#. }=-
#. }=-
