local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local meths = helpers.meths
local poke_eventloop = helpers.poke_eventloop
local read_file = helpers.read_file
local source = helpers.source
local eq = helpers.eq
local write_file = helpers.write_file

local function sizeoflong()
  if not exec_lua('return pcall(require, "ffi")') then
    pending('missing LuaJIT FFI')
  end
  return exec_lua('return require("ffi").sizeof(require("ffi").typeof("long"))')
end

describe('Ex command', function()
  before_each(clear)
  after_each(function() eq({}, meths.get_vvar('errors')) end)

  it('checks for address line overflow', function()
    if sizeoflong() < 8 then
      pending('Skipped: only works with 64 bit long ints')
    end

    source [[
      new
      call setline(1, 'text')
      call assert_fails('|.44444444444444444444444', 'E1247:')
      call assert_fails('|.9223372036854775806', 'E1247:')
      bwipe!
    ]]
  end)
end)

it(':confirm command dialog', function()
  local screen

  local function start_new()
    clear()
    screen = Screen.new(60, 20)
    screen:attach()
  end

  write_file('foo', 'foo1\n')
  write_file('bar', 'bar1\n')

  -- Test for saving all the modified buffers
  start_new()
  command("set nomore")
  command("new foo")
  command("call setline(1, 'foo2')")
  command("new bar")
  command("call setline(1, 'bar2')")
  command("wincmd b")
  feed(':confirm qall\n')
  screen:expect([[
    bar2                                                        |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    bar [+]                                                     |
    foo2                                                        |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    foo [+]                                                     |
                                                                |
    ~                                                           |
    ~                                                           |
                                                                |
    :confirm qall                                               |
    Save changes to "bar"?                                      |
    [Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ^          |
  ]])
  feed('A')
  poke_eventloop()

  eq('foo2\n', read_file('foo'))
  eq('bar2\n', read_file('bar'))

  -- Test for discarding all the changes to modified buffers
  start_new()
  command("set nomore")
  command("new foo")
  command("call setline(1, 'foo3')")
  command("new bar")
  command("call setline(1, 'bar3')")
  command("wincmd b")
  feed(':confirm qall\n')
  screen:expect([[
    bar3                                                        |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    bar [+]                                                     |
    foo3                                                        |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    foo [+]                                                     |
                                                                |
    ~                                                           |
    ~                                                           |
                                                                |
    :confirm qall                                               |
    Save changes to "bar"?                                      |
    [Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ^          |
  ]])
  feed('D')
  poke_eventloop()

  eq('foo2\n', read_file('foo'))
  eq('bar2\n', read_file('bar'))

  -- Test for saving and discarding changes to some buffers
  start_new()
  command("set nomore")
  command("new foo")
  command("call setline(1, 'foo4')")
  command("new bar")
  command("call setline(1, 'bar4')")
  command("wincmd b")
  feed(':confirm qall\n')
  screen:expect([[
    bar4                                                        |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    bar [+]                                                     |
    foo4                                                        |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    foo [+]                                                     |
                                                                |
    ~                                                           |
    ~                                                           |
                                                                |
    :confirm qall                                               |
    Save changes to "bar"?                                      |
    [Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: ^          |
  ]])
  feed('N')
  screen:expect([[
    bar4                                                        |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    bar [+]                                                     |
    foo4                                                        |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    ~                                                           |
    foo [+]                                                     |
                                                                |
                                                                |
    :confirm qall                                               |
    Save changes to "bar"?                                      |
                                                                |
    Save changes to "foo"?                                      |
    [Y]es, (N)o, (C)ancel: ^                                     |
  ]])
  feed('Y')
  poke_eventloop()

  eq('foo4\n', read_file('foo'))
  eq('bar2\n', read_file('bar'))

  os.remove('foo')
  os.remove('bar')
end)
