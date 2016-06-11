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

local helpers = require('test.functional.helpers')(after_each)

local feed = helpers.feed
local clear = helpers.clear
local source = helpers.source
local insert = helpers.insert
local expect = helpers.expect
local execute = helpers.execute

describe('Commands that close windows and/or buffers', function()
  setup(clear)

  it('is working', function()
    insert('testtext')

    feed('GA 1<Esc>:$w! Xtest1<CR>')
    feed('$r2:$w! Xtest2<CR>')
    feed('$r3:$w! Xtest3<CR>')
    execute('n! Xtest1 Xtest2')
    feed('A 1<Esc>:set hidden<CR>')

    -- Test for working :n when hidden set
    execute('n')
    expect('testtext 2')

    -- Test for failing :rew when hidden not set
    execute('set nohidden')
    feed('A 2<Esc>:rew<CR>')
    expect('testtext 2 2')

    -- Test for working :rew when hidden set
    execute('set hidden')
    execute('rew')
    expect('testtext 1 1')

    -- Test for :all keeping a buffer when it's modified
    execute('set nohidden')
    feed('A 1<Esc>:sp<CR>')
    execute('n Xtest2 Xtest3')
    execute('all')
    execute('1wincmd w')
    expect('testtext 1 1 1')

    -- Test abandoning changed buffer, should be unloaded even when 'hidden' set
    execute('set hidden')
    feed('A 1<Esc>:q!<CR>')
    expect('testtext 2 2')
    execute('unhide')
    expect('testtext 2 2')

    -- Test ":hide" hides anyway when 'hidden' not set
    execute('set nohidden')
    feed('A 2<Esc>:hide<CR>')
    expect('testtext 3')

    -- Test ":edit" failing in modified buffer when 'hidden' not set
    feed('A 3<Esc>:e Xtest1<CR>')
    expect('testtext 3 3')

    -- Test ":edit" working in modified buffer when 'hidden' set
    execute('set hidden')
    execute('e Xtest1')
    expect('testtext 1')

    -- Test ":close" not hiding when 'hidden' not set in modified buffer
    execute('sp Xtest3')
    execute('set nohidden')
    feed('A 3<Esc>:close<CR>')
    expect('testtext 3 3 3')

    -- Test ":close!" does hide when 'hidden' not set in modified buffer
    feed('A 3<Esc>:close!<CR>')
    execute('set nohidden')
    expect('testtext 1')

    -- Test ":all!" hides changed buffer
    execute('sp Xtest4')
    feed('GA 4<Esc>:all!<CR>')
    execute('1wincmd w')
    expect('testtext 2 2 2')

    -- Test ":q!" and hidden buffer.
    execute('bw! Xtest1 Xtest2 Xtest3 Xtest4')
    execute('sp Xtest1')
    execute('wincmd w')
    execute('bw!')
    execute('set modified')
    execute('bot sp Xtest2')
    execute('set modified')
    execute('bot sp Xtest3')
    execute('set modified')
    execute('wincmd t')
    execute('hide')
    execute('q!')
    expect('testtext 3')
    execute('q!')
    feed('<CR>')
    expect('testtext 1')
    source([[
      q!
      " Now nvim should have exited
      throw "Oh, Not finished yet."]])
  end)

  teardown(function()
    os.remove('Xtest1')
    os.remove('Xtest2')
    os.remove('Xtest3')
  end)
end)
