# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Core DNS module
[core:docstring]

#. DNS -={
core:import util

#. Glossary
#.  <hgd>      host-group-directives
#.  <hnh>      hostname hint; either a <shn>, or a <qdn>
#.  <sdh>      subdomain hint
#.  <hcs>      host-connection-string
#.  <lhi>      ldap-host index

#. DNS Glossary
#.  <fqdn>     server.services.company.com.au |fully qualified domain name
#.  <shn>      server                         |short host name
#.  <qdn>      server.services                |(partially) qualified domain name
#.  <usdn>            services                |unqualified sub-domain name
#.  <qsdn>            services.company.com.au |qualified sub-domain name
#.  <dn>                       company.com.au |domain name

#. dns:tldid() -={
function :dns:tldid() {
    core:raise_bad_fn_call $# 2
    local tldid="$1"
    local mode="$2"

    local -i e=${CODE_SUCCESS?}

    [ "${tldid}" != '_' ] || tldid="${USER_TLDID_DEFAULT?}"
    grep -qFw "${tldid}" <<< "${!USER_TLDS[@]}"
    [ $? -eq ${CODE_SUCCESS?} ] || e=1

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        local -a hits=( "$(eval "echo -n '\${!USER_SUBDOMAIN_${tldid}[@]}'")" )
        [ ${#hits[@]} -gt 0 ] || e=2
    fi

    case ${mode}:${e} in
        raise:0|return:0)
            echo "${tldid}"
        ;;
        raise:*)
            core:raise EXCEPTION_BAD_FN_CALL "Invalid tldid \`${tldid}'"
        ;;
        return:*)
            : noop
        ;;
        *:*)
            core:raise EXCEPTION_BAD_FN_CALL "Invalid mode/error \`${mode}:${e}'"
        ;;
    esac

    return $e
}
#. }=-
#. dns:tldids -={
function dns:tldids() {
    local -i e=${CODE_DEFAULT?}

    if [[ $# -eq 0 || $# -eq 1 && "$1" == '.' ]]; then
        e=${CODE_SUCCESS?}
        for tldid in ${!USER_TLDS[@]}; do
            cpf "%{@tldid:%s}: %{@host:%s}\n" ${tldid} ${USER_TLDS[${tldid}]}
        done
    else
        e=${CODE_SUCCESS?}
        for tldid in $@; do
            local dn="${USER_TLDS[${tldid}]:--}"
            if [ "${dn}" != "-" ]; then
                cpf "%{@tldid:%s}: %{@host:%s}\n" ${tldid} ${dn}
            else
                cpf "%{@tldid:%s}: %{@error:%s}\n" ${tldid} "Unidentified"
                e=${CODE_FAILURE?}
            fi
        done
    fi

    return $e
}
#. }=-
#. dns:resolve() -={
function :dns:resolve() {
    core:raise_bad_fn_call $# 1 2
    local -r qdn="$1"
    local -l qt="${2:-.}"

    local -i e=${CODE_FAILURE?}

    local resolved
    case $#:${qt} in
        1:.|2:.)
            :dns:resolve ${qdn} a || :dns:resolve ${qdn} c
            e=$?
        ;;
        2:a)
            resolved=$(
                dig +short +retry=1 +time=2 ${qdn%%.}. A 2>/dev/null |
                    grep -v ^';' |
                    head -n1
            )
            if [ ${PIPESTATUS[0]} -ne 0 -o ${#resolved} -eq 0 ]; then
                resolved="$(
                    getent hosts |
                        awk "\$2~/^${qdn}\>/{print}" |
                        grep -E "\<${qdn}\>" |
                        awk '{print$1}' |
                        head -n1
                    exit $((${PIPESTATUS[0]}|${PIPESTATUS[2]}))
                )"
                e=$?
            else
                e=${CODE_SUCCESS?}
            fi
        ;;
        2:c)
            resolved=$(
                dig +short +retry=1 +time=2 ${qdn%%.}. CNAME 2>/dev/null |
                grep -v ^';' |
                head -n1
            )
            [ ${#resolved} -eq 0 ] || e=${CODE_SUCCESS?}
        ;;
        *)
            core:raise EXCEPTION_BAD_FN_CALL "Failed to parse \`$#:${qt}'"
        ;;
    esac

    [ $e -ne ${CODE_SUCCESS?} ] || echo "${resolved}"

    return $e
}
#. }=-
#. dns:subdomains -={
function :dns:subdomains() {
    #. return the short or full subdomain for the given <tldid>

    core:raise_bad_fn_call $# 2
    local tldid
    tldid="$(:dns:tldid $1 raise)"
    local mode="$2"

    local -i e=${CODE_FAILURE?}

    local -a sdns
    local sdn

    case ${tldid}:${mode} in
        *:full)
            for sdn in $(eval "echo -n \${USER_SUBDOMAIN_${tldid}[@]}"); do
                if [ ${sdn} != '.' ]; then
                    sdns+=( ${sdn}.${USER_TLDS[${tldid}]} )
                else
                    sdns+=( ${USER_TLDS[${tldid}]} )
                fi
            done
            e=${CODE_SUCCESS?}
        ;;
        *:short)
            for sdn in $(eval "echo -n \${USER_SUBDOMAIN_${tldid}[@]}"); do
                if [ ${sdn} != '.' ]; then
                    sdns+=( ${sdn} )
                else
                    sdns+=( ${USER_TLDS[${tldid}]} )
                fi
            done
            e=${CODE_SUCCESS?}
        ;;
        *:*)
            core:raise EXCEPTION_BAD_FN_CALL "Cannot parse \`${tldid}:${mode}'"
        ;;
    esac

    echo "${sdns[@]}"

    return $e
}

