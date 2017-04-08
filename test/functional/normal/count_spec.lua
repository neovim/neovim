local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local clear = helpers.clear
local command = helpers.command

describe('v:count/v:count1', function()
  before_each(function()
    clear()

    command('map <silent> _x :<C-u>let g:count = "v:count=". v:count .", v:count1=". v:count1<CR>')
  end)

  describe('in cmdwin', function()
    it('equal 0/1 when no count is given', function()
      feed('q:_x')
      eq('v:count=0, v:count1=1', eval('g:count'))
    end)

    it('equal 2/2 when count of 2 is given', function()
      feed('q:2_x')
      eq('v:count=2, v:count1=2', eval('g:count'))
    end)
  end)

  describe('in normal mode', function()
    it('equal 0/1 when no count is given', function()
      feed('_x')
      eq('v:count=0, v:count1=1', eval('g:count'))
    end)

    it('equal 2/2 when count of 2 is given', function()
      feed('2_x')
      eq('v:count=2, v:count1=2', eval('g:count'))
    end)
  end)
end)
