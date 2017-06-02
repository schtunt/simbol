# vim: tw=0:ts=4:sw=4:et:ft=bash

function dnsSetUp() {
    core:import util
    core:import dns
    assertTrue "${FUNCNAME?}/0" $?
}

function dnsTearDown() {
    : noop
}

function tearDown() {
    mock:clear
}

#. -={
#. testCoreDnsResolveInternal -={
function testCoreDnsResolveInternalHits() {
    local data

    data=$(:dns:resolve google-public-dns-a.google.com. a)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" '8.8.8.8' "${data}"

    data=$(:dns:resolve google-public-dns-b.google.com a)
    assertTrue "${FUNCNAME?}/2.1" $?
    assertEquals "${FUNCNAME?}/2.2" '8.8.4.4' "${data}"
}

function testCoreDnsResolveInternalGuesses() {
    local data

    data=$(:dns:resolve google-public-dns-a.google.com.)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" '8.8.8.8' "${data}"

    data=$(:dns:resolve google-public-dns-b.google.com)
    assertTrue "${FUNCNAME?}/2.1" $?
    assertEquals "${FUNCNAME?}/2.2" '8.8.4.4' "${data}"
}

function testCoreDnsResolveInternalMisses() {
    local data

    data=$(:dns:resolve 404.google.com a)
    assertFalse "${FUNCNAME?}/1" $?

    data=$(:dns:resolve 404.google.com c)
    assertFalse "${FUNCNAME?}/2" $?

    data=$(:dns:resolve 404.google.com)
    assertFalse "${FUNCNAME?}/3" $?
}
#. }=-
#. testCoreDnsSubdomainsInternal -={
function testCoreDnsSubdomainsInternalFull() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( [a]='aws.amazon.com' [b]='buildings.amazon.com' )
        local -a USER_SUBDOMAIN_a=( s3 ec2 ddb rds )
        local -a USER_SUBDOMAIN_b=( dopler arizona kumo blackfoot )
        local USER_TLDID_DEFAULT='b'
	!MOCK

    local -a sdns
    local -a results

    sdns=( $(mock:wrapper dns :subdomains a full) )
    assertTrue "${FUNCNAME?}/1.1" $?
    results=( {s3,ec2,ddb,rds}.aws.amazon.com )
    assertEquals "${FUNCNAME?}/1.2"\
        "$(:util:join , results)"\
        "$(:util:join , sdns)"

    sdns=( $(mock:wrapper dns :subdomains b full) )
    assertTrue "${FUNCNAME?}/2.1" $?
    results=( {dopler,arizona,kumo,blackfoot}.buildings.amazon.com )
    assertEquals "${FUNCNAME?}/2.2"\
        "$(:util:join , results)"\
        "$(:util:join , sdns)"

    sdns=( $(mock:wrapper dns :subdomains _ full) )
    assertTrue "${FUNCNAME?}/3.1" $?
    results=( {dopler,arizona,kumo,blackfoot}.buildings.amazon.com )
    assertEquals "${FUNCNAME?}/3.2"\
        "$(:util:join , results)"\
        "$(:util:join , sdns)"
}

function testCoreDnsSubdomainsInternalShort() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( [a]='aws.amazon.com' [b]='buildings.amazon.com' )
        local -a USER_SUBDOMAIN_a=( s3 ec2 ddb rds )
        local -a USER_SUBDOMAIN_b=( dopler arizona kumo blackfoot )
        local USER_TLDID_DEFAULT='a'
	!MOCK

    local -a sdns
    local -a results

    sdns=( $(mock:wrapper dns :subdomains a short) )
    assertTrue "${FUNCNAME?}/1.1" $?
    results=( {s3,ec2,ddb,rds} )
    assertEquals "${FUNCNAME?}/1.2"\
        "$(:util:join , results)"\
        "$(:util:join , sdns)"

    sdns=( $(mock:wrapper dns :subdomains b short) )
    assertTrue "${FUNCNAME?}/2.1" $?
    results=( {dopler,arizona,kumo,blackfoot} )
    assertEquals "${FUNCNAME?}/2.2"\
        "$(:util:join , results)"\
        "$(:util:join , sdns)"

    sdns=( $(mock:wrapper dns :subdomains _ short) )
    assertTrue "${FUNCNAME?}/3.1" $?
    results=( {s3,ec2,ddb,rds} )
    assertEquals "${FUNCNAME?}/3.2"\
        "$(:util:join , results)"\
        "$(:util:join , sdns)"
}
#. }=-
#. testCoreDnsSubdomainsPublic -={
function testCoreDnsSubdomainsPublicShort() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( [a]='aws.amazon.com' [b]='buildings.amazon.com' )
        local -a USER_SUBDOMAIN_a=( s3 ec2 ddb rds )
        local -a USER_SUBDOMAIN_b=( dopler arizona kumo blackfoot )
        local USER_TLDID_DEFAULT='a'
	!MOCK

    local -a sdns
    local -a results

    sdns=( $(mock:wrapper dns subdomains -T a -s) )
    assertTrue "${FUNCNAME?}/1" $?

    sdns=( $(mock:wrapper dns subdomains -T b -s) )
    assertTrue "${FUNCNAME?}/2" $?

    sdns=( $(mock:wrapper dns subdomains -T_ -s) )
    assertTrue "${FUNCNAME?}/3" $?

    sdns=( $(mock:wrapper dns subdomains -s) )
    assertTrue "${FUNCNAME?}/4" $?
}

function testCoreDnsSubdomainsPubliclShortMiss() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( )
        unset USER_SUBDOMAIN_x
        unset USER_SUBDOMAIN_y
	!MOCK

    mock:wrapper dns subdomains -Tx -s
    assertFalse "${FUNCNAME?}/1" $?

    mock:wrapper dns subdomains -Ty
    assertFalse "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreDnsInspectCsvInternal -={
