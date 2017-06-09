# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
This modules handles everything Perl!
[core:docstring]

#. XPLM->Perl -={
core:import xplm

#. pl:list -={
function pl:list() {
    local -i e; let e=CODE_DEFAULT

    xplm:list pl "$@"
    e=$?

    return $e
}
#. }=-
#. pl:install -={
function pl:install:usage() { echo "[<pkg> [<pkg> [...]]]"; }
function pl:install() {
    local -i e; let e=CODE_DEFAULT

    xplm:install pl "$@"
    e=$?

    return $e
}
#. }=-
#. pl:purge -={
function pl:purge() {
    local -i e; let e=CODE_DEFAULT

    xplm:purge pl "$@"
    e=$?

    return $e
}
#. }=-
#. pl:shell -={
function pl:shell() {
    local -i e; let e=CODE_DEFAULT

    xplm:shell pl "$@"
    e=$?

    return $e
}
#. }=-
#. pl:search -={
function pl:search:usage() { echo "<search-str>"; }
function pl:search() {
    local -i e; let e=CODE_DEFAULT

    xplm:search pl "$@"
    e=$?

    return $e
}
#. }=-
#. pl:repl -={
function pl:repl() {
    local -i e; let e=CODE_DEFAULT

    xplm:repl pl "$@"
    e=$?

    return $e
}
#. }=-
#. pl:run -={
function pl:run() {
    local -i e; let e=CODE_DEFAULT

    xplm:run pl "$@"
    e=$?

    return $e
}
#. }=-
#. }=-
