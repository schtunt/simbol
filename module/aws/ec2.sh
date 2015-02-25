# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
AWS EC2 (Elastic Cloud Compute)
[core:docstring]

#. AWS EC2 (Elastic Compute Cloud) -={

core:import util
core:import py
core:import net

AWS_DEFAULT_REGION="${USER_AWS_DEFAULT_REGION:-us-east-1}"

#. aws.ec2:selfcheck -={
function aws.ec2:selfcheck() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 ]; then
        e=${CODE_SUCCESS?}

        cpf "Dependency check..."
        local dep
        for dep in boto awscli dateutils jmespath docutils rsa; do
            if :xplm:requires py ${dep}; then
                cpf '.'
            else
                cpf '![%s]' "${dep}"
                e=${CODE_FAILURE?}
            fi
        done
        cpf '...'

        theme HAS_AUTOED $e
    fi
}
#. }=-
#. aws.ec2:describe -={
function aws.ec2:describe:usage() {
    cat <<!
  ltree | ptree | vpc | region [<region>]
( ltree | ptree | vpc | az | i | igw ) <region>
!
}
function aws.ec2:describe() {
    local -i e=${CODE_DEFAULT?}

    local subcmd="$1"
    case ${subcmd}:$# in
        #. Global Physical Queries
        region:1) #. -={
            py:run aws --region='us-east-1' ec2 describe-regions |
                jq -c  '.Regions[]|[ .RegionName, .Endpoint ]'
            e=${PIPESTATUS[0]}
        ;; #. }=-

        #. Regional Physical Queries
        ptree:[12]) #. -={
            e=${CODE_SUCCESS?}

            cpf "Gathering data..."

            local regions
            regions=$(py:run aws --region="${2:-us-west-1}" ec2 describe-regions | jq '.Regions[]')
            [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'
            if [ $# -eq 2 ]; then
                regions=$(jq "select(.RegionName == \"${2}\")" <<< "${regions}")
                [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'
            fi

            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED

                local region
                for region in $(jq -c  '.RegionName' <<< "${regions}"); do
                    region=${region//\"/}
                    cpf "+ %{y:%s}..." ${region}

                    local subnets
                    subnets=$(py:run aws --region="${region}" ec2 describe-subnets | jq '.Subnets[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    local zones
                    zones=$(py:run aws --region="${region}" ec2 describe-availability-zones |  jq '.AvailabilityZones[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    local instances
                    instances=$(py:run aws --region="${region}" ec2 describe-instances | jq '.Reservations[].Instances[]' )
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    if [ $e -eq ${CODE_SUCCESS?} ]; then
                        theme HAS_PASSED
                        local az
                        for az in $(jq -c '.ZoneName' <<< "${zones}"); do
                            az=${az//\"/}
                            cpf "   \\___ %{y:%s}..." ${az}
                            jq -c "select(.ZoneName == \"${az}\")" <<< "${zones}"

                            local subnet
                            for subnet in $(jq -c "select(.AvailabilityZone == \"${az}\")|.SubnetId" <<< "${subnets}"); do
                                subnet=${subnet//\"/}
                                cpf "      \\___ %{@subnet:%s}..." ${subnet}
                                jq -c "select(.SubnetId == \"${subnet}\")" <<< "${subnets}"

                                local instance
                                for instance in $(jq -c "select(.SubnetId == \"${subnet}\")|.InstanceId" <<< "${instances}"); do
                                    instance=${instance//\"/}
                                    cpf "         \\___ %{@host:%s}..." ${instance}
                                    jq -c "select(.InstanceId == \"${instance}\")|.State.Name" <<< "${instances}"
                                done
                            done
                        done
                    else
                        theme HAS_FAILED
                    fi
                done
            else
                theme HAS_FAILED
            fi
        ;; #. }=-
        subnet:2) #. -={
            local region="$2"
            py:run aws --region="${region}" ec2 describe-subnets |
                jq -c  '.Subnets[]'
            e=${PIPESTATUS[0]}
        ;; #. }=-
        az:2) #. -={
            local region="$2"
            py:run aws --region="${region}" ec2 describe-availability-zones |
                jq -c  '.AvailabilityZones[]'
            e=${PIPESTATUS[0]}
        ;; #. }=-
        i:2) #. -={
            local region="$2"
            py:run aws --region="${region}" ec2 describe-instances |
                jq -c '.Instances[]?'
            e=${PIPESTATUS[0]}
        ;; #. }=-

        #. Logical Queries
        ltree:[12]) #. -={
            e=${CODE_SUCCESS?}

            cpf "Gathering data..."

            local regions
            regions=$(py:run aws --region="${2:-us-west-1}" ec2 describe-regions | jq '.Regions[]')
            [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'
            if [ $# -eq 2 ]; then
                regions=$(jq "select(.RegionName == \"${2}\")" <<< "${regions}")
                [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'
            fi

            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED

                local region
                for region in $(jq -c  '.RegionName' <<< "${regions}"); do
                    region=${region//\"/}
                    cpf "+ %{y:%s}..." ${region}

                    local igws
                    igws=$(py:run aws --region="${region}" ec2 describe-internet-gateways | jq '.InternetGateways[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    local vpcs
                    vpcs=$(py:run aws --region="${region}" ec2 describe-vpcs | jq -c '.Vpcs[]')
                    if [ $? -eq ${CODE_SUCCESS?} ]; then
                        theme HAS_PASSED
                        local vpc
                        for vpc in $(jq '.VpcId' <<< "${vpcs}"); do
                            vpc="${vpc//\"/}"
                            cpf "   \\___ %{y:%s}..." ${vpc}
                            jq -c "select(.VpcId == \"${vpc}\")" <<< "${vpcs}"

                            local igw
                            for igw in $(jq -c "select(.Attachments[].VpcId == \"${vpc}\")|.InternetGatewayId" <<< "${igws}"); do
                                igw=${igw//\"/}
                                cpf "      \\___ %{@host:%s}..." ${igw}
                                jq -c "select(.InternetGatewayId == \"${igw}\") | .Attachments" <<< "${igws}"
                            done
                        done
                    fi
                done
                e=${PIPESTATUS[0]}
            fi
        ;; #. }=-
        igw:2) #. -={
            local region="$2"
            py:run aws --region="${region}" ec2 describe-internet-gateways |
                jq -c  '.InternetGateways[]'
            e=${PIPESTATUS[0]}
        ;; #. }=-
        vpc:[12]) #. -={
            e=${CODE_SUCCESS?}

            cpf "Gathering data..."

            local regions
            regions=$(py:run aws --region="${2:-us-east-1}" ec2 describe-regions | jq '.Regions[]')
            [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'
            if [ $# -eq 2 ]; then
                regions=$(jq "select(.RegionName == \"${2}\")" <<< "${regions}")
                [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'
            fi

            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED

                local region
                for region in $(jq -c  '.RegionName' <<< "${regions}"); do
                    region=${region//\"/}
                    cpf "+ %{y:%s}..." ${region}

                    local vpcs
                    vpcs=$(py:run aws --region="${region}" ec2 describe-vpcs | jq -c '.Vpcs[]')
                    if [ $? -eq ${CODE_SUCCESS?} ]; then
                        theme HAS_PASSED
                        local vpc
                        for vpc in $(jq '.VpcId' <<< "${vpcs}"); do
                            vpc="${vpc//\"/}"
                            cpf "   \\___ %{y:%s}..." ${vpc}
                            jq -c "select(.VpcId == \"${vpc}\")" <<< "${vpcs}"
                        done
                    fi
                done
                e=${PIPESTATUS[0]}
            fi
        ;; #. }=-
    esac

    return $e
}
#. }=-
#. aws.ec2:vpc -={
function aws.ec2:vpc:usage() {
    cat <<!
create <cidr>
create-subnet <vpc> <cidr> <region> <az>
!
}
function aws.ec2:vpc() {
    local -i e=${CODE_DEFAULT?}

    local subcmd="$1"
    case ${subcmd}:$# in
        create:2)
            local cidr="$2"
            py:run aws ec2 create-vpc --cidr="${cidr}" |
                jq '.'
            e=${PIPESTATUS[0]}
        ;;
        create-subnet:5)
            local vpc="$2"
            local cidr="$3"
            local region="$4"
            local az="$5"
            py:run aws --region="${region}" ec2 create-subnet --vpc="${vpc}" --cidr="${cidr}" --availability-zone=${az} |
                jq '.'
            e=${PIPESTATUS[0]}
        ;;
        list:1)
            local cidr="$2"
            py:run aws ec2 describe-vpcs |
                jq -c '.Vpcs[]'
            e=${PIPESTATUS[0]}
        ;;
    esac

    return $e
}
#. }=-
#. aws.ec2:i -={
function aws.ec2:i:shflags() {
    cat <<!
string region ${AWS_DEFAULT_REGION?} aws-default-region r
!
}
function aws.ec2:i:usage() { echo "list|screendump <instance-id>"; }
function aws.ec2:i() {
    local -i e=${CODE_DEFAULT?}

    local region=${FLAGS_region:-${AWS_DEFAULT_REGION?}}; unset FLAGS_region

    local subcmd="$1"
    case ${subcmd}:$# in
        attr:1)
            py:run aws --region="${region}" ec2 describe-account-attributes |
                jq -c  '.AccountAttributes[]|[ .AttributeName, (.AttributeValues[]|.AttributeValue) ]'
            e=${PIPESTATUS[0]}
        ;;
        list:1)
            py:run aws --region="${region}" ec2 describe-instances |
                jq -c '.Reservations[].Instances[]|[.InstanceId,.PublicDnsName,.ImageId,.State.Name,.SecurityGroups[].GroupId,.SecurityGroups[].GroupName]'
            e=${PIPESTATUS[0]}
        ;;
        screendump:2)
            local iid=$2

            e=${CODE_FAILURE?}

            local dump
            dump=$(py:run aws --region="${region}" ec2 get-console-output --instance-id ${iid} | jq -e '.Output' | tr -d '\040-\042')
            e=$?
            echo -e "${dump}"
        ;;
    esac

    return $e
}
#. }=-
#. aws.ec2:sg -={
function aws.ec2:sg:usage() { echo "list|apply <instance> <sgs>"; }
function aws.ec2:sg() {
    local -i e=${CODE_DEFAULT?}

    local subcmd="$1"
    case ${subcmd}:$# in
        list:1)
            py:run aws ec2 describe-security-groups |
                jq -e -c '.SecurityGroups[]|[.GroupId,.GroupName]'
            e=$?
        ;;
        apply:3)
            local instance="$2"
            local sgs="${3}"
            py:run aws ec2 modify-instance-attribute\
                --instance-id "${instance}"\
                --groups "$(:util:listify ${sgs})"
        ;;
    esac

    return $e
}
#. }=-
#. aws.ec2:acl -={
function aws.ec2:acl:usage() { echo "check|create|delete"; }
function aws.ec2:acl() {
    local -i e=${CODE_DEFAULT?}
    local secgrp="SG:simbol/${SIMBOL_PROFILE}/${USER_USERNAME}/SSHOnly"
    local subcmd="$1"
    local myip
    case $#:${subcmd} in
        1:check)
            cpf "Your public IP address..."
            myip=$(:net:myip)
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED "${myip}/32"

                cpf "Testing ACL for ssh access from ${myip}/32..."
                local ip
                ip=$(py:run aws ec2 describe-security-groups |
                    jq -e '
                        .SecurityGroups[]
                        |   select(.GroupName == "'${secgrp}'" )
                        |   .IpPermissions[].IpRanges[].CidrIp
                    '
                )
                e=$?
                theme HAS_AUTOED $e "${secgrp}"
            else
                theme HAS_FAILED "NO_INTERNET"
            fi
        ;;
        1:create)
            cpf "Your public IP address..."
            myip=$(:net:myip)
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED "${myip}/32"

                cpf "Creating a rule for ${myip}/32..."
                py:run aws ec2 create-security-group \
                    --group-name "${secgrp}" \
                    --description "/inbound/ssh/src:${myip}" >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    py:run aws ec2 authorize-security-group-ingress \
                        --group-name "${secgrp}" \
                        --cidr "${myip}/32" \
                        --protocol tcp --port 22 >/dev/null 2>&1
                    e=$?
                else
                    e=${CODE_FAILURE?}
                fi
                theme HAS_AUTOED $e "${secgrp}"
            else
                theme HAS_FAILED "NO_INTERNET"
            fi
        ;;
        1:delete)
            cpf "Your public IP address..."
            myip=$(:net:myip)
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED "${myip}/32"

                cpf "Deleting rule for ${myip}/32..."
                py:run aws ec2 delete-security-group \
                    --group-name "${secgrp}" &>/dev/null
                e=$?
                theme HAS_AUTOED $e
            else
                theme HAS_FAILED "NO_INTERNET"
            fi
        ;;
    esac

    return $e
}
#. }=-

#. }=-
