local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec = helpers.exec
local command = helpers.command
local feed = helpers.feed
local eq = helpers.eq
local eval = helpers.eval
local poke_eventloop = helpers.poke_eventloop

before_each(clear)

-- oldtest: Test_ChangedP()
it('TextChangedI and TextChangedP autocommands', function()
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
  eq('', eval('g:autocmd'))

  command([[let g:autocmd = '']])
  feed('S')
  poke_eventloop()
  feed('f')
  poke_eventloop()
  eq('I', eval('g:autocmd'))
  feed('<esc>')

  command([[let g:autocmd = '']])
  feed('S')
  poke_eventloop()
  feed('f')
  poke_eventloop()
  feed('<C-N>')
  poke_eventloop()
  eq('IP', eval('g:autocmd'))
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
  eq('IPP', eval('g:autocmd'))
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
  eq('IPPP', eval('g:autocmd'))
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
  eq('IPPPP', eval('g:autocmd'))
  feed('<esc>')

  eq({'foo', 'bar', 'foobar', 'foo'}, eval('getline(1, "$")'))
end)

-- oldtest: Test_TextChangedI_with_setline()
it('TextChangedI with setline()', function()
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

-- oldtest: Test_Changed_ChangedI()
it('TextChangedI and TextChanged', function()
  exec([[
    let [g:autocmd_i, g:autocmd_n] = ['','']

    func! TextChangedAutocmdI(char)
      let g:autocmd_{tolower(a:char)} = a:char .. b:changedtick
    endfunc

    augroup Test_TextChanged
      au!
      au TextChanged  <buffer> :call TextChangedAutocmdI('N')
      au TextChangedI <buffer> :call TextChangedAutocmdI('I')
    augroup END
  ]])

  feed('i')
  poke_eventloop()
  feed('f')
  poke_eventloop()
  feed('o')
  poke_eventloop()
  feed('o')
  poke_eventloop()
  feed('<esc>')
  eq('', eval('g:autocmd_n'))
  eq('I5', eval('g:autocmd_i'))

  command([[call feedkeys("yyp", 'tnix')]])
  eq('N6', eval('g:autocmd_n'))
  eq('I5', eval('g:autocmd_i'))

  -- TextChangedI should only trigger if change was done in Insert mode
  command([[let g:autocmd_i = '']])
  command([[call feedkeys("yypi\<esc>", 'tnix')]])
  eq('', eval('g:autocmd_i'))

  -- TextChanged should only trigger if change was done in Normal mode
  command([[let g:autocmd_n = '']])
  command([[call feedkeys("ibar\<esc>", 'tnix')]])
  eq('', eval('g:autocmd_n'))
end)
