# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import remote

#. Remote -={
function remoteOneTimeSetUp() {
    declare -g g_SSH_MOCK="${SIMBOL_USER_VAR_TMP?}/ssh.honeypot"
    declare -g g_TMUX_MOCK="${SIMBOL_USER_VAR_TMP?}/tmux.honeypot"
}

function remoteSetUp() {
    mock:write <<-!MOCK
        export USER_VAULT_PASSPHRASE=ItsASecret

        function dig() {
            $(which dig) -p 5353 @localhost "\$@"
            return \$?
        }

        function cp() {
            cat <<-!SCP >> "${g_SSH_MOCK?}.cp"
                \$@
			!SCP
			return \$?
        }

        function rsync() {
            cat <<-!SCP >> "${g_SSH_MOCK?}.rsync"
                \$@
			!SCP
			return \$?
        }

        function read_stdin() {
            local -i e=0

            local stdin
            while [ \$e -eq 0 ]; do
                IFS= read -t0.1 -r stdin
                e=\$?
                printf -- "%s\n" "\${stdin}"
            done

            return \$e
        }

        function ssh() {
            local -i e

            printf -- "#. time: %s\n" "\$(date +%s.%N)" >> "${g_SSH_MOCK?}.ssh"
            printf -- "ssh %s\n" "\$*" >> "${g_SSH_MOCK?}.ssh"

            if [[ "\$*" =~ .+\\.mockery\\.net ]]; then
                printf -- "#. %s\n" "Mockery WILL Mock" >> "${g_SSH_MOCK?}.ssh"
                printf -- "#. %s\n" "Mockery matched on domain 'mockery.net'" >> "${g_SSH_MOCK?}.ssh"

                #. read stdin, but doing nothing with it for now
                local stdin
                stdin="\$(read_stdin)"

                shift 1
                local arg
                for arg in "\$@"; do
                    [[ "\$1" =~ .*\\.mockery\\.net ]] && break || shift
                done;
                shift 1

                [ \$# -ne 0 ] || return 0
                [ "\$1" != '--' ] || shift 1
                [ \$# -ne 0 ] || return 1

                if [ \$# -gt 0 ]; then
                    [ "\$1" != '--' ] || shift

                    local cmd
                    if [ "\$1" != 'sudo' ]; then
                        cmd="\${*}"
                    else
                        # Remove "sudo -S"
                        cmd="\${*:3}"
                    fi
                    printf -- "#. Mockery will execute '%s' locally instead\n" "\${cmd}" >> "${g_SSH_MOCK?}.ssh"
                    eval "\${cmd}"
                    e=\$?
                else
                    printf -- "#. Mockery will fake connection instead\n" >> "${g_SSH_MOCK?}.ssh"
                    e=\$?
                fi
            else
                printf -- "#. %s\n" "Mockery WILL NOT Mock" >> "${g_SSH_MOCK?}.ssh"
                printf -- "#. %s\n" "Mockery did not match on domain 'mockery.net'" >> "${g_SSH_MOCK?}.ssh"
                \$(which ssh) "\$@"
                e=\$?
            fi

            return \$e
        }
	!MOCK
}

function remoteTearDown() {
    rm -f "${g_SSH_MOCK?}".*
    mock:clear
}

function remoteOneTimeTearDown() {
    rm -f "${g_SSH_MOCK?}".*
}

#. Execution (ssh)
#. testCoreRemoteConnectPasswordlessInternal -={
function testCoreRemoteConnectPasswordlessInternal() {
    local hn="batman.mockery.net"

    truncate -s0 "${g_SSH_MOCK?}.ssh"
    mock:wrapper remote :connect:passwordless ${hn} >"${stdoutF?}" 2>"${stderrF?}"

    grep -qFw -- 'batman.mockery.net' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qFw -- 'PasswordAuthentication=no' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qFw -- 'StrictHostKeyChecking=no' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.3" $?

    grep -qFw -- "${NOW?}" "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.4" $?
}
#. }=-
#. testCoreRemoteConnectInternal -={
function testCoreRemoteConnectInternal() {
    local hn="batman.mockery.net"

    truncate -s0 "${g_SSH_MOCK?}.ssh"
    mock:wrapper remote :connect ${hn} >"${stdoutF?}" 2>"${stderrF?}"

    grep -qFw -- 'batman.mockery.net' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qFw -- '-ttt' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.1" $?
    grep -qFw -- '-T' "${g_SSH_MOCK?}.ssh"
    assertFalse "${FUNCNAME?}/1.2.2" $?
}
#. }=-
#. testCoreRemoteConnectPublic -={
function testCoreRemoteConnectPublic() {
    local hn="batman.mockery.net"

    truncate -s0 "${g_SSH_MOCK?}.ssh"
    mock:wrapper remote connect ${hn} >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    grep -qFw -- 'batman.mockery.net' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qFw -- '-ttt' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.1" $?
    grep -qFw -- '-T' "${g_SSH_MOCK?}.ssh"
    assertFalse "${FUNCNAME?}/1.2.2" $?
}
#. }=-
#. testCoreRemoteConnectPublicAndRunCommand -={
function testCoreRemoteConnectPublicAndRunCommand() {
    local hn="joker.mockery.net"

    truncate -s0 "${g_SSH_MOCK?}.ssh"
    mock:wrapper remote connect ${hn} -- printf "%s\n" 0xdeadbeef >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    grep -qFw -- 'joker.mockery.net' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qFw -- '-ttt' "${g_SSH_MOCK?}.ssh"
    assertFalse "${FUNCNAME?}/1.2.1" $?
    grep -qFw -- '-T' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.2" $?

    grep -qFw -- '0xdeadbeef' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.3" $?

    #. the double-dash should have been removed by public function
    grep -qFw -- '--' "${g_SSH_MOCK?}.ssh"
    assertFalse "${FUNCNAME?}/1.4" $?
}
#. }=-
#. testCoreRemoteSudoInternal -={
function testCoreRemoteSudoInternal() {
    local hn="batman.mockery.net"

    truncate -s0 "${g_SSH_MOCK?}.ssh"
    local who
    who=$(mock:wrapper remote :sudo ${hn} whoami)
    assertTrue "${FUNCNAME?}/1" $?

    assertEquals "${FUNCNAME?}/1.1" "$(whoami)" "${who}"

    local -i cmds
    let cmds=$(grep -cvE '^#\. ' "${g_SSH_MOCK?}.ssh")
    assertEquals "${FUNCNAME?}/1.2.1" 1 "${cmds}"

    grep -qFw -- "-E ${SIMBOL_USER_VAR_LOG?}/ssh.log" "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.2" $?

    grep -qFw -- '-T' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.3" $?

    grep -qF -- '-S whoami' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.3.4" $?

    grep -qFw -- "${hn}" "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.4.5" $?
}
#. }=-
#. testCoreRemoteSudoPublic -={
function testCoreRemoteSudoPublic() {
    local hn="batman.mockery.net"

    local who
    truncate -s0 "${g_SSH_MOCK?}.ssh"
    who="$(mock:wrapper remote sudo "${hn}" whoami)"
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/1.1" "$(whoami)" "${who}"

    local -i cmds
    let cmds=$(grep -cvE '^#\. ' < "${g_SSH_MOCK?}.ssh")
    assertEquals "${FUNCNAME?}/1.2.1" 1 ${cmds}

    grep -qFw -- "-E ${SIMBOL_USER_VAR_LOG}/ssh.log" "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.2" $?

    grep -qFw -- '-T' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.3" $?

    grep -qF -- '-S whoami' "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.4" $?

    grep -qFw -- "${hn}" "${g_SSH_MOCK?}.ssh"
    assertTrue "${FUNCNAME?}/1.2.5" $?
}
#. }=-

#. TMUX
#. testCoreRemoteTmuxPublic -={
function testCoreRemoteTmuxPublic() {
    mock:write <<-!MOCK
        function tmux() { printf -- "%s\n" "\$*"; }
        function cpf() { :; }
	!MOCK

    mock:wrapper remote tmux '|(#10.0.0.0/29)' >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreRemoteTmuxPrivate -={
function testCoreRemoteTmuxPrivate() {
    truncate -s0 "${g_TMUX_MOCK?}"
    mock:write <<-!MOCK
        function tmux() {
            printf -- "%s\n" "\$*" >> "${g_TMUX_MOCK?}"
            case \$1 in
                list-panes)
                    local pane
                    for pane in {1..6}; do
                        echo \$pane
                    done
                ;;
            esac
        }
        function cpf() { :; }
	!MOCK

    mock:wrapper remote ::tmux s '|(#10.0.0.0/29)' >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    local -i count
    let count=$(grep -cE '10\.0\.0\.' "${g_TMUX_MOCK?}")
    assertEquals "${FUNCNAME?}/1.1" 6 ${count}

    let count=$(grep -cFw 'new-session' "${g_TMUX_MOCK?}")
    assertEquals "${FUNCNAME?}/1.2" 1 ${count}

    let count=$(grep -cFw 'attach-session' "${g_TMUX_MOCK?}")
    assertEquals "${FUNCNAME?}/1.3" 1 ${count}

    let count=$(grep -cFw 'kill-session' "${g_TMUX_MOCK?}")
    assertEquals "${FUNCNAME?}/1.4" 1 ${count}
}
#. }=-
#. testCoreRemoteTmux_attachPrivate -={
function testCoreRemoteTmux_attachPrivate() {
    mock:write <<-!MOCK
        function tmux() { printf -- "%s\n" "\$*"; }
        function cpf() { :; }
	!MOCK

    local session="foobar"
    mock:wrapper remote ::tmux_attach "${session}" >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    grep -qF -- "select-window -t ${session}" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qF -- "select-pane -t ${session}.0" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qF -- "attach-session -t ${session}" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.3" $?
}
#. }=-

#. Copy (rsync over ssh)
#. testCoreRemoteCopyPublicRemoteFileToDirectory() -={
function testCoreRemoteCopyPublicRemoteFileToDirectory() {
    local hn="joker.mockery.net"
    local fn="/etc/cards"

    mock:wrapper remote copy \
        ${hn}:${fn} "${SIMBOL_USER_VAR_CACHE?}/"\
    >"${stdoutF?}" 2>"${stderrF?}"

    grep -qFw -- '-ae ssh' "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qFw -- "${SIMBOL_USER_VAR_CACHE?}/" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qFw -- "${hn}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.3" $?
}
#. }=-
#. testCoreRemoteCopyPublicRemoteFileToFile() -={
function testCoreRemoteCopyPublicRemoteFileToFile() {
    local hn="joker.mockery.net"
    local fn="/etc/cards"

    mock:wrapper remote copy\
        ${hn}:${fn} "${SIMBOL_USER_VAR_CACHE?}/deck"\
    >"${stdoutF?}" 2>"${stderrF?}"

    grep -qFw -- '-ae ssh' "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.1" $?

    grep -qFw -- "${SIMBOL_USER_VAR_CACHE?}/deck" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qFw -- "${hn}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.3" $?
}
#. }=-
#. testCoreRemoteCopyPublicRemoteFileToRemoteFile() -={
function testCoreRemoteCopyPublicRemoteFileToRemoteFile() {
    local hnFrom="batman.mockery.net"
    local hnTo="joker.mockery.net"
    local fn="/etc/cards/joker"

    truncate -s0 "${g_SSH_MOCK?}.rsync"
    mock:wrapper remote copy\
        ${hnFrom}:${fn} ${hnTo}:${fn}\
    >"${stdoutF?}" 2>"${stderrF?}"

    local -i cmds; let cmds=$(wc -l < "${g_SSH_MOCK?}.rsync")
    assertEquals "${FUNCNAME?}/1" 2 ${cmds}

    grep -qFw -- '-ae ssh' "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qFw -- "${hnFrom?}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.3" $?

    grep -qE -- "${SIMBOL_USER_VAR_TMP?}/.*/${fn}\>" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.4" $?

    grep -qFw -- "${hnFrom}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.5" $?

    grep -qFw -- "${hnTo}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.6" $?
}
#. }=-
#. testCoreRemoteCopyPublicRemoteDirectoryToRemoteDirectory() -={
function testCoreRemoteCopyPublicRemoteDirectoryToRemoteDirectory() {
    local hnFrom="batman.mockery.net"
    local hnTo="joker.mockery.net"
    local fn="/etc/cards/"

    truncate -s0 "${g_SSH_MOCK?}.rsync"
    mock:wrapper remote copy\
        ${hnFrom}:${fn} ${hnTo}:${fn}\
    >"${stdoutF?}" 2>"${stderrF?}"

    local -i cmds; let cmds=$(wc -l < "${g_SSH_MOCK?}.rsync")
    assertEquals "${FUNCNAME?}/1.1" 2 ${cmds}

    grep -qFw -- '-ae ssh' "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qFw -- "${hnFrom?}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.3" $?

    grep -qE -- "${SIMBOL_USER_VAR_TMP?}/.*/${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.4" $?

    grep -qFw -- "${hnFrom}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.5" $?

    grep -qFw -- "${hnTo}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.6" $?
}
#. }=-
#. testCoreRemoteCopyPublicRemoteDirectoryToDirectory() -={
function testCoreRemoteCopyPublicRemoteDirectoryToDirectory() {
    local hnFrom="batman.mockery.net"
    local fn="/etc/cards/"

    truncate -s0 "${g_SSH_MOCK?}.rsync"
    mock:wrapper remote copy\
        ${hnFrom}:${fn} ${fn}\
    >"${stdoutF?}" 2>"${stderrF?}"

    local -i cmds; let cmds=$(wc -l < "${g_SSH_MOCK?}.rsync")
    assertEquals "${FUNCNAME?}/1.1" 1 ${cmds}

    grep -qFw -- '-ae ssh' "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.2" $?

    grep -qFw -- "${hnFrom}:${fn}" "${g_SSH_MOCK?}.rsync"
    assertTrue "${FUNCNAME?}/1.3" $?
}
#. }=-
#. testCoreRemoteCopyPublicDirectoryToRemoteDirectory() -={
function testCoreRemoteCopyPublicDirectoryToRemoteDirectory() {
    local hnFrom="batman.mockery.net"
    local fn="/etc/cards/"

    truncate -s0 "${g_SSH_MOCK?}.rsync"
    mock:wrapper remote copy\
        ${fn} ${hnFrom}:${fn}\
    >"${stdoutF?}" 2>"${stderrF?}"

    local -i cmds; let cmds=$(wc -l < "${g_SSH_MOCK?}.rsync")
    assertEquals "${FUNCNAME?}/1.1" 1 ${cmds}
}
#. }=-

#. Multi-Thread Execution
#. testCoreRemoteThreadSetup() -={
function testCoreRemoteThreadSetup() {
    local -i pid=$$
    rm -f "${SIMBOL_USER_VAR_TMP?}/thread.${pid}.sct"
    ::remote:thread:setup ${pid}
    assertTrue "${FUNCNAME?}/1" $?

    test -e "${SIMBOL_USER_VAR_TMP?}/thread.${pid}.sct"
    assertTrue "${FUNCNAME?}/1.1" $?

    echo 111 >&3
    assertTrue "${FUNCNAME?}/1.2.1" $?

    echo 222 >&3
    assertTrue "${FUNCNAME?}/1.2.2" $?

    echo 333 >&3
    assertTrue "${FUNCNAME?}/1.2.3" $?
}
#. }=-
#. testCoreRemoteThreadTeardown() -={
function testCoreRemoteThreadTeardown() {
    local -i pid=$$
    test -e "${SIMBOL_USER_VAR_TMP?}/thread.${pid}.sct"
    assertTrue "${FUNCNAME?}/1" $?

    local -i a b c

    read -r -u4 a
    assertTrue "${FUNCNAME?}/2.1" $?

    read -r -u4 b
    assertTrue "${FUNCNAME?}/2.2" $?

    read -r -u4 c
    assertTrue "${FUNCNAME?}/2.3" $?

    #shellcheck disable=SC2086
    assertEquals "${FUNCNAME?}/3.1" $a 111
    #shellcheck disable=SC2086
    assertEquals "${FUNCNAME?}/3.2" $b 222
    #shellcheck disable=SC2086
    assertEquals "${FUNCNAME?}/3.3" $c 333

    ::remote:thread:teardown ${pid}
    assertTrue "${FUNCNAME?}/4" $?

    test -e "${SIMBOL_USER_VAR_TMP?}/thread.${pid}.sct"
    assertFalse "${FUNCNAME?}/4.1" $?
}
#. }=-
#. testCoreRemoteSsh_threadIpcPrivate -={
function testCoreRemoteSsh_threadIpcPrivate() {
    local -i pid=$$
    local hn='batman.mockery.net'

    ::remote:thread:setup ${pid} >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1.1" $?

    mock:wrapper remote ::ssh_thread.ipc 1 1 "${hn}"\
        echo "0xDEADBEEF"\
    >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1.2" $?

    local hcs
    while ! read -ru 4 -d $'\0' hcs; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.1" "${hn}" "${hcs}"

    local stdout
    while ! read -ru 4 -d $'\0' stdout; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.2" '0xDEADBEEF' "${stdout}"

    local stderr
    while ! read -ru 4 -d $'\0' stderr; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.3" '' "${stderr}"

    local ee
    while ! read -ru 4 -d $'\0' ee; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.4" 0 "${ee}"

    local metadata_raw
    while ! read -ru 4 -d $'\0' metadata_raw; do sleep 0.1; done
    assertEquals "${FUNCNAME?}/1.3.5" "tries=1;" "${metadata_raw}"

    ::remote:thread:teardown ${pid}
    assertTrue "${FUNCNAME?}/1.4" $?
}
#. }=-
#. testCoreRemoteMonIpcPrivate -={
function testCoreRemoteMonIpcPrivate() {
    mock:wrapper remote ::mon.ipc 1 1 1 '|' \
        'batman.mockery.net,joker.mockery.net' hostname\
    >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    grep -qFc "xc|batman.mockery.net|0" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.1.1" $?
    grep -qFc "so|batman.mockery.net|${HOSTNAME?}" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.1.2" $?
    grep -qFc "se|batman.mockery.net|" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.1.3" $?
    grep -qFc "md|batman.mockery.net|tries=1" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.1.4" $?

    grep -qFc "xc|joker.mockery.net|0" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.2.1" $?
    grep -qFc "so|joker.mockery.net|${HOSTNAME?}" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.2.2" $?
    grep -qFc "se|joker.mockery.net|" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.2.3" $?
    grep -qFc "md|joker.mockery.net|tries=1" "${stdoutF?}"
    assertTrue "${FUNCNAME?}/1.2.4" $?
}
#. }=-
#. testCoreRemoteMonPublic -={
function testCoreRemoteMonPublic() {
    : noop
}
#. }=-
#. }=-
