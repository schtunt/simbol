# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Core GNUPG module
[core:docstring]

#. GNUPG -={
core:requires gpg2

core:requires ENV SIMBOL_PROFILE
core:requires ENV USER_USERNAME
core:requires ENV USER_FULLNAME
core:requires ENV USER_EMAIL

#. gpg:keypath -={
function ::gpg:keypath() {
    #. Prints:
    #. . -> <path>
    #. * -> <path> <key-id>
    #.
    #. Returns:
    #. CODE_SUCCESS if keys exists
    #. CODE_FAILURE if keys don't exist
    core:raise_bad_fn_call_unless $# in 1

    local -i e=${CODE_FAILURE?}

    local -a data=()
    local gpgkid="${1}"
    local -r gpgkp="${HOME?}/.gnupg/${USER_USERNAME?}.${SIMBOL_PROFILE%%@*}"
    case ${gpgkid}:${#gpgkid} in
        '.':1)
            data=( ${gpgkp} )
            e=${CODE_SUCCESS?}
        ;;
        '*':1)
            local -a files=( ${gpgkp}.* )
            if ! [[ ${files[0]} =~ ${SIMBOL_PROFILE%%@*}\.\*$ ]]; then
                for file in "${files[@]}"; do
                    gpgkid=$(
                        basename ${file} |
                            sed -n -e "s/${USER_USERNAME?}.${SIMBOL_PROFILE%%@*}.\(.*\).sec/\1/p"
                    )
                    if [ ${#gpgkid} -eq 10 ]; then
                        data=( $(::gpg:keypath ${gpgkid}) )
                        e=$?
                        break
                    fi
                done
            fi
        ;;
        *:10)
            if [ -e ${gpgkp}.${gpgkid}.sec -a -e ${gpgkp}.${gpgkid}.pub ]; then
                e=${CODE_SUCCESS?}
                data=( ${gpgkp} ${gpgkid} )

                gpg2 --no-default-keyring \
                    --secret-keyring ${gpgkp}.${gpgkid}.sec\
                    --keyring ${gpgkp}.${gpgkid}.pub\
                    --list-secret-keys >/dev/null 2>&1
                e=$?
            fi
        ;;
    esac

    [ ${#data[@]} -eq 0 ] || echo "${data[@]}"

    return $e
}
#. }=-
#. gpg:kid -={
function ::gpg:kid() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e=${CODE_FAILURE?}

    local gpgkp
    gpgkp=( $(::gpg:keypath "$1") )
    e=$?
    [ $e -ne ${CODE_SUCCESS?} ] || echo "${gpgkp[1]}"

    return $e
}
#. }=-

#. gpg:decrypt -={
function :gpg:decrypt() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local input="${1}"
        local output="${2}"
        local gpgkid=$(::gpg:kid '*')

        if [ -e ${output} ]; then
            core:log WARN "Removed ${output}"
            rm -f "${output}"
        fi
        gpg -q\
            --batch\
            --use-agent\
            --trust-model always\
            --decrypt\
            --default-key ${gpgkid}\
            -o ${output} ${input} 2>/dev/null
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. gpp:encrypt -={
function :gpg:encrypt() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local input="${1}"
        local output="${2}"
        local gpgkid=$(::gpg:kid '*')

        if [ -e ${output} ]; then
            core:log WARN "Removed ${output}"
            rm -f "${output}"
        fi
        gpg -q -a\
            --batch\
            --use-agent\
            --trust-model always\
            --encrypt\
            --recipient ${gpgkid}\
            -o ${output} ${input} 2>/dev/null
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. gpg:create -={
function :gpg:create() {
    core:raise_bad_fn_call_unless $# in 0

    local -i e=${CODE_FAILURE?}

    local -a data
    data=( $(::gpg:keypath '*') )
    if [ ${#data[@]} -eq 0 ]; then
        mkdir -p ~/.gnupg
        chmod 700 ~/.gnupg

        local -i keysize=3072
        local gpgkp
        gpgkp=$(::gpg:keypath '.')
        cat <<! >"${gpgkp}.conf"
Key-Type: RSA
Key-Length: ${keysize}
Subkey-Type: ELG-E
Subkey-Length: ${keysize}
Name-Real: ${USER_FULLNAME?}
Name-Comment: ${USER_USERNAME?} profile key generated via simbol
Name-Email: ${USER_EMAIL?}
Expire-Date: 0
Passphrase: TEMPORARY_PASSPHRASE
%pubring ${gpgkp}.pub
%commit
!
        gpg2 -q --batch --gen-key ${gpgkp}.conf 2>/dev/null |
            sed -e '/^$/d' -e 's/^/   * /' 2>/dev/null
        if [ $? -eq ${CODE_SUCCESS?} ] && [ -e "${gpgkp}.pub" ]; then
            local gpgkid
            gpgkid=0x$(
                gpg2 --no-default-keyring \
                    --keyring ${gpgkp}.pub\
                    --list-secret-keys 2>/dev/null |
                        awk -F '[ /]+' '$1~/^sec/{print$3}'
            )
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                if gpg -q --batch --import ${gpgkp}.pub; then
                    mv ${gpgkp}.pub ${gpgkp}.${gpgkid}.pub
                    mv ${gpgkp}.conf ${gpgkp}.${gpgkid}.conf
                    echo ${gpgkid}
                    e=${CODE_SUCCESS?}
                fi
            fi
        fi

        return $e
        if [ $e -ne ${CODE_SUCCESS?} ]; then
            rm -f ${gpgkp}.pub
            rm -f ${gpgkp}.conf
        fi
    fi

    return $e
}

function gpg:create() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 ]; then
        local gpgkp
        gpgkp=( $(::gpg:keypath '*') )
        e=$?
        if [ ${#gpgkp[@]} -eq 0 ]; then
            cpf "Generating an RSA/ELG-E GPG key for %{@user:%s}@%{@profile:%s}..." "${USER_USERNAME?}" "${SIMBOL_PROFILE%%@*}"
            local gpgkid
            gpgkid=$(:gpg:create)
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED "${gpgkid}"
            else
                theme HAS_FAILED
            fi
        elif [ ${#gpgkp[@]} -eq 2 ]; then
            theme HAS_WARNED "KEY_EXISTS:${gpgkp[1]}"
            e=${CODE_FAILURE?}
        else
            core:raise EXCEPTION_BAD_FN_CALL
        fi
    fi

    return $e
}
#. }=-
#. gpg:delete -={
function :gpg:delete() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local gpgkid=$1
        local -a data
        data=( $(::gpg:keypath "${gpgkid}") )
        if [ ${#data[@]} -eq 2 ]; then
            #. Delete secret keys
            local -a secretkeys=(
                $(
                    gpg --list-secret-keys --with-colons --fingerprint ${gpgkid} |
                        sed -n 's/^fpr:::::::::\([[:alnum:]]\+\):/\1/p'
                )
            )

            local sk
            for sk in "${secretkeys[@]}"; do
                gpg --batch --yes --delete-secret-key "${sk}"
            done

            #. Delete publik key
            gpg -q --batch --yes --delete-key ${gpgkid}

            #. Delete files
            local gpgkp
            gpgkp="${data[0]}.${gpgkid}"
            rm -f "${gpgkp}.sec"
            rm -f "${gpgkp}.pub"
            rm -f "${gpgkp}.conf"

            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function gpg:delete:usage() { echo "<gpg-key-id>"; }
function gpg:delete() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local gpgkid=$1
        cpf "Removing GPG key %{@hash:${gpgkid}}..."

        :gpg:delete ${gpgkid}
        e=$?
        if [ $e -eq ${CODE_SUCCESS?} ]; then
            theme HAS_PASSED "${gpgkid}"
        else
            theme HAS_FAILED "${gpgkid}"
        fi
    fi

    return $e
}
#. }=-
#. gpg:list -={
function :gpg:list() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -a data
        data=( $(::gpg:keypath "${1}") )
        e=$?
        if [ ${#data[@]} -eq 2 ]; then
            echo "${data[@]}"
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function gpg:list:usage() { echo "[<gpg-key-id>]"; }
function gpg:list() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -le 1 ]; then
        local data
        data=$(:gpg:list "${1:-*}")
        e=$?

        read -r gpgkp gpgkid <<< "${data[@]}"
        cpf "Inspecting GPG Key..."
        if [ $e -eq ${CODE_SUCCESS?} ]; then
            theme HAS_PASSED "${gpgkid}"
        else
            theme HAS_FAILED "NO_KEYS"
        fi
    fi

    return $e
}
#. }=-
#. }=-
