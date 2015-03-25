# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
AWS S3 (Simple Storage Service)
[core:docstring]

#. AWS S3 (Simple Storage Service) -={

core:import util
core:import vault

#. aws.s3:uploda -={
function :aws.s3:upload() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 4 ]; then
        e=${CODE_SUCCESS?}

        local key_id="$1"
        local key_secret="$2"
        local bucket="$3"
        local path="$4"

        local content_type="application/octet-stream"
        local date="$(LC_ALL=C date -u +"%a, %d %b %Y %X %z")"
        local md5="$(openssl md5 -binary < "$path" | base64)"
        local sig="$(
            printf "PUT\n${md5}\n${content_type}\n${date}\n/${bucket}/${path}" |
                openssl sha1 -binary -hmac "$key_secret" |
                base64
        )"

        curl -T ${path} http://${bucket}.s3.amazonaws.com/${path} \
            -H "Date: ${date}" \
            -H "Authorization: AWS ${key_id}:${sig}" \
            -H "Content-Type: ${content_type}" \
            -H "Content-MD5: ${md5}"
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function aws.s3:upload:usage() { echo "<cred-vault-id> <bucket> [<file1> [<file2> [...]]]"; }
function aws.s3:upload() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 3 ]; then
        cpf "Requesting credentials from the vault..."
        local cred_vault_id="$1"
        local key_id key_secret
        local aws_api_key
        aws_api_key="$(:vault:read ${cred_vault_id})"
        e=$?
        theme HAS_AUTOED $e

        if [ $e -eq ${CODE_SUCCESS?} ]; then
            IFS=: read key_id key_secret <<< "${aws_api_key}"

            local bucket="$2"
            local file
            for file in "${@:3}"; do
                printf "Uploading ${file} to S3 bucket ${bucket}..."
                :aws_s3:upload "${key_id}" "${key_secret}" "${bucket}" "${file}"
                e=$?
                theme HAS_AUTOED $e
            done
        fi
    fi

    return $e
}
#. }=-

#. }=-
