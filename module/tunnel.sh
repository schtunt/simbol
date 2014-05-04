# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
SSH Tunnelling
[core:docstring]

#. Tunneling Module -={
core:import dns
core:import net
core:import util

core:requires ssh
core:requires netstat

: ${SIMBOL_USER_SSH_CONTROLPATH:=${SIMBOL_USER_RUN?}/simbol-ssh-mux.sock}

#. tunnel:status -={
function :tunnel:pid() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 0 ]; then
        if [ -e "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
            local raw
            raw=$(
                ssh ${g_SSH_OPTS} -o 'ControlMaster=no'\
                    -S "${SIMBOL_USER_SSH_CONTROLPATH}" -O check NULL 2>&1 |
                    tr -d '\r\n'
            )
            e=$?

            if [ $e -eq 0 ]; then
                echo "${raw}" |
                    sed -e 's/Master running (pid=\(.*\))$/\1/'
            fi
        else
            e=${CODE_SUCCESS?} #. No tunnel
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function tunnel:status() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 ]; then
        cpf "Checking ssh control master..."

        local pid
        pid=$(:tunnel:pid)
        e=$?

        if [ $e -eq ${CODE_SUCCESS?} ]; then
            theme HAS_AUTOED $e "${pid:-NO_TUNNEL}"

            while read line; do
                IFS='[: ]' read lh1 lport lh2 rport rhost <<< "${line}"
                cpf "Tunnel from %{@int:${lport}} to %{@host:${rhost}}:%{@int:${rport}}\n"
            done < <(
                ps -fC ssh |
                    awk '$0~/ssh\.conf/{print$0}' |
                    grep -oE 'localhost:[^ ]+ .*'
            )
        fi
    fi

    return $e
}
#. }=-
#. tunnel:start -={
#. XXX do not $(:tunnel:start) - it hangs !?!?!
function :tunnel:start() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local -i pid
        local -r hcs=${1}
        local -ir port=${2}
        if [ -S "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
            pid=$(:tunnel:pid ${hcs})
            [ $? -ne ${CODE_SUCCESS?} ] || e=${CODE_E01?}
        else
            if ssh ${g_SSH_OPTS} -n -fNS "${SIMBOL_USER_SSH_CONTROLPATH}" -p ${port} ${USER_USERNAME}@${hcs}; then
                pid=$(:tunnel:pid ${hcs})
                e=$?
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function tunnel:start:usage() { echo "<hcs> [<port:22>]"; }
function tunnel:start() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local -r hcs=${1}
        local -ri port=${2:-22}
        cpf "Starting ssh control master to %{@host:${hcs}}..."
        local -i pid
        if [ -S "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
            pid=$(:tunnel:pid ${hcs})
            e=${CODE_SUCCESS?}
            theme HAS_WARNED "ALREADY_RUNNING:${pid}"
        else
            if :tunnel:start ${hcs} ${port}; then
                pid=$(:tunnel:pid ${hcs})
                e=$?
            fi
            theme HAS_AUTOED $e ${pid}
        fi
    fi

    return $e
}
#. }=-
#. tunnel:stop -={
function :tunnel:stop() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -i pid=0
        local -r hcs="${1}"
        if [ -e "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
            pid=$(:tunnel:pid ${hcs})
            if [ $? -eq ${CODE_SUCCESS?} ]; then
                ssh ${g_SSH_OPTS} -no 'ControlMaster=no'\
                    -fNS "${SIMBOL_USER_SSH_CONTROLPATH}" ${hcs} -O stop >/dev/null 2>&1
                e=$?
            fi
        else
            e=${CODE_FAILURE?}
        fi
        echo ${pid}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function tunnel:stop:usage() { echo "<hcs>"; }
function tunnel:stop() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local -r hcs="${1}"
        cpf "Stopping ssh control master to %{@host:${hcs}}..."

        if [ -e "${SIMBOL_USER_SSH_CONTROLPATH}" ]; then
            local -i pid
            pid=$(:tunnel:stop "${hcs}")
            e=$?
            theme HAS_AUTOED $e ${pid}
        else
            e=${CODE_SUCCESS?}
            theme HAS_WARNED "NOT_RUNNING"
        fi
    fi

    return $e
}
#. }=-
#. tunnel:create -={
function :tunnel:create() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 5 ]; then
        local hcs="${1}"
        local laddr="${2}"
        local lport="${3}"
        local raddr="${4}"
        local rport="${5}"
        if [ -S ${SIMBOL_USER_SSH_CONTROLPATH} ]; then
            if ! :net:localportping ${lport}; then
                ssh ${g_SSH_OPTS} -fNL "${laddr}:${lport}:${raddr}:${rport}" ${hcs}
                e=$?
            else
                e=${CODE_E01?}
            fi
        else
            e=${CODE_E02?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
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
    echo "<hcs> [-l|--local-addr <local-addr>] <local-port> [-r|--remote-addr <remote-addr>] <remote-port> [<port>]";
}
function tunnel:create() {
    local -i e=${CODE_DEFAULT?}

    local raddr=${FLAGS_remote:-localhost}; unset FLAGS_remote
    local laddr=${FLAGS_local:-localhost};  unset FLAGS_local

    if [ $# -eq 3 -o $# -eq 4 ]; then
        local -r hcs=${1}
        local -i lport=${2}
        local -i rport=${3}
        local -i port=${4:-22}
        local pid
        pid=$(:tunnel:pid ${hcs})
        e=$?
        if [ $e -eq ${CODE_SUCCESS?} -a ${#pid} -eq 0 ]; then
            if :tunnel:start ${hcs} ${port}; then
                pid=$(:tunnel:pid ${hcs} ${port})
                e=$?
            fi
        fi

        cpf "Creating ssh tunnel %{@host:${hcs}} ["
        if [ ${e} -eq ${CODE_SUCCESS?} -a ${#pid} -gt 0 ]; then
            cpf "%{@ip:${laddr?}}:%{@int:${lport}}"
            cpf "%{r:<--->}"
            cpf "%{@ip:${raddr?}}:%{@int:${rport}}"
            cpf "] ..."
            :tunnel:create ${hcs} ${laddr} ${lport} ${raddr} ${rport}
            e=$?
            if [ $e -ne ${CODE_E01?} ]; then
                theme HAS_AUTOED $e
            else
                theme HAS_FAILED "${lport}:PORT_USED"
            fi
        else
            theme HAS_FAILED
        fi
    fi

    return $e
}
#. }=-
#. }=-
