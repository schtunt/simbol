# vim: tw=0:ts=4:sw=4:et:ft=bash
#shellcheck disable=SC2034

#shellcheck disable=SC2086
if [ ${SOURCED_CONSTANTS:-0} -eq 0 ]; then

#. Constants -={
export SIMBOL_VERSION=1.0-rc1
export SIMBOL_DATE_FORMAT="%x-%X"

#. Magic Numbers -={
declare -ri FD_STDIN=0
export FD_STDIN

declare -ri FD_STDOUT=1
export FD_STDOUT

declare -ri FD_STDERR=2
export FD_STDERR

true
export TRUE=$?
export CODE_SUCCESS=${TRUE?}

false
export FALSE=$?
export CODE_FAILURE=${FALSE?}

#. 64..127 Internal
export CODE_NOTIMPL=64
export CODE_DISABLED=66
export CODE_USAGE_SHORT=90
export CODE_USAGE_MODS=91
export CODE_USAGE_MOD=92
export CODE_USAGE_FN_GUESS=93
#CODE_USAGE_FN_SHORT=94
export CODE_USAGE_FN_LONG=95

export CODE_IMPORT_GOOOD=${CODE_SUCCESS} #. good module
export CODE_IMPORT_ERROR=96              #. invalid/bad module (can't source/parse)
export CODE_IMPORT_ADMIN=97              #. administratively disabled
export CODE_IMPORT_UNDEF=98              #. no such module
export CODE_IMPORT_UNSET=99              #. no module set

#. 128..255 General Error Codes
export CODE_E01=128
export CODE_E02=129
export CODE_E03=130
export CODE_E04=131
export CODE_E05=132
export CODE_E06=133
export CODE_E07=134
export CODE_E08=135
export CODE_E09=136

SIMBOL_DELIM="$(printf "\x07")"
export SIMBOL_DELIM
SIMBOL_DELOM="$(printf "\x08")"
export SIMBOL_DELOM

# shellcheck disable=SC2034
export CODE_DEFAULT=${CODE_USAGE_FN_LONG?}


#. }=-

declare -A SIMBOL_BOOL=(
    [false]=${FALSE?}
    [true]=${TRUE?}
)
export SIMBOL_BOOL

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
