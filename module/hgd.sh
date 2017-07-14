# vim: tw=0:ts=4:sw=4:et:ft=bash
:<<[core:docstring]
Core HGD (Host-Group Directive) module
[core:docstring]

#. A quick note on the language used in this module.
#
# A `session' is the `id' of the entries in the `hgd' cache file, like the
# primary key if you will.
#
# A `formula' here refers to the logic statements that look something like
# `&(...,...,|(...,...))'. The elements referenced inside these formulas are
# host groups entities or `hgrp'.  These all start with a special character
# like `%', `#', `@', and so on.  These can further be expanded into individual
# hosts or IP addresses.
#
# So to summarize:
# - A session is the key by which we save entries in the `hgd' cache.
# - Each cache entry contains the `session' name, the logic `formula', and
#   the resolution of that `formula'.
# - A `formula' is composed of one or more `hgrp' elements.
# - A `hgrp' element can be expanded to one or more hosts, or ip addresses.


#. HGD -={
core:requires python

core:import net
core:import util

#core:softimport ng

[ -v g_HGD_CACHE ] || declare -g g_HGD_CACHE="${SIMBOL_USER_ETC?}/hgd.conf"
[ -e "${g_HGD_CACHE?}" ] || touch "${g_HGD_CACHE?}"

#. HGD Resolvers -={
function ::hgd:validate() {
    local -i e; let e=CODE_FAILURE
    core:raise_bad_fn_call_unless $# eq 1
    let e=CODE_SUCCESS

    local -i balance=0
    local -i opset=0

    local -i i
    local ch
    for (( i=0; i<${#1}; i++ )); do
        ch="${1:$i:1}"
        case "${ch}" in
            '(')
                if (( opset == 1 )); then
                    let balance++
                    let opset=0
                else
                    let e=1
                fi
            ;;
            ')')
                let balance--
                (( balance == 0 )) || let e=2
            ;;
            '|'|'!'|'&')
                if (( opset == 0 )); then
                    let opset=1
                else
                    let e=3
                fi
            ;;
            *)
                (( balance > 0 )) || let e=4
            ;;
        esac

        (( e == CODE_SUCCESS )) || break
    done

    if (( e == 0 )) && (( balance > 0 )); then
        let e=5
    fi

    return $e
}