function dns:subdomains:shflags() {
    cat <<-!SHFLAGS
        boolean  short     false       "short-mode"   s
	!SHFLAGS
}
function dns:subdomains:usage() { echo "-T|--tldid <tldid> [-s|--short]"; }
function dns:subdomains() {
    local -i e=${CODE_DEFAULT?}
    [ $# -eq 0 ] || return $e

    eval "$(core:bool.eval short)"
    local rt='full'
    [ ${short} -eq ${FALSE?} ] || rt='short'

    local tldid=${g_TLDID?}
    tldid="$(:dns:tldid ${g_TLDID?} return)"
    [ $? -eq ${CODE_SUCCESS?} ] || return ${CODE_FAILURE?}

    local data
    data="$(:dns:subdomains ${tldid} ${rt})"
    e=$?
    [ $e -ne ${CODE_SUCCESS?} ] || echo "${data}"

    return $e
}
#. }=-
#. dns:inspect -={
#. Given a <hnh>, try to determine the <tldid>, [fqdn, qdn, ext], resolved
function :dns:inspect.csv() {
    #. while read line; do
    #.     read qt hnh qual tldid usdn dn fqdn resolved qid <<< ${line}
    #.     ...
    #. done < <(:dns:inspect ${hnh} ${qt})
    #. e=$?

    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local -r hnh="${1}"
        local -r qt="${2}"
        local shn
        local qsdn
        local usdn
        local tldid
        local resolved
        local -a results
        local -i hit=0

        #. <hnh> = <fqdn> ?
        resolved=$(:dns:resolve ${hnh} ${qt})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            #. If the hnh does not end with a period
            if [ ${hnh} == ${hnh%.} ]; then
                for tldid in ${!USER_TLDS[@]}; do
                    local dn="${USER_TLDS[${tldid}]}"

                    #. 1. <hnh> = <shn>.<usdn>.<dn> ?
                    fqdn=${hnh}
                    local -a qsdns=( $(:dns:subdomains ${tldid} full) )
                    for qsdn in ${qsdns[@]}; do
                        shn=${fqdn%.${qsdn}}
                        if [ ${shn} != ${fqdn} ]; then
                            hit=1
                            usdn=${qsdn%.${dn}}
                            results+=(
                                "${qt},${hnh},fqdn,${tldid},${usdn},${dn},${fqdn},${resolved},1"
                            )
                        fi
                    done

                    #. 6. <hnh> = <shn>.<usdn>{.<dn>} ?
                    qdn=${hnh}
                    local -a usdns=( $(:dns:subdomains ${tldid} short) )
                    for usdn in ${usdns[@]}; do
                        shn=${qdn%.${usdn}}
                        if [ ${shn} != ${qdn} ]; then
                            hit=1
                            fqdn=${qdn}.${dn}
                            results+=(
                                "${qt},${hnh},qdn,${tldid},${usdn},${dn},${fqdn},${resolved},6"
                            )
                        fi
                    done

                    #. 7. <hnh> = <shn>{.<qsdn>} ?
                    shn=${hnh}
                    local -a qsdns=( $(:dns:subdomains ${tldid} full) )
                    for qsdn in ${qsdns[@]}; do
                        fqdn=${shn}.${qsdn}
                        local resolves
                        resolves=$(:dns:resolve ${fqdn} ${qt});
                        if [ $? -eq ${CODE_SUCCESS?} ]; then
                            hit=1
                            fqdn=${shn}.${qsdn}
                            usdn=${qsdn%.${dn}}
                            results+=(
                                "${qt},${hnh},shn,${tldid},${usdn},${dn},${fqdn},${resolves},7"
                            )
                        fi
                    done

                    #. 9. <hnh> = <shn>{.<dn>} ?
                    if [ ${hit} -eq 0 ]; then
                        fqdn=${shn}.${dn}
                        local resolves
                        resolves=$(:dns:resolve ${fqdn} ${qt});
                        if [ $? -eq ${CODE_SUCCESS?} ]; then
                            hit=1
                            fqdn=${shn}.${dn}
                            usdn=
                            results+=(
                                "${qt},${hnh},shn,${tldid},${usdn},${dn},${fqdn},${resolves},9"
                            )
                        fi
                    fi

                    #. 2. <hnh> = <shn>.<dn> ?
                    fqdn=${hnh}
                    if [ ${hit} -eq 0 ]; then
                        shn=${fqdn%.${dn}}
                        if [ ${shn} != ${fqdn} ]; then
                            hit=1
                            results+=(
                                "${qt},${hnh},fqdn,${tldid},,${dn},${fqdn},${resolved},2"
                            )
                        fi
                    fi
                done
            fi

            #. 3. <hnh> = <ext> ?
            if [ $(core:len results) -eq 0 -a ${hit} -eq 0 ]; then
                hit=1
                fqdn=${hnh}
                results+=(
                    "${qt},${hnh},ext,-,-,-,${fqdn},${resolved},3"
                )
            fi
        else
            qdn=${hnh}

            for tldid in ${!USER_TLDS[@]}; do
                local -i hit=0
                local dn="${USER_TLDS[${tldid}]}"

                #. 4. <hnh> = <shn>.<usdn>{.<dn>} = <qdn>{.<dn>} ?
                local -a usdns=( $(:dns:subdomains ${tldid} short) )
                for usdn in ${usdns[@]}; do
                    shn=${qdn%.${usdn}}
                    if [ ${shn} != ${qdn} ]; then
                        fqdn=${shn}.${usdn}.${dn}
                        resolved=$(:dns:resolve ${fqdn} ${qt})
                        if [ $? -eq ${CODE_SUCCESS?} ]; then
                            results+=(
                                "${qt},${hnh},qdn,${tldid},${usdn},${dn},${fqdn},${resolved},4"
                            )
                            hit=1
                        fi
                    fi
                done

                #. 5. <hnh> = <shn>{<usdn>.<dn>} ?
                if [ ${hit} -eq 0 ]; then
                    shn=${qdn}
                    local -a usdns=( $(:dns:subdomains ${tldid} short) )
                    for usdn in ${usdns[@]}; do
                        fqdn=${shn}.${usdn}.${dn}
                        resolved=$(:dns:resolve ${fqdn} ${qt})
                        if [ $? -eq ${CODE_SUCCESS?} ]; then
                            results+=(
                                "${qt},${hnh},shn,${tldid},${usdn},${dn},${fqdn},${resolved},5"
                            )
                            hit=1
                        fi
                    done
                fi

                #. 8. <hnh> = <shn>{.<dn>} ?
                if [ ${hit} -eq 0 ]; then
                    fqdn=${shn}.${dn}
                    local resolves
                    resolves=$(:dns:resolve ${fqdn} ${qt});
                    if [ $? -eq ${CODE_SUCCESS?} ]; then
                        hit=1
                        fqdn=${shn}.${dn}
                        usdn=
                        results+=(
                            "${qt},${hnh},shn,${tldid},${usdn},${dn},${fqdn},${resolves},8"
                        )
                    fi
                fi

            done
        fi

        if [ $(core:len results) -gt 0 ]; then
            local result
            for result in "${results[@]}"; do
                echo "${result}"
            done
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. dns:lookup -={
function :dns:loockup.csv:cached() { echo 3600; }
function :dns:lookup.csv() {
  g_CACHE_OUT "$*" || {
    #. Sample example of how to use this function
    #.
    #.   local hnh=$1
    #.   local tldid=${g_TLDID?}
    #.
    #.   local -a data
    #.   data=( $(:dns:lookup.csv ${tldid} a ${hnh}) )
    #.
    #.   local qt hnh_ qual tldid_ usdn dn fqdn resolved qid
    #.   IFS=, read qt hnh_ qual tldid_ usdn dn fqdn resolved qid
    #.   e=$?
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 3 ]; then
        local tldidstr records hnh
        read tldidstr records hnh <<< "${@}"
        local -a results

        local -i i
        for ((i=0; i<${#records}; i++)); do
            local record=${records:${i}:1}
            results=( $(:dns:inspect.csv ${hnh} ${record}) )
            if [ $? -eq ${CODE_SUCCESS?} ]; then
                local csv qt hnh qual tldid usdn dn fqdn resolved qid
                for csv in ${results[@]}; do
                    IFS=, read qt hnh qual tldid usdn dn fqdn resolved qid <<< "${csv}"
                    if [ "${record}" == "${qt}" ]; then
                        IFS=, read -a tldidary <<< "${tldidstr}"
                        for _tldid in "${tldidary[@]}"; do
                            if [ ${_tldid} == "${tldid}" -o ${_tldid} == '.' ]; then
                                echo ${csv}
                                e=${CODE_SUCCESS?}
                            fi
                        done
                    fi
                done
            fi
        done
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    core:return $e
  } > ${g_CACHE_FILE?}; g_CACHE_IN; return $?
}

function dns:lookup:usage() { echo "<hnh>"; }
function dns:lookup() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        e=${CODE_FAILURE?}

        local -r hnh=$1
        local -r tldid=${g_TLDID?}
        local -a tldids=( ${!USER_TLDS[@]} _ )
        local tldidstr=$(:util:join ',' tldids)
        local data
        data=( $(:dns:lookup.csv ${tldidstr} ca ${hnh}) )
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            local csv qt hnh_ qual tldid_ usdn dn fqdn resolved qid
            for csv in "${data[@]}"; do
                IFS=, read qt hnh_ qual tldid_ usdn dn fqdn resolved qid <<< "${csv}"

                if [[ "${tldid}" == "${tldid_}" || "${tldid}" == '_' ]]; then
                    local qdn="${fqdn%.${dn}}"
                    if [ "${qt}" == 'c' ]; then
                        cpf "%{@ip:%-48s}" "${qdn}"
                        cpf "%{@comment:#. (%s for %s)}\n"\
                            "CNAME RECORD" "${resolved}"
                        e=${CODE_SUCCESS?}
                    elif [ "${qt}" == 'a' ]; then
                        cpf "%{@host:%-48s}" "${qdn}"
                        cpf "%{@comment:#. (%s for %s)}\n"\
                            "A RECORD" "${resolved}"
                        e=${CODE_SUCCESS?}
                    fi
                fi
            done
        fi

        [ ${e} -eq ${CODE_SUCCESS?} ] || theme HAS_FAILED "Could not look up ${hnh}"
    fi

    return $e
}
#. }=-
#. dns:get -={
function :dns:get() {
    core:raise_bad_fn_call $# 3
    local -r tldid=$1
    local -r format=$2
    local -r hnh=$3

    local -i e=${CODE_FAILURE?}

    local buffer
    buffer=$(:dns:lookup.csv ${tldid} a ${hnh})
    e=$?

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        local csv qt hnh_ qual tldid_ usdn dn fqdn resolved qid
        while read csv; do
            IFS=, read qt hnh_ qual tldid_ usdn dn fqdn resolved qid <<< "${csv}"
            case ${format} in
                fqdn)     echo "${fqdn}";;
                qdn)      echo "${fqdn%.${dn}}";;
                usdn)     echo "${usdn}";;
                tldid)    echo "${tldid_}";;
                resolved) echo "${resolved}";;
                *)        core:raise EXCEPTION_BAD_FN_CALL;;
            esac
        done <<< "${buffer}"
    fi

    return $e
}
#. }=-
#. dns:iscname -={
function :dns:iscname() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local tldid="${1}"
        local fqdn="${2}"
        local resolved
        resolved=$(:dns:get ${tldid} resolved ${fqdn})
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            #. If it didn't resolve to an IP address...
            if [ "${resolved//[0-9]/}" != '...' ]; then
                e=${CODE_SUCCESS?}
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. dns:isarecord -={
function :dns:isarecord() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local tldid="${1}"
        local fqdn="${2}"
        resolved=$(:dns:get ${tldid} resolved ${fqdn})
        if [ $? -eq 0 -a "${resolved//[0-9]/}" == '...' ]; then
            e=${CODE_SUCCESS?}
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. dns:fqdn -={
function dns:fqdn:usage() { echo "-T|--tldid <tldid> <hnh>"; }
function dns:fqdn() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}
    if [ $# -eq 1 -a ${#tldid} -gt 0 ]; then
        local hnh=$1
        :dns:get ${tldid} fqdn ${hnh}
        e=$?
    fi

    return $e
}
#. }=-
#. dns:qdn -={
function dns:qdn:usage() { echo "-T|--tldid <tldid> <hnh>"; }
function dns:qdn() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}
    if [ $# -eq 1 -a ${#tldid} -gt 0 ]; then
        local hnh=$1
        :dns:get ${tldid} qdn ${hnh}
        e=$?
    fi

    return $e
}
#. }=-
#. dns:usdn -={
function dns:usdn:usage() { echo "-T|--tldid <tldid> <hnh>"; }
function dns:usdn() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}
    if [ $# -eq 1 -a ${#tldid} -gt 0 ]; then
        local hnh=$1
        :dns:get ${tldid} usdn ${hnh}
        e=$?
    fi

    return $e
}
#. }=-

#. }=-
