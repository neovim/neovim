local helpers = require('test.functional.helpers')(after_each)

local NIL = helpers.NIL
local clear = helpers.clear
local command = helpers.command
local curbufmeths = helpers.curbufmeths
local eq = helpers.eq
local meths = helpers.meths
local bufmeths = helpers.bufmeths
local matches = helpers.matches
local source = helpers.source
local pcall_err = helpers.pcall_err
local exec_lua = helpers.exec_lua
local assert_alive = helpers.assert_alive
local feed = helpers.feed
local funcs = helpers.funcs

describe('nvim_get_commands', function()
  local cmd_dict  = { addr=NIL, bang=false, bar=false, complete=NIL, complete_arg=NIL, count=NIL, definition='echo "Hello World"', name='Hello', nargs='1', preview=false, range=NIL, register=false, keepscript=false, script_id=0, }
  local cmd_dict2 = { addr=NIL, bang=false, bar=false, complete=NIL, complete_arg=NIL, count=NIL, definition='pwd',                name='Pwd',   nargs='?', preview=false, range=NIL, register=false, keepscript=false, script_id=0, }
  before_each(clear)

  it('gets empty list if no commands were defined', function()
    eq({}, meths.get_commands({builtin=false}))
  end)

  it('validation', function()
    eq('builtin=true not implemented', pcall_err(meths.get_commands,
      {builtin=true}))
    eq("Invalid key: 'foo'", pcall_err(meths.get_commands,
      {foo='blah'}))
  end)

  it('gets global user-defined commands', function()
    -- Define a command.
    command('command -nargs=1 Hello echo "Hello World"')
    eq({Hello=cmd_dict}, meths.get_commands({builtin=false}))
    -- Define another command.
    command('command -nargs=? Pwd pwd');
    eq({Hello=cmd_dict, Pwd=cmd_dict2}, meths.get_commands({builtin=false}))
    -- Delete a command.
    command('delcommand Pwd')
    eq({Hello=cmd_dict}, meths.get_commands({builtin=false}))
  end)

  it('gets buffer-local user-defined commands', function()
    -- Define a buffer-local command.
    command('command -buffer -nargs=1 Hello echo "Hello World"')
    eq({Hello=cmd_dict}, curbufmeths.get_commands({builtin=false}))
    -- Define another buffer-local command.
    command('command -buffer -nargs=? Pwd pwd')
    eq({Hello=cmd_dict, Pwd=cmd_dict2}, curbufmeths.get_commands({builtin=false}))
    -- Delete a command.
    command('delcommand Pwd')
    eq({Hello=cmd_dict}, curbufmeths.get_commands({builtin=false}))

    -- {builtin=true} always returns empty for buffer-local case.
    eq({}, curbufmeths.get_commands({builtin=true}))
  end)

  it('gets various command attributes', function()
    local cmd0 = { addr='arguments', bang=false, bar=false, complete='dir',    complete_arg=NIL,         count='10', definition='pwd <args>',                    name='TestCmd', nargs='1', preview=false, range='10', register=false, keepscript=false, script_id=0, }
    local cmd1 = { addr=NIL,         bang=false, bar=false, complete='custom', complete_arg='ListUsers', count=NIL,  definition='!finger <args>',                name='Finger',  nargs='+', preview=false, range=NIL,  register=false, keepscript=false, script_id=1, }
    local cmd2 = { addr=NIL,         bang=true,  bar=false, complete=NIL,      complete_arg=NIL,         count=NIL,  definition='call \128\253R2_foo(<q-args>)', name='Cmd2',    nargs='*', preview=false, range=NIL,  register=false, keepscript=false, script_id=2, }
    local cmd3 = { addr=NIL,         bang=false, bar=true,  complete=NIL,      complete_arg=NIL,         count=NIL,  definition='call \128\253R3_ohyeah()',      name='Cmd3',    nargs='0', preview=false, range=NIL,  register=false, keepscript=false, script_id=3, }
    local cmd4 = { addr=NIL,         bang=false, bar=false, complete=NIL,      complete_arg=NIL,         count=NIL,  definition='call \128\253R4_just_great()',  name='Cmd4',    nargs='0', preview=false, range=NIL,  register=true,  keepscript=false, script_id=4, }
    source([[
      let s:foo = 1
      command -complete=custom,ListUsers -nargs=+ Finger !finger <args>
    ]])
    eq({Finger=cmd1}, meths.get_commands({builtin=false}))
    command('command -nargs=1 -complete=dir -addr=arguments -count=10 TestCmd pwd <args>')
    eq({Finger=cmd1, TestCmd=cmd0}, meths.get_commands({builtin=false}))

    source([[
      function! s:foo() abort
      endfunction
      command -bang -nargs=* Cmd2 call <SID>foo(<q-args>)
    ]])
    source([[
      function! s:ohyeah() abort
      endfunction
      command -bar -nargs=0 Cmd3 call <SID>ohyeah()
    ]])
    source([[
      function! s:just_great() abort
      endfunction
      command -register Cmd4 call <SID>just_great()
    ]])
    -- TODO(justinmk): Order is stable but undefined. Sort before return?
    eq({Cmd2=cmd2, Cmd3=cmd3, Cmd4=cmd4, Finger=cmd1, TestCmd=cmd0}, meths.get_commands({builtin=false}))
  end)
end)

