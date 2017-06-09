# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import gpg

#. GPG -={
function gpgOneTimeSetUp() {
    export SIMBOL_PROFILE=UNITTEST
    export GNUPG_TEST_D="${SIMBOL_USER_VAR_TMP?}/gpg-test-data"
    export USER_VAULT_PASSPHRASE="SoSecrative"
    export GNUPGHOME="${SIMBOL_USER_VAR_CACHE?}/dot.gnupg"

    rm -rf "${GNUPGHOME?}"
    mkdir "${GNUPGHOME?}"
    chmod 700 "${GNUPGHOME?}"

    rm -rf "${GNUPG_TEST_D?}"
    mkdir -p "${GNUPG_TEST_D?}"

    mock:clear
    mock:write <<-!MOCK
    declare -g -A FILES=(
        [data_orig]="\${GNUPG_TEST_D?}/gpg-\${SIMBOL_PROFILE?}-data"
        [data_encr]="\${GNUPG_TEST_D?}/gpg-\${SIMBOL_PROFILE?}-data.enc"
        [data_decr]="\${GNUPG_TEST_D?}/gpg-\${SIMBOL_PROFILE?}-data.dec"
        [key_cnf]="\${GNUPGHOME?}/*.\${SIMBOL_PROFILE?}.*.conf"
        [key_sec]="\${GNUPGHOME?}/*.\${SIMBOL_PROFILE?}.*.sec"
        [key_pub]="\${GNUPGHOME?}/*.\${SIMBOL_PROFILE?}.*.pub"
    )
	!MOCK
}

function gpgSetUp() {
    : pass
}

function gpgTearDown() {
    : pass
}

