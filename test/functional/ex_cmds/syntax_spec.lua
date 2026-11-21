local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local pcall_err = t.pcall_err
local clear = n.clear
local command = n.command
local eval = n.eval

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

  describe('iskeyword', function()
    it('replaces previous keyword characters', function()
      command('call setline(1, "NOTE:")')
      command('syntax keyword Note NOTE')
      command('syntax iskeyword @,48-57,_,:')
      eq('', eval('synIDattr(synID(1, 1, 1), "name")'))

      command('syntax iskeyword @,48-57,_')
      eq('Note', eval('synIDattr(synID(1, 1, 1), "name")'))
    end)
  end)
end)
