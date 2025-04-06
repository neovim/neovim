-- Test for Vim overrides of lua built-ins
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local NIL = vim.NIL
local feed = n.feed
local clear = n.clear
local fn = n.fn
local api = n.api
local command = n.command
local write_file = t.write_file
local exec_capture = n.exec_capture
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err
local is_os = t.is_os

local fname = 'Xtest-functional-lua-overrides-luafile'

before_each(clear)

after_each(function()
  os.remove(fname)
end)

describe('print', function()
  it('returns nothing', function()
    eq(NIL, fn.luaeval('print("abc")'))
    eq(0, fn.luaeval('select("#", print("abc"))'))
  end)
  it('allows catching printed text with :execute', function()
    eq('\nabc', fn.execute('lua print("abc")'))
    eq('\nabc', fn.execute('luado print("abc")'))
    eq('\nabc', fn.execute('call luaeval("print(\'abc\')")'))
    write_file(fname, 'print("abc")')
    eq('\nabc', fn.execute('luafile ' .. fname))

    eq('abc', exec_capture('lua print("abc")'))
    eq('abc', exec_capture('luado print("abc")'))
    eq('abc', exec_capture('call luaeval("print(\'abc\')")'))
    write_file(fname, 'print("abc")')
    eq('abc', exec_capture('luafile ' .. fname))
  end)
  it('handles errors in __tostring', function()
    write_file(
      fname,
      [[
      local meta_nilerr = { __tostring = function() error(nil) end }
      local meta_abcerr = { __tostring = function() error("abc") end }
      local meta_tblout = { __tostring = function() return {"TEST"} end }
      v_nilerr = setmetatable({}, meta_nilerr)
      v_abcerr = setmetatable({}, meta_abcerr)
      v_tblout = setmetatable({}, meta_tblout)
    ]]
    )
    eq('', exec_capture('luafile ' .. fname))
    -- TODO(bfredl): these look weird, print() should not use "E5114:" style errors..
    eq(
      'Vim(lua):E5108: Error executing lua E5114: Error while converting print argument #2: [NULL]',
      pcall_err(command, 'lua print("foo", v_nilerr, "bar")')
    )
    eq(
      'Vim(lua):E5108: Error executing lua E5114: Error while converting print argument #2: Xtest-functional-lua-overrides-luafile:2: abc',
      pcall_err(command, 'lua print("foo", v_abcerr, "bar")')
    )
    eq(
      'Vim(lua):E5108: Error executing lua E5114: Error while converting print argument #2: <Unknown error: lua_tolstring returned NULL for tostring result>',
      pcall_err(command, 'lua print("foo", v_tblout, "bar")')
    )
  end)
  it('coerces error values into strings', function()
    write_file(
      fname,
      [[
    function string_error() error("my mistake") end
    function number_error() error(1234) end
    function nil_error() error(nil) end
    function table_error() error({message = "my mistake"}) end
    function custom_error()
      local err = {message = "my mistake", code = 11234}
      setmetatable(err, {
        __tostring = function(t)
          return "Internal Error [" .. t.code .. "] " .. t.message
        end
      })
      error(err)
    end
    function bad_custom_error()
      local err = {message = "my mistake", code = 11234}
      setmetatable(err, {
        -- intentionally not a function, downstream programmer has made an mistake
        __tostring = "Internal Error [" .. err.code .. "] " .. err.message
      })
      error(err)
    end
    ]]
    )
    eq('', exec_capture('luafile ' .. fname))
    eq(
      'Vim(lua):E5108: Error executing lua Xtest-functional-lua-overrides-luafile:1: my mistake',
      pcall_err(command, 'lua string_error()')
    )
    eq(
      'Vim(lua):E5108: Error executing lua Xtest-functional-lua-overrides-luafile:2: 1234',
      pcall_err(command, 'lua number_error()')
    )
    eq('Vim(lua):E5108: Error executing lua [NULL]', pcall_err(command, 'lua nil_error()'))
    eq('Vim(lua):E5108: Error executing lua [NULL]', pcall_err(command, 'lua table_error()'))
    eq(
      'Vim(lua):E5108: Error executing lua Internal Error [11234] my mistake',
      pcall_err(command, 'lua custom_error()')
    )
    eq('Vim(lua):E5108: Error executing lua [NULL]', pcall_err(command, 'lua bad_custom_error()'))
  end)
  it('prints strings with NULs and NLs correctly', function()
    api.nvim_set_option_value('more', true, {})
    eq(
      'abc ^@ def\nghi^@^@^@jkl\nTEST\n\n\nT\n',
      exec_capture([[lua print("abc \0 def\nghi\0\0\0jkl\nTEST\n\n\nT\n")]])
    )
    eq(
      'abc ^@ def\nghi^@^@^@jkl\nTEST\n\n\nT^@',
      exec_capture([[lua print("abc \0 def\nghi\0\0\0jkl\nTEST\n\n\nT\0")]])
    )
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
    exec_lua(function(cmd)
      function test()
        local timer = vim.uv.new_timer()
        local done = false
        timer:start(10, 0, function()
          print('very fast')
          timer:close()
          done = true
        end)
        -- be kind to slow travis OS X jobs:
        -- loop until we know for sure the callback has been executed
        while not done do
          os.execute(cmd)
          vim.uv.run('nowait') -- fake os_breakcheck()
        end
        print('very slow')
        vim.api.nvim_command('sleep 1m') -- force deferred event processing
      end
    end, (is_os('win') and 'timeout 1') or 'sleep 0.1')
    eq('very slow\nvery fast', exec_capture('lua test()'))
  end)

  it('blank line in message works', function()
    local screen = Screen.new(40, 8)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { bold = true, foreground = Screen.colors.SeaGreen },
      [2] = { bold = true, reverse = true },
    })
    feed([[:lua print('\na')<CR>]])
    screen:expect {
      grid = [[
                                              |
      {0:~                                       }|*3
      {2:                                        }|
                                              |
      a                                       |
      {1:Press ENTER or type command to continue}^ |
    ]],
    }
    feed('<CR>')
    feed([[:lua print('b\n\nc')<CR>]])
    screen:expect {
      grid = [[
                                              |
      {0:~                                       }|*2
      {2:                                        }|
      b                                       |
                                              |
      c                                       |
      {1:Press ENTER or type command to continue}^ |
    ]],
    }
  end)
