# vim: tw=0:ts=4:sw=4:et:ft=bash

function testCoreGitImport() {
    core:softimport git
    assertTrue 0x0 $?
}

function gitSetUp() {
    git config --global user.email > /dev/null
    [ $? -eq 0 ] || git config --global user.email "travis.c.i@unit-testing.org"

    git config --global user.name > /dev/null
    [ $? -eq 0 ] || git config --global user.name "Travis C. I."

    declare -g g_PLAYGROUND="/tmp/git-pg"
}

function gitTearDown() {
    rm -rf ${g_PLAYGROUND?}
}

function test_1_1_CoreGitRmPublic() {
    core:import git
    cd ${SIMBOL_SCM?}

    dd if=/dev/urandom of=BadFile count=1024 bs=1024 >${stdoutF?} 2>${stderrF?}
    assertTrue 0x0 $?
}

function test_1_2_CoreGitFilePublic() {
    core:import git

    cd ${SIMBOL_SCM?}

    local -i c

    c=$(core:wrapper git file BadFile | wc -l 2>${stderrF?})
    assertEquals 0x0 0 ${c} #. nothing here yet

    #. Add it
    git add BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?

    git commit BadFile -m "BadFile added" >${stdoutF?} 2>${stderrF?}
    assertTrue 0x2 $?

    c=$(core:wrapper git file BadFile | wc -l 2>${stderrF?})
    assertEquals 0x3 1 ${c} #. added

    #. Delete it
    git rm BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue 0x4 $?

    git commit BadFile -m "BadFile removed" >${stdoutF?} 2>${stderrF?}
    assertTrue 0x5 $?

    c=$(core:wrapper git file BadFile | wc -l 2>${stderrF?})
    assertEquals 0x6 2 ${c} #. added and removed

    #. Remove it from history
    core:wrapper git rm BadFile >${stdoutF?} 2>${stderrF?}
    assertTrue 0x7 $?

    #. Assert it is really gone
    #. FIXME: NFI why this doesn't work on Travis, can't reproduce it locally
    #c=$(core:wrapper git file BadFile | wc -l 2>${stderrF?})
    #assertEquals 0x8 0 ${c} #. all gone
}

function test_1_4_CoreGitVacuumPublic() {
    core:import git

    core:wrapper git vacuum ${SIMBOL_SCM?} >${stdoutF?} 2>${stderrF?}
    assertTrue 0x0 $?
}

function test_2_1_CoreGitPlaygroundPublic() {
    core:import git
    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}

    core:wrapper git playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue 0x0 $?

    core:wrapper git playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertFalse 0x0 $?
}

function test_2_2_CoreGitCommitallPublic() {
    core:import git
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
    assertTrue 0x0 $?

    #. look for individual commits
    local -i committed=$(git log --pretty=format:'%s'|grep '^\.\.\.'|wc -l)
    assertEquals 0x1 101 ${committed}
}

function test_2_3_CoreGitSplitPublic() {
    core:import git
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
    committed=$(git log --pretty=format:'%s'|grep '^\.\.\.'|wc -l)
    assertEquals 0x1 0 ${committed}

#. TODO: This is interactive due to the `git rebase -i'
#    #. now split them up
#    core:wrapper git split HEAD >${stdoutF?} 2>${stderrF?}
#
#    #. test it worked
#    committed=$(git log --pretty=format:'%s'|grep '^\.\.\.'|wc -l)
#    assertEquals 0x2 99 ${committed}
}

function test_2_4_CoreGitBasedirInternal() {
    core:import git
    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}

    core:wrapper git playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    cd ${g_PLAYGROUND}

    :git:basedir ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue 0x0 $?

    rm -rf ${g_PLAYGROUND}

    :git:basedir ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertFalse 0x0 $?

    :git:basedir /tmp >${stdoutF?} 2>${stderrF?}
    assertFalse 0x0 $?
}

function test_3_1_CoreGitSizePublic() {
    core:import git

    cd /
    core:wrapper git size ${SIMBOL_SCM?} >${stdoutF?} 2>${stderrF?}
    assertTrue 0x0 $?

    cd ${SIMBOL_SCM?}
    core:wrapper git size >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?

    cd ${SIMBOL_SCM?}/module
    core:wrapper git size >${stdoutF?} 2>${stderrF?}
    assertTrue 0x2 $?
}

function test_3_1_CoreGitUsagePublic() {
    core:import git

    cd /
    core:wrapper git usage ${SIMBOL_SCM?} >${stdoutF?} 2>${stderrF?}
    assertTrue 0x0 $?

    cd ${SIMBOL_SCM?}
    core:wrapper git usage >${stdoutF?} 2>${stderrF?}
    assertTrue 0x1 $?

    cd ${SIMBOL_SCM?}/module
    core:wrapper git usage >${stdoutF?} 2>${stderrF?}
    assertTrue 0x2 $?
}
