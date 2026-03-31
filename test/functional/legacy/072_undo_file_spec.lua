-- Tests for undo file.
-- Since this script is sourced we need to explicitly break changes up in
-- undo-able pieces.  Do that by setting 'undolevels'.

local n = require('test.functional.testnvim')()

local feed, insert = n.feed, n.insert
local clear, feed_command, expect = n.clear, n.feed_command, n.expect

describe('72', function()
  setup(clear)

  it('is working', function()
    insert([[
      1111 -----
      2222 -----

      123456789]])

    -- Test 'undofile': first a simple one-line change.
    feed_command('set visualbell')
    feed_command('set ul=100 undofile undodir=. nomore')
    feed_command('e! Xtestfile')
    feed('ggdGithis is one line<esc>:set ul=100<cr>')
    feed_command('s/one/ONE/')
    feed_command('set ul=100')
    feed_command('w')
    feed_command('bwipe!')
    feed_command('e Xtestfile')
    feed('u:.w! test.out<cr>')

    -- Test 'undofile', change in original file fails check.
    feed_command('set noundofile')
    feed_command('e! Xtestfile')
    feed_command('s/line/Line/')
    feed_command('w')
    feed_command('set undofile')
    feed_command('bwipe!')
    feed_command('e Xtestfile')
    ---- TODO: this beeps.
    feed('u:.w >>test.out<cr>')

    -- Test 'undofile', add 10 lines, delete 6 lines, undo 3.
    feed_command('set undofile')
    feed('ggdGione<cr>')
    feed('two<cr>')
    feed('three<cr>')
    feed('four<cr>')
    feed('five<cr>')
    feed('six<cr>')
    feed('seven<cr>')
    feed('eight<cr>')
    feed('nine<cr>')
    feed('ten<esc>:set ul=100<cr>')
    feed('3Gdd:set ul=100<cr>')
    feed('dd:set ul=100<cr>')
    feed('dd:set ul=100<cr>')
    feed('dd:set ul=100<cr>')
    feed('dd:set ul=100<cr>')
    feed('dd:set ul=100<cr>')
    feed_command('w')
    feed_command('bwipe!')
    feed_command('e Xtestfile')
    feed('uuu:w >>test.out<cr>')

    -- Test that reading the undofiles when setting undofile works.
    feed_command('set noundofile ul=0')
    feed('i<cr>')
    feed('<esc>u:e! Xtestfile<cr>')
    feed_command('set undofile ul=100')
    feed('uuuuuu:w >>test.out<cr>')

    ---- Open the output to see if it meets the expectations
    feed_command('e! test.out')

    -- Assert buffer contents.
    expect([[
      this is one line
      this is ONE Line
      one
      two
      six
      seven
      eight
      nine
      ten
      one
      two
      three
      four
      five
      six
      seven
      eight
      nine
      ten]])
  end)

  teardown(function()
    os.remove('Xtestfile')
    os.remove('test.out')
    os.remove('.Xtestfile.un~')
  end)
end)
