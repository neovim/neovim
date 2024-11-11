-- Tests for core Vimscript "eval" behavior.
--
-- See also:
--    let_spec.lua
--    null_spec.lua
--    operators_spec.lua
--
-- Tests for the Vimscript |builtin-functions| library should live in:
--    test/functional/vimscript/<funcname>_spec.lua
--    test/functional/vimscript/functions_spec.lua

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local mkdir = t.mkdir
local clear = n.clear
local eq = t.eq
local exec = n.exec
local exc_exec = n.exc_exec
local exec_lua = n.exec_lua
local exec_capture = n.exec_capture
local eval = n.eval
local command = n.command
local write_file = t.write_file
local api = n.api
local sleep = vim.uv.sleep
local matches = t.matches
local pcall_err = t.pcall_err
local assert_alive = n.assert_alive
local poke_eventloop = n.poke_eventloop
local feed = n.feed
local expect_exit = n.expect_exit

describe('Up to MAX_FUNC_ARGS arguments are handled by', function()
  local max_func_args = 20 -- from eval.h
  local range = n.fn.range

  before_each(clear)

  it('printf()', function()
    local printf = n.fn.printf
    local rep = n.fn['repeat']
    local expected = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,'
    eq(expected, printf(rep('%d,', max_func_args - 1), unpack(range(2, max_func_args))))
    local ret = exc_exec('call printf("", 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)')
    eq('Vim(call):E740: Too many arguments for function printf', ret)
  end)

  it('rpcnotify()', function()
    local rpcnotify = n.fn.rpcnotify
    local ret = rpcnotify(0, 'foo', unpack(range(3, max_func_args)))
    eq(1, ret)
    ret = exc_exec('call rpcnotify(0, "foo", 3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)')
    eq('Vim(call):E740: Too many arguments for function rpcnotify', ret)
  end)
end)

describe('backtick expansion', function()
  setup(function()
    clear()
    mkdir('test-backticks')
    write_file('test-backticks/file1', 'test file 1')
    write_file('test-backticks/file2', 'test file 2')
    write_file('test-backticks/file3', 'test file 3')
    mkdir('test-backticks/subdir')
    write_file('test-backticks/subdir/file4', 'test file 4')
    -- Long path might cause "Press ENTER" prompt; use :silent to avoid it.
    command('silent cd test-backticks')
  end)

  teardown(function()
    n.rmdir('test-backticks')
  end)

  it("with default 'shell'", function()
    if t.is_os('win') then
      command(':silent args `dir /b *2`')
    else
      command(':silent args `echo ***2`')
    end
    eq({ 'file2' }, eval('argv()'))
    if t.is_os('win') then
      command(':silent args `dir /s/b *4`')
      eq({ 'subdir\\file4' }, eval('map(argv(), \'fnamemodify(v:val, ":.")\')'))
    else
      command(':silent args `echo */*4`')
      eq({ 'subdir/file4' }, eval('argv()'))
    end
  end)

  it('with shell=fish', function()
    if eval("executable('fish')") == 0 then
      pending('missing "fish" command')
      return
    end
    command('set shell=fish')
    command(':silent args `echo ***2`')
    eq({ 'file2' }, eval('argv()'))
    command(':silent args `echo */*4`')
    eq({ 'subdir/file4' }, eval('argv()'))
  end)
end)

describe('List support code', function()
  local dur
  local min_dur = 8
  local len = 131072

  if not pending('does not actually allows interrupting with just got_int', function() end) then
    return
  end
  -- The following tests are confirmed to work with os_breakcheck() just before
  -- `if (got_int) {break;}` in tv_list_copy and list_join_inner() and not to
  -- work without.
  setup(function()
    clear()
    dur = 0
    while true do
      command(([[
        let rt = reltime()
        let bl = range(%u)
        let dur = reltimestr(reltime(rt))
      ]]):format(len))
      dur = tonumber(api.nvim_get_var('dur'))
      if dur >= min_dur then
        -- print(('Using len %u, dur %g'):format(len, dur))
        break
      else
        len = len * 2
      end
    end
  end)
  it('allows interrupting copy', function()
    feed(':let t_rt = reltime()<CR>:let t_bl = copy(bl)<CR>')
    sleep(min_dur / 16 * 1000)
    feed('<C-c>')
    poke_eventloop()
    command('let t_dur = reltimestr(reltime(t_rt))')
    local t_dur = tonumber(api.nvim_get_var('t_dur'))
    if t_dur >= dur / 8 then
      eq(nil, ('Took too long to cancel: %g >= %g'):format(t_dur, dur / 8))
    end
  end)
  it('allows interrupting join', function()
    feed(':let t_rt = reltime()<CR>:let t_j = join(bl)<CR>')
    sleep(min_dur / 16 * 1000)
    feed('<C-c>')
    poke_eventloop()
    command('let t_dur = reltimestr(reltime(t_rt))')
    local t_dur = tonumber(api.nvim_get_var('t_dur'))
    print(('t_dur: %g'):format(t_dur))
    if t_dur >= dur / 8 then
      eq(nil, ('Took too long to cancel: %g >= %g'):format(t_dur, dur / 8))
    end
  end)
end)

