# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import ldap

#. ldap -={
function ldapOneTimeSetUp() {
    export SIMBOL_PROFILE=UNITTEST
}

function ldapSetUp() {
    : pass
}

function ldapTearDown() {
    : pass
}

function ldapOneTimeTearDown() {
    : pass
}

#. testCoreLdapHostInternal -={
function testCoreLdapHostInternal() {
    : pass
}
#. }=-

#. testCoreLdapHost_rwInternal -={
function testCoreLdapHost_rwInternal() {
    : pass
}
#. }=-

#. testCoreLdapAuthenticateInternal -={
function testCoreLdapAuthenticateInternal() {
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

#. testCoreLdapMkldifPrivate -={
function testCoreLdapMkldifPrivate() {
    : pass
}
#. }=-

#. testCoreLdapMkldifPublic -={
function testCoreLdapMkldifPublic() {
    : pass
}
#. }=-
