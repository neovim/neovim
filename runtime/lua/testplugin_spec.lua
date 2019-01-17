local helpers = require('test.functional.helpers')(after_each)
local eq, ok = helpers.eq, helpers.ok
local buffer, command, eval, nvim, next_msg = helpers.buffer,
  helpers.command, helpers.eval, helpers.nvim, helpers.next_msg
local feed = helpers.feed
local expect_err = helpers.expect_err
local write_file = helpers.write_file
local curbufmeths = helpers.curbufmeths
local exe_lua = helpers.meths.execute_lua

describe("API: map", function()
  before_each(function()
    helpers.clear()
    command("source $VIMRUNTIME/plugin/testplugin.vim")
  end)

  it("testplugin", function()
    command("StartTestPlugin")
    
    nvim('input', "<F2>")
    local lines = curbufmeths.get_lines(0, 1, true)

    eq({'Testplugin'}, lines)
  end)

  it("test plugin 2", function()
    command("e tmp")
    command("StartTestPlugin")
    command("sp tmp2")
    command("b tmp")

    feed("<F2>")
    feed("<Esc>")
    feed("oa<Esc>")
    feed("<lt>")
    local lines = curbufmeths.get_lines(0, 2, true)
    eq({'Testplugin2', 'Testplugin'}, lines)

    command("b tmp2")
    feed("<F2>")
    feed("<Esc>")
    feed("ia<Esc>")
    feed("<lt>")
    local lines = curbufmeths.get_lines(0, 2, true)
    eq({'Testplugin', 'a'}, lines)

  end)

  it("Mapping errors", function ()
    local err = exe_lua('local e,m=require("testplugin").maperr1() return {e,m}', {})
    eq(false, err[1])
    assert(err[2]:match("not allowed in function map"))

    local err = exe_lua('local e,m=require("testplugin").maperr2() return {e,m}', {})
    eq(false, err[1])
    assert(err[2]:match("'keys' mandatory string"))
  end)

  it("Unmapping", function()
    command("StartTestPlugin")
    feed("<F2>")
    local lines = curbufmeths.get_lines(0, 1, true)
    eq({'Testplugin'}, lines)

    exe_lua('require("testplugin").clear_f2()', {})
    feed("<F2>")
    local lines = curbufmeths.get_lines(0, 2, true)
    eq({'Testplugin', ''}, lines)

    assert(exe_lua('local r = require("testplugin").clear_f3() return r == nil', {}))
  end)

end)
