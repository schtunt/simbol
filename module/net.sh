# vim: tw=0:ts=4:sw=4:et:ft=bash
:<<[core:docstring]
Core networking module
[core:docstring]

#. Network Utilities -={

function :net:fix() {
    #. input  10.1.2.123/24
    #. output 10.1.2.0/24
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local ip mask
        IFS=/ read -r ip mask <<< "${1}"

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
            printf "%d.%d.%d.%d\n" "${q[@]}"
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
    core:requires ANY ip ifconfig
    core:raise_bad_fn_call_unless $# in 1

    local -i e=${CODE_FAILURE?}

    local -r iface=$1
    local ipdump
    if ipdump="$(ip addr show dev ${iface} permanent 2>/dev/null)"; then
        e=${CODE_SUCCESS?}
    elif ipdump="$(ifconfig ${iface} 2>/dev/null)"; then
        e=${CODE_SUCCESS?}
    fi

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        local ip
        ip="$(awk '$1~/^inet$/{print$2}' <<< "${ipdump}")"
        echo "${ip%%/*}"
    fi

    return $e
}
#. }=-
#. net:hosts -={
function :net:hosts() {
    #. input  123.123.123.123/12
    #. output (a list of all hosts in the subnet)
    local -i e=${CODE_SUCCESS?}

    if [ $# -eq 1 ]; then
        [ "${1//[^.]/}" == '...' ] || e=${CODE_FAILURE?}
        [ "${1//[^\/]/}" == '/' ] || [ "${1//[^\/]/}" == '' ] || e=${CODE_FAILURE?}
        if [ $e -eq ${CODE_SUCCESS?} ]; then
            IFS=/ read -r ips nmb <<< "$1"
            local -r ipx=$(:net:s2h ${ips})
            local -r nm=$(:net:b2nm ${nmb})
            local -r hm=$(:net:b2hm ${nmb})
            local nw ip i=0
            while [ ${i} -lt $((hm - 1)) ]; do
                ((i++))
                ip=$(printf "0x%x" $(( ( ipx & nm ) + i)))
                :net:h2s ${ip}
                e=$?
            done
        else
            core:raise EXCEPTION_BAD_FN_CALL "Invalid ip/subnet: \`%s'" "$1"
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, 2 expected"
    fi

    return $e
}
function net:hosts:usage() { echo "<ip-subnet>"; }
function net:hosts() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local subnet="$1"

        cpf "Resolving %{@subnet:%s}..." ${subnet}

        local -a hosts
        hosts=( $(:net:hosts "${subnet}") )
        e=$?
        if [ $e -eq ${CODE_SUCCESS?} ]; then
            theme HAS_PASSED
            local host
            for host in "${hosts[@]}"; do
                cpf "%{@host:%s}\n" "${host}"
            done
        else
            theme HAS_FAILED
        fi
    fi

    return $e
}
#. }=-
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

    core:raise_bad_fn_call_unless $# in 3
    local qdn="$1"
    local -i port; let port=$2
    local -i attempts; let attempts=$3

    local -i e=${CODE_FAILURE?}

    local -i i=0
    while ((i < attempts)) && ((e == ${CODE_FAILURE?})); do
        :net:portping "${qdn}" ${port}
        e=$?
        ((i++))
    done

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
    for port in "$@"; do
        if ! :net:localportping ${port}; then
            freeport=$port
            e=${CODE_SUCCESS?}
            break
        fi
    done

    while [ ${freeport} -eq 0 ]; do
        ((port=1024+RANDOM))
        if ! :net:localportping ${port}; then
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
    core:raise_bad_fn_call_unless $# in 2

    core:requires nc
    core:requires socat

    local qdn="$1"
    local port="$2"
    local cmd="nc -zqw1 ${qdn} ${port}"
    cmd="socat /dev/null TCP:${qdn}:${port},connect-timeout=1"

    eval ${cmd} >&/dev/null
    return $?
}
function net:portping:usage() { echo "<hnh> <port>"; }
function net:portping() {
    local -i e=${CODE_DEFAULT?}
    [ $# -eq 2 ] || return $e

    local hn=$1
    local port=$2

    cpf "Testing TCP connectivity to %{@host:%s}:%{@port:%s}..." ${hn} ${port}

    if :net:portping ${hn} ${port}; then
        theme HAS_PASSED "CONNECTED"
        e=${CODE_SUCCESS?}
    else
        theme HAS_WARNED "NO_CONN"
        e=${CODE_FAILURE?}
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
