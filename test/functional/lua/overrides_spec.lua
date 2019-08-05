-- Test for Vim overrides of lua built-ins
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local neq = helpers.neq
local NIL = helpers.NIL
local feed = helpers.feed
local clear = helpers.clear
local funcs = helpers.funcs
local meths = helpers.meths
local iswin = helpers.iswin
local command = helpers.command
local write_file = helpers.write_file
local redir_exec = helpers.redir_exec
local alter_slashes = helpers.alter_slashes
local exec_lua = helpers.exec_lua

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
    eq('\nE5105: Error while calling lua chunk: E5114: Error while converting print argument #2: [NULL]',
       redir_exec('lua print("foo", v_nilerr, "bar")'))
    eq('\nE5105: Error while calling lua chunk: E5114: Error while converting print argument #2: Xtest-functional-lua-overrides-luafile:2: abc',
       redir_exec('lua print("foo", v_abcerr, "bar")'))
    eq('\nE5105: Error while calling lua chunk: E5114: Error while converting print argument #2: <Unknown error: lua_tolstring returned NULL for tostring result>',
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
  it('prints empty strings correctly', function()
    -- Regression: first test used to crash
    eq('', redir_exec('lua print("")'))
    eq('\n def', redir_exec('lua print("", "def")'))
    eq('\nabc ', redir_exec('lua print("abc", "")'))
    eq('\nabc  def', redir_exec('lua print("abc", "", "def")'))
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
    eq('\nvery slow\nvery fast',redir_exec('lua test()'))
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

describe('package.path/package.cpath', function()
  local sl = alter_slashes

  local function get_new_paths(sufs, runtimepaths)
    runtimepaths = runtimepaths or meths.list_runtime_paths()
    local new_paths = {}
    local sep = package.config:sub(1, 1)
    for _, v in ipairs(runtimepaths) do
      for _, suf in ipairs(sufs) do
        new_paths[#new_paths + 1] = v .. sep .. 'lua' .. suf
      end
    end
    return new_paths
  end
  local function execute_lua(cmd, ...)
    return meths.execute_lua(cmd, {...})
  end
  local function eval_lua(expr, ...)
    return meths.execute_lua('return ' .. expr, {...})
  end
  local function set_path(which, value)
    return execute_lua('package[select(1, ...)] = select(2, ...)', which, value)
  end

  it('contains directories from &runtimepath on first invocation', function()
    local new_paths = get_new_paths(sl{'/?.lua', '/?/init.lua'})
    local new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str, eval_lua('package.path'):sub(1, #new_paths_str))

    local new_cpaths = get_new_paths(iswin() and {'\\?.dll'} or {'/?.so'})
    local new_cpaths_str = table.concat(new_cpaths, ';')
    eq(new_cpaths_str, eval_lua('package.cpath'):sub(1, #new_cpaths_str))
  end)
  it('puts directories from &runtimepath always at the start', function()
    meths.set_option('runtimepath', 'a,b')
    local new_paths = get_new_paths(sl{'/?.lua', '/?/init.lua'}, {'a', 'b'})
    local new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str, eval_lua('package.path'):sub(1, #new_paths_str))

    set_path('path', sl'foo/?.lua;foo/?/init.lua;' .. new_paths_str)

    neq(new_paths_str, eval_lua('package.path'):sub(1, #new_paths_str))

    command('set runtimepath+=c')
    new_paths = get_new_paths(sl{'/?.lua', '/?/init.lua'}, {'a', 'b', 'c'})
    new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str, eval_lua('package.path'):sub(1, #new_paths_str))
  end)
  it('understands uncommon suffixes', function()
    set_path('cpath', './?/foo/bar/baz/x.nlua')
    meths.set_option('runtimepath', 'a')
    local new_paths = get_new_paths({'/?/foo/bar/baz/x.nlua'}, {'a'})
    local new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str, eval_lua('package.cpath'):sub(1, #new_paths_str))

    set_path('cpath', './yyy?zzz/x')
    meths.set_option('runtimepath', 'b')
    new_paths = get_new_paths({'/yyy?zzz/x'}, {'b'})
    new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str, eval_lua('package.cpath'):sub(1, #new_paths_str))

    set_path('cpath', './yyy?zzz/123?ghi/x')
    meths.set_option('runtimepath', 'b')
    new_paths = get_new_paths({'/yyy?zzz/123?ghi/x'}, {'b'})
    new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str, eval_lua('package.cpath'):sub(1, #new_paths_str))
  end)
  it('preserves empty items', function()
    local many_empty_path = ';;;;;;'
    local many_empty_cpath = ';;;;;;./?.luaso'
    set_path('path', many_empty_path)
    set_path('cpath', many_empty_cpath)
    meths.set_option('runtimepath', 'a')
    local new_paths = get_new_paths(sl{'/?.lua', '/?/init.lua'}, {'a'})
    local new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str .. ';' .. many_empty_path, eval_lua('package.path'))
    local new_cpaths = get_new_paths({'/?.luaso'}, {'a'})
    local new_cpaths_str = table.concat(new_cpaths, ';')
    eq(new_cpaths_str .. ';' .. many_empty_cpath, eval_lua('package.cpath'))
  end)
  it('preserves empty value', function()
    set_path('path', '')
    meths.set_option('runtimepath', 'a')
    local new_paths = get_new_paths(sl{'/?.lua', '/?/init.lua'}, {'a'})
    local new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str .. ';', eval_lua('package.path'))
  end)
  it('purges out all additions if runtimepath is set to empty', function()
    local new_paths = get_new_paths(sl{'/?.lua', '/?/init.lua'})
    local new_paths_str = table.concat(new_paths, ';')
    local path = eval_lua('package.path')
    eq(new_paths_str, path:sub(1, #new_paths_str))

    local new_cpaths = get_new_paths(iswin() and {'\\?.dll'} or {'/?.so'})
    local new_cpaths_str = table.concat(new_cpaths, ';')
    local cpath = eval_lua('package.cpath')
    eq(new_cpaths_str, cpath:sub(1, #new_cpaths_str))

    meths.set_option('runtimepath', '')
    eq(path:sub(#new_paths_str + 2, -1), eval_lua('package.path'))
    eq(cpath:sub(#new_cpaths_str + 2, -1), eval_lua('package.cpath'))
  end)
  it('works with paths with escaped commas', function()
    meths.set_option('runtimepath', '\\,')
    local new_paths = get_new_paths(sl{'/?.lua', '/?/init.lua'}, {','})
    local new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str, eval_lua('package.path'):sub(1, #new_paths_str))
  end)
  it('ignores paths with semicolons', function()
    meths.set_option('runtimepath', 'foo;bar,\\,')
    local new_paths = get_new_paths(sl{'/?.lua', '/?/init.lua'}, {','})
    local new_paths_str = table.concat(new_paths, ';')
    eq(new_paths_str, eval_lua('package.path'):sub(1, #new_paths_str))
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
