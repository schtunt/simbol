# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
Core Unit-Testing Module
[core:docstring]

#. Unit Testing -={
#. Scaffolding -={
moduleScaffold() {
    local -i e=0

    local cl=${1^}

    #. aws.ec2
    local module=$2

    #. AwsEc2
    local modulecaps=$(IFS='.' read -a __ <<< "${module}"; printf "%s" ${__[@]^})

    #. awsEc2SetUp/awsEc2TearDown
    modulefn=${modulecaps,}${cl}

    cpf "%{@comment:${modulefn}...}"

    if [ -f ${g_RUNTIME_SCRIPT?} ]; then
        if [ $? -eq 0 ]; then
            if [ "$(type -t ${modulefn} 2>/dev/null)" == "function" ]; then
                ${modulefn}
                e=$?
                if [ $e -eq 0 ]; then
                    theme HAS_PASSED
                else
                    theme HAS_FAILED
                fi
            else
                theme HAS_WARNED "UNDEFINED:${modulefn}"
            fi
        else
            theme HAS_FAILED
            e=${CODE_FAILURE?}
        fi
    else
        theme HAS_PASSED "DYNAMIC_ONLY"
    fi

    return $e
}

oneTimeSetUp() {
    : ${module?}

    cpf "%{@comment:unitSetUp...}"
    local -i e=${CODE_SUCCESS?}

    declare -gi tid=0

    declare -g oD="${SHUNIT_TMPDIR?}"
    mkdir -p "${oD}"

    declare -g stdoutF="${oD}/stdout"
    declare -g stderrF="${oD}/stderr"

    #. Enable all modules regardless
    local _module
    for _module in ${!CORE_MODULES[@]}; do
        CORE_MODULES[${_module}]=1
    done

    case ${g_MODE?} in
        prime)
            : noop
        ;;
        execute)
            if [ "${CITM_HOST:-false}" == "d41d8cd98f00b204e9800998ecf8427e" ]; then
                #. Set up the network/hosts/etc for unit testing -={
                #. Prime `/etc/hosts' -={
                (
                    local -i i=0
                    local -i j
                    local -i k
                    local -i index

                    local -a subdomains
                    local tldid
                    local domain subdomain
                    for tldid in "${!USER_TLDS[@]}"; do
                        ((i++))
                        subdomains=( $(eval echo "\${USER_SUBDOMAIN_${tldid}[@]}") )
                        if [ ${#subdomains[@]} -gt 0 ]; then
                            for ((j=8; j<16; j++)); do
                                domain=${USER_TLDS[${tldid}]}
                                printf "127.%d.%d.%d		host-%x.%s\n"\
                                    ${i} ${j} 99\
                                    ${j} ${domain}
                                for ((k=8; k<16; k++)); do
                                    ((index=k%${#subdomains[@]}))
                                    printf "127.%d.%d.%d		host-%x%x.%s.%s host-%x%x.%s\n"\
                                        ${i} ${j} ${k}\
                                        ${j} ${k} ${subdomains[${index}]} ${domain}\
                                        ${j} ${k} ${subdomains[${index}]}
                                done
                            done
                        fi
                    done
                ) | sudo tee -a /etc/hosts >/dev/null 2>&1
                #. }=-
                #. Prime  `~/.ssh/known_hosts' -={
                touch ~/.ssh/known_hosts
                local -i i=0
                local -i j
                local -i k
                local -i index

                local -a subdomains
                local tldid
                local ip qdn fqdn
                local domain subdomain
                (
                    for tldid in "${!USER_TLDS[@]}"; do
                        ((i++))
                        subdomains=( $(eval echo "\${USER_SUBDOMAIN_${tldid}[@]}") )
                        for ((j=8; j<16; j++)); do
                            domain=${USER_TLDS[${tldid}]}

                            local ip=$(printf "127.%d.%d.%d" ${i} ${j} 99)
                            ssh-keyscan -t rsa ${ip}

                            local fqdn=$(printf "host-%x.%s" ${j} ${domain})
                            ssh-keyscan -t rsa ${fqdn}

                            for ((k=8; k<16; k++)); do
                                ip=$(printf "127.%d.%d.%d" ${i} ${j} ${k})
                                ssh-keyscan -t rsa ${ip}

                                ((index=k%${#subdomains[@]}))
                                qdn=$(
                                    printf "host-%x%x.%s"\
                                        ${j} ${k} ${subdomains[${index}]}
                                )
                                ssh-keyscan -t rsa ${qdn}

                                fqdn=$(
                                    printf "host-%x%x.%s.%s"\
                                        ${j} ${k} ${subdomains[${index}]} ${domain}
                                )
                                ssh-keyscan -t rsa ${fqdn}
                            done
                        done
                    done
                )  2>/dev/null | sudo tee -a ~/.ssh/known_hosts >/dev/null
                #. }=-
                #. Generate `~/.ssh/id_rsa*' -={
                [ -e ~/.ssh/id_rsa ] || ssh-keygen -q -t rsa -N "" -f ~/.ssh/id_rsa
                #. }=-
                #. Prime `~root/.ssh/authorized_keys -={
                install -m 400 ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
                #. }=-
            #. }=-
            fi
        ;;
    esac
    theme HAS_PASSED

    moduleScaffold setUp ${module?}
    e=$?

    return $e
}

oneTimeTearDown() {
    local -i e=${CODE_SUCCESS?}

    moduleScaffold tearDown ${module?}
    e=$?

    cpf "%{@comment:unitTearDown...}"
    rm -rf "${oD?}"
    theme HAS_PASSED

    return $e
}

setUp() {
    : ${tid?}
    ((tid++))
    tidstr=$(printf "%03d" ${tid})
    cpf "%{@comment:Test} %{y:#%s} " "${tidstr}"
}

tearDown() {
    :
}
#. }=-
#. Unit-testing coverage test -={
declare -g -A g_MODULES
function testCoverage() {
    local profile=${g_RUNTIME_PROFILE?}

    #. aws.ec2
    local module=${g_RUNTIME_MODULE?}

    #. AwsEc2
    local modulecaps=$(IFS='.' read -a __ <<< "${module}"; printf "%s" ${__[@]^})

    #. aws/ec2.sh
    local modulepath=${g_RUNTIME_MODULEPATH?}

    local script=${g_RUNTIME_SCRIPT?}
    local cwd=${g_RUNTIME_CWD?}
    local -i e=0
    local -i t=0
    local -i p=0
    local -i s=0

    local -A fnregexes=(
        [private]='^function ::%s:[a-z0-9_]+(\.(json|csv|eval))?\(\)'
        [internal]='^function :%s:[a-z0-9_]+(\.(json|csv|eval))?\(\)'
        [public]='^function %s:[a-z0-9_]+\(\)'
    )

    if [ -d ${cwd} ]; then
        cd ${cwd}
        local context
        local -i blacklisted=0
        local dynamic="${SIMBOL_UNIT_TESTS?}/${module}-dynamic.csv"
        if [ -e ${dynamic} ]; then
            blacklisted=$(
                awk -F\| "BEGIN{b=0};NF==2&&\$1~/^#${profile}$/&&\$2~/^${module}$/{b=1};END{print(b)}" ${dynamic}
            )
        fi

        if [ ${blacklisted} -eq 0 ]; then
            cpf "%{@profile:${profile}}: %{!module:${module}} %{r:-=[}\n"
            for context in private internal public; do
                local regex=$(printf "${fnregexes[${context}]}" ${module})
                local -i count=$(grep -cE "${regex}" ${modulepath})
                cpf "     %{m:${context}}:%{!module:${module}}:%{@int:${count} functions}\n"
                if [ $count -gt 0 ]; then
                    local -a fns=(
                        $(grep -oE "${regex}" ${modulepath} |
                            sed -e "s/^function :\{0,2\}${module}:\([^.()]\+\)\(\.[a-z]\+\)\?()/\1/")
                    )
                    for fn in ${fns[@]}; do
                        local utf="test${profile^}${modulecaps}${fn^}${context^}"
                        utf=${utf/[:]/} #. Remove the colon for shunit2
                        utf=${utf/[.]/} #. Remove the dot if it exists

                        local utf_regex="^test((_[0-9])+_)?${profile^}${modulecaps}${fn^}${context^}$"
                        utf_regex=${utf_regex/:/} #. Remove the colon for shunit2

                        local -i static_tests=$(declare -F|awk '$3~/'${utf_regex}'/{print$3}'|wc -l)
                        if [ ${static_tests} -gt 0 ]; then
                            cpf "      %{@comment:|___} %{!function:${module}:${fn}} %{+bo}%{g:static}%{-bo} %{@fn:${utf}}..."
                            theme HAS_PASSED "Static:${static_tests}"
                        fi

                        cpf "      %{@comment:|___} %{!function:${module}:${fn}} %{g:dynamic}; %{@fn:${utf}}..."
                        if [ -e ${dynamic} ]; then
                            blacklisted=$(
                                awk -F\| "BEGIN{b=0};NF==4&&\$1~/^#${profile}$/&&\$2~/^${module}$/&&\$3~/^${fn}$/&&\$4~/^${context}$/{b=1};END{print(b)}" ${dynamic}
                            )
                        fi
                        if [ ${blacklisted} -eq 0 ]; then
                            local input
                            if [ -e ${dynamic} ]; then
                                input="$(awk -F\| "\$1~/^${profile}$/&&\$2~/^${module}$/&&\$3~/^${fn}$/&&\$4~/^${context}$/{print\$0}" ${dynamic})"
                            fi
                            if [ -n "${input}" ]; then
                                local -i i=0
                                local line
                                while read line; do
                                    ((i++))
                                    local ffn=
                                    case ${context} in
                                        private)  ffn+=::;;
                                        internal) ffn+=:;;
                                    esac
                                    ffn+=${prefix}${module}:${fn}
                                    if [ "${context}" == "public" ]; then
                                        cat <<!SCRIPT >> ${script}
#. Dynamic function ${i} for ${utf} {no-args} [ simbol:${profile}:${module}.${fn}() ] -={

function ${utf}Dyn${i}NoArgs() {
    #. Check if the function called without any arguments returns CODE_DEFAULT, or otherwise CODE_SUCCESS
    #. TODO: At the moment, no way to tell automatically if its CODE_DEFAULT or CODE_SUCCESS we expect
    #. TODO: so this either/or approach will have to do.
    core:softimport ${module}
    cpf " %{@comment ___simbol} %{!function:${module}:${fn}} {no-args} "
    if assertEquals "import ${module}" ${CODE_SUCCESS?} \$?; then
        ${ffn} >/dev/null 2>&1
        ((e=\$? % ${CODE_DEFAULT?})) #. See why above
        if assertEquals "exit code" ${CODE_SUCCESS?} \${e}; then
            theme HAS_PASSED
        else
            theme HAS_FAILED "Expected return code ${CODE_DEFAULT?} or ${CODE_SUCCESS?}, but not \${e}"
        fi
    fi
}
#. }=-
!SCRIPT
                                    fi
                                    IFS='|' read       \
                                        auto_profile   \
                                        auto_module    \
                                        auto_fn        \
                                        auto_context   \
                                        auto_stdin     \
                                        auto_arguments \
                                        auto_stdout    \
                                        auto_stderr    \
                                        auto_exitcode  \
                                        auto_simbol      \
                                    <<< "${line}"
                                    cat <<!SCRIPT >> ${script}
#. Dynamic function ${i} for ${utf} [ simbol:${auto_profile}:${auto_module}.${auto_fn}() ] -={

function ${utf}Dyn${i}() {
    local regex_stdin="${auto_stdin?}";
    local regex_stdout='${auto_stdout?}';
    local regex_stderr='${auto_stderr?}';

    cpf " %{@comment ___simbol} %{!function:${auto_module}:${auto_fn}} ${auto_arguments//%/%%} %{r:-=[} "
        cpf "%{g:out(}"; echo -ne "\${regex_stdout:--}"; cpf "%{g:)}"; cpf " %{y:/} "
        cpf "%{r:err(}"; echo -ne "\${regex_stderr:--}"; cpf "%{r:)}"; cpf " %{y:/} ";
        [ ${auto_exitcode} -eq 0 ] && cpf "%{g:0}" || cpf "%{r:${auto_exitcode}}"
    cpf " %{r:]=-}"

    if [ -z "${auto_simbol}" -o "${auto_simbol}" == "${SIMBOL_PROFILE?}" ]; then
        cpf
        core:softimport ${auto_module}
        if assertEquals "import ${auto_module}" ${CODE_SUCCESS?} \$?; then
            if assertEquals "function" \$(type -t "${ffn}"); then
                local -i e
                local argv='${auto_arguments}'
                if [ "${auto_context}" == "public" ]; then
                    if [ -z "\${regex_stdin}" ]; then
                        #. We go via the outer core wrapper to ensure user short
                        #. and long options are resovled properly for public functions.
                        core:wrapper ${auto_module} ${auto_fn} \${argv} >\${stdoutF?} 2>\${stderrF?}
                    else
                        echo "\${regex_stdin}" | core:wrapper ${auto_module} ${auto_fn} \${argv} >\${stdoutF?} 2>\${stderrF?}
                        e=\$?
                    fi
                else
                    if [ -z "\${regex_stdin}" ]; then
                        #. No need to worry about such -a|--argument style options
                        #. for non-public function calls as they do not support
                        #. this, only public functions do, so we can call the
                        #. inner functions directly.
                        ${ffn} \${argv} >\${stdoutF?} 2>\${stderrF?}
                    else
                        echo "\${regex_stdin}" | ${ffn} \${argv} >\${stdoutF?} 2>\${stderrF?}
                        e=\$?
                    fi
                fi
                e=\$?

                if assertEquals "exit code" ${auto_exitcode} \$e; then
                    if [ -n "\${regex_stdout?}" ]; then
                        local stdout_ok=0
                        if [ \${#regex_stdout} -eq 32 -a -z "\${regex_stdout//[0-9a-f]/}" ]; then
                            local md5=\$(md5sum \${stdoutF?}|awk '{print\$1}')
                            if [ "\${md5}" == "\${regex_stdout?}" ]; then
                                stdout_ok=1
                            else
                                echo "    \${md5}" vs "\${regex_stdout?}"
                            fi
                        fi
                        if [ \${stdout_ok} -eq 0 ]; then
                            read -r stdout_line <\${stdoutF?}
                            if ! [[ \${stdout_line?} =~ \${regex_stdout} ]]; then
                                assertEquals "\${regex_stdout?}" "\${stdout_line?}"
                            fi
                        fi
                    fi

                    if [ -n "\${regex_stderr}" ]; then
                        local stderr_ok=1
                        if [ \${#regex_stderr} -eq 32 -a -z "\${regex_stderr//[0-9a-f]/}" ]; then
                            local md5=\$(md5sum \${stderrF}|awk '{print\$1}')
                            if [ "\${md5}" == "\${regex_stderr}" ]; then
                                stderr_ok=1
                            else
                                echo "    \${md5}" vs "\${regex_stderr?}"
                            fi
                        fi
                        if [ \${stderr_ok} -eq 0 ]; then
                            read -r stderr_line <\${stderrF?}
                            if ! [[ \${stderr_line?} =~ \${regex_stderr} ]]; then
                                cpf "    %{@warn:WARNING}: Unexpected output to stderr [%{@warn:%s}]\n" "\${auto_stderr}"
                            fi
                        fi
                    fi

                else
                    echo "Exiting early."
                fi
            else
                echo "Exiting early."
            fi
        else
            echo "Exiting early."
        fi
    else
        theme HAS_WARNED "Skipped (${auto_simbol})"
    fi
}
#. }=-
!SCRIPT
                                done <<< "${input}"
                                theme HAS_PASSED "Dynamic:$i"
                                ((p++))
                            else
                                if [ ${static_tests} -gt 0 ]; then
                                    theme HAS_PASSED "StaticOnly"
                                    ((p++))
                                else
                                    theme HAS_FAILED "Undefined"
                                    ((e++))
                                fi
                            fi
                        else
                            theme HAS_WARNED "Blacklisted"
                            ((s++))
                        fi
                        ((t++))
                    done
                fi
            done
            cpf "%{r:]=-} %{@profile:${profile}}: %{!module:${module}}\n"
        else
            cpf "%{@profile:${profile}}: %{!module:${module}} %{r:-=[} %{@warn:BLACKLISTED} %{r:]=-} %{@profile:${profile}}: %{!module:${module}}\n"
        fi
        cd ${OLDPWD?}
    fi

    assertEquals "of the $t unit-tests, $p passed, $s skipped, and $e missing; i.e.," $((t-s)) $p
}
#. }=-
#. Unit-test `simbol' module function -={
function ::unit:test() {
    declare -g g_MODE

    local -i e=0

    local -A profiles=(
        [core]=${SIMBOL_CORE_MOD?}
        [${SIMBOL_PROFILE?}]=${SIMBOL_USER_MOD?}
    )
    for profile in ${!profiles[@]}; do
        if [ -d ${profiles[${profile}]} ]; then
            cd ${profiles[${profile}]}
            local module script
            while read modulepath; do
                module=${modulepath//\//.}
                module=${module%.sh}
                if [ ${#g_MODULES[@]} -eq 0 -o ${g_MODULES[${module}]--1} -eq 1 ]; then
                    g_MODE="prime"
                    cpf "%{@comment:${profile}.${module}}.%{r:${g_MODE?} -=[}\n";
                    (
                        export g_RUNTIME_CWD=${profiles[${profile}]}
                        export g_RUNTIME_PROFILE=${profile}
                        export g_RUNTIME_MODULEPATH=${modulepath}
                        export g_RUNTIME_MODULE=${module}
                        export g_RUNTIME_SCRIPT=${SIMBOL_USER_CACHE?}/unittest-${module}.sh

                        cat <<!SCRIPT > ${g_RUNTIME_SCRIPT?}
#!/bin/bash
#. Script    : ${script}
#. Profile   : ${profile}
#. Module    : ${module}
#. Generated : $(date)
!SCRIPT
                        script=${SIMBOL_UNIT_TESTS?}/${module}-static.sh
                        if [ -r "${script}" ]; then
                            cat "${script}" > ${g_RUNTIME_SCRIPT?}
                        fi
                        source ${g_RUNTIME_SCRIPT?}
                        SHUNIT_PARENT="${SIMBOL_CORE_MOD?}/unit.sh" source ${SHUNIT2?}
                    )
                    local -i ep=$?

                    cpf "%{r:]=-} %{@comment:${profile}.${module}}.%{r:${g_MODE?}}...";
                    if [ ${ep} -eq 0 ]; then
                        theme HAS_PASSED
                    else
                        theme HAS_FAILED
                        let e++
                    fi
                    cpf "%{@comment:#############################################################################}\n"

                    g_MODE="execute"
                    cpf "%{@comment:${profile}.${module}}.%{r:${g_MODE?} -=[}\n";
                    script=${SIMBOL_USER_CACHE?}/unittest-${module}.sh
                    local -i ee=-1
                    if [ -r "${script}" ]; then
                        (
                            export g_RUNTIME_SCRIPT="${script}"
                            source "${script}"
                            SHUNIT_PARENT="${script}" source "${SHUNIT2?}"
                        )
                        ee=$?
                    fi
                    cpf "%{r:]=-} %{@comment:${profile}.${module}}.%{r:${g_MODE?}}...";
                    if [ ${ee} -eq 0 ]; then
                        theme HAS_PASSED
                    elif [ ${ee} -eq -1 ]; then
                        theme HAS_WARNED "SKIPPED"
                    else
                        theme HAS_FAILED
                        let e++
                    fi
                    cpf "%{@comment:#############################################################################}\n"
                fi
            done < <(find . -name '*.sh'|cut -b3-)
        fi
    done

    return $e
}

function unit:test:usage() { echo "[<module> [<module> [...]]]"; }
function unit:test() {
    local -i e=${CODE_DEFAULT?}

    if [ "${CITM_HOST:-false}" == "d41d8cd98f00b204e9800998ecf8427e" ]; then
        e=${CODE_SUCCESS?}

        local module
        if [ $# -gt 0 ]; then
            for module in ${@}; do
                if core:softimport ${module}; then
                    g_MODULES[${module}]=1
                else
                    g_MODULES[${module}]=0
                    e=${CODE_FAILURE?}
                fi
            done
        fi

        if [ $e -eq ${CODE_SUCCESS?} ]; then
            if [ -e "${SHUNIT2?}" ]; then
                cpf "%{@comment:#############################################################################}\n"
                #. Only regenerate the script if it doesn't exist, or if it is
                #. older than the input unittest csv file.
                ::unit:test
                e=$?

                cpf "Unit-test overall result..."
                [ $e -eq 0 ] && theme HAS_PASSED || theme HAS_FAILED
            else
                theme ERR_USAGE "${SHUNIT2?} is missing"
                e=${CODE_FAILURE?}
            fi
        else
            e=${CODE_FAILURE?}
        fi
    else
        cpf "Dear %{@user:%s}\n" "${USER_USERNAME?}"
        cat <<!

Developers are encouraged to run unit-testing on a throw-away virtual machine.

Please do not run unit testing on your own machine as it will make undesireable
changes to your system.

In order to bypass this lock and run the unit-tests on your thow-away test
machines, simply export CITM_HOST to the output of \`printf|md5sum' first.

Have a wonderful day!

The Site Development Team
!
        e=${CODE_FAILURE?}
    fi

    return $e
}
#. }=-

function unit:core() {
    local -i e=${CODE_SUCCESS?}

    g_MODE="core"

    cpf "%{@comment:${profile}.${module}}.%{r:${g_MODE?} -=[}\n";
    script=${SIMBOL_UNIT_TESTS?}/core.sh
    local -i ee=-1
    if [ -r "${script}" ]; then
        (
            export g_RUNTIME_SCRIPT="${script}"
            source "${script}"
            SHUNIT_PARENT="${script}" source "${SHUNIT2?}"
        )
        ee=$?
    fi
    cpf "%{r:]=-} %{@comment:${profile}.${module}}.%{r:${g_MODE?}}...";
    if [ ${ee} -eq 0 ]; then
        theme HAS_PASSED
    elif [ ${ee} -eq -1 ]; then
        theme HAS_WARNED "SKIPPED"
    else
        theme HAS_FAILED
        let e++
    fi

    return $e
}
#. }=-
