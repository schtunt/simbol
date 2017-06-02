#!/usr/bin/env bash

#. The current test suite is unsafe to run on a non-disposable machine.  We're
#. working on removing that constraint by adding enough mechanisms to mock, to
#. obviate the need for sudo and other potentially destructive actions.
#.
#. Until then, use this script and copy-paste your `function test*' functions
#. in the place-holder section below.

SIMBOL_PROFILE=$(activate)
source ~/.simbol/.scm/lib/libsh/libsimbol/libsimbol.sh

function oneTimeSetUp() {
    declare -g oD="${SHUNIT_TMPDIR?}"
    mkdir -p "${oD}"
    declare -g stdoutF="${oD}/stdout"
    declare -g stderrF="${oD}/stderr"
}

function oneTimeTearDown() {
    :
}

#. -={
script=~/.simbol/.scm/share/unit/tests/hgd-static.sh
#. }=-

source ${script}
SHUNIT_PARENT="${script}" source "${SHUNIT2?}"
source ~/.simbol/var/libexec/shunit2
