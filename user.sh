#!/bin/bash

function userman() {
    local -i e=1

    if [ $# -eq 2 ]; then
        local action=$1
        local user=$2

        declare -a profiles=(
            $(grep -oE '^\[(.*)\]$' ~/.aws/credentials)
        )

        for profile in "${profiles[@]}"; do
            profile=${profile:1:-1}

            local userdata="$(aws iam --profile=${profile} get-user --user-name="${user}" 2>/dev/null)"
            if [ ${#userdata} -gt 0 ]; then
                echo "### ${user}@${profile} ###"
                case $action in
                    freeze|deactivate|delete|purge)
                        echo "#. Stage 1 of 4 (Freeze) -={"

                        #. Delete Keys
                        echo aws --profile=${profile} iam delete-access-key --user-name=${user}

                        #. Delete Certs
                        echo aws --profile=${profile} iam delete-signing-certificate --user-name=${user}

                        echo "#. }=-"
                        e=0
                    ;;
                esac

                case $action in
                    deactivate|delete|purge)
                        echo "#. Stage 2 of 4 (Deactivate) -={"

                        #. Delete the user's password, if the user has one.
                        echo aws --profile=${profile} iam delete-login-profile --user-name=${user}

                        #. Deactivate the user's MFA device, if the user has one.
                        echo aws --profile=${profile} iam deactivate-mfa-device --user-name=${user}

                        echo "#. }=-"
                    ;;
                esac

                case $action in
                    delete|purge)
                        echo "#. Stage 3 of 4 (Delete) -={"

                        #. Detach any policies that are attached to the user.
                        local policies=$(aws --profile=${profile} iam list-attached-user-policies --user-name=${user}|jq '.AttachedPolicies[]')
                        for policy in $(jq '.PolicyName' <<< "${policies}"); do
                            policy=${policy//\"/}
                            arn="$(jq "select(.PolicyName==\"${policy}\")|.PolicyArn" <<< "${policies}")"
                            echo aws --profile=${profile} iam detach-user-policy --polict-arn="${arn}" --user-name="${user}" echo "#. removed from policy ${policy}"
                        done

                        #. Get a list of any groups the user was in, and remove the user from those groups.
                        local groups=$(aws --profile="${profile}" iam list-groups-for-user --user-name="${user}"|jq '.Groups[]')
                        for group in $(jq ".GroupName" <<< "${groups}"); do
                            group=${group//\"/}
                            arn="$(jq "select(.GroupName==\"${group}\")|.Arn" <<< "${groups}")"
                            echo aws --profile="${profile}" iam remove-user-from-group --group=arn="${arn}" --user-name="${user}" "#. removed from group ${group}"
                        done

                        echo "#. }=-"
                    ;;
                esac

                case $action in
                    purge)
                        echo "#. Stage 4 of 4 (Purge) -={"

                        #. Delete the user.
                        echo aws --profile="${profile}" iam delete-user --user-name="${user}"

                        echo "#. }=-"
                    ;;
                esac
            else
                echo "### ${user}@${profile} - No such user ###"
            fi
        done
    fi

    return $e
}


let e=9

if [ $# -eq 2 ]; then
    action=$1
    case ${action} in
        freeze|deactivate|delete|purge)
            user=$2
            userman ${action} ${user}
            e=$?
        ;;
    esac
fi

if [ $e -eq 9 ]; then
    echo "Usage: $(basename $0) freeze|deactivate|delete|purge <username>"
fi

exit $e
