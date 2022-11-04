" Test for various 'cpoptions' (cpo) flags

source check.vim
source view_util.vim

" Test for the 'a' flag in 'cpo'. Reading a file should set the alternate
" file name.
func Test_cpo_a()
  let save_cpo = &cpo
  call writefile(['one'], 'Xfile')
  " Wipe out all the buffers, so that the alternate file is empty
  edit Xfoo | %bw
  set cpo-=a
  new
  read Xfile
  call assert_equal('', @#)
  %d
  set cpo+=a
  read Xfile
  call assert_equal('Xfile', @#)
  close!
  call delete('Xfile')
  let &cpo = save_cpo
endfunc

" Test for the 'A' flag in 'cpo'. Writing a file should set the alternate
" file name.
func Test_cpo_A()
  let save_cpo = &cpo
  " Wipe out all the buffers, so that the alternate file is empty
  edit Xfoo | %bw
  set cpo-=A
  new Xfile1
  write Xfile2
  call assert_equal('', @#)
  %bw
  call delete('Xfile2')
  new Xfile1
  set cpo+=A
  write Xfile2
  call assert_equal('Xfile2', @#)
  close!
  call delete('Xfile2')
  let &cpo = save_cpo
endfunc

" Test for the 'b' flag in 'cpo'. "\|" at the end of a map command is
" recognized as the end of the map.
func Test_cpo_b()
  let save_cpo = &cpo
  set cpo+=b
  nnoremap <F5> :pwd\<CR>\|let i = 1
  call assert_equal(':pwd\<CR>\', maparg('<F5>'))
  nunmap <F5>
  exe "nnoremap <F5> :pwd\<C-V>|let i = 1"
  call assert_equal(':pwd|let i = 1', maparg('<F5>'))
  nunmap <F5>
  set cpo-=b
  nnoremap <F5> :pwd\<CR>\|let i = 1
  call assert_equal(':pwd\<CR>|let i = 1', maparg('<F5>'))
  let &cpo = save_cpo
  nunmap <F5>
endfunc

" Test for the 'c' flag in 'cpo'.
func Test_cpo_c()
  let save_cpo = &cpo
  set cpo+=c
  new
  call setline(1, ' abababababab')
  exe "normal gg/abab\<CR>"
  call assert_equal(3, searchcount().total)
  set cpo-=c
  exe "normal gg/abab\<CR>"
  call assert_equal(5, searchcount().total)
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'C' flag in 'cpo' (line continuation)
func Test_cpo_C()
  let save_cpo = &cpo
  call writefile(['let l = [', '\ 1,', '\ 2]'], 'Xfile')
  set cpo-=C
  source Xfile
  call assert_equal([1, 2], g:l)
  set cpo+=C
  call assert_fails('source Xfile', 'E10:')
  call delete('Xfile')
  let &cpo = save_cpo
endfunc

" Test for the 'd' flag in 'cpo' (tags relative to the current file)
func Test_cpo_d()
  let save_cpo = &cpo
  call mkdir('Xdir')
  call writefile(["one\tXfile1\t/^one$/"], 'tags')
  call writefile(["two\tXfile2\t/^two$/"], 'Xdir/tags')
  set tags=./tags
  set cpo-=d
  edit Xdir/Xfile
  call assert_equal('two', taglist('.*')[0].name)
  set cpo+=d
  call assert_equal('one', taglist('.*')[0].name)
  %bw!
  call delete('tags')
  call delete('Xdir', 'rf')
  set tags&
  let &cpo = save_cpo
endfunc

" Test for the 'D' flag in 'cpo' (digraph after a r, f or t)
func Test_cpo_D()
  CheckFeature digraphs
  let save_cpo = &cpo
  new
  set cpo-=D
  call setline(1, 'abcdefgh|')
  exe "norm! 1gg0f\<c-k>!!"
  call assert_equal(9, col('.'))
  set cpo+=D
  exe "norm! 1gg0f\<c-k>!!"
  call assert_equal(1, col('.'))
  set cpo-=D
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'e' flag in 'cpo'
func Test_cpo_e()
  let save_cpo = &cpo
  let @a='let i = 45'
  set cpo+=e
  call feedkeys(":@a\<CR>", 'xt')
  call assert_equal(45, i)
  set cpo-=e
  call feedkeys(":@a\<CR>6\<CR>", 'xt')
  call assert_equal(456, i)
  let &cpo = save_cpo
endfunc

" Test for the 'E' flag in 'cpo' with yank, change, delete, etc. operators
func Test_cpo_E()
  new
  call setline(1, '')
  set cpo+=E
  " yank an empty line
  call assert_beeps('normal "ayl')
  " change an empty line
  call assert_beeps('normal lcTa')
  " delete an empty line
  call assert_beeps('normal D')
  call assert_beeps('normal dl')
  call assert_equal('', getline(1))
  " change case of an empty line
  call assert_beeps('normal gul')
  call assert_beeps('normal gUl')
  " replace a character
  call assert_beeps('normal vrx')
  " increment and decrement
  call assert_beeps('exe "normal v\<C-A>"')
  call assert_beeps('exe "normal v\<C-X>"')
  set cpo-=E
  close!
endfunc

" Test for the 'f' flag in 'cpo' (read in an empty buffer sets the file name)
func Test_cpo_f()
  let save_cpo = &cpo
  new
  set cpo-=f
  read test_cpoptions.vim
  call assert_equal('', @%)
  %d
  set cpo+=f
  read test_cpoptions.vim
  call assert_equal('test_cpoptions.vim', @%)
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'F' flag in 'cpo' (write in an empty buffer sets the file name)
func Test_cpo_F()
  let save_cpo = &cpo
  new
  set cpo-=F
  write Xfile
  call assert_equal('', @%)
  call delete('Xfile')
  set cpo+=F
  write Xfile
  call assert_equal('Xfile', @%)
  close!
  call delete('Xfile')
  let &cpo = save_cpo
endfunc

" Test for the 'g' flag in 'cpo' (jump to line 1 when re-editing a file)
func Test_cpo_g()
  throw 'Skipped: Nvim does not support cpoptions flag "g"'
  let save_cpo = &cpo
  new test_cpoptions.vim
  set cpo-=g
  normal 20G
  edit
  call assert_equal(20, line('.'))
  set cpo+=g
  edit
  call assert_equal(1, line('.'))
  close!
  let &cpo = save_cpo
endfunc

" Test for inserting text in a line with only spaces ('H' flag in 'cpoptions')
func Test_cpo_H()
  throw 'Skipped: Nvim does not support cpoptions flag "H"'
  let save_cpo = &cpo
  new
  set cpo-=H
  call setline(1, '    ')
  normal! Ia
  call assert_equal('    a', getline(1))
  set cpo+=H
  call setline(1, '    ')
  normal! Ia
  call assert_equal('   a ', getline(1))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'I' flag in 'cpo' (deleting autoindent when using arrow keys)
func Test_cpo_I()
  let save_cpo = &cpo
  new
  setlocal autoindent
  set cpo+=I
  exe "normal i    one\<CR>\<Up>"
  call assert_equal('    ', getline(2))
  set cpo-=I
  %d
  exe "normal i    one\<CR>\<Up>"
  call assert_equal('', getline(2))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'J' flag in 'cpo' (two spaces after a sentence)
func Test_cpo_J()
  let save_cpo = &cpo
  new
  set cpo-=J
  call setline(1, 'one. two!  three? four."''  five.)]')
  normal 0
  for colnr in [6, 12, 19, 28, 34]
    normal )
    call assert_equal(colnr, col('.'))
  endfor
  for colnr in [28, 19, 12, 6, 1]
    normal (
    call assert_equal(colnr, col('.'))
  endfor
  set cpo+=J
  normal 0
  for colnr in [12, 28, 34]
    normal )
    call assert_equal(colnr, col('.'))
  endfor
  for colnr in [28, 12, 1]
    normal (
    call assert_equal(colnr, col('.'))
  endfor
  close!
  let &cpo = save_cpo
endfunc

" TODO: Add a test for 'k' in 'cpo'

" TODO: Add a test for 'K' in 'cpo'

" Test for the 'l' flag in 'cpo' (backslash in a [] range)
func Test_cpo_l()
  let save_cpo = &cpo
  new
  call setline(1, ['', "a\tc" .. '\t'])
  set cpo-=l
  exe 'normal gg/[\t]' .. "\<CR>"
  call assert_equal([2, 8], [col('.'), virtcol('.')])
  set cpo+=l
  exe 'normal gg/[\t]' .. "\<CR>"
  call assert_equal([4, 10], [col('.'), virtcol('.')])
  close!
  let &cpo = save_cpo
endfunc

" Test for inserting tab in virtual replace mode ('L' flag in 'cpoptions')
func Test_cpo_L()
  let save_cpo = &cpo
  new
  set cpo-=L
  call setline(1, 'abcdefghijklmnopqr')
  exe "normal 0gR\<Tab>"
  call assert_equal("\<Tab>ijklmnopqr", getline(1))
  set cpo+=L
  set list
  call setline(1, 'abcdefghijklmnopqr')
  exe "normal 0gR\<Tab>"
  call assert_equal("\<Tab>cdefghijklmnopqr", getline(1))
  set nolist
  call setline(1, 'abcdefghijklmnopqr')
  exe "normal 0gR\<Tab>"
  call assert_equal("\<Tab>ijklmnopqr", getline(1))
  close!
  let &cpo = save_cpo
endfunc

" TODO: This test doesn't work.

" Test for the 'M' flag in 'cpo' (% with escape parenthesis)
func Test_cpo_M()
  let save_cpo = &cpo
  new
  call setline(1, ['( \( )', '\( ( \)'])

  set cpo-=M
  call cursor(1, 1)
  normal %
  call assert_equal(6, col('.'))
  call cursor(1, 4)
  call assert_beeps('normal %')
  call cursor(2, 2)
  normal %
  call assert_equal(7, col('.'))
  call cursor(2, 4)
  call assert_beeps('normal %')

  set cpo+=M
  call cursor(1, 4)
  normal %
  call assert_equal(6, col('.'))
  call cursor(1, 1)
  call assert_beeps('normal %')
  call cursor(2, 4)
  normal %
  call assert_equal(7, col('.'))
  call cursor(2, 1)
  call assert_beeps('normal %')

  close!
  let &cpo = save_cpo
endfunc

" Test for the 'n' flag in 'cpo' (using number column for wrapped lines)
func Test_cpo_n()
  let save_cpo = &cpo
  new
  call setline(1, repeat('a', &columns))
  setlocal number
  set cpo-=n
  redraw!
  call assert_equal('    aaaa', Screenline(2))
  set cpo+=n
  redraw!
  call assert_equal('aaaa', Screenline(2))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'o' flag in 'cpo' (line offset to search command)
func Test_cpo_o()
  let save_cpo = &cpo
  new
  call setline(1, ['', 'one', 'two', 'three', 'one', 'two', 'three'])
  set cpo-=o
  exe "normal /one/+2\<CR>"
  normal n
  call assert_equal(7, line('.'))
  set cpo+=o
  exe "normal /one/+2\<CR>"
  normal n
  call assert_equal(5, line('.'))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'O' flag in 'cpo' (overwriting an existing file)
func Test_cpo_O()
  let save_cpo = &cpo
  new Xfile
  call setline(1, 'one')
  call writefile(['two'], 'Xfile')
  set cpo-=O
  call assert_fails('write', 'E13:')
  set cpo+=O
  write
  call assert_equal(['one'], readfile('Xfile'))
  close!
  call delete('Xfile')
  let &cpo = save_cpo
endfunc

" Test for the 'P' flag in 'cpo' (appending to a file sets the current file
" name)
func Test_cpo_P()
  let save_cpo = &cpo
  call writefile([], 'Xfile')
  new
  call setline(1, 'one')
  set cpo+=F
  set cpo-=P
  write >> Xfile
  call assert_equal('', @%)
  set cpo+=P
  write >> Xfile
  call assert_equal('Xfile', @%)
  close!
  call delete('Xfile')
  let &cpo = save_cpo
endfunc

" Test for the 'q' flag in 'cpo' (joining multiple lines)
func Test_cpo_q()
  let save_cpo = &cpo
  new
  call setline(1, ['one', 'two', 'three', 'four', 'five'])
  set cpo-=q
  normal gg4J
  call assert_equal(14, col('.'))
  %d
  call setline(1, ['one', 'two', 'three', 'four', 'five'])
  set cpo+=q
  normal gg4J
  call assert_equal(4, col('.'))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'r' flag in 'cpo' (redo command with a search motion)
func Test_cpo_r()
  let save_cpo = &cpo
  new
  call setline(1, repeat(['one two three four'], 2))
  set cpo-=r
  exe "normal ggc/two\<CR>abc "
  let @/ = 'three'
  normal 2G.
  call assert_equal('abc two three four', getline(2))
  %d
  call setline(1, repeat(['one two three four'], 2))
  set cpo+=r
  exe "normal ggc/two\<CR>abc "
  let @/ = 'three'
  normal 2G.
  call assert_equal('abc three four', getline(2))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'R' flag in 'cpo' (clear marks after a filter command)
func Test_cpo_R()
  CheckUnix
  let save_cpo = &cpo
  new
  call setline(1, ['three', 'one', 'two'])
  set cpo-=R
  3mark r
  %!sort
  call assert_equal(3, line("'r"))
  %d
  call setline(1, ['three', 'one', 'two'])
  set cpo+=R
  3mark r
  %!sort
  call assert_equal(0, line("'r"))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'S' flag in 'cpo' (copying buffer options)
func Test_cpo_S()
  let save_cpo = &cpo
  new Xfile1
  set noautoindent
  new Xfile2
  set cpo-=S
  set autoindent
  wincmd p
  call assert_equal(0, &autoindent)
  wincmd p
  call assert_equal(1, &autoindent)
  set cpo+=S
  wincmd p
  call assert_equal(1, &autoindent)
  set noautoindent
  wincmd p
  call assert_equal(0, &autoindent)
  wincmd t
  close!
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'u' flag in 'cpo' (Vi-compatible undo)
func Test_cpo_u()
  let save_cpo = &cpo
  new
  set cpo-=u
  exe "normal iabc\<C-G>udef\<C-G>ughi"
  normal uu
  call assert_equal('abc', getline(1))
  %d
  set cpo+=u
  exe "normal iabc\<C-G>udef\<C-G>ughi"
  normal uu
  call assert_equal('abcdefghi', getline(1))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'x' flag in 'cpo' (Esc on command-line executes command)
func Test_cpo_x()
  let save_cpo = &cpo
  set cpo-=x
  let i = 1
  call feedkeys(":let i=10\<Esc>", 'xt')
  call assert_equal(1, i)
  set cpo+=x
  call feedkeys(":let i=10\<Esc>", 'xt')
  call assert_equal(10, i)
  let &cpo = save_cpo
endfunc

" Test for the 'X' flag in 'cpo' ('R' with a count)
func Test_cpo_X()
  let save_cpo = &cpo
  new
  call setline(1, 'aaaaaa')
  set cpo-=X
  normal gg4Rx
  call assert_equal('xxxxaa', getline(1))
  normal ggRy
  normal 4.
  call assert_equal('yyyyaa', getline(1))
  call setline(1, 'aaaaaa')
  set cpo+=X
  normal gg4Rx
  call assert_equal('xxxxaaaaa', getline(1))
  normal ggRy
  normal 4.
  call assert_equal('yyyyxxxaaaaa', getline(1))
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'y' flag in 'cpo' (repeating a yank command)
func Test_cpo_y()
  let save_cpo = &cpo
  new
  call setline(1, ['one', 'two'])
  set cpo-=y
  normal ggyy
  normal 2G.
  call assert_equal("one\n", @")
  %d
  call setline(1, ['one', 'two'])
  set cpo+=y
  normal ggyy
  normal 2G.
  call assert_equal("two\n", @")
  close!
  let &cpo = save_cpo
endfunc

" Test for the 'Z' flag in 'cpo' (write! resets 'readonly')
func Test_cpo_Z()
  let save_cpo = &cpo
  call writefile([], 'Xfile')
  new Xfile
  setlocal readonly
  set cpo-=Z
  write!
  call assert_equal(0, &readonly)
  set cpo+=Z
  setlocal readonly
  write!
  call assert_equal(1, &readonly)
  close!
  call delete('Xfile')
  let &cpo = save_cpo
endfunc

" Test for cursor movement with '-' in 'cpoptions'
func Test_cpo_minus()
  throw 'Skipped: Nvim does not support cpoptions flag "-"'
  new
  call setline(1, ['foo', 'bar', 'baz'])
  let save_cpo = &cpo
  set cpo+=-
  call assert_beeps('normal 10j')
  call assert_equal(1, line('.'))
  normal G
  call assert_beeps('normal 10k')
  call assert_equal(3, line('.'))
  call assert_fails(10, 'E16:')
  let &cpo = save_cpo
  close!
endfunc

" Test for displaying dollar when changing text ('$' flag in 'cpoptions')
func Test_cpo_dollar()
  throw 'Skipped: use test/functional/legacy/cpoptions_spec.lua'
  new
  let g:Line = ''
  func SaveFirstLine()
    let g:Line = Screenline(1)
    return ''
  endfunc
  inoremap <expr> <buffer> <F2> SaveFirstLine()
  call test_override('redraw_flag', 1)
  set cpo+=$
  call setline(1, 'one two three')
  redraw!
  exe "normal c2w\<F2>vim"
  call assert_equal('one tw$ three', g:Line)
  call assert_equal('vim three', getline(1))
  set cpo-=$
  call test_override('ALL', 0)
  delfunc SaveFirstLine
  %bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
