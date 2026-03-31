local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, eval, eq = n.clear, n.eval, t.eq
local command = n.command

describe('v:event', function()
  before_each(clear)
  it('is empty before any autocommand', function()
    eq({}, eval('v:event'))
  end)

  it('is immutable', function()
    eq(false, pcall(command, 'let v:event = {}'))
    eq(false, pcall(command, 'let v:event.mykey = {}'))
  end)
end)

describe('v:argf', function()
  it('is read-only', function()
    n.clear()
    t.matches('E46', t.pcall_err(command, "let v:argf = ['foo']"))
  end)

  it('gets file args, ignores :argadd, handles "--"', function()
    local file1, file2, file3 = 'Xargf_sep1', 'Xargf_sep2', 'Xargf_sep3'

    n.clear {
      args_rm = { '--cmd', '-c' },
      args = {
        '--clean',
        '--cmd',
        'argadd extrafile.txt', -- :argadd should not affect v:argf.
        file1,
        file2,
        '-c',
        'let a = 1 + 3',
        '--',
        file3,
      },
    }

    local abs1 = n.fn.fnamemodify(file1, ':p')
    local abs2 = n.fn.fnamemodify(file2, ':p')
    local abs3 = n.fn.fnamemodify(file3, ':p')

    eq({ abs1, abs2, abs3 }, n.eval('v:argf'))
  end)
end)
