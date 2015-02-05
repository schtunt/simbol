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

#. tunnel:sockpath -={
SIMBOL_USER_SSH_CONTROLPATH="simbol-ssh-mux@prd.proxy.sock"
function :tunnel:sockpath() {
    local -i e=${CODE_FAILURE?}
    local sockpath

    if [ $# -eq 1 ]; then
        if [ "$1" == '-' ]; then
            sockpath=${SIMBOL_USER_RUN?}/${SIMBOL_USER_SSH_CONTROLPATH?}
        else
            sockpath=${SIMBOL_USER_RUN?}/${1}
        fi
    elif [ $# -eq 0 ]; then
        sockpath=${SIMBOL_USER_RUN?}/${SIMBOL_USER_SSH_CONTROLPATH?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    [ ! -S "${sockpath}" ] || e=${CODE_SUCCESS?}

    echo ${sockpath}

    return $e
}
#. }=-
#. tunnel:status -={
function :tunnel:pid() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -r sock="${1}"

        local sockpath
        sockpath="$(:tunnel:sockpath ${sock})"
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            local raw
            raw=$(
                ssh ${g_SSH_OPTS} -no 'ControlMaster=no'\
                    -S "${sockpath}" -O check NULL 2>&1 |
                    tr -d '\r\n'
            )
            e=$?

            if [ $e -eq 0 ]; then
                echo "${raw}" |
                    sed -e 's/Master running (pid=\(.*\))$/\1/'
            fi
        else
            echo 0
            e=${CODE_SUCCESS?} #. No tunnel
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function tunnel:status:shflags() {
    cat <<!
string sock ${SIMBOL_USER_SSH_CONTROLPATH?} "ssh-controlpath-socket" s
!
}
function tunnel:status:usage() { echo "[-s|--sock <ssh-controlpath-socket>]"; }
function tunnel:status() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 ]; then
        local sock=${FLAGS_sock:--}; unset FLAGS_sock
        local sockpath=$(:tunnel:sockpath ${sock})
        cpf "Checking ssh control master for %{@path:%s}..." "$(basename ${sockpath})"

        local -i pid
        pid=$(:tunnel:pid ${sock})
        if [ ${pid} -gt 0 ]; then
            theme HAS_PASSED ${pid}

            local line
            while read line; do
                IFS='[: ]' read lh1 lport lh2 rport rhost <<< "${line}"
                cpf " - Tunnel from %{@int:${lport}} to %{@host:${rhost}}:%{@int:${rport}}\n"
            done < <(
                ps -fC ssh |
                    awk '$0~/ssh\.conf/{print$0}' |
                    grep -oE 'localhost:[^ ]+ .*'
            )

            local hnh
            local -i port
            while read line; do
                IFS=: read hnh port <<< "${line}"
                cpf " + Discovered tunnel %{@host:%s}:%{@int:%s}\n" ${hnh} ${port}
            done < <(
                lsof -p ${pid} -a -i4 -iTCP -sTCP:LISTEN -Fn |
                    sed -ne 's/^n//p'
            )
            #netstat -ltnpAinet 2>/dev/null

            e=${CODE_SUCCESS?}
        else
            theme HAS_FAILED "NO_TUNNEL"
            e=${CODE_FAILURE?}
        fi
    fi

}
#. }=-
#. tunnel:start -={
#. FIXME why does $(:tunnel:start) hang?
function :tunnel:start() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 3 ]; then
        local -i pid
        local -r sock="${1}"
        local -r hcs="${2}"
        local -ir port="${3}"

        local sockpath
        sockpath="$(:tunnel:sockpath ${sock})"
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            pid=$(:tunnel:pid ${sock})
            [ ${pid} -eq 0 ] || e=${CODE_E01?}
        else
            if ssh ${g_SSH_OPTS} -n -fNS "${sockpath}" -p ${port} ${USER_USERNAME}@${hcs}; then
                pid=$(:tunnel:pid ${sock})
                [ ${pid} -eq 0 ] || e=${CODE_E01?}
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function tunnel:start:shflags() {
    cat <<!
string hcs  prd.proxy "ssh-controlpath-host"   h
string sock ${SIMBOL_USER_SSH_CONTROLPATH?} "ssh-controlpath-socket" s
!
}
function tunnel:start:usage() { echo "[-s|--sock <ssh-controlpath-socket>] [-h|--host <hcs>] [<port:22>]"; }
function tunnel:start() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -le 1 ]; then
        local -r sock="${FLAGS_sock:--}"; unset FLAGS_sock
        local -r hcs=${FLAGS_hcs:-prd.proxy}; unset FLAGS_hcs

        local -ri port=${1:-22}

        cpf "Starting ssh control master to %{@host:${hcs}}..."
        local -i pid

        local sockpath
        sockpath="$(:tunnel:sockpath ${sock})"
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            e=${CODE_SUCCESS?}
            pid=$(:tunnel:pid ${sock})
            theme HAS_WARNED "ALREADY_RUNNING:${pid}"
        else
            :tunnel:start ${sock} ${hcs} ${port}
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                pid=$(:tunnel:pid ${sock})
                [ ${pid} -ne 0 ] || e=${CODE_E01?}
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

    if [ $# -eq 2 ]; then
        local -i pid=0
        local -r sock="${1}"
        local -r hcs="${2}"

        local sockpath
        sockpath="$(:tunnel:sockpath ${sock})"
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            pid=$(:tunnel:pid ${sock})
            if [ ${pid} -gt 0 ]; then
                ssh ${g_SSH_OPTS} -no 'ControlMaster=no'\
                    -S "${sockpath}" -O stop NULL >/dev/null 2>&1
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

function tunnel:stop:shflags() {
    cat <<!
string sock ${SIMBOL_USER_SSH_CONTROLPATH?} "ssh-controlpath-socket" s
!
}
function tunnel:stop:usage() { echo "[-s|--sock <ssh-controlpath-socket>] <hcs>"; }
function tunnel:stop() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 ]; then
        local -r sock="${FLAGS_sock:--}"; unset FLAGS_hcs

        cpf "Stopping ssh control master to %{@path:${sock}}..."

        local sockpath
        sockpath="$(:tunnel:sockpath ${sock})"
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            local -i pid
            pid=$(:tunnel:stop "${sock}" "${hcs}")
            if [ ${pid} -eq 0  ]; then
                theme HAS_PASSED
                e=${CODE_SUCCESS?}
            else
                theme HAS_FAILED "${pid}"
                e=${CODE_FAILURE?}
            fi
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

    if [ $# -ge 5 ]; then
        local sock="${1}"

        local laddr="${2}"
        local lport="${3}"
        local raddr="${4}"
        local rport="${5}"

        local -a hcss=( "${@:6}" )
        #. TODO/FIXME
        #. first hcs gets -f, but all may as well have it
        #. last hcs gets -N only
        #. all get -L

        local sockpath
        sockpath="$(:tunnel:sockpath ${sock})"
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            if ! :net:localportping ${lport}; then
                local -i first=0
                local -i last=${#hcss[@]}
                local -a cmd
                local hcsn
                for ((i=0; i<${#hcss[@]}; i++)); do
                    hcsn="${hcss[i]}"
                    if [ ${#hcss[@]} -eq 1 ]; then
                        cmd+=( "ssh ${g_SSH_OPTS} -fNL" )
                    elif [ $i -eq 0 ]; then
                        cmd+=( "ssh ${g_SSH_OPTS} -fL" )
                    elif [ $i -eq $((${#hcss[@]}-1)) ]; then
                        cmd+=( "ssh -NL" )
                    else
                        cmd+=( "ssh -fL" )
                    fi
                    cmd+=( "${laddr}:${lport}:${raddr}:${rport} ${hcsn}" )
                done
                #echo "${cmd[@]}"
                eval '${cmd[@]}'
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
string sock ${SIMBOL_USER_SSH_CONTROLPATH?} "ssh-controlpath-socket" s
string local  localhost "local-addr"  l
string remote localhost "remote-addr" r
!
}
function tunnel:create:usage() {
    echo "[-s|--sock <ssh-controlpath-socket>] [-l|--local-addr <local-addr>] <local-port> [-r|--remote-addr <remote-addr>] <remote-port> <hcs> [<hcs> [...]]";
}
function tunnel:create() {
    local -i e=${CODE_DEFAULT?}

    local raddr=${FLAGS_remote:-localhost}; unset FLAGS_remote
    local laddr=${FLAGS_local:-localhost};  unset FLAGS_local
    local sock=${FLAGS_sock:--}; unset FLAGS_sock
    local sockpath=$(:tunnel:sockpath ${sock})

    if [ $# -ge 3 ]; then
        local -i lport=${1}
        local -i rport=${2}
        local -a hcss=( "${@:3}" )
        local pid
        pid=$(:tunnel:pid ${sock})
        e=$?
        #if [ ${e} -eq ${CODE_SUCCESS?} -a ${#pid} -gt 0 ]; then
        #    if :tunnel:start ${hcs} ${port}; then
        #        pid=$(:tunnel:pid ${hcs} ${port})
        #        e=$?
        #    fi
        #fi

        cpf "Creating ssh tunnel %{@host:${hcs}} ["
        if [ ${e} -eq ${CODE_SUCCESS?} -a ${#pid} -gt 0 ]; then
            cpf "%{@ip:${laddr?}}:%{@int:${lport}}"
            cpf "%{r:<--->}"
            cpf "%{@ip:${raddr?}}:%{@int:${rport}}"
            cpf "]..."
            :tunnel:create ${sock} ${laddr} ${lport} ${raddr} ${rport} ${hcss[@]}
            e=$?
            if [ $e -ne ${CODE_E01?} ]; then
                theme HAS_AUTOED $e
            else
                theme HAS_FAILED "${lport}:PORT_USED"
            fi
        else
            cpf "!!!] ..."
            theme HAS_FAILED
        fi
    fi

    return $e
}
#. }=-
#. }=-
