local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local command = t.command
local feed = t.feed
local write_file = t.write_file

before_each(clear)

describe('debugger', function()
  local screen

  before_each(function()
    screen = Screen.new(999, 10)
    screen:attach()
  end)

  -- oldtest: Test_Debugger_breakadd_expr()
  it(':breakadd expr', function()
    write_file('XdebugBreakExpr.vim', 'let g:Xtest_var += 1')
    finally(function()
      os.remove('XdebugBreakExpr.vim')
    end)

    command('edit XdebugBreakExpr.vim')
    command(':let g:Xtest_var = 10')
    command(':breakadd expr g:Xtest_var')
    feed(':source %<CR>')
    screen:expect {
      grid = [[
      ^let g:Xtest_var += 1{MATCH: *}|
      {1:~{MATCH: *}}|*8
      :source %{MATCH: *}|
    ]],
    }
    feed(':source %<CR>')
    screen:expect {
      grid = [[
      let g:Xtest_var += 1{MATCH: *}|
      {1:~{MATCH: *}}|
      {3:{MATCH: *}}|
      Breakpoint in "{MATCH:.*}XdebugBreakExpr.vim" line 1{MATCH: *}|
      Entering Debug mode.  Type "cont" to continue.{MATCH: *}|
      Oldval = "10"{MATCH: *}|
      Newval = "11"{MATCH: *}|
      {MATCH:.*}XdebugBreakExpr.vim{MATCH: *}|
      line 1: let g:Xtest_var += 1{MATCH: *}|
      >^{MATCH: *}|
    ]],
    }
    feed('cont<CR>')
    screen:expect {
      grid = [[
      ^let g:Xtest_var += 1{MATCH: *}|
      {1:~{MATCH: *}}|*8
      {MATCH: *}|
    ]],
    }
    feed(':source %<CR>')
    screen:expect {
      grid = [[
      let g:Xtest_var += 1{MATCH: *}|
      {1:~{MATCH: *}}|
      {3:{MATCH: *}}|
      Breakpoint in "{MATCH:.*}XdebugBreakExpr.vim" line 1{MATCH: *}|
      Entering Debug mode.  Type "cont" to continue.{MATCH: *}|
      Oldval = "11"{MATCH: *}|
      Newval = "12"{MATCH: *}|
      {MATCH:.*}XdebugBreakExpr.vim{MATCH: *}|
      line 1: let g:Xtest_var += 1{MATCH: *}|
      >^{MATCH: *}|
    ]],
    }
  end)
end)
