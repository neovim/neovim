" Tests for setbufline(), getbufline(), appendbufline(), deletebufline()

source shared.vim
" source screendump.vim

func Test_setbufline_getbufline()
  new
  let b = bufnr('%')
  hide
  call assert_equal(0, setbufline(b, 1, ['foo', 'bar']))
  call assert_equal(['foo'], getbufline(b, 1))
  call assert_equal(['bar'], getbufline(b, 2))
  call assert_equal(['foo', 'bar'], getbufline(b, 1, 2))
  exe "bd!" b
  call assert_equal([], getbufline(b, 1, 2))

  split Xtest
  call setline(1, ['a', 'b', 'c'])
  let b = bufnr('%')
  wincmd w
  call assert_equal(1, setbufline(b, 5, ['x']))
  call assert_equal(1, setbufline(1234, 1, ['x']))
  call assert_equal(0, setbufline(b, 4, ['d', 'e']))
  call assert_equal(['c'], getbufline(b, 3))
  call assert_equal(['d'], getbufline(b, 4))
  call assert_equal(['e'], getbufline(b, 5))
  call assert_equal([], getbufline(b, 6))
  exe "bwipe! " . b
endfunc

func Test_setbufline_getbufline_fold()
  split Xtest
  setlocal foldmethod=expr foldexpr=0
  let b = bufnr('%')
  new
  call assert_equal(0, setbufline(b, 1, ['foo', 'bar']))
  call assert_equal(['foo'], getbufline(b, 1))
  call assert_equal(['bar'], getbufline(b, 2))
  call assert_equal(['foo', 'bar'], getbufline(b, 1, 2))
  exe "bwipe!" b
  bwipe!
endfunc

func Test_setbufline_getbufline_fold_tab()
  split Xtest
  setlocal foldmethod=expr foldexpr=0
  let b = bufnr('%')
  tab new
  call assert_equal(0, setbufline(b, 1, ['foo', 'bar']))
  call assert_equal(['foo'], getbufline(b, 1))
  call assert_equal(['bar'], getbufline(b, 2))
  call assert_equal(['foo', 'bar'], getbufline(b, 1, 2))
  exe "bwipe!" b
  bwipe!
endfunc

func Test_setline_startup()
  let cmd = GetVimCommand('Xscript')
  if cmd == ''
    return
  endif
  call writefile(['call setline(1, "Hello")', 'silent w Xtest', 'q!'], 'Xscript')
  call system(cmd)
  call assert_equal(['Hello'], readfile('Xtest'))

  call delete('Xscript')
  call delete('Xtest')
endfunc

func Test_appendbufline()
  new
  let b = bufnr('%')
  hide
  call assert_equal(0, appendbufline(b, 0, ['foo', 'bar']))
  call assert_equal(['foo'], getbufline(b, 1))
  call assert_equal(['bar'], getbufline(b, 2))
  call assert_equal(['foo', 'bar'], getbufline(b, 1, 2))
  exe "bd!" b
  call assert_equal([], getbufline(b, 1, 2))

  split Xtest
  call setline(1, ['a', 'b', 'c'])
  let b = bufnr('%')
  wincmd w
  call assert_equal(1, appendbufline(b, 4, ['x']))
  call assert_equal(1, appendbufline(1234, 1, ['x']))
  call assert_equal(0, appendbufline(b, 3, ['d', 'e']))
  call assert_equal(['c'], getbufline(b, 3))
  call assert_equal(['d'], getbufline(b, 4))
  call assert_equal(['e'], getbufline(b, 5))
  call assert_equal([], getbufline(b, 6))
  exe "bwipe! " . b
endfunc

func Test_deletebufline()
  new
  let b = bufnr('%')
  call setline(1, ['aaa', 'bbb', 'ccc'])
  hide
  call assert_equal(0, deletebufline(b, 2))
  call assert_equal(['aaa', 'ccc'], getbufline(b, 1, 2))
  call assert_equal(0, deletebufline(b, 2, 8))
  call assert_equal(['aaa'], getbufline(b, 1, 2))
  exe "bd!" b
  call assert_equal(1, deletebufline(b, 1))

  split Xtest
  call setline(1, ['a', 'b', 'c'])
  let b = bufnr('%')
  wincmd w
  call assert_equal(1, deletebufline(b, 4))
  call assert_equal(0, deletebufline(b, 1))
  call assert_equal(['b', 'c'], getbufline(b, 1, 2))
  exe "bwipe! " . b
endfunc

func Test_appendbufline_redraw()
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif
  let lines =<< trim END
    new foo
    let winnr=bufwinnr('foo')
    let buf=bufnr('foo')
    wincmd p
    call appendbufline(buf, '$', range(1,200))
    exe winnr. 'wincmd w'
    norm! G
    wincmd p
    call deletebufline(buf, 1, '$')
    call appendbufline(buf, '$', 'Hello Vim world...')
  END
  call writefile(lines, 'XscriptMatchCommon')
  let buf = RunVimInTerminal('-S XscriptMatchCommon', #{rows: 10})
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_appendbufline_1', {})

  call StopVimInTerminal(buf)
  call delete('XscriptMatchCommon')
endfunc
