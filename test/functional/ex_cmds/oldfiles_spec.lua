local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')

local buf, eq, execute = helpers.curbufmeths, helpers.eq, helpers.execute
local feed, nvim, nvim_prog = helpers.feed, helpers.nvim, helpers.nvim_prog
local set_session, spawn = helpers.set_session, helpers.spawn

local shada_file = 'test.shada'

--
-- helpers.clear() uses "-i NONE", which is not useful for this test.
--
local function _clear()
  if session then
    session:exit(0)
  end
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
    screen = Screen.new(100, 5)
    screen:attach()
    execute('edit testfile1')
    local filename1 = buf.get_name()
    execute('edit testfile2')
    local filename2 = buf.get_name()
    execute('wshada ' .. shada_file)
    execute('rshada! ' .. shada_file)
    execute('oldfiles')
    screen:expect([[
      testfile2                                                                                           |
      1: ]].. add_padding(filename1) ..[[ |
      2: ]].. add_padding(filename2) ..[[ |
                                                                                                          |
      Press ENTER or type command to continue^                                                             |
    ]])
  end)
end)

describe(':oldfiles!', function()
  local filename

  before_each(function()
    _clear()
    execute('edit testfile1')
    execute('edit testfile2')
    filename = buf.get_name()
    execute('wshada ' .. shada_file)
    _clear()
    execute('rshada! ' .. shada_file)
    execute('oldfiles!')
  end)

  after_each(function()
    os.remove(shada_file)
  end)

  it('provides a prompt and edits the chosen file', function()
    feed('2<cr>')
    eq(filename, buf.get_name())
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
