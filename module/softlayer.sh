# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Softlayer API
[core:docstring]

#. SoftLayer -={
core:import util
core:import dns
core:requires PYTHON pytz
core:requires PYTHON SoftLayer
core:requires VAULT  SOFTLAYER_API_KEY

#. softlayer:ipmicreds -={
function :softlayer:ipmicreds() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local data
        data=$(:softlayer:hostdump.json ${fqdn})
        if [ ${#data} -gt 0 -a $? -eq ${CODE_SUCCESS?} ]; then
            local username=$(
                echo -ne "${data}" | :util:json -a 'remoteManagementAccounts[0]["username"]'
            )
            local password=$(
                echo -ne "${data}" | :util:json -a 'remoteManagementAccounts[0]["password"]'
            )
            local ipmiaddr=$(echo -ne "${data}" | :util:json -a 'networkManagementIpAddress')

            echo "${username}${SIMBOL_DELIM?}${password}${SIMBOL_DELIM?}${ipmiaddr}"
            e=${CODE_SUCCESS?}
        fi
    fi

    return $e
}
#. }=-
#. softlayer:ipmi -={
function softlayer:ipmi:usage() { echo "sol|health|dump <fqdn>"; }
function softlayer:ipmi() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 2 ]; then
        local cmd=$1
        local fqdn=$2
        local creds
        creds="$(:softlayer:ipmicreds ${fqdn})"
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            IFS=${SIMBOL_DELIM?} read username password ipmiaddr <<< "${creds}"

            case ${cmd} in
                sol)
                    #. Disconnect
                    ipmiutil sol -U ${username} -P ${password} -N ${ipmiaddr} -V3 -d

                    #. Connect
                    ipmiutil sol -U ${username} -P ${password} -N ${ipmiaddr} -V3 -a
                    e=$?
                ;;
                health)
                    ipmiutil health -U ${username} -P ${password} -N ${ipmiaddr} -V3 -fghils
                    e=$?
                ;;
                dump)
                    ipmiutil lan -U ${username} -P ${password} -N ${ipmiaddr} -r -V3
                    e=$?
                ;;
            esac
        else
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. softlayer:subnets -={
function softlayer:subnets:usage() { echo "[private] [public]"; }
function softlayer:subnets() {
    local -i e=${CODE_DEFAULT?}

    local -a subnets
    if [ $# -gt 0 ]; then
        e=${CODE_SUCCESS?}
        local subnet
        for subnet in $@; do
            case ${subnet} in
                private) subnets+=( ${subnet} ) ;;
                public)  subnets+=( ${subnet} ) ;;
                *) e=${CODE_USAGE?};;
            esac
        done
    else
        e=${CODE_SUCCESS?}
        subnets+=( private public )
    fi

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        local nw cidr gw
        local -i count total vlan
        for subnet in ${subnets[@]}; do
            case ${subnet} in
                private|public)
                    while read line; do
                        read gw nw cidr count vlan <<< "${line}"
                        ((total+=count))
                        cpf "%15s/%s @ vlan:%-6s -> %-15s (%s, %s hosts)\n" \
                            "${nw}" "${cidr}" "${vlan}" "${gw}" "${subnet}" "${count}"
                    done < <(
                        softlayer "Account::get${subnet^}Subnets" |
                            :util:json -a gateway networkIdentifier cidr usableIpAddressCount networkVlanId
                    )
                ;;
            esac
        done
        if [ -t 1 ]; then
            cpf "\nTotal addressable IPv4 addresses in the %{y:%s} space: %{@int:%s}\n" "$(:util:join / subnets)" "${total}"
        fi
    fi

    return $e
}
#. }=-
#. softlayer:hostlist -={
function :softlayer:hostlist() {
    local -i e=${CODE_FAILURE?}

    local mask='networkComponents.primarySubnet'

    #print y['primarySubnet']['gateway'], x['id']
    if [ $# -eq 0 ]; then
        echo "FQDN" "IPMIAddr" "IPBackend" "Gw" "IPPrimary"
        softlayer 'Account::getHardware' mask=${mask} |
            :util:json -a \
                fullyQualifiedDomainName \
                networkManagementIpAddress \
                primaryBackendIpAddress \
                'networkComponents[0]["primarySubnet"]["gateway"]' \
                primaryIpAddress
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. softlayer:hostdump -={
function :softlayer:hostdump.json() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local fqdn="$1"
        local mask="remoteManagementAccounts,remoteManagementAccounts"
        softlayer 'Account::getHardware' mask=${mask} |
            :util:json -a -c 'this.fullyQualifiedDomainName == "'${fqdn}'"' 2>/dev/null
        e=$?
        echo "${data}"
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. softlayer:hostid -={
function :softlayer:hostid() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        softlayer 'Account::getHardware' |
            :util:json -a -c 'this.fullyQualifiedDomainName == "'${fqdn}'"' 2>/dev/null |
            :util:json -a 'id' 2>/dev/null
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. softlayer:hostpower -={
function :softlayer:hostpower() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local fqdn=$1
        local id
        id=$(:softlayer:hostid ${fqdn})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            softlayer 'Hardware_Server::getServerPowerState' id=${id} |
                :util:json -a 2>/dev/null
            e=$?
        fi
    elif [ $# -eq 2 ]; then
        local fqdn=$1
        local cmd=$2
        local success
        id=$(:softlayer:hostid ${fqdn})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            case ${cmd} in
                reset)
                    success=$(softlayer 'Hardware_Server::powerCycle' id=${id})
                ;;
                on)
                    success=$(softlayer 'Hardware_Server::powerOn' id=${id})
                ;;
                off)
                    success=$(softlayer 'Hardware_Server::powerOff' id=${id})
                ;;
                *)
                    core:raise EXCEPTION_BAD_FN_CALL
                ;;
            esac
            e=${CODE_FAILURE?}
            [ "${success}" != "true" ] || e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. softlayer:host -={
function softlayer:host:usage() { echo "list | dump <fqdn> | power <fqdn> status|on|off|reset"; }
function softlayer:host() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 1 ]; then
        local cmd=$1
        local hnh=$2
        local fqdn=${hnh} #. FIXME
        local tldid=${g_TLDID?}
        local -a fqdns

        local tld=${USER_TLDS[${tldid}]}
        if [ ${#tld} -gt 0 ]; then
            case $#:${cmd} in
                1:list)
                    :softlayer:hostlist | column -t
                    e=$?
                ;;
                2:dump)
                    local -a fqdns
                    fqdns=( $(:dns:get ${tldid} fqdn ${hnh}) )
                    if [ ${#fqdns[@]} -gt 0 ]; then
                        e=${CODE_SUCCESS?}
                        for fqdn in ${fqdns[@]}; do
                            :softlayer:hostdump.json ${fqdn}
                            e=$?
                        done
                    else
                        theme HAS_FAILED "CANNOT_RESOLVE_HNH"
                        e=${CODE_FAILURE?}
                    fi
                ;;
                3:power)
                    fqdns=( $(:dns:get ${tldid} fqdn ${hnh}) )
                    if [ ${#fqdns[@]} -gt 0 ]; then
                        fqdn=${fqdns[0]}
                    else
                        theme HAS_FAILED "CANNOT_RESOLVE_HNH"
                        e=${CODE_FAILURE?}
                    fi

                    if [ $e -ne ${CODE_FAILURE?} ]; then
                        cpf "Host %{@host:${fqdn}} is .."

                        local request=$3
                        local power
                        power=$(:softlayer:hostpower ${fqdn})
                        e=$?
                        cpf '.'

                        if [ $e -eq ${CODE_SUCCESS?} ]; then
                            case ${power}:${request} in
                                on:status)  cpf "%{g:ON}\n" ; e=${CODE_SUCCESS?} ;;
                                off:status) cpf "%{r:OFF}\n"; e=${CODE_SUCCESS?} ;;
                                on:on)      cpf "already %{g:ON}\n" ; e=${CODE_SUCCESS?} ;;
                                off:off)    cpf "already %{r:OFF}\n"; e=${CODE_SUCCESS?} ;;
                                on:reset)
                                    cpf "%{g:ON}\n"
                                    cpf "Powercycling server..."
                                    :softlayer:hostpower reset
                                    e=$?
                                    if [ $e -eq ${CODE_SUCCESS?} ]; then
                                        theme HAS_PASSED
                                    else
                                        theme HAS_FAILED
                                    fi
                                ;;
                                on:off)
                                    cpf "%{g:ON}\n"
                                    cpf "Powering server %{r:OFF}..."
                                    :softlayer:hostpower off
                                    e=$?
                                ;;
                                off:on)
                                    cpf "%{r:OFF}\n"
                                    cpf "Powering server %{g:ON}..."
                                    :softlayer:hostpower on
                                    e=$?
                                ;;
                                *)
                                    echo "What is teh ${power}:${request}?"
                                ;;
                            esac
                        else
                            theme HAS_FAILED
                        fi
                    fi
                ;;
            esac
        else
            theme ERR "Invalid TLD identifier \'${tldid}'"
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. softlayer:ticket -={
function softlayer:ticket:usage() { echo "[<ticket-id>]"; }
function softlayer:ticket() {
    local e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local data=$(:softlayer:query Ticket::getLastUpdate id=$1)
        local message=$(:util:json 'entry' <<< "${data}")
        local new=$(:softlayer:query Ticket::getNewUpdatesFlag id=$1)
        if [ "${new}" == "true" ]; then
            echo "################################################################################"
        else
            echo "--------------------------------------------------------------------------------"
        fi
        echo "$message"
        if [ "${new}" == "true" ]; then
            echo "################################################################################"
        else
            echo "--------------------------------------------------------------------------------"
        fi
        e=$?
    elif [ $# -eq 0 ]; then
        local mask="newUpdatesFlag"
        local data="$(:softlayer:query Account::getOpenTickets mask=${mask})"
        echo -ne "${data}" |
            :util:json -a id newUpdateFlag modifyDate 'status["name"]' title |
            sort -r -k3 |
            column -c 5
        e=$?
    fi

    return $e
}
#. }=-
#. softlayer:dc -={
function softlayer:dc:usage() { echo "<shn> [<shn> [...]]"; }
function softlayer:dc() {
    local e=${CODE_DEFAULT?}

    if [ $# -gt 0 ]; then
        local shn
        local sid
        local dc
        for shn in $@; do
            while read line; do
                read sid fqdn <<< ${line}
                if [ ${#sid} -gt 0 ]; then
                    dc=$(
                        softlayer 'Hardware_Server::getTopLevelLocation' id=${sid} |
                            :util:json -a name
                    )
                    echo ${fqdn} @ ${dc}
                else
                    echo ${shn} @ FAIL
                fi
            done < <(
                softlayer 'Account::getHardware' |
                    :util:json -ac "this.hostname==\"${shn}\"" id fullyQualifiedDomainName
            )
        done

        e=${CODE_SUCCESS?}
    fi

    return $e
}
#. }=-
#. softlayer:query -={
function :softlayer:query() {
    softlayer "${@}"
    return $?
}

function softlayer:query:usage() { echo "<query>"; }
function softlayer:query() {
    local -i e=${CODE_USAGE?}

    #simbol nexpose test getHardware '$.privateIpAddress'
    #simbol nexpose test getHardware '$.*[152]'

    #. https://control.softlayer.com/network/vlans
    #simbol softlayer query Network_Vlan::getObject

    #. https://control.softlayer.com/network/vlans/114973
    #simbol softlayer query Network_Vlan::getSubnets id=114973 path='$..networkIdentifier'

    if [ $# -gt 1 ]; then
        {
            echo "/* vim:syntax=json */"
            :softlayer:query "${@}" | :util:json
        } | vimcat
        e=${CODE_SUCCESS?}
    fi

    return $e
}
#. }=-
#. }=-
