# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
The simbol remote access/execution module (ssh, ssh/sudo, tmux, etc.)
[core:docstring]

#. Remote Execution/Monitoring -={
core:import dns
core:import hgd
core:import util

core:requires ssh
core:requires tmux
core:requires socat
core:requires netstat

#.  :remote:sshproxy*() DEPRECATED -={
#function :remote:sshproxystr() {
#    core:raise EXCEPTION_DEPRECATED
#
#    local -i e=${CODE_FAILURE?}
#
#    if [ $# -eq 1 ]; then
#        local tldid=$1
#        local sshproxystr="${USER_SSH_PROXY[${tldid}]}"
#        #. If the given tldid didn't checkout, try the wildcard tldid `_' - that
#        #. is if it exists:
#        if [ -z "${sshproxystr}" -a "${tldid}" != '_' ]; then
#            sshproxystr="${USER_SSH_PROXY[_]}"
#        fi
#
#        if [ -n "${sshproxystr}" ]; then
#            e=${CODE_SUCCESS?}
#
#            echo "${sshproxystr}"
#        fi
#    else
#        core:raise EXCEPTION_BAD_FN_CALL
#    fi
#
#    return $e
#}

#function :remote:sshproxycmd() {
#    core:raise EXCEPTION_DEPRECATED
#
#    local -i e=${CODE_FAILURE?}
#
#    if [ $# -eq 1 ]; then
#        local ssh_proxy_cmd
#
#        local tldid=$1
#
#        local sshproxystr
#        sshproxystr=$(:remote:sshproxystr ${tldid})
#        if [ $? -eq ${CODE_SUCCESS?} ]; then
#            local ssh_proxy
#            if [ "${sshproxystr//[^:]/}" == ':' ]; then
#                local -i ssh_port
#                IFS=: read ssh_proxy ssh_port <<< "${sshproxystr}"
#                #ssh_proxy_cmd="ssh -p ${ssh_port} ${USER_USERNAME?}@${ssh_proxy} nc %h 22"
#                ssh_proxy_cmd="/usr/bin/ssh -p ${ssh_port} ${USER_USERNAME?}@${ssh_proxy} -W %h:%p"
#                e=${CODE_SUCCESS?}
#            elif [ -z "${sshproxystr//[^:]/}" ]; then
#                ssh_proxy=${sshproxystr}
#                #ssh_proxy_cmd="ssh ${USER_USERNAME?}@${ssh_proxy} nc %h 22"
#                ssh_proxy_cmd="/usr/bin/ssh ${USER_USERNAME?}@${ssh_proxy} -W %h:%p"
#                e=${CODE_SUCCESS?}
#            else
#                core:log ERR "Invalid proxy string (${sshproxystr})!"
#                e=${CODE_FAILURE?}
#            fi
#        fi
#
#        [ -z "${ssh_proxy_cmd}" ] || echo "${ssh_proxy_cmd}"
#    else
#        core:raise EXCEPTION_BAD_FN_CALL
#    fi
#
#    return ${e}
#}

#function :remote:sshproxyopts() {
#    core:raise EXCEPTION_DEPRECATED
#
#    local -i e=${CODE_FAILURE?}
#
#    if [ $# -eq 1 ]; then
#        local ssh_options
#
#        local tldid=$1
#
#        local sshproxystr
#        sshproxystr=$(:remote:sshproxystr ${tldid})
#        if [ $? -eq ${CODE_SUCCESS?} ]; then
#            local ssh_proxy_cmd
#            if [ "${sshproxystr//[^:]/}" == ':' -o -z "${sshproxystr//[^:]/}" ]; then
#                ssh_proxy_cmd=$(:remote:sshproxycmd ${tldid})
#                ssh_options="-o Ciphers=arcfour -o ProxyCommand='${ssh_proxy_cmd}'"
#                e=${CODE_SUCCESS?}
#            else
#                core:log ERR "Invalid proxy string (${sshproxystr})!"
#                e=${CODE_FAILURE?}
#            fi
#        fi
#
#        [ -z "${ssh_options}" ] || echo "${ssh_options}"
#    else
#        core:raise EXCEPTION_BAD_FN_CALL
#    fi
#
#    return ${e}
#}
#. }=-