describe('nvim_create_user_command', function()
  before_each(clear)

  it('works with strings', function()
    meths.create_user_command('SomeCommand', 'let g:command_fired = <args>', {nargs = 1})
    meths.command('SomeCommand 42')
    eq(42, meths.eval('g:command_fired'))
  end)

  it('works with Lua functions', function()
    exec_lua [[
      result = {}
      vim.api.nvim_create_user_command('CommandWithLuaCallback', function(opts)
        result = opts
      end, {
        nargs = "*",
        bang = true,
        count = 2,
      })
    ]]

    eq({
      name = "CommandWithLuaCallback",
      args = [[this\  is    a\ test]],
      fargs = {"this ", "is", "a test"},
      bang = false,
      line1 = 1,
      line2 = 1,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 0,
      count = 2,
      reg = "",
    }, exec_lua [=[
      vim.api.nvim_command([[CommandWithLuaCallback this\  is    a\ test]])
      return result
    ]=])

    eq({
      name = "CommandWithLuaCallback",
      args = [[this   includes\ a backslash: \\]],
      fargs = {"this", "includes a", "backslash:", "\\"},
      bang = false,
      line1 = 1,
      line2 = 1,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 0,
      count = 2,
      reg = "",
    }, exec_lua [=[
      vim.api.nvim_command([[CommandWithLuaCallback this   includes\ a backslash: \\]])
      return result
    ]=])

    eq({
      name = "CommandWithLuaCallback",
      args = "a\\b",
      fargs = {"a\\b"},
      bang = false,
      line1 = 1,
      line2 = 1,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 0,
      count = 2,
      reg = "",
    }, exec_lua [=[
      vim.api.nvim_command('CommandWithLuaCallback a\\b')
      return result
    ]=])

    eq({
      name = "CommandWithLuaCallback",
      args = 'h\tey ',
      fargs = {[[h]], [[ey]]},
      bang = true,
      line1 = 10,
      line2 = 10,
      mods = "confirm unsilent botright horizontal",
      smods = {
        browse = false,
        confirm = true,
        emsg_silent = false,
        hide = false,
        horizontal = true,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "botright",
        tab = -1,
        unsilent = true,
        verbose = -1,
        vertical = false,
      },
      range = 1,
      count = 10,
      reg = "",
    }, exec_lua [=[
      vim.api.nvim_command('unsilent horizontal botright confirm 10CommandWithLuaCallback! h\tey ')
      return result
    ]=])

    eq({
      name = "CommandWithLuaCallback",
      args = "h",
      fargs = {"h"},
      bang = false,
      line1 = 1,
      line2 = 42,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 1,
      count = 42,
      reg = "",
    }, exec_lua [[
      vim.api.nvim_command('CommandWithLuaCallback 42 h')
      return result
    ]])

    eq({
      name = "CommandWithLuaCallback",
      args = "",
      fargs = {},  -- fargs works without args
      bang = false,
      line1 = 1,
      line2 = 1,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 0,
      count = 2,
      reg = "",
    }, exec_lua [[
      vim.api.nvim_command('CommandWithLuaCallback')
      return result
    ]])

    -- f-args doesn't split when command nargs is 1 or "?"
    exec_lua [[
      result = {}
      vim.api.nvim_create_user_command('CommandWithOneOrNoArg', function(opts)
        result = opts
      end, {
        nargs = "?",
        bang = true,
        count = 2,
      })
    ]]

    eq({
      name = "CommandWithOneOrNoArg",
      args = "hello I'm one argument",
      fargs = {"hello I'm one argument"},  -- Doesn't split args
      bang = false,
      line1 = 1,
      line2 = 1,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 0,
      count = 2,
      reg = "",
    }, exec_lua [[
      vim.api.nvim_command('CommandWithOneOrNoArg hello I\'m one argument')
      return result
    ]])

    -- f-args is an empty table if no args were passed
    eq({
      name = "CommandWithOneOrNoArg",
      args = "",
      fargs = {},
      bang = false,
      line1 = 1,
      line2 = 1,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 0,
      count = 2,
      reg = "",
    }, exec_lua [[
      vim.api.nvim_command('CommandWithOneOrNoArg')
      return result
    ]])

    -- f-args is an empty table when the command nargs=0
    exec_lua [[
      result = {}
      vim.api.nvim_create_user_command('CommandWithNoArgs', function(opts)
        result = opts
      end, {
        nargs = 0,
        bang = true,
        count = 2,
        register = true,
      })
    ]]
    eq({
      name = "CommandWithNoArgs",
      args = "",
      fargs = {},
      bang = false,
      line1 = 1,
      line2 = 1,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 0,
      count = 2,
      reg = "",
    }, exec_lua [[
      vim.cmd('CommandWithNoArgs')
      return result
    ]])
    -- register can be specified
    eq({
      name = "CommandWithNoArgs",
      args = "",
      fargs = {},
      bang = false,
      line1 = 1,
      line2 = 1,
      mods = "",
      smods = {
        browse = false,
        confirm = false,
        emsg_silent = false,
        hide = false,
        horizontal = false,
        keepalt = false,
        keepjumps = false,
        keepmarks = false,
        keeppatterns = false,
        lockmarks = false,
        noautocmd = false,
        noswapfile = false,
        sandbox = false,
        silent = false,
        split = "",
        tab = -1,
        unsilent = false,
        verbose = -1,
        vertical = false,
      },
      range = 0,
      count = 2,
      reg = "+",
    }, exec_lua [[
      vim.cmd('CommandWithNoArgs +')
      return result
    ]])

  end)

  it('can define buffer-local commands', function()
    local bufnr = meths.create_buf(false, false)
    bufmeths.create_user_command(bufnr, "Hello", "", {})
    matches("Not an editor command: Hello", pcall_err(meths.command, "Hello"))
    meths.set_current_buf(bufnr)
    meths.command("Hello")
    assert_alive()
  end)

  it('can use a Lua complete function', function()
    exec_lua [[
      vim.api.nvim_create_user_command('Test', '', {
        nargs = "*",
        complete = function(arg, cmdline, pos)
          local options = {"aaa", "bbb", "ccc"}
          local t = {}
          for _, v in ipairs(options) do
            if string.find(v, "^" .. arg) then
              table.insert(t, v)
            end
          end
          return t
        end,
      })
    ]]

    feed(':Test a<Tab>')
    eq('Test aaa', funcs.getcmdline())
    feed('<C-U>Test b<Tab>')
    eq('Test bbb', funcs.getcmdline())
  end)

  it('does not allow invalid command names', function()
    eq("Invalid command name (must start with uppercase): 'test'", pcall_err(exec_lua, [[
      vim.api.nvim_create_user_command('test', 'echo "hi"', {})
    ]]))
    eq("Invalid command name: 't@'", pcall_err(exec_lua, [[
      vim.api.nvim_create_user_command('t@', 'echo "hi"', {})
    ]]))
    eq("Invalid command name: 'T@st'", pcall_err(exec_lua, [[
      vim.api.nvim_create_user_command('T@st', 'echo "hi"', {})
    ]]))
    eq("Invalid command name: 'Test!'", pcall_err(exec_lua, [[
      vim.api.nvim_create_user_command('Test!', 'echo "hi"', {})
    ]]))
    eq("Invalid command name: '💩'", pcall_err(exec_lua, [[
      vim.api.nvim_create_user_command('💩', 'echo "hi"', {})
    ]]))
  end)

  it('smods can be used with nvim_cmd', function()
    exec_lua[[
      vim.api.nvim_create_user_command('MyEcho', function(opts)
        vim.api.nvim_cmd({ cmd = 'echo', args = { '&verbose' }, mods = opts.smods }, {})
      end, {})
    ]]
    eq("3", meths.cmd({ cmd = 'MyEcho', mods = { verbose = 3 } }, { output = true }))

    eq(1, #meths.list_tabpages())
    exec_lua[[
      vim.api.nvim_create_user_command('MySplit', function(opts)
        vim.api.nvim_cmd({ cmd = 'split', mods = opts.smods }, {})
      end, {})
    ]]
    meths.cmd({ cmd = 'MySplit' }, {})
    eq(1, #meths.list_tabpages())
    eq(2, #meths.list_wins())
    meths.cmd({ cmd = 'MySplit', mods = { tab = 1 } }, {})
    eq(2, #meths.list_tabpages())
    eq(2, funcs.tabpagenr())
    meths.cmd({ cmd = 'MySplit', mods = { tab = 1 } }, {})
    eq(3, #meths.list_tabpages())
    eq(2, funcs.tabpagenr())
    meths.cmd({ cmd = 'MySplit', mods = { tab = 3 } }, {})
    eq(4, #meths.list_tabpages())
    eq(4, funcs.tabpagenr())
    meths.cmd({ cmd = 'MySplit', mods = { tab = 0 } }, {})
    eq(5, #meths.list_tabpages())
    eq(1, funcs.tabpagenr())
  end)
end)

describe('nvim_del_user_command', function()
  before_each(clear)

  it('can delete global commands', function()
    meths.create_user_command('Hello', 'echo "Hi"', {})
    meths.command('Hello')
    meths.del_user_command('Hello')
    matches("Not an editor command: Hello", pcall_err(meths.command, "Hello"))
  end)

  it('can delete buffer-local commands', function()
    bufmeths.create_user_command(0, 'Hello', 'echo "Hi"', {})
    meths.command('Hello')
    bufmeths.del_user_command(0, 'Hello')
    matches("Not an editor command: Hello", pcall_err(meths.command, "Hello"))
  end)
end)
