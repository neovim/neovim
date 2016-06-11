-- Tests for undo file.
-- Since this script is sourced we need to explicitly break changes up in
-- undo-able pieces.  Do that by setting 'undolevels'.

local helpers = require('test.functional.helpers')(after_each)
local feed, insert = helpers.feed, helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('72', function()
  setup(clear)

  it('is working', function()
    insert([[
      1111 -----
      2222 -----
      
      123456789]])

    -- Test 'undofile': first a simple one-line change.
    execute('set visualbell')
    execute('set ul=100 undofile undodir=. nomore')
    execute('e! Xtestfile')
    feed('ggdGithis is one line<esc>:set ul=100<cr>')
    execute('s/one/ONE/')
    execute('set ul=100')
    execute('w')
    execute('bwipe!')
    execute('e Xtestfile')
    feed('u:.w! test.out<cr>')

    -- Test 'undofile', change in original file fails check.
    execute('set noundofile')
    execute('e! Xtestfile')
    execute('s/line/Line/')
    execute('w')
    execute('set undofile')
    execute('bwipe!')
    execute('e Xtestfile')
    ---- TODO: this beeps.
    feed('u:.w >>test.out<cr>')

    -- Test 'undofile', add 10 lines, delete 6 lines, undo 3.
    execute('set undofile')
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
    execute('w')
    execute('bwipe!')
    execute('e Xtestfile')
    feed('uuu:w >>test.out<cr>')

    -- Test that reading the undofiles when setting undofile works.
    execute('set noundofile ul=0')
    feed('i<cr>')
    feed('<esc>u:e! Xtestfile<cr>')
    execute('set undofile ul=100')
    feed('uuuuuu:w >>test.out<cr>')

    ---- Open the output to see if it meets the expections
    execute('e! test.out')

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
