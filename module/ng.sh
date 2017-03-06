# vim: tw=0:ts=4:sw=4:et:ft=bash
:<<[core:docstring]
Core netgroup module
[core:docstring]

#. Netgroups -={
core:import dns
core:import ldap

#. ng:tree -={
function ::ng:tree_data() {
  g_CACHE_OUT "$*" || {
    : ${#g_PROCESSED_NETGROUP[@]?}
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 -o $# -eq 5 ]; then
        local tldid=${1:--} #. Recursive search
        local -i rflag=${2:-0} #. Recursive search
        local -i hflag=${3:-0} #. Hosts (too)
        local -i vflag=${4:-0} #. Verification of netgroups (and hosts)
        shift $(($#-1))

        local parent=$1
        local child
        local -a children

    #. if(!DEBUG) -={
        [ -z "${g_PROCESSED_NETGROUP[${parent}]}" ] || return
        g_PROCESSED_NETGROUP[${parent}]=1
    #. } else {
        #if [ -z "${g_PROCESSED_NETGROUP[${parent}]}" ]; then
        #    g_PROCESSED_NETGROUP[${parent}]=1
        #else
        #    g_PROCESSED_NETGROUP[${parent}]=$((${g_PROCESSED_NETGROUP[${parent}]}+1))
        #fi
        #printf "#. %-32s %s\n" "${parent}" "${g_PROCESSED_NETGROUP[${parent}]}" >&2
    #. }=-

        #. Netgroup->Netgroup via memberNisNetgroup
        IFS="${SIMBOL_DELOM?}" read -a children <<< "$(:ldap:search -2 netgroup cn=${parent} memberNisNetgroup)"
        for child in ${children[@]}; do
            if [ ${vflag} -eq 0 ]; then
                echo ${parent}:?+${child}:-
            else
                local hit="$(:ldap:search -2 netgroup cn=${child} cn)"
                if [ ${#hit} -gt 0 ]; then
                    IFS="${SIMBOL_DELOM?}" read -a mnN <<< "$(:ldap:search -2 netgroup cn=${child} memberNisNetgroup)"
                    IFS="${SIMBOL_DELOM?}" read -a nnT <<< "$(:ldap:search -2 netgroup cn=${child} nisNetgroupTriple)"
                    if [ ${#mnN[@]} -gt 0 -o ${#nnT[@]} -gt 0 ]; then
                        echo ${parent}:1+${child}:- #. Child exists and has children
                    else
                        echo ${parent}:0+${child}:- #. Child exists but has no children
                    fi
                else
                    echo ${parent}:-+${child}:- #. Child does not exist
                fi
            fi

            if [ ${rflag} -eq 1 ]; then
                ${FUNCNAME?} ${tldid} ${rflag} ${hflag} ${vflag} ${child}
            fi
        done

        #. Netgroup->Host
        if [ ${hflag} -eq 1 ]; then
            IFS="${SIMBOL_DELOM?}" read -a children <<< "$(:ldap:search -2 netgroup cn=${parent} nisNetgroupTriple)"
            local -a tldids
            if [ ${tldid} == '-' ]; then
                tldids=( ${!USER_TLDS[@]} )
            else
                tldids=( ${tldid} )
            fi

            for tldid in ${tldids[@]}; do
                local tld=${USER_TLDS[${tldid}]}
                for child in ${children[@]}; do
                    if echo ${child} | grep -qE "\<${tld}\>"; then
                        child=$(echo ${child}|tr -d '(),')
                        if [ ${vflag} -eq 0 ]; then
                            echo ${parent}:?@${child/.${tld}/:${tldid}}
                        else
                            looked=$(:dns:get ${tldid} fqdn ${child})
                            if [ $? -eq 0 ]; then
                                echo ${parent}:1@${child/.${tld}/:${tldid}}
                            else
                                echo ${parent}:-@${child/.${tld}/:${tldid}}
                            fi
                        fi
                    fi
                done
            done
        fi

        e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi
  } > ${g_CACHE_FILE?}; g_CACHE_IN; return $?
}

function ::ng:treecpf() {
    local -i indent=$1
    ((indent--))

    local cpfid=$2
    local child=$3
    local parent=$4

    local -A colors=(
        [netgroup]=darkolivegreen4
        [netgroup_empty]=darkolivegreen
        [netgroup_missing]=brown2
        [host]=deepskyblue4
        [host_bad]=firebrick3
    )

    local prefix=$(printf " %$((${indent}*4))s%%{wh:|___ }" ' ')

    if [ ${g_FORMAT?} != 'dot' ]; then
        cpf "${prefix}%{@${cpfid}:%s}\n" "${child}"
    else
        parent_id=${parent//[.-]/_}
        child_id=${child//[.-]/_}

        if [ "${cpfid//netgroup/}" != "${cpfid}" ]; then
            cpf "%s [label=\"%s\",fillcolor=%s,shape=doubleoctagon]\n" "${parent_id}" "${parent}" "${colors[${cpfid}]}"
            cpf "%s [label=\"%s\",fillcolor=%s,shape=doubleoctagon]\n" "${child_id}" "${child}" "${colors[${cpfid}]}"
            cpf "${parent_id}->${child_id}\n"
        elif [ "${cpfid//host/}" != "${cpfid}" ]; then
            cpf "%s [label=\"%s\",fillcolor=%s,shape=ellipse]\n" "${child_id}" "${child}" "${colors[${cpfid}]}"
            cpf "${parent_id}->${child_id}\n"
        else
            echo "#error"
        fi
    fi
}

function ::ng:tree_draw() {
    : ${#g_TREE[@]?}
    : ${#g_PROCESSED_NETGROUP[@]?}
    #. simbol ng tree -VHR edia -fdot |
    #.     sfdp -Gsize=67! -Goverlap=prism -Tpng >
    #.     ngtree.png && feh ngtree.png

    local -i indent=$1
    if [ ${indent} -eq 0 ]; then
        if [ ${g_FORMAT?} != 'dot' ]; then
            cpf "%{@netgroup:%s}\n" "${g_ROOT:2}"
        else
            cpf "digraph N {\n"
            cpf "splines=true;\n"
            cpf "splice=true;\n"
            cpf "overlap = false;\n"
            cpf "K=1.4;\n"
            cpf "graph [truecolor bgcolor=gray10,overlap=scalexy];\n"
            cpf "edge [splines=polyline,color=white,arrowhead=open,arrowsize=0.25,len=1,concentrate=true];\n"
            cpf "node [style=filled,fontsize=8,color=white,nodesep=9.0];\n"
        fi
    fi
    ((indent++))

    local child
    local parent=$2

    #. if(!DEBUG) -={
        [ -z "${g_PROCESSED_NETGROUP[${parent}]}" ] || return
        g_PROCESSED_NETGROUP[${parent}]=1
    #. } else {
        #if [ -z "${g_PROCESSED_NETGROUP[${parent}]}" ]; then
        #    g_PROCESSED_NETGROUP[${parent}]=1
        #else
        #    g_PROCESSED_NETGROUP[${parent}]=$((${g_PROCESSED_NETGROUP[${parent}]}+1))
        #fi
        #printf "#. %-32s %s\n" "${parent}" "${g_PROCESSED_NETGROUP[${parent}]}" >&2
    #. }=-

    IFS=, read -a children <<< "${g_TREE[${parent}]}"
    for child in ${children[@]}; do
        # verified netgroup
        if [ ${child:1:1} == '+' ]; then
            if [ ${child:0:1} == '1' ]; then
                ::ng:treecpf ${indent} netgroup ${child:2} ${parent}
            elif [ ${child:0:1} == '?' ]; then
                ::ng:treecpf ${indent} netgroup ${child:2} ${parent}
            elif [ ${child:0:1} == '0' ]; then
                ::ng:treecpf ${indent} netgroup_empty ${child:2} ${parent}
            elif [ ${child:0:1} == '-' ]; then
                ::ng:treecpf ${indent} netgroup_missing ${child:2} ${parent}
            else
                core:log ERR "${child} is an invalid entry; ${child:0:1} is unknown"
            fi
            ${FUNCNAME?} $indent ${child:2}
        # verified host
        elif [ ${child:1:1} == '@' ]; then
            if [ ${child:0:1} == '1' ]; then
                ::ng:treecpf ${indent} host ${child:2} ${parent}
            elif [ ${child:0:1} == '-' ]; then
                ::ng:treecpf ${indent} host_bad ${child:2} ${parent}
            elif [ ${child:0:1} == '?' ]; then
                ::ng:treecpf ${indent} host ${child:2} ${parent}
            else
                core:log ERR "${child} is an invalid entry; ${child:0:1} is unknown"
            fi
        else
            core:log ERR "${child} is an invalid entry; ${child:1:1} is unknown"
        fi
    done

    if [ ${indent} -eq 1 ]; then
        if [ ${g_FORMAT?} == 'dot' ]; then
            cpf "}\n"
        fi
    fi
}

function ::ng:tree_build() {
    : ${g_ROOT:=$1}

    local grandparent=$1
    local gp=${grandparent:2}
    shift

    local token parent child tldid
    for token in $@; do
        IFS=: read parent child tldid <<< "${token}"
        if [ "${parent}" == "${gp}" ]; then
            if [ -n "${g_TREE[${gp}]}" ]; then
                if ! echo "${g_TREE[${gp}]}" | grep -qE "\<${child}\>"; then
                    if [ "${tldid}" != "-" ]; then
                        g_TREE[${gp}]+=,${child}.${tldid}
                    else
                        g_TREE[${gp}]+=,${child}
                    fi
                fi
            else
                if [ "${tldid}" != "-" ]; then
                    g_TREE[${gp}]=${child}.${tldid}
                else
                    g_TREE[${gp}]=${child}
                fi
            fi
        fi
    done

    if [ -n "${g_TREE[${gp}]}" ]; then
        local -a children
        IFS=, read -a children <<< "${g_TREE[${gp}]}"
        for child in ${children[@]}; do
            if [ "${child:1:1}" == '+' ]; then
                ${FUNCNAME?} ${child} $@
            fi
        done
    fi
}

function ng:tree:shflags() {
    cat <<!
boolean recursive false "traverse-the-netgroup-tree-recursively" r
boolean showhosts false "show-host-leaf-nodes-in-netgroup-tree"  h
boolean verifyall false "verify-all-entries"                     v
!
}
function ng:tree:usage() { echo "-T|--tldid <tldid> <netgroup>"; }
function ng:tree:formats() { echo "dot png"; }
function ng:tree() {
    local -i e=${CODE_DEFAULT?}

    if [ "${g_FORMAT?}" == "dot" -o "${g_FORMAT?}" == "png" ]; then
        core:requires sfdp
        core:requires dot
        core:requires feh
    fi

    local tldid=${g_TLDID?}
    if [ $# -eq 1 -a ${#tldid} -gt 0 ]; then
        local -i recursive=${FLAGS_recursive:-0}; ((recursive=~recursive+2)); unset FLAGS_recursive
        local -i showhosts=${FLAGS_showhosts:-0}; ((showhosts=~showhosts+2)); unset FLAGS_showhosts
        local -i verifyall=${FLAGS_verifyall:-0}; ((verifyall=~verifyall+2)); unset FLAGS_verifyall

        declare -g -A g_TREE
        declare -g -A g_PROCESSED_NETGROUP
        ::ng:tree_build 1+$1 $(::ng:tree_data ${tldid} ${recursive} ${showhosts} ${verifyall} $1)
        if [ $? -ne ${CODE_SUCCESS?} ]; then
            e=${CODE_FAILURE?}
            theme ERR "No such netgroups \`$1'"
        else
            if :ng:ping ${g_ROOT:2}; then
                if [ "${g_FORMAT?}" == "png" ]; then
                    cpf "Generating image..."
                    g_FORMAT=dot ::ng:tree_draw 0 ${g_ROOT:2} |
                        sfdp -Gsize=67! -Goverlap=prism -Tpng > ${SIMBOL_USER_CACHE?}/${g_ROOT:2}.png
                    if [ $? -eq 0 ]; then
                        theme HAS_PASSED
                        feh -q -. ${SIMBOL_USER_CACHE?}/${g_ROOT:2}.png
                    else
                        theme HAS_FAILED
                    fi
                else
                    ::ng:tree_draw 0 ${g_ROOT:2}
                fi
                e=${CODE_SUCCESS?}
            else
                e=${CODE_FAILURE?}
                theme ERR "No such netgroups \`${g_ROOT:2}'"
            fi
        fi
        unset g_TREE g_ROOT
    fi

    return $e
}
#. }=-
#. ng:ping -={
function :ng:ping() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 1 ]; then
        hit=$(:ldap:search -2 netgroup cn="$1" cn|wc -l)
        [ ${hit} -eq 0 ] || e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. ng:resolve -={
function :ng:resolve() {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local tldid="$1"
        local ng="$2"

        if :ng:ping ${ng}; then
            local tld
            if tld=$(core:tld ${tldid}); then
                IFS="${SIMBOL_DELOM?}" read -a children <<< "$(:ldap:search -2 netgroup cn=${ng} memberNisNetgroup)"
                for child in ${children[@]}; do
                    ${FUNCNAME?} ${tldid} ${child}
                done

                IFS="${SIMBOL_DELOM?}" read -a children <<< "$(:ldap:search -2 netgroup cn=${ng} nisNetgroupTriple|tr -d '(),')"
                for child in ${children[@]}; do
                    if [ ${tldid} != '_' ]; then
                        if echo "${child}"|grep -qE "\.${tld}$"; then
                            echo "${child/.${tld}/}"
                        else
                            echo "${child}"
                        fi
                    else
                        echo "${child}"
                    fi
                done | sort -u
                e=${CODE_SUCCESS?}
            else
                core:log WARNING "Invalid TLDID ${tldid}"
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. ng:hosts -={
function :ng:hosts() {
  g_CACHE_OUT "$*" || {
    local -i e=${CODE_FAILURE?}

    if [ $# -eq 2 ]; then
        local -a data
        local tldid=$1
        local ng=$2

        local tld=${USER_TLDS[${tldid}]}
        if [ ${tldid} == '_' -o ${#tld} -gt 0 ]; then
            if :ng:ping ${ng}; then
                data=( $(:ng:resolve ${tldid} ${ng}|sort -u) )
                printf '%s\n' "${data[@]}"
                e=${CODE_SUCCESS?}
            fi
        else
            core:raise EXCEPTION_BAD_FN_CALL "Invalid TLDID"
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

  } > ${g_CACHE_FILE?}; g_CACHE_IN; return $?
}

function ng:hosts:usage() { echo "<netgroup>"; }
function ng:hosts() {
    local -i e=${CODE_DEFAULT?}

    local tldid=${g_TLDID?}
    if [ $# -eq 1 -a ${#tldid} -gt 0 ]; then
        local ng=$1
        cpf "Looking up %{@tldid:%s} entries for netgroup %{@netgroup:%s}..." ${tldid} ${ng}

        local -a data
        data=( $(:ng:hosts ${tldid} ${ng}) )
        if [ $? -eq ${CODE_SUCCESS?} ]; then
            e=${CODE_SUCCESS?}
            if [ ${#data[@]} -eq 0 ]; then
                theme HAS_WARNED "Empty netgroup"
            else
                theme HAS_PASSED
                local shn
                for shn in ${data[@]}; do
                    cpf "    %{@host:%s}\n" ${shn}
                done
            fi
        else
            e=${CODE_FAILURE?}
            theme HAS_FAILED "No such netgroup"
        fi
    fi

    return $e
}
#. }=-
#. ng:host -={
function :ng:host() {
    #. This function, contrary to the general rule, is not used by it's public version,
    #. it's simply a copy of it which simply generates non-fancy script-useable output.
    #.
    #. Of course all user-friendly crap such as suggestions and such have been removed.
    #.
    #. That includes the ${hni} variable used for indentation.
    local -i e=${CODE_FAILURE?}
    local tldid=${g_TLDID?}

    if [ $# -eq 1 -o $# -eq 2 ]; then
        local -i hni=${2:-0}
        ((hni++))

        local ng
        local -a raw

        e=${CODE_SUCCESS?}

        local fqdn
        local -a hosts

        local shn=$1

        if [ ${hni} -eq 1 ]; then
            if [ $? -eq ${CODE_SUCCESS?} ]; then
                fqdn="$(:dns:get ${tldid} fqdn ${shn})"
                if [ $? -eq 0 ]; then
                    hosts+=( "${fqdn}" )
                else
                    e=${CODE_FAILURE?}
                fi
            else
                [ "${shn##*.}" != "${shn}" ] || hosts+=( ${shn} )
                for tldid in ${!USER_TLDS[@]}; do
                    fqdn="$(:dns:get ${tldid} fqdn ${shn})"
                    hosts+=( ${fqdn} )
                done
            fi

            if [ $e -eq ${CODE_SUCCESS?} ]; then
                local -a raw
                for fqdn in ${hosts[@]}; do
                    local -a preraw=( $(:ldap:search -2 netgroup nisNetgroupTriple="\(${fqdn},,\)" cn ))

                    if [ ${#preraw[@]} -gt 0 ]; then
                        raw=( ${preraw[@]} )
                    fi
                done
            fi
        else
            local ng=$1
            raw=( $(:ldap:search -2 netgroup memberNisNetgroup="${ng}" cn) )
            e=${CODE_SUCCESS?}
        fi

        if [ $e -eq ${CODE_SUCCESS?} ]; then
            for ng in ${raw[@]}; do
                cpf "%s\n" "${ng}"
                ${FUNCNAME?} "$ng" ${hni}
            done
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL 443
    fi

    return $e
}

function ng:host:usage() { echo "<hnh>"; }
function ng:host() {
    local -i e=${CODE_DEFAULT?}
    local tldid=${g_TLDID?}

    if [ $# -eq 1 -o $# -eq 2 ]; then
        local -i hni=${2:-0}
        ((hni++))

        local prefix ng
        local -a raw
        local shn=$1
        local fqdn=${shn}
        if [ ${hni} -eq 1 ]; then
            e=${CODE_SUCCESS?}

            local -a hosts

            if [ $? -eq ${CODE_SUCCESS?} ]; then
                fqdn="$(:dns:get ${tldid} fqdn ${shn})"
                if [ $? -eq 0 ]; then
                    hosts+=( "${fqdn}" )
                else
                    e=${CODE_FAILURE?}
                fi
            else
                [ "${shn##*.}" != "${shn}" ] || hosts+=( ${shn} )
                for tldid in ${!USER_TLDS[@]}; do
                    fqdn="$(:dns:get ${tldid} fqdn ${shn})"
                    hosts+=( ${fqdn} )
                done
            fi

            if [ $e -eq ${CODE_SUCCESS?} ]; then
                for fqdn in ${hosts[@]}; do
                    [ ! -t 1 ] || cpf "Trying %{@fqdn:%s}..." ${fqdn}

                    local -a preraw=( $(:ldap:search -2 netgroup nisNetgroupTriple="\(${fqdn},,\)" cn) )

                    if [ ${#preraw[@]} -eq 0 ]; then
                        theme HAS_WARNED "There are no netgroups with \`${fqdn}' as a member"
                    else
                        theme HAS_PASSED
                        raw+=( ${preraw[@]} )
                        break
                    fi
                done
            else
                theme HAS_FAILED "No such host ${1}"
            fi
        else
            local ng=$1
            raw=( $(:ldap:search -2 netgroup memberNisNetgroup="${ng}" cn) )
            e=${CODE_SUCCESS?}
        fi

        if [ $e -eq ${CODE_SUCCESS?} ]; then
            for ng in ${raw[@]}; do
                local col='indirect'
                [ ${hni} -ne 1 ] || col='direct'
                prefix="$(printf %$((${hni}*2))s ' ')"
                cpf "${prefix} %{@netgroup_${col}:%s}\n" "${ng}"
                ${FUNCNAME?} "$ng" ${hni}
            done
        else
            if [ ${g_VERBOSE?} -eq 1 ]; then
                local -a didumean=( $(:ldap:search -2 netgroup nisNetgroupTriple~="\(${fqdn},,\)" nisNetgroupTriple) )
                if [ ${#didumean[@]} -gt 0 ]; then
                    printf "? %s\n" ${didumean[@]}
                fi
            fi
        fi

    fi

    return $e
}
#. }=-
#. ng:search -={
function ng:search:usage() { echo "<search-token>"; }
function ng:search() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 1 ]; then
        :ldap:search -2 netgroup cn description "|(cn=*$1*)(description=*$1*)" |
            column -t -s'+++'
        e=$?
    fi

    return $e
}
#. }=-
#. ng:summary -={
function ng:summary() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 ]; then
        local -i i=0
        while read line; do
            ((i++))
            IFS="${SIMBOL_DELIM?}" read ng desc <<< "${line}"
            cpf "%{@int:%04s}. %{@netgroup:%-32s} %{@comment:%s}\n" "${i}" "${ng}" "${desc}"
        done < <( :ldap:search -2 netgroup cn description|sort )
        e=$?
    fi

    return $e
}
#. }=-
#. ng:create -={
function ng:create:usage() { echo "<name> <hgd:fqdn>"; }
function ng:create() {
:<<:
    simbol ng create nyNetgroupName /^server1.*/
:

    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 2 ]; then
        core:import hgd

        local tldid=${g_TLDID?}
        local ng="${1}"

        local host
        local -a nnt
        for host in $(:hgd:resolve "${tldid}" "${2}"); do
            nnt+=( "nisNetgroupTriple=(${host},,)" )
        done

        :ldap:add netgroup ${ng} "${nnt[@]}"
        e=$?
    fi

    return $e
}
#. }=-
#. }=-