describe('uncaught exception', function()
  before_each(clear)

  it('is not forgotten #13490', function()
    command('autocmd BufWinEnter * throw "i am error"')
    eq('i am error', exc_exec('try | new | endtry'))

    -- Like Vim, throwing here aborts the processing of the script, but does not stop :runtime!
    -- from processing the others.
    -- Only the first thrown exception should be rethrown from the :try below, though.
    for i = 1, 3 do
      write_file(
        'throw' .. i .. '.vim',
        ([[
        let result ..= '%d'
        throw 'throw%d'
        let result ..= 'X'
      ]]):format(i, i)
      )
    end
    finally(function()
      for i = 1, 3 do
        os.remove('throw' .. i .. '.vim')
      end
    end)

    command('set runtimepath+=. | let result = ""')
    eq('throw1', exc_exec('try | runtime! throw*.vim | endtry'))
    eq('123', eval('result'))
  end)

  it('multiline exception remains multiline #25350', function()
    local screen = Screen.new(80, 11)
    exec_lua([[
      function _G.Oops()
        error("oops")
      end
    ]])
    feed(':try\rlua _G.Oops()\rendtry\r')
    screen:expect {
      grid = [[
      {3:                                                                                }|
      :try                                                                            |
      :  lua _G.Oops()                                                                |
      :  endtry                                                                       |
      {9:Error detected while processing :}                                               |
      {9:E5108: Error executing lua [string "<nvim>"]:2: oops}                            |
      {9:stack traceback:}                                                                |
      {9:        [C]: in function 'error'}                                                |
      {9:        [string "<nvim>"]:2: in function 'Oops'}                                 |
      {9:        [string ":lua"]:1: in main chunk}                                        |
      {6:Press ENTER or type command to continue}^                                         |
    ]],
    }
  end)
end)

describe('listing functions using :function', function()
  before_each(clear)

  it('works for lambda functions with <lambda> #20466', function()
    command('let A = {-> 1}')
    local num = exec_capture('echo A'):match("function%('<lambda>(%d+)'%)")
    eq(
      ([[
   function <lambda>%s(...)
1  return 1
   endfunction]]):format(num),
      exec_capture(('function <lambda>%s'):format(num))
    )
  end)

  it('does not crash if another function is deleted while listing', function()
    local _ = Screen.new(80, 24)
    matches(
      'Vim%(function%):E454: Function list was modified$',
      pcall_err(
        exec_lua,
        [=[
      vim.cmd([[
        func Func1()
        endfunc
        func Func2()
        endfunc
        func Func3()
        endfunc
      ]])

      local ns = vim.api.nvim_create_namespace('test')

      vim.ui_attach(ns, { ext_messages = true }, function(event, _, content)
        if event == 'msg_show' and content[1][2] == 'function Func1()'  then
          vim.cmd('delfunc Func3')
        end
      end)

      vim.cmd('function')

      vim.ui_detach(ns)
    ]=]
      )
    )
    assert_alive()
  end)

  it('does not crash if the same function is deleted while listing', function()
    local _ = Screen.new(80, 24)
    matches(
      'Vim%(function%):E454: Function list was modified$',
      pcall_err(
        exec_lua,
        [=[
      vim.cmd([[
        func Func1()
        endfunc
        func Func2()
        endfunc
        func Func3()
        endfunc
      ]])

      local ns = vim.api.nvim_create_namespace('test')

      vim.ui_attach(ns, { ext_messages = true }, function(event, _, content)
        if event == 'msg_show' and content[1][2] == 'function Func1()'  then
          vim.cmd('delfunc Func2')
        end
      end)

      vim.cmd('function')

      vim.ui_detach(ns)
    ]=]
      )
    )
    assert_alive()
  end)
end)

it('no double-free in garbage collection #16287', function()
  clear()
  -- Don't use exec() here as using a named script reproduces the issue better.
  write_file(
    'Xgarbagecollect.vim',
    [[
    func Foo() abort
      let s:args = [a:000]
      let foo0 = ""
      let foo1 = ""
      let foo2 = ""
      let foo3 = ""
      let foo4 = ""
      let foo5 = ""
      let foo6 = ""
      let foo7 = ""
      let foo8 = ""
      let foo9 = ""
      let foo10 = ""
      let foo11 = ""
      let foo12 = ""
      let foo13 = ""
      let foo14 = ""
    endfunc

    set updatetime=1
    call Foo()
    call Foo()
  ]]
  )
  finally(function()
    os.remove('Xgarbagecollect.vim')
  end)
  command('source Xgarbagecollect.vim')
  sleep(10)
  assert_alive()
end)

it('no heap-use-after-free with EXITFREE and partial as prompt callback', function()
  clear()
  exec([[
    func PromptCallback(text)
    endfunc
    setlocal buftype=prompt
    call prompt_setcallback('', funcref('PromptCallback'))
  ]])
  expect_exit(command, 'qall!')
end)
