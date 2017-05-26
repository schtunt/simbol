# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import gpg

function gpgOneTimeSetUp() {
    declare -g -A FILES=(
        [data_orig]="/tmp/simbol-gpg-unit-test-data"
        [data_encr]="/tmp/simbol-gpg-unit-test-data.enc"
        [data_decr]="/tmp/simbol-gpg-unit-test-data.dec"
        [key_cnf]="${HOME}/.gnupg/*.UNITTEST.*.conf"
        [key_sec]="${HOME}/.gnupg/*.UNITTEST.*.sec"
        [key_pub]="${HOME}/.gnupg/*.UNITTEST.*.pub"
    )
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
        eval rm -f "${FILES[${file}]}"
    done

    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    local -a gpgkid=( $(cat ${stdoutF?}) )
    if [ ${#gpgkid[@]} -gt 0 ]; then
    	SIMBOL_PROFILE=UNITTEST :gpg:delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
    fi
}

function testCoreGpgVersionInternal() {
    local gpg_version; gpg_version="$(:gpg:version)"
    assertTrue "${FUNCNAME?}/1.1" $?
    assertNotEquals "${FUNCNAME?}/1.2" "" "${gpg_version}"
}

function testCoreGpgKeypathPrivate() {

    local -i c

    SIMBOL_PROFILE=UNITTEST ::gpg:keypath '.' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?
    let c=$(wc -w < "${stdoutF}")
    assertEquals "${FUNCNAME?}/1.2" 1 $c

    SIMBOL_PROFILE=UNITTEST ::gpg:keypath '*' >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/1.3" $?
    let c=$(wc -w < "${stdoutF}")
    assertEquals "${FUNCNAME?}/1.4" 0 $c
}

function testCoreGpgListInternal() {
    #. Should be none to list at first
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/1.1" $?
}

function testCoreGpgCreateInternal() {
    #. Create one
    SIMBOL_PROFILE=UNITTEST :gpg:create >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    #. List it
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.2" $?

    local -a gpgkid=( $(cat ${stdoutF?}) )
    assertEquals "${FUNCNAME?}/1.3" 2 ${#gpgkid[@]}
    assertEquals "${FUNCNAME?}/1.4" 10 ${#gpgkid[1]}
}

function testCoreGpgKidPrivate() {
    local -a gpgkid_a=( $(cat ${stdoutF?}) )
    SIMBOL_PROFILE=UNITTEST ::gpg:kid
    assertFalse "${FUNCNAME?}/1.1" $?
    local gpgkid_b; gpgkid_b="$(SIMBOL_PROFILE=UNITTEST ::gpg:kid '*')"
    assertEquals "${FUNCNAME?}/1.2" "${gpgkid_a[1]}" "${gpgkid_b}"

    local gpgkid_c; gpgkid_c=$(SIMBOL_PROFILE=UNITTEST ::gpg:kid ${gpgkid_b})
    assertEquals "${FUNCNAME?}/1.3" "${gpgkid_c}" "${gpgkid_b}"
}

function testCoreGpgDeleteInternal() {
    local gpgkid=( $(cat ${stdoutF?}) )

    #. Delete it
    SIMBOL_PROFILE=UNITTEST :gpg:delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    #. Should be none to list again
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/1.2" $?
}

function testCoreGpgListPublic() {
    #. Should be none to list at first
    SIMBOL_PROFILE=UNITTEST core:wrapper gpg list >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/1.1" $?
}

function testCoreGpgCreatePublic() {
    #. Create one
    SIMBOL_PROFILE=UNITTEST core:wrapper gpg create >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    #. List it
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.2" $?
    local gpgkid=( $(cat ${stdoutF?}) )
    assertEquals "${FUNCNAME?}/1.3" 2 ${#gpgkid[@]}
    assertEquals "${FUNCNAME?}/1.4" 10 ${#gpgkid[1]}
}

function testCoreGpgDeletePublic() {
    local gpgkid=( $(cat ${stdoutF?}) )
    if assertEquals "${FUNCNAME?}/1.1" 2 ${#gpgkid[@]}; then
        #. Delete it
        SIMBOL_PROFILE=UNITTEST core:wrapper gpg delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
        assertTrue "${FUNCNAME?}/1.1" $?

        #. Try to delete it again and fail
        SIMBOL_PROFILE=UNITTEST core:wrapper gpg delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
        assertFalse "${FUNCNAME?}/1.2" $?

        #. Should be none to list again
        SIMBOL_PROFILE=UNITTEST core:wrapper gpg list >${stdoutF?} 2>${stderrF?}
        assertFalse "${FUNCNAME?}/1.3" $?
    fi
}

function testCoreGpgEncryptInternal() {
    #. Create it
    SIMBOL_PROFILE=UNITTEST :gpg:create >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    dd if=/dev/urandom of=${FILES[data_orig]} bs=1024 count=1024 2>/dev/null
    SIMBOL_PROFILE=UNITTEST :gpg:encrypt\
        ${FILES[data_orig]} ${FILES[data_encr]} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.2" $?
}

function testCoreGpgDecryptInternal() {
    SIMBOL_PROFILE=UNITTEST :gpg:decrypt\
        ${FILES[data_encr]} ${FILES[data_decr]} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.1" $?

    local match; let match=$(
        cat ${FILES[data_orig]} ${FILES[data_decr]} |
            md5sum | awk '{print$1}' | wc -l
    )
    assertEquals "${FUNCNAME?}/1.2" ${match} 1

    #. Delete it
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.3" $?
    local -a gpgkid=( $(cat ${stdoutF?}) )
    SIMBOL_PROFILE=UNITTEST :gpg:delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1.4" $?
}
