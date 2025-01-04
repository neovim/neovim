-- Specs for :wundo and underlying functions

local n = require('test.functional.testnvim')()

local command = n.command
local clear = n.clear
local eval = n.eval
local set_session = n.set_session

describe(':wundo', function()
  before_each(clear)
  after_each(function()
    os.remove(eval('getcwd()') .. '/foo')
  end)

  it('safely fails on new, non-empty buffer', function()
    command('normal! iabc')
    command('wundo foo') -- This should not segfault. #1027
    --TODO: check messages for error message
  end)
end)

describe('u_* functions', function()
  it('safely fail on new, non-empty buffer', function()
    local session = n.new_session(false, {
      args = {
        '-c',
        'set undodir=. undofile',
      },
    })
    set_session(session)
    command('echo "True"') -- Should not error out due to crashed Neovim
    session:close()
  end)
end)
