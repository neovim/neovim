local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local feed = helpers.feed
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local sleep = helpers.sleep

describe("'pastetoggle' option", function()
  before_each(function()
    clear()
    command('set nopaste')
    command('set pastetoggle=a')
  end)
  it("toggles 'paste'", function()
    eq(eval('&paste'), 0)
    feed('a')
    -- Need another key so that the vgetorpeek() function returns.
    feed('j')
    eq(eval('&paste'), 1)
  end)
  it("multiple key 'pastetoggle' is waited for", function()
    eq(eval('&paste'), 0)
    local pastetoggle = 'lllll'
    command('set pastetoggle=' .. pastetoggle)
    command('set timeoutlen=1 ttimeoutlen=10000')
    feed(pastetoggle:sub(0, 2))
    -- sleep() for long enough that vgetorpeek() is gotten into, but short
    -- enough that ttimeoutlen is not reached.
    sleep(200)
    feed(pastetoggle:sub(3, -1))
    -- Need another key so that the vgetorpeek() function returns.
    feed('j')
    eq(eval('&paste'), 1)
  end)
end)
