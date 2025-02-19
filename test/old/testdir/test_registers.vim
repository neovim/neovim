" Tests for register operations

source check.vim
source view_util.vim

" This test must be executed first to check for empty and unset registers.
func Test_aaa_empty_reg_test()
  call assert_fails('normal @@', 'E748:')
  call assert_fails('normal @%', 'E354:')
  call assert_fails('normal @#', 'E354:')
  call assert_fails('normal @!', 'E354:')
  call assert_fails('normal @:', 'E30:')
  call assert_fails('normal @.', 'E29:')
  call assert_fails('put /', 'E35:')
  call assert_fails('put .', 'E29:')
endfunc

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
    " Disable clipboard
    let save_clipboard = get(g:, 'clipboard', {})
    let g:clipboard = {}

    e file1
    e file2
    call setline(1, ['foo', 'bar'])
    /bar
    exe 'norm! y2l"axx'
    call feedkeys("i\<C-R>=2*4\n\<esc>")
    call feedkeys(":ls\n", 'xt')

    " these commands work in the sandbox
    let a = execute('sandbox display')
    let b = execute('sandbox registers')

    call assert_equal(a, b)
    call assert_match('^\nType Name Content\n'
          \ .         '  c  ""   a\n'
          \ .         '  c  "0   ba\n'
          \ .         '  c  "a   b\n'
          \ .         '.*'
          \ .         '  c  "-   a\n'
          \ .         '.*'
          \ .         '  c  ":   ls\n'
          \ .         '  c  "%   file2\n'
          \ .         '  c  "#   file1\n'
          \ .         '  c  "/   bar\n'
          \ .         '  c  "=   2\*4', a)

    let a = execute('registers a')
    call assert_match('^\nType Name Content\n'
          \ .         '  c  "a   b', a)

    let a = execute('registers :')
    call assert_match('^\nType Name Content\n'
          \ .         '  c  ":   ls', a)

    bwipe!
    let g:clipboard = save_clipboard
endfunc

func Test_register_one()
  " delete a line goes into register one
  new
  call setline(1, "one")
  normal dd
  call assert_equal("one\n", @1)

  " delete a word does not change register one, does change "-
  call setline(1, "two")
  normal de
  call assert_equal("one\n", @1)
  call assert_equal("two", @-)

  " delete a word with a register does not change register one
  call setline(1, "three")
  normal "ade
  call assert_equal("three", @a)
  call assert_equal("one\n", @1)

  " delete a word with register DOES change register one with one of a list of
  " operators
  " %
  call setline(1, ["(12)3"])
  normal "ad%
  call assert_equal("(12)", @a)
  call assert_equal("(12)", @1)

  " (
  call setline(1, ["first second"])
  normal $"ad(
  call assert_equal("first secon", @a)
  call assert_equal("first secon", @1)

  " )
  call setline(1, ["First Second."])
  normal gg0"ad)
  call assert_equal("First Second.", @a)
  call assert_equal("First Second.", @1)

  " `
  call setline(1, ["start here."])
  normal gg0fhmx0"ad`x
  call assert_equal("start ", @a)
  call assert_equal("start ", @1)

  " /
  call setline(1, ["searchX"])
  exe "normal gg0\"ad/X\<CR>"
  call assert_equal("search", @a)
  call assert_equal("search", @1)

  " ?
  call setline(1, ["Ysearch"])
  exe "normal gg$\"ad?Y\<CR>"
  call assert_equal("Ysearc", @a)
  call assert_equal("Ysearc", @1)

  " n
  call setline(1, ["Ynext"])
  normal gg$"adn
  call assert_equal("Ynex", @a)
  call assert_equal("Ynex", @1)

  " N
  call setline(1, ["prevY"])
  normal gg0"adN
  call assert_equal("prev", @a)
  call assert_equal("prev", @1)

  " }
  call setline(1, ["one", ""])
  normal gg0"ad}
  call assert_equal("one\n", @a)
  call assert_equal("one\n", @1)

  " {
  call setline(1, ["", "two"])
  normal 2G$"ad{
  call assert_equal("\ntw", @a)
  call assert_equal("\ntw", @1)

  bwipe!
