# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
This modules handles everything Ruby!
[core:docstring]

#. XPLM->Ruby -={
core:import xplm

#. rb:list -={
function rb:list() {
    local -i e; let e=CODE_DEFAULT

    xplm:list rb "$@"
    e=$?

    return $e
}
#. }=-
#. rb:install -={
function rb:install:usage() { echo "[<pkg> [<pkg> [...]]]"; }
function rb:install() {
    local -i e; let e=CODE_DEFAULT

    xplm:install rb "$@"
    e=$?

    return $e
}
#. }=-
#. rb:purge -={
function rb:purge() {
    local -i e; let e=CODE_DEFAULT

    xplm:purge rb "$@"
    e=$?

    return $e
}
#. }=-
#. rb:shell -={
function rb:shell() {
    local -i e; let e=CODE_DEFAULT

    xplm:shell rb "$@"
    e=$?

    return $e
}
#. }=-
#. rb:search -={
function rb:search:usage() { echo "<search-str>"; }
function rb:search() {
    local -i e; let e=CODE_DEFAULT

    xplm:search rb "$@"
    e=$?

    return $e
}
#. }=-
#. rb:repl -={
function rb:repl() {
    local -i e; let e=CODE_DEFAULT

    xplm:repl rb "$@"
    e=$?

    return $e
}
#. }=-
#. rb:run -={
function rb:run() {
    local -i e; let e=CODE_DEFAULT

    xplm:run rb "$@"
    e=$?

    return $e
}
#. }=-
#. }=-
