# vim: tw=0:ts=4:sw=4:et:ft=bash
#shellcheck disable=SC2166,SC2119,SC2120

:<<[core:docstring]
Core GNUPG module
[core:docstring]

#. GNUPG -={
core:requires ANY gpg2 gpg

core:requires ENV SIMBOL_PROFILE
core:requires ENV USER_USERNAME
core:requires ENV USER_FULLNAME
core:requires ENV USER_EMAIL

#shellcheck disable=SC2086
: ${GNUPGHOME:="${HOME}/.gnupg"}
core:requires ENV GNUPGHOME

declare -g gpg_bin
gpg_bin="$(which gpg2)" || gpg_bin="$(which gpg)"

#. :gpg:version -={
function :gpg:version() {
    core:raise_bad_fn_call_unless $# in 0

    local -i e; let e=CODE_FAILURE

    local gpg_version;
    if gpg_version="$(${gpg_bin} --version | head -n 1 | cut -d' ' -f3)"; then
        case "${gpg_version}" in
            2.*)
                echo "${gpg_version// /.}"
                let e=CODE_SUCCESS
            ;;
            *)
                theme HAS_FAILED "GnuPG version not supported (v${gpg_version// /.})"
            ;;
        esac
    fi

    return $e
}

#. }=-
#. ::gpg:keypath -={
function ::gpg:keypath() {
    core:raise_bad_fn_call_unless $# in 0

    echo "${GNUPGHOME:-${HOME?}/.gnupg}/${USER_USERNAME?}.${SIMBOL_PROFILE%%@*}"
}
#. }=-
#. ::gpg:keyid -={
function ::gpg:keyid() {
    core:raise_bad_fn_call_unless $# in 1
    sed -E -e 's/.*\.(0x[0-9A-F]+).conf/\1/' <<< "$1"
}
#. }=-
#. ::gpg:keys.eval -={
function ::gpg:keys.eval() {
    #. Usage: <bash-assoc-array-name> [*|<gpg-key-id>]
    #. Returns:
    #. - CODE_SUCCESS if keys exists
    #. - CODE_FAILURE if no keys exist
    core:raise_bad_fn_call_unless $# in 1 2

    local -i e; let e=CODE_FAILURE

    local gpgkid="${2:-*}"

    local -r gpgkp="$(::gpg:keypath)"
    case ${gpgkid}:${#gpgkid} in
        '*':1)
            set +f; local -a files=( ${gpgkp}.* ); set -f
            if ! [[ ${files[0]} =~ ${SIMBOL_PROFILE%%@*}\.\*$ ]]; then
                for file in "${files[@]}"; do
                    gpgkid=$(
                        basename "${file}" |
                            sed -n -e "s/${USER_USERNAME?}.${SIMBOL_PROFILE%%@*}.\(.*\).pub/\1/p"
                    )
                    if [ ${#gpgkid} -eq 10 ]; then
                        if ::gpg:keys.eval "$1" "${gpgkid}"; then
                            let e=CODE_SUCCESS
                            break
                        fi
                    fi
                done
            fi
        ;;
        *:10)
            if [ -e "${gpgkp}.${gpgkid}.pub" ]; then
                echo "local -A $1"
                echo "$1[${gpgkid}]=\"${gpgkp}.${gpgkid}\""

                ${gpg_bin} --no-default-keyring \
                    --secret-keyring "${gpgkp}.${gpgkid}.sec"\
                    --keyring "${gpgkp}.${gpgkid}.pub"\
                    --list-secret-keys >&/dev/null
                let e=$?
            fi
        ;;
    esac

    #shellcheck disable=SC2086
    [ $e -eq ${CODE_SUCCESS?} ] || echo "local -A $1=()"
    return $e
}
#. }=-

#. gpg:create -={
function :gpg:create() {
    core:raise_bad_fn_call_unless $# in 0

    [ "${USER_VAULT_PASSPHRASE:-NilOrNotSet}" != "NilOrNotSet" ] ||
        core:raise EXCEPTION_BAD_FN_CALL "USER_VAULT_PASSPHRASE was not set"

    local -i e; let e=CODE_FAILURE

    eval "$(::gpg:keys.eval 'data' '*')"
    [ ${#data[@]} -eq 0 ] || return $e

    mkdir -p "${GNUPGHOME}"
    chmod 700 "${GNUPGHOME}"

    if [ "${SIMBOL_PROFILE}" == "UNITTEST" ]; then
        passphrase_setting="Passphrase: ${USER_VAULT_PASSPHRASE}"
    else
        passphrase_setting="%ask-passphrase"
    fi
    local -i keysize=3072
    local gpgkp; gpgkp="$(::gpg:keypath)"
    cat <<! >"${gpgkp}.conf"
Key-Type: RSA
Key-Length: ${keysize}
Subkey-Type: ELG-E
Subkey-Length: ${keysize}
Name-Real: ${USER_FULLNAME?}
Name-Comment: ${USER_USERNAME?} profile key generated via simbol
Name-Email: ${USER_EMAIL?}
Expire-Date: 0
${passphrase_setting}
%pubring ${gpgkp}.pub
%secring ${gpgkp}.sec
%commit
!
    "${gpg_bin}" -q --batch --gen-key "${gpgkp}.conf" 2>/dev/null |
        sed -e '/^$/d' -e 's/^/   * /' 2>/dev/null
    #shellcheck disable=SC2086
    if [ $? -eq ${CODE_SUCCESS?} ] && [ -e "${gpgkp}.pub" ]; then
        local gpgkid
        gpgkid="0x$(
            ${gpg_bin} --no-default-keyring \
                --keyring "${gpgkp}.pub"\
                --keyid-format short\
                --list-keys 2>/dev/null |
                    awk -F '[ /]+' '$1~/^pub/{print$3}'
        )"
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            if ${gpg_bin} -q --batch --import "${gpgkp}.pub"; then
                mv "${gpgkp}.pub" "${gpgkp}.${gpgkid}.pub"
                local gpg_version=$(:gpg:version)
                local major minor
                read major minor _<<<"${gpg_version//./ }"

                case "${major}.${minor}" in
                    2.0)
                        if ${gpg_bin} -q --batch --import "${gpgkp}.sec"; then
                            mv "${gpgkp}.sec" "${gpgkp}.${gpgkid}.sec"
                        else
                            core:raise EXCEPTION_SHOULD_NOT_GET_HERE
                        fi
                        ;;
                esac
                mv "${gpgkp}.conf" "${gpgkp}.${gpgkid}.conf"
                echo "${gpgkid}"
                let e=CODE_SUCCESS
            fi
        fi
    fi

    #shellcheck disable=SC2086
    if [ $e -ne ${CODE_SUCCESS?} ]; then
        rm -f "${gpgkp}.pub"
        rm -f "${gpgkp}.sec"
        rm -f "${gpgkp}.conf"
    fi

    return $e
}
function gpg:create() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 0 ] || return $e

    cpf "Generating an RSA/ELG-E GPG key for %{@user:%s}@%{@profile:%s}..." "${USER_USERNAME?}" "${SIMBOL_PROFILE%%@*}"
    eval "$(::gpg:keys.eval 'data' '*')"
    if [ ${#data[@]} -eq 0 ]; then
        local gpgkid
        if gpgkid=$(:gpg:create); then
            let e=CODE_SUCCESS
            theme HAS_PASSED "${gpgkid}"
        else
            theme HAS_FAILED
        fi
    else
        #shellcheck disable=SC2154
        theme HAS_WARNED "KEY_EXISTS:${!data[*]}"
        let e=CODE_FAILURE
    fi

    return $e
}
#. }=-
#. gpg:list -={
function :gpg:list() {
    core:raise_bad_fn_call_unless $# in 1

    local gpgkid="$1"
    eval "$(::gpg:keys.eval 'data' "${gpgkid}")"
    #shellcheck disable=SC2086
    [ ${#data[@]} -gt 0 ] || return ${CODE_FAILURE?}

    echo "${!data[@]}"
    #shellcheck disable=SC2086
    return ${CODE_SUCCESS?}
}
function gpg:list:usage() { echo "[<gpg-key-id>]"; }
function gpg:list() {
    local -i e; let e=CODE_DEFAULT
    [ $# -le 1 ] || return $e

    let e=CODE_SUCCESS

    cpf "Inspecting GPG Key..."

    local data
    if data="$(:gpg:list "${1:-*}")"; then
        theme HAS_PASSED "${data}"
    else
        if [ $# -eq 0 ]; then
            theme HAS_WARNED "NO_KEYS"
        else
            theme HAS_FAILED "NO_SUCH_KEY"
            let e=CODE_FAILURE
        fi
    fi

    return $e
}
#. }=-
#. gpg:delete -={
function :gpg:delete() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e; let e=CODE_FAILURE
    local gpgkid="$1"

    eval "$(::gpg:keys.eval 'data' "${gpgkid}")"
    [ ${#data[@]} -gt 0 ] || return $e

    #. Delete secret keys
    local -a secretkeys
    secretkeys=(
        #. Note: Why head -n 1
        #. gpg >= 2.1 also prints out the fingerprint of ssb
        $(
            ${gpg_bin} --list-secret-keys --with-colons --fingerprint "${gpgkid}" 2>/dev/null |
                sed -n 's/^fpr:::::::::\([[:alnum:]]\+\):/\1/p' |
                head -n 1
        )
    )
    let e=$?
    #shellcheck disable=SC2086
    if [ $e -eq ${CODE_SUCCESS} -a "${secretkeys:-NilOrNotSet}" != "NilOrNotSet" ]; then
        local sk
        for sk in "${secretkeys[@]}"; do
            if ! ${gpg_bin} --batch --yes --delete-secret-key "${sk}" 2>/dev/null; then
                e=${CODE_FAILURE?}
                core:log WARNING "Could not delete secret key ${gpgkid}."
            fi
        done
    else
        let e=CODE_FAILURE
        core:log WARNING "There is no secret key ${gpgkid} to delete."
    fi

    #. Delete public key
    if ! ${gpg_bin} -q --batch --yes --delete-key "${gpgkid}" 2>/dev/null; then
        let e=CODE_FAILURE
        core:log WARNING "There is no public key ${gpgkid} to delete"
    fi

    #. Delete files
    local gpgkp; gpgkp="${data[${gpgkid}]}"
    rm -f "${gpgkp}.sec" || core:log WARNING "There is no ${gpgkp}.sec to delete."
    rm -f "${gpgkp}.pub" || core:log WARNING "There is no ${gpgkp}.pub to delete."
    rm -f "${gpgkp}.conf" || core:log WARNING "There is no ${gpgkp}.conf to delete"

    if [ -e "${gpgkp}.${gpgkid}.sec" -o -e "${gpgkp}.${gpgkid}.pub" -o -e "${gpgkp}.${gpgkid}.conf" ]; then
        let e=CODE_FAILURE
    fi

    return $e
}

function gpg:delete:usage() { echo "<gpg-key-id>"; }
function gpg:delete() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 1 ] || return $e

    local gpgkid=$1
    cpf "Removing GPG key ${gpgkid}..."

    if :gpg:delete "${gpgkid}"; then
        let e=CODE_SUCCESS
        theme HAS_PASSED "${gpgkid}"
    else
        theme HAS_FAILED "${gpgkid}. Check ${SIMBOL_LOG}"
    fi

    return $e
}
#. }=-

#. gpp:encrypt -={
function :gpg:encrypt() {
    core:raise_bad_fn_call_unless $# in 2

    local -i e; let e=CODE_FAILURE

    local input="${1}"
    local output="${2}"
    eval "$(::gpg:keys.eval 'data' '*')"
    #shellcheck disable=SC2086
    if [ ${#data[@]} -ne 1 ]; then
        core:log ERR "GPG default recipient not found."
    else
        if [ -e "${output}" ]; then
            core:log WARNING "Removing ${output}"
            rm -f "${output}"
        fi

        local gpgkid="${!data[*]}"
        ${gpg_bin} -q -a\
            --batch\
            --trust-model always\
            --encrypt\
            --recipient "${gpgkid}"\
            -o "${output}" "${input}" 2>/dev/null
        let e=$?
    fi

    return $e
}
#. }=-
#. gpg:decrypt -={

#shellcheck disable=SC2119
function :gpg:decrypt() {
    core:raise_bad_fn_call_unless $# in 2
    local -i e; let e=CODE_FAILURE

    local input="$1"
    local output="$2"
    local gpg_version=$(:gpg:version)
    eval "$(::gpg:keys.eval 'data' '*')"
    local -r gpgkp="$(::gpg:keypath)"

    #shellcheck disable=SC2086
    if [ ${#data[@]} -ne 1 ]; then
        core:log ERR "GPG default recipient not found."
    else
        if [ -e "${output}" ]; then
            core:log WARNING "Removed ${output}"
            rm -f "${output}"
        fi

        local gpgkid="${!data[*]}"
        local options=""
        local major minor release
        read major minor release <<<"${gpg_version//./ }"

        case "${major}.${minor}" in
            2.0) options="--secret-keyring ${gpgkp}.${gpgkid}.sec";;
            2.1)
                if [ $release -ge 15 ]; then
                    options="--pinentry-mode loopback"
                fi
                ;;
            *) core:raise EXCEPTION_SHOULD_NOT_GET_HERE ;;
        esac
        if [ "${SIMBOL_PROFILE}" == "UNITTEST" ]; then
            options+=" --passphrase ${USER_VAULT_PASSPHRASE:-N/A}"
        fi

        ${gpg_bin} -q\
            --yes \
            --batch\
            --trust-model always\
            --decrypt\
            --default-key "${gpgkid}" ${options}\
            -o "${output}" "${input}" 2>/dev/null
        e=$?
    fi

    return $e
}
#. }=-
#. }=-
