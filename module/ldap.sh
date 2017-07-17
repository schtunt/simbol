#shellcheck disable=SC2155,SC2154
# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
The simbol LDAP module
[core:docstring]

#. LDAP -={
#. https://access.redhat.com/simbol/documentation/en-US/Red_Hat_Directory_Server/8.2/html-single/Administration_Guide/index.html#Managing_Replication-Replicating-Password-Attributes
#g_MAXDATA=20380119031407Z

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
    #. {no-arguments} = 
    #.    Returns a random LDAP host from the pool or the globally set g_LDAPHOST
    #.
    #. <arguments> = 0..
    #.    Returns a specific LDAP host if 1 argument is supplied which is
    #.    positive and less than the number of ldap hosts defined.
    #.
    #. Throws an exception otherwise.

    core:raise_bad_fn_call_unless $# in 0 1
    local -i e; let e=CODE_FAILURE
    local user_ldaphost=
    case $# in
        0)
            if (( g_LDAPHOST >= 0 )); then
            	user_ldaphost=$(:ldap:host "${g_LDAPHOST?}")
            	let e=$?
	    else
            	let e=CODE_SUCCESS
	    fi
            ;;
        1)
            local -i lhi; let lhi=$1
            if [[ ${lhi} -lt ${#USER_LDAPHOSTS[@]} && ${lhi} -ge 0 ]]; then
            	user_ldaphost="${USER_LDAPHOSTS[${lhi}]}"
               	let e=CODE_SUCCESS
	    else
                core:raise EXCEPTION_BAD_FN_CALL "BAD_INDEX"
            fi 
            ;;
        *) core:raise EXCEPTION_BAD_FN_CALL ;;
    esac

    if (( e == CODE_SUCCESS )); then
        if [ ${#user_ldaphost} -eq 0 ]; then
            user_ldaphost="${USER_LDAPHOSTS[$((${RANDOM?}%${#USER_LDAPHOSTS[@]}))]}"
        fi
        echo "${user_ldaphost}"
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}
#shellcheck disable=SC2120
function :ldap:host_rw() {
    #. Returns a random LDAP host from the pool, that offer rw functionality
    #. Assumes all hosts are functional
    core:raise_bad_fn_call_unless $# in 0

    local -i e; let e=CODE_FAILURE

    local user_ldaphost_rw
    if [ "${g_LDAPHOST?}" -lt 0 ]; then
        user_ldaphost_rw="${USER_LDAPHOSTS_RW[$((${RANDOM?}%${#USER_LDAPHOSTS_RW[@]}))]}"
        let e=CODE_SUCCESS
    elif [ "${g_LDAPHOST?}" -lt ${#USER_LDAPHOSTS_RW[@]} ]; then
        user_ldaphost_rw="${USER_LDAPHOSTS_RW[${g_LDAPHOST?}]}"
        let e=CODE_SUCCESS
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi
    echo "${user_ldaphost_rw}"

    return $e
}
#. }=-
#. ldap:authentication -={
declare -g g_PASSWD_CACHED=
function :ldap:authenticate() {
    local -i e; let e=CODE_FAILURE

    if [ ${#g_PASSWD_CACHED} -eq 0 ]; then
        g_PASSWD_CACHED="$(:vault:read LDAP)"
        let e=$?

        #shellcheck disable=SC2119
        local ldaphost_rw=$(:ldap:host_rw)
        if [ $e -ne 0 ]; then
            read -r -p "Enter LDAP ($ldaphost_rw}) Password: " -s g_PASSWD_CACHED
            echo
        fi

        if ldapsearch -x -LLL -h "${ldaphost_rw}" -p "${USER_LDAPPORT:-389}"\
            -D "uid=${USER_USERNAME?},${USER_UDN?}" -w "${g_PASSWD_CACHED?}"\
            -b "${USER_UDN?}" >/dev/null 2>&1; then
            export g_PASSWD_CACHED
            let e=CODE_SUCCESS
        else
            g_PASSWD_CACHED=
        fi
    else
        let e=CODE_SUCCESS
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
    core:raise_bad_fn_call_unless $# ge 4
    local -i e; let e=CODE_DEFAULT

    vimcat <<< "$(::ldap:mkldif "$@")" >&2
    let e=$?

    return $e
}
function ::ldap:mkldif() {
: <<!
    This function generates an ldif; which is suitable for feeding into
    ldapmodify.
!
    core:raise_bad_fn_call_unless $# gt 3
    local -i e; let e=CODE_FAILURE

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
            let e=CODE_SUCCESS
        ;;
        group)
            local groupname=$3
            dn="cn=${groupname},${USER_GDN?}"
            let e=CODE_SUCCESS
        ;;
        netgroup)
            local netgroupname=$3
            dn="cn=${netgroupname},${USER_NDN?}"
            let e=CODE_SUCCESS
        ;;
    esac

    if (( e == CODE_SUCCESS )); then
        echo "# vim:syntax=ldif"
        echo "dn: ${dn}"
        echo "changetype: ${change}"
        local attr=
        for ((i=4; i<$#+1; i++)); do
            if [[ "${!i}" != "-" && ${#attr} -gt 0 ]]; then
                #shellcheck disable=SC2059
                printf "\n${attr}: ${!i}";
            else
                if [ ${#attr} -gt 0 ]; then
                    printf "\n-\n"
                    ((i++))
                fi
                attr="${!i}"
                #shellcheck disable=SC2059
                printf "${action}: ${attr}"
            fi
        done
        printf "\n"
    else
        core:raise EXCEPTION_BAD_FN_CALL
    fi

    return $e
}

function :ldap:modify() {
    core:raise_bad_fn_call_unless $# ge 3
    local -i e; let e=CODE_FAILURE

    local context=$1
    case ${context} in
        user)
            if :ldap:authenticate; then
                local username=$2
                local change=$3
                case ${change} in
                    delete|add|replace)
                        shift 3
                        local ldif="$(::ldap:mkldif "${change}" user "${username}" "$@")"
                        #shellcheck disable=SC2119
                        local ldaphost_rw=$(:ldap:host_rw)
                        ldapmodify -x -h "${ldaphost_rw}"\
                            -p "${USER_LDAPPORT:-389}"\
                            -D "uid=${USER_USERNAME?},${USER_UDN?}"\
                            -w "${g_PASSWD_CACHED?}"\
                            -c <<< "${ldif}"  >/dev/null 2>&1
                        let e=$?
                        if (( e !=  CODE_SUCCESS )); then
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
                        local ldif="$(::ldap:mkldif "${change}" group "${groupname}" "$@")"
                        #shellcheck disable=SC2119
                        local ldaphost_rw=$(:ldap:host_rw)
                        ldapmodify -x -h "${ldaphost_rw}"\
                            -p "${USER_LDAPPORT:-389}"\
                            -D "uid=${USER_USERNAME?},${USER_UDN?}"\
                            -w "${g_PASSWD_CACHED?}"\
                            -c <<< "${ldif}"  >/dev/null 2>&1
                        let e=$?
                        if (( e != CODE_SUCCESS )); then
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

    return $e
}

function :ldap:add() {
:<<:
...
:
    core:raise_bad_fn_call_unless $# ge 3
    local -i e; let e=CODE_FAILURE

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
                    "objectClass=top"
                    "objectClass=nisNetgroup"
                    "cn=${id}"
                )
            ;;
            *) core:raise EXCEPTION_BAD_FN_CALL;;
        esac

        #shellcheck disable=SC2119
        local ldaphost_rw=$(:ldap:host_rw)
        local ldif="$(
            printf "dn: %s\n" "${dn}"

            local attr
            for attr in "${template[@]}" "${@:3}"; do
                IFS='=' read -r key value <<< "${attr}"
                printf "%s: %s\n" "${key}" "${value}"
            done
            printf "\n"
        )"

        local output=$(
            ldapmodify -a -x -h "${ldaphost_rw}" -p "${USER_LDAPPORT:-389}"\
                -D "uid=${USER_USERNAME?},${USER_UDN?}"\
                -w "${g_PASSWD_CACHED?}" <<< "${ldif}" 2>&1
        )

        let e=$?
        if (( e == CODE_SUCCESS )); then
            core:log INFO "${output}"
        else
            core:log ERR "${output}"
        fi
    fi

    return $e
}
#. }=-
#. ldap:checksum -={
function ldap:checksum:usage() { echo "[<ldaphostid> <ldaphostid> [<ldaphostid> [...]]]"; }
function ldap:checksum() {
    core:requires ANY colordiff diff

    local -i e; let e=CODE_DEFAULT

    local -i lhi
    local -a ldaphostids
    if [ $# -eq 0 ]; then
        local -i e; let e=CODE_SUCCESS
        ldaphostids=( ${!USER_LDAPHOSTS[@]} )
    elif [ $# -ge 2 ]; then
        local -i e; let e=CODE_SUCCESS
        for lhi in "$@"; do
            if (( lhi  < ${#USER_LDAPHOSTS[@]} )); then
                ldaphostids+=( ${lhi} )
            else
                local -i e; let e=CODE_FAILURE
            fi
        done
    fi

    if (( e == CODE_SUCCESS )); then
        local -A dump
        local md5
        local uidc

        local -a ldaphosts
        for lhi in "${ldaphostids[@]}"; do
            ldaphosts+=( ${USER_LDAPHOSTS[${lhi}]} )
        done
        cpf "Integrity check between %{@int:%s} ldap hosts (ids:%{@int:%s})...\n"\
            "${#ldaphostids[@]}" "$(:util:join , ldaphostids)"

        for ngc in {a..z}; do
            cpf "Integrity check for %{c:ng=}%{r:${ngc}*}..."
            local -A md5s=()
            for lh in "${ldaphosts[@]}"; do
                if dump[${lh}]=$(
                    ldapsearch -x -LLL -E pr=128/noprompt -S dn -h "${lh}"\
                        -p "${USER_LDAPPORT:-389}" -b "${USER_NDN?}"\
                        cn="${ngc}*" cn memberNisNetgroup netgroupTriple description |
                            sed -e 's/^dn:.*/\L&/' |
                            grep -v 'pagedresults:' 2>/dev/null
                ); then
                    cpf '+'
                else
                    cpf '!'
                fi
                md5="$(echo "${dump[${lh}]}"|md5sum|awk '{print$1}')"
                md5s[${md5}]=${lh}
            done

            #. identical block -={
            cpf ...
            local ldaphost=${ldaphosts[0]}
            local -i len=${#dump[${ldaphost}]}
            if [ ${#md5s[@]} -eq 1 ]; then
                if (( len > 1 )); then
                    theme HAS_PASSED "${md5}:${len}"
                else
                    theme HAS_PASSED "${md5}:empty"
                fi
            else
                theme HAS_FAILED "${#md5s[@]} variants in the ${#ldaphosts[@]} hosts"
                e=${CODE_FAILURE?}
                for lh in "${ldaphosts[@]}"; do
                    if [ "${lh}" != "${ldaphost}" ]; then
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
            for lh in "${ldaphosts[@]}"; do
                if dump[${lh}]=$(
                    ldapsearch -x -LLL -E pr=128/noprompt -p "${USER_LDAPPORT:-389}"\
                        -S dn -h "${lh}" -b "${USER_UDN?}"\
                        uid="${uidc}*" "${USER_LDAP_SYNC_ATTRS[@]}" |
                            sed -e 's/^dn:.*/\L&/' |
                            grep -v 'pagedresults:' 2>/dev/null
                ); then
                    cpf '+'
                else
                    cpf '!'
                fi
                md5="$(echo "${dump[${lh}]}"|md5sum|awk '{print$1}')"
                md5s[${md5}]=${lh}
            done

            #. identical block -={
            cpf ...
            local ldaphost=${ldaphosts[0]}
            local -i len; let len=${#dump[${ldaphost}]}
            if [ ${#md5s[@]} -eq 1 ]; then
                if [ ${len} -gt 1 ]; then
                    theme HAS_PASSED "${md5}:${len}"
                else
                    theme HAS_PASSED "${md5}:empty"
                fi
            else
                theme HAS_FAILED "${#md5s[@]} variants in the ${#ldaphosts[@]} hosts"
                let e=CODE_FAILURE
                for lh in "${ldaphosts[@]}"; do
                    if [ "${lh}" != "${ldaphost}" ]; then
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
    core:raise_bad_fn_call_unless $# in 2
    local -i e; let e=CODE_FAILURE

        local -i lhi; let lhi=$1
        local context=$2
        shift 3
        case $context in
            host)
                local hostname=$3
                local ldaphost=$(:ldap:host ${lhi})
                local userdata=$(
                    ldapsearch -x -LLL -E pr=1024/noprompt -h "${ldaphost}"\
                        -p "${USER_LDAPPORT:-389}"\
                        -b "${USER_HDN?}" "cn=${hostname}" "$@"|grep -vE '^#'
                )
                let e=$?

                echo "${userdata}"
            ;;
            user)
                local username=$3
                local ldaphost=$(:ldap:host ${lhi})
                local userdata=$(
                    ldapsearch -x -LLL -E pr=1024/noprompt -h "${ldaphost}"\
                        -p "${USER_LDAPPORT:-389}"\
                        -b "${USER_UDN?}" "uid=${username}" "$@"|grep -vE '^#'
                )
                if [ $# -gt 0 ]; then
                    #. User specified which attrs they want:
                    for attr in "$@"; do
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
                    while read -r line; do
                        #shellcheck disable=SC2001
                        local attr="$(echo "${line}"|sed -e 's/^\(.*\): *\(.*\)$/\L\1/')"
                        #shellcheck disable=SC2001
                        local val="$(echo "${line}"|sed -e 's/^\(.*\): *\(.*\)$/\2/')"
                        if [ "${ldifdata[${attr}]:-NilOrNotSet}" == 'NilOrNotSet' ]; then
                            eval "local -a _ldap_${attr,,}=( \"${val}\" )"
                            #shellcheck disable=SC2149
                            ((ldifdata[${attr}]=1))
                        else
                            #shellcheck disable=SC2149
                            ((ldifdata[${attr}]+=1))
                            eval "_ldap_${attr,,}+=( '${val}' )"
                        fi
                    done <<< "${userdata}"

                    #. Print as eval bash arrays
                    printf "#. WARNING: If ldap values have double-quotes, they will be stripped.\n"
                    for attrs in ${!_ldap_*}; do
                        local -i attrlen
                        #shellcheck disable=SC1087
                        let attrlen=$(eval "echo \${#$attrs[@]}") #. number of attribute definitions

                        echo -n "local -a ${attrs}=("
                        for ((i=0; i<attrlen; i++)); do
                            printf ' "'
                            eval "printf \"\${$attrs[${i}]}\""|tr -d '"'
                            printf '"'
                        done
                        printf " )\n"

                    done

                    #. Print as ldif (bash comments)
                    for attrs in ${!_ldap_*}; do
                        local -i attrlen;
                        #shellcheck disable=SC1087
                        let attrlen=$(eval "echo \${#$attrs[@]}") #. number of attribute definitions
                        for ((i=0; i<attrlen; i++)); do
                            #shellcheck disable=SC2086
                            eval 'echo "#. ${attrs//_ldap_/}: ${'$attrs'[${i}]}"'
                        done
                    done
                fi

                let e=CODE_SUCCESS
            ;;
        esac
    return $e
}

function :ldap:search() {
    : "${SIMBOL_DELOM?}"
    #. This function seaches for multiple objects
    #.
    #. Usage:
    #.       IFS="${SIMBOL_DELOM?}" read -a fred <<< "$(:ldap:search <lhi> netgroup cn=jboss_prd nisNetgroupTriple)"
    core:raise_bad_fn_call_unless $# gt 2
    local -i e; let e=CODE_FAILURE

    local bdn
    local -i lhi; let lhi=0
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
        local -i awknf; let awknf=$((2 + 2*${#display[@]}))

        #shellcheck disable=SC2016
        local awkfields='$4'
        for ((i=6; i<=awknf; i+=2)); do
            awkfields+=",\"${SIMBOL_DELIM?}\",\$$i"
        done

        #. Script-readable dump
        local filterstr="(&$(:util:join '' filter))"
        local -l displaystr=$(:util:join ',' display)
        local querystr="ldapsearch -x -LLL -h '${ldaphost}'\
            -p ${USER_LDAPPORT:-389} -x\
            -b '${bdn}' '${filterstr}' ${display[*]}"
        #cpf "%{@cmd:%s}\n" "${querystr}"

        #. TITLE: echo ${display[@]^^}
        #. FIXME: awk BEGIN section has weird RS assignments, which at this time do not
        #. FIXME: make sense to anybody
        eval "${querystr}" |
            grep -vE '^#' |
            gawk -v fields=${#display[@]} -v displaystr="${displaystr}" \
                -v delom="${SIMBOL_DELOM?}" -v delim="${SIMBOL_DELIM?}" '
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
        let e=${PIPESTATUS[0]}
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
    core:raise_bad_fn_call_unless $# in 1
    local -i e; let e=CODE_DEFAULT

    local bdn
    case $1 in
        host)     bdn=${USER_HDN?};;
        subnet)   bdn=${USER_SDN?};;
        user)     bdn=${USER_UDN?};;
        group)    bdn=${USER_GDN?};;
        netgroup) bdn=${USER_NDN?};;
    esac

    if [ ${#bdn} -gt 0 ]; then
        local data="$(:ldap:search -2 "$@")"
        let e=$?

        if (( e == CODE_SUCCESS )); then
            #. Look for filter tokens
            local -a filter
            local -a display
            local token
            for token in "${@:2}"; do
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

            while IFS="${SIMBOL_DELIM?}" read -r "${display[@]}"; do
                for attr in "${display[@]}"; do
                    local values_raw=${!attr}
                    if [ ${#values_raw} -gt 0 ]; then
                        IFS="${SIMBOL_DELOM?}" read -r -a values <<< "${values_raw}"
                        local value
                        for value in "${values[@]}"; do
                            cpf "%{@key:%-32s}%{@val:%s}\n" "${attr}" "${value}"
                        done
                    else
                        cpf "%{@key:%-32s}%{@err:%s}\n" "${attr}" "ERROR"
                        let e=CODE_FAILURE
                    fi
                done
                echo
            done <<< "${data}"
        else
            theme HAS_FAILED "UNKNOWN ERROR"
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
    core:raise_bad_fn_call_unless $# in 0
    local -i e; let e=CODE_DEFAULT

    local bdn=${USER_NDN?}
    local data=$(:ldap:search -2 netgroup cn nisNetgroupTriple)
    let e=$?
    if (( e == CODE_SUCCESS )); then
        #. Look for filter tokens
        while IFS="${SIMBOL_DELIM?}" read -r cn nisNetgroupTripleRaw; do
            local -i hits=0
            IFS="${SIMBOL_DELOM?}" read -r -a nisNetgroupTriples <<< "${nisNetgroupTripleRaw}"
            for nisNetgroupTriple in "${nisNetgroupTriples[@]}"; do
                if [[ ${nisNetgroupTriple} =~ ${USER_REGEX[NIS_NETGROUP_TRIPLE_PASS]} ]]; then
                    : cpf "%{@netgroup:%-32s} -> %{@pass:%s}\n" "${cn}" "${nisNetgroupTriple}"
                    : hits=1
                elif [[ ${nisNetgroupTriple} =~ ${USER_REGEX[NIS_NETGROUP_TRIPLE_WARN]} ]]; then
                    cpf "%{@netgroup:%-32s} -> %{@warn:%s}\n" "${cn}" "${nisNetgroupTriple}"
                    hits=1
                else
                    cpf "%{@netgroup:%-32s} -> %{@fail:%s}\n" "${cn}" "${nisNetgroupTriple}"
                    hits=1
                fi
            done
            [ ${hits} -eq 0 ] || echo
        done <<< "${data}"
    else
        theme HAS_FAILED "LDAP_CONNECT"
    fi

    return $e
}
#. }=-
#. }=-