endfunc

func Test_recording_status_in_ex_line()
  norm qx
  redraw!
  call assert_equal('recording @x', Screenline(&lines))
  set shortmess=q
  redraw!
  call assert_equal('', Screenline(&lines)) " Nvim: shm+=q fully hides message
  set shortmess&
  norm q
  redraw!
  call assert_equal('', Screenline(&lines))
endfunc

" Check that replaying a typed sequence does not use an Esc and following
" characters as an escape sequence.
func Test_recording_esc_sequence()
  new
  try
    let save_F2 = &t_F2
  catch
  endtry
  let t_F2 = "\<Esc>OQ"
  call feedkeys("qqiTest\<Esc>", "xt")
  call feedkeys("OQuirk\<Esc>q", "xt")
  call feedkeys("Go\<Esc>@q", "xt")
  call assert_equal(['Quirk', 'Test', 'Quirk', 'Test'], getline(1, 4))
  bwipe!
  if exists('save_F2')
    let &t_F2 = save_F2
  else
    set t_F2=
  endif
endfunc

func Test_recording_with_select_mode()
  new
  call feedkeys("qacc12345\<Esc>gH98765\<Esc>q", "tx")
  call assert_equal("98765", getline(1))
  call assert_equal("cc12345\<Esc>gH98765\<Esc>", @a)
  call setline(1, 'asdf')
  normal! @a
  call assert_equal("98765", getline(1))
  bwipe!
endfunc

func Run_test_recording_with_select_mode_utf8()
  new

  " Test with different text lengths: 5, 7, 9, 11, 13, 15, to check that
  " a character isn't split between two buffer blocks.
  for s in ['12345', '口=口', '口口口', '口=口=口', '口口=口口', '口口口口口']
    " 0x80 is K_SPECIAL
    " 0x9B is CSI
    " 哦: 0xE5 0x93 0xA6
    " 洛: 0xE6 0xB4 0x9B
    " 固: 0xE5 0x9B 0xBA
    " 四: 0xE5 0x9B 0x9B
    " 最: 0xE6 0x9C 0x80
    " 倒: 0xE5 0x80 0x92
    " 倀: 0xE5 0x80 0x80
    for c in ['哦', '洛', '固', '四', '最', '倒', '倀']
      call setline(1, 'asdf')
      call feedkeys($"qacc{s}\<Esc>gH{c}\<Esc>q", "tx")
      call assert_equal(c, getline(1))
      call assert_equal($"cc{s}\<Esc>gH{c}\<Esc>", @a)
      call setline(1, 'asdf')
      normal! @a
      call assert_equal(c, getline(1))

      " Test with Shift modifier.
      let shift_c = eval($'"\<S-{c}>"')
      call setline(1, 'asdf')
      call feedkeys($"qacc{s}\<Esc>gH{shift_c}\<Esc>q", "tx")
      call assert_equal(c, getline(1))
      call assert_equal($"cc{s}\<Esc>gH{shift_c}\<Esc>", @a)
      call setline(1, 'asdf')
      normal! @a
      call assert_equal(c, getline(1))
    endfor
  endfor

  bwipe!
endfunc

func Test_recording_with_select_mode_utf8()
  call Run_test_recording_with_select_mode_utf8()
endfunc

" This must be done as one of the last tests, because it starts the GUI, which
" cannot be undone.
func Test_zz_recording_with_select_mode_utf8_gui()
  CheckCanRunGui

  gui -f
  call Run_test_recording_with_select_mode_utf8()
endfunc

func Test_recording_with_super_mod()
  if "\<D-j>"[-1:] == '>'
    throw 'Skipped: <D- modifier not supported'
  endif

  nnoremap <D-j> <Ignore>
  let s = repeat("\<D-j>", 1000)
  " This used to crash Vim
  call feedkeys($'qr{s}q', 'tx')
  call assert_equal(s, @r)
  nunmap <D-j>
endfunc

