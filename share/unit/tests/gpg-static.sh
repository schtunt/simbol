# vim: tw=0:ts=4:sw=4:et:ft=bash
declare -A FILES=(
    [data_orig]="/tmp/simbol-gpg-unit-test-data"
    [data_encr]="/tmp/simbol-gpg-unit-test-data.enc"
    [data_decr]="/tmp/simbol-gpg-unit-test-data.dec"
    [key_cnf]="~/.gnupg/*.UNITTEST.*.conf"
    [key_sec]="~/.gnupg/*.UNITTEST.*.sec"
    [key_pub]="~/.gnupg/*.UNITTEST.*.pub"
)

function gpgSetUp() {
    for file in ${!FILES[@]}; do
        eval rm -f ${FILES[${file}]}
    done
}

function gpgTearDown() {
    for file in ${!FILES[@]}; do
        eval rm -f ${FILES[${file}]}
    done
}

function testCoreGpgImport() {
    core:softimport gpg
    assertEquals 0x1 0 $?
}

function test_1_1_CoreGpgKeypathPrivate() {
    core:import gpg

    SIMBOL_PROFILE=UNITTEST ::gpg:keypath '.' >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?
    assertEquals 0x2 1 $(cat ${stdoutF}|wc -w)

    SIMBOL_PROFILE=UNITTEST ::gpg:keypath '*' >${stdoutF?} 2>${stderrF?}
    assertFalse 0x3 $?
    assertEquals 0x4 0 $(cat ${stdoutF}|wc -w)
}

function test_2_1_CoreGpgListInternal() {
    core:import gpg

    #. Should be none to list at first
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertFalse 0x1 $?
}

function test_2_2_CoreGpgCreateInternal() {
    core:import gpg

    #. Create one
    SIMBOL_PROFILE=UNITTEST :gpg:create >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?

    #. List it
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertTrue 0x2 $?

    local -a gpgkid=( $(cat ${stdoutF?}) )
    assertEquals 0x3 2 ${#gpgkid[@]}
    assertEquals 0x4 10 ${#gpgkid[1]}
}

function test_2_3_CoreGpgKidPrivate() {
    core:import gpg

    local -a gpgkid_a=( $(cat ${stdoutF?}) )
    local gpgkid_b="$(SIMBOL_PROFILE=UNITTEST ::gpg:kid)"
    assertEquals 0x1 "${gpgkid_a[1]}" "${gpgkid_b}"

    if [ $? -eq 0 ]; then
        local gpgkid_c=$(SIMBOL_PROFILE=UNITTEST ::gpg:kid ${gpgkid_b})
        assertEquals 0x2 "${gpgkid_c}" "${gpgkid_b}"
    fi
}

function test_2_4_CoreGpgDeleteInternal() {
    core:import gpg

    local gpgkid=( $(cat ${stdoutF?}) )

    #. Delete it
    SIMBOL_PROFILE=UNITTEST :gpg:delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?

    #. Should be none to list again
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertFalse 0x2 $?
}

function test_3_1_CoreGpgListPublic() {
    core:import gpg

    #. Should be none to list at first
    SIMBOL_PROFILE=UNITTEST core:wrapper gpg list >${stdoutF?} 2>${stderrF?}
    assertFalse 0x1 $?
}

function test_3_2_CoreGpgCreatePublic() {
    core:import gpg

    #. Create one
    SIMBOL_PROFILE=UNITTEST core:wrapper gpg create >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?

    #. List it
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    assertTrue 0x2 $?
    local gpgkid=( $(cat ${stdoutF?}) )
    assertEquals 0x3 2 ${#gpgkid[@]}
    assertEquals 0x4 10 ${#gpgkid[1]}
}

function test_3_3_CoreGpgDeletePublic() {
    core:import gpg

    local gpgkid=( $(cat ${stdoutF?}) )
    if assertEquals 0x1 2 ${#gpgkid[@]}; then
        #. Delete it
        SIMBOL_PROFILE=UNITTEST core:wrapper gpg delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
        assertTrue 0x1 $?

        #. Try to delete it again and fail
        SIMBOL_PROFILE=UNITTEST core:wrapper gpg delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
        assertFalse 0x2 $?

        #. Should be none to list again
        SIMBOL_PROFILE=UNITTEST core:wrapper gpg list >${stdoutF?} 2>${stderrF?}
        assertFalse 0x3 $?
    fi
}

function test_4_1_CoreGpgEncryptInternal() {
    core:import gpg

    #. Create it
    SIMBOL_PROFILE=UNITTEST :gpg:create >${stdoutF?} 2>${stderrF?}

    dd if=/dev/urandom of=${FILES[data_orig]} bs=1024 count=1024 2>/dev/null
    SIMBOL_PROFILE=UNITTEST :gpg:encrypt\
        ${FILES[data_orig]} ${FILES[data_encr]} >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?
}

function test_4_2_CoreGpgDecryptInternal() {
    core:import gpg

    SIMBOL_PROFILE=UNITTEST :gpg:encrypt\
        ${FILES[data_encr]} ${FILES[data_decr]} >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?

    local match=$(
        cat ${FILES[data_orig]} ${FILES[data_decr]} |
            md5sum | awk '{print$1}' | wc -l
    )

    assertEquals 0x2 ${match} 1

    #. Delete it
    SIMBOL_PROFILE=UNITTEST :gpg:list '*' >${stdoutF?} 2>${stderrF?}
    local -a gpgkid=( $(cat ${stdoutF?}) )
    SIMBOL_PROFILE=UNITTEST :gpg:delete ${gpgkid[1]} >${stdoutF?} 2>${stderrF?}
}
