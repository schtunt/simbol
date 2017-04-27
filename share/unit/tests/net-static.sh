# vim: tw=0:ts=4:sw=4:et:ft=bash

function netOneTimeSetUp() {
    core:import net
    assertTrue ${FUNCNAME?}/0 $?
}

function testCoreNetPortpersistInternal() {
    local -a tcpPorts=(
        $(netstat -ntl|awk -F '[: ]+' '$1~/^tcp$/&&$8~/^LISTEN$/{print$5}')
    )

    local -A scanned
    local -i tcpPort
    for tcpPort in ${tcpPorts[*]}; do
        :net:portpersist localhost ${tcpPort} 1
        assertTrue "0.1.${tcpPort}" $?
        scanned[${tcpPort}]=1
    done

    for tcpPort in {1..20}; do
        if [ ${scanned[${tcpPort}]-0} -eq 0 ]; then
            :net:portpersist localhost ${tcpPort} 1
            assertFalse "0.2.${tcpPort}" $?
        fi
    done
}

function testCoreNetLocalportpingInternal() {
    :net:localportping 22
    assertFalse '0.1' $?

    :net:localportping 5000
    assertFalse '0.2' $?
}

function testCoreNetFreelocalportInternal() {
    local -i port
    for ((i=0; i<10; i++)); do
        port=$(:net:freelocalport)
        assertTrue '0.1' $?

        [ ${port} -lt 65536 ]
        assertTrue '0.2' $?

        [ ${port} -ge 1024 ]
        assertTrue '0.3' $?
    done
}

function testCoreNetMyipInternal() {
    :net:myip >/dev/null
    assertTrue '0.1' $?
}

function testCoreNetI2sInternal() {
    local -a ifaces=( $(ifconfig|awk -F: '$0~/^[a-z]/{print$1}') )
    local iface
    local ip
    for iface in "${ifaces[@]}"; do
        if [[ ${iface} =~ lo.*[0-9]+ ]]; then
            ip="$(mock:wrapper net :i2s ${iface})"
            assertTrue "${FUNCNAME?}/1" $?
            assertEquals "${FUNCNAME?}/2" "127.0.0.1" "${ip}"
            break
        fi
    done
}

