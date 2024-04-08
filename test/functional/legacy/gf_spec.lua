local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local command = t.command
local eq = t.eq
local pcall_err = t.pcall_err

describe('gf', function()
  before_each(clear)

  it('is not allowed when buffer is locked', function()
    command('au OptionSet diff norm! gf')
    command([[call setline(1, ['Xfile1', 'line2', 'line3', 'line4'])]])
    eq(
      'OptionSet Autocommands for "diff": Vim(normal):E788: Not allowed to edit another buffer now',
      pcall_err(command, 'diffthis')
    )
  end)
end)
