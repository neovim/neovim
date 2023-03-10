" Tests for startup using utf-8.

source check.vim
source shared.vim
source screendump.vim

func Test_read_stdin_utf8()
  let linesin = ['テスト', '€ÀÈÌÒÙ']
  call writefile(linesin, 'Xtestin')
  let before = [
	\ 'set enc=utf-8',
	\ 'set fencs=cp932,utf-8',
	\ ]
  let after = [
	\ 'write ++enc=utf-8 Xtestout',
	\ 'quit!',
	\ ]
  if has('win32')
    let pipecmd = 'type Xtestin | '
  else
    let pipecmd = 'cat Xtestin | '
  endif
  if RunVimPiped(before, after, '-', pipecmd)
    let lines = readfile('Xtestout')
    call assert_equal(linesin, lines)
  else
    call assert_equal('', 'RunVimPiped failed.')
  endif
  call delete('Xtestout')
  call delete('Xtestin')
endfunc

func Test_read_fifo_utf8()
  if !has('unix')
    return
  endif
  " Using bash/zsh's process substitution.
  if executable('bash')
    set shell=bash
  elseif executable('zsh')
    set shell=zsh
  else
    return
  endif
  let linesin = ['テスト', '€ÀÈÌÒÙ']
  call writefile(linesin, 'Xtestin')
  let before = [
	\ 'set enc=utf-8',
	\ 'set fencs=cp932,utf-8',
	\ ]
  let after = [
	\ 'write ++enc=utf-8 Xtestout',
	\ 'quit!',
	\ ]
  if RunVim(before, after, '<(cat Xtestin)')
    let lines = readfile('Xtestout')
    call assert_equal(linesin, lines)
  else
    call assert_equal('', 'RunVim failed.')
  endif
  call delete('Xtestout')
  call delete('Xtestin')
endfunc

func Test_detect_ambiwidth()
  CheckRunVimInTerminal

  " Use the title termcap entries to output the escape sequence.
  call writefile([
	\ 'set enc=utf-8',
	\ 'set ambiwidth=double',
	\ 'call test_option_not_set("ambiwidth")',
	\ 'redraw',
	\ ], 'Xscript')
  let buf = RunVimInTerminal('-S Xscript', #{keep_t_u7: 1})
  call term_wait(buf)
  call term_sendkeys(buf, "S\<C-R>=&ambiwidth\<CR>\<Esc>")
  call WaitForAssert({-> assert_match('single', term_getline(buf, 1))})

  call StopVimInTerminal(buf)
  call delete('Xscript')
endfunc
