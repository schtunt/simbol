# vim: tw=0:ts=4:sw=4:et:ft=bash

function cpfSetUp() {
    declare -g g_PLAYGROUND="/tmp/cpf-pg"
}

function cpfTearDown() {
    #rm -rf ${g_PLAYGROUND?}
    : noop
}

function testCoreCpfPublic() {
    local data
    data="$(cpf "Hello World")"
    assertTrue 'cpf.cpf/1.1' $?
    assertEquals "${data}" "Hello World"
    if [ ${SIMBOL_IN_COLOR} -eq 1 ]; then
        assertEquals "$(cpf "%{ul:%s}" "Hello World")" "$(echo -e "\E[4mHello World\E[24m")"
    else
        assertEquals "$(cpf "%{ul:%s}" "Hello World")" "$(echo -e "Hello World")"
    fi
    #data="$(cpf "%s" "foo" "bar" 2> /dev/null )"
    #assertFalse 'cpf.cpf/1.2' $?
}

function testCoreCpfModule_is_modifiedPrivate() {
    ::cpf:module_is_modified $(core:module_path dns) dns
    assertFalse '::cpf:is_modified/1.1' $?
}

function testCoreCpfModule_has_alertsPrivate() {
    local data

    data=$(::cpf:module_has_alerts $(core:module_path remote) remote)
    assertTrue '::cpf:has_alerts/1.1' $?

    data=$(::cpf:module_has_alerts  $(core:module_path dns) dns)
    assertFalse '::cpf:has_alerts/1.2' $?
}

function testCoreCpfModulePrivate() {
    : noop
}

function testCoreCpfFunction_has_alertsPrivate() {
    local data

    data="$(::cpf:function_has_alerts $(core:module_path remote) remote cluster)"
    assertTrue '::cpf:function_has_alerts/1.1' $?

    data="$(::cpf:function_has_alerts $(core:module_path dns) dns resolve)"
    assertFalse '::cpf:function_has_alerts/1.2' $?

    data="$(::cpf:function_has_alerts $(core:module_path remote) remote clusterfoo)"
    assertFalse '::cpf:function_has_alerts/1.3' $?
}

function testCoreCpfFunctionPrivate() {
    : noop
}

function testCoreCpfIs_fmtPrivate() {
    ::cpf:is_fmt '%s'
    assertTrue '::cpf:is_fmt/1.1' $?

    ::cpf:is_fmt '%%s'
    assertTrue '::cpf:is_fmt/1.2' $?

    ::cpf:is_fmt '%'
    assertFalse '::cpf:is_fmt/1.3' $?

    ::cpf:is_fmt '%{%ss}'
    assertTrue '::cpf:is_fmt/1.4' $?

    ::cpf:is_fmt '%{%ss}%'
    assertTrue '::cpf:is_fmt/1.5' $?
}

function testCoreCpfThemePrivate() {
    local out
    out=$(::cpf:theme "@host" "%s")
    assertTrue '::cpf:theme/1.1' $?
    assertEquals '::cpf:theme/1.2' "${out}" "@ %{y:%s} %s"
    assertEquals '::cpf:theme/1.3' "$(::cpf:theme "@netgroup" "%s")" "+ %{c:%s} %s"
}

function testCoreCpfIndentPublic() {
    local out
    CPF_INDENT=0
    out=$(cpfi foo)
    assertTrue 'cpf:indent/1.1' $?
    assertEquals 'cpf:indent/1.1' "${out}" "foo"
    -=[
    assertEquals 'cpf:indent/1.2' 1 ${CPF_INDENT}
    out=$(cpfi foo)
    assertEquals 'cpf:indent/1.2' "${out}" "$(printf "%$((CPF_INDENT * USER_CPF_INDENT_SIZE))s" "${USER_CPF_INDENT_STR}")foo"
    -=[
    -=[
    -=[
    assertEquals 'cpf:indent/1.3' 4 ${CPF_INDENT}
    ]=-
    ]=-
    assertEquals 'cpf:indent/1.4' 2 ${CPF_INDENT}
}
