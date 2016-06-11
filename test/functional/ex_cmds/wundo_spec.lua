-- Specs for :wundo and underlying functions

local helpers = require('test.functional.helpers')(after_each)
local execute, clear, eval, feed, spawn, nvim_prog, set_session =
  helpers.execute, helpers.clear, helpers.eval, helpers.feed, helpers.spawn,
  helpers.nvim_prog, helpers.set_session


describe(':wundo', function()
  before_each(clear)

  it('safely fails on new, non-empty buffer', function()
    feed('iabc<esc>')
    execute('wundo foo') -- This should not segfault. #1027
    --TODO: check messages for error message

    os.remove(eval('getcwd()') .. '/foo') --cleanup
  end)
end)

describe('u_* functions', function()
  it('safely fail on new, non-empty buffer', function()
    local session = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed',
                           '-c', 'set undodir=. undofile'})
    set_session(session)
    execute('echo "True"')  -- Should not error out due to crashed Neovim
    session:close()
  end)
end)
