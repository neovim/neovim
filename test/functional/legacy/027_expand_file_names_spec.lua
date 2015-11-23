-- Test for expanding file names

local helpers = require('test.functional.helpers')
local clear, feed = helpers.clear, helpers.feed
local execute = helpers.execute
local curbuf_contents = helpers.curbuf_contents
local eq = helpers.eq

describe('expand file name', function()
  setup(clear)

  it('is working', function()
    execute('!mkdir Xdir1')
    execute('!mkdir Xdir2')
    execute('!mkdir Xdir3')
    execute('cd Xdir3')
    execute('!mkdir Xdir4')
    execute('cd ..')
    execute('w Xdir1/file')
    execute('w Xdir3/Xdir4/file')
    execute('n Xdir?/*/file')

    -- Yank current file path to @a register
    feed('i<C-R>%<Esc>V"ad')

    -- Put @a and current file path in the current buffer
    execute('n! Xdir?/*/nofile')
    feed('V"ap')
    feed('o<C-R>%<Esc>')

    eq("Xdir3/Xdir4/file\nXdir?/*/nofile", curbuf_contents())
  end)

  teardown(function()
    os.execute('rm -rf Xdir1 Xdir2 Xdir3')
  end)
end)