#.   remote:connect() -={
function :remote:connect() {
    local -i e=${CODE_FAILURE?}

    if [ $# -ge 2 ]; then
        local tldid="$1"
        local hcs="$2"

        local ssh_options
        if [ $# -eq 2 ]; then
            #. User wants to ssh into a shell
            ssh_options="${g_SSH_OPTS?} -ttt"
        elif [ $# -ge 3 ]; then
            if [ "$3" == "sudo" ]; then
                #. User wants to ssh and execute a command via sudo
                ssh_options="${g_SSH_OPTS?} -T"
            else
                #. User wants to ssh and execute a command
                ssh_options="${g_SSH_OPTS?} -T"
            fi
        else
            #. User is confused, and so we will follow.
            core:raise EXCEPTION_BAD_FN_CALL
        fi
#       #. DEPRECATED
#       ssh_options+=" $(:remote:sshproxyopts ${tldid})"

        export TERM=vt100
        eval "ssh ${ssh_options} ${hcs} ${*:3}"
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function remote:connect:shflags() {
    cat <<!
boolean resolve   false  "resolve-first"  r
!
}
function remote:connect:usage() { echo "[<username>@]<hnh> [<cmd> [<args> [...]]]"; }
function remote:connect() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 1 ]; then
        local tldid=${g_TLDID?}

        local username=
        [ "${1//[^@]/}" != '@' ] || username="${1//@*}"

        local hnh=${1##*@}
        local -i resolve=${FLAGS_resolve:-0}; ((resolve=~resolve+2)); unset FLAGS_resolve
        [ "${hnh: -1}" != '.' ] || resolve=0

        local hcs qdn qt hnh_ qual tldid_ usdn dn fqdn resolved qid
        [ ! -t 1 ] || cpf "Resolving %{@host:%s} in %{@tldid:%s}..." "${hnh}" "${tldid}"
        if [ ${resolve} -eq 1 ]; then
            local -a data=( $(:dns:lookup.csv ${tldid} a ${hnh}) )

            if [ ${#data[@]} -eq 1 ]; then
                IFS=, read qt hnh_ qual tldid_ usdn dn fqdn resolved qid <<< "${data[0]}"
                [ ! -t 1 ] || theme HAS_PASSED "${fqdn}/${resolved}"

                qdn="${fqdn%.${dn}}"
                [ ! -t 1 ] || cpf "Connecting to %{@host:%s}.%{@tldid:%s}...\n"\
                    "${qdn}" "${tldid}"

                hcs=${fqdn}
            elif [ ${#data[@]} -gt 1 ]; then
                [ ! -t 1 ] || theme ERR "Too many matches to the <hnh> \`${hnh}'"
                e=${CODE_FAILURE?}
            else
                [ ! -t 1 ] || theme ERR "Failed to resolve any host matching \`${hnh}'"
                e=${CODE_FAILURE?}
            fi
        else
            hcs=${hnh}
            [ ! -t 1 ] || theme HAS_WARNED "SKIPPED/${hcs}"
        fi

        if [ $e -ne ${CODE_FAILURE?} ]; then
#           #. DEPRECATED
#           local sshproxystr=$(:remote:sshproxystr ${tldid})
#           if [ $? -eq ${CODE_SUCCESS?} ]; then
#               #. If bouncing, use the FQDN as we don't know if the remote host
#               #. will resolve like out local simbol host:
#               local hcs=${fqdn}
#           fi

            [ ${#username} -eq 0 ] || hcs=${username}@${hcs}
            if [ $# -eq 1 ]; then
                :remote:connect ${tldid} ${hcs}
                e=$?
            else
                :remote:connect ${tldid} ${hcs} "${@:2}"
                e=$?
                if [ $e -eq 255 ]; then
                    [ ! -t 1 ] || theme HAS_FAILED "Failed to connect to \`${hcs}'"
                elif [ $e -ne ${CODE_SUCCESS?} ]; then
                    [ ! -t 1 ] || theme HAS_WARNED "Connection terminated with error code \`$e'"
                fi
            fi
        fi
    fi

    return $e
}
#. }=-
#.   remote:copy() -={
function remote:copy:usage() { echo "-T<tldid> [[<user>@]<dst-hnh>:]<src-path> [[<user>@]<dst-hnh>:]<dst-path>"; }
function remote:copy() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}
    local -A data
    if [ $# -eq 2 ]; then
        e=${CODE_SUCCESS?}

        local hs=src
        local -a uri

        for hstr in "$@"; do
            if [[ ${hstr} =~ ^(([^@]+@)?[^:]+:)?[^:@]*$ ]]; then
                IFS=':@' read -a uri <<< "${hstr}"

                data[mode_${hs}]=3
                [ ${#uri[@]} -ge 1 ] && data[pth_${hs}]="${uri[-1]}" || ((data[mode_${hs}]--))
                [ ${#uri[@]} -ge 2 ] && data[hnh_${hs}]="${uri[-2]}" || ((data[mode_${hs}]--))
                [ ${#uri[@]} -eq 3 ] && data[un_${hs}]="${uri[-3]}"  || ((data[mode_${hs}]--))

                #. If a hostname is at all specified...
                local hnh="${data[hnh_${hs}]}"
                if [ ${#hnh} -gt 0 ]; then
                    [ ! -t 1 ] || cpf "Resolving %{@host:%s} in %{@tldid:%s}..." "${hnh}" "${tldid}"

                    local -a hdata=( $(:dns:lookup.csv ${tldid} a ${hnh}) )
                    if [ ${#hdata[@]} -eq 1 ]; then
                        local qt hnh_ qual tldid_ usdn dn fqdn resolved qid
                        IFS=, read qt hnh_ qual tldid_ usdn dn fqdn resolved qid <<< "${hdata[0]}"

                        data[qdn_${hs}]=${fqdn%.${dn}}
                        data[fqdn_${hs}]=${fqdn}
                        [ ! -t 1 ] || theme HAS_PASSED "${data[qdn_${hs}]}"
                    else
                        [ ! -t 1 ] || theme HAS_FAILED
                        e=${CODE_FAILURE?}
                    fi
                fi

                case ${data[mode_${hs}]} in
                    1) data[cmd_${hs}]="${data[pth_${hs}]}";;
                    2) data[cmd_${hs}]="${data[fqdn_${hs}]}:${data[pth_${hs}]}";;
                    3) data[cmd_${hs}]="${data[un_${hs}]}@${data[fqdn_${hs}]}:${data[pth_${hs}]}";;
               esac
            else
                e=${CODE_DEFAULT?}
            fi
            hs=dst
        done

        local ssh_options="${g_SSH_OPTS?}"

        [ ! -t 1 ] || cpf "Copying from %{@path:%s} to %{@path:%s} [MODE:%{@int:%s}:%{@int:%s}]..."\
            "${data[cmd_src]}" "${data[cmd_dst]}" ${data[mode_src]} ${data[mode_dst]}

        case ${data[mode_src]}:${data[mode_dst]} in
            1:1)
                cp -a "${data[pth_src]}" "${data[pth_dst]}"
                e=$?
            ;;
            [23]:1|1:[23])
                eval "rsync -ae 'ssh ${ssh_options}' ${data[cmd_src]} ${data[cmd_dst]}"
                e=$?
            ;;
            *:*)
                local tmp="${SIMBOL_USER_TMP?}/remote-copy.$$.tmp/${data[pth_src]}"
                rm -rf ${tmp}
                mkdir -p $(dirname ${tmp})
                eval "rsync -ae 'ssh ${ssh_options}' ${data[cmd_src]} ${tmp}"
                [ $? -ne 0 ] || eval "rsync -ae 'ssh ${ssh_options}' ${tmp} ${data[cmd_dst]}"
                e=$?
                rm -rf ${tmp}
            ;;
        esac
        theme HAS_AUTOED $e

        e=$?
    fi

    return $e
}
#. }=-
#.   remote:sudo() -={
function ::remote:pipewrap() {
    #. This function acts mostly as a transparent pipe; data in -> data out.
    #.
    #. There is just once case where it intervenes, and that is when it is used
    #. with `sudo -S', and at this point, it will insert a <password>.
    #.
    #. After initially inserting the password, it simply copies input from the
    #. terminal and sends it to the ssh process directly.
    #.
    #. Credits: https://code.google.com/p/sshsudo/
    local passwd="${1}"
    local lckfile="${2}"

    printf '%s\n' "${passwd}"

    #. The function will exit when output pipe is closed,
    while [ -e ${lckfile} ]; do
        # i.e., the ssh process
        read -t 1 line
        [ $? -ne 0 ] || echo "${line}"
    done
}

function :remote:sudo() {
    local -i e=${CODE_FAILURE?}

    core:import vault

    if [ $# -ge 3 ]; then
        local tldid="$1"
        local hcs="$2"

        local sudo_opts=
        local lckfile=$(mktemp)

        local passwd
        passwd="$(:vault:read SUDO)"
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            local prompt="$(printf "\r")"
            eval ::remote:pipewrap '${passwd}' '${lckfile}' | (
                :remote:connect ${tldid} ${hcs} sudo -p "${prompt}" -S "${@:3}"
                e=$?
                rm -f ${lckfile}
                exit $e
            )
            e=$?
        else
            :remote:connect ${tldid} ${hcs} sudo -S "${@:3}"
            e=$?
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function remote:sudo:usage() { echo "-T|--tldid <hnh> <cmd>"; }
function remote:sudo() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 2 ]; then
        local -r hnh="$1"
        local -r tldid="${g_TLDID?}"
        [ ! -t 1 ] || cpf "Resolving %{@host:%s} in %{@tldid:%s}..." "${hnh}" "${tldid}"

        local -a data
        data=( $(:dns:lookup.csv ${tldid} a ${hnh}) )

        local qt hnh_ qual tldid_ usdn dn fqdn resolved qid
        if [ ${#data[@]} -eq 1 ]; then
            IFS=, read qt hnh_ qual tldid_ usdn dn fqdn resolved qid <<< "${data[0]}"
            [ ! -t 1 ] || theme HAS_PASSED "${fqdn}"

            local hcs=${fqdn}
#           #. DEPRECATED
#           local sshproxystr=$(:remote:sshproxystr ${tldid})
#           if [ $? -eq ${CODE_SUCCESS?} ]; then
#               #. If bouncing, use the FQDN as we don't know if the remote host
#               #. will resolve like out local simbol host:
#               local hcs=${fqdn}
#           fi

            [ ! -t 1 ] || theme INFO "SUDOing \`${*:2}'"
            :remote:sudo ${tldid} ${hcs} "${@:2}"
        else
            [ ! -t 1 ] || theme HAS_FAILED "${hnh}"
        fi
        e=$?
    fi

    return $e
}
#. }=-
#.   remote:tmux() -={
function remote:cluster:alert() {
    cat <<!
DEPR This function has been deprecated in favour of tmux.
!
}
function remote:cluster:usage() { echo "<hnh> [<hnh> [...]]"; }
function remote:cluster() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}

    if [ $# -eq 1 ]; then
        local hgd=$1
        local -a hosts
        hosts=( $(hgd:resolve ${tldid} ${hgd}) )
        if [ $? -eq 0 -a ${#hosts[@]} -gt 0 ]; then
            cssh ${hosts[@]}
        else
            theme ERR_USAGE "That <hgd> did not resolve to any hosts."
            e=${CODE_FAILURE?}
        fi
    elif [ $# -gt 1 ]; then
        local -a qdns
        local hnh
        for hnh in $@; do
            qdns=( ${qdns[@]} $(:dns:get qdn ${tldid} ${hnh}) )
        done
        cssh ${qdns[@]}
        e=$?
    fi

    return $e
}

function ::remote:tmux.eval() {
    if [ $# -eq 3 ]; then
        local session=$1
        echo "#. session ${session}"

        local -i panes=$2
        echo "#. ${panes} panes in total"

        local pane_res=$3
        IFS=x read x y <<< "${pane_res}"
        echo "#. window pane resolution set to ${x}x${y}"

        local -i ppw
        ((ppw=x*y))
        echo "#. ${ppw} panes per window"

        local -i leftovers
        ((leftovers=panes%ppw))

        local -i windows
        ((windows=panes/ppw))

        if [ ${leftovers} -gt 0 ]; then
            ((windows++))
            echo "#. last-window has ${leftovers} panes"
        fi
        echo "#. ${windows} windows"

        echo "#. session creation"
        echo tmux new-session -d -s ${session}

        echo "#. window creation"
        wid=0
        wname=${session}:w${wid}
        echo tmux rename-window -t ${session} ${session}:w0
        for ((wid=1; wid<${WINDOWS?}; wid++)); do
            wname=${session}:w${wid}
            echo tmux new-window -t ${session} -d -a -n ${wname}
        done

        echo "#. pane creation"
        wid=0
        wname=${session}:w${wid}
        for ((pid=0; pid<PANES; pid++)); do
            if ((pid%PPW == 0)); then
                if ((pid>0)); then
                    echo "tmux select-layout -t ${session}:${wname} tiled >/dev/null"
                    wname=${session}:w$((pid/PPW))
                    echo "tmux select-window -t ${session}:${wname} #. Pane $pid, Window ${wname}"
                else
                    echo "#. Pane $pid, Window ${wname}"
                fi
            elif ((pid%X == 0)); then
                echo "tmux split-window -h #. Pane $pid, Row $(((pid / X) % Y))"
                echo "tmux select-layout -t ${session}:${wname} tiled >/dev/null"
            else
                echo "tmux split-window -v #. Pane $pid"
            fi
        done

        echo "#. view preparation and session connection"
        wid=0
        wname=${session}:w${wid}
        echo "tmux select-window -t ${session}:${wname}"
        echo tmux select-pane -t ${session}:${wname}.0
        echo tmux attach-session -t ${session}

        echo "#. cleanup"
        echo tmux kill-session -t tmux
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi
}

function ::remote:tmux() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 3 ]; then
        local tldid=$1
        local session=$2
        local hgd=$3

        local -a hosts=( $(:hgd:resolve ${tldid} ${hgd}) )
        if [ ${#hosts[@]} -gt 0 ]; then
            local cmd="tmux new-session -d -s '${session}'"
            eval ${cmd}
            if [ $? -eq 0 ]; then
                local tab
                local -i pid
                local -i lpid
                local -i tid
                local -i otid
                local -i nodes=${#hosts[@]}

                local -i zoning=12 #. Terminals per tab (tmux window)
                for ((pid=0; pid<nodes; pid++)); do
                    ((lpid=pid%zoning))
                    ((tid=pid/zoning))
                    tab="tab-${tid}"
                    if [ ${pid} -gt 0 ]; then
                        if [ ${otid} -ne ${tid} ]; then
                            tmux new-window -t "${session}" -a -n "${tab}"
                            tmux select-window -t "${session}:${tab}"
                        fi
                    else
                        tmux rename-window -t "${session}" "${tab}"
                        tmux select-window -t "${session}:${tab}"
                    fi
                    ((otid=tid))

                    [ ${lpid} -eq 0 ] || tmux split-window -h
                    cpf "Connection %{g:${tab}}:%{@int:${pid}} to %{@host:${hosts[${pid}]}}..."
                    #if [[ ${hosts[${pid}]} =~ /
                    tmux send-keys -t "${lpid}" "SIMBOL_USER_SSH_CONF=${SIMBOL_USER_SSH_CONF} SIRCA_ENV=${SIRCA_ENV} simbol remote connect '${hosts[${pid}]}'" C-m
                    #tmux send-keys -t "${lpid}" "${SIMBOL_CORE_BIN?}/ssh ${hosts[${pid}]}" C-m
                    #XXX tmux send-keys -t "${lpid}" "ss${tldid} ${hosts[${pid}]}" C-m
                    tmux select-layout -t "${session}:${tab}" tiled >/dev/null
                    theme HAS_PASSED "${tab}:${pid}"
                done

                for tid in $(tmux list-windows -t ${session}|awk -F: '{print$1}'); do
                    tab="tab-${tid}"
                    tmux select-window -t "${session}:${tid}"
                    tmux set synchronize-panes on >/dev/null
                    tmux select-pane   -t "${session}:${tab}.0"
                done

                tid=0
                pid=0
                tab="tab-${tid}"
                tmux select-window -t "${session}:${tab}"
                tmux select-pane   -t "${session}:${tab}.0"

                tmux attach-session -t "${session}"
                [ $? -ne 0 ] || e=${CODE_SUCCESS?}
            else
                core:log WARN "Empty HGD resolution"
            fi
        else
            core:log ERR "Failed to execute cmd \`${cmd}'"
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function remote:tmux:help() {
    cat <<!
    To create a new <tmux-session>, both arguments become mandatory:

        <tmux-session> <hgd:@+>

    Once the <tmux-session> is created however, you can simply connect
    to it without specifying the second argument:

        <tmux-session>

    Finally, you can also opt to use the last form described above if
    you'd like to reference an already created <hgd> session, that
    is the equivalent of specifying two argument with exactly the same
    value.
!
}
function remote:tmux:usage() { echo "<tmux-session> [<hgd:@+>]"; }
function remote:tmux() {
    local -i e=${CODE_DEFAULT?}

    core:requires tmux

    local tldid=${g_TLDID?}
    local session=$1
    local hgd=${2:-${session}}

    if [ $# -eq 1 ]; then
        tmux attach-session -t "${session}" 2>/dev/null
        e=$?
        if [ $e -ne 0 ]; then
            if :hgd:list ${hgd} >/dev/null; then
                ::remote:tmux "${tldid}" "${hgd}" "${hgd}"
                e=$?
            else
                theme ERR_USAGE "There is no hgd or tmux session by that name."
            fi
        fi
    elif [ $# -eq 2 ]; then
        if ! tmux has-session -t "${session}" 2>/dev/null; then
            ::remote:tmux "${tldid}" "${session}" "${hgd}"
            e=$?
        else
            theme ERR_USAGE "That session already exists."
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#.   remote:mon() -={
#. Deprecated Mon Serial Execution
function ::remote:serialmon() {
    local -i e=${CODE_FAILURE?}

    if [ $# -ge 2 ]; then
        local tldid=${g_TLDID?}
        local -a qdns=( $(:hgd:resolve ${tldid} $1) )
        local -r rcmd=${@:2}

        if [ ${#rcmd} -gt 0 ]; then
            local qdn info postcmd
            for qdn in ${qdns[@]}; do
                info="$(:remote:connect ${tldid} ${qdn} ${rcmd}|tr -d '\r\n'; exit ${PIPESTATUS[0]})"
                if [ $? -eq ${CODE_SUCCESS?} ]; then
                    e=${CODE_SUCCESS?}
                    echo "${info}"
                fi
            done
        else
            core:raise EXCEPTION_BAD_FN_CALL
        fi
    fi

    return $e
}

function remote:mon:shflags() {
    cat <<!
integer timeout   8     "timeout"      t
integer threads   32    "threads"      h
integer attempts  3     "attempts"     a
boolean sudo      false "run-as-root"  s
!
}
function remote:mon:usage() { echo "<hgd:*> @$(echo ${!USER_MON_CMDGRPREMOTE[@]}|sed -e 's+ +|@+g') | <arbitrary-command>"; }
function remote:mon() {
    local -i e=${CODE_DEFAULT?}

    #core:requires PYTHON futures
    #core:requires PYTHON paramiko

    core:requires RUBY gpgme
    core:requires RUBY parallel
    core:requires RUBY net-ssh
    core:requires RUBY net-ssh-multi
    core:requires RUBY net-ssh-gateway

    if [ $# -ge 2 ]; then
        local -i timeout=${FLAGS_timeout:-8}; unset FLAGS_timeout
        local -i threads=${FLAGS_threads:-32}; unset FLAGS_threads
        local -i attempts=${FLAGS_attempts:-3}; unset FLAGS_attempts
        local -i sudo=${FLAGS_sudo:-0}; ((sudo=~sudo+2)); unset FLAGS_sudo

        local -r hgd="$1"
        local tldid=${g_TLDID?}

        local rcmd lcmd
        if [ ${2:0:1} == '@' ]; then
            rcmd="${USER_MON_CMDGRPREMOTE[${2:1}]}"
            lcmd="${USER_MON_CMDGRPLOCAL[${2:1}]}"
        else
            shift 1
            rcmd=${@}
        fi

        if [ ${#rcmd} -gt 0 ]; then
            e=${CODE_FAILURE?}

            cpf "Processing..."
            local qdn ip
            local -a qdns
            qdns=( $(:hgd:resolve ${tldid} ${hgd}) )
            e=$?
            if [ $e -eq 0 ]; then
                cpf "(%{@int:${#qdns[@]}} hosts (max-threads=%{@int:%s})" ${threads}

                if [ ${#qdns[@]} -gt ${threads} ]; then
                    cpf "; this could take some time"
                fi
                cpf ")...\n"

                local line
                local csv_hosts=$(:util:join ',' qdns)

                if [ ${threads} -gt 1 ]; then
                    local script=

                    ::xplm:loadvirtenv rb
                    script="${SIMBOL_CORE_LIBEXEC?}/ssh.rb ${threads} 1 ${timeout} mod_hgd=${csv_hosts} ${rcmd}"
                    #echo "#. DEBUG: ${script}" >&2

#                   local sshproxystr=$(:remote:sshproxystr ${tldid})
#                   local ssh_proxy_host=${sshproxystr%:*}
#                   local ssh_proxy_port=22
#                   [ "${sshproxystr//[^:]/}" != ':' ] || ssh_proxy_port=${sshproxystr#*:}
#                   local data="$(
#                       SSH_PROXY_HOST=${ssh_proxy_host}\
#                       SSH_PROXY_PORT=${ssh_proxy_port}\
#                       TLD=${USER_TLDS[${tldid}]} ${script}
#                   )"

                    local sid
                    [ ${sudo} -eq 0 ] || sid=SUDO
                    local data="$(SUDO=${sid} TLD=${USER_TLDS[${tldid}]} ${script})"
                    eval "${data}"

                    local qdn
                    for qdn in ${qdns[@]}; do
                        cpf "%{@host:%-32s}" ${qdn}

                        sha1=$(echo -ne "${qdn}"|sha1sum|awk '{print$1}')
                        local err=${mod_hgd[${sha1}]}
                        if [ ${#err} -gt 0 ]; then
                            if [ ${err} -eq 0 ]; then
                                if [ -n "${mod_hgd_w[${sha1}]}" ]; then
                                    theme HAS_WARNED "${mod_hgd_o[${sha1}]}"
                                else
                                    local info="${mod_hgd_o[${sha1}]}"
                                    if [ ${#lcmd} -gt 0 ]; then
                                        local postcmd
                                        postcmd=$(printf "${lcmd}" "${info}");
                                        info="$(${postcmd}; exit ${PIPESTATUS[0]})"
                                        e=$?
                                    fi
                                    theme HAS_PASSED "${info}"
                                fi
                            else
                                local chan
                                local emsg="exit:${err}"

                                chan="${mod_hgd_e[${sha1}]}"
                                [ -z "${chan}" ] || emsg+=" / stderr(${chan})"

                                chan="${mod_hgd_o[${sha1}]}"
                                [ -z "${chan}" ] || emsg+=" / stdout(${chan})"

                                theme HAS_FAILED "${emsg}"
                            fi
                        else
                            theme HAS_WARNED "NO_DATA"
                        fi
                    done

                    e=$?
                elif [ ${threads} -eq 1 ]; then
                    local rcmd lcmd
                    if [ ${2:0:1} == '/' ]; then
                        rcmd="${USER_MON_CMDGRPREMOTE[${2:1}]}"
                        lcmd="${USER_MON_CMDGRPLOCAL[${2:1}]}"
                    else
                        rcmd=${@:2}
                    fi

                    if [ ${#rcmd} -gt 0 ]; then
                        e=${CODE_SUCCESS?}
                        cpf "(%{@int:${#qdns[@]}} hosts"
                        for qdn in ${qdns[@]}; do
                            cpf "%{@host:%-32s}" ${qdn}
                            read record context query sdn ip <<< "$(:dns:lookup P a ${qdn})"
                            if [ $? -eq 0 ]; then
                                cpf "%{@ip:%-32s}" ${ip}
                                socat -t1 -T1 -u TCP:${ip}:22,connect-timeout=1 STDOUT >/dev/null 2>&1
                                e=$?
                                if [ $e -eq 0 ]; then
                                    info=$(::remote:serialmon ${qdn} ${rcmd}; exit ${PIPESTATUS[0]})
                                    if [ $? -eq 0 ]; then
                                        if [ ${#lcmd} -gt 0 ]; then
                                            local postcmd
                                            postcmd=$(printf "${lcmd}" "${info}");
                                            info="$(${postcmd}; exit ${PIPESTATUS[0]})"
                                            e=$?
                                        fi
                                        theme HAS_PASSED "${info}"
                                        e=${CODE_SUCCESS?}
                                    else
                                        e=${CODE_FAILURE?}
                                        theme HAS_FAILED "EXIT CODE:$e"
                                    fi
                                else
                                    e=${CODE_FAILURE?}
                                    theme HAS_FAILED "SSH_DOWN"
                                fi
                            else
                                e=${CODE_FAILURE?}
                                theme HAS_FAILED "NO_A_RECORD"
                            fi
                        done
                    fi
                fi
            else
                theme HAS_FAILED "NO_SUCH_HGD"
            fi
        fi
    fi

    return $e
}
#. }=-
#. }=-
