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
    data=$(cpf "Hello world")
    assertTrue 1.1 $?
    assertEquals "${data}" "Hello world"
}

function testCoreCpfModule_is_modifiedPrivate() {
    local data
    #data=$(::cpf:module_is_modified core cpf)
    #assertFalse 1.1 $?
    data=$(::cpf:module_is_modified core dns)
    assertTrue 1.2 $?
}

function testCoreCpfModule_has_alertsPrivate() {
    local data
    data=$(::cpf:module_has_alerts core remote)
    assertTrue 1.1 $?
    data=$(::cpf:module_has_alerts core dns)
    assertFalse 1.2 $?
    data=$(::cpf:module_has_alerts foo dns)
    assertEquals 1 $?
    data=$(::cpf:module_has_alerts core foo)
    assertEquals 1 $?
}

function testCoreCpfModulePrivate() {
    : noop
}

function testCoreCpfFunction_has_alertsPrivate() {
    local data
    data=$(::cpf:function_has_alerts core remote cluster)
    assertTrue 1.1 $?
    data=$(::cpf:function_has_alerts core dns resolve)
    assertFalse 1.2 $?
    data=$(::cpf:function_has_alerts core remote clusterfoo)
    assertEquals 1 $?
    data=$(::cpf:function_has_alerts core foo cluster)
    assertEquals 1 $?
    data=$(::cpf:function_has_alerts foo remote cluster)
    assertEquals 1 $?
}

function testCoreCpfFunctionPrivate() {
    : noop
}

function testCoreCpfIs_fmtPrivate() {
    ::cpf:is_fmt '%s'
    assertTrue 1.1 $?
    ::cpf:is_fmt '%%s'
    assertTrue 1.2 $?
    ::cpf:is_fmt '%'
    assertFalse 1.3 $?
    ::cpf:is_fmt '%{%ss}'
    assertTrue 1.4 $?
    ::cpf:is_fmt '%{%ss}%'
    assertTrue 1.5 $?
}

function testCoreCpfThemePrivate() {
    : noop
}

function testCoreCpfIndentPublic() {
    CPF_INDENT=0
    -=[
    assertEquals 1 ${CPF_INDENT}
    -=[
    -=[
    -=[
    assertEquals 4 ${CPF_INDENT}
    ]=-
    ]=-
    assertEquals 2 ${CPF_INDENT}
}
