-- Test for mappings and abbreviations

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local feed_command, expect, wait = helpers.feed_command, helpers.expect, helpers.wait

describe('mapping', function()
  before_each(clear)

  it('abbreviations with р (0x80)', function()
    insert([[
      test starts here:
      ]])

    -- Abbreviations with р (0x80) should work.
    feed_command('inoreab чкпр   vim')
    feed('GAчкпр <esc>')

    expect([[
      test starts here:
      vim ]])
  end)

  it('Ctrl-c works in Insert mode', function()
    -- Mapping of ctrl-c in insert mode
    feed_command('set cpo-=< cpo-=k')
    feed_command('inoremap <c-c> <ctrl-c>')
    feed_command('cnoremap <c-c> dummy')
    feed_command('cunmap <c-c>')
    feed('GA<cr>')
    feed('TEST2: CTRL-C |')
    wait()
    feed('<c-c>A|<cr><esc>')
    wait()
    feed_command('unmap <c-c>')
    feed_command('unmap! <c-c>')

    expect([[

      TEST2: CTRL-C |<ctrl-c>A|
      ]])
  end)

  it('Ctrl-c works in Visual mode', function()
    feed_command([[vnoremap <c-c> :<C-u>$put ='vmap works'<cr>]])
    feed('GV')
    -- XXX: For some reason the mapping is only triggered
    -- when <C-c> is in a separate feed command.
    wait()
    feed('<c-c>')
    feed_command('vunmap <c-c>')

    expect([[

      vmap works]])
  end)

  it('langmap', function()
    -- langmap should not get remapped in insert mode.
    feed_command('inoremap { FAIL_ilangmap')
    feed_command('set langmap=+{ langnoremap')
    feed('o+<esc>')

    -- Insert mode expr mapping with langmap.
    feed_command('inoremap <expr> { "FAIL_iexplangmap"')
    feed('o+<esc>')

    -- langmap should not get remapped in cmdline mode.
    feed_command('cnoremap { FAIL_clangmap')
    feed('o+<esc>')
    feed_command('cunmap {')

    -- cmdline mode expr mapping with langmap.
    feed_command('cnoremap <expr> { "FAIL_cexplangmap"')
    feed('o+<esc>')
    feed_command('cunmap {')

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
    feed_command('nnoremap . :call feedkeys(".", "in")<cr>')
    feed('/^a b<cr>')
    feed('0qqdw.ifoo<esc>qj0@q<esc>')
    feed_command('unmap .')
    expect([[
      fooc d
      fooc d
      ]])
  end)

  it('i_CTRL-G_U', function()
    -- <c-g>U<cursor> works only within a single line
    feed_command('imapclear')
    feed_command('imap ( ()<c-g>U<left>')
    feed('G2o<esc>ki<cr>Test1: text with a (here some more text<esc>k.')
    -- test undo
    feed('G2o<esc>ki<cr>Test2: text wit a (here some more text [und undo]<c-g>u<esc>k.u')
    feed_command('imapclear')
    feed_command('set whichwrap=<,>,[,]')
    feed('G3o<esc>2k')
    feed_command([[:exe ":norm! iTest3: text with a (parenthesis here\<C-G>U\<Right>new line here\<esc>\<up>\<up>."]])

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
