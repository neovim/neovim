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

    let a = execute('display')
    let b = execute('registers')

    call assert_equal(a, b)
    call assert_match('^\nType Name Content\n'
          \ .         '  c  ""   a\n'
          \ .         '  c  "0   ba\n'
          \ .         '  c  "1   b\n'
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

func Test_recording_status_in_ex_line()
  norm qx
  redraw!
  call assert_equal('recording @x', Screenline(&lines))
  set shortmess=q
  redraw!
  call assert_equal('recording', Screenline(&lines))
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

  call assert_equal('', getregtype('!'))

  " Test for inserting an invalid register content
  call assert_beeps('exe "normal i\<C-R>!"')

  " Test for inserting a register with multiple lines
  call deletebufline('', 1, '$')
  call setreg('r', ['a', 'b'])
  exe "normal i\<C-R>r"
  call assert_equal(['a', 'b', ''], getline(1, '$'))

  " Test for inserting a multi-line register in the command line
  call feedkeys(":\<C-R>r\<Esc>", 'xt')
  call assert_equal("a\rb", histget(':', -1))  " Modified because of #6137

  enew!
endfunc

func Test_set_register()
  call assert_fails("call setreg('#', 200)", 'E86:')

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

  " Test for settting a list of lines to special registers
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

  enew!
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

func Test_ve_blockpaste()
  new
  set ve=all
  0put =['QWERTZ','ASDFGH']
  call cursor(1,1)
  exe ":norm! \<C-V>3ljdP"
  call assert_equal(1, col('.'))
  call assert_equal(getline(1, 2), ['QWERTZ', 'ASDFGH'])
  call cursor(1,1)
  exe ":norm! \<C-V>3ljd"
  call cursor(1,1)
  norm! $3lP
  call assert_equal(5, col('.'))
  call assert_equal(getline(1, 2), ['TZ  QWER', 'GH  ASDF'])
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


" vim: shiftwidth=2 sts=2 expandtab
