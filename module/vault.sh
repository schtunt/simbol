# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Core vault and secrets module
[core:docstring]

#. The Vault -={
core:import gpg

core:requires pwgen
core:requires shred
core:requires xclip

g_VAULT=${SIMBOL_USER_ETC?}/simbol.vault
g_VAULT_TMP=${SIMBOL_USER_TMP?}/vault.killme
g_VAULT_TS=${SIMBOL_USER_TMP?}/vault.timestamp
g_VAULT_BU=${SIMBOL_USER_TMP?}/vault.$(date +'%Y%m%d')

#. vault:clean -={
#function ::vault:draw() {
#    ${HOME?}/bin/gpg2png $1
#    cp $1.png ~/vault.png
#    cp $1-qr.png ~/g_VAULT-QR.PNG
#    img2txt ~/vault.png ~/g_VAULT-QR.PNG
#}

function ::vault:clean() {
    local -i e=${CODE_SUCCESS?}
    test ! -f ${g_VAULT?}     || chmod 600 ${g_VAULT?}
    test ! -f ${g_VAULT_BU?}  || chmod 400 ${g_VAULT_BU?}
    test ! -f ${g_VAULT_TMP?} || shred -fuz ${g_VAULT_TMP?}
    test ! -f ${g_VAULT_TS?}  || shred -fuz ${g_VAULT_TS?}
    return $e
}
#. DEPRECATED
#function ::vault:secrets() {
#    local -i e=${CODE_FAILURE?}
#
#    if [ $# -eq 1 ]; then
#        ${SIMBOL_CORE_LIBEXEC?}/secret $1
#        e=$?
#    else
#        core:raise EXCEPTION_BAD_FN_CALL
#    fi
#
#    return $e
#}
#. }=-

#. vault:create -={
function :vault:create() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local vault=$1
        if [ ! -f ${vault} ]; then
            local -i pwid=0
            while read pw; do
                let pwid++
                echo MY_SECRET_${pwid}    ${pw}
            done <<< "$(pwgen 64 7)" | :gpg:encrypt - ${vault}
            e=$?
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function vault:create:usage() { echo "[<vault-path:${g_VAULT}>]"; }
function vault:create() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -le 1 ]; then
        cpf "Generating blank secrets file..."
        local vault=${1:-${g_VAULT?}}
        if [ ! -f ${vault} ]; then
            :vault:create ${vault}
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED ${vault}
            else
                theme HAS_FAILED ${vault}
            fi
        else
            e=${CODE_FAILURE?}
            theme HAS_FAILED "${vault} exists"
        fi
    fi

    return $e
}
#. }=-
#. vault:list -={
function :vault:list() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 -o $# -eq 2 ]; then
        local vault="$1"
        local sid="$2"
        if [ -r ${vault} ]; then
            if [ ${#sid} -eq 0 ]; then
                local -a secrets
                secrets=(
                    $(
                        :gpg:decrypt ${vault} - | awk '$1!~/^[\t ]*#/{print$1}';
                        exit ${PIPESTATUS[0]}
                    )
                )
                if [ $? -eq 0 ]; then
                    echo "${secrets[@]}"
                    e=${CODE_SUCCESS?}
                fi
            else
                local secret=$(
                    :gpg:decrypt ${vault} - | awk '$1~/\<'${sid}'\>/{print$1}';
                    exit ${PIPESTATUS[0]}
                )

                if [ $? -eq 0 -a ${#secret} -gt 0 ]; then
                    e=${CODE_SUCCESS?}
                fi
            fi
        else
            e=9
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function vault:list:usage() { echo "[<sid>]"; }
function vault:list() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -le 1 ]; then
        cpf "Inspecting vault..."
        local vault=${g_VAULT?}
        local sid="${1}"
        local -a secrets
        secrets=( $(:vault:list ${vault}) )
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            theme HAS_PASSED ${vault}

            if [ ${#sid} -gt 0 ]; then
                cpf "Checking for SID %{r:%s}..." ${sid}
                if :vault:list ${vault} ${sid}; then
                    theme HAS_PASSED
                    e=${CODE_SUCCESS?}
                else
                    theme HAS_FAILED
                    e=${CODE_FAILURE?}
                fi
            else
                for sid in ${secrets[@]}; do
                    cpf " * %{r:%s}\n" ${sid}
                done
                e=${CODE_SUCCESS?}
            fi
        elif [ $e -eq 9 ]; then
            theme HAS_FAILED "MISSING_VAULT:${vault}"
            e=${CODE_FAILURE?}
        else
            theme HAS_FAILED "CANNOT_DECRYPT:${vault}"
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. vault:edit -={
function vault:edit:usage() { echo "[<vault>]"; }
function vault:edit() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 -o $# -eq 1 ]; then
        local vault="${1:-${g_VAULT?}}"
        mkdir -p $(dirname ${g_VAULT_TMP?})

        cpf "Decrypting secrets..."
        umask 377
        :gpg:decrypt ${g_VAULT?} ${g_VAULT_TMP?}
        e=$?
        theme HAS_AUTOED $e

        if [ $e -eq 0 ]; then
            touch ${g_VAULT_TS?}
            ${EDITOR:-vim} -n ${g_VAULT_TMP?}
            if [ ${g_VAULT_TMP?} -nt ${g_VAULT_TS?} ]; then
                cpf "Encrypting secrets..."
                #::vault:draw ${g_VAULT_TMP?}
                mv --force ${g_VAULT?} ${g_VAULT_BU?}
                :gpg:encrypt ${g_VAULT_TMP?} ${g_VAULT?}
                e=$?
                theme HAS_AUTOED $e
            fi
        fi

        cpf "Shredding remains..."
        ::vault:clean
        theme HAS_AUTOED $?
    fi

    return $e
}

#. }=-
#. vault:read -={
function :vault:read() {
    local -i e=${CODE_FAILURE?}

    local vault="${g_VAULT?}"
    local sid
    if [ $# -eq 1 ]; then
        sid="$1"
    elif [ $# -eq 2 ]; then
        vault="$1"
        sid="$2"
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    local secret
    secret="$(:gpg:decrypt "${vault}" - | sed -ne "s/^${sid}\> \+\(.*\)\$/\1/p")"
    if [ ${#secret} -gt 0 ]; then
        printf '%s' "${secret}"
        e=${CODE_SUCCESS?}
    else
        core:log WARNING "No such sid: ${secret}"
    fi

    return $e
}

function vault:read:usage() { echo "<secret-id> [<vault>]"; }
function vault:read() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 -o $# -eq 2 ]; then
        local sid="${1}"
        local vault="${2:-${g_VAULT?}}"

        [ ! -t 1 ] || cpf "Checking for secret id %{r:%s}..." "${sid}"

        local secret
        secret="$(:vault:read "${vault}" "${sid}")"
        e=$?

        if [ $e -eq 0 ]; then
            if [ -t 1 ]; then
                printf "%s" "${secret}" | xclip -i
                theme HAS_PASSED "COPIED_TO_CLIPBOARD"
            else
                printf "%s" "${secret}"
            fi
        else
            theme HAS_FAILED "NO_SUCH_SECRET_ID"
        fi

    fi

    return $e
}
#. }=-
#. }=-
