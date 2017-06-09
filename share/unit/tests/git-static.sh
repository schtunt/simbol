# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import git

#. Git -={
function gitOneTimeSetUp() {
    declare -g g_PLAYGROUND="/tmp/git-pg.$$"
    mock:wrapper git playground "${g_PLAYGROUND}.template" >& /dev/null
    assertTrue "${FUNCNAME?}/0" $?
}

function gitSetUp() {
    cp -a "${g_PLAYGROUND}.template" "${g_PLAYGROUND}"
    assertTrue "${FUNCNAME?}/0" $?
}

function gitTearDown() {
    rm -rf ${g_PLAYGROUND?}
    assertTrue "${FUNCNAME?}/0" $?
}

function gitOneTimeTearDown() {
    rm -rf "${g_PLAYGROUND?}.template"
    assertTrue "${FUNCNAME?}/0" $?
}

#. testCoreGitFilePublic() -={
#shellcheck disable=SC2164
function testCoreGitFilePublic() {
    cd "${g_PLAYGROUND?}"

    local -i c
    let c=$(core:wrapper git file BadFile | wc -l 2>${stderrF?})
    assertEquals "${FUNCNAME?}/0" 0 ${c} #. nothing here yet

    #. Add it
    echo "Evil" > BadFile
    git add BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1" $?

    git commit BadFile -m "BadFile added" >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2" $?

    c=$(core:wrapper git file BadFile | wc -l 2>${stderrF?})
    assertEquals "${FUNCNAME?}/3" 1 ${c} #. added

    #. Delete it
    git rm BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/4" $?

    git commit BadFile -m "BadFile removed" >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/5" $?

    c=$(core:wrapper git file BadFile | wc -l 2>${stderrF?})
    assertEquals "${FUNCNAME?}/6" 2 ${c} #. added and removed

    #. Remove it from history
    core:wrapper git rm BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/7" $?

    #. Assert it is really gone
    c=$(core:wrapper git file BadFile | wc -l 2>${stderrF?})
    assertEquals "${FUNCNAME?}/8" 0 ${c}
}
#. }=-
#. testCoreGitRmPublic -={
function testCoreGitRmPublic() {
    : Tested in testCoreGitFilePublic
}
#. }=-
#. testCoreGitVacuumPublic -={
function testCoreGitVacuumPublic() {
    core:wrapper git vacuum ${g_PLAYGROUND?} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?
}
#. }=-
#. testCoreGitPlaygroundPublic -={
function testCoreGitPlaygroundPublic() {
    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}

    core:wrapper git playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?

    core:wrapper git playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/0" $?
}
#. }=-
#. testCoreGitCommitallPublic -={
#shellcheck disable=SC2164
function testCoreGitCommitallPublic() {
    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}

    core:wrapper git playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    cd ${g_PLAYGROUND}
    git clean -q -f #. remove uncommitted crap from playground command first

    #. add 101 files
    for i in {1..101}; do
        local fN="fileA-${i}.data"
        dd if=/dev/urandom of=${fN} bs=1024 count=1 >${stdoutF?} 2>${stderrF?}
        git add ${fN}.data >${stdoutF?} 2>${stderrF?}
    done

    #. run commitall
    core:wrapper git commitall >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?

    #. look for individual commits
    local -i committed=$(git log --pretty=format:'%s'|grep -c '^\.\.\.')
    assertEquals "${FUNCNAME?}/1" 101 ${committed}
}
#. }=-
#. testCoreGitSplitPublic -={
#shellcheck disable=SC2164
function testCoreGitSplitPublic() {
    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}

    core:wrapper git playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    cd ${g_PLAYGROUND}
    git clean -q -f #. remove uncommitted crap from playground command first

    #. add 99 files
    for i in {1..99}; do
        local fN="fileB-${i}.data"
        dd if=/dev/urandom of=${fN} bs=1024 count=1 >${stdoutF?} 2>${stderrF?}
    done

    #. commit them all in one hit
    git add fileB-*.data >${stdoutF?} 2>${stderrF?}
    git commit -a -m '99 files added' >${stdoutF?} 2>${stderrF?}

    local -i committed

    #. look for single commits
    committed=$(git log --pretty=format:'%s'|grep -c '^\.\.\.')
    assertEquals "${FUNCNAME?}/1" 0 ${committed}

#. TODO: This is interactive due to the `git rebase -i'
#    #. now split them up
#    core:wrapper git split HEAD >${stdoutF?} 2>${stderrF?}
#
#    #. test it worked
#    committed=$(git log --pretty=format:'%s'|grep '^\.\.\.'|wc -l)
#    assertEquals "${FUNCNAME?}/2" 99 ${committed}
}
#. }=-
#. testCoreGitBasedirInternal -={
#shellcheck disable=SC2164
function testCoreGitBasedirInternal() {
    : ${g_PLAYGROUND?}

    cd ${g_PLAYGROUND}

    :git:basedir ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?

    :git:basedir ${g_PLAYGROUND}.wat >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/0" $?

    :git:basedir /tmp >${stdoutF?} 2>${stderrF?}
    assertFalse "${FUNCNAME?}/0" $?
}
#. }=-
#. testCoreGitSizePublic -={
#shellcheck disable=SC2164
function testCoreGitSizePublic() {
    cd /
    core:wrapper git size ${g_PLAYGROUND?} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?

    cd "${g_PLAYGROUND?}"
    core:wrapper git size >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1" $?

    cd "${g_PLAYGROUND?}"
    core:wrapper git size >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2" $?
}
#. }=-
#. testCoreGitUsagePublic -={
#shellcheck disable=SC2164
function testCoreGitUsagePublic() {
    cd /
    core:wrapper git usage ${g_PLAYGROUND?} >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/0" $?

    cd "${g_PLAYGROUND?}"
    core:wrapper git usage >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/1" $?

    cd "${g_PLAYGROUND?}"
    core:wrapper git usage >${stdoutF?} 2>${stderrF?}
    assertTrue "${FUNCNAME?}/2" $?
}
#. }=-
#. }=-
