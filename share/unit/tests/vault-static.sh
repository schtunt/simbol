# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import gpg
core:import vault

declare -g g_GPGKID

function vaultSetUp() {
    case ${g_MODE?} in
        prime)
            : noop
        ;;
        execute)
            export SIMBOL_PROFILE=UNITTEST
            g_GPGKID=$(:gpg:create)
        ;;
        *)
            exit 127
        ;;
    esac
}

function vaultTearDown() {
    local vault="${1:-${g_VAULT?}}"
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    case ${g_MODE?} in
        prime)
            : noop
        ;;
        execute)
            :gpg:delete ${g_GPGKID} >${stdoutF?} 2>${stderrF?}
            rm -f ${vault}
            rm -f ${vault_bu}
        ;;
        *)
            return 127
        ;;
    esac
}

function testCoreVaultCreatePublic() {
    local vault=${1:-${g_VAULT?}}
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    rm -f ${vault}
    core:wrapper vault create >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    test -e ${vault}
    assertTrue 0.2 $?
}

function testCoreVaultCleanPrivate() {
    local vault="${1:-${g_VAULT?}}"
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    chmod 1777 ${vault}
    for f in "${vault_ts}" "${vault_tmp}" "${vault_bu}"; do
        rm -f ${f}
        touch ${f}
        echo "secret" > ${f}
        chmod 7777 ${f}
    done

    ::vault:clean
    assertTrue 0.1 $?
    assertEquals 0.6 600 "$(:util:statmode "${vault}")"

    test ! -e ${vault_ts}
    assertTrue 0.2 $?

    test ! -e ${vault_tmp}
    assertTrue 0.3 $?

    #. Back-up should not be removed, just fixed
    test -e ${vault_bu}
    assertTrue 0.4 $?
    assertEquals 0.6 400 "$(:util:statmode "${vault_bu}")"
    rm -f ${vault_bu}
}

function testCoreVaultCreateInternal() {
    local vault="${1:-${g_VAULT?}}"
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    rm -f ${vault}
    :vault:create ${vault} >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    test -e ${vault}
    assertTrue 0.2 $?
}

function testCoreVaultListPublic() {
    core:wrapper vault list >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?
}

function testCoreVaultListInternal() {
    local vault="${1:-${g_VAULT?}}"
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    :vault:list ${vault} >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?
}

function testCoreVaultEditPublic() {
    local vault="${1:-${g_VAULT?}}"
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    #shellcheck disable=SC2037
    EDITOR=cat core:wrapper vault edit "${vault}" >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    #. No amendments, so no back-up should be created
    test ! -e ${vault_bu}
    assertTrue 0.2 $?

    if [ -e ${vault_bu} ]; then
        #. TODO: When mid-edit however, check that the backup file created has
        #. TODO: the right mode set
        local mode
        mode=$(:util:statmode ${vault_bu})
        assertTrue 0.3 $?
        assertEquals 0.4 400 ${mode}
    fi
}

function testCoreVaultReadInternal() {
    :vault:read MY_SECRET_1 >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    :vault:read MY_SECRET_111 >${stdoutF?} 2>${stderrF?}
    assertFalse 0.2 $?
}

function testCoreVaultReadPublic() {
    core:wrapper vault read MY_SECRET_1 >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    core:wrapper vault read MY_SECRET_111 >${stdoutF?} 2>${stderrF?}
    assertFalse 0.2 $?
}

function testCoreVaultEncryptionInternal() {
    local secret="${SIMBOL_USER_VAR_TMP}/secret.txt"
    rm -f "${secret}"
    echo "Secret" > "${secret}"
    chmod 600 "${secret}"
    assertTrue 0.1.1 $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    [ "${md5}" == "6657d705191a76297fe693296075b400" ]
    assertTrue 0.1.2 $?

    :vault:encryption "${secret}" on >${stdoutF?} 2>${stderrF?}
    assertTrue 0.2.1 $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertNotEquals 0.2.2 "6657d705191a76297fe693296075b400" "${md5}"

    :vault:encryption ${secret} off >${stdoutF?} 2>${stderrF?}
    assertTrue 0.3.1 $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertEquals 0.3.2 "6657d705191a76297fe693296075b400" "${md5}"

    rm -f "${secret}"
}

function test_1_CoreVaultEncryptPublic() {
    local secret="${SIMBOL_USER_VAR_TMP}/secret.txt"
    rm -f "${secret}"
    echo "Secret" > "${secret}"
    chmod 600 "${secret}"
    assertTrue 1.1.1 $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertEquals 1.1.2 "6657d705191a76297fe693296075b400" "${md5}"

    core:wrapper vault encrypt "${secret}" >${stdoutF?} 2>${stderrF?}
    assertTrue 1.2.1 $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertNotEquals 1.2.2 "6657d705191a76297fe693296075b400" "${md5}"
}

function test_2_CoreVaultDecryptPublic() {
    local secret="${SIMBOL_USER_VAR_TMP}/secret.txt"
    [ -e "${secret}" ]
    assertTrue 2.1 $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertNotEquals 2.2 "6657d705191a76297fe693296075b400" "${md5}"

    core:wrapper vault decrypt "${secret}" >${stdoutF?} 2>${stderrF?}
    assertTrue 2.3.1 $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertEquals 2.3.2 "6657d705191a76297fe693296075b400" "${md5}"

    rm -f "${secret}"
}
