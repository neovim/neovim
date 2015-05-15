-- Tests for correct display (cursor column position) with +conceal and
-- tabulators.

local helpers = require('test.functional.helpers')
local feed, insert, eq, eval = helpers.feed, helpers.insert, helpers.eq, helpers.eval
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('cursor and column position with conceal and tabulators', function()
  setup(clear)

  it('are working', function()
    insert([[
      start:
      .concealed.     text
      |concealed|	text
      
      	.concealed.	text
      	|concealed|	text
      
      .a.	.b.	.c.	.d.
      |a|	|b|	|c|	|d|]])

    -- Conceal settings.
    execute('set conceallevel=2')
    execute('set concealcursor=nc')
    execute('syntax match test /|/ conceal')
    -- Save current cursor position. Only works in <expr> mode, can't be used
    -- with :normal because it moves the cursor to the command line. Thanks to
    -- ZyX <zyx.vim@gmail.com> for the idea to use an <expr> mapping.
    execute('let positions = []')
    execute([[nnoremap <expr> GG ":let positions += ['".screenrow().":".screencol()."']\n"]])
    -- Start test.
    execute('/^start:')
    feed('ztj')
    feed('GG')
    -- We should end up in the same column when running these commands on the
    -- two lines.
    execute('normal ft')
    feed('GG')
    feed('$')
    feed('GG')
    feed('0j')
    feed('GG')
    execute('normal ft')
    feed('GG')
    feed('$')
    feed('GG')
    feed('j0j')
    feed('GG')
    -- Same for next test block.
    execute('normal ft')
    feed('GG')
    feed('$')
    feed('GG')
    feed('0j')
    feed('GG')
    execute('normal ft')
    feed('GG')
    feed('$')
    feed('GG')
    feed('0j0j')
    feed('GG')
    -- And check W with multiple tabs and conceals in a line.
    feed('W')
    feed('GG')
    feed('W')
    feed('GG')
    feed('W')
    feed('GG')
    feed('$')
    feed('GG')
    feed('0j')
    feed('GG')
    feed('W')
    feed('GG')
    feed('W')
    feed('GG')
    feed('W')
    feed('GG')
    feed('$')
    feed('GG')
    execute('set lbr')
    feed('$')
    feed('GG')
    -- Display result.
    execute([[call append('$', 'end:')]])
    execute([[call append('$', positions)]])
    execute('0,/^end/-1 d')

    -- Assert buffer contents.
    expect([[
      end:
      2:1
      2:17
      2:20
      3:1
      3:17
      3:20
      5:8
      5:25
      5:28
      6:8
      6:25
      6:28
      8:1
      8:9
      8:17
      8:25
      8:27
      9:1
      9:9
      9:17
      9:25
      9:26
      9:26]])
  end)
end)
