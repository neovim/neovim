" Test insert mode completion does not get stuck when looping around.
" In a separate file to avoid the settings to leak to other test cases.

set complete+=kspell
set completeopt+=menu
set completeopt+=menuone
set completeopt+=noselect
set completeopt+=noinsert
let g:autocompletion = v:true

func Test_ins_complete_no_halt()
  function! OpenCompletion()
    if pumvisible() && (g:autocompletion == v:true)
      call feedkeys("\<C-e>\<C-n>", "i")
      return
    endif
    if ((v:char >= 'a' && v:char <= 'z') || (v:char >= 'A' && v:char <= 'Z')) && (g:autocompletion == v:true)
      call feedkeys("\<C-n>", "i")
      redraw
    endif
  endfunction

  autocmd InsertCharPre * noautocmd call OpenCompletion()

  setlocal spell! spelllang=en_us

  call feedkeys("iauto-complete-halt-test test test test test test test test test test test test test test test test test test test\<C-c>", "tx!")
  call assert_equal(["auto-complete-halt-test test test test test test test test test test test test test test test test test test test"], getline(1, "$"))
endfunc

func Test_auto_complete_backwards_no_halt()
  function! OpenCompletion()
    if pumvisible() && (g:autocompletion == v:true)
      call feedkeys("\<C-e>\<C-p>", "i")
      return
    endif
    if ((v:char >= 'a' && v:char <= 'z') || (v:char >= 'A' && v:char <= 'Z')) && (g:autocompletion == v:true)
      call feedkeys("\<C-p>", "i")
      redraw
    endif
  endfunction

  autocmd InsertCharPre * noautocmd call OpenCompletion()

  setlocal spell! spelllang=en_us

  call feedkeys("iauto-complete-halt-test test test test test test test test test test test test test test test test test test test\<C-c>", "tx!")
  call assert_equal(["auto-complete-halt-test test test test test test test test test test test test test test test test test test test"], getline(1, "$"))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
