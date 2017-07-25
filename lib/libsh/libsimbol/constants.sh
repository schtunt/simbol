# vim: tw=0:ts=4:sw=4:et:ft=bash
#shellcheck disable=SC2034,SC2155

set -f
set -u

#shellcheck disable=SC2086
if [ ${SOURCED_CONSTANTS:-0} -eq 0 ]; then

#. Constants -={
declare -r SIMBOL_VERSION="1.0-rc3"; export SIMBOL_VERSION
declare -r SIMBOL_DATE_FORMAT="%x-%X"; export SIMBOL_DATE_FORMAT
declare BASH_DECLARE_GLOBAL_OPTS=g

#. Magic Numbers -={

case ${BASH_VERSINFO[0]}:${BASH_VERSINFO[1]}:${BASH_VERSINFO[2]} in
    4:[01]:*) BASH_DECLARE_GLOBAL_OPTS=;;
esac
export BASH_DECLARE_GLOBAL_OPTS

declare -ri${BASH_DECLARE_GLOBAL_OPTS} FD_STDIN=0; export FD_STDIN
declare -ri${BASH_DECLARE_GLOBAL_OPTS} FD_STDOUT=1; export FD_STDOUT
declare -ri${BASH_DECLARE_GLOBAL_OPTS} FD_STDERR=2; export FD_STDERR

true; declare -ri${BASH_DECLARE_GLOBAL_OPTS} TRUE=$?; export TRUE
false; declare -ri${BASH_DECLARE_GLOBAL_OPTS} FALSE=$?; export FALSE
declare -A SIMBOL_BOOL=( [false]=${FALSE?} [true]=${TRUE?} ); export SIMBOL_BOOL


#. 0x00..0x1f General Error Codes -={
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_SUCCESS=0x00; export CODE_SUCCESS
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_FAILURE=0x01; export CODE_FAILURE

declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E01=0x01; export CODE_E01
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E02=0x02; export CODE_E02
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E03=0x03; export CODE_E03
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E04=0x04; export CODE_E04
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E05=0x05; export CODE_E05
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E06=0x06; export CODE_E06
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E07=0x07; export CODE_E07
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E08=0x08; export CODE_E08
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E09=0x09; export CODE_E09
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E10=0x0a; export CODE_E10
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E11=0x0b; export CODE_E11
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E12=0x0c; export CODE_E12
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E13=0x0d; export CODE_E13
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E14=0x0e; export CODE_E14
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_E15=0x0f; export CODE_E15
#. }=-
#. 0x20..0x2f Module Import Codes -={
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_IMPORT_GOOOD=0x00; export CODE_IMPORT_GOOOD      #. good module; export CODE_IMPORT_GOOOD
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_IMPORT_ERROR=0x20; export CODE_IMPORT_ERROR      #. invalid/bad module (can't source/parse); export CODE_IMPORT_ERROR
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_IMPORT_ADMIN=0x21; export CODE_IMPORT_ADMIN      #. administratively disabled; export CODE_IMPORT_ADMIN
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_IMPORT_UNDEF=0x22; export CODE_IMPORT_UNDEF      #. no such module; export CODE_IMPORT_UNDEF
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_IMPORT_UNSET=0x23; export CODE_IMPORT_UNSET      #. no module set; export CODE_IMPORT_UNSET
#. }=-
#. 0x30..0x3f Usage Codes -={
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_NOTIMPL=0x30; export CODE_NOTIMPL
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_DISABLED=0x31; export CODE_DISABLED
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_USAGE_SHORT=0x32; export CODE_USAGE_SHORT
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_USAGE_MODS=0x33; export CODE_USAGE_MODS
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_USAGE_MOD=0x34; export CODE_USAGE_MOD
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_USAGE_FN_GUESS=0x34; export CODE_USAGE_FN_GUESS
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_USAGE_FN_LONG=0x35; export CODE_USAGE_FN_LONG
#. }=-
#. 0x40..0x4f Special Non-Failure Codes -={
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_WARNING=0x40; export CODE_WARNING
#. }=-
#. 0x80..0x8f OS Reserved Codes -={
declare -ri${BASH_DECLARE_GLOBAL_OPTS} CODE_CANCELS=0x82; export CODE_CANCELS
#. }=-

