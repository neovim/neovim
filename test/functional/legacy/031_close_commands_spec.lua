-- Test for commands that close windows and/or buffers
-- :quit
-- :close
-- :hide
-- :only
-- :sall
-- :all
-- :ball
-- :buf
-- :edit

local t = require('test.functional.testutil')(after_each)

local feed = t.feed
local clear = t.clear
local source = t.source
local insert = t.insert
local expect = t.expect
local feed_command = t.feed_command
local expect_exit = t.expect_exit

describe('Commands that close windows and/or buffers', function()
  local function cleanup()
    os.remove('Xtest1')
    os.remove('Xtest2')
    os.remove('Xtest3')
  end
  setup(function()
    cleanup()
    clear()
  end)
  teardown(function()
    cleanup()
  end)

  it('is working', function()
    insert('testtext')

    feed('GA 1<Esc>:$w! Xtest1<CR>')
    feed('$r2:$w! Xtest2<CR>')
    feed('$r3:$w! Xtest3<CR>')
    feed_command('n! Xtest1 Xtest2')
    feed('A 1<Esc>:set hidden<CR>')

    -- Test for working :n when hidden set
    feed_command('n')
    expect('testtext 2')

    -- Test for failing :rew when hidden not set
    feed_command('set nohidden')
    feed('A 2<Esc>:rew<CR>')
    expect('testtext 2 2')

    -- Test for working :rew when hidden set
    feed_command('set hidden')
    feed_command('rew')
    expect('testtext 1 1')

    -- Test for :all keeping a buffer when it's modified
    feed_command('set nohidden')
    feed('A 1<Esc>:sp<CR>')
    feed_command('n Xtest2 Xtest3')
    feed_command('all')
    feed_command('1wincmd w')
    expect('testtext 1 1 1')

    -- Test abandoning changed buffer, should be unloaded even when 'hidden' set
    feed_command('set hidden')
    feed('A 1<Esc>:q!<CR>')
    expect('testtext 2 2')
    feed_command('unhide')
    expect('testtext 2 2')

    -- Test ":hide" hides anyway when 'hidden' not set
    feed_command('set nohidden')
    feed('A 2<Esc>:hide<CR>')
    expect('testtext 3')

    -- Test ":edit" failing in modified buffer when 'hidden' not set
    feed('A 3<Esc>:e Xtest1<CR>')
    expect('testtext 3 3')

    -- Test ":edit" working in modified buffer when 'hidden' set
    feed_command('set hidden')
    feed_command('e Xtest1')
    expect('testtext 1')

    -- Test ":close" not hiding when 'hidden' not set in modified buffer
    feed_command('sp Xtest3')
    feed_command('set nohidden')
    feed('A 3<Esc>:close<CR>')
    expect('testtext 3 3 3')

    -- Test ":close!" does hide when 'hidden' not set in modified buffer
    feed('A 3<Esc>:close!<CR>')
    feed_command('set nohidden')
    expect('testtext 1')

    -- Test ":all!" hides changed buffer
    feed_command('sp Xtest4')
    feed('GA 4<Esc>:all!<CR>')
    feed_command('1wincmd w')
    expect('testtext 2 2 2')

    -- Test ":q!" and hidden buffer.
    feed_command('bw! Xtest1 Xtest2 Xtest3 Xtest4')
    feed_command('sp Xtest1')
    feed_command('wincmd w')
    feed_command('bw!')
    feed_command('set modified')
    feed_command('bot sp Xtest2')
    feed_command('set modified')
    feed_command('bot sp Xtest3')
    feed_command('set modified')
    feed_command('wincmd t')
    feed_command('hide')
    feed_command('q!')
    expect('testtext 3')
    feed_command('q!')
    feed('<CR>')
    expect('testtext 1')
    expect_exit(
      source,
      [[
      q!
      " Now nvim should have exited
      throw "Oh, Not finished yet."]]
    )
  end)
end)
