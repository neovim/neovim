local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local command = t.command
local exec = t.exec
local exec_lua = t.exec_lua
local expect_exit = t.expect_exit
local feed = t.feed
local fn = t.fn
local api = t.api
local read_file = t.read_file
local source = t.source
local eq = t.eq
local write_file = t.write_file
local is_os = t.is_os

local function sizeoflong()
  if not exec_lua('return pcall(require, "ffi")') then
    pending('missing LuaJIT FFI')
  end
  return exec_lua('return require("ffi").sizeof(require("ffi").typeof("long"))')
end

describe('Ex command', function()
  before_each(clear)
  after_each(function()
    eq({}, api.nvim_get_vvar('errors'))
  end)

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

describe(':confirm command dialog', function()
  local screen

  local function start_new()
    clear()
    screen = Screen.new(75, 20)
    screen:attach()
  end

  -- Test for the :confirm command dialog
  -- oldtest: Test_confirm_cmd()
  it('works', function()
    write_file('Xfoo', 'foo1\n')
    write_file('Xbar', 'bar1\n')

    -- Test for saving all the modified buffers
    start_new()
    exec([[
      set nomore
      new Xfoo
      call setline(1, 'foo2')
      new Xbar
      call setline(1, 'bar2')
      wincmd b
    ]])
    feed(':confirm qall\n')
    screen:expect([[
      bar2                                                                       |
      {1:~                                                                          }|*5
      {2:Xbar [+]                                                                   }|
      foo2                                                                       |
      {1:~                                                                          }|*4
      {2:Xfoo [+]                                                                   }|
                                                                                 |
      {1:~                                                                          }|*2
      {3:                                                                           }|
      :confirm qall                                                              |
      {6:Save changes to "Xbar"?}                                                    |
      {6:[Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: }^                         |
    ]])
    expect_exit(1000, feed, 'A')

    eq('foo2\n', read_file('Xfoo'))
    eq('bar2\n', read_file('Xbar'))

    -- Test for discarding all the changes to modified buffers
    start_new()
    exec([[
      set nomore
      new Xfoo
      call setline(1, 'foo3')
      new Xbar
      call setline(1, 'bar3')
      wincmd b
    ]])
    feed(':confirm qall\n')
    screen:expect([[
      bar3                                                                       |
      {1:~                                                                          }|*5
      {2:Xbar [+]                                                                   }|
      foo3                                                                       |
      {1:~                                                                          }|*4
      {2:Xfoo [+]                                                                   }|
                                                                                 |
      {1:~                                                                          }|*2
      {3:                                                                           }|
      :confirm qall                                                              |
      {6:Save changes to "Xbar"?}                                                    |
      {6:[Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: }^                         |
    ]])
    expect_exit(1000, feed, 'D')

    eq('foo2\n', read_file('Xfoo'))
    eq('bar2\n', read_file('Xbar'))

    -- Test for saving and discarding changes to some buffers
    start_new()
    exec([[
      set nomore
      new Xfoo
      call setline(1, 'foo4')
      new Xbar
      call setline(1, 'bar4')
      wincmd b
    ]])
    feed(':confirm qall\n')
    screen:expect([[
      bar4                                                                       |
      {1:~                                                                          }|*5
      {2:Xbar [+]                                                                   }|
      foo4                                                                       |
      {1:~                                                                          }|*4
      {2:Xfoo [+]                                                                   }|
                                                                                 |
      {1:~                                                                          }|*2
      {3:                                                                           }|
      :confirm qall                                                              |
      {6:Save changes to "Xbar"?}                                                    |
      {6:[Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: }^                         |
    ]])
    feed('N')
    screen:expect([[
      bar4                                                                       |
      {1:~                                                                          }|*5
      {2:Xbar [+]                                                                   }|
      foo4                                                                       |
      {1:~                                                                          }|*4
      {2:Xfoo [+]                                                                   }|
                                                                                 |
      {3:                                                                           }|
      :confirm qall                                                              |
      {6:Save changes to "Xbar"?}                                                    |
                                                                                 |
      {6:Save changes to "Xfoo"?}                                                    |
      {6:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    expect_exit(1000, feed, 'Y')

    eq('foo4\n', read_file('Xfoo'))
    eq('bar2\n', read_file('Xbar'))

    os.remove('Xfoo')
    os.remove('Xbar')
  end)

  -- oldtest: Test_confirm_cmd_cancel()
  it('can be cancelled', function()
    -- Test for closing a window with a modified buffer
    start_new()
    screen:try_resize(75, 10)
    exec([[
      set nohidden nomore
      new
      call setline(1, 'abc')
    ]])
    feed(':confirm close\n')
    screen:expect([[
      abc                                                                        |
      {1:~                                                                          }|*3
      {3:[No Name] [+]                                                              }|
                                                                                 |
      {3:                                                                           }|
      :confirm close                                                             |
      {6:Save changes to "Untitled"?}                                                |
      {6:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    feed('C')
    screen:expect([[
      ^abc                                                                        |
      {1:~                                                                          }|*3
      {3:[No Name] [+]                                                              }|
                                                                                 |
      {1:~                                                                          }|*2
      {2:[No Name]                                                                  }|
                                                                                 |
    ]])
    feed(':confirm close\n')
    screen:expect([[
      abc                                                                        |
      {1:~                                                                          }|*3
      {3:[No Name] [+]                                                              }|
                                                                                 |
      {3:                                                                           }|
      :confirm close                                                             |
      {6:Save changes to "Untitled"?}                                                |
      {6:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    feed('N')
    screen:expect([[
      ^                                                                           |
      {1:~                                                                          }|*8
                                                                                 |
    ]])
  end)

  -- oldtest: Test_confirm_q_wq()
  it('works with :q and :wq', function()
    write_file('Xfoo', 'foo')
    start_new()
    screen:try_resize(75, 8)
    exec([[
      set hidden nomore
      call setline(1, 'abc')
      edit Xfoo
      set nofixendofline
    ]])
    feed(':confirm q\n')
    screen:expect([[
      foo                                                                        |
      {1:~                                                                          }|*3
      {3:                                                                           }|
      :confirm q                                                                 |
      {6:Save changes to "Untitled"?}                                                |
      {6:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    feed('C')
    screen:expect([[
      ^abc                                                                        |
      {1:~                                                                          }|*6
                                                                                 |
    ]])

    command('edit Xfoo')
    feed(':confirm wq\n')
    screen:expect([[
      foo                                                                        |
      {1:~                                                                          }|*3
      {3:                                                                           }|
      "Xfoo" [noeol] 1L, 3B written                                              |
      {6:Save changes to "Untitled"?}                                                |
      {6:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    feed('C')
    screen:expect([[
      ^abc                                                                        |
      {1:~                                                                          }|*6
      "Xfoo" [noeol] 1L, 3B written                                              |
    ]])

    os.remove('Xfoo')
  end)

  -- oldtest: Test_confirm_write_ro()
  it('works when writing a read-only file', function()
    write_file('Xconfirm_write_ro', 'foo\n')
    start_new()
    screen:try_resize(75, 8)
    exec([[
      set ruler
      set nobackup ff=unix cmdheight=2
      edit Xconfirm_write_ro
      norm Abar
    ]])

    -- Try to write with 'ro' option.
    feed(':set ro | confirm w\n')
    screen:expect([[
      foobar                                                                     |
      {1:~                                                                          }|*2
      {3:                                                                           }|
      :set ro | confirm w                                                        |
      {6:'readonly' option is set for "Xconfirm_write_ro".}                          |
      {6:Do you wish to write anyway?}                                               |
      {6:(Y)es, [N]o: }^                                                              |
    ]])
    feed('N')
    screen:expect([[
      fooba^r                                                                     |
      {1:~                                                                          }|*5
                                                                                 |
                                                               1,6           All |
    ]])
    eq('foo\n', read_file('Xconfirm_write_ro'))

    feed(':confirm w\n')
    screen:expect([[
      foobar                                                                     |
      {1:~                                                                          }|*2
      {3:                                                                           }|
      :confirm w                                                                 |
      {6:'readonly' option is set for "Xconfirm_write_ro".}                          |
      {6:Do you wish to write anyway?}                                               |
      {6:(Y)es, [N]o: }^                                                              |
    ]])
    feed('Y')
    if is_os('win') then
      screen:expect([[
        foobar                                                                     |
        {1:~                                                                          }|
        {3:                                                                           }|
        :confirm w                                                                 |
        {6:'readonly' option is set for "Xconfirm_write_ro".}                          |
        {6:Do you wish to write anyway?}                                               |
        "Xconfirm_write_ro" [unix] 1L, 7B written                                  |
        {6:Press ENTER or type command to continue}^                                    |
      ]])
    else
      screen:expect([[
        foobar                                                                     |
        {1:~                                                                          }|
        {3:                                                                           }|
        :confirm w                                                                 |
        {6:'readonly' option is set for "Xconfirm_write_ro".}                          |
        {6:Do you wish to write anyway?}                                               |
        "Xconfirm_write_ro" 1L, 7B written                                         |
        {6:Press ENTER or type command to continue}^                                    |
      ]])
    end
    eq('foobar\n', read_file('Xconfirm_write_ro'))
    feed('<CR>') -- suppress hit-enter prompt

    -- Try to write with read-only file permissions.
    fn.setfperm('Xconfirm_write_ro', 'r--r--r--')
    feed(':set noro | silent undo | confirm w\n')
    screen:expect([[
      foobar                                                                     |
      {1:~                                                                          }|
      {3:                                                                           }|
      :set noro | silent undo | confirm w                                        |
      {6:File permissions of "Xconfirm_write_ro" are read-only.}                     |
      {6:It may still be possible to write it.}                                      |
      {6:Do you wish to try?}                                                        |
      {6:(Y)es, [N]o: }^                                                              |
    ]])
    feed('Y')
    if is_os('win') then
      screen:expect([[
        foobar                                                                     |
        {3:                                                                           }|
        :set noro | silent undo | confirm w                                        |
        {6:File permissions of "Xconfirm_write_ro" are read-only.}                     |
        {6:It may still be possible to write it.}                                      |
        {6:Do you wish to try?}                                                        |
        "Xconfirm_write_ro" [unix] 1L, 4B written                                  |
        {6:Press ENTER or type command to continue}^                                    |
      ]])
    else
      screen:expect([[
        foobar                                                                     |
        {3:                                                                           }|
        :set noro | silent undo | confirm w                                        |
        {6:File permissions of "Xconfirm_write_ro" are read-only.}                     |
        {6:It may still be possible to write it.}                                      |
        {6:Do you wish to try?}                                                        |
        "Xconfirm_write_ro" 1L, 4B written                                         |
        {6:Press ENTER or type command to continue}^                                    |
      ]])
    end
    eq('foo\n', read_file('Xconfirm_write_ro'))
    feed('<CR>') -- suppress hit-enter prompt

    os.remove('Xconfirm_write_ro')
  end)

  -- oldtest: Test_confirm_write_partial_file()
  it('works when writing a partial file', function()
    write_file('Xwrite_partial', 'a\nb\nc\nd\n')
    start_new()
    screen:try_resize(75, 8)
    exec([[
      set ruler
      set nobackup ff=unix cmdheight=2
      edit Xwrite_partial
    ]])

    feed(':confirm 2,3w\n')
    screen:expect([[
      a                                                                          |
      b                                                                          |
      c                                                                          |
      d                                                                          |
      {3:                                                                           }|
      :confirm 2,3w                                                              |
      {6:Write partial file?}                                                        |
      {6:(Y)es, [N]o: }^                                                              |
    ]])
    feed('N')
    screen:expect([[
      ^a                                                                          |
      b                                                                          |
      c                                                                          |
      d                                                                          |
      {1:~                                                                          }|*2
                                                                                 |
                                                               1,1           All |
    ]])
    eq('a\nb\nc\nd\n', read_file('Xwrite_partial'))
    os.remove('Xwrite_partial')

    feed(':confirm 2,3w\n')
    screen:expect([[
      a                                                                          |
      b                                                                          |
      c                                                                          |
      d                                                                          |
      {3:                                                                           }|
      :confirm 2,3w                                                              |
      {6:Write partial file?}                                                        |
      {6:(Y)es, [N]o: }^                                                              |
    ]])
    feed('Y')
    if is_os('win') then
      screen:expect([[
        a                                                                          |
        b                                                                          |
        c                                                                          |
        {3:                                                                           }|
        :confirm 2,3w                                                              |
        {6:Write partial file?}                                                        |
        "Xwrite_partial" [New][unix] 2L, 4B written                                |
        {6:Press ENTER or type command to continue}^                                    |
      ]])
    else
      screen:expect([[
        a                                                                          |
        b                                                                          |
        c                                                                          |
        {3:                                                                           }|
        :confirm 2,3w                                                              |
        {6:Write partial file?}                                                        |
        "Xwrite_partial" [New] 2L, 4B written                                      |
        {6:Press ENTER or type command to continue}^                                    |
      ]])
    end
    eq('b\nc\n', read_file('Xwrite_partial'))

    os.remove('Xwrite_partial')
  end)
end)
