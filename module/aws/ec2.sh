# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
AWS EC2 (Elastic Cloud Compute)
[core:docstring]

#. AWS EC2 (Elastic Compute Cloud) -={

core:import util
core:import py
core:import net

AWS_DEFAULT_REGION="${USER_AWS_DEFAULT_REGION:-us-east-1}"

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
                            cpf "${INDENT_STR}%{y:%s}..." ${az}
                            jq -c "select(.ZoneName == \"${az}\")" <<< "${zones}"

                            local subnet
                            for subnet in $(jq -c "select(.AvailabilityZone == \"${az}\")|.SubnetId" <<< "${subnets}"); do
                                subnet=${subnet//\"/}
                                cpf "${INDENT_STR}%{@subnet:%s}..." ${subnet}
                                jq -c "select(.SubnetId == \"${subnet}\")" <<< "${subnets}"

                                local instance
                                for instance in $(jq -c "select(.SubnetId == \"${subnet}\")|.InstanceId" <<< "${instances}"); do
                                    instance=${instance//\"/}
                                    cpf "${INDENT_STR}%{@host:%s}..." ${instance}
                                    jq -c "select(.InstanceId == \"${instance}\")|[.InstanceType,.State.Name,.PublicDnsName]" <<< "${instances}"
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

            local raw
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED

                local region
                for region in $(jq -c  '.RegionName' <<< "${regions}" | tr -d '"'); do
                    cpf "${INDENT_STR?}%{y:%s}..." ${region}

                    local igws
                    igws=$(py:run aws --region="${region}" ec2 describe-internet-gateways | jq '.InternetGateways[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    local rts
                    rts=$(py:run aws --region="${region}" ec2 describe-route-tables | jq '.RouteTables[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    local subnets
                    subnets=$(py:run aws --region="${region}" ec2 describe-subnets | jq -c '.Subnets[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    local vpcs
                    vpcs=$(py:run aws --region="${region}" ec2 describe-vpcs | jq -c '.Vpcs[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    local instances
                    instances=$(py:run aws --region="${region}" ec2 describe-instances | jq '.Reservations[].Instances[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    local interfaces
                    interfaces=$(py:run aws --region="${region}" ec2 describe-network-interfaces | jq '.NetworkInterfaces[]')
                    [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                    if [ $e -eq ${CODE_SUCCESS?} ]; then -{
                        theme HAS_PASSED
                        cpf "${INDENT_STR}%{@version:%s}...\n" "Amazon VPC"

                        local vpc
                        for vpc in $(jq '.VpcId' <<< "${vpcs}" | tr -d '"'); do -{
                            local name=$(jq -c "select(.VpcId==\"${vpc}\")|.Tags[]|select(.Key==\"Name\")|.Value" <<< "${vpcs}" 2>/dev/null | tr -d '"')
                            cpf "${INDENT_STR}%{@key:%s} (%{@name:%s})..." ${vpc} "${name:-n/a}"
                            jq -c "select(.VpcId == \"${vpc}\")|{\"cidr\":.CidrBlock,\"state\":.State}" <<< "${vpcs}"

                            local igw
                            for igw in $(jq -c "select(.Attachments[].VpcId == \"${vpc}\")|.InternetGatewayId" <<< "${igws}" | tr -d '"'); do -{
                                local name=$(jq -c "select(.InternetGatewayId==\"${igw}\")|.Tags[]|select(.Key==\"Name\")|.Value" <<< "${igws}" 2>/dev/null | tr -d '"')
                                cpf "${INDENT_STR}%{@key:%s} (%{@name:%s})...\n" ${igw} "${name:-n/a}"

                                for raw in $(jq -c "select(.VpcId==\"${vpc}\")|.Routes[]|select(.GatewayId==\"${igw}\")|.DestinationCidrBlock+\",\"+.GatewayId" <<< "${rts}" | tr -d '"'); do -{
                                    IFS=, read cidr gw <<< "${raw}"
                                    cpf "${INDENT_STR}%{@key:routes}: %{@subnet:%s} via %{@host:%s}\n" "${cidr}" "${gw}"
                                }- done
                            }- done

                            local subnet
                            for subnet in $(jq -c "select(.VpcId == \"${vpc}\")|.SubnetId" <<< "${subnets}" | tr -d '"'); do -{
                                local name="$(jq -c "select(.SubnetId == \"${subnet}\")|.Tags[]?|select(.Key==\"Name\")|.Value" <<< "${subnets}" | tr -d '"')"
                                cpf "${INDENT_STR}%{@key:%s} (%{@name:%s})..." "${subnet}" "${name:-n/a}"
                                jq -c "select(.SubnetId == \"${subnet}\")|{\"az\":.AvailabilityZone,\"cidr\":.CidrBlock,\"free\":.AvailableIpAddressCount}" <<< "${subnets}"

                                local instance
                                for instance in $(jq -c "select(.NetworkInterfaces[].SubnetId == \"${subnet}\")|.InstanceId" <<< "${instances}" | tr -d '"' | sort -u); do -{
                                    local name=$(jq -c "select(.InstanceId==\"${instance}\")|.Tags[]|select(.Key==\"Name\")|.Value" <<< "${instances}" 2>/dev/null | tr -d '"')

                                    cpf "${INDENT_STR}%{r:%s}/%{@name:%s}..." "${instance}" "${name:-noname}"
                                    jq -c "select(.InstanceId == \"${instance}\")|{\"type\":.InstanceType,\"state\":.State.Name,\"fqdn\":.PublicDnsName,\"ami\":.ImageId, \"sg\":[.SecurityGroups[].GroupId]}" <<< "${instances}"

                                    for eni in $(jq -c "select(.Attachment.InstanceId == \"${instance}\")|select(.SubnetId == \"${subnet}\")|.NetworkInterfaceId" <<< "${interfaces}" | tr -d '"'); do -{
                                        cpf "${INDENT_STR}%{@key:%s}: " "${eni}"
                                        jq -c "select(.NetworkInterfaceId == \"${eni}\")|{\"pri\":.PrivateIpAddress,\"pub\":.Association.PublicIp,\"fqdn\":.Association.PublicDnsName}" <<< "${interfaces}"
                                        for raw in $(jq -c "select(.NetworkInterfaceId == \"${eni}\")|.Groups[]|.GroupId+\",\"+.GroupName" <<< "${interfaces}" | tr -d '"'); do -{
                                            local sgid sgname
                                            IFS=, read sgid sgname <<< "${raw}"
                                            cpf "${INDENT_STR}%{@key:%s}: %{@name:%s}\n" "${sgid}" "${sgname}"
                                        }- done
                                    }- done

                                    local rt
                                    for rt in $(jq -c ".Associations[]|select(.SubnetId==\"${subnet}\")|.RouteTableId" <<< "${rts}" 2>/dev/null | tr -d '"'); do -{
                                        cpf "${INDENT_STR}%{@key:%s}\n" ${rt}
                                        for raw in $(jq -c "select(.VpcId==\"${vpc}\")|select(.RouteTableId==\"${rt}\")|.Routes[]|.DestinationCidrBlock+\",\"+.GatewayId" <<< "${rts}" | tr -d '"'); do -{
                                            IFS=, read cidr gw <<< "${raw}"
                                            cpf "${INDENT_STR}%{@key:routes}: %{@subnet:%s} via %{@host:%s}\n" "${cidr}" "${gw}"
                                        }- done
                                    }- done
                                }- done
                            }- done
                        }- done

                        cpf "${INDENT_STR}%{@version:%s}...\n" "Amazon Classic"; -{
                            cpf "${INDENT_STR}%{@key:%s}...\n" "subnet-00000000"

                            local instance
                            for instance in $(jq -c "select(.VpcId == null)|.InstanceId" <<< "${instances}" | tr -d '"' | sort -u); do -{
                                local name=$(jq -c "select(.InstanceId==\"${instance}\")|.Tags[]|select(.Key==\"Name\")|.Value" <<< "${instances}" | tr -d '"' 2>/dev/null)
                                cpf "${INDENT_STR}%{r:%s}/%{@name:%s}..." "${instance}" "${name:-noname}"
                                jq -c "select(.InstanceId == \"${instance}\")|{\"type\":.InstanceType,\"state\":.State.Name,\"fqdn\":.PublicDnsName,\"ami\":.ImageId, \"sg\":[.SecurityGroups[].GroupId]}" <<< "${instances}"

                                -{
                                    cpf "${INDENT_STR}%{@key:sg}: "
                                    jq -c "select(.InstanceId == \"${instance}\")|.SecurityGroups[]|[.GroupId,.GroupName]" <<< "${instances}"
                                }-

                                local eni
                                for eni in $(jq -c "select(.Attachment.InstanceId == \"${instance}\")|[.NetworkInterfaceId,.VpcId,.SubnetId,.AvailabilityZone,.PrivateIpAddress,.Association.PublicIp,.Association.PublicDnsName]" <<< "${interfaces}"); do -{
                                    cpf "${INDENT_STR}%{@key:eni}: %{@val:%s}\n" "${eni}"
                                    for raw in $(jq -c "select(.NetworkInterfaceId == \"${eni}\")|.Groups[]|.GroupId+\",\"+.GroupName" <<< "${interfaces}" | tr -d '"'); do -{
                                        local sgid sgname
                                        IFS=, read sgid sgname <<< "${raw}"
                                        cpf "${INDENT_STR}%{@key:%s}: %{@name:%s}\n" "${sgid}" "${sgname}"
                                    }- done
                                }- done
                            }- done
                        }-
                    }- fi
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
                            cpf "${INDENT_STR}%{y:%s}..." ${vpc}
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
list
create <cidr>
create-subnet <region> <vpc> <az> <cidr>
set-dns-hostnames <region> <vpc> enable|disable
!
}
function aws.ec2:vpc() {
    local -i e=${CODE_DEFAULT?}

    local subcmd="$1"
    case ${subcmd}:$# in
        list:2)
            local region="$2"
            py:run aws ec2 --region="${region}" describe-vpcs | jq -c '.Vpcs[]'
            e=${PIPESTATUS[0]}
        ;;
        create:2)
            local cidr="$2"
            py:run aws ec2 create-vpc --cidr="${cidr}" |
                jq '.'
            e=${PIPESTATUS[0]}
        ;;
        create-subnet:5)
            local region="$2"
            local vpc="$3"
            local az="$4"
            local cidr="$5"
            py:run aws --region="${region}" ec2 create-subnet --vpc="${vpc}" --cidr="${cidr}" --availability-zone=${az} |
                jq '.'
            e=${PIPESTATUS[0]}
        ;;
        set-dns-hostnames:4)
            local region="$2"
            local vpc="$3"
            local action="$4"
            case ${action} in
                enable|on)
                    py:run aws --region="${region}" ec2 modify-vpc-attribute --vpc-id="${vpc}" --enable-dns-hostnames
                    e=${PIPESTATUS[0]}
                ;;
                disable|off)
                    py:run aws --region="${region}" ec2 modify-vpc-attribute --vpc-id="${vpc}" --disable-dns-hostnames
                    e=${PIPESTATUS[0]}
                ;;
            esac
        ;;
        *)
            theme ERR_USAGE "Unsupported option \`${subcmd}'"
            e=${CODE_FAILURE?}
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
function aws.ec2:i:usage() { echo "desc|attr|screendump|terminate <instance-id>"; }
function aws.ec2:i() {
    local -i e=${CODE_DEFAULT?}

    local region=${FLAGS_region:-${AWS_DEFAULT_REGION?}}; unset FLAGS_region

    local subcmd="$1"
    case ${subcmd}:$# in
        attr:1) #. -={
            py:run aws --region="${region}" ec2 describe-account-attributes |
                jq -c '.AccountAttributes[]|{ (.AttributeName): (.AttributeValues[]|.AttributeValue) }'
            e=${PIPESTATUS[0]}
        ;; #. }=-
        desc:[12]) #. -={
            local regions
            regions=$(py:run aws --region="${2:-us-west-1}" ec2 describe-regions | jq '.Regions[]')
            [ $# -eq 2 ] && regions=$(jq "select(.RegionName == \"${2}\")" <<< "${regions}")

            local region
            for region in $(jq -c  '.RegionName' <<< "${regions}" | tr -d '"'); do
                cpf "${INDENT_STR?}%{y:%s}..." ${region}

                local instances
                instances=$(py:run aws --region="${region}" ec2 describe-instances | jq '.Reservations[].Instances[]')
                [ $? -ne ${CODE_SUCCESS?} ] && cpf '!' && e=${CODE_FAILURE} || cpf '.'

                cpf "\n"

                for instance in $(jq -c ".InstanceId" <<< "${instances}" | tr -d '"' | sort -u); do -{
                    local name=$(jq -c "select(.InstanceId==\"${instance}\")|.Tags[]|select(.Key==\"Name\")|.Value" <<< "${instances}" 2>/dev/null | tr -d '"')

                    cpf "${INDENT_STR}%{r:%s}/%{@name:%s}..." "${instance}" "${name:-noname}"
                    jq -c "select(.InstanceId == \"${instance}\")|{\"type\":.InstanceType,\"state\":.State.Name,\"fqdn\":.PublicDnsName,\"ami\":.ImageId, \"sg\":[.SecurityGroups[].GroupId]}" <<< "${instances}"
                }- done
            done
            e=${PIPESTATUS[0]}
        ;; #. }=-
        screendump:2) #. -={
            e=${CODE_FAILURE?}

            local iid=$2
            cpf "Retrieving screen dump from EC2 instance %{r:%s}..." ${iid}
            local dump
            dump="$(py:run aws --region="${region}" ec2 get-console-output --instance-id ${iid} 2>/dev/null | jq -e '.Output' | tr '\040-\042' ' ')"
            if [ ${PIPESTATUS[0]} -eq ${CODE_SUCCESS?} -a ${#dump} -gt 0 ]; then
                e=${CODE_SUCCESS?}
                theme HAS_PASSED
                echo -e "${dump}"
            else
                theme HAS_FAILED
                e=${CODE_FAILURE?}
            fi
        ;; #. }=-
        terminate:[2-9]) #. -={
            e=${CODE_SUCCESS?}
            local iid
            for iid in ${@:2}; do
                cpf "${INDENT_STR}Terminating %{r:%s}..." "${iid}"
                py:run aws --region="${region}" ec2 terminate-instances --instance-ids=${iid} | jq -c
                [ ${PIPESTATUS[0]} -eq ${CODE_SUCCESS?} ] || e=${CODE_FAILURE?}
            done
        ;; #. }=-
    esac

    return $e
}
#. }=-
#. aws.ec2:sg -={
function aws.ec2:sg:usage() {
cat <<!
list <region>
apply <region> <instance> <sgs>
!
}
function aws.ec2:sg() {
    local -i e=${CODE_DEFAULT?}

    local subcmd="$1"
    case ${subcmd}:$# in
        list:2)
            local region="$2"
            py:run aws --region="${region}" ec2 describe-security-groups |
                jq -e -c '.SecurityGroups[]|[.GroupId,.GroupName]'
            e=$?
        ;;
        apply:4)
            local region="$2"
            local instance="$3"
            local sgs="$4"
            py:run aws ec2 --region="${region}" modify-instance-attribute\
                --instance-id "${instance}"\
                --groups "$(:util:listify ${sgs})"
            e=$?
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
    local region="$2"
    local myip
    case $#:${subcmd} in
        2:check)
            region="$2"

            cpf "Your public IP address..."
            myip=$(:net:myip)
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED "${myip}/32"

                cpf "Testing ACL for ssh access from ${myip}/32..."
                local ip
                ip=$(py:run aws --region="${region}" ec2 describe-security-groups |
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
        2:create)
            region="$2"

            cpf "Your public IP address..."
            myip=$(:net:myip)
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED "${myip}/32"

                cpf "Creating a rule for ${myip}/32..."
                py:run aws --region="${region}" ec2 create-security-group \
                    --group-name "${secgrp}" \
                    --description "/inbound/ssh/src:${myip}" >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    py:run aws --region="${region}" ec2 authorize-security-group-ingress \
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
        2:delete)
            region="$2"

            cpf "Your public IP address..."
            myip=$(:net:myip)
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                theme HAS_PASSED "${myip}/32"

                cpf "Deleting rule for ${myip}/32..."
                py:run aws --region="${region}" ec2 delete-security-group \
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