function gpgOneTimeTearDown() {
    local file
    for file in "${!FILES[@]}"; do
        rm -f "${FILES[${file}]}"
    done

    mock:wrapper gpg :list '*' >"${stdoutF?}" 2>"${stderrF?}"
    local -a gpgkid=( $(cat "${stdoutF?}") )
    if [ ${#gpgkid[@]} -gt 0 ]; then
    	mock:wrapper gpg :delete "${gpgkid[1]}" >"${stdoutF?}" 2>"${stderrF?}"
    fi

    rm -rf "${GNUPGHOME?}"
    rm -rf "${GNUPG_TEST_D?}"

    mock:clear
}

#. testCoreGpgVersionInternal -={
function testCoreGpgVersionInternal() {
    local gpg_version; gpg_version="$(mock:wrapper gpg :version)"
    assertTrue "${FUNCNAME?}/1.1" $?
    assertNotEquals "${FUNCNAME?}/1.2" "" "${gpg_version}"
}
#. }=-
#. testCoreGpgKidPrivate -={
function testCoreGpgKeyidPrivate() {
    local kid; kid="$(mock:wrapper gpg ::keyid "/home/nobody/.gnupg/nobody.UNITTEST.0x81C8A8ED.conf")"
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/1.1" "0x81C8A8ED" "${kid}"
}
#. }=-
#. testCoreGpgKeysEvalPrivate -={
function testCoreGpgKeysEvalPrivate() {
    eval "$(mock:wrapper gpg ::keys.eval data '*')"
    assertTrue "${FUNCNAME?}/1.1" $?
    #shellcheck disable=SC2154
    assertEquals "${FUNCNAME?}/1.2" 0 ${#data[@]}
}
#. }=-
#. testCoreGpgKeypathPrivate -={
function testCoreGpgKeypathPrivate() {
    local path
    #shellcheck disable=SC2034
    path="$(mock:wrapper gpg ::keypath)"
    assertTrue "${FUNCNAME?}/1.1" $?
    #shellcheck disable=SC2016
    assertTrue "${FUNCNAME?}/1.2" '[ "${path//${GNUPGHOME}/}" != "${path}" ]'
}
#. }=-
#. testCoreGpgListInternal -={
function testCoreGpgListInternal() {
    #. Should be none to list at first
    mock:wrapper gpg :list '*' >"${stdoutF?}" 2>"${stderrF?}"
    assertFalse "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreGpgListPublic -={
function testCoreGpgListPublic() {
    SIMBOL_PROFILE=UNITTEST mock:wrapper gpg list >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    grep -q NO_KEYS "${stdoutF?}"
    assertTrue "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreGpgCreateAndDeleteInternal -={
function testCoreGpgCreateAndDeleteInternal() {
    #. Create one
    local kid; kid="$(mock:wrapper gpg :create)"
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/1.1" 10 ${#kid}

    #. List it
    local kid2

    kid2="$(mock:wrapper gpg :list '*')"
    assertTrue "${FUNCNAME?}/2" $?
    assertEquals "${FUNCNAME?}/2.1" "${kid}" "${kid2}"

    kid2="$(mock:wrapper gpg :list "${kid}")"
    assertTrue "${FUNCNAME?}/3" $?
    assertEquals "${FUNCNAME?}/3.1" "${kid}" "${kid2}"

    mock:wrapper gpg :delete "${kid}"
    assertTrue "${FUNCNAME?}/4" $?
    local ftype
    for ftype in pub sec conf; do
        stat "${GNUPGHOME}/${USER_USERNAME}.${SIMBOL_PROFILE}.${kid}.${ftype}" 2>/dev/null
        assertFalse "${FUNCNAME?}/4.${ftype}" $?
    done
}
function testCoreGpgCreateInternal() {
    : noop testCoreGpgCreateAndDeleteInternal
}
function testCoreGpgDeleteInternal() {
    : see testCoreGpgCreateAndDeleteInternal
}
#. }=-
#. testCoreGpgCreateAndDeletePublic -={
function testCoreGpgCreateAndDeletePublic() {
    #. Create one
    mock:wrapper gpg create >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    #. List it
    local kid; kid="$(mock:wrapper gpg :list '*')"
    assertTrue "${FUNCNAME?}/2" $?
    assertEquals "${FUNCNAME?}/2.1" 10 ${#kid}

    #. Delete it
    mock:wrapper gpg delete "${kid}" >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/3" $?

    #. Try to delete it again and fail
    mock:wrapper gpg delete "${kid}" >"${stdoutF?}" 2>"${stderrF?}"
    assertFalse "${FUNCNAME?}/3.1" $?

    #. Should be none to list again
    mock:wrapper gpg list "${kid}" >"${stdoutF?}" 2>"${stderrF?}"
    assertFalse "${FUNCNAME?}/3.2" $?
}
function testCoreGpgCreatePublic() {
    : see testCoreGpgCreateAndDeletePublic
}
function testCoreGpgDeletePublic() {
    : see testCoreGpgCreateAndDeletePublic
}
#. }=-
#. testCoreGpgEncryptInternal -={
function testCoreGpgEncryptInternal() {
    #. Create it
    mock:wrapper gpg :create >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    dd if=/dev/urandom of="${FILES[data_orig]}" bs=1024 count=1024 2>/dev/null
    mock:wrapper gpg :encrypt\
        "${FILES[data_orig]}" "${FILES[data_encr]}"
    # >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreGpgDecryptInternal -={
function testCoreGpgDecryptInternal() {
    mock:wrapper gpg :decrypt\
        "${FILES[data_encr]}" "${FILES[data_decr]}" >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/1" $?

    local match; let match=$(
        md5sum "${FILES[data_orig]}" "${FILES[data_decr]}" |
            awk '{print$1}' | sort -u | wc -l
    )
    assertEquals "${FUNCNAME?}/2" ${match} 1

    local kid; kid="$(mock:wrapper gpg :list '*')"
    assertTrue "${FUNCNAME?}/3" $?

    #. Delete it
    mock:wrapper gpg :delete "${kid}" >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME?}/4" $?
}
#. }=-
#. }=-
