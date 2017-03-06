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

#. dns:resolve() -={
function :dns:resolve() {
    local -i e=${CODE_FAILURE?}

    local -r qdn="${1}"
    local -l qt="${2:-.}"

    local resolved
    case $#:${qt} in
        1:.|2:.)
            :dns:resolve ${qdn} a || :dns:resolve ${qdn} cname
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
            core:raise EXCEPTION_BAD_FN_CALL
        ;;
    esac
    [ $e -ne ${CODE_SUCCESS?} ] || echo "${resolved}"

    return $e
}
#. }=-
#. dns:subdomains -={
#. return the short or full subdomain for the given <tldid>
function :dns:subdomains() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local -a sdns
        local tldid=$1
        case ${tldid}:$2 in
            _:full)
                for tldid in ${!USER_TLDS[@]}; do
                    for sdn in $(eval "echo -n \${USER_SUBDOMAIN_${tldid}[@]}"); do
                        sdns+=( ${sdn}.${USER_TLDS[${tldid}]} )
                    done
                done
                e=${CODE_SUCCESS?}
            ;;
            *:full)
                local sdn
                for sdn in $(eval "echo -n \${USER_SUBDOMAIN_${tldid}[@]}"); do
                    sdns+=( ${sdn}.${USER_TLDS[${tldid}]} )
                done
                e=${CODE_SUCCESS?}
            ;;
            *:short)
                sdns=( $(eval "echo -n \${USER_SUBDOMAIN_${tldid}[@]}") )
                e=${CODE_SUCCESS?}
            ;;
            *)
                core:raise EXCEPTION_BAD_FN_CALL
            ;;
        esac

        echo "${sdns[@]}"
    fi

    return $e
}

