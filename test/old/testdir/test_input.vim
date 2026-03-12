" Tests for character input and feedkeys() function.

func Test_feedkeys_x_with_empty_string()
  new
  call feedkeys("ifoo\<Esc>")
  call assert_equal('', getline('.'))
  call feedkeys('', 'x')
  call assert_equal('foo', getline('.'))

  " check it goes back to normal mode immediately.
  call feedkeys('i', 'x')
  call assert_equal('foo', getline('.'))
  quit!
endfunc

func Test_feedkeys_with_abbreviation()
  new
  inoreabbrev trigger value
  call feedkeys("atrigger ", 'x')
  call feedkeys("atrigger ", 'x')
  call assert_equal('value value ', getline(1))
  bwipe!
  iunabbrev trigger
endfunc

func Test_feedkeys_escape_special()
  nnoremap … <Cmd>let g:got_ellipsis += 1<CR>
  call feedkeys('…', 't')
  call assert_equal('…', getcharstr())
  let g:got_ellipsis = 0
  call feedkeys('…', 'xt')
  call assert_equal(1, g:got_ellipsis)
  unlet g:got_ellipsis
  nunmap …
endfunc

func Test_input_simplify_ctrl_at()
  new
  " feeding unsimplified CTRL-@ should still trigger i_CTRL-@
  call feedkeys("ifoo\<Esc>A\<*C-@>x", 'xt')
  call assert_equal('foofo', getline(1))
  bw!
endfunc

func Test_input_simplify_noremap()
  call feedkeys("i\<*C-M>", 'nx')
  call assert_equal('', getline(1))
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  bw!
endfunc

func Test_input_simplify_timedout()
  inoremap <C-M>a b
  call feedkeys("i\<*C-M>", 'xt')
  call assert_equal('', getline(1))
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  iunmap <C-M>a
  bw!
endfunc

" Check that <Ignore> and <MouseMove> are no-op in the middle of various
" commands as they are ignored by plain_vgetc().
func Test_input_noop_keys()
  for key in ["\<Ignore>", "\<MouseMove>"]
    20new
    setlocal scrolloff=0

    let lines = range(1, 100)->mapnew({_, n -> $'line {n}'})
    call setline(1, lines)
    let InsertNoopKeys = {s -> key .. split(s, '\zs')->join(key) .. key}

    call feedkeys(InsertNoopKeys("60z\<CR>\<C-\>\<C-N>"), 'tnix')
    call assert_equal(60, line('w0'))
    call assert_equal('line 60', getline('.'))

    call feedkeys(InsertNoopKeys("gg20ddi\<C-V>x5F\<Esc>"), 'tnix')
    call assert_equal(80, line('$'))
    call assert_equal('_line 21', getline('.'))

    call feedkeys(InsertNoopKeys("fea\<C-K>,.\<C-\>\<C-N>"), 'tnix')
    call assert_equal('_line… 21', getline('.'))

    call feedkeys(InsertNoopKeys("Iabcde\<C-G>ufghij\<Esc>u"), 'tnix')
    call assert_equal('abcde_line… 21', getline('.'))
    call feedkeys("\<C-R>$2Feg~tj", 'tnix')
    call assert_equal('abcdEFGHIj_line… 21', getline('.'))

    let @g = 'FOO'
    call feedkeys(InsertNoopKeys("A\<C-R>g\<C-R>\<C-O>g\<Esc>"), 'tnix')
    call assert_equal('abcdEFGHIj_line… 21FOOFOO', getline('.'))

    call feedkeys(InsertNoopKeys("0v10l\<C-G>\<C-R>g?!!\<Esc>"), 'tnix')
    call assert_equal('abcdEFGHIj_', @g)
    call assert_equal('?!!line… 21FOOFOO', getline('.'))

    let @g = 'BAR'
    call feedkeys(InsertNoopKeys("$:\"abc\<C-R>\<C-R>\<C-W>\<CR>"), 'tnix')
    call assert_equal('"abc21FOOFOO', @:)
    call feedkeys(InsertNoopKeys(":\<C-\>e'\"foo'\<CR>\<C-R>g\<CR>"), 'tnix')
    call assert_equal('"fooBAR', @:)

    call feedkeys(InsertNoopKeys("z10\<CR>"), 'tnix')
    call assert_equal(10, winheight(0))
    call feedkeys(InsertNoopKeys("\<C-W>10+"), 'tnix')
    call assert_equal(20, winheight(0))

    bwipe!
  endfor
endfunc

" vim: shiftwidth=2 sts=2 expandtab
