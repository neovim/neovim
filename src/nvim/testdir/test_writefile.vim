" Tests for the writefile() function.

func Test_writefile()
  let f = tempname()
  call writefile(["over","written"], f, "b")
  call writefile(["hello","world"], f, "b")
  call writefile(["!", "good"], f, "a")
  call writefile(["morning"], f, "ab")
  call writefile(["", "vimmers"], f, "ab")
  let l = readfile(f)
  call assert_equal("hello", l[0])
  call assert_equal("world!", l[1])
  call assert_equal("good", l[2])
  call assert_equal("morning", l[3])
  call assert_equal("vimmers", l[4])
  call delete(f)
endfunc

func Test_writefile_fails_gently()
  call assert_fails('call writefile(["test"], "Xfile", [])', 'E730:')
  call assert_false(filereadable("Xfile"))
  call delete("Xfile")

  call assert_fails('call writefile(["test", [], [], [], "tset"], "Xfile")', 'E745:')
  call assert_false(filereadable("Xfile"))
  call delete("Xfile")

  call assert_fails('call writefile([], "Xfile", [])', 'E730:')
  call assert_false(filereadable("Xfile"))
  call delete("Xfile")

  call assert_fails('call writefile([], [])', 'E730:')
endfunc

func SetFlag(timer)
  let g:flag = 1
endfunc

func Test_write_quit_split()
  " Prevent exiting by splitting window on file write.
  augroup testgroup
    autocmd BufWritePre * split
  augroup END
  e! Xfile
  call setline(1, 'nothing')
  wq

  if has('timers')
    " timer will not run if "exiting" is still set
    let g:flag = 0
    call timer_start(1, 'SetFlag')
    sleep 50m
    call assert_equal(1, g:flag)
    unlet g:flag
  endif
  au! testgroup
  bwipe Xfile
  call delete('Xfile')
endfunc

func Test_nowrite_quit_split()
  " Prevent exiting by opening a help window.
  e! Xfile
  help
  wincmd w
  exe winnr() . 'q'

  if has('timers')
    " timer will not run if "exiting" is still set
    let g:flag = 0
    call timer_start(1, 'SetFlag')
    sleep 50m
    call assert_equal(1, g:flag)
    unlet g:flag
  endif
  bwipe Xfile
endfunc

func Test_writefile_autowrite()
  set autowrite
  new
  next Xa Xb Xc
  call setline(1, 'aaa')
  next
  call assert_equal(['aaa'], readfile('Xa'))
  call setline(1, 'bbb')
  call assert_fails('edit XX')
  call assert_false(filereadable('Xb'))

  set autowriteall
  edit XX
  call assert_equal(['bbb'], readfile('Xb'))

  bwipe!
  call delete('Xa')
  call delete('Xb')
  set noautowrite
endfunc

func Test_writefile_autowrite_nowrite()
  set autowrite
  new
  next Xa Xb Xc
  set buftype=nowrite
  call setline(1, 'aaa')
  let buf = bufnr('%')
  " buffer contents silently lost
  edit XX
  call assert_false(filereadable('Xa'))
  rewind
  call assert_equal('', getline(1))

  bwipe!
  set noautowrite
endfunc
