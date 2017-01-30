-- Test for Vim overrides of lua built-ins
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local NIL = helpers.NIL
local feed = helpers.feed
local clear = helpers.clear
local funcs = helpers.funcs
local meths = helpers.meths
local command = helpers.command
local write_file = helpers.write_file
local redir_exec = helpers.redir_exec

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

    eq('\nabc', redir_exec('lua print("abc")'))
    eq('\nabc', redir_exec('luado print("abc")'))
    eq('\nabc', redir_exec('call luaeval("print(\'abc\')")'))
    write_file(fname, 'print("abc")')
    eq('\nabc', redir_exec('luafile ' .. fname))
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
    eq('', redir_exec('luafile ' .. fname))
    eq('\nE5114: Error while converting print argument #2: [NULL]',
       redir_exec('lua print("foo", v_nilerr, "bar")'))
    eq('\nE5114: Error while converting print argument #2: Xtest-functional-lua-overrides-luafile:2: abc',
       redir_exec('lua print("foo", v_abcerr, "bar")'))
    eq('\nE5114: Error while converting print argument #2: <Unknown error: lua_tolstring returned NULL for tostring result>',
       redir_exec('lua print("foo", v_tblout, "bar")'))
  end)
  it('prints strings with NULs and NLs correctly', function()
    meths.set_option('more', true)
    eq('\nabc ^@ def\nghi^@^@^@jkl\nTEST\n\n\nT\n',
       redir_exec([[lua print("abc \0 def\nghi\0\0\0jkl\nTEST\n\n\nT\n")]]))
    eq('\nabc ^@ def\nghi^@^@^@jkl\nTEST\n\n\nT^@',
       redir_exec([[lua print("abc \0 def\nghi\0\0\0jkl\nTEST\n\n\nT\0")]]))
    eq('\nT^@', redir_exec([[lua print("T\0")]]))
    eq('\nT\n', redir_exec([[lua print("T\n")]]))
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
    screen:expect([[
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
      {E:E5105: Error while calling lua chunk: [string "<VimL }|
      {E:compiled string>"]:5: attempt to perform arithmetic o}|
      {E:n local 'a' (a nil value)}                            |
      Interrupt: {cr:Press ENTER or type command to continue}^   |
    ]])
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
    screen:expect([[
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
      {E:E5105: Error while calling lua chunk: [string "<VimL }|
      {E:compiled string>"]:5: attempt to perform arithmetic o}|
      {E:n local 'a' (a nil value)}                            |
      {cr:Press ENTER or type command to continue}^              |
    ]])
  end)
end)
