local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local feed = helpers.feed
local command = helpers.command
local eq = helpers.eq
local expect = helpers.expect
local eval = helpers.eval
local insert = helpers.insert
local sleep = helpers.sleep

describe("'pastetoggle' option", function()
  before_each(clear)
  it("toggles 'paste'", function()
    command('set pastetoggle=a')
    eq(0, eval('&paste'))
    feed('a')
    -- Need another key so that the vgetorpeek() function returns.
    feed('j')
    eq(1, eval('&paste'))
  end)
  it("multiple key 'pastetoggle' is waited for", function()
    eq(0, eval('&paste'))
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
    eq(1, eval('&paste'))
  end)
  it('does not interfere with character-find', function()
    insert('foo,bar')
    feed('0')
    command('set pastetoggle=,sp')
    feed('dt,')
    expect(',bar')
  end)
end)
