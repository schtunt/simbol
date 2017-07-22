# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import ldap

#. ldap -={
function ldapOneTimeSetUp() {
    export SIMBOL_PROFILE=UNITTEST
    mock:clear
    mock:write <<-!MOCK
        declare -a USER_LDAPHOSTS=( ldap1.mockery.net ldap2.mockery.net ldap3.mockery.net )
        declare -a USER_LDAPHOSTS_RW=( ldap1.rw.mockery.net ldap2.rw.mockery.net )
        declare -g USER_UDN="ou=users,dc=mockery,dc=net"
        declare -g USER_GDN="ou=groups,dc=mockery,dc=net"
        declare -g USER_NDN="ou=netgroups,dc=mockery,dc=net"
        declare -g USER_HDN="ou=hosts,dc=mockery,dc=net"
        declare -g USER_SDN="ou=subnets,dc=mockery,dc=net"
        declare -g g_LDAPHOST=0

        export USER_LDAPHOSTS USER_LDAPHOSTS_RW
	    function :vault:read() { echo "pa55w0rd"; return 0; }
	    function ldapsearch() { echo "ldapsearch \$@" >> /tmp/debug;
            case "\$*" in
                -x*-LLL*-h*ldap1.mockery.net*-b*\${USER_HDN}*\&*cn=host1.mockery.net*ipHostNumber=*ipHostNumber) cat "${SIMBOL_UNIT_TESTS}/md5s/ldap/cefd1aa0dcd563c87f69c583052d6859" ;;
                -x*-LLL*-h*ldap1.mockery.net*-b*\${USER_UDN}*\&*uid=schtunt*homeDirectory=*homeDirectory) cat "${SIMBOL_UNIT_TESTS}/md5s/ldap/eaa8644b5c27fcb0e3b558840715624f" ;;
                -x*-LLL*-h*ldap1.mockery.net*-b*\${USER_GDN}*\&*cn=schtunts*gidNumber=*gidNumber) cat "${SIMBOL_UNIT_TESTS}/md5s/ldap/693e7d519876cefbd0fbe09873f2c101" ;;
                -x*-LLL*-h*ldap1.mockery.net*-b*\${USER_NDN}*\&*cn=schtunt-hosts*nisNetgroupTriple=*nisNetgroupTriple) cat "${SIMBOL_UNIT_TESTS}/md5s/ldap/a5c04cee101a2b2aa9aeb3302098b29e" ;;
                -x*-LLL*-h*ldap1.mockery.net*-b*\${USER_SDN}*\&*cn=services*ipNetworkNumber=*ipNetworkNumber) cat "${SIMBOL_UNIT_TESTS}/md5s/ldap/8efd0c25796dca275ef6a9b495079e1a" ;;
            esac
            return 0;
        }
	    function ldapmodify() { return 0; }
        #function :ldap:search() {
        #    case "\$*" in
        #        0*host*cn=host1.mockery.net*ipHostNumber) echo "1.2.3.4";;
        #        0*user*uid=schtunt*homeDirectory) echo "/home/schtunt";;
        #        0*group*cn=schtunts*gidNumber) echo "1000";;
        #        0*subnet*cn=services*ipNetworkNumber) echo "10.0.0.0";;
        #        0*netgroup*cn=schtunt-hosts*nisNetgroupTriple) echo "(schtunt1.mockery.net,,) (schtunt2.mockery.net,,)";;
        #    esac
            return 0
        }
!MOCK

}

function ldapSetUp() {
    rm -rf "${SIMBOL_DEADMAN}"
}

function ldapTearDown() {
    : pass
}

function ldapOneTimeTearDown() {
    : pass
}

#. testCoreLdapHostInternal -={
function testCoreLdapHostInternal() {
    local rv
    # random one
    mock:wrapper ldap :host >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME[0]}/1.1" $?
    rv="$(cat "${stdoutF}")"
    assertEquals "${FUNCNAME[0]}/1.2" mockery.net "${rv#*.}"

    # 2nd one
    mock:wrapper ldap :host 1 >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME[0]}/1.3" $?
    rv="$(cat "${stdoutF}")"
    assertEquals "${FUNCNAME[0]}/1.4" ldap2.mockery.net "${rv}"

    # bad index one
    mock:wrapper ldap :host 4 >"${stdoutF?}" 2>"${stderrF?}"
    assertFalse "${FUNCNAME[0]}/1.5" $?
}
#. }=-

#. testCoreLdapHost_rwInternal -={
function testCoreLdapHost_rwInternal() {
    local rv
    mock:wrapper ldap :host_rw >"${stdoutF?}" 2>"${stderrF?}"
    assertTrue "${FUNCNAME[0]}/1.1" $?
    rv="$(cat "${stdoutF}")"
    assertEquals "${FUNCNAME[0]}/1.2" rw.mockery.net "${rv#*.}"
    : pass
}
#. }=-

#. testCoreLdapAddInternal -={
function testCoreLdapAddInternal() {
    : pass
}

#. }=-
#. testCoreLdapSearchEvalInternal -={
function testCoreLdapSearchEvalInternal() {
    : pass
}

#. }=-
#. testCoreLdapSearchInternal -={
function testCoreLdapSearchInternal() {
    : pass
}

#. }=-
#. testCoreLdapChecksumPublic -={
function testCoreLdapChecksumPublic() {
    : pass
}

#. }=-
#. testCoreLdapSearchPublic -={
function testCoreLdapSearchPublic() {
    : pass
}
#. }=-

#. testCoreLdapNgverifyPublic -={
function testCoreLdapNgverifyPublic() {
    : pass
}
#. }=-
