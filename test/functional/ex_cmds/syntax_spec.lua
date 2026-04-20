local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local pcall_err = t.pcall_err
local clear = n.clear
local command = n.command

describe(':syntax', function()
  before_each(clear)

  describe('keyword', function()
    it('does not crash when group name contains unprintable characters', function()
      eq(
        'Vim(syntax):E669: Unprintable character in group name',
        pcall_err(command, 'syntax keyword \024 foo bar')
      )
    end)
  end)
end)
