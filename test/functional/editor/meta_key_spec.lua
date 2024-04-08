local t = require('test.functional.testutil')(after_each)
local clear, feed, insert = t.clear, t.feed, t.insert
local command = t.command
local exec_lua = t.exec_lua
local eval = t.eval
local expect = t.expect
local fn = t.fn
local eq = t.eq

describe('meta-keys #8226 #13042', function()
  before_each(function()
    clear()
  end)

  it('ALT/META, normal-mode', function()
    -- Unmapped ALT-chord behaves as ESC+c.
    insert('hello')
    feed('0<A-x><M-x>')
    expect('llo')
    -- Unmapped ALT-chord resolves isolated (non-ALT) ESC mapping. #13086 #15869
    command('nnoremap <ESC> A<lt>ESC><Esc>')
    command('nnoremap ; A;<Esc>')
    feed('<A-;><M-;>')
    expect('llo<ESC>;<ESC>;')
    -- Mapped ALT-chord behaves as mapped.
    command('nnoremap <M-l> Ameta-l<Esc>')
    command('nnoremap <A-j> Aalt-j<Esc>')
    feed('<A-j><M-l>')
    expect('llo<ESC>;<ESC>;alt-jmeta-l')
    -- Unmapped ALT-chord with characters containing K_SPECIAL bytes
    command('nnoremap … A…<Esc>')
    feed('<A-…><M-…>')
    expect('llo<ESC>;<ESC>;alt-jmeta-l<ESC>…<ESC>…')
    command("execute 'nnoremap' nr2char(0x40000000) 'AMAX<Esc>'")
    command("call nvim_input('<A-'.nr2char(0x40000000).'>')")
    command("call nvim_input('<M-'.nr2char(0x40000000).'>')")
    expect('llo<ESC>;<ESC>;alt-jmeta-l<ESC>…<ESC>…<ESC>MAX<ESC>MAX')
  end)

  it('ALT/META, visual-mode', function()
    -- Unmapped ALT-chords behave as ESC+c
    insert('peaches')
    feed('viw<A-x>viw<M-x>')
    expect('peach')
    -- Unmapped ALT-chord resolves isolated (non-ALT) ESC mapping. #13086 #15869
    command('vnoremap <ESC> A<lt>ESC>')
    feed('viw<A-;><Esc>viw<M-;><Esc>')
    expect('peach<ESC>;<ESC>;')
    -- Mapped ALT-chord behaves as mapped.
    command('vnoremap <M-l> Ameta-l<Esc>')
    command('vnoremap <A-j> Aalt-j<Esc>')
    feed('viw<A-j>viw<M-l>')
    expect('peach<ESC>;<ESC>;alt-jmeta-l')
    -- Unmapped ALT-chord with characters containing K_SPECIAL bytes
    feed('viw<A-…><Esc>viw<M-…><Esc>')
    expect('peach<ESC>;<ESC>;alt-jmeta-l<ESC>…<ESC>…')
    command("execute 'inoremap' nr2char(0x40000000) 'MAX'")
    command("call nvim_input('viw<A-'.nr2char(0x40000000).'><Esc>')")
    command("call nvim_input('viw<M-'.nr2char(0x40000000).'><Esc>')")
    expect('peach<ESC>;<ESC>;alt-jmeta-l<ESC>…<ESC>…<ESC>MAX<ESC>MAX')
  end)

  it('ALT/META insert-mode', function()
    -- Mapped ALT-chord behaves as mapped.
    command('inoremap <M-l> meta-l')
    command('inoremap <A-j> alt-j')
    feed('i<M-l> xxx <A-j><M-h>a<A-h>')
    expect('meta-l xxx alt-j')
    eq({ 0, 1, 14, 0 }, fn.getpos('.'))
    -- Unmapped ALT-chord behaves as ESC+c.
    command('iunmap <M-l>')
    feed('0i<M-l>')
    eq({ 0, 1, 2, 0 }, fn.getpos('.'))
    -- Unmapped ALT-chord has same `undo` characteristics as ESC+<key>
    command('0,$d')
    feed('ahello<M-.>')
    expect('hellohello')
    feed('u')
    expect('hello')
  end)

  it('ALT/META terminal-mode', function()
    exec_lua([[
      _G.input_data = ''
      vim.api.nvim_open_term(0, { on_input = function(_, _, _, data)
        _G.input_data = _G.input_data .. vim.fn.strtrans(data)
      end })
    ]])
    -- Mapped ALT-chord behaves as mapped.
    command('tnoremap <M-l> meta-l')
    command('tnoremap <A-j> alt-j')
    feed('i<M-l> xxx <A-j>')
    eq('meta-l xxx alt-j', exec_lua([[return _G.input_data]]))
    -- Unmapped ALT-chord is sent to terminal as-is. #16202 #16220
    exec_lua([[_G.input_data = '']])
    command('tunmap <M-l>')
    feed('<M-l>')
    local meta_l_seq = exec_lua([[return _G.input_data]])
    command('tnoremap <Esc> <C-\\><C-N>')
    feed('yyy<M-l><A-j>')
    eq(meta_l_seq .. 'yyy' .. meta_l_seq .. 'alt-j', exec_lua([[return _G.input_data]]))
    eq('t', eval('mode(1)'))
    feed('<Esc>j')
    eq({ 0, 2, 1, 0 }, fn.getpos('.'))
    eq('nt', eval('mode(1)'))
  end)

  it('ALT/META when recording a macro #13235', function()
    command('inoremap <M-Esc> <lt>M-ESC>')
    feed('ifoo<CR>bar<CR>baz<Esc>gg0')
    -- <M-"> is reinterpreted as <Esc>"
    feed('qrviw"ayC// This is some text: <M-">apq')
    expect([[
      // This is some text: foo
      bar
      baz]])
    -- Should not insert an extra double quote or trigger <M-Esc> when replaying
    feed('j0@rj0@@')
    expect([[
      // This is some text: foo
      // This is some text: bar
      // This is some text: baz]])
    command('%delete')
  end)

  it('ALT/META with special key when recording a macro', function()
    command('inoremap <M-Esc> <lt>M-ESC>')
    command('noremap <S-Tab> "')
    command('noremap! <S-Tab> "')
    feed('ifoo<CR>bar<CR>baz<Esc>gg0')
    -- <M-S-Tab> is reinterpreted as <Esc><S-Tab>
    feed('qrviw<S-Tab>ayC// This is some text: <M-S-Tab>apq')
    expect([[
      // This is some text: foo
      bar
      baz]])
    -- Should not insert an extra double quote or trigger <M-Esc> when replaying
    feed('j0@rj0@@')
    expect([[
      // This is some text: foo
      // This is some text: bar
      // This is some text: baz]])
  end)

  it('ALT/META with vim.on_key()', function()
    feed('ifoo<CR>bar<CR>baz<Esc>gg0')

    exec_lua [[
      keys = {}
      typed = {}

      vim.on_key(function(buf, typed_buf)
        table.insert(keys, vim.fn.keytrans(buf))
        table.insert(typed, vim.fn.keytrans(typed_buf))
      end)
    ]]

    -- <M-"> is reinterpreted as <Esc>"
    feed('qrviw"ayc$FOO.<M-">apq')
    expect([[
      FOO.foo
      bar
      baz]])

    -- vim.on_key() callback should only receive <Esc>"
    eq('qrviw"ayc$FOO.<Esc>"apq', exec_lua [[return table.concat(keys, '')]])
    eq('qrviw"ayc$FOO.<Esc>"apq', exec_lua [[return table.concat(typed, '')]])
  end)
end)
