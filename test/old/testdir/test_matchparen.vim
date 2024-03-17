" Test for the matchparen plugin

if !has('gui_running') && has('unix')
  " set term=ansi
endif

source view_util.vim
source check.vim
source screendump.vim

" Test for scrolling that modifies buffer during visual block
func Test_visual_block_scroll()
  CheckScreendump

  let lines =<< trim END
    source $VIMRUNTIME/plugin/matchparen.vim
    set scrolloff=1
    call setline(1, ['a', 'b', 'c', 'd', 'e', '', '{', '}', '{', 'f', 'g', '}'])
    call cursor(5, 1)
  END

  let filename = 'Xvisualblockmodifiedscroll'
  call writefile(lines, filename, 'D')

  let buf = RunVimInTerminal('-S '.filename, #{rows: 7})
  call term_sendkeys(buf, "V\<C-D>\<C-D>")

  call VerifyScreenDump(buf, 'Test_display_visual_block_scroll', {})

  call StopVimInTerminal(buf)
endfunc

" Test for clearing paren highlight when switching buffers
func Test_matchparen_clear_highlight()
  CheckScreendump

  let lines =<< trim END
    source $VIMRUNTIME/plugin/matchparen.vim
    set hidden
    call setline(1, ['()'])
    normal 0

    func OtherBuffer()
       enew
       exe "normal iaa\<Esc>0"
    endfunc
  END
  call writefile(lines, 'XMatchparenClear', 'D')
  let buf = RunVimInTerminal('-S XMatchparenClear', #{rows: 5})
  call VerifyScreenDump(buf, 'Test_matchparen_clear_highlight_1', {})

  call term_sendkeys(buf, ":call OtherBuffer()\<CR>:\<Esc>")
  call VerifyScreenDump(buf, 'Test_matchparen_clear_highlight_2', {})

  call term_sendkeys(buf, "\<C-^>:\<Esc>")
  call VerifyScreenDump(buf, 'Test_matchparen_clear_highlight_1', {})

  call term_sendkeys(buf, "\<C-^>:\<Esc>")
  call VerifyScreenDump(buf, 'Test_matchparen_clear_highlight_2', {})

  call StopVimInTerminal(buf)
endfunc

" Test for matchparen highlight when switching buffer in win_execute()
func Test_matchparen_win_execute()
  CheckScreendump

  let lines =<< trim END
    source $VIMRUNTIME/plugin/matchparen.vim
    let s:win = win_getid()
    call setline(1, '{}')
    split

    func SwitchBuf()
      call win_execute(s:win, 'enew | buffer #')
    endfunc
  END
  call writefile(lines, 'XMatchparenWinExecute', 'D')
  let buf = RunVimInTerminal('-S XMatchparenWinExecute', #{rows: 5})
  call VerifyScreenDump(buf, 'Test_matchparen_win_execute_1', {})

  " Switching buffer away and back shouldn't change matchparen highlight.
  call term_sendkeys(buf, ":call SwitchBuf()\<CR>:\<Esc>")
  call VerifyScreenDump(buf, 'Test_matchparen_win_execute_1', {})

  call StopVimInTerminal(buf)
endfunc

" Test for scrolling that modifies buffer during visual block
func Test_matchparen_pum_clear()
  CheckScreendump

  let lines =<< trim END
    source $VIMRUNTIME/plugin/matchparen.vim
    set completeopt=menuone
    call setline(1, ['aa', 'aaa', 'aaaa', '(a)'])
    call cursor(4, 3)
  END

  let filename = 'Xmatchparen'
  call writefile(lines, filename, 'D')

  let buf = RunVimInTerminal('-S '.filename, #{rows: 10})
  call term_sendkeys(buf, "i\<C-N>\<C-N>")

  call VerifyScreenDump(buf, 'Test_matchparen_pum_clear_1', {})

  call StopVimInTerminal(buf)
endfunc


" vim: shiftwidth=2 sts=2 expandtab
