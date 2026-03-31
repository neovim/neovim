local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec = n.exec
local command = n.command
local feed = n.feed
local eq = t.eq
local neq = t.neq
local eval = n.eval
local poke_eventloop = n.poke_eventloop
local write_file = t.write_file

-- oldtest: Test_ChangedP()
it('TextChangedI and TextChangedP autocommands', function()
  clear()
  -- The oldtest uses feedkeys() with 'x' flag, which never triggers TextChanged.
  -- So don't add TextChanged autocommand here.
  exec([[
    call setline(1, ['foo', 'bar', 'foobar'])
    set complete=. completeopt=menuone
    au! TextChangedI <buffer> let g:autocmd ..= 'I'
    au! TextChangedP <buffer> let g:autocmd ..= 'P'
    call cursor(3, 1)
  ]])

  command([[let g:autocmd = '']])
  feed('o')
  poke_eventloop()
  feed('<esc>')
  -- TextChangedI triggers only if text is actually changed in Insert mode
  eq('I', eval('g:autocmd'))

  command([[let g:autocmd = '']])
  feed('S')
  poke_eventloop()
  feed('f')
  poke_eventloop()
  eq('II', eval('g:autocmd'))
  feed('<esc>')

  command([[let g:autocmd = '']])
  feed('S')
  poke_eventloop()
  feed('f')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  eq('IIP', eval('g:autocmd'))
  feed('<esc>')

  command([[let g:autocmd = '']])
  feed('S')
  poke_eventloop()
  feed('f')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  eq('IIPP', eval('g:autocmd'))
  feed('<esc>')

  command([[let g:autocmd = '']])
  feed('S')
  poke_eventloop()
  feed('f')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  eq('IIPPP', eval('g:autocmd'))
  feed('<esc>')

  command([[let g:autocmd = '']])
  feed('S')
  poke_eventloop()
  feed('f')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  feed('<C-N>')
  eq('IIPPPP', eval('g:autocmd'))
  feed('<esc>')

  eq({ 'foo', 'bar', 'foobar', 'foo' }, eval('getline(1, "$")'))
end)

-- oldtest: Test_TextChangedI_with_setline()
it('TextChangedI with setline()', function()
  clear()
  exec([[
    let g:setline_handled = v:false
    func SetLineOne()
      if !g:setline_handled
        call setline(1, "(x)")
        let g:setline_handled = v:true
      endif
    endfunc
    autocmd TextChangedI <buffer> call SetLineOne()
  ]])

  feed('i')
  poke_eventloop()
  feed('(')
  poke_eventloop()
  feed('<CR>')
  poke_eventloop()
  feed('<Esc>')
  eq('(', eval('getline(1)'))
  eq('x)', eval('getline(2)'))
  command('undo')
  eq('', eval('getline(1)'))
  eq('', eval('getline(2)'))
end)

-- oldtest: Test_TextChanged_with_norm()
it('TextChanged is triggered after :norm that enters Insert mode', function()
  clear()
  exec([[
    let g:a = 0
    au TextChanged * let g:a += 1
  ]])
  eq(0, eval('g:a'))
  feed(':norm! ia<CR>')
  eq(1, eval('g:a'))
end)

-- oldtest: Test_Changed_ChangedI()
it('TextChangedI and TextChanged', function()
  write_file('XTextChangedI2', 'one\ntwo\nthree')
  finally(function()
    os.remove('XTextChangedI2')
  end)
  clear('XTextChangedI2')

  exec([[
    let [g:autocmd_n, g:autocmd_i] = ['','']

    func TextChangedAutocmd(char)
      let g:autocmd_{tolower(a:char)} = a:char .. b:changedtick
    endfunc

    au TextChanged  <buffer> :call TextChangedAutocmd('N')
    au TextChangedI <buffer> :call TextChangedAutocmd('I')

    nnoremap <CR> o<Esc>
  ]])

  -- TextChanged should trigger if a mapping enters and leaves Insert mode.
  feed('<CR>')
  eq('N4', eval('g:autocmd_n'))
  eq('', eval('g:autocmd_i'))

  feed('i')
  eq('N4', eval('g:autocmd_n'))
  eq('', eval('g:autocmd_i'))
  -- TextChangedI should trigger if change is done in Insert mode.
  feed('f')
  eq('N4', eval('g:autocmd_n'))
  eq('I5', eval('g:autocmd_i'))
  feed('o')
  eq('N4', eval('g:autocmd_n'))
  eq('I6', eval('g:autocmd_i'))
  feed('o')
  eq('N4', eval('g:autocmd_n'))
  eq('I7', eval('g:autocmd_i'))
  -- TextChanged shouldn't trigger when leaving Insert mode and TextChangedI
  -- has been triggered.
  feed('<Esc>')
  eq('N4', eval('g:autocmd_n'))
  eq('I7', eval('g:autocmd_i'))

  -- TextChanged should trigger if change is done in Normal mode.
  feed('yyp')
  eq('N8', eval('g:autocmd_n'))
  eq('I7', eval('g:autocmd_i'))

  -- TextChangedI shouldn't trigger if change isn't done in Insert mode.
  feed('i')
  eq('N8', eval('g:autocmd_n'))
  eq('I7', eval('g:autocmd_i'))
  feed('<Esc>')
  eq('N8', eval('g:autocmd_n'))
  eq('I7', eval('g:autocmd_i'))

  -- TextChangedI should trigger if change is a mix of Normal and Insert modes.
  local function validate_mixed_textchangedi(keys)
    feed('ifoo<Esc>')
    command(":let [g:autocmd_n, g:autocmd_i] = ['', '']")
    feed(keys)
    eq('', eval('g:autocmd_n'))
    neq('', eval('g:autocmd_i'))
    feed('<Esc>')
    eq('', eval('g:autocmd_n'))
    neq('', eval('g:autocmd_i'))
  end

  validate_mixed_textchangedi('o')
  validate_mixed_textchangedi('O')
  validate_mixed_textchangedi('ciw')
  validate_mixed_textchangedi('cc')
  validate_mixed_textchangedi('C')
  validate_mixed_textchangedi('s')
  validate_mixed_textchangedi('S')
end)
