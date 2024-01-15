local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local expect_exit = helpers.expect_exit
local api, eq, feed_command = helpers.api, helpers.eq, helpers.feed_command
local feed, poke_eventloop = helpers.feed, helpers.poke_eventloop
local ok = helpers.ok
local eval = helpers.eval

local shada_file = 'Xtest.shada'

local function _clear()
  clear {
    args = {
      '-i',
      shada_file, -- Need shada for these tests.
      '--cmd',
      'set noswapfile undodir=. directory=. viewdir=. backupdir=. belloff= noshowcmd noruler',
    },
    args_rm = { '-i', '--cmd' },
  }
end

describe(':oldfiles', function()
  before_each(_clear)

  after_each(function()
    expect_exit(command, 'qall!')
    os.remove(shada_file)
  end)

  local function add_padding(s)
    return s .. string.rep(' ', 96 - string.len(s))
  end

  it('shows most recently used files', function()
    local screen = Screen.new(100, 5)
    screen:attach()
    feed_command('edit testfile1')
    feed_command('edit testfile2')
    feed_command('wshada')
    feed_command('rshada!')
    local oldfiles = api.nvim_get_vvar('oldfiles')
    feed_command('oldfiles')
    screen:expect([[
                                                                                                          |
      1: ]] .. add_padding(oldfiles[1]) .. [[ |
      2: ]] .. add_padding(oldfiles[2]) .. [[ |
                                                                                                          |
      Press ENTER or type command to continue^                                                             |
    ]])
    feed('<CR>')
  end)

  it('can be filtered with :filter', function()
    feed_command('edit file_one.txt')
    local file1 = api.nvim_buf_get_name(0)
    feed_command('edit file_two.txt')
    local file2 = api.nvim_buf_get_name(0)
    feed_command('edit another.txt')
    local another = api.nvim_buf_get_name(0)
    feed_command('wshada')
    feed_command('rshada!')

    local function get_oldfiles(cmd)
      local t = eval([[split(execute(']] .. cmd .. [['), "\n")]])
      for i, _ in ipairs(t) do
        t[i] = t[i]:gsub('^%d+:%s+', '')
      end
      table.sort(t)
      return t
    end

    local oldfiles = get_oldfiles('oldfiles')
    eq({ another, file1, file2 }, oldfiles)

    oldfiles = get_oldfiles('filter file_ oldfiles')
    eq({ file1, file2 }, oldfiles)

    oldfiles = get_oldfiles('filter /another/ oldfiles')
    eq({ another }, oldfiles)

    oldfiles = get_oldfiles('filter! file_ oldfiles')
    eq({ another }, oldfiles)
  end)
end)

describe(':browse oldfiles', function()
  local filename
  local filename2
  local oldfiles

  before_each(function()
    _clear()
    feed_command('edit testfile1')
    filename = api.nvim_buf_get_name(0)
    feed_command('edit testfile2')
    filename2 = api.nvim_buf_get_name(0)
    feed_command('wshada')
    poke_eventloop()
    _clear()

    -- Ensure nvim is out of "Press ENTER..." prompt.
    feed('<cr>')

    -- Ensure v:oldfiles isn't busted.  Since things happen so fast,
    -- the ordering of v:oldfiles is unstable (it uses qsort() under-the-hood).
    -- Let's verify the contents and the length of v:oldfiles before moving on.
    oldfiles = helpers.api.nvim_get_vvar('oldfiles')
    eq(2, #oldfiles)
    ok(filename == oldfiles[1] or filename == oldfiles[2])
    ok(filename2 == oldfiles[1] or filename2 == oldfiles[2])

    feed_command('browse oldfiles')
  end)

  after_each(function()
    expect_exit(command, 'qall!')
    os.remove(shada_file)
  end)

  it('provides a prompt and edits the chosen file', function()
    feed('2<cr>')
    eq(oldfiles[2], api.nvim_buf_get_name(0))
  end)

  it('provides a prompt and does nothing on <cr>', function()
    feed('<cr>')
    eq('', api.nvim_buf_get_name(0))
  end)

  it('provides a prompt and does nothing if choice is out-of-bounds', function()
    feed('3<cr>')
    eq('', api.nvim_buf_get_name(0))
  end)
end)
