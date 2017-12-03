local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local feed = helpers.feed
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local sleep = helpers.sleep
local expect = helpers.expect

describe("'pastetoggle' option", function()
  before_each(function()
    clear()
    command('set nopaste')
  end)

  it("toggles 'paste'", function()
    command('set pastetoggle=a')
    eq(0, eval('&paste'))
    feed('a')
    -- Need another key so that the vgetorpeek() function returns.
    feed('j')
    eq(1, eval('&paste'))
  end)


  it('does not wait for timeout', function()
    command('set pastetoggle=abc')
    command('set ttimeoutlen=9999999')
    eq(0, eval('&paste'))
    -- n.b. need <esc> to return from vgetorpeek()
    feed('abc<esc>')
    eq(1, eval('&paste'))
    feed('ab')
    sleep(10)
    feed('c<esc>')
    expect('bc')
    eq(1, eval('&paste'))
  end)
end)