function ::hgd:explode() {
    core:raise_bad_fn_call_unless $# eq 1

    # FIXME: This method is poorly named

    # This method takes a `hgrp' and expands it either into a set of hosts,
    # or a set of IP addresses - depending on the expansion definition associated
    # with the `hgrp' (based on the first character in the `hgrp'.

    local -i e; let e=CODE_SUCCESS

    local hgd="${1}"
    local hgdc="${hgd:0:1}"         #. First character
    local hgdn="${hgd:1:${#hgd}}"   #. All after first character
    local hgdl="${hgd:${#hgd}-1:1}" #. Last character

    case ${hgdc} in
        '+')
            let e=CODE_FAILURE
            if core:imported ng; then
                local hosts
                if hosts="$(:ng:resolve "${hgdn}")"; then
                    echo "${hosts}"
                    let e=CODE_SUCCESS
                fi
            fi
        ;;
        '=')
            let e=CODE_FAILURE
            if core:imported ng; then
                local hosts
                if hosts="$(:ng:resolve "${hgdn}")"; then
                    echo "${hosts}"
                    let e=CODE_SUCCESS
                fi
            fi
        ;;
        '@')
            local host="${hgdn}"
            echo "${host}"
        ;;
        '%')
            if [ ${#USER_HGD_RESOLVERS[@]} -gt 0 ]; then
                # Try reading in key-value pair from %<key>=<value>
                IFS='=' read -r -a kvp <<< "${hgdn}"
                if [ ${#kvp[@]} -eq 2 ] && [ ${#USER_HGD_RESOLVERS[${kvp}]} -gt 0 ]; then
                    local -a v
                    IFS='+' read -r -a v <<< "${kvp[1]}"
                    #shellcheck disable=SC2059
                    ${SIMBOL_SHELL:-${SHELL}} -c "$(printf "${USER_HGD_RESOLVERS[${kvp[0]}]}" "${v[@]}")"
                    let e=$?
                else
                    core:log WARNING "Failed to find \`${kvp}' in USER_HGD_RESOLVERS"
                    core:log WARNING "Valid keys are: ${!USER_HGD_RESOLVERS[*]}"
                    let e=CODE_FAILURE
                fi
            else
                let e=CODE_FAILURE
            fi
        ;;
        '#')
            if [ "${hgdn//[^\/]/}" == "/" ]; then
                IFS=/ read -r subnet netmask <<< "${hgdn}"
                if [ -n "${subnet}" ] && [ -n "${netmask}" ]; then
                    :net:hosts "${subnet}/${netmask}"
                    let e=PIPESTATUS[0]
                fi
            elif [ "${hgdn//[^\/]/}" == "" ]; then
                echo "${hgdn}"
            fi
        ;;
        .|/)
            local -a hosts
            if [ "${hgdc}" == '.' ]; then
                hosts=(
                    $(awk -F'[ ]+' "\$2~/${hgdn}\>$/{print\$2}" <(getent hosts))
                )
            elif [ "${hgdc}" == "${hgdl}" ]; then
                hosts=(
                    $(awk -F'[ ]+' "\$2~${hgd}{print\$2}" <(getent hosts))
                )
            else
                let e=CODE_FAILURE
            fi

            local -a khs=( "${SSH_KNOWN_HOSTS:-${HOME?}/.ssh/known_hosts}" )
            #shellcheck disable=SC2086
            if [ $e -ne ${CODE_FAILURE?} ]; then
                for kh in "${khs[@]}"; do
                    if [ -r "${kh}" ]; then
                        if [ "${hgdc}" == '.' ]; then
                            hosts+=(
                                $(awk -F'[, ]' "\$1~/${hgdn}\>$/{print\$1}" "${kh}")
                            )
                        elif [ "${hgdc}" == "${hgdl}" ]; then
                            #. Awk slashes left out below intentionally, the
                            #. ${hgd} is already padded with `/' characters.
                            hosts+=(
                                $(awk -F'[, ]' "\$1~${hgd}{print\$1}" "${kh}")
                            )
                        fi
                    fi
                done

                if [ ${#hosts[@]} -gt 0 ]; then
                    printf "%s\n" "${hosts[@]}" | sort -u
                else
                    let e=CODE_FAILURE
                fi
            fi
        ;;
        *) let e=CODE_FAILURE;;
    esac

    return $e
}

function ::hgd:resolve() {
    core:raise_bad_fn_call_unless $# in 1

    # FIXME: This method is poorly named

    # This method takes a `formula' and resolves it into its constituent
    # `hgrp' entries; and then expand all these entries into their constituent
    # hosts and/or IP addresses.
    local -i e; let e=CODE_FAILURE

    local hgd
    local -A buffers

    local eq="$1"
    local buf
    if buf="$(sets "${eq}")"; then
        let e=CODE_SUCCESS
        read -r -a hgds <<< "${buf}"
        for hgd in "${hgds[@]}"; do
            if buf="$(::hgd:explode "${hgd}")"; then
                buffers["${hgd}"]="${buf}"
            else
                core:log WARNING "Failed to resolve ${hgd}"
                let e=CODE_FAILURE
                break
            fi
        done
    fi

    #shellcheck disable=SC2086
    if [ $e -eq ${CODE_SUCCESS?} ]; then
        for hgd in "${!buffers[@]}"; do
            printf "%s\n" "${hgd}"
            printf "%s\n\n" "${buffers[${hgd}]}"
        done
    fi

    return $e
}

function :hgd:resolve() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e; let e=CODE_FAILURE

    #. &(...|...) or |(...|...) patterns
    if [[ ${1:0:2} =~ ^[\|\&\!]\($ ]]; then
        local eq="$1"

        local buffer
        if buffer="$(::hgd:resolve "${eq}")"; then
            if [ -n "${buffer}" ]; then
                echo -e "${buffer}" | sets "${eq}"
                let e=$?
            fi
        fi
    #. simple alphanumeric patterns
    elif [[ ${1:0:1} =~ ^[a-zA-Z0-9]$ ]]; then
        local session="$1"
        local -a buflist
        if buflist=( $(awk -F '\t' "\$1~/^${session}$/{print\$0}" "${g_HGD_CACHE?}") ); then
            if [ ${#buflist[@]} -gt 3 ]; then
                echo "${buflist[@]:3}"
                let e=CODE_SUCCESS
            fi
        fi
    else
        local eq="|(${1})"
        :hgd:resolve "${eq}"
        let e=$?
    fi

    return $e
}

function hgd:resolve:help() {
    cat <<!
    The <host-group-directive> or <hgd> is of the following form:

    +<netgroup>          //. recursive netgroup resolution
    =<netgroup>          //. non-recursive (one-level) netgroup resolution
    @<hostname>          //. a specific hostname (can be one of shn, qdn, fqdn)
    #<ip-addr>           //. single IP address
    #<subnet>/<submask>  //. an entire subnet
    .<subdomain>         //. hosts in ~/.known_hosts matching given subdomain
    /<regex>/            //. regex matching hosts in ~/.known_hosts

    These patterns can then be grouped into unions, intersections, or
    differences using the |(...), &(...), or !(...) set operators, separated
    with commas.  For example, the following are all valid <hgd>

    @host1
    @host1,@host2
    |(@host3,@host4)
    &(+netgroup1,+netgroup2,+netgroup3)

    Finally, the set operators can be nested, but depending on the what
    combination of <hgd> classes are used, it may or may not make sense.
!
}
function hgd:resolve:usage(){ echo "<hgd:*>"; }
function hgd:resolve() {
    local -i e; let e=CODE_DEFAULT

    if [ $# -eq 1 ]; then
        local eq="$1"
        local -a resolved
        if resolved=( $(:hgd:resolve "${eq}") ); then
            let e=CODE_SUCCESS
            for token in "${resolved[@]}"; do
                cpf '%{b:%s}\n' "${token}"
            done | sort #| sort -n -t. -k1,1n -k2,2n -k3,3n -k4,4n -r
        else
            theme NOTE_USAGE "No matches with equation \`${eq}'"
        fi
    fi

    return $e
}
#. }=-
#. HGD Save -={
function :hgd:save() {
    core:raise_bad_fn_call_unless $# in 2

    local -i e; let e=CODE_FAILURE

    local session="$1"
    local hgd="$2"

    :hgd:delete "${session}"

    local -a hosts=( $(:hgd:resolve "${hgd}") )
    echo -e "${session}\t${NOW?}\t${hgd}\t${hosts[*]}" >> "${g_HGD_CACHE?}"
    [ ${#hosts[@]} -eq 0 ] || let e=CODE_SUCCESS

    return $e
}

function hgd:save:usage(){ echo "<session> <hgd>"; }
function hgd:save() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 2 ] || return $e

    local session="$1"
    if [ -z "${session//[-a-zA-Z0-9]/}" ]; then
        local hgd="$2"
        if :hgd:save "${session}" "${hgd}"; then
            let e=CODE_SUCCESS
        else
            theme ERR_USAGE "There is no <hgd> cached by that session name."
            let e=CODE_FAILURE
        fi
    else
        theme ERR_USAGE "That's not a valid session name."
        let e=CODE_FAILURE
    fi

    return $e
}
#. }=-
#. HGD List -={
function :hgd:list() {
    [ -s "${g_HGD_CACHE?}" ] || return 2

    local -i e; let e=CODE_SUCCESS
    if [ $# -eq 0 ]; then
        cat "${g_HGD_CACHE?}"
    else
        local hgd
        for hgd in "$@"; do
            if grep -qE "^\<${hgd}\>" "${g_HGD_CACHE?}"; then
                sed -ne "/^\<${hgd}\> *.*$/p" "${g_HGD_CACHE?}"
            else
                e=3
            fi
        done
    fi

    return $e
}

function hgd:list:usage() { echo "[<hgd> [<hgd> [...]]]"; }
function hgd:list() {
    local -i e; let e=CODE_DEFAULT

    local data; data="$(:hgd:list "$@")"
    let e=$?

    case $#:$e in
        *:${CODE_SUCCESS?})
            while read -r line; do
                read -ra data <<< "$line"
                cpf "%{y:%-24s} %{@int:%3s} %{n:%s} %{@hgd:%s}\n"\
                    "${data[0]}" "$((${#data[@]}-3))"\
                    "$(:util:date_i2s "${data[1]}")" "${data[2]}"
            done <<< "${data}"
        ;;
        0:2)
            theme HAS_WARNED "You have no saved hgd configuration items"
            let e=CODE_SUCCESS
        ;;
        *:2)
            theme HAS_FAILED "You have no saved hgd configuration items"
            let e=CODE_SUCCESS
        ;;
        *:3)
            theme HAS_FAILED "Unknown or invalid hgd configuration items specified"
            let e=CODE_FAILURE
        ;;
    esac

    return $e
}
#. }=-
#. HGD Load -={
function :hgd:load() {
    core:raise_bad_fn_call_unless $# in 1

    # This function simply returns the `formula' of a given `session'.

    local -i e; let e=CODE_FAILURE

    local session="$1"
    local hgd; hgd="$(awk -F '\t' "\$1~/^${session}$/{print\$3}" "${g_HGD_CACHE?}")"
    if [ ${#hgd} -gt 0 ]; then
        echo "${hgd}"
        let e=CODE_SUCCESS
    fi

    return $e
}

function hgd:load:usage(){ echo "<session>"; }
function hgd:load() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 1 ] || return $e

    local session="$1"
    local -a hgd=( $(:hgd:load "${session}") )
    if [ ${#hgd} -gt 0 ]; then
        cpf "%{@hgd:%s}\n" "${hgd[@]}"
        let e=CODE_SUCCESS
    else
        theme ERR_USAGE "There is no <hgd> cached by that session name."
        let e=CODE_FAILURE
    fi

    return $e
}
#. }=-
#. HGD Refresh -={
function :hgd:refresh() {
    core:raise_bad_fn_call_unless $# in 1

    local -i e; let e=CODE_FAILURE

    local session="$1"
    local hgd
    if hgd="$(:hgd:load "${session}")"; then
        :hgd:delete "${session}"
        :hgd:save "${session}" "${hgd}"
        let e=$?
    fi

    return $e
}

function hgd:refresh:usage(){ echo "<session>"; }
function hgd:refresh() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 1 ] || return $e

    local session="$1"
    if :hgd:refresh "${session}"; then
        let e=CODE_SUCCESS
    else
        theme ERR_USAGE "There is no <hgd> cached by that session name."
        let e=CODE_FAILURE
    fi

    return $e
}
#. }=-
#. HGD Delete -={
function :hgd:delete() {
    local -i e; let e=CODE_FAILURE
    core:raise_bad_fn_call_unless $# eq 1

    local session=$1
    if [ -s "${g_HGD_CACHE?}" ] && grep -qE "^\<${session}\>" "${g_HGD_CACHE?}"; then
        if sed -e "/^\<${session}\>/d" -i "${g_HGD_CACHE?}"; then
            let e=CODE_SUCCESS
        fi
    fi

    return $e
}

function hgd:delete:usage(){ echo "<session>"; }
function hgd:delete() {
    local -i e; let e=CODE_DEFAULT
    [ $# -ge 1 ] || return $e
    let e=CODE_SUCCESS

    local session
    for session in "$@"; do
        :hgd:delete "${session}" || let e=CODE_FAILURE
    done

    return $e
}
#. }=-
#. HGD Rename -={
function :hgd:rename() {
    local -i e; let e=CODE_FAILURE
    core:raise_bad_fn_call_unless $# in 2

    local session="$1"
    local new="$2"
    if [ -s "${g_HGD_CACHE?}" ] && grep -qE "^\<${session}\>" "${g_HGD_CACHE?}"; then
        if sed -e "s/^\<${session}\>/${new}/" -i "${g_HGD_CACHE?}"; then
            let e=CODE_SUCCESS
        fi
    fi

    return $e
}
function hgd:rename:usage(){ echo "<session> <new-session>"; }
function hgd:rename() {
    local -i e; let e=CODE_DEFAULT
    [ $# -eq 2 ] || return $e

    :hgd:rename "$1" "$2"
    e=$?

    return $e
}
#. }=-
#. }=-
