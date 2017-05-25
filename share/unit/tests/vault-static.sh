# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import gpg


#. Vault -={
function vaultOneTimeSetUp() {
    export vault=${SIMBOL_USER_VAR_CACHE?}/mock-etc/simbol.vault
    export SIMBOL_PROFILE=UNITTEST
    export GNUPGHOME="${SIMBOL_USER_VAR_CACHE?}/dot.gnupg"
    export GNUPG_TEST_D="${SIMBOL_USER_VAR_TMP?}/gpg-test-data"
    export USER_VAULT_PASSPHRASE="SoSecrative"

    export SIMBOL_USER_ETC=${SIMBOL_USER_VAR_CACHE?}/mock-etc
    mkdir -p ${SIMBOL_USER_ETC}
    core:import vault

    rm -rf "${GNUPGHOME?}"
    mkdir "${GNUPGHOME?}"
    chmod 700 "${GNUPGHOME?}"

    rm -rf "${GNUPG_TEST_D?}"
    mkdir -p "${GNUPG_TEST_D?}"

    mock:clear
    mock:write <<-!MOCK
	declare SIMBOL_USER_ETC=${SIMBOL_USER_VAR_CACHE?}/mock-etc
!MOCK

    mock:wrapper gpg list >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?
    grep -q NO_KEYS "${stdoutF?}"
    assertTrue "${FUNCNAME?}/2" $?

    gpgkid=$(mock:wrapper gpg :create 2>"${stderrF?}")
    assertTrue "${FUNCNAME?}/3" $?
    assertEquals "${FUNCNAME?}/4" 10 ${#gpgkid}
    cat "${stderrF?}"
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
    rm -rf "${vault}"

    mock:clear
}

#. testCoreVaultCreatePublic -={
function testCoreVaultCreatePublic() {
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    rm -f ${vault}
    core:wrapper vault :create ${vault} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME}/1" $?

    test -e ${vault}
    assertTrue "${FUNCNAME}/2" $?
}
#. }=-
#. testCoreVaultCleanPrivate -={
function testCoreVaultCleanPrivate() {
    local vault="${1:-${vault?}}"
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

    ::vault:clean >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME}/1" $?
    assertEquals "${FUNCNAME}/2" 600 "$(:util:statmode "${vault}")"

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
    local vault="${1:-${vault?}}"
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    rm -f ${vault}
    :vault:create ${vault} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME}/1" $?

    test -e ${vault}
    assertTrue "${FUNCNAME}/2" $?
}
#. }=-
#. testCoreVaultListPublic -={
function testCoreVaultListPublic() {
    core:wrapper vault list >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME}/1" $?
}
#. }=-
#. testCoreVaultListInternal -={
function testCoreVaultListInternal() {
    local vault="${1:-${vault?}}"
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    :vault:list ${vault} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME}/1" $?
}
#. }=-
#. testCoreVaultEditPublic -={
function testCoreVaultEditPublic() {
    local vault="${1:-${vault?}}"
    local vault_tmp=$(::vault:getTempFile ${vault} killme)
    local vault_ts=$(::vault:getTempFile ${vault} timestamp)
    local vault_bu=$(::vault:getTempFile ${vault} ${NOW?})

    #shellcheck disable=SC2037
    EDITOR=cat core:wrapper vault edit "${vault}" >${stdoutF?} 2>${stderrF?}
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
    :vault:read MY_SECRET_1 >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME}/1" $?

    :vault:read MY_SECRET_111 >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME}/2" $?
}
#. }=-
#. testCoreVaultReadPublic -={
function testCoreVaultReadPublic() {
    core:wrapper vault read MY_SECRET_1 >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME}/1" $?

    core:wrapper vault read MY_SECRET_111 >${stdoutF?} 2>${stderrF?}
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

    :vault:encryption "${secret}" on >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME}/3" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertNotEquals "${FUNCNAME}/4" "6657d705191a76297fe693296075b400" "${md5}"

    :vault:encryption ${secret} off >${stdoutF?} 2>${stderrF?}
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

    core:wrapper vault encrypt "${secret}" >${stdoutF?} 2>${stderrF?}
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

    core:wrapper vault decrypt "${secret}" >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME}/3" $?

    md5="$(md5sum "${secret}" | awk '{print$1}')"
    assertEquals "${FUNCNAME}/4" "6657d705191a76297fe693296075b400" "${md5}"

    rm -f "${secret}"
}
#. }=-
#. }=-
