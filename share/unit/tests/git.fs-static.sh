# vim: tw=0:ts=4:sw=4:et:ft=bash

function testCoreGitFsImport() {
    core:softimport git.fs
    assertTrue 0.0.0 $?
}

function gitFsSetUp() {
    git config --global user.email > /dev/null
    [ $? -eq 0 ] || git config --global user.email "travis.c.i@unit-testing.org"

    git config --global user.name > /dev/null
    [ $? -eq 0 ] || git config --global user.name "Travis C. I."

    declare -g g_PLAYGROUND="/tmp/git-pg"
}

function gitFsTearDown() {
    rm -rf ${g_PLAYGROUND?}
}

function test_1_3_CoreGitFsObjectsInternal() {
    core:import git.fs
    assertTrue 1.3.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}
    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}

    local -i c
    c=$(:git.fs:objects ${g_PLAYGROUND} | wc -l; exit ${PIPESTATUS[0]})
    assertTrue 1.3.1 $?
    assertEquals 1.3.2 66 ${c}
}

function test_2_1_CoreGitFsPlaygroundPublic() {
    core:import git.fs
    assertTrue 2.1.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}

    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue 2.1.1 $?

    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertFalse 2.1.2 $?
}

function test_2_2_CoreGitFsCommitallPublic() {
    core:import git.fs
    assertTrue 2.2.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}

    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    cd ${g_PLAYGROUND}
    git clean -q -f #. remove uncommitted crap from playground command first

    #. add 101 files
    for i in {1..101}; do
        local fN="fileA-${i}.data"
        dd if=/dev/urandom of=${fN} bs=1024 count=1 >${stdoutF?} 2>${stderrF?}
        git add ${fN}.data >${stdoutF?} 2>${stderrF?}
    done

    #. run commitall
    core:wrapper git.sink commitall >${stdoutF?} 2>${stderrF?}
    assertTrue 2.2.1 $?

    #. look for individual commits
    local -i committed=$(git log --pretty=format:'%s'|grep '^\.\.\.'|wc -l)
    assertEquals 0x1 101 ${committed}
}

function test_2_3_CoreGitFsSplitPublic() {
    core:import git.fs
    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}

    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
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
#    core:wrapper git.sink split HEAD >${stdoutF?} 2>${stderrF?}
#
#    #. test it worked
#    committed=$(git log --pretty=format:'%s'|grep '^\.\.\.'|wc -l)
#    assertEquals 0x2 99 ${committed}
}

function test_2_4_CoreGitFsBasedirInternal() {
    core:import git.fs
    assertTrue 2.4.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}
    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    cd ${g_PLAYGROUND}

    :git.fs:basedir ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue 2.4.1 $?
    assertEquals 2.4.2 "$(cat ${stdoutF?})" "${g_PLAYGROUND} ."

    :git.fs:basedir ${g_PLAYGROUND}/ >${stdoutF?} 2>${stderrF?}
    assertTrue 2.4.3 $?
    assertEquals 2.4.4 "$(cat ${stdoutF?})" "${g_PLAYGROUND} ."

    rm -rf ${g_PLAYGROUND}
    :git.fs:basedir ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertFalse 2.4.5 $?

    :git.fs:basedir /tmp >${stdoutF?} 2>${stderrF?}
    assertFalse 2.4.6 $?
}

function test_3_1_CoreGitFsSizePublic() {
    core:import git.fs
    assertTrue 3.1.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}
    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    cd ${g_PLAYGROUND}

    cd /
    core:wrapper git.fs size ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue 3.1.1 $?

    cd ${g_PLAYGROUND}
    core:wrapper git.fs size >${stdoutF?} 2>${stderrF?}
    assertTrue 3.1.2 $?
}

function test_3_2_CoreGitFsUsagePublic() {
    core:import git.fs
    assertTrue 3.2.0 $?

    : ${g_PLAYGROUND?}
    rm -rf ${g_PLAYGROUND}
    core:wrapper git.sink playground ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    cd ${g_PLAYGROUND}

    cd /
    core:wrapper git.fs usage ${g_PLAYGROUND} >${stdoutF?} 2>${stderrF?}
    assertTrue 3.2.1 $?

    cd ${g_PLAYGROUND}
    core:wrapper git.fs usage >${stdoutF?} 2>${stderrF?}
    assertTrue 3.2.2 $?
}
