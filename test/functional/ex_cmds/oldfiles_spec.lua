local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)

local buf, eq, feed_command = helpers.curbufmeths, helpers.eq, helpers.feed_command
local feed, nvim_prog, wait = helpers.feed, helpers.nvim_prog, helpers.wait
local ok, set_session, spawn = helpers.ok, helpers.set_session, helpers.spawn
local eval = helpers.eval

local shada_file = 'Xtest.shada'

local function _clear()
  set_session(spawn({nvim_prog, '--embed', '-u', 'NONE',
                     -- Need shada for these tests.
                     '-i', shada_file,
                     '--cmd', 'set noswapfile undodir=. directory=. viewdir=. backupdir=. belloff= noshowcmd noruler'}))
end

describe(':oldfiles', function()
  before_each(_clear)

  after_each(function()
    os.remove(shada_file)
  end)

  local function add_padding(s)
    return s .. string.rep(' ', 96 - string.len(s))
  end

  it('shows most recently used files', function()
    local screen = Screen.new(100, 5)
    screen:attach()
    feed_command("set display-=msgsep")
    feed_command('edit testfile1')
    feed_command('edit testfile2')
    feed_command('wshada')
    feed_command('rshada!')
    local oldfiles = helpers.meths.get_vvar('oldfiles')
    feed_command('oldfiles')
    screen:expect([[
      testfile2                                                                                           |
      1: ]].. add_padding(oldfiles[1]) ..[[ |
      2: ]].. add_padding(oldfiles[2]) ..[[ |
                                                                                                          |
      Press ENTER or type command to continue^                                                             |
    ]])
  end)

  it('can be filtered with :filter', function()
    feed_command('edit file_one.txt')
    local file1 = buf.get_name()
    feed_command('edit file_two.txt')
    local file2 = buf.get_name()
    feed_command('edit another.txt')
    local another = buf.get_name()
    feed_command('wshada')
    feed_command('rshada!')

    local function get_oldfiles(cmd)
      local t = eval([[split(execute(']]..cmd..[['), "\n")]])
      for i, _ in ipairs(t) do
        t[i] = t[i]:gsub('^%d+:%s+', '')
      end
      table.sort(t)
      return t
    end

    local oldfiles = get_oldfiles('oldfiles')
    eq({another, file1, file2}, oldfiles)

    oldfiles = get_oldfiles('filter file_ oldfiles')
    eq({file1, file2}, oldfiles)

    oldfiles = get_oldfiles('filter /another/ oldfiles')
    eq({another}, oldfiles)

    oldfiles = get_oldfiles('filter! file_ oldfiles')
    eq({another}, oldfiles)
  end)
end)

describe(':browse oldfiles', function()
  local filename
  local filename2
  local oldfiles

  before_each(function()
    _clear()
    feed_command('edit testfile1')
    filename = buf.get_name()
    feed_command('edit testfile2')
    filename2 = buf.get_name()
    feed_command('wshada')
    wait()
    _clear()

    -- Ensure nvim is out of "Press ENTER..." prompt.
    feed('<cr>')

    -- Ensure v:oldfiles isn't busted.  Since things happen so fast,
    -- the ordering of v:oldfiles is unstable (it uses qsort() under-the-hood).
    -- Let's verify the contents and the length of v:oldfiles before moving on.
    oldfiles = helpers.meths.get_vvar('oldfiles')
    eq(2, #oldfiles)
    ok(filename == oldfiles[1] or filename == oldfiles[2])
    ok(filename2 == oldfiles[1] or filename2 == oldfiles[2])

    feed_command('browse oldfiles')
  end)

  after_each(function()
    os.remove(shada_file)
  end)

  it('provides a prompt and edits the chosen file', function()
    feed('2<cr>')
    eq(oldfiles[2], buf.get_name())
  end)

  it('provides a prompt and does nothing on <cr>', function()
    feed('<cr>')
    eq('', buf.get_name())
  end)

  it('provides a prompt and does nothing if choice is out-of-bounds', function()
    feed('3<cr>')
    eq('', buf.get_name())
  end)
end)