declare -ri CODE_DEFAULT=CODE_USAGE_FN_LONG; export CODE_DEFAULT

declare -r SIMBOL_DELIM="$(printf "\x07")"; export SIMBOL_DELIM
declare -r SIMBOL_DELOM="$(printf "\x06 ")"; export SIMBOL_DELOM

#. }=-

#. Paths -={
SIMBOL_BASENAME="$(basename -- "$0")"
export SIMBOL_BASENAME

SIMBOL_CORE="$(readlink ~/.simbol/.scm)"
export SIMBOL_CORE

export SIMBOL_CORE_BIN=${SIMBOL_CORE}/bin
export SIMBOL_CORE_LIB=${SIMBOL_CORE}/lib
export SIMBOL_CORE_LIBEXEC=${SIMBOL_CORE}/libexec
export SIMBOL_CORE_LIBJS=${SIMBOL_CORE}/lib/libjs
export SIMBOL_CORE_LIBPY=${SIMBOL_CORE}/lib/libpy
export SIMBOL_CORE_LIBSH=${SIMBOL_CORE}/lib/libsh
export SIMBOL_CORE_MOD=${SIMBOL_CORE}/module

SIMBOL_SCM="$(readlink ~/.simbol/.scm)"
export SIMBOL_SCM

export SIMBOL_UNIT=${SIMBOL_CORE}/share/unit
export SIMBOL_UNIT_TESTS=${SIMBOL_CORE}/share/unit/tests

export SIMBOL_USER=${HOME}/.simbol
export SIMBOL_USER_ETC=${SIMBOL_USER}/etc
export SIMBOL_USER_LIB=${SIMBOL_USER}/lib
export SIMBOL_USER_LIBEXEC=${SIMBOL_USER}/libexec
export SIMBOL_USER_MOD=${SIMBOL_USER}/module
export SIMBOL_USER_VAR=${SIMBOL_USER}/var
export SIMBOL_USER_VAR_CACHE=${SIMBOL_USER}/var/cache
export SIMBOL_USER_VAR_LIB=${SIMBOL_USER}/var/lib
export SIMBOL_USER_VAR_LIBEXEC=${SIMBOL_USER}/var/libexec
export SIMBOL_USER_VAR_LIBPY=${SIMBOL_USER}/var/lib/libpy
export SIMBOL_USER_VAR_LIBSH=${SIMBOL_USER}/var/lib/libsh
export SIMBOL_USER_VAR_LOG=${SIMBOL_USER}/var/log
export SIMBOL_USER_VAR_RUN=${SIMBOL_USER}/var/run
export SIMBOL_USER_MOCKENV=${SIMBOL_USER_VAR_RUN}/.mockenv
export SIMBOL_USER_VAR_SCM=${SIMBOL_USER}/var/scm
export SIMBOL_USER_VAR_TMP=${SIMBOL_USER}/var/tmp

export SIMBOL_LOG="${SIMBOL_USER_VAR_LOG}/simbol.log"

export SIMBOL_DEADMAN=${SIMBOL_USER_VAR_CACHE?}/deadman

#. Site's PATH
PATH+=:${SIMBOL_CORE_LIBEXEC}
PATH+=:${SIMBOL_USER_VAR_LIBEXEC}
export PATH

export RBENV_VERSION=${RBENV_VERSION:-2.1.1}
#. Ruby -={
#. rbenv
RBENV_ROOT=${SIMBOL_USER_VAR}/rbenv
export RBENV_ROOT RBENV_VERSION
#. }=-

export PYENV_VERSION=${PYENV_VERSION:-3.4.0}
#. Python -={
PYTHONPATH+=:${SIMBOL_CORE_LIBPY}
PYTHONPATH+=:${SIMBOL_USER_VAR_LIBPY}
export PYTHONPATH

#. pyenv
PYENV_ROOT=${SIMBOL_USER_VAR}/pyenv
export PYENV_ROOT PYENV_VERSION
#. }=-

export PLENV_VERSION=${PLENV_VERSION:-5.18.2}
#. Perl -={
#. plenv
PLENV_ROOT=${SIMBOL_USER_VAR}/plenv
export PLENV_ROOT PLENV_VERSION
#. }=-
#. }=-
#. }=-

export SOURCED_CONSTANTS=1; fi
