
func Test_yank_shows_register()
    enew
    set report=0
    call setline(1, ['foo', 'bar'])
    " Line-wise
    exe 'norm! yy'
    call assert_equal('1 line yanked', v:statusmsg)
    exe 'norm! "zyy'
    call assert_equal('1 line yanked into "z', v:statusmsg)
    exe 'norm! yj'
    call assert_equal('2 lines yanked', v:statusmsg)
    exe 'norm! "zyj'
    call assert_equal('2 lines yanked into "z', v:statusmsg)

    " Block-wise
    exe "norm! \<C-V>y"
    call assert_equal('block of 1 line yanked', v:statusmsg)
    exe "norm! \<C-V>\"zy"
    call assert_equal('block of 1 line yanked into "z', v:statusmsg)
    exe "norm! \<C-V>jy"
    call assert_equal('block of 2 lines yanked', v:statusmsg)
    exe "norm! \<C-V>j\"zy"
    call assert_equal('block of 2 lines yanked into "z', v:statusmsg)

    bwipe!
endfunc

func Test_display_registers()
    e file1
    e file2
    call setline(1, ['foo', 'bar'])
    /bar
    exe 'norm! y2l"axx'
    call feedkeys("i\<C-R>=2*4\n\<esc>")
    call feedkeys(":ls\n", 'xt')

    let a = execute('display')
    let b = execute('registers')

    call assert_equal(a, b)
    call assert_match('^\n--- Registers ---\n'
          \ .         '""   a\n'
          \ .         '"0   ba\n'
          \ .         '"1   b\n'
          \ .         '"a   b\n'
          \ .         '.*'
          \ .         '"-   a\n'
          \ .         '.*'
          \ .         '":   ls\n'
          \ .         '"%   file2\n'
          \ .         '"#   file1\n'
          \ .         '"/   bar\n'
          \ .         '"=   2\*4', a)

    let a = execute('registers a')
    call assert_match('^\n--- Registers ---\n'
          \ .         '"a   b', a)

    let a = execute('registers :')
    call assert_match('^\n--- Registers ---\n'
          \ .         '":   ls', a)

    bwipe!
endfunc

" Check that replaying a typed sequence does not use an Esc and following
" characters as an escape sequence.
func Test_recording_esc_sequence()
  new
  let save_F2 = &t_F2
  let t_F2 = "\<Esc>OQ"
  call feedkeys("qqiTest\<Esc>", "xt")
  call feedkeys("OQuirk\<Esc>q", "xt")
  call feedkeys("Go\<Esc>@q", "xt")
  call assert_equal(['Quirk', 'Test', 'Quirk', 'Test'], getline(1, 4))
  bwipe!
  let t_F2 = save_F2
endfunc
