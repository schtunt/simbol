# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import gpg
core:import vault

#FIXME: ML: Please make this file shellcheck compliant

#. Vault -={
function vaultOneTimeSetUp() {
    #ML: All you need are global variables, not exported variables (except for
    #ML: things like GNUPGHOME... *possibly*.  Please clean.
    export g_VAULT="${SIMBOL_USER_VAR_CACHE?}/mock-etc/simbol.vault"

    export SIMBOL_PROFILE=UNITTEST
    export GNUPGHOME="${SIMBOL_USER_VAR_CACHE?}/dot.gnupg"
    export GNUPG_TEST_D="${SIMBOL_USER_VAR_TMP?}/gpg-test-data"
    export USER_VAULT_PASSPHRASE="SoSecrative"

    export SIMBOL_USER_ETC="${SIMBOL_USER_VAR_CACHE?}/mock-etc"
    mkdir -p "${SIMBOL_USER_ETC}"

    rm -rf "${GNUPGHOME?}"
    mkdir "${GNUPGHOME?}"
    chmod 700 "${GNUPGHOME?}"

    rm -rf "${GNUPG_TEST_D?}"
    mkdir -p "${GNUPG_TEST_D?}"

    mock:wrapper gpg list >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
    grep -q NO_KEYS "${stdoutF?}"
    assertTrue "${FUNCNAME?}/2" $?

    local gpgkid; let gpgkid=$(mock:wrapper gpg :create 2>"${stderrF?}")
    assertTrue "${FUNCNAME?}/3" $?
    assertEquals "${FUNCNAME?}/4" 10 ${#gpgkid}
    export gpgkid
}

function vaultSetUp() {
   assertTrue "{FUNCNAME}/1" $?

}

function vaultTearDown() {
    : noop
}

function vaultOneTimeTearDown() {
    mock:wrapper gpg :list '*' >"${stdoutF?}" 2>"${stderrF?}"
    local -a gpgkid=( $(cat "${stdoutF?}") )
    if [ ${#gpgkid[@]} -gt 0 ]; then
        mock:wrapper gpg :delete "${gpgkid[0]}" >"${stdoutF?}" 2>"${stderrF?}"
    fi

    rm -rf "${GNUPGHOME?}"
    rm -rf "${GNUPG_TEST_D?}"
    rm -rf "${SIMBOL_USER_ETC}/mock-etc"
    rm -rf "${g_VAULT}"

    mock:clear
}

#. testCoreVaultCreatePublic -={
function testCoreVaultCreatePublic() {
    #FIXME ML: this code is repeated over and over and over.  Please clean up.
    local vault_tmp; vault_tmp="$(::vault:getTempFile "${g_VAULT}" killme)"
    local vault_ts; vault_ts="$(::vault:getTempFile "${g_VAULT}" timestamp)"
    local vault_bu
    #shellcheck disable=SC2086
    vault_bu="$(::vault:getTempFile "${g_VAULT}" ${NOW?})"

    rm -f "${g_VAULT}"
    core:wrapper g_VAULT :create "${g_VAULT}" >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    test -e "${g_VAULT}"
    assertTrue "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreVaultCleanPrivate -={
function testCoreVaultCleanPrivate() {
    #FIXME ML: this code is repeated over and over and over.  Please clean up.
    local vault_tmp; vault_tmp="$(::vault:getTempFile "${g_VAULT}" killme)"
    local vault_ts; vault_ts="$(::vault:getTempFile "${g_VAULT}" timestamp)"
    local vault_bu
    #shellcheck disable=SC2086
    vault_bu="$(::vault:getTempFile "${g_VAULT}" ${NOW?})"

    chmod 1777 ${g_VAULT}
    for f in "${vault_ts}" "${vault_tmp}" "${vault_bu}"; do
        rm -f ${f}
        touch ${f}
        echo "secret" > ${f}
        chmod 7777 ${f}
    done

    :vault:clean >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/1" $?
    assertEquals "${FUNCNAME}/2" 600 "$(:util:statmode "${g_VAULT}")"

    test ! -e ${vault_ts}
    assertTrue "${FUNCNAME}/3" $?

    test ! -e ${vault_tmp}
    assertTrue "${FUNCNAME}/4" $?

    #. Back-up should not be removed, just fixed
    test -e ${vault_bu}
    assertTrue "${FUNCNAME}/5" $?
    assertEquals "${FUNCNAME}/6" 400 "$(:util:statmode "${vault_bu}")"
    rm -f ${vault_bu}
}
#. }=-
#. testCoreVaultCreateInternal -={
function testCoreVaultCreateInternal() {
    #FIXME ML: this code is repeated over and over and over.  Please clean up.
    local g_VAULT="${1:-${g_VAULT?}}"
    local vault_tmp=$(::vault:getTempFile ${g_VAULT} killme)
    local vault_ts=$(::vault:getTempFile ${g_VAULT} timestamp)
    local vault_bu=$(::vault:getTempFile ${g_VAULT} ${NOW?})

    rm -f ${g_VAULT}
    vault:create ${g_VAULT} >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/1" $?

    test -e ${g_VAULT}
    assertTrue "${FUNCNAME}/2" $?
}
#. }=-
#. testCoreVaultListPublic -={
function testCoreVaultListPublic() {
    core:wrapper g_VAULT list >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/1" $?
}
#. }=-
#. testCoreVaultListInternal -={
function testCoreVaultListInternal() {
    #FIXME ML: this code is repeated over and over and over.  Please clean up.
    local g_VAULT="${1:-${g_VAULT?}}"
    local vault_tmp=$(::vault:getTempFile ${g_VAULT} killme)
    local vault_ts=$(::vault:getTempFile ${g_VAULT} timestamp)
    local vault_bu=$(::vault:getTempFile ${g_VAULT} ${NOW?})

    vault:list ${g_VAULT} >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/1" $?
}
#. }=-
#. testCoreVaultEditPublic -={
function testCoreVaultEditPublic() {
    #FIXME ML: this code is repeated over and over and over.  Please clean up.
    local g_VAULT="${1:-${g_VAULT?}}"
    local vault_tmp=$(::vault:getTempFile ${g_VAULT} killme)
    local vault_ts=$(::vault:getTempFile ${g_VAULT} timestamp)
    local vault_bu=$(::vault:getTempFile ${g_VAULT} ${NOW?})

    #shellcheck disable=SC2037
    EDITOR=cat core:wrapper g_VAULT edit "${g_VAULT}" >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/1" $?

    #. No amendments, so no back-up should be created
    test ! -e ${vault_bu}
    assertTrue "${FUNCNAME}/2" $?

    if [ -e ${vault_bu} ]; then
        #. TODO: When mid-edit however, check that the backup file created has
        #. TODO: the right mode set
        local mode
        mode=$(:util:statmode ${vault_bu})
        assertTrue "${FUNCNAME}/3" $?
        assertEquals "${FUNCNAME}/4" 400 ${mode}
    fi
}
#. }=-
#. testCoreVaultReadInternal -={
function testCoreVaultReadInternal() {
    vault:read MY_SECRET_1 >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/1" $?

    vault:read MY_SECRET_111 >"${stdoutF?}" 2>"${stderrF?}"
    assertFalse "${FUNCNAME}/2" $?
}
#. }=-
#. testCoreVaultReadPublic -={
function testCoreVaultReadPublic() {
    core:wrapper g_VAULT read MY_SECRET_1 >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/1" $?

    core:wrapper g_VAULT read MY_SECRET_111 >"${stdoutF?}" 2>"${stderrF?}"
    assertFalse "${FUNCNAME}/2" $?
}
#. }=-
#. testCoreVaultEncryptionInternal -={
function testCoreVaultEncryptionInternal() {
    local secret="${SIMBOL_USER_VAR_TMP}/secret.txt"
    rm -f "${secret}"
    echo "Secret" > "${secret}"
    chmod 600 "${secret}"
    assertTrue "${FUNCNAME}/1" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    [ "${md5}" == "6657d705191a76297fe693296075b400" ]
    assertTrue "${FUNCNAME}/2" $?

    vault:encryption "${secret}" on >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/3" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertNotEquals "${FUNCNAME}/4" "6657d705191a76297fe693296075b400" "${md5}"

    vault:encryption ${secret} off >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/5" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertEquals "${FUNCNAME}/6" "6657d705191a76297fe693296075b400" "${md5}"

    rm -f "${secret}"
}
#. }=-
#. testCoreVaultEncryptPublic -={
function testCoreVaultEncryptPublic() {
    local secret="${SIMBOL_USER_VAR_TMP}/secret.txt"
    rm -f "${secret}"
    echo "Secret" > "${secret}"
    chmod 600 "${secret}"
    assertTrue "${FUNCNAME}/1" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertEquals "${FUNCNAME}/2" "6657d705191a76297fe693296075b400" "${md5}"

    core:wrapper g_VAULT encrypt "${secret}" >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/3" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertNotEquals "${FUNCNAME}/4" "6657d705191a76297fe693296075b400" "${md5}"
}
#. }=-
#. testCoreVaultDecryptPublic -={
function testCoreVaultDecryptPublic() {
    local secret="${SIMBOL_USER_VAR_TMP}/secret.txt"
    [ -e "${secret}" ]
    assertTrue "${FUNCNAME}/1" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertNotEquals "${FUNCNAME}/2" "6657d705191a76297fe693296075b400" "${md5}"

    core:wrapper g_VAULT decrypt "${secret}" >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/3" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertEquals "${FUNCNAME}/4" "6657d705191a76297fe693296075b400" "${md5}"

    rm -f "${secret}"
}
#. }=-
#. }=-
