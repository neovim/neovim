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

" Test that matchparen works with multibyte chars in 'matchpairs'
func Test_matchparen_mbyte()
  CheckScreendump

  let lines =<< trim END
    source $VIMRUNTIME/plugin/matchparen.vim
    call setline(1, ['aaaaaaaa（', 'bbbb）cc'])
    set matchpairs+=（:）
  END

  call writefile(lines, 'XmatchparenMbyte', 'D')
  let buf = RunVimInTerminal('-S XmatchparenMbyte', #{rows: 10})
  call VerifyScreenDump(buf, 'Test_matchparen_mbyte_1', {})
  call term_sendkeys(buf, "$")
  call VerifyScreenDump(buf, 'Test_matchparen_mbyte_2', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_matchparen_mbyte_3', {})
  call term_sendkeys(buf, "2h")
  call VerifyScreenDump(buf, 'Test_matchparen_mbyte_4', {})
  call term_sendkeys(buf, "0")
  call VerifyScreenDump(buf, 'Test_matchparen_mbyte_5', {})
  call term_sendkeys(buf, "kA")
  call VerifyScreenDump(buf, 'Test_matchparen_mbyte_6', {})
  call term_sendkeys(buf, "\<Down>")
  call VerifyScreenDump(buf, 'Test_matchparen_mbyte_7', {})
  call term_sendkeys(buf, "\<C-W>")
  call VerifyScreenDump(buf, 'Test_matchparen_mbyte_8', {})

  call StopVimInTerminal(buf)
endfunc

" Test for ignoring certain parenthesis
func Test_matchparen_ignore_sh_case()
  CheckScreendump

  let lines =<< trim END
    source $VIMRUNTIME/plugin/matchparen.vim
    set ft=sh
    call setline(1, [
          \ '#!/bin/sh',
          \ 'SUSUWU_PRINT() (',
          \ '  case "${LEVEL}" in',
          \ '    "$SUSUWU_SH_NOTICE")',
          \ '    ${SUSUWU_S} && return 1',
          \ '  ;;',
          \ '    "$SUSUWU_SH_DEBUG")',
          \ '    (! ${SUSUWU_VERBOSE}) && return 1',
          \ '  ;;',
          \ '  esac',
          \ '  # snip',
          \ ')'
          \ ])
    call cursor(4, 26)
  END

  let filename = 'Xmatchparen_sh'
  call writefile(lines, filename, 'D')

  let buf = RunVimInTerminal('-S '.filename, #{rows: 10})
  call VerifyScreenDump(buf, 'Test_matchparen_sh_case_1', {})
  " Send keys one by one so that CursorMoved is triggered.
  for c in 'A foobar'
    call term_sendkeys(buf, c)
    call term_wait(buf)
  endfor
  call VerifyScreenDump(buf, 'Test_matchparen_sh_case_2', {})
  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
