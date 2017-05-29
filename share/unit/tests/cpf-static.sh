# vim: tw=0:ts=4:sw=4:et:ft=bash
core:import cpf

#. CPF -={
function cpfOneTimeSetUp() {
    declare -g g_PLAYGROUND="/tmp/cpf-pg"
    rm -rf ${g_PLAYGROUND?}
}

function cpfSetUp() {
    : pass
}

function cpfTearDown() {
    : pass
}

function cpfOneTimeTearDown() {
    rm -rf ${g_PLAYGROUND?}
}

#. testCoreCpfInitializePublic -={
function testCoreCpfInitializePublic() {
    cpf:initialize 1
    assertTrue "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreCpfPrintfPublic -={
function testCoreCpfPrintfPublic() {
    local -a tester=(
        '.%{d:dbg}.'
        '.%{d:%%}.'
        '.%%{d:%%}.'
        '.%%{+d}.'
        '.%%{-d}.'
        '.%%{d:dbg}.'
        '.%{d:dbg}.'
        '.%{+d}dbg%{-d}.'
        '.%{+d}%s%{-d}.|dbg'
        '.%{d:@%s@}.|dbg'
        '+%{d:-%s:}!|dbg'
        '~%{+d}&%s&%{-d}~|dbg'
        '.%{@dbg:debug}.'
    )

    local -a expect=(
        '.<d>dbg</d>.'
        '.<d>%</d>.'
        '.%{d:%}.'
        '.%{+d}.'
        '.%{-d}.'
        '.%{d:dbg}.'
        '.<d>dbg</d>.'
        '.<d>dbg</d>.'
        '.<d>dbg</d>.'
        '.<d>@dbg@</d>.'
        '+<d>-dbg:</d>!'
        '~<d>&dbg&</d>~'
        '.<d><D>debug</D></d>.'
    )

    local expc
    local rslt
    local tstr

    mock:write <<!
SIMBOL_ESCAPE_SEQUENCES+=(
    [+d]="<d>"  [-d]="</d>"
)
SIMBOL_OUTPUT_THEME+=(
    [dbg]="%{d:<D>%s</D>}"
)
!

    for ((i=0; i<${#tester[@]}; i++)); do
        expc="${expect[$i]}"
        IFS='|' read -ra tstr <<< "${tester[$i]}"

        rslt="$(mock:wrapper cpf printf "${tstr[@]}")"
        assertTrue "${FUNCNAME?}/$i.1" $?
        assertEquals "${FUNCNAME?}/$i.2" "${expc}" "${rslt}"
    done

    mock:clear
}
#. }=-
#. testCoreCpfModule_is_modifiedPrivate -={
function testCoreCpfModule_is_modifiedPrivate() {
    ::cpf:module_is_modified "$(core:module_path remote)" remote
    assertFalse "${FUNCNAME?}/1" $?
}
#. }=-
#. testCoreCpfModule_has_alertsPrivate -={
function testCoreCpfModule_has_alertsPrivate() {
    local data

    data=$(::cpf:module_has_alerts "$(core:module_path remote)" remote)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" "" "${data}"

    data=$(::cpf:module_has_alerts  "$(core:module_path git)" git)
    assertFalse "${FUNCNAME?}/2.1" $?
    assertEquals "${FUNCNAME?}/2.2" "" "${data}"
}
#. }=-
#. testCoreCpfModulePrivate -={
function testCoreCpfModulePrivate() {
    : noop
}
#. }=-
#. testCoreCpfFunction_has_alertsPrivate -={
function testCoreCpfFunction_has_alertsPrivate() {
    local data

    data="$(::cpf:function_has_alerts "$(core:module_path remote)" remote cluster)"
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" "" "${data}"

    data="$(::cpf:function_has_alerts "$(core:module_path hgd)" hgd refresh)"
    assertFalse "${FUNCNAME?}/2.1" $?
    assertEquals "${FUNCNAME?}/2.2" "" "${data}"

    data="$(::cpf:function_has_alerts "$(core:module_path remote)" remote clusterfoo)"
    assertFalse "${FUNCNAME?}/3.1" $?
    assertEquals "${FUNCNAME?}/3.2" "" "${data}"
}
#. }=-
#. testCoreCpfFunctionPrivate -={
function testCoreCpfFunctionPrivate() {
    : noop
}
#. }=-
#. testCoreCpfIs_fmtPrivate -={
function testCoreCpfIs_fmtPrivate() {
    ::cpf:is_fmt '%s'
    assertTrue "${FUNCNAME?}/1.1" $?

    ::cpf:is_fmt '%%s'
    assertTrue "${FUNCNAME?}/2" $?

    ::cpf:is_fmt '%'
    assertFalse "${FUNCNAME?}/3" $?

    ::cpf:is_fmt '%{%ss}'
    assertTrue "${FUNCNAME?}/4" $?

    ::cpf:is_fmt '%{%ss}%'
    assertTrue "${FUNCNAME?}/5" $?
}
#. }=-
#. testCoreCpfThemePrivate -={
function testCoreCpfThemePrivate() {
    local out
    out=$(::cpf:theme "@host" "%s")
    assertTrue "${FUNCNAME?}/1" $?
    assertEquals "${FUNCNAME?}/2" "${out}" "@ %{y:%s} %s"
    assertEquals "${FUNCNAME?}/3" "$(::cpf:theme "@netgroup" "%s")" "+ %{c:%s} %s"
}
#. }=-
#. testCoreCpfIndentPublic -={
function testCoreCpfIndentPublic() {
    local -i cpf_indent
    let cpf_indent=${CPF_INDENT}
    CPF_INDENT=0

    local out
    out=$(cpfi foo)
    assertTrue "${FUNCNAME?}/1.1" $?
    assertEquals "${FUNCNAME?}/1.2" "${out}" "foo"
    -=[
    assertEquals "${FUNCNAME?}/2" 1 ${CPF_INDENT}
    out=$(cpfi foo)
    assertEquals "${FUNCNAME?}/3" "${out}" \
        "$(printf\
            "%$((CPF_INDENT * USER_CPF_INDENT_SIZE + ${#USER_CPF_INDENT_STR}))s"\
            "${USER_CPF_INDENT_STR}")foo"
    -=[
    assertEquals "${FUNCNAME?}/4" 2 ${CPF_INDENT}
    -=[
    assertEquals "${FUNCNAME?}/5" 3 ${CPF_INDENT}
    -=[
    assertEquals "${FUNCNAME?}/6" 4 ${CPF_INDENT}
    ]=-
    assertEquals "${FUNCNAME?}/7" 3 ${CPF_INDENT}
    ]=-
    assertEquals "${FUNCNAME?}/8" 2 ${CPF_INDENT}
    ]=-
    assertEquals "${FUNCNAME?}/9" 1 ${CPF_INDENT}
    ]=-
    assertEquals "${FUNCNAME?}/A" 0 ${CPF_INDENT}

    let CPF_INDENT=${cpf_indent}
}
#. }=-
#. }=-
