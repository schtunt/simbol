# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
This modules handles everything Python!

You will need to install the dependencies; on Debian:

    sudo apt-get install libreadline-dev libbz2-dev zlib1g-dev libssl-dev
[core:docstring]

#. XPLM->Python -={
core:import xplm

#. py:list -={
function py:list() {
    local -i e; let e=CODE_DEFAULT

    xplm:list py "$@"
    e=$?

    return $e
}
#. }=-
#. py:install -={
function py:install:usage() { echo "[<pkg> [<pkg> [...]]]"; }
function py:install() {
    local -i e; let e=CODE_DEFAULT

    xplm:install py "$@"
    e=$?

    return $e
}
#. }=-
#. py:purge -={
function py:purge() {
    local -i e; let e=CODE_DEFAULT

    xplm:purge py "$@"
    e=$?

    return $e
}
#. }=-
#. py:shell -={
function py:shell() {
    local -i e; let e=CODE_DEFAULT

    xplm:shell py "$@"
    e=$?

    return $e
}
#. }=-
#. py:search -={
function py:search:usage() { echo "<search-str>"; }
function py:search() {
    local -i e; let e=CODE_DEFAULT

    xplm:search py "$@"
    e=$?

    return $e
}
#. }=-
#. py:repl -={
function py:repl() {
    local -i e; let e=CODE_DEFAULT

    xplm:repl py "$@"
    e=$?

    return $e
}
#. }=-
#. py:run -={
function py:run() {
    local -i e; let e=CODE_DEFAULT

    xplm:run py "$@"
    e=$?

    return $e
}
#. }=-
#. }=-
