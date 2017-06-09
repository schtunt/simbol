# vim: tw=0:ts=4:sw=4:et:ft=bash

#. Scaffolding -={
function moduleScaffold() {
    local -i e=0

    #. awsEc2SetUp/awsEc2TearDown
    local cl="${1^}"
    #shellcheck disable=SC2154
    local modulefn="${g_RUNTIME_MODULECAPS,}${cl}"

    local -i verbose
    case $1 in
        setUp|tearDown) let verbose=FALSE ;;
        oneTimeSetUp|oneTimeTearDown) let verbose=TRUE ;;
    esac

    (( verbose == FALSE )) || cpfi "%{@comment:%s...}" "${modulefn}"

    if [ -f "${g_RUNTIME_SCRIPT?}" ]; then
        if [ "$(type -t "${modulefn}" 2>/dev/null)" == "function" ]; then
            ${modulefn}
            let e=$?
            (( verbose != TRUE )) || theme HAS_AUTOED $e
        else
            (( verbose != TRUE )) || theme HAS_WARNED "UNDEFINED:${modulefn}"
        fi
    else
        (( verbose != TRUE )) || theme HAS_PASSED "DYNAMIC_ONLY"
    fi

    return $e
}

function oneTimeSetUp() {
    -=[

    cpfi "%{@comment:unitSetUp...}"
    local -i e; let e=CODE_SUCCESS

    declare -gi tid=0

    declare -g oD="${SHUNIT_TMPDIR?}"
    mkdir -p "${oD}"

    #shellcheck disable=SC2034
    declare -gr stdoutF="${oD}/stdout"

    #shellcheck disable=SC2034
    declare -gr stderrF="${oD}/stderr"

    theme HAS_PASSED

    moduleScaffold oneTimeSetUp
    e=$?

    -=[

    return $e
}

function oneTimeTearDown() {
    local -i e; let e=CODE_SUCCESS

    ]=-

    moduleScaffold oneTimeTearDown
    e=$?

    cpfi "%{@comment:unitTearDown...}"
    rm -rf "${oD?}"
    theme HAS_PASSED

    ]=-

    return $e
}

function setUp() {
    cpf:initialize 1
    moduleScaffold setUp

    : ${tid?}
    ((tid++))
    tidstr=$(printf "%03d" ${tid})
    cpfi "%{@comment:Test} %{y:#%s} " "${tidstr}"
}

function tearDown() {
    moduleScaffold tearDown
}
#. }=-
