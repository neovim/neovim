local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)

local buf, eq, execute = helpers.curbufmeths, helpers.eq, helpers.execute
local feed, nvim_prog, wait = helpers.feed, helpers.nvim_prog, helpers.wait
local ok, set_session, spawn = helpers.ok, helpers.set_session, helpers.spawn

local shada_file = 'test.shada'

--
-- helpers.clear() uses "-i NONE", which is not useful for this test.
--
local function _clear()
  set_session(spawn({nvim_prog,
                     '-u', 'NONE',
                     '--cmd', 'set noswapfile undodir=. directory=. viewdir=. backupdir=.',
                     '--embed'}))
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
    execute('edit testfile1')
    execute('edit testfile2')
    execute('wshada ' .. shada_file)
    execute('rshada! ' .. shada_file)
    local oldfiles = helpers.meths.get_vvar('oldfiles')
    execute('oldfiles')
    screen:expect([[
      testfile2                                                                                           |
      1: ]].. add_padding(oldfiles[1]) ..[[ |
      2: ]].. add_padding(oldfiles[2]) ..[[ |
                                                                                                          |
      Press ENTER or type command to continue^                                                             |
    ]])
  end)
end)

describe(':oldfiles!', function()
  local filename
  local filename2
  local oldfiles

  before_each(function()
    _clear()
    execute('edit testfile1')
    filename = buf.get_name()
    execute('edit testfile2')
    filename2 = buf.get_name()
    execute('wshada ' .. shada_file)
    wait()
    _clear()
    execute('rshada! ' .. shada_file)

    -- Ensure nvim is out of "Press ENTER..." screen
    feed('<cr>')
    
    -- Ensure v:oldfiles isn't busted.  Since things happen so fast,
    -- the ordering of v:oldfiles is unstable (it uses qsort() under-the-hood).
    -- Let's verify the contents and the length of v:oldfiles before moving on.
    oldfiles = helpers.meths.get_vvar('oldfiles')
    eq(2, #oldfiles)
    ok(filename == oldfiles[1] or filename == oldfiles[2])
    ok(filename2 == oldfiles[1] or filename2 == oldfiles[2])

    execute('oldfiles!')
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
