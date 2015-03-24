# vim: tw=0:ts=4:sw=4:et:ft=bash

function testCoreGitSinkImport() {
    core:softimport git.sink
    assertTrue 0x0 $?
}

function gitSinkSetUp() {
    git config --global user.email > /dev/null
    [ $? -eq 0 ] || git config --global user.email "travis.c.i@unit-testing.org"

    git config --global user.name > /dev/null
    [ $? -eq 0 ] || git config --global user.name "Travis C. I."

    declare -g g_PLAYGROUND="/tmp/git-pg"
}

function gitSinkTearDown() {
    rm -rf ${g_PLAYGROUND?}
}

#. -={

#. 1.0 testCoreGitSinkFilePublic,testCoreGitSinkFilePublic,testCoreGitSinkRmPublic -={
function test_1_1_CoreGitSinkFilePublic() {
    core:import git.sink
    assertTrue 1.1.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}
    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    cd ${g_PLAYGROUND}

    #. Create a dirty little secret...
    echo "<dirty-little-secret>" >> BadFile

    local -i c
    c=$(core:wrapper git.sink file BadFile | wc -l 2>${stderrF?})
    assertEquals 1.1.1 0 ${c} #. nothing here yet

    #. Add it...
    git add BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue 1.1.2 $?

    #. Commit it...
    git commit BadFile -m "BadFile added" >${stdoutF?} 2>${stderrF?}
    assertTrue 1.1.3 $?

    #. Verify add/commit...
    c=$(core:wrapper git.sink file BadFile | wc -l 2>${stderrF?})
    assertEquals 1.1.4 1 ${c}

    #. Continued in section 1.1...
}
function test_1_2_CoreGitSinkFilePublic() {
    #. ...continued from section 1.0...
    core:import git.sink
    assertTrue 1.2.0 $?

    #. Delete it...
    git rm BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue 1.2.1 $?

    #. Commit it...
    git commit BadFile -m "BadFile removed" >${stdoutF?} 2>${stderrF?}
    assertTrue 1.2.2 $?

    #. Verify delete...
    local -i c
    c=$(core:wrapper git.sink file BadFile | wc -l 2>${stderrF?})
    assertEquals 1.2.3 2 ${c}

    #. Continued in section 1.2...
}
function test_1_3_CoreGitSinkRmPublic() {
    #. ...continued from section 1.1...
    core:import git.sink
    assertTrue 1.3.0 $?

    #. Remove it from history...
    core:wrapper git.sink rm BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue 1.3.1 $?

    #. Verify history rewrite...
    local -i c
    c=$(core:wrapper git.sink file BadFile | wc -l 2>${stderrF?})
    assertEquals 1.3.2 0 ${c} #. all gone

    #. The End
}
#. }=-
#. 2.0 testCoreGitSinkPlaygroundPublic,testCoreGitSinkCommitallPublic -={
function test_2_1_CoreGitSinkPlaygroundPublic() {
    core:import git.sink
    assertTrue 2.1.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}
    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue 2.1.1 $?

    test ${g_PLAYGROUND}/.git
    assertTrue 2.1.2 $?
}
function test_2_2_CoreGitSinkCommitallPublic() {
    core:import git.sink
    assertTrue 2.2.0 $?

    : ${g_PLAYGROUND?}
    cd ${g_PLAYGROUND}

    core:wrapper git.sink commitall >${stdoutF?} 2>${stderrF?}
    assertTrue 2.2.1.1 $?
    [ $(wc -c < ${stdoutF?}) -gt 0 ]
    assertTrue 2.2.1.2 $?

    core:wrapper git.sink commitall >${stdoutF?} 2>${stderrF?}
    assertTrue 2.2.2.1 $?
    [ $(wc -c < ${stdoutF?}) -gt 0 ]
    assertFalse 2.2.2.2 $?
}
#. }=-
#. 3.0 testCoreGitSinkObjectsPublic -={
function testCoreGitSinkObjectsPublic() {
    core:import git.sink
    assertTrue 0.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}
    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}

    local -i c
    c=$(core:wrapper git.sink objects ${g_PLAYGROUND} | wc -l 2>${stderrF?})
    assertEquals 0.1 66 ${c}
}
#. }=-
#. 4.0 testCoreGitSinkVacuumPublic -={
function testCoreGitSinkVacuumPublic() {
    core:import git.sink
    assertTrue 0.0 $?

    core:wrapper git.sink vacuum ${SIMBOL_SCM?} >${stdoutF?} 2>${stderrF?}
    assertTrue 0.1 $?
}
#. }=-
#. }=-
