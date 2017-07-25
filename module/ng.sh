#shellcheck disable=SC2155
# vim: tw=0:ts=4:sw=4:et:ft=bash
:<<[core:docstring]
Core netgroup module
[core:docstring]

#. Netgroups -={
core:import dns
core:import ldap

#. ng:tree -={
function ::ng:tree_data() {
    core:raise_bad_fn_call_unless $# in 0 4
  g_CACHE_OUT "$*" || {
    #: ${#g_PROCESSED_NETGROUP[@]?}
    local -i e; let e=CODE_FAILURE
    local -i len

    local -i rflag; let rflag=${1:-0} #. Recursive search
    local -i hflag; let hflag=${2:-0} #. Hosts (too)
    local -i vflag; let vflag=${3:-0} #. Verification of netgroups (and hosts)
    shift $(($#-1))

    local parent=$1
    local child
    local -a children

#. if(!DEBUG) -={
    [ "${g_PROCESSED_NETGROUP[${parent}]:-NilOrNotSet}" == 'NilOrNotSet' ] || return
    g_PROCESSED_NETGROUP[${parent}]=1
#. } else {
    #if [ "${g_PROCESSED_NETGROUP[${parent}]:-NilOrNotSet}" == 'NilOrNotSet' ]; then
    #    g_PROCESSED_NETGROUP[${parent}]=1
    #else
    #    g_PROCESSED_NETGROUP[${parent}]=$((${g_PROCESSED_NETGROUP[${parent}]}+1))
    #fi
    #printf "#. %-32s %s\n" "${parent}" "${g_PROCESSED_NETGROUP[${parent}]}" >&2
#. }=-

    #. Netgroup->Netgroup via memberNisNetgroup
    IFS="${SIMBOL_DELOM?}" read -ra children <<< "$(:ldap:search netgroup cn="${parent}" memberNisNetgroup)"
    let len=$(core:len children)
    if (( len > 0 )); then
        for child in "${children[@]}"; do
            if [ ${vflag} -eq 0 ]; then
                echo "${parent}:?+${child}"
            else
                local hit="$(:ldap:search netgroup cn="${child}" cn)"
                if [ ${#hit} -gt 0 ]; then
                    IFS="${SIMBOL_DELOM?}" read -ra mnN <<< "$(:ldap:search netgroup cn="${child}" memberNisNetgroup)"
                    IFS="${SIMBOL_DELOM?}" read -ra nnT <<< "$(:ldap:search netgroup cn="${child}" nisNetgroupTriple)"
                    if [[ "${#mnN[@]}" -gt 0 || "${#nnT[@]}" -gt 0 ]]; then
                        echo "${parent}:1+${child}" #. Child exists and has children
                    else
                        echo "${parent}:0+${child}" #. Child exists but has no children
                    fi
                else
                    echo "${parent}:-+${child}" #. Child does not exist
                fi
            fi

            if [ ${rflag} -eq 1 ]; then
                "${FUNCNAME?}" "${rflag}" "${hflag}" "${vflag}" "${child}"
            fi
        done
    fi

    #. Netgroup->Host
    if [ ${hflag} -eq 1 ]; then
        IFS="${SIMBOL_DELOM?}" read -ra children <<< "$(:ldap:search netgroup cn="${parent}" nisNetgroupTriple)"
            for child in "${children[@]}"; do
                child=$(echo "${child}"|tr -d '(),')
                if [ ${vflag} -eq 0 ]; then
                    echo "${parent}:?@${child}}"
                else
                    echo "${parent}:1@${child}"
                fi
            done
    fi

    let e=CODE_SUCCESS
  } > "${g_CACHE_FILE?}"; g_CACHE_IN; return $?
}

function ::ng:treecpf() {
    core:raise_bad_fn_call_unless $# eq 4
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

    local prefix=$(printf " %$(( indent * 4 ))s%%{w:|___ }" ' ')

    if [ "${g_FORMAT?}" != 'dot' ]; then
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
    core:raise_bad_fn_call_unless $# eq 2
    #: ${#g_TREE[@]?}
    #: ${#g_PROCESSED_NETGROUP[@]?}
    #. simbol ng tree -VHR edia -fdot |
    #.     sfdp -Gsize=67! -Goverlap=prism -Tpng >
    #.     ngtree.png && feh ngtree.png

    local -i indent; let indent=$1
    if (( indent == 0 )); then
        if [ "${g_FORMAT?}" != 'dot' ]; then
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
        [ "${g_PROCESSED_NETGROUP[${parent}]:-NilOrNotSet}" == 'NilOrNotSet' ] || return
        g_PROCESSED_NETGROUP[${parent}]=1
    #. } else {
        #if [ "${g_PROCESSED_NETGROUP[${parent}]:-NilOrNotSet}" == 'NilOrNotSet' ]; then
        #    g_PROCESSED_NETGROUP[${parent}]=1
        #else
        #    g_PROCESSED_NETGROUP[${parent}]=$((${g_PROCESSED_NETGROUP[${parent}]}+1))
        #fi
        #printf "#. %-32s %s\n" "${parent}" "${g_PROCESSED_NETGROUP[${parent}]}" >&2
    #. }=-

    if [[ $(core:len g_TREE) -gt 0 && "${g_TREE[${parent}]:-NilOrNotSet}" != 'NilOrNotSet' ]]; then
        IFS=, read -ra children <<< "${g_TREE[${parent}]}"
        for child in "${children[@]}"; do
            # verified netgroup
            if [ "${child:1:1}" == '+' ]; then
                if [ "${child:0:1}" == '1' ]; then
                    ::ng:treecpf "${indent}" netgroup "${child:2}" "${parent}"
                elif [ "${child:0:1}" == '?' ]; then
                    ::ng:treecpf "${indent}" netgroup "${child:2}" "${parent}"
                elif [ "${child:0:1}" == '0' ]; then
                    ::ng:treecpf "${indent}" netgroup_empty "${child:2}" "${parent}"
                elif [ "${child:0:1}" == '-' ]; then
                    ::ng:treecpf "${indent}" netgroup_missing "${child:2}" "${parent}"
                else
                    core:log ERR "${child} is an invalid entry; ${child:0:1} is unknown"
                fi
                ${FUNCNAME?} ${indent} "${child:2}"
            # verified host
            elif [ "${child:1:1}" == '@' ]; then
                if [ "${child:0:1}" == '1' ]; then
                    ::ng:treecpf "${indent}" host "${child:2}" "${parent}"
                elif [ "${child:0:1}" == '-' ]; then
                    ::ng:treecpf "${indent}" host_bad "${child:2}" "${parent}"
                elif [ "${child:0:1}" == '?' ]; then
                    ::ng:treecpf "${indent}" host "${child:2}" "${parent}"
                else
                    core:log ERR "${child} is an invalid entry; ${child:0:1} is unknown"
                fi
            else
                core:log ERR "${child} is an invalid entry; ${child:1:1} is unknown"
            fi
        done
    fi

    if [ "${indent}" -eq 1 ]; then
        if [ "${g_FORMAT?}" == 'dot' ]; then
            cpf "}\n"
        fi
    fi
}

function ::ng:tree_build() {
    core:raise_bad_fn_call_unless $# ge 1
    local -i e; let e=CODE_DEFAULT
    : "${g_ROOT:=$1}"

    local grandparent=$1
    local gp=${grandparent:2}
    shift

    local token parent child
    for token in "$@"; do
        IFS=: read -r parent child <<< "${token}"
        if [ "${parent}" == "${gp}" ]; then
            if [[ $(core:len g_TREE) -gt 0 && -n "${g_TREE[${gp}]}" ]]; then
                if ! echo "${g_TREE[${gp}]}" | grep -qE "\<${child}\>"; then
                    g_TREE[${gp}]+=,${child}
                fi
            else
                g_TREE[${gp}]=${child}
            fi
        fi
    done

    if [ $(core:len g_TREE) -gt 0 ]; then 
        if [ "${g_TREE[${gp}]:-NilOrNotSet}" != "NilOrNotSet" ]; then
            local -a children
            IFS=, read -ra children <<< "${g_TREE[${gp}]}"
            for child in "${children[@]}"; do
                if [ "${child:1:1}" == '+' ]; then
                    ${FUNCNAME?} "${child}" "$@"
                fi
            done
        fi
    fi
    return $e
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
    local -i e; let e=CODE_DEFAULT

    if [ $# -eq 1 ]; then
        if [[ "${g_FORMAT?}" == "dot" || "${g_FORMAT?}" == "png" ]]; then
            core:requires sfdp
            core:requires dot
            core:requires feh
        fi

        local -i recursive; let recursive=${FLAGS_recursive:-0}; ((recursive=~recursive+2)); unset FLAGS_recursive
        local -i showhosts; let showhosts=${FLAGS_showhosts:-0}; ((showhosts=~showhosts+2)); unset FLAGS_showhosts
        local -i verifyall; let verifyall=${FLAGS_verifyall:-0}; ((verifyall=~verifyall+2)); unset FLAGS_verifyall

        declare -g -A g_TREE
        declare -g -A g_PROCESSED_NETGROUP
        if ::ng:tree_build "1+$1" "$(::ng:tree_data "${recursive}" "${showhosts}" "${verifyall}" "$1")"; then
            let e=CODE_FAILURE
            theme ERR "No such netgroups \`$1'"
        else
            if :ng:ping "${g_ROOT:2}"; then
                if [ "${g_FORMAT?}" == "png" ]; then
                    cpf "Generating image..."
                    if g_FORMAT=$(dot ::ng:tree_draw 0 "${g_ROOT:2}" |
                    sfdp -Gsize=67! -Goverlap=prism -Tpng > "${SIMBOL_USER_VAR_CACHE?}/${g_ROOT:2}.png"); then
                        theme HAS_PASSED
                        feh -q -. "${SIMBOL_USER_VAR_CACHE?}/${g_ROOT:2}.png"
                    else
                        theme HAS_FAILED
                    fi
                else
                    ::ng:tree_draw 0 "${g_ROOT:2}"
                fi
                let e=CODE_SUCCESS
            else
                let e=CODE_FAILURE
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
    core:raise_bad_fn_call_unless $# eq 1
    local -i e; let e=CODE_FAILURE

    hit=$(:ldap:search netgroup cn="$1" cn|wc -l)
    [ "${hit}" -eq 0 ] || let e=CODE_SUCCESS

    return $e
}
#. }=-
#. ng:resolve -={
function :ng:resolve() {
    core:raise_bad_fn_call_unless $# eq 1
    local -i e; let e=CODE_FAILURE
    local -a children
    local -i len

    local ng="$1"

    if :ng:ping "${ng}"; then
        IFS="${SIMBOL_DELOM?}" read -ra children <<< "$(:ldap:search netgroup cn="${ng}" memberNisNetgroup)"
        let len=$(core:len children)
        if (( len > 0 )); then
            for child in "${children[@]}"; do
                ${FUNCNAME?} "${child}"
            done
        fi

        IFS="${SIMBOL_DELOM?}" read -ra children <<< "$(:ldap:search netgroup cn="${ng}" nisNetgroupTriple|tr -d '(),')"
        let len=$(core:len children)
        if (( len > 0 )); then
            for child in "${children[@]}"; do
                echo "${child}"
            done | sort -u
        fi
        let e=CODE_SUCCESS
    fi

    return $e
}
#. }=-
#. ng:hosts -={
function :ng:hosts() {
    core:raise_bad_fn_call_unless $# eq 1
    g_CACHE_OUT "$*" || {
    local -i e; let e=CODE_FAILURE

    local -a data
    local ng=$1

    if :ng:ping "${ng}"; then
        data=( $(:ng:resolve "${ng}"|sort -u) )
        let e=CODE_SUCCESS
        printf '%s\n' "${data[@]}"
    fi

  } > "${g_CACHE_FILE?}"; g_CACHE_IN; return $?
}

function ng:hosts:usage() { echo "<netgroup>"; }
function ng:hosts() {
    local -i e; let e=CODE_DEFAULT

    if [ $# -eq 1 ]; then
        local ng=$1
        cpf "Looking up netgroup %{@netgroup:%s}..." "${ng}"

        local -a data
        if data=( $(:ng:hosts "${ng}") ); then
            let e=CODE_SUCCESS
            if [ ${#data[@]} -eq 0 ]; then
                theme HAS_WARNED "Empty netgroup"
            else
                theme HAS_PASSED
                local shn
                for shn in "${data[@]}"; do
                    cpf "    %{@host:%s}\n" "${shn}"
                done
            fi
        else
            let e=CODE_FAILURE
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
    local -i e; let e=CODE_FAILURE
    core:raise_bad_fn_call_unless $# in 1 2

    local -i hni; let hni=${2:-0}
    ((hni++))

    local ng
    local -a raw

    let e=CODE_SUCCESS


    local shn=$1
    local fqdn="${shn}"
    local -a hosts=( ${fqdn} )
    local -i len

    if [ ${hni} -eq 1 ]; then

        if (( e == CODE_SUCCESS )); then
            let len=$(core:len hosts)
            if (( len > 0 )); then
                for fqdn in "${hosts[@]}"; do
                    local -a preraw=( $(:ldap:search netgroup nisNetgroupTriple="\(${fqdn},,\)" cn ))

                    if [ ${#preraw[@]} -gt 0 ]; then
                        raw=( ${preraw[@]} )
                    fi
                done
            fi
        fi
    else
        local ng=$1
        raw=( $(:ldap:search netgroup memberNisNetgroup="${ng}" cn) )
        let e=CODE_SUCCESS
    fi

    if (( e == CODE_SUCCESS )); then
        let len=$(core:len raw)
        if (( len > 0 )); then
            for ng in "${raw[@]}"; do
                cpf "%s\n" "${ng}"
                ${FUNCNAME?} "$ng" ${hni}
            done
        fi
    fi

    return $e
}

function ng:host:usage() { echo "<hnh>"; }
function ng:host() {
    #core:raise_bad_fn_call_unless $# in 1 2
    local -i e; let e=CODE_DEFAULT
    #local tldid=${g_TLDID?}

    if [ $# -ge 1 ]; then
        local -i hni; let hni=${2:-0}
        ((hni++))

        local prefix ng
        local -a raw
        local shn=$1
        local fqdn=${shn}
        local -i len
        if [ ${hni} -eq 1 ]; then
            let e=CODE_SUCCESS

            local -a hosts=( "${fqdn}" )

            if (( e == CODE_SUCCESS )); then
                for fqdn in "${hosts[@]}"; do
                    [ ! -t 1 ] || cpf "Trying %{@fqdn:%s}..." "${fqdn}"

                    local -a preraw=( $(:ldap:search netgroup nisNetgroupTriple="\(${fqdn},,\)" cn) )

                    let len=$(core:len preraw)
                    if (( len == 0 )); then
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
            raw=( $(:ldap:search netgroup memberNisNetgroup="${ng}" cn) )
            let e=CODE_SUCCESS
        fi


        if (( e == CODE_SUCCESS )); then
            let len=$(core:len raw)
            if (( len > 0 )); then
                for ng in "${raw[@]}"; do
                    local col='indirect'
                    [ ${hni} -ne 1 ] || col='direct'
                    prefix="$(printf %$((hni*2))s ' ')"
                    cpf "${prefix} %{@netgroup_${col}:%s}\n" "${ng}"
                    ${FUNCNAME?} "$ng" ${hni}
                done
            fi
        else
            if [ "${g_VERBOSE?}" -eq "${TRUE?}" ]; then
                local -a didumean=( $(:ldap:search netgroup nisNetgroupTriple~="\(${fqdn},,\)" nisNetgroupTriple) )
                if [ ${#didumean[@]} -gt 0 ]; then
                    printf "? %s\n" "${didumean[@]}"
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
    local -i e; let e=CODE_DEFAULT

    if [ $# -eq 1 ]; then
        local -i i=0
        while read -r line; do
            ((i++))
            IFS="${SIMBOL_DELIM?}" read -r ng desc <<< "${line}"
            cpf "%{@int:%04s}. %{@netgroup:%-32s} %{@comment:%s}\n" "${i}" "${ng}" "${desc}"
        done < <( :ldap:search netgroup cn description "(|(cn=*$1*)(description=*$1*))"|sort )
        e=$?
    fi
    return $e
}
#. }=-
#. ng:summary -={
function ng:summary() {
    core:raise_bad_fn_call_unless $# eq 0
    local -i e; let e=CODE_DEFAULT

    local -i i=0
    while read -r line; do
        ((i++))
        IFS="${SIMBOL_DELIM?}" read -r ng desc <<< "${line}"
        cpf "%{@int:%04s}. %{@netgroup:%-32s} %{@comment:%s}\n" "${i}" "${ng}" "${desc}"
    done < <( :ldap:search netgroup cn description|sort )
    e=$?

    return $e
}
#. }=-
#. ng:create -={
function ng:create:usage() { echo "<name> <hgd:fqdn>"; }
function ng:create() {
:<<:
    simbol ng create nyNetgroupName /^server1.*/
:
    core:raise_bad_fn_call_unless $# eq 2
    local -i e; let e=CODE_DEFAULT

    core:import hgd

    local tldid=${g_TLDID?}
    local ng="${1}"

    local host
    local -a nnt
    for host in $(:hgd:resolve "${tldid}" "${2}"); do
        nnt+=( "nisNetgroupTriple=(${host},,)" )
    done

    :ldap:add netgroup "${ng}" "${nnt[@]}"
    e=$?

    return $e
}
#. }=-
#. }=-
