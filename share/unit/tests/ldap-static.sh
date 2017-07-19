# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import ldap

#. ldap -={
function ldapOneTimeSetUp() {
    export SIMBOL_PROFILE=UNITTEST
    mock:clear
    mock:write <<-!MOCK
        declare -a USER_LDAPHOSTS=( ldap1.mockery.net ldap2.mockery.net ldap3.mockery.net )
        declare -a USER_LDAPHOSTS_RW=( ldap1.rw.mockery.net ldap2.rw.mockery.net )
        declare USER_GDN="ou=groups,dc=mockery,dc=net"
        export USER_LDAPHOSTS USER_LDAPHOSTS_RW
	    function :vault:read() { echo "pa55w0rd"; return 0; }
	    function ldapsearch() { return 0; }
	    function ldapmodify() { return 0; }
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
