# vim: tw=0:ts=4:sw=4:et:ft=bash
:<<[core:docstring]
Core networking module
[core:docstring]

#. Network Utilities -={
core:import dns

function :net:fix() {
    #. input  10.1.2.123/24
    #. output 10.1.2.0/24
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local ip mask
        IFS=/ read ip mask <<< "${1}"

        local ip_bits=$(:net:s2h "${ip}")
        local mask_bits=$(:net:b2nm "${mask}")

        local nw_hex
        ((nw_hex = ip_bits & mask_bits))

        local nw=$(:net:h2s $nw_hex)
        printf "%s/%s\n" "${nw}" "${mask}"

        e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

#. net:b2nm -={
#. IPv4: Bits to Netmask
function :net:b2nm() {
    #. input  24
    #. output 0xffffff00
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -i -r nmb=$1
        if [ $nmb -le 32 ]; then
            printf "0x%08x\n" $(( ((1<<(32-nmb)) - 1)^0xffffffff ))
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. net:b2hm -={
#. IPv4: Bits to Hostmask
function :net:b2hm() {
    #. input  24
    #. output 0x000000ff
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -i -r hmb=$1
        if [ $hmb -le 32 ]; then
            printf "0x%08x\n" $(( ((1<<(32-hmb)) - 1)&0xffffffff ))
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. net:h2s -={
#. IPv4: Hex to String
function :net:h2s() {
    #. input  0xff00ff00
    #. output 255.0.255.0
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -ir ip=${1}
        if (( ip <= 0xffffffff )); then
            local -a q=(
                $(( (ip & (0xff << 24)) >> 24 ))
                $(( (ip & (0xff << 16)) >> 16 ))
                $(( (ip & (0xff << 8)) >> 8 ))
                $(( ip & 0xff ))
            )
            printf "%d.%d.%d.%d\n" ${q[@]}
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. net:s2h -={
#. IPv4: String to Hex
function :net:s2h() {
    #. input  255.0.255.0
    #. output 0xff00ff00
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -r ips=$1
        if [ "${ips//[0-9]/}" == '...' ]; then
            IFS=. read -ir q1 q2 q3 q4 <<< ${ips}
            printf "0x%02x%02x%02x%02x\n" $q1 $q2 $q3 $q4
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. net:i2s -={
#. IPv4: Interface to String
function :net:i2s() {
    #. input  lo
    #. output 127.0.0.1
    core:requires ip

    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -r iface=$1
        local ip
        ip=$(ip addr show dev ${iface} permanent|awk '$1~/^inet$/{print$2}' 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo ${ip%%/*}
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. net:hosts -={
function :net:hosts() {
    #. input  123.123.123.123/12
    #. output (a list of all hosts in the subnet)
    local -i e=${CODE_SUCCESS?}

    [ "${1//[^.]/}" == '...' ] || e=${CODE_FAILURE?}
    [ "${1//[^\/]/}" == '/' ] || [ "${1//[^\/]/}" == '' ] || e=${CODE_FAILURE?}
    if [ $# -eq 1 -a $e -eq ${CODE_SUCCESS?} ]; then
        IFS=/ read -r ips nmb <<< "$1"
        local -r ipx=$(:net:s2h ${ips})
        local -r nm=$(:net:b2nm ${nmb})
        local -r hm=$(:net:b2hm ${nmb})
        local hb nw ip i=0
        while [ ${i} -lt $((${hm} - 1)) ]; do
            ((i++))
            ip=$(printf "0x%x" $(( ( ipx & nm ) + ${i})))
            :net:h2s ${ip}
            e=$?
        done
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. net:firsthost -={
function :net:firsthost() {
    #. input  123.123.123.0/24
    #. ouput  123.123.123.1
    local -i e=${CODE_SUCCESS?}

    [ "${1//[^.]/}" == '...' ] || e=${CODE_FAILURE?}
    [ "${1//[^\/]/}" == '/' ] || [ "${1//[^\/]/}" == '' ] || e=${CODE_FAILURE?}

    if [ $# -eq 1 -a $e -eq ${CODE_SUCCESS?} ]; then
        IFS=/ read -r ips nmb <<< "$1"
        local -r ipx=$(:net:s2h ${ips})
        local -r nm=$(:net:b2nm ${nmb})
        local -r nw=0x$(printf "%x" $(( ipx & nm )))
        local -r fh=$(printf "%x" $(( nw + 1 )))
        :net:h2s 0x${fh}
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. net:portpersist -={
function :net:portpersist() {
    core:requires socat

    local -i e=${CODE_FAILURE?}

    if [ $# -eq 4 ]; then
        local tldid=$1
        local qdn=$2
        local port=$3
        local -i attempts=$4
        local -i i=0
        while ((i < attempts)) && ((e == ${CODE_FAILURE?})); do
            :net:portping ${tldid} ${qdn} ${port}
            e=$?
            ((i++))
        done
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. net:localportping -={
function :net:localportping() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local -i lport=$1
        local output
        output=$(netstat -ntl |
            awk 'BEGIN{e=1};$4~/^127.0.0.1:'${lport}'$/{e=0};END{exit(e)}'
        )
        if [ ${#output} -gt 0 ]; then
            echo "${output}"
            e=${CODE_SUCCESS?}
        fi
    fi

    return $e
}
#. }=-
#. net:freelocalport -={
function :net:freelocalport() {
    local -i e=${CODE_FAILURE?}

    freeport=0
    for port in $@; do
        if ! :net:localportping ${port}; then
            freeport=$port
            e=${CODE_SUCCESS?}
            break
        fi
    done

    while [ ${freeport} -eq 0 ]; do
        ((port=1024+RANDOM))
        if ! :net:localportping ${lport}; then
            freeport=${port}
            e=${CODE_SUCCESS?}
            break
        fi
    done

    [ ${freeport} -eq 0 ] || echo ${freeport}

    return $e
}
#. }=-
#. net:portping -={
function :net:portping() {
    core:requires nc
    core:requires socat

    local -i e=${CODE_FAILURE?}
    if [ $# -eq 3 -o $# -eq 4 ]; then
        local tldid="$1"
        local qdn="$2"
        local port="$3"
        local ssh_proxy="$4"
        local cmd="nc -zqw1 ${qdn} ${port}"
        cmd="socat /dev/null TCP:${qdn}:${port},connect-timeout=1"
        if [ ${tldid} != '_' ]; then
            local tld=${USER_TLDS[${tldid}]}

            #. DEPRECATED: USER_SSH_PROXY
            #local ssh_proxy=${USER_SSH_PROXY[${tldid}]}
            if [ ${#ssh_proxy} -gt 0 ]; then
                ssh ${g_SSH_OPTS} ${ssh_proxy} ${cmd} >/dev/null 2>&1
                e=$?
            else
                eval ${cmd} >/dev/null 2>&1
                e=$?
            fi
        else
            eval ${cmd} >/dev/null 2>&1
            e=$?
        fi
    else
        theme EXCEPTION "$# / $*"
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
function net:portping:usage() { echo "<hnh> <port>"; }
function net:portping() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 2 ]; then
        local hnh=$1
        local port=$2

        cpf "Testing TCP connectivity to %{@host:%s}:%{@port:%s}..." ${hnh} ${port}

        local fqdn
        local tldid=${g_TLDID?}
        #. If the name supplied does not end with a `.':
        if [ "${hnh:$((${#hnh}-1))}" != '.' ]; then
            fqdn=$(:dns:get ${tldid} fqdn ${hnh})
            if [ $? -eq ${CODE_FAILURE?} ]; then
                e=${CODE_FAILURE?}
                theme HAS_FAILED "INVALID_FQDN"
            fi
        else
            tldid='_'
            fqdn=${hnh}
        fi

        if [ $e -ne ${CODE_FAILURE?} ]; then
            if :net:portping ${tldid} ${fqdn} ${port}; then
                theme HAS_PASSED "CONNECTED"
                e=${CODE_SUCCESS?}
            else
                theme HAS_WARNED "NO_CONN"
                e=${CODE_FAILURE?}
            fi
        fi
    fi

    return $e
}
#. }=-
#. net:myip -={
function :net:myip:cached() { echo 3; }
function :net:myip() {
  g_CACHE_OUT "$*" || {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 0 ]; then
        local myip
        #! SLOW: myip=$(wget -q --timeout=1 -O- http://ifconfig.me/)
        myip=$(wget -q --timeout=1 -O- https://secure.internode.on.net/webtools/showmyip?textonly=1)
        e=$?
        if [ $e -eq 0 -a ${#myip} -gt 0 -a ${#myip} -lt 16 ]; then
            echo "${myip}"
            e=${CODE_SUCCESS?}
        fi
    fi
  } > ${g_CACHE_FILE?}; g_CACHE_IN; return $?
}
#. }=-
#. }=-
