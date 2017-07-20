# vim: tw=0:ts=4:sw=4:et:ft=bash
#shellcheck disable=SC1090,SC2059,SC2154

:<<[core:docstring]
Core Unit-Testing Module
[core:docstring]

#. Unit Testing -={
#. ::unit:functions -={
function ::unit:functions() {
    core:raise_bad_fn_call_unless $# in 3
    local context="$1"
    local module="$2"
    local modulepath="$3"

    local -A fnregexes=(
        [private]='^function ::%s:[a-z0-9_]+(\.(csv|eval|ipc|json))?\(\)'
        [internal]='^function :%s:[a-z0-9_]+(\.(csv|eval|ipc|json))?\(\)'
        [public]='^function %s:[a-z0-9_]+\(\)'
    )

    local regex; 
    #shellcheck disable=SC2059
    regex="$(printf "${fnregexes[${context}]}" "${module}")"
    grep -oE "${regex}" "${modulepath}" |
        sed -re "s/^function :{0,2}${module?}:([^.()]+)(\.([a-z]+))?\(\)/\1\u\3/"
}
#. }=-
#. ::unit:staticTestFunctions -={
function ::unit:staticTestFunctions() {
    core:raise_bad_fn_call_unless $# in 4
    local profile="$1"
    local module="$2"
    local fn="$3"
    local context="$4"

    local script_in=${SIMBOL_UNIT_TESTS?}/${module}-static.sh
    [ -e "${script_in}" ] || return

    local modulecaps; modulecaps="$(::unit:modulecaps "${module}")"

    local utf_regex="^test${profile^}${modulecaps}${fn^}${context^}([A-Z]+[a-z]*)*\(\)$"
    utf_regex=${utf_regex/:/} #. Remove the colon for shunit2

    awk "\$1~/function/&&\$2~/${utf_regex}/{print\$2}" "${script_in}"
}
#. }=-
#. ::unit:modulecaps() -={
function ::unit:modulecaps() {
    # Input: aws.ec2
    # Output: AwsEc2

    local mc
    IFS='.' read -ra mc <<< "${module}"
    printf "%s" "${mc[@]^}"
}
#. }=-
#. ::unit:testFunction() -={
function ::unit:testFunction() {
    core:raise_bad_fn_call_unless $# in 2 4

    local profile="$1"
    local module="$2"
    local modulecaps; modulecaps="$(::unit:modulecaps "${module}")"

    local tfn
    if [ $# -eq 4 ]; then
        local fn="$3"
        local context="$4"

        tfn="test${profile^}${modulecaps}${fn^}${context^}"
    else
        tfn="test${profile^}${modulecaps}"
    fi

    tfn="${tfn/[:]/}" #. Remove the colon for shunit2
    tfn="${tfn/[.]/}" #. Remove the dot if it exists

    echo "${tfn}"
}
#. }=-
#. ::unit:dynamicTestDatum.eval() -={
function ::unit:dynamicTestDatum.eval() {
    core:raise_bad_fn_call_unless $# in 4
    local profile="$1"
    local module="$2"
    local fn="$3"
    local context="$4"

    local csv_in="${SIMBOL_UNIT_TESTS?}/${module}-dynamic.csv"

    local -a variables=(
        auto_profile auto_module auto_fn auto_context
        auto_stdin auto_arguments auto_stdout auto_stderr
        auto_exitcode auto_simbol
    )

    while read -r line; do
        IFS='|' read -r "${variables[@]}" <<< "${line}"
        for var in "${variables[@]}"; do
            printf "%s='%s';" "${var}" "${!var}"
        done
        echo
    done < <(awk -F\| "\$1~/^${profile}$/&&\$2~/^${module}$/&&\$3~/^${fn}$/&&\$4~/^${context}$/{print\$0}" "${csv_in}")
}
#. }=-
#. ::unit:dynamicTestFunction() -={
function ::unit:dynamicTestFunction() {
    local module="$1"
    local fn="$2"
    local context="$3"

    local ffn
    case ${context} in
        public)   ffn="${module}";;
        internal) ffn=":${module}";;
        private)  ffn="::${module}";;
    esac

    if grep -qE '(Csv|Eval|Ipc|Json)$' <<< "${fn}"; then
        ffn+=":$(sed -re 's/(.*)(Csv|Eval|Ipc|Json)$/\1.\l\2/' <<< "${fn}")"
    else
        ffn+=":${fn}"
    fi

    echo "${ffn}"
}
#. }=-
#. ::unit:writeDynamicTestFunctions() -={
function ::unit:writeDynamicTestFunctions() {
    core:raise_bad_fn_call_unless $# in 4
    local profile="$1"
    local module="$2"
    local fn="$3"
    local context="$4"

    local utf; utf="$(::unit:testFunction "${profile}" "${module}" "${fn}" "${context}")"

    local -a dynamic_tests=( )
    local testVarDatum
    local -i i=0
    local ffn
    while read -r testVarDatum; do
        ((i++))
        ffn="$(::unit:dynamicTestFunction "${module}" "${fn}" "${context}")"
        if [ "${context}" == "public" ]; then
            dynamic_tests+=( "${utf}Dyn${i}NoArgs" )
            cat <<!SCRIPT >> "${script_out}"
#. Dynamic function ${i} for ${utf} {no-args} [ simbol:${profile}:${module}.${fn}() ] -={

function ${utf}Dyn${i}NoArgs() {
    #. Check if the function called without any arguments returns CODE_DEFAULT, or otherwise CODE_SUCCESS
    #. TODO: At the moment, no way to tell automatically if its CODE_DEFAULT or CODE_SUCCESS we expect
    #. TODO: so this either/or approach will have to do.
    -=[

    cpfi "%{@module:${module}}:%{@function:${fn}} {no-args} "
    if assertEquals "\${FUNCNAME?}/import" ${CODE_SUCCESS?} \$?; then
        ${ffn} >/dev/null 2>&1
        ((e=\$? % ${CODE_DEFAULT?})) #. See why above
        if assertEquals "\${FUNCNAME?}exitcode" ${CODE_SUCCESS?} \${e}; then
            theme HAS_PASSED
        else
            theme HAS_FAILED "Expected return code ${CODE_DEFAULT?} or ${CODE_SUCCESS?}, but not \${e}"
        fi
    fi

    ]=-
}
#. }=-
!SCRIPT
        fi

        dynamic_tests+=( "${utf}Dyn${i}" )

        eval "${testVarDatum}"
        #shellcheck disable=SC2154
        cat <<!SCRIPT >> "${script_out}"
#. Dynamic function ${i} for ${utf} [ simbol:${auto_profile}:${auto_module}.${auto_fn}() ] -={

function ${utf}Dyn${i}() {
    local regex_stdin="${auto_stdin?}";
    local regex_stdout='${auto_stdout?}';
    local regex_stderr='${auto_stderr?}';

    -=[

    cpfi "%{@module:${auto_module}}:%{@function:${auto_fn}} ${auto_arguments//%/%%} %{r:-=[} "
        cpf "%{g:out(}"; echo -ne "\${regex_stdout:--}"; cpf "%{g:)}"; cpf " %{y:/} "
        cpf "%{r:err(}"; echo -ne "\${regex_stderr:--}"; cpf "%{r:)}"; cpf " %{y:/} ";
        [ ${auto_exitcode} -eq 0 ] && cpf "%{g:0}" || cpf "%{r:${auto_exitcode}}"
    cpf " %{r:]=-}"

    if [ "${auto_simbol:-NilOrNotSet}" == 'NilOrNotSet' -o "${auto_simbol}" == "${profile}" ]; then
        echo
        core:softimport ${auto_module}
        if assertEquals "\${FUNCNAME?}/${auto_module}" ${CODE_SUCCESS?} \$?; then
            if assertEquals "\${FUNCNAME?}/${ffn}()" "function" "\$(type -t "${ffn}")"; then
                local -i e
                local argv='${auto_arguments}'
                if [ "${auto_context}" == "public" ]; then
                    if [ "\${regex_stdin:-NilOrNotSet}" == 'NilOrNotSet' ]; then
                        #. We go via the outer core wrapper to ensure user short
                        #. and long options are resovled properly for public functions.
                        core:wrapper ${auto_module} ${auto_fn} \${argv} >\${stdoutF?} 2>\${stderrF?}
                        e=\$?
                    else
                        echo "\${regex_stdin}" | core:wrapper ${auto_module} ${auto_fn} \${argv} >\${stdoutF?} 2>\${stderrF?}
                        e=\$?
                    fi
                else
                    if [ "\${regex_stdin:-NilOrNotSet}" == 'NilOrNotSet' ]; then
                        #. No need to worry about such -a|--argument style options
                        #. for non-public function calls as they do not support
                        #. this, only public functions do, so we can call the
                        #. inner functions directly.
                        ${ffn} \${argv} >\${stdoutF?} 2>\${stderrF?}
                        e=\$?
                    else
                        echo -e "\${regex_stdin}" | ${ffn} \${argv} >\${stdoutF?} 2>\${stderrF?}
                        e=\$?
                    fi
                fi

                if assertEquals "\${FUNCNAME?}/exitcode" ${auto_exitcode} \$e; then
                    if [ -n "\${regex_stdout?}" ]; then
                        local stdout_ok=0
                        if [ \${#regex_stdout} -eq 32 -a -z "\${regex_stdout//[0-9a-f]/}" ]; then
                            stdout_ok=1
                            local md5=\$(md5sum \${stdoutF?}|awk '{print\$1}')
                            assertEquals \${FUNCNAME?}/stdout_md5 "\${regex_stdout?}" "\${md5}"
                        fi
                        if [ \${stdout_ok} -eq 0 ]; then
                            read -r stdout_line <\${stdoutF?}
                            if ! [[ \${stdout_line?} =~ \${regex_stdout} ]]; then
                                assertEquals \${FUNCNAME?}/regex "\${regex_stdout?}" "\${stdout_line?}"
                            fi
                        fi
                    fi

                    if [ -n "\${regex_stderr}" ]; then
                        local stderr_ok=0
                        if [ \${#regex_stderr} -eq 32 -a -z "\${regex_stderr//[0-9a-f]/}" ]; then
                            stderr_ok=1
                            local md5=\$(md5sum \${stderrF}|awk '{print\$1}')
                            assertEquals \${FUNCNAME?}/stderr_md5 "\${regex_stderr?}" "\${md5}"
                        fi
                        if [ \${stderr_ok} -eq 0 ]; then
                            read -r stderr_line <\${stderrF?}
                            if ! [[ \${stderr_line?} =~ \${regex_stderr} ]]; then
                                cpfi "%{@warn:WARNING}: Unexpected output to stderr [%{@warn:%s}]\n" "\${auto_stderr}"
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

    ]=-
}
#. }=-
!SCRIPT
    done < <(::unit:dynamicTestDatum.eval "${profile}" "${module}" "${fn}" "${context}")

    local -i len; let len=$(core:len dynamic_tests)
    [ ${len} -eq 0 ] || echo "${dynamic_tests[@]}"
}
#. }=-
#. ::unit:blessed() -={
function ::unit:unbless() {
    core:raise_bad_fn_call_unless $# in 2
    local profile="$1"
    local module="$2"

    local -A profiles=(
        [core]="${SIMBOL_CORE_MOD?}"
        [user]="${SIMBOL_USER_MOD?}"
    )

    local blessed="${SIMBOL_USER_VAR_CACHE?}/unittest-${module}.blessed"
    rm -f "${blessed}"
}

function ::unit:bless() {
    core:raise_bad_fn_call_unless $# in 2
    local profile="$1"
    local module="$2"

    local -A profiles=(
        [core]="${SIMBOL_CORE_MOD?}"
        [user]="${SIMBOL_USER_MOD?}"
    )

    local blessed="${SIMBOL_USER_VAR_CACHE?}/unittest-${module}.blessed"
    touch "${blessed}"
}

function ::unit:blessed() {
    core:raise_bad_fn_call_unless $# in 2
    local profile="$1"
    local module="$2"

    local -A profiles=(
        [core]="${SIMBOL_CORE_MOD?}"
        [user]="${SIMBOL_USER_MOD?}"
    )

    local -i e;
    let e=CODE_FAILURE
    local blessed="${SIMBOL_USER_VAR_CACHE?}/unittest-${module}.blessed"
    [ -e "${blessed}" ] || return $e

    local modulepath
    modulepath="${profiles[${profile}]}/${module}.sh"

    local script_in="${SIMBOL_UNIT_TESTS?}/${module}-static.sh"
    local script_out="${SIMBOL_USER_VAR_CACHE?}/unittest-${module}.sh"
    local csv_in="${SIMBOL_UNIT_TESTS?}/${module}-dynamic.csv"

    [ -e "${script_in}" ] || rm -f "${blessed}"
    [ -e "${script_out}" ] || rm -f "${blessed}"
    [ "${script_out}" -nt "${script_in}" ]  || rm -f "${blessed}"
    [ "${script_out}" -nt "${modulepath}" ] || rm -f "${blessed}"
    [ "${script_out}" -nt "${csv_in}" ] || rm -f "${blessed}"

    [ ! -e "${blessed}" ] || let e=CODE_SUCCESS

    return $e
}
#. }=-
#. ::unit:generate_header() -={
function ::unit:generate_header() {
    core:raise_bad_fn_call_unless $# in 2
    local profile="$1"
    local module="$2"

    local modulepath
    modulepath="${profiles[${profile}]}/${module}.sh"

    local -i e; let e=CODE_FAILURE

    local script_out=${SIMBOL_USER_VAR_CACHE?}/unittest-${module}.sh
    local modulecaps; modulecaps="$(::unit:modulecaps "${module}")"

    cat <<!SCRIPT > "${script_out}"
#!${SIMBOL_SHELL:-${SHELL}}
#. Shell     : ${SIMBOL_SHELL:-${SHELL}}
#. ScriptOut : ${script_out}
#. Profile   : ${profile}
#. Module    : ${module}
#. Generated : $(date)

SIMBOL_PROFILE="$("${HOME?}/.simbol/bin/activate")"

source "${SIMBOL_CORE_LIBSH?}/libsimbol/libsimbol.sh"

declare -g g_RUNTIME_PROFILE="${profile}"

declare -g g_RUNTIME_MODULE="${module}"
#. (aws.ec2)

declare -g g_RUNTIME_MODULECAPS="${modulecaps}"
#. (AwsEc2)

declare -g g_RUNTIME_MODULEPATH="${modulepath}"
#. (aws/ec2.sh)

declare -g g_RUNTIME_SCRIPT="${script_out}"

$(cat "${SIMBOL_UNIT?}/shunit2parent.sh")
!SCRIPT

    chmod +x "${script_out}"
}
#. }=-
#. ::unit:generate_body() -={
function ::unit:generate_body() {
    core:raise_bad_fn_call_unless $# in 2
    local profile="$1"
    local module="$2"

    cpfi "Generating tests..."

    local script_in=${SIMBOL_UNIT_TESTS?}/${module}-static.sh
    local script_out=${SIMBOL_USER_VAR_CACHE?}/unittest-${module}.sh

    local -i e; let e=CODE_FAILURE

    if [ -e "${script_in}" ]; then
        cat <<- !SCRIPT >> "${script_out}"
$(cat "${script_in}")
		!SCRIPT
        cpf "[%{@pass:FoundStatic}]"
        e=0
    else
        cpf "[%{@fail:MissingStatic}]"
    fi

    local csv_in="${SIMBOL_UNIT_TESTS?}/${module}-dynamic.csv"
    if [ ! -e "${csv_in}" ]; then
        cpf "[%{@fail:MissingDynamic}]"
    else
        if ! awk -F\| "BEGIN{b=0};NF==2&&\$1~/^#${profile}$/&&\$2~/^${module?}$/{b=1};END{exit(b)}" "${csv_in}"; then
            cpf "[%{@warn:Blacklisted}]"
            [ $e -ne 0 ] || e=1
        else
            cpf "[%{@pass:FoundDynamic}]"
            e=0
        fi
    fi
    cpf '...'
    theme HAS_AUTOED $e

    -=[

    e=0
    local -i t=0
    local -i p=0
    local -i s=0

    local -a fns
    local context
    local -i count
    for context in private internal public; do
        fns=( $(::unit:functions "${context}" "${module}" "${modulepath}") )
        let count=$(core:len fns)
        cpfi "%{m:${context}}:%{@module:${module}}:%{@int:${count}} functions\n"
        [ ${count} -gt 0 ] || continue

        -=[
        for fn in "${fns[@]}"; do

            local utf; utf="$(::unit:testFunction "${profile}" "${module}" "${fn}" "${context}")"

            local -i blacklisted=0
            local -a dynamic_tests=( )
            if [ -e "${csv_in}" ]; then
                dynamic_tests=( $(::unit:writeDynamicTestFunctions "${profile}" "${module}" "${fn}" "${context}") )
                blacklisted=$(
                    awk -F\| "BEGIN{b=0};NF==4&&\$1~/^#${profile}$/&&\$2~/^${module}$/&&\$3~/^${fn}$/&&\$4~/^${context}$/{b=1};END{print(b)}" "${csv_in}"
                )
            fi

            local -a static_tests=( $(::unit:staticTestFunctions "${profile}" "${module}" "${fn}" "${context}") )
            cpfi "%{@module:${module}}:%{@function:${fn}} %{c:static}:%{g:%d}/%{c:dynamic}:%{g:%d} %{@function:${utf}}..."\
                ${#static_tests[@]} ${#dynamic_tests[@]}

            case ${blacklisted}:${#static_tests[@]}:${#dynamic_tests[@]} in
                0:0:0)
                    theme HAS_FAILED "Undefined"
                    ((e++))
                ;;
                0:0:*)
                    theme HAS_PASSED "DynamicOnly"
                    ((p++))
                ;;
                0:*:0)
                    theme HAS_PASSED "StaticOnly"
                    ((p++))
                ;;
                0:*:*)
                    theme HAS_PASSED
                    ((p++))
                ;;
                1:*:*)
                    theme HAS_WARNED "Blacklisted"
                    ((s++))
                ;;
            esac

            ((t++))
        done
        ]=-
    done

    local utf; utf="$(::unit:testFunction "${profile}" "${module}")"
    cat <<!SCRIPT >> "${script_out}"
function ${utf}Coverage() {
    assertEquals "of the $t unit-tests, $p passed, $s skipped, and $e missing; i.e.," $((t-s)) $p
}
!SCRIPT

    ]=-

    return $e
}
#. }=-
#. ::unit:generate_footer() -={
function ::unit:generate_footer() {
    core:raise_bad_fn_call_unless $# in 2
    local profile="$1"
    local module="$2"

    local script_out="${SIMBOL_USER_VAR_CACHE?}/unittest-${module}.sh"

    cat <<!SCRIPT >> "${script_out}"
    source ${SHUNIT2?}
!SCRIPT
}
#. }=-
#. ::unit:generate_tests -={
function ::unit:generate_tests() {
    core:raise_bad_fn_call_unless $# in 2
    local profile="$1"
    local module="$2"

    local -i e; let e=CODE_SUCCESS

    cpfi "Verifying %{@profile:%s}.%{@module:%s} eligibility..."\
        "${profile}" "${module}"
    if core:softimport "${module}"; then
        theme HAS_PASSED
    else
        theme HAS_FAILED '[SOFT_IMPORT]'
        core:raise_on_failed_softimport "${module}"
    fi

    local -A profiles=(
        [core]="${SIMBOL_CORE_MOD?}"
        [user]="${SIMBOL_USER_MOD?}"
    )

    local modulepath

    -=[
        modulepath="${profiles[${profile}]}/${module}.sh"

        cpfi "Generating %{@profile:%s}.%{@module:%s}..."\
            "${profile}" "${module}"
        if [ -e "${modulepath}" ]; then
            if ! ::unit:blessed "${profile}" "${module}"; then
                ::unit:generate_header "${profile}" "${module}"

                echo
                -=[
                    ::unit:generate_body "${profile}" "${module}" || e=${CODE_FAILURE?}
                ]=-

                ::unit:generate_footer "${profile}" "${module}"
            else
                theme HAS_PASSED "AlreadyGenerated"
            fi
        else
            theme HAS_FAILED "MissingTests"
            let e=CODE_FAILURE
        fi
    ]=-

    return $e
}
#. }=-
#. ::unit:execute_tests -={
function ::unit:execute_tests() {
    core:raise_bad_fn_call_unless $# in 2

    cpfi "Executing tests for %{@profile:%s}.%{@module:%s}..."\
        "${profile}" "${module}"

    if ::unit:blessed "${profile}" "${module}"; then
        theme HAS_PASSED "AlreadyTested"
    else
        echo
        -=[
            "${SIMBOL_USER_VAR_CACHE?}/unittest-${module}.sh"
        ]=-
    fi

    return $?
}
#. }=-

#. unit:core -={
function unit:core() {
    local -i e; let e=CODE_SUCCESS

    g_MODE="core"
    local profile='core'
    local module='core'

    cpf "%{@comment:${profile}.${module}}.%{r:${g_MODE?} -=[}\n";
    script=${SIMBOL_UNIT_TESTS?}/core.sh
    local -i ee=-1
    if [ -r "${script}" ]; then
        (
            export g_RUNTIME_SCRIPT="${script}"
            #shellcheck disable=SC1090
            source "${script}"
            #shellcheck disable=SC1090
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
#. unit:test() -={
function unit:test:usage() { echo "core|user [<module> [<module> [...]]]"; }
function unit:test() {
    local -i e; let e=CODE_DEFAULT
    [ $# -ge 2 ] || return $e

    local profile="$1"
    [ "${profile}" == 'core' ] || [ "${profile}" == 'user' ] || return $e

    local module
    local -a modules=( $(core:modules "${@:2}") )

    if [ -e "${SHUNIT2?}" ]; then
        e=${CODE_SUCCESS?}
        for module in "${modules[@]}"; do
            ::unit:generate_tests "${profile}" "${module}"
            if ::unit:execute_tests "${profile}" "${module}"; then
                ::unit:bless "${profile}" "${module}"
            else
                ::unit:unbless "${profile}" "${module}"
                let e=CODE_FAILURE
            fi
        done

        cpf "Unit-test overall result..."
        theme HAS_AUTOED $e
    else
        theme ERR_USAGE "${SHUNIT2?} is missing"
        let e=CODE_FAILURE
    fi

    return $e
}
#. }=-
#. }=-
