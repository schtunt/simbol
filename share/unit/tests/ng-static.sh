# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import ng

#. ng -={
function ngOneTimeSetUp() {
    export SIMBOL_PROFILE=UNITTEST
    mock:clear
    mock:write <<-!MOCK
    declare -g l_CACHE_TTL=-1
    function :ldap:search() {
        case "\$*" in
            netgroup*nisNetgroupTriple=*host1.mockery.net,,*cn) echo "mockery_ng_level1";;
            netgroup*memberNisNetgroup=mockery_ng_level1*cn) echo "mockery_ng_top";;
            netgroup*memberNisNetgroup=mockery_ng_top*cn) true;;
            netgroup*cn*description*cn=*mockery_ng2*description=*) cat "${SIMBOL_UNIT_TESTS}/md5s/ldap/e5f4c98dff792a2ea86b6e201cd63c44" ;;
            netgroup*cn=mockery_ng_level1*memberNisNetgroup) true;;
            netgroup*cn=mockery_ng_level1*nisNetgroupTriple) echo "(host1.mockery.net,,)";;
            netgroup*cn=mockery_ng_top*memberNisNetgroup) echo "mockery_ng_level1";;
            netgroup*cn=mockery_ng_top*nisNetgroupTriple) true;;
            netgroup*cn*description*cn=*mockery_ng_top*description=*mockery_ng_level1*) printf "mockery_ng_level1\x07Second Level mockery netgroup";;
            netgroup*cn*description*cn=*description=*) cat "${SIMBOL_UNIT_TESTS}/md5s/ldap/004d082e3d6467935ab46e50d8879b90" ;;
            netgroup*cn*description) cat "${SIMBOL_UNIT_TESTS}/md5s/ldap/004d082e3d6467935ab46e50d8879b90" ;;
            netgroup*cn=*cn) echo "\${2#cn=}" ;;
            #*) echo "NoLdapSearchMockMatch"; echo "NoLdapSearchMockMatch" >> /tmp/debug ;;
        esac
        return 0
   }
!MOCK

}

function ngSetUp() {
    rm -rf "${SIMBOL_DEADMAN}"
}

function ngTearDown() {
    : pass
}

function ngOneTimeTearDown() {
    : pass
}

#. testCoreNgTree_dataPrivate-={
function testCoreNgTree_dataPrivate() {
    : pass
}
#. }=-

#. testCoreNgTreecpfPrivate-={
function testCoreNgTreecpfPrivate() {
    : pass
}
#. }=-

#. testCoreNgTree_drawPrivate-={
function testCoreNgTree_drawPrivate() {
    : pass
}
#. }=-

#. testCoreNgTree_buildPrivate-={
function testCoreNgTree_buildPrivate() {
    : pass
}
#. }=-


#. testCoreNgTreePublic-={
function testCoreNgTreePublic() {
    : pass
}
#. }=-

#. testCoreNgCreatePublic-={
function testCoreNgCreatePublic() {
    : pass
}
#. }=-
