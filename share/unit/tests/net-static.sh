# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import net

#. Net -={
function netOneTimeSetUp() {
    : pass
}

function netSetUp() {
    : pass
}

function netTearDown() {
    : pass
}

function netOneTimeTearDown() {
    : pass
}

#. testCoreNetPortpersistInternal -={
function testCoreNetPortpersistInternal() {
    local -a tcpPorts=(
        $(netstat -ntl|awk -F '[: ]+' '$1~/^tcp$/&&$8~/^LISTEN$/{print$5}')
    )

    local -A scanned
    local -i tcpPort
    for tcpPort in ${tcpPorts[*]}; do
        #shellcheck disable=SC2086
        :net:portpersist localhost ${tcpPort} 1
        assertTrue "${FUNCNAME?}/${tcpPort}" $?
        scanned[${tcpPort}]=1
    done

    for tcpPort in {1..20}; do
        if [ ${scanned[${tcpPort}]:-0} -eq 0 ]; then
            :net:portpersist localhost ${tcpPort} 1
            assertFalse "${FUNCNAME?}/${tcpPort}" $?
        fi
    done
}
#. }=-
#. testCoreNetLocalportpingInternal -={
function testCoreNetLocalportpingInternal() {
    :net:localportping 22
    assertFalse "${FUNCNAME?}/1" $?

    :net:localportping 5000
    assertFalse "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreNetFreelocalportInternal -={
function testCoreNetFreelocalportInternal() {
    local -i port
    for ((i=0; i<10; i++)); do
        let port=$(:net:freelocalport)
        assertTrue "${FUNCNAME?}/$i.1" $?

        [ ${port} -lt 65536 ]
        assertTrue "${FUNCNAME?}/$i.2" $?

        [ ${port} -ge 1024 ]
        assertTrue "${FUNCNAME?}/$i.3" $?
    done
}
#. }=-
#. testCoreNetMyipInternal -={
function testCoreNetMyipInternal() {
    :net:myip >/dev/null
    assertTrue "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreNetI2sInternal -={
function testCoreNetI2sInternal() {
    local -a ifaces=( $(ifconfig|awk -F: '$0~/^[a-z]/{print$1}') )
    local ip
    local iface
    for iface in "${ifaces[@]}"; do
        if [[ ${iface} =~ lo.*[0-9]+ ]]; then
            ip="$(mock:wrapper net :i2s "${iface}")"
            assertTrue "${FUNCNAME?}/1" $?
            assertEquals "${FUNCNAME?}/2" "127.0.0.1" "${ip}"
            break
        fi
    done
}
#. }=-
#. }=-
