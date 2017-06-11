# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Core vault and secrets module
[core:docstring]

#. The Vault -={
core:import gpg

core:requires shred

g_VAULT=${SIMBOL_USER_ETC?}/simbol.vault

#. ::vault:getTempFile -={
function ::vault:getTempFile() {
    core:raise_bad_fn_call_unless $# in 2
    echo "${SIMBOL_USER_VAR_TMP?}/${1//\//_}.${2}"
}
#. }=-
#. ::vault:draw -={
#function ::vault:draw() {
#    ${HOME?}/bin/gpg2png $1
#    cp $1.png ~/vault.png
#    cp $1-qr.png ~/g_VAULT-QR.PNG
#    img2txt ~/vault.png ~/g_VAULT-QR.PNG
#}
#. }=-
#. ::vault:clean -={
function ::vault:clean() {
    core:raise_bad_fn_call_unless $# le 1
    local -i e; let e=CODE_FAILURE

    local vault="${1:-${g_VAULT?}}"
    local vault_tmp; vault_tmp="$(::vault:getTempFile "${vault}" killme)"
    local vault_ts; vault_ts="$(::vault:getTempFile "${vault}" timestamp)"
    local vault_bu; vault_bu="$(::vault:getTempFile "${vault}" "${NOW?}")"

    test ! -f "${vault}"     || chmod 600 "${vault}"
    test ! -f "${vault_bu}"  || chmod 400 "${vault_bu}"
    test ! -f "${vault_tmp}" || shred -fuz "${vault_tmp}"
    test ! -f "${vault_ts}"  || shred -fuz "${vault_ts}"

    let e=CODE_SUCCESS

    return $e
}
#. }=-
#.  :vault:encryption -={
function :vault:encryption() {
    core:raise_bad_fn_call_unless $# in 2
    core:raise_bad_fn_call_unless "$2" in on off

    local -i e; let e=CODE_FAILURE

    local vault="${1:-${g_VAULT?}}"
    local vault_tmp; vault_tmp="$(::vault:getTempFile "${vault}" killme)"
    local vault_ts; vault_ts="$(::vault:getTempFile "${vault}" timestamp)"
    local vault_bu; vault_bu="$(::vault:getTempFile "${vault}" "${NOW?}")"

    case $2 in
        on)
            if [ -f "${vault}" ] && :gpg:encrypt "${vault}" "${vault_bu}"; then
                cat "${vault_bu}" > "${vault}"
                let e=$?
            fi
        ;;
        off)
            if [ -f "${vault}" ] && :gpg:decrypt "${vault}" "${vault_bu}"; then
                cat "${vault_bu}" > "${vault}"
                let e=$?
            fi
        ;;
    esac

    return $e
}
#. }=-
#.   vault:encrypt -={
function vault:encrypt:usage() { echo "<file-path:${g_VAULT?}>"; }
function vault:encrypt() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e; let e=CODE_DEFAULT

    local vault="${1:-${g_VAULT?}}"
    cpf "Encrypting %{@path:%s}..." "${vault}"

    if [ -w "${vault}" ]; then
        :vault:encryption "${vault}" on
        let e=$?
        theme HAS_AUTOED $e

        cpf "Shredding remains..."
        ::vault:clean "${vault}"
        theme HAS_AUTOED $?
    else
        let e=CODE_FAILURE
        theme HAS_FAILED "NO_ACCESS/NOT_FOUND"
    fi

    return $e
}
#. }=-
#.   vault:decrypt -={
function vault:decrypt:usage() { echo "<file-path:${g_VAULT?}>"; }
function vault:decrypt() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e; let e=CODE_DEFAULT

    cpf "Decrypting %{@path:%s}..." "${vault}"
    local vault="${1:-${g_VAULT?}}"
    if [ -w "${vault}" ]; then
        :vault:encryption "${vault}" off
        let e=$?
        theme HAS_AUTOED $e

        cpf "Shredding remains..."
        ::vault:clean "${vault}"
        theme HAS_AUTOED $?
    else
        let e=CODE_FAILURE
        theme HAS_FAILED "NO_ACCESS/NOT_FOUND"
    fi

    return $e
}
#. }=-
#.   vault:create -={
function :vault:create() {
    core:raise_bad_fn_call_unless $# in 1

    core:requires pwgen
    local -i e; let e=CODE_FAILURE

    local vault=$1
    if [ ! -f "${vault}" ]; then
        local -i pwid=0
        while read -r pw; do
            let pwid++
            echo "MY_SECRET_${pwid} ${pw}"
        done <<< "$(pwgen 64 7)" | :gpg:encrypt - "${vault}"
        let e=$?
    fi

    return $e
}

