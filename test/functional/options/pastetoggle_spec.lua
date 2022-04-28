local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local feed = helpers.feed
local command = helpers.command
local eq = helpers.eq
local expect = helpers.expect
local eval = helpers.eval
local insert = helpers.insert
local meths = helpers.meths
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
  describe("multiple key 'pastetoggle'", function()
    before_each(function()
      eq(0, eval('&paste'))
      command('set timeoutlen=1 ttimeoutlen=10000')
    end)
    it('is waited for when chars are typed', function()
      local pastetoggle = 'lllll'
      command('set pastetoggle=' .. pastetoggle)
      feed(pastetoggle:sub(0, 2))
      -- sleep() for long enough that vgetorpeek() is gotten into, but short
      -- enough that ttimeoutlen is not reached.
      sleep(200)
      feed(pastetoggle:sub(3, -1))
      -- Need another key so that the vgetorpeek() function returns.
      feed('j')
      eq(1, eval('&paste'))
    end)

    it('is not waited for when there are no typed chars after mapped chars', function()
      command('set pastetoggle=abc')
      command('imap d a')
      meths.feedkeys('id', 't', true)
      -- sleep() for long enough that vgetorpeek() is gotten into, but short
      -- enough that ttimeoutlen is not reached.
      sleep(200)
      feed('bc')
      -- Need another key so that the vgetorpeek() function returns.
      feed('j')
      -- 'ttimeoutlen' should NOT apply
      eq(0, eval('&paste'))
    end)

    it('is waited for when there are typed chars after mapped chars', function()
      command('set pastetoggle=abc')
      command('imap d a')
      meths.feedkeys('idb', 't', true)
      -- sleep() for long enough that vgetorpeek() is gotten into, but short
      -- enough that ttimeoutlen is not reached.
      sleep(200)
      feed('c')
      -- Need another key so that the vgetorpeek() function returns.
      feed('j')
      -- 'ttimeoutlen' should apply
      eq(1, eval('&paste'))
    end)

    it('is waited for when there are typed chars after noremapped chars', function()
      command('set pastetoggle=abc')
      command('inoremap d a')
      meths.feedkeys('idb', 't', true)
      -- sleep() for long enough that vgetorpeek() is gotten into, but short
      -- enough that ttimeoutlen is not reached.
      sleep(200)
      feed('c')
      -- Need another key so that the vgetorpeek() function returns.
      feed('j')
      -- 'ttimeoutlen' should apply
      eq(1, eval('&paste'))
    end)
  end)
  it('does not interfere with character-find', function()
    insert('foo,bar')
    feed('0')
    command('set pastetoggle=,sp')
    feed('dt,')
    expect(',bar')
  end)
end)
