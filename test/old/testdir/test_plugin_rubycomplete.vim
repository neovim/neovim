" Tests for the Ruby omni-completion plugin

CheckFeature ruby

" The type of a variable is read from the buffer and was passed to Ruby
" eval(), so "x = EXPR.new" ran EXPR during completion of "x.".
func Test_rubycomplete_no_eval_of_var_type()
  unlet! g:rubycomplete_injected
  new
  setlocal omnifunc=rubycomplete#Complete
  call setline(1, ['x = VIM::command("let\x20g:rubycomplete_injected=1").new',
        \ 'x.'])
  call cursor(2, 1)
  call feedkeys("A\<C-X>\<C-O>\<C-E>\<Esc>", 'tx')

  call assert_false(exists('g:rubycomplete_injected'),
        \ 'buffer text was evaluated during completion')

  unlet! g:rubycomplete_injected
  bw!
endfunc
