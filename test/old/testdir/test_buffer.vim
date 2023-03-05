" Tests for Vim buffer

source check.vim

" Test for the :bunload command with an offset
func Test_bunload_with_offset()
  %bwipe!
  call writefile(['B1'], 'b1')
  call writefile(['B2'], 'b2')
  call writefile(['B3'], 'b3')
  call writefile(['B4'], 'b4')

  " Load four buffers. Unload the second and third buffers and then
  " execute .+3bunload to unload the last buffer.
  edit b1
  new b2
  new b3
  new b4

  bunload b2
  bunload b3
  exe bufwinnr('b1') . 'wincmd w'
  .+3bunload
  call assert_equal(0, getbufinfo('b4')[0].loaded)
  call assert_equal('b1',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the third and fourth buffers. Execute .+3bunload
  " and check whether the second buffer is unloaded.
  ball
  bunload b3
  bunload b4
  exe bufwinnr('b1') . 'wincmd w'
  .+3bunload
  call assert_equal(0, getbufinfo('b2')[0].loaded)
  call assert_equal('b1',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the second and third buffers and from the last
  " buffer execute .-3bunload to unload the first buffer.
  ball
  bunload b2
  bunload b3
  exe bufwinnr('b4') . 'wincmd w'
  .-3bunload
  call assert_equal(0, getbufinfo('b1')[0].loaded)
  call assert_equal('b4',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  " Load four buffers. Unload the first and second buffers. Execute .-3bunload
  " from the last buffer and check whether the third buffer is unloaded.
  ball
  bunload b1
  bunload b2
  exe bufwinnr('b4') . 'wincmd w'
  .-3bunload
  call assert_equal(0, getbufinfo('b3')[0].loaded)
  call assert_equal('b4',
        \ fnamemodify(getbufinfo({'bufloaded' : 1})[0].name, ':t'))

  %bwipe!
  call delete('b1')
  call delete('b2')
  call delete('b3')
  call delete('b4')

  call assert_fails('1,4bunload', 'E16:')
  call assert_fails(',100bunload', 'E16:')

  call assert_fails('$bunload', 'E90:')
endfunc

" Test for :buffer, :bnext, :bprevious, :brewind, :blast and :bmodified
" commands
func Test_buflist_browse()
  %bwipe!
  call assert_fails('buffer 1000', 'E86:')

  call writefile(['foo1', 'foo2', 'foo3', 'foo4'], 'Xfile1')
  call writefile(['bar1', 'bar2', 'bar3', 'bar4'], 'Xfile2')
  call writefile(['baz1', 'baz2', 'baz3', 'baz4'], 'Xfile3')
  edit Xfile1
  let b1 = bufnr()
  edit Xfile2
  let b2 = bufnr()
  edit +/baz4 Xfile3
  let b3 = bufnr()

  call assert_fails('buffer ' .. b1 .. ' abc', 'E488:')
  call assert_equal(b3, bufnr())
  call assert_equal(4, line('.'))
  exe 'buffer +/bar2 ' .. b2
  call assert_equal(b2, bufnr())
  call assert_equal(2, line('.'))
  exe 'buffer +/bar1'
  call assert_equal(b2, bufnr())
  call assert_equal(1, line('.'))

  brewind +
  call assert_equal(b1, bufnr())
  call assert_equal(4, line('.'))

  blast +/baz2
  call assert_equal(b3, bufnr())
  call assert_equal(2, line('.'))

  bprevious +/bar4
  call assert_equal(b2, bufnr())
  call assert_equal(4, line('.'))

  bnext +/baz3
  call assert_equal(b3, bufnr())
  call assert_equal(3, line('.'))

  call assert_fails('bmodified', 'E84:')
  call setbufvar(b2, '&modified', 1)
  exe 'bmodified +/bar3'
  call assert_equal(b2, bufnr())
  call assert_equal(3, line('.'))

  " With no listed buffers in the list, :bnext and :bprev should fail
  %bwipe!
  set nobuflisted
  call assert_fails('bnext', 'E85:')
  call assert_fails('bprev', 'E85:')
  set buflisted

  call assert_fails('sandbox bnext', 'E48:')

  call delete('Xfile1')
  call delete('Xfile2')
  call delete('Xfile3')
  %bwipe!
endfunc

" Test for :bdelete
func Test_bdelete_cmd()
  %bwipe!
  call assert_fails('bdelete 5', 'E516:')
  call assert_fails('1,1bdelete 1 2', 'E488:')
  call assert_fails('bdelete \)', 'E55:')

  " Deleting a unlisted and unloaded buffer
  edit Xfile1
  let bnr = bufnr()
  set nobuflisted
  enew
  call assert_fails('bdelete ' .. bnr, 'E516:')

  " Deleting more than one buffer
  new Xbuf1
  new Xbuf2
  exe 'bdel ' .. bufnr('Xbuf2') .. ' ' .. bufnr('Xbuf1')
  call assert_equal(1, winnr('$'))
  call assert_equal(0, getbufinfo('Xbuf1')[0].loaded)
  call assert_equal(0, getbufinfo('Xbuf2')[0].loaded)

  " Deleting more than one buffer and an invalid buffer
  new Xbuf1
  new Xbuf2
  let cmd = "exe 'bdel ' .. bufnr('Xbuf2') .. ' xxx ' .. bufnr('Xbuf1')"
  call assert_fails(cmd, 'E94:')
  call assert_equal(2, winnr('$'))
  call assert_equal(1, getbufinfo('Xbuf1')[0].loaded)
  call assert_equal(0, getbufinfo('Xbuf2')[0].loaded)

  %bwipe!
endfunc

func Test_buffer_error()
  new foo1
  new foo2

  call assert_fails('buffer foo', 'E93:')
  call assert_fails('buffer bar', 'E94:')
  call assert_fails('buffer 0', 'E939:')

  %bwipe
endfunc

" Test for the status messages displayed when unloading, deleting or wiping
" out buffers
func Test_buffer_statusmsg()
  CheckEnglish
  set report=1
  new Xbuf1
  new Xbuf2
  let bnr = bufnr()
  exe "normal 2\<C-G>"
  call assert_match('buf ' .. bnr .. ':', v:statusmsg)
  bunload Xbuf1 Xbuf2
  call assert_equal('2 buffers unloaded', v:statusmsg)
  bdel Xbuf1 Xbuf2
  call assert_equal('2 buffers deleted', v:statusmsg)
  bwipe Xbuf1 Xbuf2
  call assert_equal('2 buffers wiped out', v:statusmsg)
  set report&
endfunc

" Test for quitting the 'swapfile exists' dialog with the split buffer
" command.
func Test_buffer_sbuf_cleanup()
  call writefile([], 'Xfile')
  " first open the file in a buffer
  new Xfile
  let bnr = bufnr()
  close
  " create the swap file
  call writefile([], '.Xfile.swp')
  " Remove the catch-all that runtest.vim adds
  au! SwapExists
  augroup BufTest
    au!
    autocmd SwapExists Xfile let v:swapchoice='q'
  augroup END
  exe 'sbuf ' . bnr
  call assert_equal(1, winnr('$'))
  call assert_equal(0, getbufinfo('Xfile')[0].loaded)

  " test for :sball
  sball
  call assert_equal(1, winnr('$'))
  call assert_equal(0, getbufinfo('Xfile')[0].loaded)

  %bw!
  set shortmess+=F
  let v:statusmsg = ''
  edit Xfile
  call assert_equal('', v:statusmsg)
  call assert_equal(1, winnr('$'))
  call assert_equal(0, getbufinfo('Xfile')[0].loaded)
  set shortmess&

  call delete('Xfile')
  call delete('.Xfile.swp')
  augroup BufTest
    au!
  augroup END
  augroup! BufTest
endfunc

" Test for deleting a modified buffer with :confirm
func Test_bdel_with_confirm()
  " requires a UI to be active
  throw 'Skipped: use test/functional/legacy/buffer_spec.lua'
  CheckUnix
  CheckNotGui
  CheckFeature dialog_con
  new
  call setline(1, 'test')
  call assert_fails('bdel', 'E89:')
  call feedkeys('c', 'L')
  confirm bdel
  call assert_equal(2, winnr('$'))
  call assert_equal(1, &modified)
  call feedkeys('n', 'L')
  confirm bdel
  call assert_equal(1, winnr('$'))
endfunc

" Test for editing another buffer from a modified buffer with :confirm
func Test_goto_buf_with_confirm()
  " requires a UI to be active
  throw 'Skipped: use test/functional/legacy/buffer_spec.lua'
  CheckUnix
  CheckNotGui
  CheckFeature dialog_con
  new Xfile
  enew
  call setline(1, 'test')
  call assert_fails('b Xfile', 'E37:')
  call feedkeys('c', 'L')
  call assert_fails('confirm b Xfile', 'E37:')
  call assert_equal(1, &modified)
  call assert_equal('', @%)
  call feedkeys('y', 'L')
  call assert_fails('confirm b Xfile', ['', 'E37:'])
  call assert_equal(1, &modified)
  call assert_equal('', @%)
  call feedkeys('n', 'L')
  confirm b Xfile
  call assert_equal('Xfile', @%)
  close!
endfunc

" Test for splitting buffer with 'switchbuf'
func Test_buffer_switchbuf()
  new Xfile
  wincmd w
  set switchbuf=useopen
  sbuf Xfile
  call assert_equal(1, winnr())
  call assert_equal(2, winnr('$'))
  set switchbuf=usetab
  tabnew
  sbuf Xfile
  call assert_equal(1, tabpagenr())
  call assert_equal(2, tabpagenr('$'))
  set switchbuf&
  %bw
endfunc

" Test for BufAdd autocommand wiping out the buffer
func Test_bufadd_autocmd_bwipe()
  %bw!
  augroup BufAdd_Wipe
    au!
    autocmd BufAdd Xfile %bw!
  augroup END
  edit Xfile
  call assert_equal('', @%)
  call assert_equal(0, bufexists('Xfile'))
  augroup BufAdd_Wipe
    au!
  augroup END
  augroup! BufAdd_Wipe
endfunc

" Test for trying to load a buffer with text locked
" <C-\>e in the command line is used to lock the text
func Test_load_buf_with_text_locked()
  new Xfile1
  edit Xfile2
  let cmd = ":\<C-\>eexecute(\"normal \<C-O>\")\<CR>\<C-C>"
  call assert_fails("call feedkeys(cmd, 'xt')", 'E565:')
  %bw!
endfunc

" Test for using CTRL-^ to edit the alternative file keeping the cursor
" position with 'nostartofline'. Also test using the 'buf' command.
func Test_buffer_edit_altfile()
  call writefile(repeat(['one two'], 50), 'Xfile1')
  call writefile(repeat(['five six'], 50), 'Xfile2')
  set nosol
  edit Xfile1
  call cursor(25, 5)
  edit Xfile2
  call cursor(30, 4)
  exe "normal \<C-^>"
  call assert_equal([0, 25, 5, 0], getpos('.'))
  exe "normal \<C-^>"
  call assert_equal([0, 30, 4, 0], getpos('.'))
  buf Xfile1
  call assert_equal([0, 25, 5, 0], getpos('.'))
  buf Xfile2
  call assert_equal([0, 30, 4, 0], getpos('.'))
  set sol&
  call delete('Xfile1')
  call delete('Xfile2')
endfunc

" Test for running the :sball command with a maximum window count and a
" modified buffer
func Test_sball_with_count()
  %bw!
  edit Xfile1
  call setline(1, ['abc'])
  new Xfile2
  new Xfile3
  new Xfile4
  2sball
  call assert_equal(bufnr('Xfile4'), winbufnr(1))
  call assert_equal(bufnr('Xfile1'), winbufnr(2))
  call assert_equal(0, getbufinfo('Xfile2')[0].loaded)
  call assert_equal(0, getbufinfo('Xfile3')[0].loaded)
  %bw!
endfunc

func Test_badd_options()
  new SomeNewBuffer
  setlocal numberwidth=3
  wincmd p
  badd +1 SomeNewBuffer
  new SomeNewBuffer
  call assert_equal(3, &numberwidth)
  close
  close
  bwipe! SomeNewBuffer
endfunc

func Test_balt()
  new SomeNewBuffer
  balt +3 OtherBuffer
  e #
  call assert_equal('OtherBuffer', bufname())
endfunc

" Test for buffer match URL(scheme) check
" scheme is alpha and inner hyphen only.
func Test_buffer_scheme()
  CheckMSWindows

  set noshellslash
  %bwipe!
  let bufnames = [
    \ #{id: 'ssb0', name: 'test://xyz/foo/ssb0'    , match: 1},
    \ #{id: 'ssb1', name: 'test+abc://xyz/foo/ssb1', match: 0},
    \ #{id: 'ssb2', name: 'test_abc://xyz/foo/ssb2', match: 0},
    \ #{id: 'ssb3', name: 'test-abc://xyz/foo/ssb3', match: 1},
    \ #{id: 'ssb4', name: '-test://xyz/foo/ssb4'   , match: 0},
    \ #{id: 'ssb5', name: 'test-://xyz/foo/ssb5'   , match: 0},
    \]
  for buf in bufnames
    new `=buf.name`
    if buf.match
      call assert_equal(buf.name,    getbufinfo(buf.id)[0].name)
    else
      " slashes will have become backslashes
      call assert_notequal(buf.name, getbufinfo(buf.id)[0].name)
    endif
    bwipe
  endfor

  set shellslash&
endfunc

" this was using a NULL pointer after failing to use the pattern
func Test_buf_pattern_invalid()
  vsplit 0000000
  silent! buf [0--]\&\zs*\zs*e
  bwipe!

  vsplit 00000000000000000000000000
  silent! buf [0--]\&\zs*\zs*e
  bwipe!

  " similar case with different code path
  split 0
  edit ÿ
  silent! buf [0--]\&\zs*\zs*0
  bwipe!
endfunc

" Test for the 'maxmem' and 'maxmemtot' options
func Test_buffer_maxmem()
  " use 1KB per buffer and 2KB for all the buffers
  " set maxmem=1 maxmemtot=2
  new
  let v:errmsg = ''
  " try opening some files
  edit test_arglist.vim
  call assert_equal('test_arglist.vim', bufname())
  edit test_eval_stuff.vim
  call assert_equal('test_eval_stuff.vim', bufname())
  b test_arglist.vim
  call assert_equal('test_arglist.vim', bufname())
  b test_eval_stuff.vim
  call assert_equal('test_eval_stuff.vim', bufname())
  close
  call assert_equal('', v:errmsg)
  " set maxmem& maxmemtot&
endfunc

" Test for buffer allocation failure
func Test_buflist_alloc_failure()
  CheckFunction test_alloc_fail
  %bw!

  edit Xfile1
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('edit Xfile2', 'E342:')

  " test for bufadd()
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('call bufadd("Xbuffer")', 'E342:')

  " test for setting the arglist
  edit Xfile2
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('next Xfile3', 'E342:')

  " test for setting the alternate buffer name when writing a file
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('write Xother', 'E342:')
  call delete('Xother')

  " test for creating a buffer using bufnr()
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails("call bufnr('Xnewbuf', v:true)", 'E342:')

  " test for renaming buffer using :file
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('file Xnewfile', 'E342:')

  " test for creating a buffer for a popup window
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('call popup_create("mypop", {})', 'E342:')

  if has('terminal')
    " test for creating a buffer for a terminal window
    call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
    call assert_fails('call term_start(&shell)', 'E342:')
    %bw!
  endif

  " test for loading a new buffer after wiping out all the buffers
  edit Xfile4
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('%bw!', 'E342:')

  " test for :checktime loading the buffer
  call writefile(['one'], 'Xfile5')
  if has('unix')
    edit Xfile5
    " sleep for some time to make sure the timestamp is different
    sleep 200m
    call writefile(['two'], 'Xfile5')
    set autoread
    call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
    call assert_fails('checktime', 'E342:')
    set autoread&
    bw!
  endif

  " test for :vimgrep loading a dummy buffer
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('vimgrep two Xfile5', 'E342:')
  call delete('Xfile5')

  " test for quickfix command loading a buffer
  call test_alloc_fail(GetAllocId('newbuf_bvars'), 0, 0)
  call assert_fails('cexpr "Xfile6:10:Line10"', 'E342:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
