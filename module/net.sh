# vim: tw=0:ts=4:sw=4:et:ft=bash
:<<[core:docstring]
Core networking module
[core:docstring]

#. Network Utilities -={

#.  :net:fix() -={
function :net:fix() {
    #. input  10.1.2.123/24
    #. output 10.1.2.0/24
    core:raise_bad_fn_call_unless $# eq 1

    local -i e; let e=CODE_FAILURE

    local ip
    local -i mask
    IFS=/ read -r ip mask <<< "${1}"

    local -i ip_bits; let ip_bits=$(:net:s2h "${ip}")
    local -i mask_bits
    #shellcheck disable=SC2034
    let mask_bits=$(:net:b2nm "${mask}")
    local nw_hex; let nw_hex='ip_bits & mask_bits'

    local nw; nw=$(:net:h2s $nw_hex)
    printf "%s/%s\n" "${nw}" "${mask}"

    let e=CODE_SUCCESS

    return $e
}
#. }=-
#.  :net:b2nm -={
function :net:b2nm() {
    #. IPv4: Bits to Netmask
    #. input  24
    #. output 0xffffff00
    core:raise_bad_fn_call_unless $# eq 1
    local -i e

    local -i nmb; let nmb=$1
    core:raise_bad_fn_call_unless ${nmb} le 32

    printf "0x%08x\n" $(( ((1<<(32-nmb))-1)^0xffffffff ))
    let e=$?

    return $e
}
#. }=-
#.  :net:b2hm -={
function :net:b2hm() {
    #. IPv4: Bits to Hostmask
    #. input  24
    #. output 0x000000ff
    core:raise_bad_fn_call_unless $# eq 1
    local -i e; let e=CODE_FAILURE

    local -i hmb; let hmb=$1
    core:raise_bad_fn_call_unless ${hmb} le 32

    printf "0x%08x\n" $(( ((1<<(32-hmb)) - 1)&0xffffffff ))
    let e=$?

    return $e
}
#. }=-
#.  :net:h2s -={
function :net:h2s() {
    #. IPv4: Hex to String
    #. input  0xff00ff00
    #. output 255.0.255.0
    core:raise_bad_fn_call_unless $# eq 1

    local -i ip; let ip=$1
    core:raise_bad_fn_call_unless ${ip} le 0xffffffff

    local -a q=(
        $(( (ip & (0xff << 24)) >> 24 ))
        $(( (ip & (0xff << 16)) >> 16 ))
        $(( (ip & (0xff << 8)) >> 8 ))
        $(( ip & 0xff ))
    )

    printf "%d.%d.%d.%d\n" "${q[@]}"
    return $?
}
#. }=-
#.  :net:s2h -={
function :net:s2h() {
    #. IPv4: String to Hex
    #. input  255.0.255.0
    #. output 0xff00ff00
    core:raise_bad_fn_call_unless $# eq 1

    local -i e; let e=CODE_FAILURE

    local -r ips=$1
    if [ "${ips//[0-9]/}" == '...' ]; then
        IFS=. read -ir q1 q2 q3 q4 <<< "${ips}"
        #shellcheck disable=SC2086
        printf "0x%02x%02x%02x%02x\n" $q1 $q2 $q3 $q4
        let e=$?
    fi

    return $e
}
#. }=-
#.  :net:i2s -={
function :net:i2s() {
    #. IPv4: Interface to String
    #. input  lo
    #. output 127.0.0.1
    core:requires ANY ip ifconfig
    core:raise_bad_fn_call_unless $# eq 1

    local -i e; let e=CODE_SUCCESS

    local -r iface=$1
    local ipdump
    if ipdump="$(ip addr show dev "${iface}" permanent 2>/dev/null)"; then
        : noop
    elif ipdump="$(ifconfig "${iface}" 2>/dev/null)"; then
        : noop
    else
        let e=CODE_FAILURE
    fi

    if (( e == CODE_SUCCESS )); then
        local ip
        ip="$(awk '$1~/^inet$/{print$2}' <<< "${ipdump}")"
        echo "${ip%%/*}"
    fi

    return $e
}
#. }=-
#.   net:hosts -={
function :net:hosts() {
    #. input  123.123.123.123/12
    #. output (a list of all hosts in the subnet)
    core:raise_bad_fn_call_unless $# eq 1

    local -i e; let e=CODE_SUCCESS

    [ "${1//[^.]/}" == '...' ] || e=${CODE_FAILURE?}
    [ "${1//[^\/]/}" == '/' ] || [ "${1//[^\/]/}" == '' ] || e=${CODE_FAILURE?}
    if (( e == CODE_SUCCESS )); then
        IFS=/ read -r ips nmb <<< "$1"
        local -i ipx; let ipx=$(:net:s2h "${ips}")
        local -i nm; let nm=$(:net:b2nm "${nmb}")
        local -i hm; let hm=$(:net:b2hm "${nmb}")
        local -i i
        local ip
        for ((i=1; i<hm; i++)); do
            ip=$(printf "0x%x" $(( ( ipx & nm ) + i)))
            :net:h2s "${ip}"
            let e=$?
        done
    else
        core:raise EXCEPTION_BAD_FN_CALL "Invalid ip/subnet: \`%s'" "$1"
    fi

    return $e
}
function net:hosts:usage() { echo "<ip-subnet>"; }
function net:hosts() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 1 ] || return $e

    local subnet="$1"

    cpf "Resolving %{@subnet:%s}..." "${subnet}"

    local -a hosts; hosts=( $(:net:hosts "${subnet}") )
    let e=$?
    if (( e == CODE_SUCCESS )); then
        theme HAS_PASSED
        local host
        for host in "${hosts[@]}"; do
            cpf "%{@host:%s}\n" "${host}"
        done
    else
        theme HAS_FAILED
    fi

    return $e
}
#. }=-
#.  :net:firsthost -={
function :net:firsthost() {
    #. input  123.123.123.0/24
    #. ouput  123.123.123.1
    local -i e; let e=CODE_SUCCESS

    [ "${1//[^.]/}" == '...' ] || e=${CODE_FAILURE?}
    [ "${1//[^\/]/}" == '/' ] || [ "${1//[^\/]/}" == '' ] || e=${CODE_FAILURE?}

    if (( e == CODE_SUCCESS )); then
        IFS=/ read -r ips nmb <<< "$1"
        local -i ipx; let ipx=$(:net:s2h "${ips}")
        local -i nm; let nm=$(:net:b2nm "${nmb}")
        local nw; nw="0x$(printf "%x" $(( ipx & nm )))"
        local fh; fh="$(printf "%x" $(( nw + 1 )))"
        :net:h2s "0x${fh}"
        let e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL "Invalid ip/subnet: \`%s'" "$1"
    fi

    return $e
}
#. }=-
#.  :net:portpersist -={
function :net:portpersist() {
    core:requires socat
    core:raise_bad_fn_call_unless $# in 3

    local qdn="$1"
    local -i port; let port=$2
    local -i attempts; let attempts=$3

    local -i e; let e=CODE_FAILURE

    local -i i=0
    while ((i < attempts)) && ((e == ${CODE_FAILURE?})); do
        :net:portping "${qdn}" ${port}
        e=$?
        ((i++))
    done

    return $e
}
#. }=-
#.  :net:localportping -={
function :net:localportping() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e; let e=CODE_FAILURE

    local -i lport; let lport=$1
    local output; output=$(netstat -ntl |
        awk 'BEGIN{e=1};$4~/^127.0.0.1:'${lport}'$/{e=0};END{exit(e)}'
    )
    if [ ${#output} -gt 0 ]; then
        echo "${output}"
        let e=CODE_SUCCESS
    fi

    return $e
}
#. }=-
#.  :net:freelocalport -={
function :net:freelocalport() {
    local -i e; let e=CODE_FAILURE

    local -i freeport=0
    local -i port
    for port in "$@"; do
        if let port=port && ! :net:localportping ${port}; then
            let freeport=$port
            let e=CODE_SUCCESS
            break
        fi
    done

    while (( e != CODE_SUCCESS )); do
        (( port='1024 + ( RANDOM % ( (1<<16)-1-1024 ) )' ))
        if ! :net:localportping ${port}; then
            let freeport=port
            let e=CODE_SUCCESS
            break
        fi
    done

    [ ${freeport} -eq 0 ] || echo ${freeport}

    return $e
}
#. }=-
#.   net:portping -={
function :net:portping() {
    core:raise_bad_fn_call_unless $# in 2

    core:requires ANY nc socat

    local qdn="$1"
    local port="$2"

    local cmd
    if which socat >&/dev/null; then
        cmd="socat /dev/null TCP:${qdn}:${port},connect-timeout=1"
    elif which nc >&/dev/null; then
        cmd="nc -zqw1 ${qdn} ${port}"
    fi

    eval "${cmd}" >&/dev/null
    return $?
}
function net:portping:usage() { echo "<hnh> <port>"; }
function net:portping() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 2 ] || return $e

    local hn=$1
    local port=$2

    cpf "Testing TCP connectivity to %{@host:%s}:%{@port:%s}..." "${hn}" "${port}"

    if :net:portping "${hn}" "${port}"; then
        theme HAS_PASSED "CONNECTED"
        let e=CODE_SUCCESS
    else
        theme HAS_WARNED "NO_CONN"
        let e=CODE_FAILURE
    fi

    return $e
}
#. }=-
#.  :net:myip -={
function :net:myip:cached() { echo 3; }
function :net:myip() {
  g_CACHE_OUT "$*" || {
    local -i e; let e=CODE_FAILURE
    [ $# -eq 0 ] || return $e

    local myip
    #! SLOW: myip=$(wget -q --timeout=1 -O- http://ifconfig.me/)
    if myip=$(wget -q --timeout=1 -O- https://secure.internode.on.net/webtools/showmyip?textonly=1); then
        #shellcheck disable=SC2166
        if [ ${#myip} -gt 0 -a ${#myip} -lt 16 ]; then
            echo "${myip}"
            let e=CODE_SUCCESS
        fi
    fi

    core:return $e
  } > "${g_CACHE_FILE?}"; g_CACHE_IN; return $?
}
#. }=-

#. }=-
