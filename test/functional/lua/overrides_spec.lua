-- Test for Vim overrides of lua built-ins
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local NIL = helpers.NIL
local feed = helpers.feed
local clear = helpers.clear
local funcs = helpers.funcs
local meths = helpers.meths
local iswin = helpers.iswin
local command = helpers.command
local write_file = helpers.write_file
local exec_capture = helpers.exec_capture
local exec_lua = helpers.exec_lua
local pcall_err = helpers.pcall_err

local screen

local fname = 'Xtest-functional-lua-overrides-luafile'

before_each(clear)

after_each(function()
  os.remove(fname)
end)

describe('print', function()
  it('returns nothing', function()
    eq(NIL, funcs.luaeval('print("abc")'))
    eq(0, funcs.luaeval('select("#", print("abc"))'))
  end)
  it('allows catching printed text with :execute', function()
    eq('\nabc', funcs.execute('lua print("abc")'))
    eq('\nabc', funcs.execute('luado print("abc")'))
    eq('\nabc', funcs.execute('call luaeval("print(\'abc\')")'))
    write_file(fname, 'print("abc")')
    eq('\nabc', funcs.execute('luafile ' .. fname))

    eq('abc', exec_capture('lua print("abc")'))
    eq('abc', exec_capture('luado print("abc")'))
    eq('abc', exec_capture('call luaeval("print(\'abc\')")'))
    write_file(fname, 'print("abc")')
    eq('abc', exec_capture('luafile ' .. fname))
  end)
  it('handles errors in __tostring', function()
    write_file(fname, [[
      local meta_nilerr = { __tostring = function() error(nil) end }
      local meta_abcerr = { __tostring = function() error("abc") end }
      local meta_tblout = { __tostring = function() return {"TEST"} end }
      v_nilerr = setmetatable({}, meta_nilerr)
      v_abcerr = setmetatable({}, meta_abcerr)
      v_tblout = setmetatable({}, meta_tblout)
    ]])
    eq('', exec_capture('luafile ' .. fname))
    -- TODO(bfredl): these look weird, print() should not use "E5114:" style errors..
    eq('Vim(lua):E5108: Error executing lua E5114: Error while converting print argument #2: [NULL]',
       pcall_err(command, 'lua print("foo", v_nilerr, "bar")'))
    eq('Vim(lua):E5108: Error executing lua E5114: Error while converting print argument #2: Xtest-functional-lua-overrides-luafile:0: abc',
       pcall_err(command, 'lua print("foo", v_abcerr, "bar")'))
    eq('Vim(lua):E5108: Error executing lua E5114: Error while converting print argument #2: <Unknown error: lua_tolstring returned NULL for tostring result>',
       pcall_err(command, 'lua print("foo", v_tblout, "bar")'))
  end)
  it('prints strings with NULs and NLs correctly', function()
    meths.set_option('more', true)
    eq('abc ^@ def\nghi^@^@^@jkl\nTEST\n\n\nT\n',
       exec_capture([[lua print("abc \0 def\nghi\0\0\0jkl\nTEST\n\n\nT\n")]]))
    eq('abc ^@ def\nghi^@^@^@jkl\nTEST\n\n\nT^@',
       exec_capture([[lua print("abc \0 def\nghi\0\0\0jkl\nTEST\n\n\nT\0")]]))
    eq('T^@', exec_capture([[lua print("T\0")]]))
    eq('T\n', exec_capture([[lua print("T\n")]]))
  end)
  it('prints empty strings correctly', function()
    -- Regression: first test used to crash
    eq('', exec_capture('lua print("")'))
    eq(' def', exec_capture('lua print("", "def")'))
    eq('abc ', exec_capture('lua print("abc", "")'))
    eq('abc  def', exec_capture('lua print("abc", "", "def")'))
  end)
  it('defers printing in luv event handlers', function()
    exec_lua([[
      local cmd = ...
      function test()
        local timer = vim.loop.new_timer()
        local done = false
        timer:start(10, 0, function()
          print("very fast")
          timer:close()
          done = true
        end)
        -- be kind to slow travis OS X jobs:
        -- loop until we know for sure the callback has been executed
        while not done do
          os.execute(cmd)
          vim.loop.run("nowait") -- fake os_breakcheck()
        end
        print("very slow")
        vim.api.nvim_command("sleep 1m") -- force deferred event processing
      end
    ]], (iswin() and "timeout 1") or "sleep 0.1")
    eq('very slow\nvery fast', exec_capture('lua test()'))
  end)
end)

describe('debug.debug', function()
  before_each(function()
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=255},
      E = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      cr = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
    command("set display-=msgsep")
  end)
  it('works', function()
    command([[lua
      function Test(a)
        print(a)
        debug.debug()
        print(a * 100)
      end
    ]])
    feed(':lua Test()\n')
    screen:expect([[
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      nil                                                  |
      lua_debug> ^                                          |
    ]])
    feed('print("TEST")\n')
    screen:expect([[
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      nil                                                  |
      lua_debug> print("TEST")                             |
      TEST                                                 |
      lua_debug> ^                                          |
    ]])
    feed('<C-c>')
    screen:expect{grid=[[
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      nil                                                  |
      lua_debug> print("TEST")                             |
      TEST                                                 |
                                                           |
      {E:E5108: Error executing lua [string ":lua"]:5: attempt}|
      {E: to perform arithmetic on local 'a' (a nil value)}    |
      Interrupt: {cr:Press ENTER or type command to continue}^   |
    ]]}
    feed('<C-l>:lua Test()\n')
    screen:expect([[
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      nil                                                  |
      lua_debug> ^                                          |
    ]])
    feed('\n')
    screen:expect{grid=[[
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      nil                                                  |
      lua_debug>                                           |
      {E:E5108: Error executing lua [string ":lua"]:5: attempt}|
      {E: to perform arithmetic on local 'a' (a nil value)}    |
      {cr:Press ENTER or type command to continue}^              |
    ]]}
  end)

  it("can be safely exited with 'cont'", function()
    feed('<cr>')
    feed(':lua debug.debug() print("x")<cr>')
    screen:expect{grid=[[
                                                           |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      lua_debug> ^                                          |
    ]]}

    feed("conttt<cr>") -- misspelled cont; invalid syntax
    screen:expect{grid=[[
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      lua_debug> conttt                                    |
      {E:E5115: Error while loading debug string: (debug comma}|
      {E:nd):1: '=' expected near '<eof>'}                     |
      lua_debug> ^                                          |
    ]]}

    feed("cont<cr>") -- exactly "cont", exit now
    screen:expect{grid=[[
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      lua_debug> conttt                                    |
      {E:E5115: Error while loading debug string: (debug comma}|
      {E:nd):1: '=' expected near '<eof>'}                     |
      lua_debug> cont                                      |
      x                                                    |
      {cr:Press ENTER or type command to continue}^              |
    ]]}

    feed('<cr>')
    screen:expect{grid=[[
      ^                                                     |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]]}
  end)
end)

describe('os.getenv', function()
  it('returns nothing for undefined env var', function()
    eq(NIL, funcs.luaeval('os.getenv("XTEST_1")'))
  end)
  it('returns env var set by the parent process', function()
    local value = 'foo'
    clear({env = {['XTEST_1']=value}})
    eq(value, funcs.luaeval('os.getenv("XTEST_1")'))
  end)
  it('returns env var set by let', function()
    local value = 'foo'
    meths.command('let $XTEST_1 = "'..value..'"')
    eq(value, funcs.luaeval('os.getenv("XTEST_1")'))
  end)
end)
