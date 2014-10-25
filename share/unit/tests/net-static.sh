# vim: tw=0:ts=4:sw=4:et:ft=bash

function testCoreNetImport() {
    core:softimport net
    assertEquals 0 $?
}

function testCoreNetPortpersistInternal() {
    core:import net

    local -a tcpPorts=(
        $(netstat -ntl|awk -F '[: ]+' '$1~/^tcp$/&&$8~/^LISTEN$/{print$5}')
    )

    local -A scanned
    for tcpPort in ${tcpPorts[@]}; do
        :net:portpersist _ localhost ${tcpPort} 1
        assertTrue 0x1 $?
        scanned[${tcpPort}]=1
    done

    for tcpPort in {16..32}; do
        if [ ${scanned[${tcpPort}]-0} -eq 0 ]; then
            :net:portpersist _ localhost ${tcpPort} 1
            assertFalse 0x2 $?
        fi
    done
}

function testCoreNetLocalportpingInternal() {
    core:import net

    :net:localportping 22
    assertFalse 0x1 $?

    :net:localportping 5000
    assertFalse 0x2 $?
}

function testCoreNetFreelocalportInternal() {
    core:import net

    local -i port
    for ((i=0; i<10; i++)); do
        port=$(:net:freelocalport)
        assertTrue 0x1 $?

        [ ${port} -lt 65536 ]
        assertTrue 0x2 $?

        [ ${port} -ge 1024 ]
        assertTrue 0x3 $?
    done
}

function testCoreNetMyipInternal() {
    core:import net

    local myip
    myip=$(:net:myip)
    assertEquals 0 $?
}