function dns:subdomains:usage() { echo "-T|--tldid <tldid>"; }
function dns:subdomains() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}
    if [ $# -eq 0 ]; then
        local data
        local rt=short
        [ ${tldid} != '_' ] || rt=full
        data="$(:dns:subdomains ${tldid} ${rt})"
        e=$?
        [ $e -ne ${CODE_SUCCESS?} ] || echo "${data}"
    fi

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
            if [ ${#results[@]} -eq 0 -a ${hit} -eq 0 ]; then
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

        [ ${#results[@]} -eq 0 ] || e=${CODE_SUCCESS?}

        local result
        for result in "${results[@]}"; do
            echo "${result}"
        done
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
                            if [ ${_tldid} == "${tldid}" -o ${_tldid} == '_' ]; then
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
        local -a tldids=( ${!USER_TLDS[@]} )
        local tldidstr=$(:util:join ',' tldids)
        local iface
        local data
        data=( $(:dns:lookup.csv ${tldidstr} ca ${hnh}) )
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            local csv qt hnh_ qual tldid_ usdn dn fqdn resolved qid
            for csv in "${data[@]}"; do
                iface="lo"
                IFS=, read qt hnh_ qual tldid_ usdn dn fqdn resolved qid <<< "${csv}"
                [ ${tldid_} == '_' ] || iface="${USER_IFACE[${tldid_}]}"

                if [[ "${tldid}" == "${tldid_}" || "${tldid}" == '_' ]]; then
                    local qdn="${fqdn%.${dn}}"
                    if [ "${qt}" == 'c' ]; then
                        cpf "%{@ip:%-48s}" "${qdn}"
                        cpf "%{@comment:#. iface:%s, (%s for %s)}\n"\
                            "${iface}" "CNAME RECORD" "${resolved}"
                        e=${CODE_SUCCESS?}
                    elif [ "${qt}" == 'a' ]; then
                        cpf "%{@host:%-48s}" "${qdn}"
                        cpf "%{@comment:#. iface:%s, (%s for %s)}\n"\
                            "${iface}" "A RECORD" "${resolved}"
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
#. dns:tldids -={
function dns:tldids() {
    local -i e=${CODE_DEFAULT?}

    if [[ $# -eq 0 || $# -eq 1 && "$1" == '_' ]]; then
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
                cpf "%{@tldid:%s}: %{@err:%s}\n" ${tldid} "Unidentified"
                e=${CODE_FAILURE?}
            fi
        done
    fi

    return $e
}
#. }=-
#. dns:get -={
function :dns:get() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 3 ]; then
        local -r tldid=$1
        local -r format=$2
        local -r hnh=$3

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
    else
        core:raise EXCEPTION_BAD_FN_CALL
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
#. dns:cname -={
#function dns:cname:usage() { echo "-T|--tldid <tldid> <netgroup> <cname-subdomain>"; }
#function dns:cname() {
#    local -i e=${CODE_DEFAULT?}
#
#    core:softimport ng
#    if [ $? -eq 0 ]; then
#        local tldid=${g_TLDID?}
#        if [ $# -eq 2 -a ${#tldid} -gt 0 ]; then
#            local ng=$1
#            local cnamesd=${2}
#            local hosts_in_ng
#            hosts_in_ng="$(:ng:hosts ${tldid} ${ng} )"
#            if [ $? -eq 0 ]; then
#                local -a hosts=( $(sed -e 's/\([^\.]\+\)\..*/\1/' <<< "$hosts_in_ng") )
#                local cnamea=
#                local host record tldid query sdn answer
#                if [ ${#hosts[@]} -gt 0 ]; then
#                    for host in ${hosts[@]}; do
#                        read record tldid hnh sdn answer <<< "$(:dns:lookup.csv p a ${host})"
#                        if [ $? -eq 0 ]; then
#                            ip="${answer}"
#
#                            cname="${host}.${cnamesd}.${USER_TLD?}"
#                            cnamea=$(dig +short ${cname}|head -n1)
#                            cnameip=$(dig +short ${cnamea}|tail -n1)
#                            cnamea=${cnamea//.${USER_TLD?}./}
#
#                            cpf "%{@host:%-24s} %{@host:%-24s} %{@ip:%-16s}" ${host}.${cnamesd} ${cnamea} ${cnameip}
#                            if [[ ${cnamea} =~ ^${host}\..* ]]; then
#                                theme HAS_PASSED
#                            else
#                                e=${CODE_FAILURE?}
#                                theme HAS_FAILED
#                            fi
#                        else
#                            e=${CODE_FAILURE?}
#                            theme HAS_FAILED
#                        fi
#                    done
#                else
#                    e=${CODE_FAILURE?}
#                fi
#            else
#                e=${CODE_FAILURE?}
#                theme HAS_FAILED
#            fi
#        fi
#    else
#        e=${CODE_FAILURE?}
#        core:log ERROR "Failed to load the netgroup module \`ng'."
#    fi
#
#    return $e
#}
#. }=-
#. dns:ptr -={
#function dns:ptr:usage() { echo "<hgd:#>"; }
#function dns:ptr() {
#    core:import hgd
#
#    local -i e=${CODE_DEFAULT?}
#    if [ $# -eq 1 ]; then
#        local -a ips
#        ips=( $(:hgd:resolve ${tldid:-m} ${1}) )
#        if [ $? -eq 0 ]; then
#            local ip
#            for ip in ${ips[@]}; do
#                cpf '%{@ip:%-32s}' ${ip}
#                local -i ee=${CODE_FAILURE?}
#                arecord=$(dig +short -x ${ip}|grep -oE '[-a-z0-9\.]+')
#                if [ ${PIPESTATUS[0]} -eq 0 ]; then
#                    ipconfirm=$(dig +short ${arecord})
#                    if [ $? -eq 0 ]; then
#                        if [ "${ipconfirm}" == "${ip}" ]; then
#                            #. Remove the last DNS dot
#                            theme HAS_PASSED "${arecord%.}"
#                            ee=${CODE_SUCCESS?}
#                        else
#                            theme HAS_FAILED "A Record Mismatch"
#                        fi
#                    else
#                        theme HAS_FAILED "No A Record"
#                    fi
#                else
#                    theme HAS_WARNED "No PTR Record"
#                fi
#            done
#            #cat x|while read line; do echo -ne ${line}...; nc -z -w1 $line 22; [ $? -eq 0 ] && echo UP || echo DOWN; done
#            e=${CODE_SUCCESS?}
#        fi
#    fi
#
#    return $e
#}
#. }=-
#. }=-