" Test for executing the last used register (@)
func Test_last_used_exec_reg()
  " Test for the @: command
  let a = ''
  call feedkeys(":let a ..= 'Vim'\<CR>", 'xt')
  normal @:
  call assert_equal('VimVim', a)

  " Test for the @= command
  let x = ''
  let a = ":let x ..= 'Vim'\<CR>"
  exe "normal @=a\<CR>"
  normal @@
  call assert_equal('VimVim', x)

  " Test for the @. command
  let a = ''
  call feedkeys("i:let a ..= 'Edit'\<CR>", 'xt')
  normal @.
  normal @@
  call assert_equal('EditEdit', a)

  " Test for repeating the last command-line in visual mode
  call append(0, 'register')
  normal gg
  let @r = ''
  call feedkeys("v:yank R\<CR>", 'xt')
  call feedkeys("v@:", 'xt')
  call assert_equal("\nregister\nregister\n", @r)

  enew!
endfunc

func Test_get_register()
  enew
  edit Xfile1
  edit Xfile2
  call assert_equal('Xfile2', getreg('%'))
  call assert_equal('Xfile1', getreg('#'))

  call feedkeys("iTwo\<Esc>", 'xt')
  call assert_equal('Two', getreg('.'))
  call assert_equal('', getreg('_'))
  call assert_beeps('normal ":yy')
  call assert_beeps('normal "%yy')
  call assert_beeps('normal ".yy')

  call assert_equal('', getreg("\<C-F>"))
  call assert_equal('', getreg("\<C-W>"))
  call assert_equal('', getreg("\<C-L>"))
  " Change the last used register to '"' for the next test
  normal! ""yy
  let @" = 'happy'
  call assert_equal('happy', getreg())
  call assert_equal('happy', getreg(''))

  call assert_equal('', getregtype('!'))
  call assert_fails('echo getregtype([])', 'E730:')
  call assert_equal('v', getregtype())
  call assert_equal('v', getregtype(''))

  " Test for inserting an invalid register content
  call assert_beeps('exe "normal i\<C-R>!"')

  " Test for inserting a register with multiple lines
  call deletebufline('', 1, '$')
  call setreg('r', ['a', 'b'])
  exe "normal i\<C-R>r"
  call assert_equal(['a', 'b', ''], getline(1, '$'))

  " Test for inserting a multi-line register in the command line
  call feedkeys(":\<C-R>r\<Esc>", 'xt')
  " Nvim: no trailing CR because of #6137
  " call assert_equal("a\rb\r", histget(':', -1))
  call assert_equal("a\rb", histget(':', -1))

  call assert_fails('let r = getreg("=", [])', 'E745:')
  call assert_fails('let r = getreg("=", 1, [])', 'E745:')
  enew!

  " Using a register in operator-pending mode should fail
  call assert_beeps('norm! c"')
endfunc

