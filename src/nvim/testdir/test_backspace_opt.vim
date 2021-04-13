" Tests for 'backspace' settings

func Test_backspace_option()
  set backspace=
  call assert_equal('', &backspace)
  set backspace=indent
  call assert_equal('indent', &backspace)
  set backspace=eol
  call assert_equal('eol', &backspace)
  set backspace=start
  call assert_equal('start', &backspace)
  set backspace=nostop
  call assert_equal('nostop', &backspace)
  " Add the value
  set backspace=
  set backspace=indent
  call assert_equal('indent', &backspace)
  set backspace+=eol
  call assert_equal('indent,eol', &backspace)
  set backspace+=start
  call assert_equal('indent,eol,start', &backspace)
  set backspace+=nostop
  call assert_equal('indent,eol,start,nostop', &backspace)
  " Delete the value
  set backspace-=nostop
  call assert_equal('indent,eol,start', &backspace)
  set backspace-=indent
  call assert_equal('eol,start', &backspace)
  set backspace-=start
  call assert_equal('eol', &backspace)
  set backspace-=eol
  call assert_equal('', &backspace)
  " Check the error
  call assert_fails('set backspace=ABC', 'E474:')
  call assert_fails('set backspace+=def', 'E474:')
  " NOTE: Vim doesn't check following error...
  "call assert_fails('set backspace-=ghi', 'E474:')

  " Check backwards compatibility with version 5.4 and earlier
  set backspace=0
  call assert_equal('0', &backspace)
  set backspace=1
  call assert_equal('1', &backspace)
  set backspace=2
  call assert_equal('2', &backspace)
  set backspace=3
  call assert_equal('3', &backspace)
  call assert_fails('set backspace=4', 'E474:')
  call assert_fails('set backspace=10', 'E474:')

  " Cleared when 'compatible' is set
  " set compatible
  " call assert_equal('', &backspace)
  set nocompatible viminfo+=nviminfo
endfunc

" Test with backspace set to the non-compatible setting
func Test_backspace_ctrl_u()
  new
  call append(0,  [
        \ "1 this shouldn't be deleted",
        \ "2 this shouldn't be deleted",
        \ "3 this shouldn't be deleted",
        \ "4 this should be deleted",
        \ "5 this shouldn't be deleted",
        \ "6 this shouldn't be deleted",
        \ "7 this shouldn't be deleted",
        \ "8 this shouldn't be deleted (not touched yet)"])
  call cursor(2, 1)

  " set compatible
  set backspace=2

  exe "normal Avim1\<C-U>\<Esc>\<CR>"
  exe "normal Avim2\<C-G>u\<C-U>\<Esc>\<CR>"

  set cpo-=<
  inoremap <c-u> <left><c-u>
  exe "normal Avim3\<C-U>\<Esc>\<CR>"
  iunmap <c-u>
  exe "normal Avim4\<C-U>\<C-U>\<Esc>\<CR>"

  " Test with backspace set to the compatible setting
  set backspace= visualbell
  exe "normal A vim5\<Esc>A\<C-U>\<C-U>\<Esc>\<CR>"
  exe "normal A vim6\<Esc>Azwei\<C-G>u\<C-U>\<Esc>\<CR>"

  inoremap <c-u> <left><c-u>
  exe "normal A vim7\<C-U>\<C-U>\<Esc>\<CR>"

  call assert_equal([
        \ "1 this shouldn't be deleted",
        \ "2 this shouldn't be deleted",
        \ "3 this shouldn't be deleted",
        \ "4 this should be deleted3",
        \ "",
        \ "6 this shouldn't be deleted vim5",
        \ "7 this shouldn't be deleted vim6",
        \ "8 this shouldn't be deleted (not touched yet) vim7",
        \ ""], getline(1, '$'))

  " Reset values
  set compatible&vim
  set visualbell&vim
  set backspace&vim

  " Test new nostop option
  %d_
  let expected = "foo bar foobar"
  call setline(1, expected)
  call cursor(1, 8)
  exe ":norm! ianotherone\<c-u>"
  call assert_equal(expected, getline(1))
  call cursor(1, 8)
  exe ":norm! ianothertwo\<c-w>"
  call assert_equal(expected, getline(1))

  let content = getline(1)
  for value in ['indent,nostop', 'eol,nostop', 'indent,eol,nostop', 'indent,eol,start,nostop']
    exe ":set bs=".. value
    %d _
    call setline(1, content)
    let expected = " foobar"
    call cursor(1, 8)
    exe ":norm! ianotherone\<c-u>"
    call assert_equal(expected, getline(1), 'CTRL-U backspace value: '.. &bs)
    let expected = "foo  foobar"
    call setline(1, content)
    call cursor(1, 8)
    exe ":norm! ianothertwo\<c-w>"
    call assert_equal(expected, getline(1), 'CTRL-W backspace value: '.. &bs)
  endfor

  " Reset options
  set compatible&vim
  set visualbell&vim
  set backspace&vim
  close!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
