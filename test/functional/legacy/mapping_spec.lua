-- Test for mappings and abbreviations

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect, wait = helpers.execute, helpers.expect, helpers.wait

describe('mapping', function()
  before_each(clear)

  it('abbreviations with р (0x80)', function()
    insert([[
      test starts here:
      ]])

    -- Abbreviations with р (0x80) should work.
    execute('inoreab чкпр   vim')
    feed('GAчкпр <esc>')

    expect([[
      test starts here:
      vim ]])
  end)

  it('Ctrl-c works in Insert mode', function()
    -- Mapping of ctrl-c in insert mode
    execute('set cpo-=< cpo-=k')
    execute('inoremap <c-c> <ctrl-c>')
    execute('cnoremap <c-c> dummy')
    execute('cunmap <c-c>')
    feed('GA<cr>')
    feed('TEST2: CTRL-C |')
    wait()
    feed('<c-c>A|<cr><esc>')
    wait()
    execute('unmap <c-c>')
    execute('unmap! <c-c>')

    expect([[
      
      TEST2: CTRL-C |<ctrl-c>A|
      ]])
  end)

  it('Ctrl-c works in Visual mode', function()
    execute([[vnoremap <c-c> :<C-u>$put ='vmap works'<cr>]])
    feed('GV')
    -- XXX: For some reason the mapping is only triggered
    -- when <C-c> is in a separate feed command.
    wait()
    feed('<c-c>')
    execute('vunmap <c-c>')

    expect([[
      
      vmap works]])
  end)

  it('langmap', function()
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
      
      +
      +
      +
      +]])
  end)

  it('feedkeys', function()
    insert([[
      a b c d
      a b c d
      ]])

    -- Vim's issue #212 (feedkeys insert mapping at current position)
    execute('nnoremap . :call feedkeys(".", "in")<cr>')
    feed('/^a b<cr>')
    feed('0qqdw.ifoo<esc>qj0@q<esc>')
    execute('unmap .')
    expect([[
      fooc d
      fooc d
      ]])
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
