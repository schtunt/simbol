# vim: tw=0:ts=4:sw=4:et:ft=bash
#shellcheck disable=SC2166

function validate_bash() {
    local -i e; let e=CODE_SUCCESS

    local vv="${SIMBOL_USER_VAR_TMP?}/.simbol-bash-${BASH_VERSION}.verified"
    [ ! -e "${vv}" ] || return $e

    #. Associative Array Validation
    local -A aa

    #. Only supporting two style for updating associative array entries:
    # 1. foo=( [key]+=value )
    # 2. foo[key]=value
    # 3. foo[key]+=value
    #shellcheck disable=SC2154
    aa[a]='A'
    [ ${#aa[@]} -eq 1 -a "${aa[a]}" == 'A' ] || {
        e=2
        core:log CRIT "ValidationFailure: error code $e"
    }

    #. Avoid this style - `aa+=( ... )' - unless you know what you're doing.
    #
    # Only use this if the life-span of the variable is local, otherwise
    # if you do this on a variable that's controlled elsewhere, and the
    # mentioned keys already exist, the outcome could be one of two
    # things depending on the version of bash - the new assignment
    # values may clobber the existing ones, or they may append to them.
    aa+=( [b]='B' [c]='C' )
    [ ${#aa[@]} -eq 3 -a "${aa[b]}" == 'B' -a "${aa[c]}" == 'C' ] || {
        e=3
        core:log CRIT "ValidationFailure: error code $e"
    }

    aa[a]+='A'
    [ "${aa[a]}" == 'AA' ] || {
        e=4
        core:log CRIT "ValidationFailure: error code $e"
    }

    aa=( [w]='W' [x]='X' [y]='Y' [z]='Z' )
    [ ${#aa[@]} -eq 4 ] || {
        e=5
        core:log CRIT "ValidationFailure: error code $e"
    }

    #. Do not use the following as different version of bash will do
    # different things, and these are just ambiguous!
    # 2a. foo+=( [key]=value )
    # 2b. foo+=( [key]+=value )
    # 2c. foo=( [key]+=value )
    #
    # The output of the following should not match anything other than
    # some of the tests in this functioa body itself:
    #   git grep -E '[a-zA-Z0-9]+\+=\( *\['

    local buf="${SIMBOL_USER_VAR_TMP?}/.simbol-null-term-rw-test"
    local -a wstrs=( 11 'aa' 33 'stuff' ) #. TODO: \n, \r, etc.

    touch "${buf}"
    printf '%s\0' "${wstrs[@]}" >> "${buf}"

    local -a rstrs
    while read -rd $'\0' y; do
        rstrs+=( "$y" )
    done < "${buf}"
    rm -f "${buf}"

    if [ "${rstrs[*]}" != "${wstrs[*]}" -o "${#rstrs[@]}" -ne "${#wstrs[@]}" ]; then
        e=6
        core:log CRIT "ValidationFailure: error code $e"
    fi

    #. Cache the Response
    #shellcheck disable=SC2086
    [ $e -ne ${CODE_SUCCESS?} ] || touch "${vv}"

    return $e
}
