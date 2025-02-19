-- Test for mappings and abbreviations

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed, insert = n.clear, n.feed, n.insert
local expect, poke_eventloop = n.expect, n.poke_eventloop
local command, eq, eval, api = n.command, t.eq, n.eval, n.api
local exec = n.exec
local sleep = vim.uv.sleep

describe('mapping', function()
  before_each(clear)

  it('abbreviations with р (0x80)', function()
    insert([[
      test starts here:
      ]])

    -- Abbreviations with р (0x80) should work.
    command('inoreab чкпр   vim')
    feed('GAчкпр <esc>')

    expect([[
      test starts here:
      vim ]])
  end)

  -- oldtest: Test_map_ctrl_c_insert()
  it('Ctrl-c works in Insert mode', function()
    -- Mapping of ctrl-c in insert mode
    command('set cpo-=< cpo-=k')
    command('inoremap <c-c> <ctrl-c>')
    command('cnoremap <c-c> dummy')
    command('cunmap <c-c>')
    feed('GA<cr>')
    -- XXX: editor must be in Insert mode before <C-C> is put into input buffer
    poke_eventloop()
    feed('TEST2: CTRL-C |<c-c>A|<cr><esc>')
    command('unmap! <c-c>')

    expect([[

      TEST2: CTRL-C |<ctrl-c>A|
      ]])
  end)

  -- oldtest: Test_map_ctrl_c_visual()
  it('Ctrl-c works in Visual mode', function()
    command([[vnoremap <c-c> :<C-u>$put ='vmap works'<cr>]])
    feed('GV')
    -- XXX: editor must be in Visual mode before <C-C> is put into input buffer
    poke_eventloop()
    feed('vV<c-c>')
    command('vunmap <c-c>')

    expect([[

      vmap works]])
  end)

  it('langmap', function()
    -- langmap should not get remapped in insert mode.
    command('inoremap { FAIL_ilangmap')
    command('set langmap=+{ langnoremap')
    feed('o+<esc>')

    -- Insert mode expr mapping with langmap.
    command('inoremap <expr> { "FAIL_iexplangmap"')
    feed('o+<esc>')

    -- langmap should not get remapped in cmdline mode.
    command('cnoremap { FAIL_clangmap')
    feed('o+<esc>')
    command('cunmap {')

    -- cmdline mode expr mapping with langmap.
    command('cnoremap <expr> { "FAIL_cexplangmap"')
    feed('o+<esc>')
    command('cunmap {')

    -- Assert buffer contents.
    expect([[

      +
      +
      +
      +]])
  end)

  -- oldtest: Test_map_feedkeys()
  it('feedkeys', function()
    insert([[
      a b c d
      a b c d
      ]])

    -- Vim's issue #212 (feedkeys insert mapping at current position)
    command('nnoremap . :call feedkeys(".", "in")<cr>')
    feed('/^a b<cr>')
    feed('0qqdw.ifoo<esc>qj0@q<esc>')
    command('unmap .')
    expect([[
      fooc d
      fooc d
      ]])
  end)

  -- oldtest: Test_map_cursor()
  it('i_CTRL-G_U', function()
    -- <c-g>U<cursor> works only within a single line
    command('imapclear')
    command('imap ( ()<c-g>U<left>')
    feed('G2o<esc>ki<cr>Test1: text with a (here some more text<esc>k.')
    -- test undo
    feed('G2o<esc>ki<cr>Test2: text wit a (here some more text [und undo]<c-g>u<esc>k.u')
    command('imapclear')
    command('set whichwrap=<,>,[,]')
    feed('G3o<esc>2k')
    command(
      [[:exe ":norm! iTest3: text with a (parenthesis here\<C-G>U\<Right>new line here\<esc>\<up>\<up>."]]
    )

    expect([[


      Test1: text with a (here some more text)
      Test1: text with a (here some more text)


      Test2: text wit a (here some more text [und undo])
      new line here
      Test3: text with a (parenthesis here
      new line here
      ]])
  end)

  -- oldtest: Test_mouse_drag_mapped_start_select()
  it('dragging starts Select mode even if coming from mapping', function()
    command('set mouse=a')
    command('set selectmode=mouse')

    command('nnoremap <LeftDrag> <LeftDrag><Cmd><CR>')
    poke_eventloop()
    api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 0, 0, 1)
    poke_eventloop()
    eq('s', eval('mode()'))
  end)

  -- oldtest: Test_mouse_drag_insert_map()
  it('<LeftDrag> mapping in Insert mode works correctly', function()
    command('set mouse=a')

    command('inoremap <LeftDrag> <LeftDrag><Cmd>let g:dragged = 1<CR>')
    feed('i')
    poke_eventloop()
    api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 0, 0, 1)
    poke_eventloop()
    eq(1, eval('g:dragged'))
    eq('v', eval('mode()'))
    feed([[<C-\><C-N>]])

    command([[inoremap <LeftDrag> <LeftDrag><C-\><C-N>]])
    feed('i')
    poke_eventloop()
    api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 0, 0, 1)
    poke_eventloop()
    eq('n', eval('mode()'))
  end)

  -- oldtest: Test_map_after_timed_out_nop()
  it('timeout works after an <Nop> mapping is triggered on timeout', function()
    command('set timeout timeoutlen=400')
    command('inoremap ab TEST')
    command('inoremap a <Nop>')
    -- Enter Insert mode
    feed('i')
    -- Wait for the "a" mapping to time out
    feed('a')
    sleep(500)
    -- Send "a" and wait for a period shorter than 'timeoutlen'
    feed('a')
    sleep(100)
    -- Send "b", should trigger the "ab" mapping
    feed('b')
    expect('TEST')
  end)

  -- oldtest: Test_showcmd_part_map()
  it("'showcmd' with a partial mapping", function()
    local screen = Screen.new(60, 6)
    exec([[
      set notimeout showcmd
      nnoremap ,a <Ignore>
      nnoremap ;a <Ignore>
      nnoremap Àa <Ignore>
      nnoremap Ëa <Ignore>
      nnoremap βa <Ignore>
      nnoremap ωa <Ignore>
      nnoremap …a <Ignore>
      nnoremap <C-W>a <Ignore>
    ]])

    for _, c in ipairs({ ',', ';', 'À', 'Ë', 'β', 'ω', '…' }) do
      feed(c)
      screen:expect(([[
        ^                                                            |
        {1:~                                                           }|*4
                                                         %s          |
      ]]):format(c))
      feed('a')
      screen:expect([[
        ^                                                            |
        {1:~                                                           }|*4
                                                                    |
      ]])
    end

    feed('\23')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
                                                       ^W         |
    ]])
    feed('a')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
                                                                  |
    ]])

    feed('<C-W>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
                                                       ^W         |
    ]])
    feed('a')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
                                                                  |
    ]])
  end)
end)
