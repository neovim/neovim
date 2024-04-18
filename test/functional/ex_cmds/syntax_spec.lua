local t = require('test.functional.testutil')()

local eq = t.eq
local clear = t.clear
local exc_exec = t.exc_exec

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
