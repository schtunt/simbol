# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import gpg

declare -g g_GPGKID

function testCoreVaultImport() {
    core:softimport vault
    assertEquals 0 $?
}

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
    case ${g_MODE?} in
        prime)
            : noop
        ;;
        execute)
            :gpg:delete ${g_GPGKID} >${stdoutF?} 2>${stderrF?}
            rm -f ${g_VAULT?}
            rm -f ${g_VAULT_BU?}
        ;;
        *)
            return 127
        ;;
    esac
}

function testCoreVaultCreatePublic() {
    core:import vault

    rm -f ${g_VAULT?}
    core:wrapper vault create >${stdoutF?} 2>${stderrF?}
    assertTrue '0x1' $?

    test -e ${g_VAULT?}
    assertTrue '0x2' $?
}

function testCoreVaultCleanPrivate() {
    core:import vault

    chmod 1777 ${g_VAULT?}
    for f in "${g_VAULT_TS?}" "${g_VAULT_TMP?}" "${g_VAULT_BU?}"; do
        rm -f ${f}
        touch ${f}
        echo "secret" > ${f}
        chmod 7777 ${f}
    done

    ::vault:clean
    assertTrue '0x1' $?
    assertEquals '0x6' 600 $(:util:stat:mode ${g_VAULT?})

    test ! -e ${g_VAULT_TS?}
    assertTrue '0x2' $?

    test ! -e ${g_VAULT_TMP?}
    assertTrue '0x3' $?

    #. Back-up should not be removed, just fixed
    test -e ${g_VAULT_BU?}
    assertTrue '0x4' $?
    assertEquals '0x6' 400 $(:util:stat:mode ${g_VAULT_BU?})
    rm -f ${g_VAULT_BU?}
}

function testCoreVaultCreateInternal() {
    core:import vault

    rm -f ${g_VAULT?}
    :vault:create ${g_VAULT?} >${stdoutF?} 2>${stderrF?}
    assertTrue '0x1' $?

    test -e ${g_VAULT?}
    assertTrue '0x2' $?
}

function testCoreVaultListPublic() {
    core:import vault

    core:wrapper vault list >${stdoutF?} 2>${stderrF?}
    assertTrue '0x1' $?
}

function testCoreVaultListInternal() {
    core:import vault

    :vault:list ${g_VAULT} >${stdoutF?} 2>${stderrF?}
    assertTrue '0x1' $?
}

function testCoreVaultEditPublic() {
    core:import vault

    EDITOR=cat core:wrapper vault edit ${g_VAULT} >${stdoutF?} 2>${stderrF?}
    assertTrue '0x1' $?

    #. No amendments, so no back-up should be created
    test ! -e ${g_VAULT_BU?}
    assertTrue '0x2' $?

    #. TODO: When amendment is made however...
    #. Check that a backup file was created and has the right mode
    #test -e ${g_VAULT_BU?}
    #assertTrue '0x2' $?
    #local mode
    #mode=$(:util:stat:mode ${g_VAULT_BU?})
    #assertTrue '0x3' $?
    #assertEquals '0x4' 400 ${mode}
}

function testCoreVaultReadInternal() {
    core:import vault

    :vault:read MY_SECRET_1 >${stdoutF?} 2>${stderrF?}
    assertTrue '0x1' $?

    :vault:read MY_SECRET_111 >${stdoutF?} 2>${stderrF?}
    assertFalse '0x2' $?
}

function testCoreVaultReadPublic() {
    core:import vault

    core:wrapper gpg read MY_SECRET_1 >${stdoutF?} 2>${stderrF?}
    assertTrue '0x1' $?

    core:wrapper gpg read MY_SECRET_111 >${stdoutF?} 2>${stderrF?}
    assertFalse '0x2' $?
}
