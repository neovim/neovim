local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local clear = n.clear
local exc_exec = n.exc_exec

describe(':syntax', function()
  before_each(clear)

  describe('keyword', function()
    it('does not crash when group name contains unprintable characters', function()
      eq(
        'Vim(syntax):E669: Unprintable character in group name',
        exc_exec('syntax keyword \024 foo bar')
      )
    end)
  end)
end)
