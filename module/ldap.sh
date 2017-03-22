# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
The simbol LDAP module
[core:docstring]

#. LDAP -={
#. https://access.redhat.com/simbol/documentation/en-US/Red_Hat_Directory_Server/8.2/html-single/Administration_Guide/index.html#Managing_Replication-Replicating-Password-Attributes
g_MAXDATA=20380119031407Z

core:import dns
core:import util
core:import vault

core:requires ENV USER_GDN
core:requires ENV USER_LDAPHOSTS
core:requires ENV USER_LDAPHOSTS_RW
core:requires ENV USER_LDAP_SYNC_ATTRS
core:requires ENV USER_NDN
core:requires ENV USER_REGEX
core:requires ENV USER_UDN
core:requires ENV USER_USERNAME

core:requires gawk
core:requires ldapsearch
core:requires ldapmodify

#. ldap:host -={
function :ldap:host() {
    #. <arguments> = -1:
    #.    Returns a random LDAP host from the pool
    #.
    #. {no-argument} or <arguments> = -2:
    #.    Returns a random LDAP host from the pool, unless global option for
    #.    a specific <lhi> has been set, in which case that ldap host is
    #.    returned.
    #.
    #. <arguments> = 0..
    #.    Returns a specific LDAP host if 1 argument is supplied which is
    #.    positive and less than the number of ldap hosts defined.
    #.
    #. Throws an exception otherwise.

    local -i e=${CODE_FAILURE?}

    local user_ldaphost=
    if [ $# -eq 1 ]; then
        local -i lhi=$1
        if [ ${lhi} -lt ${#USER_LDAPHOSTS[@]} ]; then
            if [ ${lhi} -ge 0 ]; then
                user_ldaphost="${USER_LDAPHOSTS[${lhi}]}"
                e=${CODE_SUCCESS?}
            elif [ ${lhi} -eq -1 ]; then
                e=${CODE_SUCCESS?}
            elif [ ${lhi} -eq -2 ]; then
                [ ${g_LDAPHOST?} -ge 0 ] || g_LDAPHOST=-1
                user_ldaphost=$(:ldap:host ${g_LDAPHOST?})
                e=$?
            fi
        else
            core:raise EXCEPTION_BAD_FN_CALL "BAD_INDEX"
        fi
    elif [ $# -eq 0 ]; then
        [ ${g_LDAPHOST?} -ge 0 ] || g_LDAPHOST=-1
        user_ldaphost=$(:ldap:host ${g_LDAPHOST?})
        e=$?
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        if [ ${#user_ldaphost} -eq 0 ]; then
            user_ldaphost="${USER_LDAPHOSTS[$((${RANDOM?}%${#USER_LDAPHOSTS[@]}))]}"
        fi
        echo ${user_ldaphost}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function :ldap:host_rw() {
    #. Returns a random LDAP host from the pool, that offer rw functionality
    #. Assumes all hosts are functional

    local -i e=${CODE_FAILURE?}

    local user_ldaphost_rw
    if [ "${g_LDAPHOST?}" -lt 0 ]; then
        user_ldaphost_rw="${USER_LDAPHOSTS_RW[$((${RANDOM?}%${#USER_LDAPHOSTS_RW[@]}))]}"
        e=${CODE_SUCCESS?}
    elif [ ${g_LDAPHOST?} -lt ${#USER_LDAPHOSTS_RW[@]} ]; then
        user_ldaphost_rw="${USER_LDAPHOSTS_RW[${g_LDAPHOST?}]}"
        e=${CODE_SUCCESS?}
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi
    echo ${user_ldaphost_rw}

    return $e
}
#. }=-
#. ldap:authentication -={
declare -g g_PASSWD_CACHED=
function :ldap:authenticate() {
    local -i e=${CODE_FAILURE?}

    if [ ${#g_PASSWD_CACHED} -eq 0 ]; then
        g_PASSWD_CACHED="$(:vault:read LDAP)"
        e=$?

        local ldaphost_rw=$(:ldap:host_rw)
        if [ $e -ne 0 ]; then
            read -p "Enter LDAP ($ldaphost_rw}) Password: " -s g_PASSWD_CACHED
            echo
        fi

        ldapsearch -x -LLL -h ${ldaphost_rw} -p ${USER_LDAPPORT:-389}\
            -D "uid=${USER_USERNAME?},${USER_UDN?}" -w "${g_PASSWD_CACHED?}"\
            -b ${USER_UDN?} >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            export g_PASSWD_CACHED
            e=${CODE_SUCCESS?}
        else
            g_PASSWD_CACHED=
        fi
    else
        e=${CODE_SUCCESS?}
    fi
    return $e
}
#. }=-
#. ldap:modify -={
#. LDAP Return Copes
#. 0   - LDAP_SUCCESS
#. 1   - LDAP_OPERATIONS_ERROR
#. 10  - LDAP_REFERRAL
#. 16  - LDAP_NO_SUCH_ATTRIBUTE
#. 19  - LDAP_CONSTRAINT_VIOLATION
#. 20  - LDAP_TYPE_OR_VALUE_EXISTS

function ldap:mkldif:usage() { echo "add|modify|replace|delete user|group|netgroup <name> <attr1> <val1> [<val2> [...]] [- <attr2> ...]"; }
function ldap:mkldif() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -ge 4 ]; then
        vimcat <<< "$(::ldap:mkldif $@)" >&2
        e=$?
    fi

    return $e
}
function ::ldap:mkldif() {
: <<!
    This function generates an ldif; which is suitable for feeding into
    ldapmodify.
!
    local -i e=${CODE_FAILURE?}

    if [ $# -gt 3 ]; then
        local action=$1
        local context=$2

        local -A changes=(
            [modify]=modify
            [add]=modify
            [replace]=modify
            [delete]=modify
        )

        local change=${changes[${action}]}
        local dn
        case $context in
            user)
                local username=$3
                dn="uid=${username},${USER_UDN?}"
                e=${CODE_SUCCESS?}
            ;;
            group)
                local groupname=$3
                dn="cn=${groupname},${USER_GDN?}"
                e=${CODE_SUCCESS?}
            ;;
            netgroup)
                local netgroupname=$3
                dn="cn=${netgroupname},${USER_NDN?}"
                e=${CODE_SUCCESS?}
            ;;
        esac

        if [ $e -eq ${CODE_SUCCESS?} ]; then
            echo "# vim:syntax=ldif"
            echo "dn: ${dn}"
            echo "changetype: ${change}"
            local attr=
            for ((i=4; i<$#+1; i++)); do
                if [ "${!i}" != "-" -a ${#attr} -gt 0 ]; then
                    printf "\n${attr}: ${!i}";
                else
                    if [ ${#attr} -gt 0 ]; then
                        printf "\n-\n"
                        ((i++))
                    fi
                    attr=${!i}
                    printf "${action}: ${attr}"
                fi
            done
            printf "\n"
        else
            core:raise EXCEPTION_BAD_FN_CALL
        fi

    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function :ldap:modify() {
    local -i e=${CODE_FAILURE?}

    if [ $# -ge 3 ]; then
        local context=$1
        case ${context} in
            user)
                if :ldap:authenticate; then
                    local username=$2
                    local change=$3
                    case ${change} in
                        delete|add|replace)
                            shift 3
                            local ldif="$(::ldap:mkldif ${change} user ${username} ${@})"
                            local ldaphost_rw=$(:ldap:host_rw)
                            ldapmodify -x -h ${ldaphost_rw}\
                                -p ${USER_LDAPPORT:-389}\
                                -D "uid=${USER_USERNAME?},${USER_UDN?}"\
                                -w "${g_PASSWD_CACHED?}"\
                                -c <<< "${ldif}"  >/dev/null 2>&1
                            e=$?
                            if [ $e -ne ${CODE_SUCCESS?} ]; then
                                cpf "%{@comment:#. } LDIF %{@err:Failed} with status code %{@int:$e}:\n" >&2
                                vimcat <<< "${ldif}" >&2
                            fi
                        ;;
                        *) core:raise EXCEPTION_BAD_FN_CALL INVALID_USER_CHANGE;;
                    esac
                fi
            ;;
            group)
                if :ldap:authenticate; then
                    local groupname=$2
                    local change=$3
                    case ${change} in
                        modify|delete|add|replace)
                            shift 3
                            local ldif="$(::ldap:mkldif ${change} group ${groupname} ${@})"
                            local ldaphost_rw=$(:ldap:host_rw)
                            ldapmodify -x -h ${ldaphost_rw}\
                                -p ${USER_LDAPPORT:-389}\
                                -D "uid=${USER_USERNAME?},${USER_UDN?}"\
                                -w "${g_PASSWD_CACHED?}"\
                                -c <<< "${ldif}"  >/dev/null 2>&1
                            e=$?
                            if [ $e -ne ${CODE_SUCCESS?} ]; then
                                cpf "%{@comment:#. } LDIF %{@err:Failed} with status code %{@int:$e}:\n" >&2
                                vimcat <<< "${ldif}" >&2
                            fi
                        ;;
                        *) core:raise EXCEPTION_BAD_FN_CALL INVALID_GROUP_CHANGE;;
                    esac
                fi
            ;;
            *) core:raise EXCEPTION_BAD_FN_CALL INVALID_CONTEXT;;
        esac
    else
        core:raise EXCEPTION_BAD_FN_CALL INVALID_FN_CALL
    fi

    return $e
}

function :ldap:add() {
:<<:
...
:
    local -i e=${CODE_FAILURE?}

    if [ $# -ge 3 ]; then
        if :ldap:authenticate; then
            local context=$1
            local id=$2
            local -a template
            case $context in
                user)
                    dn="uid=${id},${USER_UDN?}"
                    template=(
                    )
                ;;
                netgroup)
                    dn="cn=${id},${USER_NDN?}"
                    template=(
                        objectClass=top
                        objectClass=nisNetgroup
                        cn=${id}
                    )
                ;;
                *) core:raise EXCEPTION_BAD_FN_CALL;;
            esac

            local ldaphost_rw=$(:ldap:host_rw)
            local ldif="$(
                printf "dn: %s\n" "${dn}"

                local attr
                for attr in "${template[@]}" "${@:3}"; do
                    IFS== read key value <<< "${attr}"
                    printf "%s: %s\n" "${key}" "${value}"
                done
                printf "\n"
            )"

            local output=$(
                ldapmodify -a -x -h ${ldaphost_rw} -p ${USER_LDAPPORT:-389}\
                    -D "uid=${USER_USERNAME?},${USER_UDN?}"\
                    -w "${g_PASSWD_CACHED?}" <<< "${ldif}" 2>&1
            )

            e=$?
            if [ $e -eq 0 ]; then
                core:log INFO "${output}"
            else
                core:log ERR "${output}"
            fi
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#. }=-
#. ldap:checksum -={
function ldap:checksum:usage() { echo "[<ldaphostid> <ldaphostid> [<ldaphostid> [...]]]"; }
function ldap:checksum() {
    core:requires ANY colordiff diff

    local -i e=${CODE_DEFAULT?}

    local lhi
    local -a ldaphostids
    if [ $# -eq 0 ]; then
        local -i e=${CODE_SUCCESS?}
        ldaphostids=( ${!USER_LDAPHOSTS[@]} )
    elif [ $# -ge 2 ]; then
        local -i e=${CODE_SUCCESS?}
        for lhi in $@; do
            if [ ${lhi} -lt ${#USER_LDAPHOSTS[@]} ]; then
                ldaphostids+=( ${lhi} )
            else
                local -i e=${CODE_FAILURE?}
            fi
        done
    fi

    if [ $e -eq ${CODE_SUCCESS?} ]; then
        local -A dump
        local md5
        local uidc

        local -a ldaphosts
        for lhi in ${ldaphostids[@]}; do
            ldaphosts+=( ${USER_LDAPHOSTS[${lhi}]} )
        done
        cpf "Integrity check between %{@int:%s} ldap hosts (ids:%{@int:%s})...\n"\
            "${#ldaphostids[@]}" "$(:util:join , ldaphostids)"

        for ngc in {a..z}; do
            cpf "Integrity check for %{c:ng=}%{r:${ngc}*}..."
            local -A md5s=()
            for lh in ${ldaphosts[@]}; do
                dump[${lh}]=$(
                    ldapsearch -x -LLL -E pr=128/noprompt -S dn -h "${lh}"\
                        -p ${USER_LDAPPORT:-389} -b "${USER_NDN?}"\
                        cn="${ngc}*" cn memberNisNetgroup netgroupTriple description |
                            sed -e 's/^dn:.*/\L&/' |
                            grep -v 'pagedresults:' 2>/dev/null
                )
                [ $? -eq 0 ] && cpf '+' || cpf '!'
                md5="$(echo ${dump[${lh}]}|md5sum|awk '{print$1}')"
                md5s[${md5}]=${lh}
            done

            #. identical block -={
            cpf ...
            local ldaphost=${ldaphosts[0]}
            local -i len=$(echo "${dump[${ldaphost}]}"|wc -c)
            if [ ${#md5s[@]} -eq 1 ]; then
                if [ ${len} -gt 1 ]; then
                    theme HAS_PASSED ${md5}:${len}
                else
                    theme HAS_WARNED ${md5}:${len}
                fi
            else
                theme HAS_FAILED "${#md5s[@]} variants in the ${#ldaphosts[@]} hosts"
                e=${CODE_FAILURE?}
                for lh in ${ldaphosts[@]}; do
                    if [ ${lh} != ${ldaphost} ]; then
                        cpf "%{@host:${ldaphost}} vs %{@host:${lh}}...\n"
                        diff -T -a -U3\
                            <(echo "${dump[${ldaphost}]}")\
                            <(echo "${dump[${lh}]}")
                    fi
                done
            fi
            #. }=-
        done

        for uidc in {a..z}; do
            cpf "Integrity check for %{c:uid=}%{r:${uidc}*}..."
            local -A md5s=()
            for lh in ${ldaphosts[@]}; do
                dump[${lh}]=$(
                    ldapsearch -x -LLL -E pr=128/noprompt -p ${USER_LDAPPORT:-389}\
                        -S dn -h "${lh}" -b "${USER_UDN?}"\
                        uid="${uidc}*" ${USER_LDAP_SYNC_ATTRS[@]} |
                            sed -e 's/^dn:.*/\L&/' |
                            grep -v 'pagedresults:' 2>/dev/null
                )
                [ $? -eq 0 ] && cpf '+' || cpf '!'
                md5="$(echo ${dump[${lh}]}|md5sum|awk '{print$1}')"
                md5s[${md5}]=${lh}
            done

            #. identical block -={
            cpf ...
            local ldaphost=${ldaphosts[0]}
            local -i len=$(echo "${dump[${ldaphost}]}"|wc -c)
            if [ ${#md5s[@]} -eq 1 ]; then
                if [ ${len} -gt 1 ]; then
                    theme HAS_PASSED ${md5}:${len}
                else
                    theme HAS_WARNED ${md5}:${len}
                fi
            else
                theme HAS_FAILED "${#md5s[@]} variants in the ${#ldaphosts[@]} hosts"
                e=${CODE_FAILURE?}
                for lh in ${ldaphosts[@]}; do
                    if [ ${lh} != ${ldaphost} ]; then
                        cpf "%{@host:${ldaphost}} vs %{@host:${lh}}...\n"
                        diff -T -a -U3\
                            <(echo "${dump[${ldaphost}]}")\
                            <(echo "${dump[${lh}]}")
                    fi
                done
            fi
            #. }=-
        done

    fi

    return $e
}
#. }=-
#. ldap:search -={
function :ldap:search.eval() {
    #. This function searches for a single object
    local -i e=${CODE_FAILURE?}

    if [ $# -ge 2 ]; then
        local -i lhi=$1
        local context=$2
        shift 3
        case $context in
            host)
                local hostname=$3
                local ldaphost=$(:ldap:host ${lhi})
                local userdata=$(
                    ldapsearch -x -LLL -E pr=1024/noprompt -h "${ldaphost}"\
                        -p ${USER_LDAPPORT:-389}\
                        -b "${USER_HDN?}" "cn=${hostname}" ${@}|grep -vE '^#'
                )
                e=$?

                echo "${userdata}"
            ;;
            user)
                local username=$3
                local ldaphost=$(:ldap:host ${lhi})
                local userdata=$(
                    ldapsearch -x -LLL -E pr=1024/noprompt -h "${ldaphost}"\
                        -p ${USER_LDAPPORT:-389}\
                        -b "${USER_UDN?}" "uid=${username}" ${@}|grep -vE '^#'
                )
                if [ $# -gt 0 ]; then
                    #. User specified which attrs they want:
                    for attr in $@; do
                        #. evaluate the value of the user-data
                        local r=$(
                            echo "${userdata}" \
                                | grep -Po "^${attr}:\s+.*"\
                                | cut -d' ' -f2\
                                | tr -d '\n'
                        )
                        echo "local _ldap_${attr,,}='${r}';"
                    done
                else
                    #. User asked for a complete dump of the user ldif
                    local -A ldifdata
                    while read line; do
                        local attr="$(echo $line|sed -e 's/^\(.*\): *\(.*\)$/\L\1/')"
                        local val="$(echo $line|sed -e 's/^\(.*\): *\(.*\)$/\2/')"
                        if [ -z "${ldifdata[${attr}]}" ]; then
                            eval "local -a _ldap_${attr,,}=( \"${val}\" )"
                            ((ldifdata[${attr}]=1))
                        else
                            ((ldifdata[${attr}]+=1))
                            eval "_ldap_${attr,,}+=( '${val}' )"
                        fi
                    done <<< "${userdata}"

                    #. Print as eval bash arrays
                    printf "#. WARNING: If ldap values have double-quotes, they will be stripped.\n"
                    for attrs in ${!_ldap_*}; do
                        local -i attrlen=$(eval "echo \${#$attrs[@]}") #. number of attribute definitions

                        printf "local -a ${attrs}=("
                        for ((i=0; i<${attrlen}; i++)); do
                            printf ' "'
                            eval "printf \"\${$attrs[${i}]}\""|tr -d '"'
                            printf '"'
                        done
                        printf " )\n"

                    done

                    #. Print as ldif (bash comments)
                    for attrs in ${!_ldap_*}; do
                        local -i attrlen=$(eval "echo \${#$attrs[@]}") #. number of attribute definitions
                        for ((i=0; i<${attrlen}; i++)); do
                            eval 'echo "#. ${attrs//_ldap_/}: ${'$attrs'[${i}]}"'
                        done
                    done
                fi

                e=${CODE_SUCCESS?}
            ;;
        esac
    fi

    return $e
}

function :ldap:search() {
    : ${SIMBOL_DELOM?}
    #. This function seaches for multiple objects
    #.
    #. Usage:
    #.       IFS="${SIMBOL_DELOM?}" read -a fred <<< "$(:ldap:search <lhi> netgroup cn=jboss_prd nisNetgroupTriple)"

    local -i e=${CODE_FAILURE?}

    if [ $# -gt 2 ]; then
        local bdn
        local -i lhi=${1}
        local ldaphost=$(:ldap:host ${lhi})

        case $2 in
            host)     bdn=${USER_HDN?};;
            user)     bdn=${USER_UDN?};;
            group)    bdn=${USER_GDN?};;
            subnet)   bdn=${USER_SDN?};;
            netgroup) bdn=${USER_NDN?};;
        esac

        if [ ${#bdn} -gt 0 ]; then
            #. Look for filter tokens
            local -a filter
            local -a display
            local token
            for token in "${@:3}"; do
                if [[ ${token} =~ \([-a-zA-Z0-9_]+([~\<\>]?=).+\) ]]; then
                    filter+=( "${token}" )
                elif [[ ${token} =~ [-a-zA-Z0-9_]+([~\<\>]?=).+ ]]; then
                    filter+=( "(${token})" )
                else
                    #. Unfortunately, for now it is mandatory that all attributes
                    #. requested must exist, otherwise the caller doesn't know
                    #. which ones are missing.
                    filter+=( "(${token}=*)" )
                    display+=( ${token} )
                fi
            done

            #. 2 for dn_key and dn_value, and 2 for each additional attr key/value pair requested
            local -i awknf=$((2 + 2*${#display[@]}))

            local awkfields='$4'
            for ((i=6; i<=${awknf}; i+=2)); do
                awkfields+=",\"${SIMBOL_DELIM?}\",\$$i"
            done

            #. Script-readable dump
            local filterstr="(&$(:util:join '' filter))"
            local -l displaystr=$(:util:join ',' display)
            local querystr="ldapsearch -x -LLL -h '${ldaphost}'\
                -p ${USER_LDAPPORT:-389} -x\
                -b '${bdn}' '${filterstr}' ${display[@]}"
            #cpf "%{@cmd:%s}\n" "${querystr}"

            #. TITLE: echo ${display[@]^^}
            #. FIXME: awk BEGIN section has weird RS assignments, which at this time do not
            #. FIXME: make sense to anybody
            eval ${querystr} |
                grep -vE '^#' |
                gawk -v fields=${#display[@]} -v displaystr=${displaystr} \
                    -v delom="${SIMBOL_DELOM?}" -v delim=${SIMBOL_DELIM?} '
BEGIN{
    FS="\n";
    RS="\n\n";
    if(fields>1) RS="\n\n";
    split(displaystr,display,",")
}
{
    for(i=1;i<=NF;i++) {
        if($i && $i!~/^#/) {
            match($i, /^([^:]+): +(.*)$/, kv);
            key=tolower(kv[1]);
            value=kv[2];
            if(length(data[key])>0) data[key]=data[key] delom value;
            else data[key]=value;
        }
    }

    total=length(display);
    hits=0;
    for(i=1;i<=total;i++) {
        key=display[i];
        if(length(data[key])) hits++;
    }

    if(hits==total) {
        for(i=1;i<=total;i++) {
            if(i>1) printf(delim);
            key = display[i];
            printf("%s", data[key]);
        }
        printf("\n");
    }
    delete data;
}'
            e=${PIPESTATUS[0]}
        else
            core:raise EXCEPTION_BAD_FN_CALL
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function ldap:search:usage() { echo "host|subnet|user|group|netgroup [<filter:<attr>=<match>> [<filter>, [...]]] <attr> [<attr> [...]]"; }
function ldap:search() {
    #. NOTE
    #. If any of the specified attributes are missing, every attribute will
    #. fail.  This can be fixed, but at relatively great expense as each
    #. attribute will result in a dedicated ldap query.

    local -i e=${CODE_DEFAULT?}

    if [ $# -gt 1 ]; then
        local bdn
        case $1 in
            host)     bdn=${USER_HDN?};;
            subnet)   bdn=${USER_SDN?};;
            user)     bdn=${USER_UDN?};;
            group)    bdn=${USER_GDN?};;
            netgroup) bdn=${USER_NDN?};;
        esac

        if [ ${#bdn} -gt 0 ]; then
            local data=$(:ldap:search -2 $@)
            e=$?

            if [ ${e} -eq ${CODE_SUCCESS?} ]; then
                #. Look for filter tokens
                local -a filter
                local -a display
                local token
                for token in ${@:2}; do
                    if [[ ${token} =~ [-a-zA-Z0-9_]+([~\<\>]?=).+ ]]; then
                        filter+=( "(${token})" )
                    else
                        #. Unfortunately, for now it is mandatory that all attributes
                        #. requested must exist, otherwise the caller doesn't know
                        #. which ones are missing.
                        filter+=( "(${token}=*)" )
                        display+=( ${token} )
                    fi
                done

                while IFS="${SIMBOL_DELIM?}" read ${display[@]}; do
                    for attr in ${display[@]}; do
                        local values_raw=${!attr}
                        if [ ${#values_raw} -gt 0 ]; then
                            IFS="${SIMBOL_DELOM?}" read -a values <<< "${values_raw}"
                            local value
                            for value in ${values[@]}; do
                                cpf "%{@key:%-32s}%{@val:%s}\n" "${attr}" "${value}"
                            done
                        else
                            cpf "%{@key:%-32s}%{@err:%s}\n" "${attr}" "ERROR"
                            e=${CODE_FAILURE?}
                        fi
                    done
                    cpf
                done <<< "${data}"
            else
                theme HAS_FAILED "UNKNOWN ERROR"
            fi
        fi
    fi

    return $e
}
#. }=-
#. ldap:ngverify -={
function ldap:ngverify() {
    #. NOTE
    #. If any of the specified attributes are missing, every attribute will
    #. fail.  This can be fixed, but at relatively great expense as each
    #. attribute will result in a dedicated ldap query.

    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 0 ]; then
        local bdn=${USER_NDN?}
        local data=$(:ldap:search -2 netgroup cn nisNetgroupTriple)
        e=$?
        if [ ${e} -eq ${CODE_SUCCESS?} ]; then
            #. Look for filter tokens
            while IFS="${SIMBOL_DELIM?}" read cn nisNetgroupTripleRaw; do
                local -i hits=0
                IFS="${SIMBOL_DELOM?}" read -a nisNetgroupTriples <<< "${nisNetgroupTripleRaw}"
                for nisNetgroupTriple in ${nisNetgroupTriples[@]}; do
                    if [[ ${nisNetgroupTriple} =~ ${USER_REGEX[NIS_NETGROUP_TRIPLE_PASS]} ]]; then
                        : cpf "%{@netgroup:%-32s} -> %{@pass:%s}\n" ${cn} ${nisNetgroupTriple}
                        : hits=1
                    elif [[ ${nisNetgroupTriple} =~ ${USER_REGEX[NIS_NETGROUP_TRIPLE_WARN]} ]]; then
                        cpf "%{@netgroup:%-32s} -> %{@warn:%s}\n" ${cn} ${nisNetgroupTriple}
                        hits=1
                    else
                        cpf "%{@netgroup:%-32s} -> %{@fail:%s}\n" ${cn} ${nisNetgroupTriple}
                        hits=1
                    fi
                done
                [ ${hits} -eq 0 ] || cpf
            done <<< "${data}"
        else
            theme HAS_FAILED "LDAP_CONNECT"
        fi
    fi

    return $e
}
#. }=-
#. }=-
