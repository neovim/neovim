local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local exc_exec = helpers.exc_exec
local execute = helpers.funcs.execute
local expect_foldclosed = helpers.expect_foldclosed
local feed_command = helpers.feed_command
local insert = helpers.insert

describe(':syntax', function()
  before_each(clear)

  describe('keyword', function()
    it('does not crash when group name contains unprintable characters',
    function()
      eq('Vim(syntax):E669: Unprintable character in group name',
         exc_exec('syntax keyword \024 foo bar'))
    end)
  end)

  it('foldlevel', function()
    feed_command('syntax foldlevel start')
    eq('\nsyntax foldlevel start', execute('syntax foldlevel'))
    feed_command('syntax foldlevel minimum')
    eq('\nsyntax foldlevel minimum', execute('syntax foldlevel'))
  end)

  describe('foldlevel', function()
    before_each(function()
      insert([[
        if (a == 1) {
            a = 0;
        } else if (a == 2) {
            a = 1;
        } else {
            a = 2;
        }
        if (a > 0) {
            if (a == 1) {
                a = 0;
            } /* missing newline */ } /* end of outer if */ else {
            a = 1;
        }
        if (a == 1)
        {
            a = 0;
        }
        else if (a == 2)
        {
            a = 1;
        }
        else
        {
            a = 2;
        }
      ]])
      feed_command('syntax region Block start="{" end="}" fold contains=Block')
      feed_command('set foldmethod=syntax')
    end)

    it('start', function()
      feed_command('syntax foldlevel start')
      feed_command('syntax sync fromstart')
      feed_command('set foldlevel=0')
      expect_foldclosed({
        -- attached cascade folds together:
        1,1,1,1,1,1,1,
        -- over-attached 'else' hidden:
        8,8,8,8,8,8,
        -- unattached cascade folds separately:
        -1,15,15,15,-1,19,19,19,-1,23,23,23,
        -- last line visible:
        -1
      })
      feed_command('set foldlevel=1')
      -- over-attached 'else' hidden:
      expect_foldclosed({9,9,9,-1}, 9, 12)
    end)

    it('minimum', function()
      feed_command('syntax foldlevel minimum')
      feed_command('syntax sync fromstart')
      feed_command('set foldlevel=0')
      expect_foldclosed({
        -- attached cascade folds separately:
        1,1,3,3,5,5,5,
        -- over-attached 'else' visible:
        8,8,8,11,11,11,
        -- unattached cascade folds separately:
        -1,15,15,15,-1,19,19,19,-1,23,23,23,
        -- last line visible:
        -1
      })
      feed_command('set foldlevel=1')
      -- over-attached 'else' visible:
      expect_foldclosed({9,9,-1,-1}, 9, 12)
    end)
  end)

  describe('foldlevel fails', function()
    it('with bad argument',
    function()
      eq('Vim(syntax):E390: Illegal argument: not_an_option',
         exc_exec('syntax foldlevel not_an_option'))
    end)

    it('with extra argument',
    function()
      eq('Vim(syntax):E390: Illegal argument: start',
         exc_exec('syntax foldlevel start start'))
    end)
  end)
end)
