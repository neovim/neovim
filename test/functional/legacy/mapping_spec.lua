-- Test for mappings and abbreviations

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('mapping', function()
  before_each(clear)

  it('is working', function()
    insert([[
      test starts here:
      ]])

    -- Abbreviations with р (0x80) should work.
    execute('inoreab чкпр   vim')
    feed('GAчкпр <esc>')

    -- langmap should not get remapped in insert mode.
    execute('inoremap { FAIL_ilangmap')
    execute('set langmap=+{ langnoremap')
    feed('o+<esc>')

    -- Insert mode expr mapping with langmap.
    execute('inoremap <expr> { "FAIL_iexplangmap"')
    feed('o+<esc>')

    -- langmap should not get remapped in cmdline mode.
    execute('cnoremap { FAIL_clangmap')
    feed('o+<esc>')
    execute('cunmap {')

    -- cmdline mode expr mapping with langmap.
    execute('cnoremap <expr> { "FAIL_cexplangmap"')
    feed('o+<esc>')
    execute('cunmap {')

    -- Assert buffer contents.
    expect([[
      test starts here:
      vim 
      +
      +
      +
      +]])
  end)

  it('i_CTRL-G_U', function()
    -- <c-g>U<cursor> works only within a single line
    execute('imapclear')
    execute('imap ( ()<c-g>U<left>')
    feed('G2o<esc>ki<cr>Test1: text with a (here some more text<esc>k.')
    -- test undo
    feed('G2o<esc>ki<cr>Test2: text wit a (here some more text [und undo]<c-g>u<esc>k.u')
    execute('imapclear')
    execute('set whichwrap=<,>,[,]')
    feed('G3o<esc>2k')
    execute([[:exe ":norm! iTest3: text with a (parenthesis here\<C-G>U\<Right>new line here\<esc>\<up>\<up>."]])

    expect([[
      
      
      Test1: text with a (here some more text)
      Test1: text with a (here some more text)
      
      
      Test2: text wit a (here some more text [und undo])
      new line here
      Test3: text with a (parenthesis here
      new line here
      ]])
  end)
end)