end)

describe('debug.debug', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    screen = Screen.new()
    screen:set_default_attr_ids {
      [0] = { bold = true, foreground = 255 },
      [1] = { bold = true, reverse = true },
      E = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      cr = { bold = true, foreground = Screen.colors.SeaGreen4 },
    }
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
    screen:expect {
      grid = [[
                                                           |
      {0:~                                                    }|*10
      {1:                                                     }|
      nil                                                  |
      lua_debug> ^                                          |
    ]],
    }
    feed('print("TEST")\n')
    screen:expect([[
                                                           |
      {0:~                                                    }|*8
      {1:                                                     }|
      nil                                                  |
      lua_debug> print("TEST")                             |
      TEST                                                 |
      lua_debug> ^                                          |
    ]])
    feed('<C-c>')
    screen:expect {
      grid = [[
                                                           |
      {0:~                                                    }|*2
      {1:                                                     }|
      nil                                                  |
      lua_debug> print("TEST")                             |
      TEST                                                 |
                                                           |
      {E:E5108: Error executing lua [string ":lua"]:5: attempt}|
      {E: to perform arithmetic on local 'a' (a nil value)}    |
      {E:stack traceback:}                                     |
      {E:        [string ":lua"]:5: in function 'Test'}        |
      {E:        [string ":lua"]:1: in main chunk}             |
      Interrupt: {cr:Press ENTER or type command to continue}^   |
    ]],
    }
    feed('<C-l>:lua Test()\n')
    screen:expect([[
                                                           |
      {0:~                                                    }|*10
      {1:                                                     }|
      nil                                                  |
      lua_debug> ^                                          |
    ]])
    feed('\n')
    screen:expect {
      grid = [[
                                                           |
      {0:~                                                    }|*4
      {1:                                                     }|
      nil                                                  |
      lua_debug>                                           |
      {E:E5108: Error executing lua [string ":lua"]:5: attempt}|
      {E: to perform arithmetic on local 'a' (a nil value)}    |
      {E:stack traceback:}                                     |
      {E:        [string ":lua"]:5: in function 'Test'}        |
      {E:        [string ":lua"]:1: in main chunk}             |
      {cr:Press ENTER or type command to continue}^              |
    ]],
    }
  end)

  it("can be safely exited with 'cont'", function()
    feed('<cr>')
    feed(':lua debug.debug() print("x")<cr>')
    screen:expect {
      grid = [[
                                                           |
      {0:~                                                    }|*12
      lua_debug> ^                                          |
    ]],
    }

    feed('conttt<cr>') -- misspelled cont; invalid syntax
    screen:expect {
      grid = [[
                                                           |
      {0:~                                                    }|*8
      {1:                                                     }|
      lua_debug> conttt                                    |
      {E:E5115: Error while loading debug string: (debug comma}|
      {E:nd):1: '=' expected near '<eof>'}                     |
      lua_debug> ^                                          |
    ]],
    }

    feed('cont<cr>') -- exactly "cont", exit now
    screen:expect {
      grid = [[
                                                           |
      {0:~                                                    }|*6
      {1:                                                     }|
      lua_debug> conttt                                    |
      {E:E5115: Error while loading debug string: (debug comma}|
      {E:nd):1: '=' expected near '<eof>'}                     |
      lua_debug> cont                                      |
      x                                                    |
      {cr:Press ENTER or type command to continue}^              |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                                                     |
      {0:~                                                    }|*12
                                                           |
    ]],
    }
  end)
end)

describe('os.getenv', function()
  it('returns nothing for undefined env var', function()
    eq(NIL, fn.luaeval('os.getenv("XTEST_1")'))
  end)
  it('returns env var set by the parent process', function()
    local value = 'foo'
    clear({ env = { ['XTEST_1'] = value } })
    eq(value, fn.luaeval('os.getenv("XTEST_1")'))
  end)
  it('returns env var set by let', function()
    local value = 'foo'
    command('let $XTEST_1 = "' .. value .. '"')
    eq(value, fn.luaeval('os.getenv("XTEST_1")'))
  end)
end)

-- "bit" module is always available, regardless if nvim is built with
-- luajit or PUC lua 5.1.
describe('bit module', function()
  it('works', function()
    eq(9, exec_lua [[ return require'bit'.band(11,13) ]])
  end)
end)
