local h = require('test.functional.helpers')

local buf     = h.curbufmeths
local command = h.command
local eq      = h.eq
local execute = h.execute
local feed    = h.feed
local nvim    = h.nvim

local shada_file = 'test.shada'

-- h.clear() uses "-i NONE", which is not useful for this test.
local function clear()
  if session then
    session:exit(0)
  end
  h.set_session(h.spawn({h.nvim_prog,
                         '-u', 'NONE',
                         '--cmd', 'set noswapfile undodir=. directory=. viewdir=. backupdir=.',
                         '--embed'}))
end

describe(':oldfiles', function()
  before_each(clear)

  it('shows most recently used files', function()
    command('edit testfile1')
    command('edit testfile2')
    command('wshada ' .. shada_file)
    command('rshada! ' .. shada_file)
    assert(string.find(nvim('command_output', 'oldfiles'), 'testfile2'))
    os.remove(shada_file)
  end)
end)

describe(':oldfiles!', function()
  it('provides a file selection prompt and edits the chosen file', function()
    command('edit testfile1')
    command('edit testfile2')
    local filename = buf.get_name()
    command('wshada ' .. shada_file)
    clear()
    command('rshada! ' .. shada_file)
    execute('oldfiles!')
    feed('2<cr>')
    eq(filename, buf.get_name())
    os.remove(shada_file)
  end)
end)
