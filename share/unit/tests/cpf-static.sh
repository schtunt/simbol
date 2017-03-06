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
    data="$(cpf "Hello World!")"
    assertTrue 'cpf.cpf/1.1' $?
    assertEquals "${data}" "Hello World!"
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
    : noop
}

function testCoreCpfIndentPublic() {
    CPF_INDENT=0
    -=[
    assertEquals 'cpf:indent/1.1' 1 ${CPF_INDENT}
    -=[
    -=[
    -=[
    assertEquals 'cpf:indent/1.2' 4 ${CPF_INDENT}
    ]=-
    ]=-
    assertEquals 'cpf:indent/1.3' 2 ${CPF_INDENT}
}