function vault:create:usage() { echo "[<vault-path:${g_VAULT}>]"; }
function vault:create() {
    local -i e; let e=CODE_DEFAULT

    cpf "Generating blank secrets file..."
    local vault=${1:-${g_VAULT?}}
    if [ ! -f "${vault}" ]; then
        if :vault:create "${vault}"; then
            let e=CODE_SUCCESS
            theme HAS_PASSED "${vault}"
        else
            theme HAS_FAILED "Failed to create vault \`${vault}'"
            let e=CODE_FAILURE
        fi
    else
        let e=CODE_FAILURE
        theme HAS_FAILED "Vault \`${vault}' already exists"
    fi

    cpf "Shredding remains..."
    ::vault:clean "${vault}"
    theme HAS_AUTOED $?

    return $e
}
#. }=-
#.   vault:list -={
function :vault:list() {
    core:raise_bad_fn_call_unless $# in 1 2
    local -i e; let e=CODE_FAILURE

    local vault="$1"
    if [ -r "${vault}" ]; then
        if [ $# -eq 1 ]; then
            local -a secrets
            if secrets=(
                $(
                    :gpg:decrypt "${vault}" - | awk '$1!~/^[\t ]*#/{print$1}';
                    #shellcheck disable=SC2086
                    exit ${PIPESTATUS[0]}
                )
            ); then
                echo "${secrets[@]}"
                let e=CODE_SUCCESS
            fi
        else
            local sid="${2}"
            local secret
            if secret=$(
                :gpg:decrypt "${vault}" - | awk "\$1~/\<${sid}\>/{print\$1}";
                #shellcheck disable=SC2086
                exit ${PIPESTATUS[0]}
            ) && [ ${#secret} -gt 0 ]; then
                let e=CODE_SUCCESS
            fi
        fi
    else
        let e=9
    fi

    return $e
}

function vault:list:usage() { echo "[<sid>]"; }
function vault:list() {
    local -i e; let e=CODE_DEFAULT
    [ $# -le 1 ] || return $e

    cpf "Inspecting vault..."
    local vault=${g_VAULT?}
    local sid="${1:-}"
    local -a secrets;
    if secrets=( $(:vault:list "${vault}") ); then
        theme HAS_PASSED "${vault}"

        if [ ${#sid} -gt 0 ]; then
            cpf "Checking for SID %{r:%s}..." "${sid}"
            if :vault:list "${vault}" "${sid}"; then
                theme HAS_PASSED
                let e=CODE_SUCCESS
            else
                theme HAS_FAILED
                let e=CODE_FAILURE
            fi
        else
            for sid in "${secrets[@]}"; do
                cpf " * %{r:%s}\n" "${sid}"
            done
            let e=CODE_SUCCESS
        fi
    elif [ $e -eq 9 ]; then
        theme HAS_FAILED "MISSING_VAULT:${vault}"
        let e=CODE_FAILURE
    else
        theme HAS_FAILED "CANNOT_DECRYPT:${vault}"
        let e=CODE_FAILURE
        #. gpg -q --batch --allow-secret-key-import --import ~/.gnupg/ntd.AWS.0xFFFFFFFF.sec
        #. gpg -q --batch --import ~/.gnupg/ntd.AWS.0xFFFFFFFF.pub
    fi

    return $e
}
#. }=-
#.   vault:edit -={
function vault:edit:usage() { echo "[<vault>]"; }
function vault:edit() {
    local -i e; let e=CODE_DEFAULT
    [ $# -le 1 ] || return $e

    local vault="${1:-${g_VAULT?}}"
    local vault_tmp; vault_tmp="$(::vault:getTempFile "${vault}" killme)"
    local vault_ts; vault_ts="$(::vault:getTempFile "${vault}" timestamp)"
    local vault_bu; vault_bu="$(::vault:getTempFile "${vault}" "${NOW?}")"

    mkdir -p "$(dirname "${vault_tmp?}")"

    local org_umask; org_umask="$(umask)"
    umask 377

    cpf "Decrypting secrets..."
    if :gpg:decrypt "${vault}" "${vault_tmp}"; then
        let e=CODE_SUCCESS
        theme HAS_PASSED

        touch "${vault_ts}"
        ${EDITOR:-vim} -n "${vault_tmp}"
        if [ "${vault_tmp?}" -nt "${vault_ts}" ]; then
            cpf "Encrypting secrets..."
            #::vault:draw ${vault_tmp?}
            mv --force "${vault}" "${vault_bu}"
            :gpg:encrypt "${vault_tmp}" "${vault}"
            let e=$?
            theme HAS_AUTOED $e
        fi
    else
        theme HAS_FAILED
    fi

    umask "${org_umask}"

    cpf "Shredding remains..."
    ::vault:clean "${vault}"
    theme HAS_AUTOED $?

    return $e
}

#. }=-
#.   vault:read -={
function :vault:read() {
    core:raise_bad_fn_call_unless $# in 1 2

    local -i e; let e=CODE_FAILURE

    local vault="${g_VAULT?}"
    local sid
    case $# in
        1)
            sid="$1"
        ;;
        2)
            vault="$1"
            sid="$2"
        ;;
    esac

    local secret
    secret="$(:gpg:decrypt "${vault}" - | sed -ne "s/^${sid}\> \+\(.*\)\$/\1/p")"
    if [ ${#secret} -gt 0 ]; then
        printf '%s' "${secret}"
        let e=CODE_SUCCESS
    else
        core:log WARNING "No such sid: ${secret}"
    fi

    return $e
}

function vault:read:usage() { echo "<secret-id> [<vault>]"; }
function vault:read() {
    core:raise_bad_fn_call_unless $# in 1 2
    local -i e; let e=CODE_DEFAULT

    local sid="${1}"
    local vault="${2:-${g_VAULT?}}"

    [ ! -t 1 ] || cpf "Checking for secret id %{r:%s}..." "${sid}"

    local secret
    if secret="$(:vault:read "${vault}" "${sid}")"; then
        if [ -t 1 ]; then
            if :core:requires xclip; then
                printf "%s" "${secret}" | xclip -i
                theme HAS_PASSED "COPIED_TO_CLIPBOARD"
            else
                theme HAS_FAILED "XCLIP_NOT_FOUND"
                let e=CODE_FAILURE
            fi
        else
            theme HAS_PASSED
            printf "%s" "${secret}"
        fi
    else
        theme HAS_FAILED "NO_SUCH_SECRET_ID"
    fi

    return $e
}
#. }=-
#. }=-
