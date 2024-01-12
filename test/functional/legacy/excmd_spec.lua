local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local exec = helpers.exec
local exec_lua = helpers.exec_lua
local expect_exit = helpers.expect_exit
local feed = helpers.feed
local fn = helpers.fn
local api = helpers.api
local read_file = helpers.read_file
local source = helpers.source
local eq = helpers.eq
local write_file = helpers.write_file
local is_os = helpers.is_os

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
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { bold = true, reverse = true }, -- StatusLine, MsgSeparator
      [2] = { reverse = true }, -- StatusLineNC
      [3] = { bold = true, foreground = Screen.colors.SeaGreen }, -- MoreMsg
    })
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
      {0:~                                                                          }|*5
      {2:Xbar [+]                                                                   }|
      foo2                                                                       |
      {0:~                                                                          }|*4
      {2:Xfoo [+]                                                                   }|
                                                                                 |
      {0:~                                                                          }|*2
      {1:                                                                           }|
      :confirm qall                                                              |
      {3:Save changes to "Xbar"?}                                                    |
      {3:[Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: }^                         |
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
      {0:~                                                                          }|*5
      {2:Xbar [+]                                                                   }|
      foo3                                                                       |
      {0:~                                                                          }|*4
      {2:Xfoo [+]                                                                   }|
                                                                                 |
      {0:~                                                                          }|*2
      {1:                                                                           }|
      :confirm qall                                                              |
      {3:Save changes to "Xbar"?}                                                    |
      {3:[Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: }^                         |
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
      {0:~                                                                          }|*5
      {2:Xbar [+]                                                                   }|
      foo4                                                                       |
      {0:~                                                                          }|*4
      {2:Xfoo [+]                                                                   }|
                                                                                 |
      {0:~                                                                          }|*2
      {1:                                                                           }|
      :confirm qall                                                              |
      {3:Save changes to "Xbar"?}                                                    |
      {3:[Y]es, (N)o, Save (A)ll, (D)iscard All, (C)ancel: }^                         |
    ]])
    feed('N')
    screen:expect([[
      bar4                                                                       |
      {0:~                                                                          }|*5
      {2:Xbar [+]                                                                   }|
      foo4                                                                       |
      {0:~                                                                          }|*4
      {2:Xfoo [+]                                                                   }|
                                                                                 |
      {1:                                                                           }|
      :confirm qall                                                              |
      {3:Save changes to "Xbar"?}                                                    |
                                                                                 |
      {3:Save changes to "Xfoo"?}                                                    |
      {3:[Y]es, (N)o, (C)ancel: }^                                                    |
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
      {0:~                                                                          }|*3
      {1:[No Name] [+]                                                              }|
                                                                                 |
      {1:                                                                           }|
      :confirm close                                                             |
      {3:Save changes to "Untitled"?}                                                |
      {3:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    feed('C')
    screen:expect([[
      ^abc                                                                        |
      {0:~                                                                          }|*3
      {1:[No Name] [+]                                                              }|
                                                                                 |
      {0:~                                                                          }|*2
      {2:[No Name]                                                                  }|
                                                                                 |
    ]])
    feed(':confirm close\n')
    screen:expect([[
      abc                                                                        |
      {0:~                                                                          }|*3
      {1:[No Name] [+]                                                              }|
                                                                                 |
      {1:                                                                           }|
      :confirm close                                                             |
      {3:Save changes to "Untitled"?}                                                |
      {3:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    feed('N')
    screen:expect([[
      ^                                                                           |
      {0:~                                                                          }|*8
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
      {0:~                                                                          }|*3
      {1:                                                                           }|
      :confirm q                                                                 |
      {3:Save changes to "Untitled"?}                                                |
      {3:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    feed('C')
    screen:expect([[
      ^abc                                                                        |
      {0:~                                                                          }|*6
                                                                                 |
    ]])

    command('edit Xfoo')
    feed(':confirm wq\n')
    screen:expect([[
      foo                                                                        |
      {0:~                                                                          }|*3
      {1:                                                                           }|
      "Xfoo" [noeol] 1L, 3B written                                              |
      {3:Save changes to "Untitled"?}                                                |
      {3:[Y]es, (N)o, (C)ancel: }^                                                    |
    ]])
    feed('C')
    screen:expect([[
      ^abc                                                                        |
      {0:~                                                                          }|*6
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
      {0:~                                                                          }|*2
      {1:                                                                           }|
      :set ro | confirm w                                                        |
      {3:'readonly' option is set for "Xconfirm_write_ro".}                          |
      {3:Do you wish to write anyway?}                                               |
      {3:(Y)es, [N]o: }^                                                              |
    ]])
    feed('N')
    screen:expect([[
      fooba^r                                                                     |
      {0:~                                                                          }|*5
                                                                                 |
                                                               1,6           All |
    ]])
    eq('foo\n', read_file('Xconfirm_write_ro'))

    feed(':confirm w\n')
    screen:expect([[
      foobar                                                                     |
      {0:~                                                                          }|*2
      {1:                                                                           }|
      :confirm w                                                                 |
      {3:'readonly' option is set for "Xconfirm_write_ro".}                          |
      {3:Do you wish to write anyway?}                                               |
      {3:(Y)es, [N]o: }^                                                              |
    ]])
    feed('Y')
    if is_os('win') then
      screen:expect([[
        foobar                                                                     |
        {0:~                                                                          }|
        {1:                                                                           }|
        :confirm w                                                                 |
        {3:'readonly' option is set for "Xconfirm_write_ro".}                          |
        {3:Do you wish to write anyway?}                                               |
        "Xconfirm_write_ro" [unix] 1L, 7B written                                  |
        {3:Press ENTER or type command to continue}^                                    |
      ]])
    else
      screen:expect([[
        foobar                                                                     |
        {0:~                                                                          }|
        {1:                                                                           }|
        :confirm w                                                                 |
        {3:'readonly' option is set for "Xconfirm_write_ro".}                          |
        {3:Do you wish to write anyway?}                                               |
        "Xconfirm_write_ro" 1L, 7B written                                         |
        {3:Press ENTER or type command to continue}^                                    |
      ]])
    end
    eq('foobar\n', read_file('Xconfirm_write_ro'))
    feed('<CR>') -- suppress hit-enter prompt

    -- Try to write with read-only file permissions.
    fn.setfperm('Xconfirm_write_ro', 'r--r--r--')
    feed(':set noro | silent undo | confirm w\n')
    screen:expect([[
      foobar                                                                     |
      {0:~                                                                          }|
      {1:                                                                           }|
      :set noro | silent undo | confirm w                                        |
      {3:File permissions of "Xconfirm_write_ro" are read-only.}                     |
      {3:It may still be possible to write it.}                                      |
      {3:Do you wish to try?}                                                        |
      {3:(Y)es, [N]o: }^                                                              |
    ]])
    feed('Y')
    if is_os('win') then
      screen:expect([[
        foobar                                                                     |
        {1:                                                                           }|
        :set noro | silent undo | confirm w                                        |
        {3:File permissions of "Xconfirm_write_ro" are read-only.}                     |
        {3:It may still be possible to write it.}                                      |
        {3:Do you wish to try?}                                                        |
        "Xconfirm_write_ro" [unix] 1L, 4B written                                  |
        {3:Press ENTER or type command to continue}^                                    |
      ]])
    else
      screen:expect([[
        foobar                                                                     |
        {1:                                                                           }|
        :set noro | silent undo | confirm w                                        |
        {3:File permissions of "Xconfirm_write_ro" are read-only.}                     |
        {3:It may still be possible to write it.}                                      |
        {3:Do you wish to try?}                                                        |
        "Xconfirm_write_ro" 1L, 4B written                                         |
        {3:Press ENTER or type command to continue}^                                    |
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
      {1:                                                                           }|
      :confirm 2,3w                                                              |
      {3:Write partial file?}                                                        |
      {3:(Y)es, [N]o: }^                                                              |
    ]])
    feed('N')
    screen:expect([[
      ^a                                                                          |
      b                                                                          |
      c                                                                          |
      d                                                                          |
      {0:~                                                                          }|*2
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
      {1:                                                                           }|
      :confirm 2,3w                                                              |
      {3:Write partial file?}                                                        |
      {3:(Y)es, [N]o: }^                                                              |
    ]])
    feed('Y')
    if is_os('win') then
      screen:expect([[
        a                                                                          |
        b                                                                          |
        c                                                                          |
        {1:                                                                           }|
        :confirm 2,3w                                                              |
        {3:Write partial file?}                                                        |
        "Xwrite_partial" [New][unix] 2L, 4B written                                |
        {3:Press ENTER or type command to continue}^                                    |
      ]])
    else
      screen:expect([[
        a                                                                          |
        b                                                                          |
        c                                                                          |
        {1:                                                                           }|
        :confirm 2,3w                                                              |
        {3:Write partial file?}                                                        |
        "Xwrite_partial" [New] 2L, 4B written                                      |
        {3:Press ENTER or type command to continue}^                                    |
      ]])
    end
    eq('b\nc\n', read_file('Xwrite_partial'))

    os.remove('Xwrite_partial')
  end)
end)
