# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import util
core:import gpg

declare -g g_GPGKID

function testCoreVaultImport() {
    core:softimport vault
    assertEquals 0.0 0 $?
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
    assertTrue 0.0 $?

    rm -f ${g_VAULT?}
    core:wrapper vault create >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    test -e ${g_VAULT?}
    assertTrue 0.2 $?
}

function testCoreVaultCleanPrivate() {
    core:import vault
    assertTrue 0.0 $?

    chmod 1777 ${g_VAULT?}
    for f in "${g_VAULT_TS?}" "${g_VAULT_TMP?}" "${g_VAULT_BU?}"; do
        rm -f ${f}
        touch ${f}
        echo "secret" > ${f}
        chmod 7777 ${f}
    done

    ::vault:clean
    assertTrue 0.1 $?
    assertEquals 0.6 600 $(:util:statmode ${g_VAULT?})

    test ! -e ${g_VAULT_TS?}
    assertTrue 0.2 $?

    test ! -e ${g_VAULT_TMP?}
    assertTrue 0.3 $?

    #. Back-up should not be removed, just fixed
    test -e ${g_VAULT_BU?}
    assertTrue 0.4 $?
    assertEquals 0.6 400 $(:util:statmode ${g_VAULT_BU?})
    rm -f ${g_VAULT_BU?}
}

function testCoreVaultCreateInternal() {
    core:import vault
    assertTrue 0.0 $?

    rm -f ${g_VAULT?}
    :vault:create ${g_VAULT?} >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    test -e ${g_VAULT?}
    assertTrue 0.2 $?
}

function testCoreVaultListPublic() {
    core:import vault
    assertTrue 0.0 $?

    core:wrapper vault list >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?
}

function testCoreVaultListInternal() {
    core:import vault
    assertTrue 0.0 $?

    :vault:list ${g_VAULT} >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?
}

function testCoreVaultEditPublic() {
    core:import vault
    assertTrue 0.0 $?

    EDITOR=cat core:wrapper vault edit ${g_VAULT} >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    #. No amendments, so no back-up should be created
    test ! -e ${g_VAULT_BU?}
    assertTrue 0.2 $?

    if [ -e ${g_VAULT_BU?} ]; then
        #. TODO: When mid-edit however, check that the backup file created has
        #. TODO: the right mode set
        local mode
        mode=$(:util:statmode ${g_VAULT_BU?})
        assertTrue 0.3 $?
        assertEquals 0.4 400 ${mode}
    fi
}

function testCoreVaultReadInternal() {
    core:import vault
    assertTrue 0.0 $?

    :vault:read MY_SECRET_1 >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    :vault:read MY_SECRET_111 >${stdoutF?} 2>${stderrF?}
    assertFalse 0.2 $?
}

function testCoreVaultReadPublic() {
    core:import vault
    assertTrue 0.0 $?

    core:wrapper vault read MY_SECRET_1 >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?

    core:wrapper vault read MY_SECRET_111 >${stdoutF?} 2>${stderrF?}
    assertFalse 0.2 $?
}
