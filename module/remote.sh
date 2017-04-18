# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
The simbol remote access/execution module (ssh, ssh/sudo, tmux, etc.)
[core:docstring]

#. Remote Execution/Monitoring -={
core:import hgd
core:import util

core:requires ssh
core:requires tmux
core:requires socat
core:requires netstat

#.   remote:connect:passwordless -={
function :remote:connect:passwordless() {
    # Verify if we can connect to box with a certain connection string
    local -i e=${CODE_SUCCESS?}
    local extra_SSH_OPTS="-o PasswordAuthentication=no -o StrictHostKeyChecking=no"
    local hcs="$1"

    local rv
    rv=$(ssh ${g_SSH_OPTS?} ${extra_SSH_OPTS} ${hcs} -- echo -n "${NOW}" 2> /dev/null)
    [ $? -eq ${CODE_SUCCESS?} -a "${rv}" = "${NOW}" ] || e=${CODE_FAILURE?}

    return $e
}
#. }=-
#.   remote:connect() -={
function :remote:connect() {
    local -i e=${CODE_FAILURE?}

    if [ $# -ge 2 ]; then
        local tldid="$1"
        local hcs="$2"

        local ssh_options="${g_SSH_OPTS?}"
        if [ $# -eq 2 ]; then
            #. User wants to ssh into a shell
            ssh_options+=" -ttt"
        elif [ $# -ge 3 ]; then
            if [ "$3" == "sudo" ]; then
                #. User wants to ssh and execute a command via sudo
                ssh_options+=" -T"
            else
                #. User wants to ssh and execute a command
                ssh_options+=" -T"
            fi
        else
            #. User is confused, and so we will follow.
            core:raise EXCEPTION_BAD_FN_CALL
        fi

        export TERM=vt100
        ssh ${ssh_options} "${hcs}" "${@:3}"
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

        local hcs="${1##*@}"
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

    return $e
}
#. }=-
#.   remote:copy() -={
function remote:copy:usage() { echo "-T<tldid> [[<user>@]<dst-hnh>:]<src-path> [[<user>@]<dst-hnh>:]<dst-path>"; }
function remote:copy() {
    local -i e=${CODE_DEFAULT?}
    [ $# -eq 2 ] || return $e

    local tldid=${g_TLDID?}
    local -A data
    e=${CODE_SUCCESS?}

    local hs=src
    local -a uri

    for hstr in "$@"; do
        if [[ ${hstr} =~ ^(([^@]+@)?[^:]+:)?[^:@]*$ ]]; then
            IFS=':@' read -a uri <<< "${hstr}"

            ((data[mode_${hs}] = ${#uri[@]}))
            case ${data[mode_${hs}]} in
                1)
                    data[pth_${hs}]="${uri[0]}"
                ;;
                2)
                    data[hn_${hs}]="${uri[0]}"
                    data[pth_${hs}]="${uri[1]}"
                ;;
                3)
                    data[un_${hs}]="${uri[0]}"
                    data[hn_${hs}]="${uri[1]}"
                    data[pth_${hs}]="${uri[2]}"
                ;;
            esac
        else
            e=${CODE_DEFAULT?}
        fi

        case ${data[mode_${hs}]} in
            1) data[cmd_${hs}]="${data[pth_${hs}]}";;
            2) data[cmd_${hs}]="${data[hn_${hs}]}:${data[pth_${hs}]}";;
            3) data[cmd_${hs}]="${data[un_${hs}]}@${data[hn_${hs}]}:${data[pth_${hs}]}";;
        esac

        hs=dst
    done

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        local ssh_options="${g_SSH_OPTS?}"

        [ ! -t 1 ] || cpf "Copying from %{@path:%s} to %{@path:%s} [MODE:%{@int:%s}:%{@int:%s}]..."\
            "${data[cmd_src]}" "${data[cmd_dst]}" ${data[mode_src]} ${data[mode_dst]}

        case ${data[mode_src]}:${data[mode_dst]} in
            1:1)
                cp -a "${data[pth_src]}" "${data[pth_dst]}"
                e=$?
            ;;
            [23]:1|1:[23])
                eval "rsync -ae 'ssh ${ssh_options}' '${data[cmd_src]}' '${data[cmd_dst]}'"
                e=$?
            ;;
            *:*)
                local tmp="${SIMBOL_USER_VAR_TMP?}/remote-copy.$$.tmp/${data[pth_src]}"
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
function ::remote:pipewrap.eval() {
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
            eval ::remote:pipewrap.eval '${passwd}' '${lckfile}' | (
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
        local -r hcs="$1"
        local -r tldid="${g_TLDID?}"

        [ ! -t 1 ] || theme INFO "SUDOing \`${*:2}'"
        :remote:sudo ${tldid} ${hcs} "${@:2}"
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
        cssh "$@"
        e=$?
    fi

    return $e
}

function ::remote:tmux_setup.eval() {
    if [ $# -eq 3 ]; then
        local session=$1
        echo "#. Session ${session} -={"

        local -i panes=$2
        echo "#. + ${panes} panes in total"

        local -i ppw=$3
        echo "#. + ${ppw} panes per window"

        local -i leftovers
        ((leftovers=panes%ppw))

        local -i windows
        ((windows=panes/ppw))

        if [ ${leftovers} -gt 0 ]; then
            ((windows++))
            echo "#.   + last-window has ${leftovers} panes"
        fi
        echo "#. + ${windows} windows"
        echo "#. }=-"

        echo "#. Session Creation"
        echo "tmux new-session -d -s ${session}"

        echo "#. Window Creation"
        local -i wid=1
        local wname=${session}:w${wid}
        echo "tmux rename-window -t ${session} ${wname}"
        for ((wid=2; wid<windows+1; wid++)); do
            wname=${session}:w${wid}
            echo "tmux new-window -d -n ${wname}"
        done

        echo "#. pane creation"
        for ((pid=0; pid<panes; pid++)); do
            if ((pid % ppw == 0)); then
                wname=${session}:w$((pid/ppw+1))
                echo "tmux select-layout -t ${session}:${wname} tiled >/dev/null"
                echo "tmux select-window -t ${session}:${wname} #. Pane $pid, Window ${wname}"
            else
                echo "tmux split-window #. Pane $pid"
                echo "tmux select-layout -t ${session}:${wname} tiled >/dev/null"
            fi
        done

        echo "#. View Preparation and Session Connection"
        wid=1
        wname=${session}:w${wid}
        echo "tmux select-window -t ${session}:${wname}"
        echo "tmux select-pane -t ${session}:${wname}.0"
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi
}

function ::remote:tmux_attach() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local session=$1

        local -a windows=(
            $(tmux list-windows -a -t ${session}| awk -F': ' '{print$1}')
        )

        local wid
        for wid in $(tmux list-windows -t ${session}|awk -F: '{print$1}'|sort -r); do
            tmux select-window -t "${wid}"
            tmux select-pane   -t "${wid}.0"
            tmux set synchronize-panes on >/dev/null
        done

        tmux attach-session -t ${session}
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function ::remote:tmux() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 3 ]; then
        local tldid=$1
        local session=$2
        local hgd=$3

        local -a hosts=( $(:hgd:resolve ${tldid} ${hgd}) )
        if [ ${#hosts[@]} -gt 0 ]; then
            eval "$(::remote:tmux_setup.eval ${session} ${#hosts[@]} 12)"

            local -a panes=(
                $(tmux list-panes -t ${session} -a | awk -F': ' '{print$1}')
            )

            local -A data
            eval data=$(:util:zip.eval hosts panes)

            local missconnects=${SIMBOL_USER_VAR_TMP?}/${session}.missconnects
            > ${missconnects}

            local host pane
            local -i pid=1
            for host in "${hosts[@]}"; do
                pane="${data[${host}]}"

                cpf "Connection %{g:${pane}}:%{@int:${pid}} to %{@host:${host}}..."
                tmux send-keys -t "${pane}" "  clear" C-m
                tmux send-keys -t "${pane}" "  simbol remote connect '${host}' || ( tput setab 1; clear; echo ${host} >> ${missconnects};echo 'ERROR: Could not connect to ${host}'; read -n1 ); exit" C-m
                theme HAS_PASSED "${pane}:${pid}"

                ((pid++))
            done

            ::remote:tmux_attach ${session}
            [ $? -ne 0 ] || e=${CODE_SUCCESS?}

            [ -s ${missconnects} ] || rm -f ${missconnects}
            if [ -e ${missconnects} ]; then
                cpf "%{r:ERROR}: Failed to connect to the following hosts...\n"
                while read host; do
                    cpf " ! %{@host:%s}\n" "${host}"
                done < ${missconnects}
            fi

            tmux kill-session -t ${session}
        else
            core:log WARN "Empty HGD resolution"
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

declare -g -A STATES
#. TODO: move this to util -={
LOCKDIR="/tmp/lock.%d.sct"
function lock() {
    local action="${1}"
    local lid=${2:-0}
    local lockdir="$(printf "${LOCKDIR}" ${lid})"
    case ${action} in
        on)
            while ! mkdir "${lockdir}" &>/dev/null; do
                sleep 0.1
            done
        ;;
        off)
            rmdir "${lockdir}"
        ;;
    esac
}
#. }=-

#. ::remote:thread:cleanup() -={
function ::remote:thread:cleanup() {
    local -i e=${CODE_SUCCESS?}

    rm -f "/tmp/${USER}.sct"
    [ $? -eq ${CODE_SUCCESS?} ] || e=${CODE_FAILURE?}

    rm -rf "/tmp/lock.*.sct"
    [ $? -eq ${CODE_SUCCESS?} ] || e=${CODE_FAILURE?}

    return $e
}
#. }=-
#. ::remote:thread:setup() -={
function ::remote:thread:setup() {
    local -i e

    ::remote:thread:cleanup
    e=$?

    exec 3>/tmp/${USER}.sct
    exec 4</tmp/${USER}.sct

    return $e
}
#. }=-
#. ::remote:thread:teardown() -={
function ::remote:thread:teardown() {
    local -i e=${CODE_FAILURE?}

    exec 3>&-
    exec 4>&-

    ::remote:thread:cleanup
    e=$?

    return $e
}
#. }=-

#. ::remote:ssh_thread.ipc() -={
function ::remote:ssh_thread.ipc() {
    # ::remote:ssh_thread.ipc                    | ::remote:mon.ipc
    #                                            |
    #                _____ [5<stdin]___/dev/null |
    #               /                            |
    #             [.....]                        |
    #             [.....]                        |
    #             [.....]                        |
    #               \ \___ [6>stdout>7]___       |
    #                \____ [8>stderr>9]__ \      |
    #                                    \ \     |
    #                                     \_\__ [3>user>4]___*
    #                                            |

    local -i e=-1

    local -i retries=$1
    local -i timeout=$2
    local hcs="$3"

    local -a argv
    if [ "$4" != '--' ]; then
        argv=( "${@:4}" )
    else
        argv=( "${@:5}" )
    fi

    #. Maybe we want to read data one day, for now it's /dev/null
    local stdin="/dev/null"
    exec 5<"${stdin}"

    #. Create a process-local read (7) and write (6) stdout file descriptor and
    #. associated buffer file
    local stdout="/tmp/stdout.${BASHPID}.sct"
    exec 6>"${stdout}"
    exec 7<"${stdout}"

    #. Create a process-local read (9) and write (8) stderr file descriptor and
    #. associated buffer file
    local stderr="/tmp/stderr.${BASHPID}.sct"
    exec 8>"${stderr}"
    exec 9<"${stderr}"

    #. Execute the command, reading stdin from file descriptor 5, writing stdout
    #. to file descriptor 6, and writing stderr to file descriptor 8
    local -i tries=0
    while ((tries < retries)); do
        ((tries++))
        core:log DEBUG "Remote execution launched; attempt ${tries} of ${retries}; timeout of ${timeout}s"
        case ${hcs} in
            localhost|127.*)
                eval -- "${argv[@]}" <&5 1>&6 2>&8
                e=$?
            ;;
            *)
                ssh -xTTT ${g_SSH_OPTS?}\
                    -o ConnectionAttempts=${retries}\
                    -o ConnectTimeout=${timeout}\
                    -o PasswordAuthentication=no\
                    -o PreferredAuthentications=publickey\
                    -o StrictHostKeyChecking=no\
                    -o BatchMode=yes\
                    -o UserKnownHostsFile=/dev/null\
                        "${hcs}" -- "${argv[@]}" <&5 1>&6 2>&8
                e=$?
            ;;
        esac
        [ $e -ne 0 ] || break
        sleep 1.${RANDOM}
    done

    #. Close all write file descriptors
    exec 6>&-
    exec 8>&-

    #. IPC/write -={
    #. Get the mutex and write all data as null-terminated tokens in the
    #. order of: <hcs>, <exit-code>, <stdout>, <stderr>; note that the latter
    #. two can be 0 or more lines.
    lock on
    printf "%s\0" "${hcs}"   >&3 #. hcs
    cat <&7 >&3; printf "\0" >&3 #. stdout
    cat <&9 >&3; printf "\0" >&3 #. stderr
    printf "%d\0" ${e}       >&3 #. ee
    printf "%s=%d;"\
        "tries" ${tries}\
                             >&3 #. metadata
    printf "\0"              >&3 #. metadata
    lock off
    #. }=-

    #. Close all read file descriptors
    exec 5>&-
    exec 7>&-
    exec 9>&-

    #. Remove all buffer files
    rm -f ${stdout}
    rm -f ${stderr}

    return $e
}
#. }=-
#. ::remote:mon.ipc() -={
function ::remote:mon.ipc() {
    local -i e=${CODE_FAILURE?}

    local -i threads=$1
    local -i retries=$2
    local -i timeout=$3

    local delim="$4"

    local -a hcss
    IFS=, read -a hcss <<< "$5"

    local -a argv=( "${@:6}" )

    local -i ee
    local -i incomplete=1
    local -i success=0
    local -i failure=0
    local -i total=0

    local -i hcsi=0
    local -i active
    local state

    core:log DEBUG "Seting up the thread-pool"
    ::remote:thread:setup

    local hcs stdout stderr ee metadata_raw
    while [ ${incomplete} -eq 1 ]; do
        active=0
        for state in "${STATES[@]}"; do
            if [ "${state}" == "PENDING" ]; then
                ((active++))
            fi
        done

        while [ ${active} -lt ${threads} -a ${hcsi} -lt ${#hcss[@]} ]; do
            hcs=${hcss[${hcsi}]}
            core:log DEBUG "Launching remote execution on ${hcs}"
            ((hcsi++))

            STATES[${hcs}]='PENDING'
            ( ::remote:ssh_thread.ipc ${retries} ${timeout} "${hcs}" "${argv[@]}" )&

            ((active++))
            core:log DEBUG "Active thread-count at ${active} (of ${threads})"
        done

        if [ ${active} -gt 0 ]; then
            ee=-9
            core:log DEBUG "Reading from thread IPC"
            #. IPC/read -={
            while ! read -u 4 -d $'\0' hcs; do sleep 0.1; done
            while ! read -u 4 -d $'\0' stdout; do sleep 0.1; done
            while ! read -u 4 -d $'\0' stderr; do sleep 0.1; done
            while ! read -u 4 -d $'\0' ee; do sleep 0.1; done
            while ! read -u 4 -d $'\0' metadata_raw; do sleep 0.1; done
            #. }=-
            core:log DEBUG "Creating payload for view layer"

            printf "%s${delim}%s${delim}%s\n" xc "${hcs}" "${ee}"

            local -a payload
            while read line; do
                payload=( so "${hcs}" "${line}" )
                :util:join ${delim} payload
                echo
            done <<< "${stdout}"

            while read line; do
                payload=( se "${hcs}" "${line}" )
                :util:join ${delim} payload
                echo
            done <<< "${stderr}"

            IFS=';' read -a metadata <<< "${metadata_raw}"
            for line in "${metadata[@]}"; do
                payload=( md "${hcs}" "${line}" )
                :util:join ${delim} payload
                echo
            done

            STATES[${hcs}]=$ee
            if [ $ee -eq 0 ]; then
                ((success++))
                ((total++))
            else
                ((failure++))
                ((total++))
                e=1
            fi
        else
            core:log DEBUG "Work complete"
            incomplete=0
        fi
    done

    core:log DEBUG "Tearing down the thread-pool"
    ::remote:thread:teardown

    core:log INFO "Successfully complete ${success} of ${total} threads"
    [ ${failure} -eq 0 ] || core:log ERR "Failures in ${failure} threads"

    return $e
}
#. }=-
#.   remote:mon() -={
function remote:mon:shflags() {
    cat <<!
integer timeout   8           "timeout"      t
integer threads   8           "threads"      h
integer retries   3           "retries"      a
string  output    so,se,xc    "output"       o
!
#boolean sudo      false       "run-as-root"  s
}
function remote:mon:usage() {
    printf "[-h|--threads <threads>] [-o so,se,xc] <hgd:*> "
    printf "@%s|" "${!USER_MON_CMDGRPREMOTE[@]}"
    printf -- "-- <arbitrary-command>\n"
}
function remote:mon() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 2 ]; then
        local -i timeout=${FLAGS_timeout:-8}; unset FLAGS_timeout
        local -i threads=${FLAGS_threads:-32}; unset FLAGS_threads
        local -i retries=${FLAGS_retries:-3}; unset FLAGS_retries
        local -i sudo=${FLAGS_sudo:-0}; ((sudo=~sudo+2)); unset FLAGS_sudo

        #. so:stdout, se:stdout, xc:exit-code, md:metadata
        local output_raw="${FLAGS_output:-so,se,xc}"; unset FLAGS_output

        #. Validate user parameters -={
        e=${CODE_SUCCESS?}

        [ ${threads} -gt 0 ] || e=${CODE_DEFAULT?}

        local -A output=( [so]=0 [se]=0 [xc]=0 [md]=0 )

        if [ ${g_VERBOSE?} -eq 1 ]; then
            output[so]=1
            output[se]=1
            output[xc]=1
            output[md]=1
        else
            local token
            local -a tokens
            IFS=, read -a tokens <<< "${output_raw}"
            for token in ${tokens[@]}; do
                case ${token} in
                    so) output[so]=1 ;;
                    se) output[se]=1 ;;
                    xc) output[xc]=1 ;;
                    md) output[md]=1 ;;
                esac
            done
        fi
        #. }=-

        if [ $e -eq ${CODE_SUCCESS?} ]; then
            local -r hgd="$1"
            local tldid=${g_TLDID?}

            local -a rcmd
            local lcmd
            if [ ${2:0:1} == '@' ]; then
                rcmd=( "${USER_MON_CMDGRPREMOTE[${2:1}]}" )
                lcmd="${USER_MON_CMDGRPLOCAL[${2:1}]}"
            else
                shift 1
                rcmd=( "${@}" )
            fi

            if [ ${#rcmd[0]} -gt 0 ]; then
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

                    if [ ${g_VERBOSE?} -eq 1 ]; then
                        echo "#. Hosts:      ${#qdns[@]}"
                        echo "#. Threads:    ${threads}"
                        echo "#. Remote Cmd: ${rcmd[*]}"
                        echo "#.   Attempts: ${retries}"
                        echo "#.   Timeout:  ${timeout}"
                        echo "#. Local Cmd:  ${lcmd:-Undefined}"
                    fi

                    local delim='|'
                    local line
                    local otype
                    local hcs
                    local payload
                    while read line; do
                        IFS="${delim}" read otype hcs payload <<< "${line}"
                        case ${otype}:${output[${otype}]}:${#payload} in
                            xc:1:[1-9]*)
                                case ${payload} in
                                    0)
                                        cpf "%{g:%8s}%{@host:%-48s}: "\
                                            "excode" "${hcs}"
                                        theme HAS_AUTOED ${payload}
                                    ;;
                                    *)
                                        cpf "%{r:%8s}%{@host:%-48s}: "\
                                            "excode" "${hcs}"
                                        theme HAS_AUTOED ${payload}
                                    ;;
                                esac
                            ;;
                            so:1:[1-9]*)
                                cpf "%{c:%8s}%{@host:%-48s}: %s\n"\
                                    "stdout" "${hcs}" "${payload}"
                            ;;
                            se:1:[1-9]*)
                                cpf "%{r:%8s}%{@host:%-48s}: %s\n"\
                                    "stderr" "${hcs}" "${payload}"
                            ;;
                            md:1:[1-9]*)
                                cpf "%{m:%8s}%{@host:%-48s}: %s\n"\
                                    "metadata" "${hcs}" "${payload}"
                            ;;
                            so:0:*|so:1:0|se:0:*|se:1:0|md:0:*|xc:0:*)
                                : pass
                            ;;
                            *:*:*)
                                theme HAS_FAILED "Can't stomach \`${otype}:${output[${otype}]}:${#payload}'"
                                core:raise EXCEPTION_SHOULD_NOT_GET_HERE
                            ;;
                        esac
                    done < <(::remote:mon.ipc\
                        ${threads} ${retries} ${timeout}\
                        "${delim}" "${csv_hosts}" "${rcmd[@]}"
                    )
                else
                    theme HAS_FAILED "NO_SUCH_HGD"
                fi
            fi
        fi
    fi

    return $e
}
#. }=-
#. }=-