function testCoreDnsInspectCsvInternal() {
    local -a data

    data=( $(:dns:inspect.csv 'google-public-dns-a.google.com.' a) )
    assertTrue   "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" 1 ${#data[@]}
    assertEquals "${FUNCNAME?}/1.3"\
        "a,google-public-dns-a.google.com.,ext,-,-,-,google-public-dns-a.google.com.,8.8.8.8,3"\
        "${data[0]}"

    #TODO: Look in git history for a comprehensive test, when you figure out
    #TODO: a way to mock DNS
}
#. }=-
#. testCoreDnsLookupCsvInternal -={
function testCoreDnsLookupCsvInternal() {
    local -a data

    #TODO: Look in git history for a comprehensive test, when you figure out
    #TODO: a way to mock DNS
}
#. }=-
#. testCoreDnsLookupPublic -={
function testCoreDnsLookupPublic() {
    local hostname

    hostname='www.amazon.com'
    mock:wrapper dns lookup ${hostname} >${stdoutF?} 2>${stderrF?}
    assertTrue   "${FUNCNAME?}/1" $?

    hostname='www.schtunt.com'
    mock:wrapper dns lookup ${hostname} >${stdoutF?} 2>${stderrF?}
    assertFalse  "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreDnsTldidsPublic -={
function testCoreDnsTldidsPublic() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( [a]='aws.amazon.com' [b]='buildings.amazon.com' )
        local -a USER_SUBDOMAIN_a=( s3 ec2 ddb rds )
        local -a USER_SUBDOMAIN_b=( dopler arizona kumo blackfoot )
        local USER_TLDID_DEFAULT='a'
	!MOCK

    local data

    data="$(mock:wrapper dns tldids)"
    assertTrue "${FUNCNAME?}/1.1" $?
    local -i len=$(wc -l <<< "${data}")
    assertEquals "${FUNCNAME?}/1.2" 2 ${len}

    data="$(mock:wrapper dns tldids .)"
    assertTrue "${FUNCNAME?}/2.1" $?
    local -i len=$(wc -l <<< "${data}")
    assertEquals "${FUNCNAME?}/2.2" 2 ${len}

    data="$(mock:wrapper dns tldids b)"
    assertTrue "${FUNCNAME?}/3.1" $?
    local -i len=$(wc -l <<< "${data}")
    assertEquals "${FUNCNAME?}/3.2" 1 ${len}
}

function testCoreDnsTldidsPublicMiss() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( )
        unset USER_SUBDOMAIN_z
	!MOCK

    data="$(mock:wrapper dns tldids z)"
    assertFalse "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreDnsGetInternal -={
function testCoreDnsGetInternal() {
    local data
    data=$(mock:wrapper dns :get . usdn www.google.com.)
    assertTrue "${FUNCNAME?}/1" $?

    data=$(mock:wrapper dns :get . qdn www.google.com.)
    assertTrue "${FUNCNAME?}/2" $?

    data=$(mock:wrapper dns :get . fqdn www.google.com.)
    assertTrue "${FUNCNAME?}/3" $?

    data=$(mock:wrapper dns :get . resolved www.google.com.)
    assertTrue "${FUNCNAME?}/4" $?
}
#. }=-
#. testCoreDnsFqdnPublic -={
function testCoreDnsFqdnPublic() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( [a]='aws.amazon.com' [b]='buildings.amazon.com' )
        local -a USER_SUBDOMAIN_a=( s3 ec2 ddb rds )
        local -a USER_SUBDOMAIN_b=( dopler arizona kumo blackfoot )
        local USER_TLDID_DEFAULT='a'
	!MOCK

    local data

    data=$(mock:wrapper dns fqdn -T . www.google.com.)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" "www.google.com." "${data}"

    data=$(mock:wrapper dns fqdn www.google.com.)
    assertFalse "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreDnsQdnPublic -={
function testCoreDnsQdnPublic() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( [a]='aws.amazon.com' [b]='buildings.amazon.com' )
        local -a USER_SUBDOMAIN_a=( s3 ec2 ddb rds )
        local -a USER_SUBDOMAIN_b=( dopler arizona kumo blackfoot )
        local USER_TLDID_DEFAULT='a'
	!MOCK

    local data

    data=$(mock:wrapper dns qdn -T . www.google.com.)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" "www.google.com." "${data}"

    data=$(mock:wrapper dns qdn www.google.com.)
    assertFalse "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreDnsUsdnPublic -={
function testCoreDnsUsdnPublic() {
    mock:write <<-!MOCK
        local -A USER_TLDS=( [a]='aws.amazon.com' [b]='buildings.amazon.com' )
        local -a USER_SUBDOMAIN_a=( s3 ec2 ddb rds )
        local -a USER_SUBDOMAIN_b=( dopler arizona kumo blackfoot )
        local USER_TLDID_DEFAULT='a'
	!MOCK

    local data

    data=$(mock:wrapper dns usdn -T . www.google.com.)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" "-" "${data}"

    data=$(mock:wrapper dns usdn www.google.com.)
    assertFalse "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreDnsIscnameInternal -={
function testCoreDnsIscnameInternal() {
    mock:wrapper dns :iscname . www.amazon.com
    assertTrue "${FUNCNAME?}/1" $?

    mock:wrapper dns :iscname . www.google.com
    assertFalse "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreDnsIsarecordInternal -={
function testCoreDnsIsarecordInternal() {
    mock:wrapper dns :isarecord . www.google.com
    assertTrue "${FUNCNAME?}/1" $?

    mock:wrapper dns :isarecord . www.amazon.com
    assertFalse "${FUNCNAME?}/2" $?
}
#. }=-
#. }=-