func Test_set_register()
  call assert_fails("call setreg('#', 200)", 'E86:')
  " call assert_fails("call setreg('a', test_unknown())", 'E908:')

  edit Xfile_alt_1
  let b1 = bufnr('')
  edit Xfile_alt_2
  let b2 = bufnr('')
  edit Xfile_alt_3
  let b3 = bufnr('')
  call setreg('#', 'alt_1')
  call assert_equal('Xfile_alt_1', getreg('#'))
  call setreg('#', b2)
  call assert_equal('Xfile_alt_2', getreg('#'))

  let ab = 'regwrite'
  call setreg('=', '')
  call setreg('=', 'a', 'a')
  call setreg('=', 'b', 'a')
  call assert_equal('regwrite', getreg('='))

  " Test for setting a list of lines to special registers
  call setreg('/', [])
  call assert_equal('', @/)
  call setreg('=', [])
  call assert_equal('', @=)
  call assert_fails("call setreg('/', ['a', 'b'])", 'E883:')
  call assert_fails("call setreg('=', ['a', 'b'])", 'E883:')
  call assert_equal(0, setreg('_', ['a', 'b']))

  " Test for recording to a invalid register
  call assert_beeps('normal q$')

  " Appending to a register when recording
  call append(0, "text for clipboard test")
  normal gg
  call feedkeys('qrllq', 'xt')
  call feedkeys('qRhhq', 'xt')
  call assert_equal('llhh', getreg('r'))

  " Appending a list of characters to a register from different lines
  let @r = ''
  call append(0, ['abcdef', '123456'])
  normal gg"ry3l
  call cursor(2, 4)
  normal "Ry3l
  call assert_equal('abc456', @r)

  " Test for gP with multiple lines selected using characterwise motion
  %delete
  call append(0, ['vim editor', 'vim editor'])
  let @r = ''
  exe "normal ggwy/vim /e\<CR>gP"
  call assert_equal(['vim editor', 'vim editor', 'vim editor'], getline(1, 3))

  " Test for gP with . register
  %delete
  normal iabc
  normal ".gp
  call assert_equal('abcabc', getline(1))
  normal 0".gP
  call assert_equal('abcabcabc', getline(1))

  let @"=''
  call setreg('', '1')
  call assert_equal('1', @")
  call setreg('@', '2')
  call assert_equal('2', @")

  enew!
endfunc

" Test for blockwise register width calculations
func Test_set_register_blockwise_width()
  " Test for regular calculations and overriding the width
  call setreg('a', "12\n1234\n123", 'b')
  call assert_equal("\<c-v>4", getreginfo('a').regtype)
  call setreg('a', "12\n1234\n123", 'b1')
  call assert_equal("\<c-v>1", getreginfo('a').regtype)
  call setreg('a', "12\n1234\n123", 'b6')
  call assert_equal("\<c-v>6", getreginfo('a').regtype)

  " Test for Unicode parsing
  call setreg('a', "z😅😅z\n12345", 'b')
  call assert_equal("\<c-v>6", getreginfo('a').regtype)
  call setreg('a', ["z😅😅z", "12345"], 'b')
  call assert_equal("\<c-v>6", getreginfo('a').regtype)
endfunc

" Test for clipboard registers (* and +)
func Test_clipboard_regs()
  throw 'skipped: needs clipboard=autoselect,autoselectplus'

  CheckNotGui
  CheckFeature clipboard_working

  new
  call append(0, "text for clipboard test")
  normal gg"*yiw
  call assert_equal('text', getreg('*'))
  normal gg2w"+yiw
  call assert_equal('clipboard', getreg('+'))

  " Test for replacing the clipboard register contents
  set clipboard=unnamed
  let @* = 'food'
  normal ggviw"*p
  call assert_equal('text', getreg('*'))
  call assert_equal('food for clipboard test', getline(1))
  normal ggviw"*p
  call assert_equal('food', getreg('*'))
  call assert_equal('text for clipboard test', getline(1))

  " Test for replacing the selection register contents
  set clipboard=unnamedplus
  let @+ = 'food'
  normal ggviw"+p
  call assert_equal('text', getreg('+'))
  call assert_equal('food for clipboard test', getline(1))
  normal ggviw"+p
  call assert_equal('food', getreg('+'))
  call assert_equal('text for clipboard test', getline(1))

  " Test for auto copying visually selected text to clipboard register
  call setline(1, "text for clipboard test")
  let @* = ''
  set clipboard=autoselect
  normal ggwwviwy
  call assert_equal('clipboard', @*)

  " Test for auto copying visually selected text to selection register
  let @+ = ''
  set clipboard=autoselectplus
  normal ggwviwy
  call assert_equal('for', @+)

  set clipboard&vim
  bwipe!
endfunc

" Test for restarting the current mode (insert or virtual replace) after
" executing the contents of a register
func Test_put_reg_restart_mode()
  new
  call append(0, 'editor')
  normal gg
  let @r = "ivim \<Esc>"
  call feedkeys("i\<C-O>@r\<C-R>=mode()\<CR>", 'xt')
  call assert_equal('vimi editor', getline(1))

  call setline(1, 'editor')
  normal gg
  call feedkeys("gR\<C-O>@r\<C-R>=mode()\<CR>", 'xt')
  call assert_equal('vimReditor', getline(1))

  bwipe!
endfunc

" Test for executing a register using :@ command
func Test_execute_register()
  call setreg('r', [])
  call assert_beeps('@r')
  let i = 1
  let @q = 'let i+= 1'
  @q
  @
  call assert_equal(3, i)

  " try to execute expression register and use a backspace to cancel it
  new
  call feedkeys("@=\<BS>ax\<CR>y", 'xt')
  call assert_equal(['x', 'y'], getline(1, '$'))
  close!

  " cannot execute a register in operator pending mode
  call assert_beeps('normal! c@r')
endfunc

" Test for getting register info
func Test_get_reginfo()
  enew
  call setline(1, ['foo', 'bar'])

  exe 'norm! "zyy'
  let info = getreginfo('"')
  call assert_equal('z', info.points_to)
  call setreg('y', 'baz')
  call assert_equal('z', getreginfo('').points_to)
  call setreg('y', { 'isunnamed': v:true })
  call assert_equal('y', getreginfo('"').points_to)

  exe '$put'
  call assert_equal(getreg('y'), getline(3))
  call setreg('', 'qux')
  call assert_equal('0', getreginfo('').points_to)
  call setreg('x', 'quux')
  call assert_equal('0', getreginfo('').points_to)

  let info = getreginfo('')
  call assert_equal(getreg('', 1, 1), info.regcontents)
  call assert_equal(getregtype(''), info.regtype)

  exe "norm! 0\<c-v>e" .. '"zy'
  let info = getreginfo('z')
  call assert_equal(getreg('z', 1, 1), info.regcontents)
  call assert_equal(getregtype('z'), info.regtype)
  call assert_equal(1, +info.isunnamed)

  let info = getreginfo('"')
  call assert_equal('z', info.points_to)

  let @a="a1b2"
  nnoremap <F2> <Cmd>let g:RegInfo = getreginfo()<CR>
  exe "normal \"a\<F2>"
  call assert_equal({'regcontents': ['a1b2'], 'isunnamed': v:false,
        \ 'regtype': 'v'}, g:RegInfo)
  nunmap <F2>
  unlet g:RegInfo

  " The type of "isunnamed" was VAR_SPECIAL but should be VAR_BOOL.  Can only
  " be noticed when using json_encod().
  call setreg('a', 'foo')
  let reginfo = getreginfo('a')
  let expected = #{regcontents: ['foo'], isunnamed: v:false, regtype: 'v'}
  call assert_equal(json_encode(expected), json_encode(reginfo))

  bwipe!
endfunc

" Test for restoring register with dict from getreginfo
func Test_set_register_dict()
  enew!

  call setreg('"', #{ regcontents: ['one', 'two'],
        \ regtype: 'V', points_to: 'z' })
  call assert_equal(['one', 'two'], getreg('"', 1, 1))
  let info = getreginfo('"')
  call assert_equal('z', info.points_to)
  call assert_equal('V', info.regtype)
  call assert_equal(1, +getreginfo('z').isunnamed)

  call setreg('x', #{ regcontents: ['three', 'four'],
        \ regtype: 'v', isunnamed: v:true })
  call assert_equal(['three', 'four'], getreg('"', 1, 1))
  let info = getreginfo('"')
  call assert_equal('x', info.points_to)
  call assert_equal('v', info.regtype)
  call assert_equal(1, +getreginfo('x').isunnamed)

  call setreg('y', #{ regcontents: 'five',
        \ regtype: "\<c-v>", isunnamed: v:false })
  call assert_equal("\<c-v>4", getreginfo('y').regtype)
  call assert_equal(0, +getreginfo('y').isunnamed)
  call assert_equal(['three', 'four'], getreg('"', 1, 1))
  call assert_equal('x', getreginfo('"').points_to)

  call setreg('"', #{ regcontents: 'six' })
  call assert_equal('0', getreginfo('"').points_to)
  call assert_equal(1, +getreginfo('0').isunnamed)
  call assert_equal(['six'], getreginfo('0').regcontents)
  call assert_equal(['six'], getreginfo('"').regcontents)

  let @x = 'one'
  call setreg('x', {})
  call assert_equal(1, len(split(execute('reg x'), '\n')))

  call assert_fails("call setreg('0', #{regtype: 'V'}, 'v')", 'E118:')
  call assert_fails("call setreg('0', #{regtype: 'X'})", 'E475:')
  call assert_fails("call setreg('0', #{regtype: 'vy'})", 'E475:')

  bwipe!
endfunc

func Test_v_register()
  enew
  call setline(1, 'nothing')

  func s:Put()
    let s:register = v:register
    exec 'normal! "' .. v:register .. 'P'
  endfunc
  nnoremap <buffer> <plug>(test) :<c-u>call s:Put()<cr>
  nmap <buffer> S <plug>(test)

  let @z = "testz\n"
  let @" = "test@\n"

  let s:register = ''
  call feedkeys('"_ddS', 'mx')
  call assert_equal('test@', getline('.'))  " fails before 8.2.0929
  call assert_equal('"', s:register)        " fails before 8.2.0929

  let s:register = ''
  call feedkeys('"zS', 'mx')
  call assert_equal('z', s:register)

  let s:register = ''
  call feedkeys('"zSS', 'mx')
  call assert_equal('"', s:register)

  let s:register = ''
  call feedkeys('"_S', 'mx')
  call assert_equal('_', s:register)

  let s:register = ''
  normal "_ddS
  call assert_equal('"', s:register)        " fails before 8.2.0929
  call assert_equal('test@', getline('.'))  " fails before 8.2.0929

  let s:register = ''
  execute 'normal "z:call' "s:Put()\n"
  call assert_equal('z', s:register)
  call assert_equal('testz', getline('.'))

  " Test operator and omap
  let @b = 'testb'
  func s:OpFunc(...)
    let s:register2 = v:register
  endfunc
  set opfunc=s:OpFunc

  normal "bg@l
  normal S
  call assert_equal('"', s:register)        " fails before 8.2.0929
  call assert_equal('b', s:register2)

  func s:Motion()
    let s:register1 = v:register
    normal! l
  endfunc
  onoremap <buffer> Q :<c-u>call s:Motion()<cr>

  normal "bg@Q
  normal S
  call assert_equal('"', s:register)
  call assert_equal('b', s:register1)
  call assert_equal('"', s:register2)

  set opfunc&
  bwipe!
endfunc

" Test for executing the contents of a register as an Ex command with line
" continuation.
func Test_execute_reg_as_ex_cmd()
  " Line continuation with just two lines
  let code =<< trim END
    let l = [
      \ 1]
  END
  let @r = code->join("\n")
  let l = []
  @r
  call assert_equal([1], l)

  " Line continuation with more than two lines
  let code =<< trim END
    let l = [
      \ 1,
      \ 2,
      \ 3]
  END
  let @r = code->join("\n")
  let l = []
  @r
  call assert_equal([1, 2, 3], l)

  " use comments interspersed with code
  let code =<< trim END
    let l = [
      "\ one
      \ 1,
      "\ two
      \ 2,
      "\ three
      \ 3]
  END
  let @r = code->join("\n")
  let l = []
  @r
  call assert_equal([1, 2, 3], l)

  " use line continuation in the middle
  let code =<< trim END
    let a = "one"
    let l = [
      \ 1,
      \ 2]
    let b = "two"
  END
  let @r = code->join("\n")
  let l = []
  @r
  call assert_equal([1, 2], l)
  call assert_equal("one", a)
  call assert_equal("two", b)

  " only one line with a \
  let @r = "\\let l = 1"
  call assert_fails('@r', 'E10:')

  " only one line with a "\
  let @r = '   "\ let i = 1'
  @r
  call assert_false(exists('i'))

  " first line also begins with a \
  let @r = "\\let l = [\n\\ 1]"
  call assert_fails('@r', 'E10:')

  " Test with a large number of lines
  let @r = "let str = \n"
  let @r ..= repeat("  \\ 'abcdefghijklmnopqrstuvwxyz' ..\n", 312)
  let @r ..= '  \ ""'
  @r
  call assert_equal(repeat('abcdefghijklmnopqrstuvwxyz', 312), str)
endfunc

func Test_ve_blockpaste()
  new
  set ve=all
  0put =['QWERTZ','ASDFGH']
  call cursor(1,1)
  exe ":norm! \<C-V>3ljdP"
  call assert_equal(1, col('.'))
  call assert_equal(['QWERTZ', 'ASDFGH'], getline(1, 2))
  call cursor(1,1)
  exe ":norm! \<C-V>3ljd"
  call cursor(1,1)
  norm! $3lP
  call assert_equal(5, col('.'))
  call assert_equal(['TZ  QWER', 'GH  ASDF'], getline(1, 2))
  set ve&vim
  bwipe!
endfunc

func Test_insert_small_delete()
  new
  call setline(1, ['foo foobar bar'])
  call cursor(1,1)
  exe ":norm! ciw'\<C-R>-'"
  call assert_equal("'foo' foobar bar", getline(1))
  exe ":norm! w.w."
  call assert_equal("'foo' 'foobar' 'bar'", getline(1))
  bwipe!
endfunc

" Record in insert mode using CTRL-O
func Test_record_in_insert_mode()
  new
  let @r = ''
  call setline(1, ['foo'])
  call feedkeys("i\<C-O>qrbaz\<C-O>q", 'xt')
  call assert_equal('baz', @r)
  bwipe!
endfunc

func Test_record_in_select_mode()
  new
  call setline(1, 'text')
  sil norm q00
  sil norm q
  call assert_equal('0ext', getline(1))

  %delete
  let @r = ''
  call setline(1, ['abc', 'abc', 'abc'])
  smap <F2> <Right><Right>,
  call feedkeys("qrgh\<F2>Dk\<Esc>q", 'xt')
  call assert_equal("gh\<F2>Dk\<Esc>", @r)
  norm j0@rj0@@
  call assert_equal([',Dk', ',Dk', ',Dk'], getline(1, 3))
  sunmap <F2>

  bwipe!
endfunc

" A mapping that ends recording should be removed from the recorded register.
func Test_end_record_using_mapping()
  new
  call setline(1, 'aaa')
  nnoremap s q
  call feedkeys('safas', 'tx')
  call assert_equal('fa', @a)
  nunmap s

  nnoremap xx q
  call feedkeys('0xxafaxx', 'tx')
  call assert_equal('fa', @a)
  nunmap xx

  nnoremap xsx q
  call feedkeys('0qafaxsx', 'tx')
  call assert_equal('fa', @a)
  nunmap xsx

  bwipe!
endfunc

" Starting a new recording should work immediately after replaying a recording
" that ends with a <Nop> mapping or a character search.
func Test_end_reg_executing()
  new
  nnoremap s <Nop>
  let @a = 's'
  call feedkeys("@aqaq\<Esc>", 'tx')
  call assert_equal('', @a)
  call assert_equal('', getline(1))

  call setline(1, 'aaa')
  nnoremap s qa
  let @a = 'fa'
  call feedkeys("@asq\<Esc>", 'tx')
  call assert_equal('', @a)
  call assert_equal('aaa', getline(1))

  nunmap s
  bwipe!
endfunc

func Test_reg_executing_in_range_normal()
  new
  set showcmd
  call setline(1, range(10))
  let g:log = []
  nnoremap s <Cmd>let g:log += [reg_executing()]<CR>
  let @r = 's'

  %normal @r
  call assert_equal(repeat(['r'], 10), g:log)

  nunmap s
  unlet g:log
  set showcmd&
  bwipe!
endfunc

" An operator-pending mode mapping shouldn't be applied to keys typed in
" Insert mode immediately after a character search when replaying.
func Test_replay_charsearch_omap()
  CheckFeature timers

  new
  call setline(1, 'foo[blah]')
  onoremap , k
  call timer_start(10, {-> feedkeys(",bar\<Esc>q", 't')})
  call feedkeys('qrct[', 'xt!')
  call assert_equal(',bar[blah]', getline(1))
  call assert_equal("ct[\<Ignore>,bar\<Esc>", @r)
  call assert_equal('ct[<Ignore>,bar<Esc>', keytrans(@r))
  undo
  call assert_equal('foo[blah]', getline(1))
  call feedkeys('@r', 'xt!')
  call assert_equal(',bar[blah]', getline(1))

  ounmap ,
  bwipe!
endfunc

" Make sure that y_append is correctly reset
" and the previous register is working as expected
func Test_register_y_append_reset()
  new
  call setline(1, ['1',
    \ '2 ----------------------------------------------------',
    \ '3',
    \ '4',
    \ '5 ----------------------------------------------------',
    \ '6',
    \ '7',
    \ '8 ----------------------------------------------------',
    \ '9',
    \ '10 aaaaaaa 4.',
    \ '11 Game Dbl-Figures Leaders:',
    \ '12 Player Pts FG% 3P% FT% RB AS BL ST TO PF EFF',
    \ '13 bbbbbbbbb 12 (50 /0 /67 )/ 7/ 3/ 0/ 2/ 3/ 4/+15',
    \ '14 cccccc 12 (57 /67 /100)/ 2/ 1/ 1/ 0/ 1/ 3/+12',
    \ '15 ddddddd 10 (63 /0 /0 )/ 1/ 3/ 0/ 3/ 5/ 3/ +9',
    \ '16 4 5-15 0-3 2-2 5-12 1-1 3-4 33.3 0.0 100 41.7 100 75 12 14',
    \ '17 F 23-55 2-10 9-11 23-52 3-13 26-29 41.8 20 81.8 44.2 23.1 89.7 57 75',
    \ '18 4 3 6 3 2 3 3 4 3 3 7 3 1 4 6 -1 -1 +2 -1 -2',
    \ '19 F 13 19 5 10 4 17 22 9 14 32 13 4 20 17 -1 -13 -4 -3 -3 +5'])
  11
  exe "norm! \"a5dd"
  norm! j
  exe "norm! \"bY"
  norm! 2j
  exe "norm! \"BY"
  norm! 4k
  norm! 5dd
  norm! 3k
  " The next put should put the content of the unnamed register, not of
  " register b!
  norm! p
  call assert_equal(['1',
    \ '2 ----------------------------------------------------',
    \ '3',
    \ '4',
    \ '5 ----------------------------------------------------',
    \ '6',
    \ '10 aaaaaaa 4.',
    \ '16 4 5-15 0-3 2-2 5-12 1-1 3-4 33.3 0.0 100 41.7 100 75 12 14',
    \ '17 F 23-55 2-10 9-11 23-52 3-13 26-29 41.8 20 81.8 44.2 23.1 89.7 57 75',
    \ '18 4 3 6 3 2 3 3 4 3 3 7 3 1 4 6 -1 -1 +2 -1 -2',
    \ '19 F 13 19 5 10 4 17 22 9 14 32 13 4 20 17 -1 -13 -4 -3 -3 +5',
    \ '7',
    \ '8 ----------------------------------------------------',
    \ '9'], getline(1,'$'))
  bwipe!
endfunc

func Test_insert_small_delete_replace_mode()
  new
  call setline(1, ['foo', 'bar', 'foobar',  'bar'])
  let @- = 'foo'
  call cursor(2, 1)
  exe ":norm! R\<C-R>-\<C-R>-"
  call assert_equal('foofoo', getline(2))
  call cursor(3, 1)
  norm! D
  call assert_equal(['foo', 'foofoo', '',  'bar'], getline(1, 4))
  call cursor(4, 2)
  exe ":norm! R\<C-R>-ZZZZ"
  call assert_equal(['foo', 'foofoo', '',  'bfoobarZZZZ'], getline(1, 4))
  call cursor(1, 1)
  let @- = ''
  exe ":norm! R\<C-R>-ZZZ"
  call assert_equal(['ZZZ', 'foofoo', '',  'bfoobarZZZZ'], getline(1, 4))
  let @- = 'βbβ'
  call cursor(4, 1)
  exe ":norm! R\<C-R>-"
  call assert_equal(['ZZZ', 'foofoo', '',  'βbβobarZZZZ'], getline(1, 4))
  let @- = 'bβb'
  call cursor(4, 1)
  exe ":norm! R\<C-R>-"
  call assert_equal(['ZZZ', 'foofoo', '',  'bβbobarZZZZ'], getline(1, 4))
  let @- = 'βbβ'
  call cursor(4, 1)
  exe ":norm! R\<C-R>-"
  call assert_equal(['ZZZ', 'foofoo', '',  'βbβobarZZZZ'], getline(1, 4))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
