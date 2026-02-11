local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local feed = n.feed
local write_file = t.write_file

before_each(clear)

describe('debugger', function()
  local screen

  before_each(function()
    screen = Screen.new(999, 7)
  end)

  -- oldtest: Test_Debugger_breakadd_expr()
  -- This doesn't seem to work as documented. The breakpoint is not
  -- triggered until the next function call.
  it(':breakadd expr', function()
    write_file(
      'XbreakExpr.vim',
      [[
      func Foo()
        eval 1
        eval 2
      endfunc

      let g:Xtest_var += 1
      call Foo()
      let g:Xtest_var += 1
      call Foo()]]
    )
    finally(function()
      os.remove('XbreakExpr.vim')
    end)

    command('edit XbreakExpr.vim')
    command(':let g:Xtest_var = 10')
    command(':breakadd expr g:Xtest_var')
    local initial_screen = [[
      ^func Foo(){MATCH: *}|
        eval 1{MATCH: *}|
        eval 2{MATCH: *}|
      endfunc{MATCH: *}|
      {MATCH: *}|
      let g:Xtest_var += 1{MATCH: *}|
      {MATCH: *}|
    ]]
    screen:expect(initial_screen)

    feed(':source %<CR>')
    screen:expect([[
      Breakpoint in "Foo" line 1{MATCH: *}|
      Entering Debug mode.  Type "cont" to continue.{MATCH: *}|
      Oldval = "10"{MATCH: *}|
      Newval = "11"{MATCH: *}|
      {MATCH:.*}XbreakExpr.vim[7]..function Foo{MATCH: *}|
      line 1: eval 1{MATCH: *}|
      >^{MATCH: *}|
    ]])
    feed('cont<CR>')
    screen:expect([[
      >cont{MATCH: *}|
      Breakpoint in "Foo" line 1{MATCH: *}|
      Oldval = "11"{MATCH: *}|
      Newval = "12"{MATCH: *}|
      {MATCH:.*}XbreakExpr.vim[9]..function Foo{MATCH: *}|
      line 1: eval 1{MATCH: *}|
      >^{MATCH: *}|
    ]])
    feed('cont<CR>')
    screen:expect(initial_screen)

    -- Check the behavior without the g: prefix.
    -- The Oldval and Newval don't look right here.
    command(':breakdel *')
    command(':breakadd expr Xtest_var')
    feed(':source %<CR>')
    screen:expect([[
      Breakpoint in "Foo" line 1{MATCH: *}|
      Entering Debug mode.  Type "cont" to continue.{MATCH: *}|
      Oldval = "13"{MATCH: *}|
      Newval = "(does not exist)"{MATCH: *}|
      {MATCH:.*}XbreakExpr.vim[7]..function Foo{MATCH: *}|
      line 1: eval 1{MATCH: *}|
      >^{MATCH: *}|
    ]])
    feed('cont<CR>')
    screen:expect([[
      {MATCH:.*}XbreakExpr.vim[7]..function Foo{MATCH: *}|
      line 1: eval 1{MATCH: *}|
      >cont{MATCH: *}|
      Breakpoint in "Foo" line 2{MATCH: *}|
      {MATCH:.*}XbreakExpr.vim[7]..function Foo{MATCH: *}|
      line 2: eval 2{MATCH: *}|
      >^{MATCH: *}|
    ]])
    feed('cont<CR>')
    screen:expect([[
      >cont{MATCH: *}|
      Breakpoint in "Foo" line 1{MATCH: *}|
      Oldval = "14"{MATCH: *}|
      Newval = "(does not exist)"{MATCH: *}|
      {MATCH:.*}XbreakExpr.vim[9]..function Foo{MATCH: *}|
      line 1: eval 1{MATCH: *}|
      >^{MATCH: *}|
    ]])
    feed('cont<CR>')
    screen:expect([[
      {MATCH:.*}XbreakExpr.vim[9]..function Foo{MATCH: *}|
      line 1: eval 1{MATCH: *}|
      >cont{MATCH: *}|
      Breakpoint in "Foo" line 2{MATCH: *}|
      {MATCH:.*}XbreakExpr.vim[9]..function Foo{MATCH: *}|
      line 2: eval 2{MATCH: *}|
      >^{MATCH: *}|
    ]])
    feed('cont<CR>')
    screen:expect(initial_screen)
  end)
end)
