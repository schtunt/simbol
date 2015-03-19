# vim: tw=0:ts=4:sw=4:et:ft=bash
:<<[core:docstring]
Core HGD (Host-Group Directive) module
[core:docstring]

#. HGD -={
core:requires python

core:import dns
core:import net
core:import util

core:softimport ng
core:softimport mongo

declare -g g_HGD_CACHE=${SIMBOL_USER_ETC?}/hgd.conf
[ -e ${g_HGD_CACHE?} ] || touch ${g_HGD_CACHE?}

#. HGD Resolvers -={
function ::hgd:explode() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        e=${CODE_SUCCESS?}

        local tldid="${1}"
        local hgd="${2}"
        local hgdc="${hgd:0:1}"         #. First character
        local hgdn="${hgd:1:${#hgd}}"   #. All after first character
        local hgdl="${hgd:${#hgd}-1:1}" #. Last character

        case ${hgdc} in
            '+')
                if core:imported ng; then
                    local hosts
                    hosts="$(:ng:resolve ${tldid} ${hgdn})"
                    if [ $? -eq ${CODE_SUCCESS?} ]; then
                        echo "${hosts}"
                    else
                        e=${CODE_FAILURE?}
                    fi
                else
                    e=${CODE_FAILURE?}
                fi
            ;;
            '=')
                if core:imported ng; then
                    local hosts
                    hosts="$(:ng:resolve ${tldid} ${hgdn})"
                    if [ $? -eq ${CODE_SUCCESS?} ]; then
                        echo "${hosts}"
                    else
                        e=${CODE_FAILURE?}
                    fi
                else
                    e=${CODE_FAILURE?}
                fi
            ;;
            '@')
                local host
                host="$(:dns:get ${tldid} fqdn ${hgdn})"
                if [ $? -eq ${CODE_SUCCESS?} ]; then
                    echo "${host}"
                else
                    e=${CODE_FAILURE?}
                fi
            ;;
            '%')
                if core:imported mongo; then
                    local -a filters
                    IFS=% read -a filters <<< "${hgdn}"
                    local -a hosts
                    :mongo:query ${SIMBOL_PROFILE//@*} qdn ${filters[@]}
                    [ $? -eq ${CODE_SUCCESS?} ] || e=${CODE_FAILURE?}
                else
                    e=${CODE_FAILURE?}
                fi
            ;;
            '#')
                if [ "${hgdn//[^\/]/}" == "/" ]; then
                    IFS=/ read subnet netmask <<< "${hgdn}"
                    if [ -n "${subnet}" -a -n "${netmask}" ]; then
                        :net:hosts ${subnet}/${netmask}
                        e=${PIPESTATUS[0]}
                    fi
                elif [ "${hgdn//[^\/]/}" == "" ]; then
                    echo ${hgdn}
                fi
            ;;
            .|/)
                local -a hosts
                if [ ${hgdc} == '.' ]; then
                    hosts=(
                        $(awk -F'[ ]+' '$2~/'${hgdn}'\>$/{print$2}' <(getent hosts))
                    )
                elif [ ${hgdc} == ${hgdl} ]; then
                    hosts=(
                        $(awk -F'[ ]+' '$2~'${hgd}'{print$2}' <(getent hosts))
                    )
                else
                    e=${CODE_FAILURE?}
                fi

                local -a khs=( ${HOME?}/.ssh/known_hosts )
                if [ $e -ne ${CODE_FAILURE?} ]; then
                    for kh in ${#khs[@]}; do
                        if [ -r "${kh}" ]; then
                            if [ ${hgdc} == '.' ]; then
                                hosts+=(
                                    $(awk -F'[, ]' '$1~/'${hgdn}'\>$/{print$1}' ${kh})
                                )
                            elif [ ${hgdc} == ${hgdl} ]; then
                                hosts+=(
                                    $(awk -F'[, ]' '$1~'${hgd}'{print$1}' ${kh})
                                )
                            fi
                        fi
                    done

                    if [ ${#hosts[@]} -gt 0 ]; then
                        printf "%s\n" ${hosts[@]} | sort -u
                    else
                        e=${CODE_FAILURE?}
                    fi
                fi
            ;;
            *) e=${CODE_FAILURE?};;
        esac
    fi

    return $e
}

function ::hgd:resolve() {
    local -i e=${CODE_FAILURE?}

    local hgd
    local -A buffers

    if [ $# -eq 2 ]; then
        local tldid="$1"
        local eq="$2"
        local buf
        buf=$(sets "${eq}")
        if [ $? -eq 0 ]; then
            e=${CODE_SUCCESS?}
            read -a hgds <<< "${buf}"
            for hgd in ${hgds[@]}; do
                buf="$(::hgd:explode ${tldid} ${hgd})"
                if [ $? -eq 0 ]; then
                    buffers[${hgd}]="${buf}"
                else
                    core:log WARNING "Failed to resolve ${hgd}"
                    e=${CODE_FAILURE?}
                    break
                fi
            done
        fi
    fi

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        for hgd in ${!buffers[@]}; do
            printf "%s\n" ${hgd}
            printf "%s\n\n" "${buffers[${hgd}]}"
        done
    fi

    return $e
}

function :hgd:resolve() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local tldid=$1

        #. &(...|...) or |(...|...) patterns
        if [[ ${2:0:2} =~ ^[\|\&\!]\($ ]]; then
            local eq="${2}"

            local buffer
            buffer="$(::hgd:resolve ${tldid} ${eq})"
            if [ $? -eq ${CODE_SUCCESS?} -a -n "${buffer}" ]; then
                echo -e "${buffer}" | sets "$eq"
                e=$?
            else
                e=${CODE_FAILURE?}
            fi
        #. simple alphanumeric patterns
        elif [[ ${2:0:1} =~ ^[a-zA-Z0-9]$ ]]; then
            local session="$2"
            local -a buflist
            buflist=( $(awk -F '\t' '$1~/^'${session}'$/&&$2~/^('${tldid}'|\_)$/{print$0}' ${g_HGD_CACHE?}) )
            if [ $? -eq ${CODE_SUCCESS?} -a ${#buflist[@]} -gt 3 ]; then
                e=${CODE_SUCCESS?}
                echo ${buflist[@]:4}
            fi
        else
            local eq="|(${2})"
            :hgd:resolve ${tldid} ${eq}
            e=$?
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, 2 expected"
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
function hgd:resolve:usage(){ echo "[-T <tldid>] <hgd:*>"; }
function hgd:resolve() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}
    if [ $# -eq 1 ]; then
        local eq=$1
        local tld
        if tld=$(core:tld "${tldid}"); then
            local -a resolved
            resolved=$(:hgd:resolve "${tldid}" "${eq}")
            e=$?
            if [ $e -eq ${CODE_SUCCESS?} ]; then
                for token in ${resolved[@]}; do
                    cpf '%{b:%s}\n' ${token}
                done | sort #| sort -n -t. -k1,1n -k2,2n -k3,3n -k4,4n -r
            else
                theme ERR_USAGE "Bad formula or zero matches with equation \`${eq}' and TLDID ${tldid}"
            fi
        else
            e=${CODE_FAILURE?}
            theme ERR_USAGE "Invalid TLDID ${tldid}"
        fi
    fi

    return $e
}
#. }=-
#. HGD Save -={
function :hgd:save() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 3 ]; then
        local tldid="$1"
        local session="$2"
        local hgd="$3"

        local -a hosts
        hosts=( $(:hgd:resolve ${tldid} ${hgd}) )
        if [ $? -eq 0 -a ${#hosts[@]} -gt 0 ]; then
            :hgd:delete ${session}
        fi
        echo -ne "${session}\t${tldid}\t${NOW?}\t${hgd}\t${hosts[@]}\n" >> ${g_HGD_CACHE?}
        e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, 2 expected"
    fi

    return $e
}

function hgd:save:usage(){ echo "[-T <tldid>] <session> <hgd>"; }
function hgd:save() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}
    if [ $# -eq 2 ]; then
        local session="$1"
        if [ -z "${session//[-a-zA-Z0-9]/}" ]; then
            local hgd="$2"
            if :hgd:save "${tldid}" "${session}" "${hgd}"; then
                e=${CODE_SUCCESS?}
            else
                theme ERR_USAGE "There is no <hgd> cached by that session name."
                e=${CODE_FAILURE?}
            fi
        else
            theme ERR_USAGE "That's not a valid session name."
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. HGD List -={
function :hgd:list() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 0 ]; then
        if [ -s ${g_HGD_CACHE?} ]; then
            cat ${g_HGD_CACHE?}
            e=${CODE_SUCCESS?}
        else
            e=2
        fi
    elif [ $# -eq 1 ]; then
        if grep -qE "^\<${1}\>" ${g_HGD_CACHE?}; then
            sed -ne "/^\<${1}\> *.*$/p" ${g_HGD_CACHE?}
            e=${CODE_SUCCESS?}
        else
            e=3
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, 0 or 1 expected"
    fi

    return $e
}

function hgd:list() {
    local -i e=${CODE_DEFAULT?}

    local data
    data=$(:hgd:list "$@")
    e=$?
    case $#:$e in
        0:${CODE_SUCCESS?}|1:${CODE_SUCCESS?})
            while read line; do
                read -a data <<< "$line"
                cpf '%{y:%-24s} %{@tldid:%s} %{@int:%3s} %{bl:%s} %{@hgd:%s}\n'\
                    ${data[0]} ${data[1]} $((${#data[@]}-4))\
                    $(:util:date_i2s ${data[2]}) ${data[3]}
            done <<< "${data}"
        ;;
        0:2)
            theme HAS_WARNED "You have no saved sessions"
            e=${CODE_SUCCESS?}
        ;;
        1:3)
            theme HAS_FAILED "You have no saved sessions by that name"
            e=${CODE_FAILURE?}
        ;;
    esac

    return $e
}
#. }=-
#. HGD Load -={
function :hgd:load() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local tldid=$1
        local session=$2
        local hgd=$(awk -F '\t' '$1~/^'${session}'$/&&$2~/^('${tldid}'|\.)$/{print$4}' ${g_HGD_CACHE?})
        if [ ${#hgd} -gt 0 ]; then
            echo ${hgd}
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, 1 expected"
    fi

    return $e
}

function hgd:load:usage(){ echo "<session>"; }
function hgd:load() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local tldid=${g_TLDID?}
        local session=$1
        local -a hgd=( $(:hgd:load ${tldid} ${session}) )
        if [ ${#hgd} -gt 0 ]; then
            cpf "%{@hgd:%s}\n" "${hgd[@]}"
            e=${CODE_SUCCESS?}
        else
            theme ERR_USAGE "There is no <hgd> cached by that session name."
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. HGD Refresh -={
function :hgd:refresh() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local tldid="$1"
        local session="$2"
        local hgd
        hgd="$(:hgd:load ${tldid} ${session})"
        if [ $? -eq 0 ]; then
            :hgd:delete ${session}
            :hgd:save "${tldid}" "${session}" "${hgd}"
            e=$?
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, 2 expected"
    fi

    return $e
}

function hgd:refresh:usage(){ echo "<session>"; }
function hgd:refresh() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        local tldid=${g_TLDID?}
        local session="$1"
        local hgd="$2"
        if :hgd:refresh "${tldid}" "${session}"; then
            e=${CODE_SUCCESS?}
        else
            theme ERR_USAGE "There is no <hgd> cached by that session name."
            e=${CODE_FAILURE?}
        fi
    fi

    return $e
}
#. }=-
#. HGD Delete -={
function :hgd:delete() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        local session=$1
        if [ -s ${g_HGD_CACHE?} ] && grep -qE "^\<${session}\>" ${g_HGD_CACHE?}; then
            if sed -e "/^\<${session}\>/d" -i ${g_HGD_CACHE?}; then
                e=${CODE_SUCCESS?}
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, 1 expected"
    fi

    return $e
}

function hgd:delete:usage(){ echo "<session>"; }
function hgd:delete() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        :hgd:delete ${1}
        e=$?
    fi

    return $e
}
#. }=-
#. HGD Rename -={
function :hgd:rename() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local session=$1
        local new=$2
        if [ -s ${g_HGD_CACHE?} ] && grep -qE "^\<${session}\>" ${g_HGD_CACHE?}; then
            if sed -e "s/^\<${session}\>/${new}/" -i ${g_HGD_CACHE?}; then
                e=${CODE_SUCCESS?}
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, 2 expected"
    fi

    return $e
}
function hgd:rename:usage(){ echo "<session> <new-session>"; }
function hgd:rename() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 2 ]; then
        :hgd:rename ${1} ${2}
        e=$?
    fi

    return $e
}
#. }=-
#. }=-
