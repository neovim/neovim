" Tests for editing the command line.

source check.vim
source screendump.vim
source view_util.vim
source shared.vim

func Test_complete_tab()
  call writefile(['testfile'], 'Xtestfile')
  call feedkeys(":e Xtestf\t\r", "tx")
  call assert_equal('testfile', getline(1))

  " Pressing <Tab> after '%' completes the current file, also on MS-Windows
  call feedkeys(":e %\t\r", "tx")
  call assert_equal('e Xtestfile', @:)
  call delete('Xtestfile')
endfunc

func Test_complete_list()
  " We can't see the output, but at least we check the code runs properly.
  call feedkeys(":e test\<C-D>\r", "tx")
  call assert_equal('test', expand('%:t'))

  " If a command doesn't support completion, then CTRL-D should be literally
  " used.
  call feedkeys(":chistory \<C-D>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"chistory \<C-D>", @:)
endfunc

func Test_complete_wildmenu()
  call mkdir('Xdir1/Xdir2', 'p')
  call writefile(['testfile1'], 'Xdir1/Xtestfile1')
  call writefile(['testfile2'], 'Xdir1/Xtestfile2')
  call writefile(['testfile3'], 'Xdir1/Xdir2/Xtestfile3')
  call writefile(['testfile3'], 'Xdir1/Xdir2/Xtestfile4')
  set wildmenu

  " Pressing <Tab> completes, and moves to next files when pressing again.
  call feedkeys(":e Xdir1/\<Tab>\<Tab>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))
  call feedkeys(":e Xdir1/\<Tab>\<Tab>\<Tab>\<CR>", 'tx')
  call assert_equal('testfile2', getline(1))

  " <S-Tab> is like <Tab> but begin with the last match and then go to
  " previous.
  call feedkeys(":e Xdir1/Xtest\<S-Tab>\<CR>", 'tx')
  call assert_equal('testfile2', getline(1))
  call feedkeys(":e Xdir1/Xtest\<S-Tab>\<S-Tab>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))

  " <Left>/<Right> to move to previous/next file.
  call feedkeys(":e Xdir1/\<Tab>\<Right>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))
  call feedkeys(":e Xdir1/\<Tab>\<Right>\<Right>\<CR>", 'tx')
  call assert_equal('testfile2', getline(1))
  call feedkeys(":e Xdir1/\<Tab>\<Right>\<Right>\<Left>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))

  " <Up>/<Down> to go up/down directories.
  call feedkeys(":e Xdir1/\<Tab>\<Down>\<CR>", 'tx')
  call assert_equal('testfile3', getline(1))
  call feedkeys(":e Xdir1/\<Tab>\<Down>\<Up>\<Right>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))

  " this fails in some Unix GUIs, not sure why
  if !has('unix') || !has('gui_running')
    " <C-J>/<C-K> mappings to go up/down directories when 'wildcharm' is
    " different than 'wildchar'.
    set wildcharm=<C-Z>
    cnoremap <C-J> <Down><C-Z>
    cnoremap <C-K> <Up><C-Z>
    call feedkeys(":e Xdir1/\<Tab>\<C-J>\<CR>", 'tx')
    call assert_equal('testfile3', getline(1))
    call feedkeys(":e Xdir1/\<Tab>\<C-J>\<C-K>\<CR>", 'tx')
    call assert_equal('testfile1', getline(1))
    set wildcharm=0
    cunmap <C-J>
    cunmap <C-K>
  endif

  " Test for canceling the wild menu by adding a character
  redrawstatus
  call feedkeys(":e Xdir1/\<Tab>x\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xdir1/Xdir2/x', @:)

  " Completion using a relative path
  cd Xdir1/Xdir2
  call feedkeys(":e ../\<Tab>\<Right>\<Down>\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"e Xtestfile3 Xtestfile4', @:)
  cd -

  " cleanup
  %bwipe
  call delete('Xdir1/Xdir2/Xtestfile4')
  call delete('Xdir1/Xdir2/Xtestfile3')
  call delete('Xdir1/Xtestfile2')
  call delete('Xdir1/Xtestfile1')
  call delete('Xdir1/Xdir2', 'd')
  call delete('Xdir1', 'd')
  set nowildmenu
endfunc

func Test_wildmenu_screendump()
  CheckScreendump

  let lines =<< trim [SCRIPT]
    set wildmenu hlsearch
  [SCRIPT]
  call writefile(lines, 'XTest_wildmenu')

  let buf = RunVimInTerminal('-S XTest_wildmenu', {'rows': 8})
  call term_sendkeys(buf, ":vim\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_1', {})

  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_2', {})

  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_3', {})

  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_4', {})
  call term_sendkeys(buf, "\<Esc>")

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_wildmenu')
endfunc

func Test_redraw_in_autocmd()
  CheckScreendump

  let lines =<< trim END
      set cmdheight=2
      autocmd CmdlineChanged * redraw
  END
  call writefile(lines, 'XTest_redraw', 'D')

  let buf = RunVimInTerminal('-S XTest_redraw', {'rows': 8})
  call term_sendkeys(buf, ":for i in range(3)\<CR>")
  call VerifyScreenDump(buf, 'Test_redraw_in_autocmd_1', {})

  call term_sendkeys(buf, "let i =")
  call VerifyScreenDump(buf, 'Test_redraw_in_autocmd_2', {})

  " clean up
  call term_sendkeys(buf, "\<CR>")
  call StopVimInTerminal(buf)
endfunc

func Test_redrawstatus_in_autocmd()
  CheckScreendump

  let lines =<< trim END
      set laststatus=2
      set statusline=%=:%{getcmdline()}
      autocmd CmdlineChanged * redrawstatus
  END
  call writefile(lines, 'XTest_redrawstatus', 'D')

  let buf = RunVimInTerminal('-S XTest_redrawstatus', {'rows': 8})
  " :redrawstatus is postponed if messages have scrolled
  call term_sendkeys(buf, ":echo \"one\\ntwo\\nthree\\nfour\"\<CR>")
  call term_sendkeys(buf, ":foobar")
  call VerifyScreenDump(buf, 'Test_redrawstatus_in_autocmd_1', {})
  " it is not postponed if messages have not scrolled
  call term_sendkeys(buf, "\<Esc>:for in in range(3)")
  call VerifyScreenDump(buf, 'Test_redrawstatus_in_autocmd_2', {})
  " with cmdheight=1 messages have scrolled when typing :endfor
  call term_sendkeys(buf, "\<CR>:endfor")
  call VerifyScreenDump(buf, 'Test_redrawstatus_in_autocmd_3', {})
  call term_sendkeys(buf, "\<CR>:set cmdheight=2\<CR>")
  " with cmdheight=2 messages haven't scrolled when typing :for or :endfor
  call term_sendkeys(buf, ":for in in range(3)")
  call VerifyScreenDump(buf, 'Test_redrawstatus_in_autocmd_4', {})
  call term_sendkeys(buf, "\<CR>:endfor")
  call VerifyScreenDump(buf, 'Test_redrawstatus_in_autocmd_5', {})

  " clean up
  call term_sendkeys(buf, "\<CR>")
  call StopVimInTerminal(buf)
endfunc

func Test_changing_cmdheight()
  CheckScreendump

  let lines =<< trim END
      set cmdheight=1 laststatus=2
      func EchoTwo()
        set laststatus=2
        set cmdheight=5
        echo 'foo'
        echo 'bar'
        set cmdheight=1
      endfunc
  END
  call writefile(lines, 'XTest_cmdheight', 'D')

  let buf = RunVimInTerminal('-S XTest_cmdheight', {'rows': 8})
  call term_sendkeys(buf, ":resize -3\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_1', {})

  " using the space available doesn't change the status line
  call term_sendkeys(buf, ":set cmdheight+=3\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_2', {})

  " using more space moves the status line up
  call term_sendkeys(buf, ":set cmdheight+=1\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_3', {})

  " reducing cmdheight moves status line down
  call term_sendkeys(buf, ":set cmdheight-=2\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_4', {})

  " reducing window size and then setting cmdheight 
  call term_sendkeys(buf, ":resize -1\<CR>")
  call term_sendkeys(buf, ":set cmdheight=1\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_5', {})

  " setting 'cmdheight' works after outputting two messages
  call term_sendkeys(buf, ":call EchoTwo()\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_6', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_cmdheight_tabline()
  CheckScreendump

  let buf = RunVimInTerminal('-c "set ls=2" -c "set stal=2" -c "set cmdheight=1"', {'rows': 6})
  call VerifyScreenDump(buf, 'Test_cmdheight_tabline_1', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_map_completion()
  if !has('cmdline_compl')
    return
  endif
  call feedkeys(":map <unique> <si\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <unique> <silent>', getreg(':'))
  call feedkeys(":map <script> <un\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <script> <unique>', getreg(':'))
  call feedkeys(":map <expr> <sc\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <expr> <script>', getreg(':'))
  call feedkeys(":map <buffer> <e\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <buffer> <expr>', getreg(':'))
  call feedkeys(":map <nowait> <b\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <nowait> <buffer>', getreg(':'))
  call feedkeys(":map <special> <no\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <special> <nowait>', getreg(':'))
  call feedkeys(":map <silent> <sp\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <silent> <special>', getreg(':'))

  map <Middle>x middle

  map ,f commaf
  map ,g commaf
  map <Left> left
  map <A-Left>x shiftleft
  call feedkeys(":map ,\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map ,f', getreg(':'))
  call feedkeys(":map ,\<Tab>\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map ,g', getreg(':'))
  call feedkeys(":map <L\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <Left>', getreg(':'))
  call feedkeys(":map <A-Left>\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal("\"map <A-Left>\<Tab>", getreg(':'))
  unmap ,f
  unmap ,g
  unmap <Left>
  unmap <A-Left>x

  set cpo-=< cpo-=B cpo-=k
  map <Left> left
  call feedkeys(":map <L\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <Left>', getreg(':'))
  call feedkeys(":map <M\<Tab>\<Home>\"\<CR>", 'xt')
  " call assert_equal("\"map <M\<Tab>", getreg(':'))
  unmap <Left>

  " set cpo+=<
  map <Left> left
  exe "set t_k6=\<Esc>[17~"
  call feedkeys(":map \<Esc>[17~x f6x\<CR>", 'xt')
  call feedkeys(":map <L\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <Left>', getreg(':'))
  if !has('gui_running')
    call feedkeys(":map \<Esc>[17~\<Tab>\<Home>\"\<CR>", 'xt')
    " call assert_equal("\"map <F6>x", getreg(':'))
  endif
  unmap <Left>
  call feedkeys(":unmap \<Esc>[17~x\<CR>", 'xt')
  set cpo-=<

  set cpo+=B
  map <Left> left
  call feedkeys(":map <L\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <Left>', getreg(':'))
  unmap <Left>
  set cpo-=B

  " set cpo+=k
  map <Left> left
  call feedkeys(":map <L\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <Left>', getreg(':'))
  unmap <Left>
  " set cpo-=k

  unmap <Middle>x
  set cpo&vim
endfunc

func Test_match_completion()
  if !has('cmdline_compl')
    return
  endif
  hi Aardig ctermfg=green
  call feedkeys(":match A\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"match Aardig', getreg(':'))
  call feedkeys(":match \<S-Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"match none', getreg(':'))
endfunc

func Test_highlight_completion()
  if !has('cmdline_compl')
    return
  endif
  hi Aardig ctermfg=green
  call feedkeys(":hi default A\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"hi default Aardig', getreg(':'))
  call feedkeys(":hi clear Aa\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"hi clear Aardig', getreg(':'))
  call feedkeys(":hi li\<S-Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"hi link', getreg(':'))
  call feedkeys(":hi d\<S-Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"hi default', getreg(':'))
  call feedkeys(":hi c\<S-Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"hi clear', getreg(':'))

  " A cleared group does not show up in completions.
  hi Anders ctermfg=green
  call assert_equal(['Aardig', 'Anders'], getcompletion('A', 'highlight'))
  hi clear Aardig
  call assert_equal(['Anders'], getcompletion('A', 'highlight'))
  hi clear Anders
  call assert_equal([], getcompletion('A', 'highlight'))
endfunc

func Test_expr_completion()
  if !has('cmdline_compl')
    return
  endif
  for cmd in [
	\ 'let a = ',
	\ 'const a = ',
	\ 'if',
	\ 'elseif',
	\ 'while',
	\ 'for',
	\ 'echo',
	\ 'echon',
	\ 'execute',
	\ 'echomsg',
	\ 'echoerr',
	\ 'call',
	\ 'return',
	\ 'cexpr',
	\ 'caddexpr',
	\ 'cgetexpr',
	\ 'lexpr',
	\ 'laddexpr',
	\ 'lgetexpr']
    call feedkeys(":" . cmd . " getl\<Tab>\<Home>\"\<CR>", 'xt')
    call assert_equal('"' . cmd . ' getline(', getreg(':'))
  endfor
endfunc

func Test_getcompletion()
  if !has('cmdline_compl')
    return
  endif
  let groupcount = len(getcompletion('', 'event'))
  call assert_true(groupcount > 0)
  let matchcount = len('File'->getcompletion('event'))
  call assert_true(matchcount > 0)
  call assert_true(groupcount > matchcount)

  if has('menu')
    source $VIMRUNTIME/menu.vim
    let matchcount = len(getcompletion('', 'menu'))
    call assert_true(matchcount > 0)
    call assert_equal(['File.'], getcompletion('File', 'menu'))
    call assert_true(matchcount > 0)
    let matchcount = len(getcompletion('File.', 'menu'))
    call assert_true(matchcount > 0)
  endif

  let l = getcompletion('v:n', 'var')
  call assert_true(index(l, 'v:null') >= 0)
  let l = getcompletion('v:notexists', 'var')
  call assert_equal([], l)

  args a.c b.c
  let l = getcompletion('', 'arglist')
  call assert_equal(['a.c', 'b.c'], l)
  %argdelete

  let l = getcompletion('', 'augroup')
  call assert_true(index(l, 'END') >= 0)
  let l = getcompletion('blahblah', 'augroup')
  call assert_equal([], l)

  let l = getcompletion('', 'behave')
  call assert_true(index(l, 'mswin') >= 0)
  let l = getcompletion('not', 'behave')
  call assert_equal([], l)

  let l = getcompletion('', 'color')
  call assert_true(index(l, 'default') >= 0)
  let l = getcompletion('dirty', 'color')
  call assert_equal([], l)

  let l = getcompletion('', 'command')
  call assert_true(index(l, 'sleep') >= 0)
  let l = getcompletion('awake', 'command')
  call assert_equal([], l)

  let l = getcompletion('', 'dir')
  call assert_true(index(l, 'sautest/') >= 0)
  let l = getcompletion('NoMatch', 'dir')
  call assert_equal([], l)

  if glob('~/*') !=# ''
    let l = getcompletion('~/', 'dir')
    call assert_true(l[0][0] ==# '~')
  endif

  let l = getcompletion('exe', 'expression')
  call assert_true(index(l, 'executable(') >= 0)
  let l = getcompletion('kill', 'expression')
  call assert_equal([], l)

  let l = getcompletion('tag', 'function')
  call assert_true(index(l, 'taglist(') >= 0)
  let l = getcompletion('paint', 'function')
  call assert_equal([], l)

  let Flambda = {-> 'hello'}
  let l = getcompletion('', 'function')
  let l = filter(l, {i, v -> v =~ 'lambda'})
  call assert_equal(0, len(l))

  let l = getcompletion('run', 'file')
  call assert_true(index(l, 'runtest.vim') >= 0)
  let l = getcompletion('walk', 'file')
  call assert_equal([], l)
  set wildignore=*.vim
  let l = getcompletion('run', 'file', 1)
  call assert_true(index(l, 'runtest.vim') < 0)
  set wildignore&

  let l = getcompletion('ha', 'filetype')
  call assert_true(index(l, 'hamster') >= 0)
  let l = getcompletion('horse', 'filetype')
  call assert_equal([], l)

  let l = getcompletion('z', 'syntax')
  call assert_true(index(l, 'zimbu') >= 0)
  let l = getcompletion('emacs', 'syntax')
  call assert_equal([], l)

  let l = getcompletion('jikes', 'compiler')
  call assert_true(index(l, 'jikes') >= 0)
  let l = getcompletion('break', 'compiler')
  call assert_equal([], l)

  let l = getcompletion('last', 'help')
  call assert_true(index(l, ':tablast') >= 0)
  let l = getcompletion('giveup', 'help')
  call assert_equal([], l)

  let l = getcompletion('time', 'option')
  call assert_true(index(l, 'timeoutlen') >= 0)
  let l = getcompletion('space', 'option')
  call assert_equal([], l)

  let l = getcompletion('er', 'highlight')
  call assert_true(index(l, 'ErrorMsg') >= 0)
  let l = getcompletion('dark', 'highlight')
  call assert_equal([], l)

  let l = getcompletion('', 'messages')
  call assert_true(index(l, 'clear') >= 0)
  let l = getcompletion('not', 'messages')
  call assert_equal([], l)

  let l = getcompletion('', 'mapclear')
  call assert_true(index(l, '<buffer>') >= 0)
  let l = getcompletion('not', 'mapclear')
  call assert_equal([], l)

  let l = getcompletion('.', 'shellcmd')
  call assert_equal(['./', '../'], filter(l, 'v:val =~ "\\./"'))
  call assert_equal(-1, match(l[2:], '^\.\.\?/$'))
  let root = has('win32') ? 'C:\\' : '/'
  let l = getcompletion(root, 'shellcmd')
  let expected = map(filter(glob(root . '*', 0, 1),
        \ 'isdirectory(v:val) || executable(v:val)'), 'isdirectory(v:val) ? v:val . ''/'' : v:val')
  call assert_equal(expected, l)

  if has('cscope')
    let l = getcompletion('', 'cscope')
    let cmds = ['add', 'find', 'help', 'kill', 'reset', 'show']
    call assert_equal(cmds, l)
    " using cmdline completion must not change the result
    call feedkeys(":cscope find \<c-d>\<c-c>", 'xt')
    let l = getcompletion('', 'cscope')
    call assert_equal(cmds, l)
    let keys = ['a', 'c', 'd', 'e', 'f', 'g', 'i', 's', 't']
    let l = getcompletion('find ', 'cscope')
    call assert_equal(keys, l)
  endif

  if has('signs')
    sign define Testing linehl=Comment
    let l = getcompletion('', 'sign')
    let cmds = ['define', 'jump', 'list', 'place', 'undefine', 'unplace']
    call assert_equal(cmds, l)
    " using cmdline completion must not change the result
    call feedkeys(":sign list \<c-d>\<c-c>", 'xt')
    let l = getcompletion('', 'sign')
    call assert_equal(cmds, l)
    let l = getcompletion('list ', 'sign')
    call assert_equal(['Testing'], l)
  endif

  " Command line completion tests
  let l = getcompletion('cd ', 'cmdline')
  call assert_true(index(l, 'sautest/') >= 0)
  let l = getcompletion('cd NoMatch', 'cmdline')
  call assert_equal([], l)
  let l = getcompletion('let v:n', 'cmdline')
  call assert_true(index(l, 'v:null') >= 0)
  let l = getcompletion('let v:notexists', 'cmdline')
  call assert_equal([], l)
  let l = getcompletion('call tag', 'cmdline')
  call assert_true(index(l, 'taglist(') >= 0)
  let l = getcompletion('call paint', 'cmdline')
  call assert_equal([], l)

  func T(a, c, p)
    let g:cmdline_compl_params = [a:a, a:c, a:p]
    return "oneA\noneB\noneC"
  endfunc
  command -nargs=1 -complete=custom,T MyCmd
  let l = getcompletion('MyCmd ', 'cmdline')
  call assert_equal(['oneA', 'oneB', 'oneC'], l)
  call assert_equal(['', 'MyCmd ', 6], g:cmdline_compl_params)

  delcommand MyCmd
  delfunc T
  unlet g:cmdline_compl_params

  " For others test if the name is recognized.
  let names = ['buffer', 'environment', 'file_in_path', 'mapping', 'tag', 'tag_listfiles', 'user']
  if has('cmdline_hist')
    call add(names, 'history')
  endif
  if has('gettext')
    call add(names, 'locale')
  endif
  if has('profile')
    call add(names, 'syntime')
  endif

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//", "word\tfile\tcmd"], 'Xtags')

  for name in names
    let matchcount = len(getcompletion('', name))
    call assert_true(matchcount >= 0, 'No matches for ' . name)
  endfor

  call delete('Xtags')
  set tags&

  call assert_fails("call getcompletion('\\\\@!\\\\@=', 'buffer')", 'E871:')
  call assert_fails('call getcompletion("", "burp")', 'E475:')
  call assert_fails('call getcompletion("abc", [])', 'E475:')
endfunc

func Test_fullcommand()
  let tests = {
        \ '':           '',
        \ ':':          '',
        \ ':::':        '',
        \ ':::5':       '',
        \ 'not_a_cmd':  '',
        \ 'Check':      '',
        \ 'syntax':     'syntax',
        \ ':syntax':    'syntax',
        \ '::::syntax': 'syntax',
        \ 'sy':         'syntax',
        \ 'syn':        'syntax',
        \ 'synt':       'syntax',
        \ ':sy':        'syntax',
        \ '::::sy':     'syntax',
        \ 'match':      'match',
        \ '2match':     'match',
        \ '3match':     'match',
        \ 'aboveleft':  'aboveleft',
        \ 'abo':        'aboveleft',
        \ 's':          'substitute',
        \ '5s':         'substitute',
        \ ':5s':        'substitute',
        \ "'<,'>s":     'substitute',
        \ ":'<,'>s":    'substitute',
        \ 'CheckUni':   'CheckUnix',
        \ 'CheckUnix':  'CheckUnix',
  \ }

  for [in, want] in items(tests)
    call assert_equal(want, fullcommand(in))
  endfor
  call assert_equal('', fullcommand(v:_null_string))

  call assert_equal('syntax', 'syn'->fullcommand())

  command -buffer BufferLocalCommand :
  command GlobalCommand :
  call assert_equal('GlobalCommand', fullcommand('GlobalCom'))
  call assert_equal('BufferLocalCommand', fullcommand('BufferL'))
  delcommand BufferLocalCommand
  delcommand GlobalCommand
endfunc

func Test_shellcmd_completion()
  let save_path = $PATH

  call mkdir('Xpathdir/Xpathsubdir', 'p')
  call writefile([''], 'Xpathdir/Xfile.exe')
  call setfperm('Xpathdir/Xfile.exe', 'rwx------')

  " Set PATH to example directory without trailing slash.
  let $PATH = getcwd() . '/Xpathdir'

  " Test for the ":!<TAB>" case.  Previously, this would include subdirs of
  " dirs in the PATH, even though they won't be executed.  We check that only
  " subdirs of the PWD and executables from the PATH are included in the
  " suggestions.
  let actual = getcompletion('X', 'shellcmd')
  let expected = map(filter(glob('*', 0, 1), 'isdirectory(v:val) && v:val[0] == "X"'), 'v:val . "/"')
  call insert(expected, 'Xfile.exe')
  call assert_equal(expected, actual)

  call delete('Xpathdir', 'rf')
  let $PATH = save_path
endfunc

func Test_expand_star_star()
  call mkdir('a/b', 'p')
  call writefile(['asdfasdf'], 'a/b/fileXname')
  call feedkeys(":find **/fileXname\<Tab>\<CR>", 'xt')
  call assert_equal('find a/b/fileXname', getreg(':'))
  bwipe!
  call delete('a', 'rf')
endfunc

func Test_cmdline_paste()
  let @a = "def"
  call feedkeys(":abc \<C-R>a ghi\<C-B>\"\<CR>", 'tx')
  call assert_equal('"abc def ghi', @:)

  new
  call setline(1, 'asdf.x /tmp/some verylongword a;b-c*d ')

  call feedkeys(":aaa \<C-R>\<C-W> bbb\<C-B>\"\<CR>", 'tx')
  call assert_equal('"aaa asdf bbb', @:)

  call feedkeys("ft:aaa \<C-R>\<C-F> bbb\<C-B>\"\<CR>", 'tx')
  call assert_equal('"aaa /tmp/some bbb', @:)

  call feedkeys(":aaa \<C-R>\<C-L> bbb\<C-B>\"\<CR>", 'tx')
  call assert_equal('"aaa '.getline(1).' bbb', @:)

  set incsearch
  call feedkeys("fy:aaa veryl\<C-R>\<C-W> bbb\<C-B>\"\<CR>", 'tx')
  call assert_equal('"aaa verylongword bbb', @:)

  call feedkeys("f;:aaa \<C-R>\<C-A> bbb\<C-B>\"\<CR>", 'tx')
  call assert_equal('"aaa a;b-c*d bbb', @:)

  call feedkeys(":\<C-\>etoupper(getline(1))\<CR>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"ASDF.X /TMP/SOME VERYLONGWORD A;B-C*D ', @:)
  bwipe!

  " Error while typing a command used to cause that it was not executed
  " in the end.
  new
  try
    call feedkeys(":file \<C-R>%Xtestfile\<CR>", 'tx')
  catch /^Vim\%((\a\+)\)\=:E32/
    " ignore error E32
  endtry
  call assert_equal("Xtestfile", bufname("%"))

  " Try to paste an invalid register using <C-R>
  call feedkeys(":\"one\<C-R>\<C-X>two\<CR>", 'xt')
  call assert_equal('"onetwo', @:)

  " Test for pasting register containing CTRL-H using CTRL-R and CTRL-R CTRL-R
  let @a = "xy\<C-H>z"
  call feedkeys(":\"\<C-R>a\<CR>", 'xt')
  call assert_equal('"xz', @:)
  call feedkeys(":\"\<C-R>\<C-R>a\<CR>", 'xt')
  call assert_equal("\"xy\<C-H>z", @:)
  call feedkeys(":\"\<C-R>\<C-O>a\<CR>", 'xt')
  call assert_equal("\"xy\<C-H>z", @:)

  " Test for pasting register containing CTRL-V using CTRL-R and CTRL-R CTRL-R
  let @a = "xy\<C-V>z"
  call feedkeys(":\"\<C-R>=@a\<CR>\<cr>", 'xt')
  call assert_equal('"xyz', @:)
  call feedkeys(":\"\<C-R>\<C-R>=@a\<CR>\<cr>", 'xt')
  call assert_equal("\"xy\<C-V>z", @:)

  call assert_beeps('call feedkeys(":\<C-R>=\<C-R>=\<Esc>", "xt")')

  bwipe!
endfunc

func Test_cmdline_remove_char()
  let encoding_save = &encoding

  " for e in ['utf8', 'latin1']
  for e in ['utf8']
    exe 'set encoding=' . e

    call feedkeys(":abc def\<S-Left>\<Del>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"abc ef', @:, e)

    call feedkeys(":abc def\<S-Left>\<BS>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"abcdef', @:)

    call feedkeys(":abc def ghi\<S-Left>\<C-W>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"abc ghi', @:, e)

    call feedkeys(":abc def\<S-Left>\<C-U>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"def', @:, e)

    " This was going before the start in latin1.
    call feedkeys(": \<C-W>\<CR>", 'tx')
  endfor

  let &encoding = encoding_save
endfunc

func Test_cmdline_keymap_ctrl_hat()
  if !has('keymap')
    return
  endif

  set keymap=esperanto
  call feedkeys(":\"Jxauxdo \<C-^>Jxauxdo \<C-^>Jxauxdo\<CR>", 'tx')
  call assert_equal('"Jxauxdo Ĵaŭdo Jxauxdo', @:)
  set keymap=
endfunc

func Test_illegal_address1()
  new
  2;'(
  2;')
  quit
endfunc

func Test_illegal_address2()
  call writefile(['c', 'x', '  x', '.', '1;y'], 'Xtest.vim')
  new
  source Xtest.vim
  " Trigger calling validate_cursor()
  diffsp Xtest.vim
  quit!
  bwipe!
  call delete('Xtest.vim')
endfunc

func Test_mark_from_line_zero()
  " this was reading past the end of the first (empty) line
  new
  norm oxxxx
  call assert_fails("0;'(", 'E20:')
  bwipe!
endfunc

func Test_cmdline_complete_wildoptions()
  help
  call feedkeys(":tag /\<c-a>\<c-b>\"\<cr>", 'tx')
  let a = join(sort(split(@:)),' ')
  set wildoptions=tagfile
  call feedkeys(":tag /\<c-a>\<c-b>\"\<cr>", 'tx')
  let b = join(sort(split(@:)),' ')
  call assert_equal(a, b)
  bw!
endfunc

func Test_cmdline_complete_user_cmd()
  command! -complete=color -nargs=1 Foo :
  call feedkeys(":Foo \<Tab>\<Home>\"\<cr>", 'tx')
  call assert_equal('"Foo blue', @:)
  call feedkeys(":Foo b\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_equal('"Foo blue', @:)
  delcommand Foo
endfunc

func Test_complete_user_cmd()
  command FooBar echo 'global'
  command -buffer FooBar echo 'local'
  call feedkeys(":Foo\<C-A>\<Home>\"\<CR>", 'tx')
  call assert_equal('"FooBar', @:)

  delcommand -buffer FooBar
  delcommand FooBar
endfunc

func s:ScriptLocalFunction()
  echo 'yes'
endfunc

func Test_cmdline_complete_user_func()
  call feedkeys(":func Test_cmdline_complete_user\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_match('"func Test_cmdline_complete_user_', @:)
  call feedkeys(":func s:ScriptL\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_match('"func <SNR>\d\+_ScriptLocalFunction', @:)

  " g: prefix also works
  call feedkeys(":echo g:Test_cmdline_complete_user_f\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_match('"echo g:Test_cmdline_complete_user_func', @:)

  " using g: prefix does not result in just "g:" matches from a lambda
  let Fx = { a ->  a }
  call feedkeys(":echo g:\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_match('"echo g:[A-Z]', @:)

  " existence of script-local dict function does not break user function name
  " completion
  function s:a_dict_func() dict
  endfunction
  call feedkeys(":call Test_cmdline_complete_user\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_match('"call Test_cmdline_complete_user_', @:)
  delfunction s:a_dict_func
endfunc

func Test_cmdline_complete_user_names()
  if has('unix') && executable('whoami')
    let whoami = systemlist('whoami')[0]
    let first_letter = whoami[0]
    if len(first_letter) > 0
      " Trying completion of  :e ~x  where x is the first letter of
      " the user name should complete to at least the user name.
      call feedkeys(':e ~' . first_letter . "\<c-a>\<c-B>\"\<cr>", 'tx')
      call assert_match('^"e \~.*\<' . whoami . '\>', @:)
    endif
  endif
  if has('win32')
    " Just in case: check that the system has an Administrator account.
    let names = system('net user')
    if names =~ 'Administrator'
      " Trying completion of  :e ~A  should complete to Administrator.
      " There could be other names starting with "A" before Administrator.
      call feedkeys(':e ~A' . "\<c-a>\<c-B>\"\<cr>", 'tx')
      call assert_match('^"e \~.*Administrator', @:)
    endif
  endif
endfunc

func Test_cmdline_complete_bang()
  if executable('whoami')
    call feedkeys(":!whoam\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_match('^".*\<whoami\>', @:)
  endif
endfunc

funct Test_cmdline_complete_languages()
  let lang = substitute(execute('language time'), '.*"\(.*\)"$', '\1', '')
  call assert_equal(lang, v:lc_time)

  let lang = substitute(execute('language ctype'), '.*"\(.*\)"$', '\1', '')
  call assert_equal(lang, v:ctype)

  let lang = substitute(execute('language collate'), '.*"\(.*\)"$', '\1', '')
  call assert_equal(lang, v:collate)

  let lang = substitute(execute('language messages'), '.*"\(.*\)"$', '\1', '')
  call assert_equal(lang, v:lang)

  call feedkeys(":language \<c-a>\<c-b>\"\<cr>", 'tx')
  call assert_match('^"language .*\<collate\>.*\<ctype\>.*\<messages\>.*\<time\>', @:)

  if has('unix')
    " TODO: these tests don't work on Windows. lang appears to be 'C'
    " but C does not appear in the completion. Why?
    call assert_match('^"language .*\<' . lang . '\>', @:)

    call feedkeys(":language messages \<c-a>\<c-b>\"\<cr>", 'tx')
    call assert_match('^"language .*\<' . lang . '\>', @:)

    call feedkeys(":language ctype \<c-a>\<c-b>\"\<cr>", 'tx')
    call assert_match('^"language .*\<' . lang . '\>', @:)

    call feedkeys(":language time \<c-a>\<c-b>\"\<cr>", 'tx')
    call assert_match('^"language .*\<' . lang . '\>', @:)

    call feedkeys(":language collate \<c-a>\<c-b>\"\<cr>", 'tx')
    call assert_match('^"language .*\<' . lang . '\>', @:)
  endif
endfunc

func Test_cmdline_complete_env_variable()
  let $X_VIM_TEST_COMPLETE_ENV = 'foo'

  call feedkeys(":edit $X_VIM_TEST_COMPLETE_E\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('"edit $X_VIM_TEST_COMPLETE_ENV', @:)

  unlet $X_VIM_TEST_COMPLETE_ENV
endfunc

func Test_cmdline_complete_expression()
  let g:SomeVar = 'blah'
  for cmd in ['exe', 'echo', 'echon', 'echomsg']
    call feedkeys(":" .. cmd .. " SomeV\<Tab>\<C-B>\"\<CR>", 'tx')
    call assert_match('"' .. cmd .. ' SomeVar', @:)
    call feedkeys(":" .. cmd .. " foo SomeV\<Tab>\<C-B>\"\<CR>", 'tx')
    call assert_match('"' .. cmd .. ' foo SomeVar', @:)
  endfor
  unlet g:SomeVar
endfunc

" Test for various command-line completion
func Test_cmdline_complete_various()
  " completion for a command starting with a comment
  call feedkeys(": :|\"\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\" :|\"\<C-A>", @:)

  " completion for a range followed by a comment
  call feedkeys(":1,2\"\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"1,2\"\<C-A>", @:)

  " completion for :k command
  call feedkeys(":ka\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"ka\<C-A>", @:)

  " completion for short version of the :s command
  call feedkeys(":sI \<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"sI \<C-A>", @:)

  " completion for :write command
  call mkdir('Xdir')
  call writefile(['one'], 'Xdir/Xfile1')
  let save_cwd = getcwd()
  cd Xdir
  call feedkeys(":w >> \<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"w >> Xfile1", @:)
  call chdir(save_cwd)
  call delete('Xdir', 'rf')

  " completion for :w ! and :r ! commands
  call feedkeys(":w !invalid_xyz_cmd\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"w !invalid_xyz_cmd", @:)
  call feedkeys(":r !invalid_xyz_cmd\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"r !invalid_xyz_cmd", @:)

  " completion for :>> and :<< commands
  call feedkeys(":>>>\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\">>>\<C-A>", @:)
  call feedkeys(":<<<\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"<<<\<C-A>", @:)

  " completion for command with +cmd argument
  call feedkeys(":buffer +/pat Xabc\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"buffer +/pat Xabc", @:)
  call feedkeys(":buffer +/pat\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"buffer +/pat\<C-A>", @:)

  " completion for a command with a trailing comment
  call feedkeys(":ls \" comment\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"ls \" comment\<C-A>", @:)

  " completion for a command with a trailing command
  call feedkeys(":ls | ls\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"ls | ls", @:)

  " completion for a command with an CTRL-V escaped argument
  call feedkeys(":ls \<C-V>\<C-V>a\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"ls \<C-V>a\<C-A>", @:)

  " completion for a command that doesn't take additional arguments
  call feedkeys(":all abc\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"all abc\<C-A>", @:)

  " completion for :wincmd with :horizontal modifier
  call feedkeys(":horizontal wincm\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"horizontal wincmd", @:)

  " completion for a command with a command modifier
  call feedkeys(":topleft new\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"topleft new", @:)

  " completion for the :match command
  call feedkeys(":match Search /pat/\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"match Search /pat/\<C-A>", @:)

  " completion for the :s command
  call feedkeys(":s/from/to/g\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s/from/to/g\<C-A>", @:)

  " completion for the :dlist command
  call feedkeys(":dlist 10 /pat/ a\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"dlist 10 /pat/ a\<C-A>", @:)

  " completion for the :doautocmd command
  call feedkeys(":doautocmd User MyCmd a.c\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"doautocmd User MyCmd a.c\<C-A>", @:)

  " completion of autocmd group after comma
  call feedkeys(":doautocmd BufNew,BufEn\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"doautocmd BufNew,BufEnter", @:)

  " completion of file name in :doautocmd
  call writefile([], 'Xfile1')
  call writefile([], 'Xfile2')
  call feedkeys(":doautocmd BufEnter Xfi\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"doautocmd BufEnter Xfile1 Xfile2", @:)
  call delete('Xfile1')
  call delete('Xfile2')

  " completion for the :augroup command
  augroup XTest.test
  augroup END
  call feedkeys(":augroup X\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"augroup XTest.test", @:)
  call feedkeys(":au X\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"au XTest.test", @:)
  augroup! XTest.test

  " completion for the :unlet command
  call feedkeys(":unlet one two\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"unlet one two", @:)

  " completion for the :buffer command with curlies
  " FIXME: what should happen on MS-Windows?
  if !has('win32')
    edit \{someFile}
    call feedkeys(":buf someFile\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal("\"buf {someFile}", @:)
    bwipe {someFile}
  endif

  " completion for the :bdelete command
  call feedkeys(":bdel a b c\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"bdel a b c", @:)

  " completion for the :mapclear command
  call feedkeys(":mapclear \<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"mapclear <buffer>", @:)

  " completion for user defined commands with menu names
  menu Test.foo :ls<CR>
  com -nargs=* -complete=menu MyCmd
  call feedkeys(":MyCmd Te\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd Test.', @:)
  delcom MyCmd
  unmenu Test

  " completion for user defined commands with mappings
  mapclear
  map <F3> :ls<CR>
  com -nargs=* -complete=mapping MyCmd
  call feedkeys(":MyCmd <F\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd <F3>', @:)
  mapclear
  delcom MyCmd

  " completion for :set path= with multiple backslashes
  call feedkeys(":set path=a\\\\\\ b\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set path=a\\\ b', @:)

  " completion for :set dir= with a backslash
  call feedkeys(":set dir=a\\ b\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set dir=a\ b', @:)

  " completion for the :py3 commands
  call feedkeys(":py3\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"py3 py3do py3file', @:)

  " redir @" is not the start of a comment. So complete after that
  call feedkeys(":redir @\" | cwin\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"redir @" | cwindow', @:)

  " completion after a backtick
  call feedkeys(":e `a1b2c\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e `a1b2c', @:)

  " completion for the expression register
  call feedkeys(":\"\<C-R>=float2\t\"\<C-B>\"\<CR>", 'xt')
  call assert_equal('"float2nr("', @=)
endfunc

func Test_cmdline_write_alternatefile()
  new
  call setline('.', ['one', 'two'])
  f foo.txt
  new
  f #-A
  call assert_equal('foo.txt-A', expand('%'))
  f #<-B.txt
  call assert_equal('foo-B.txt', expand('%'))
  f %<
  call assert_equal('foo-B', expand('%'))
  new
  call assert_fails('f #<', 'E95')
  bw!
  f foo-B.txt
  f %<-A
  call assert_equal('foo-B-A', expand('%'))
  bw!
  bw!
endfunc

func Test_cmdline_expand_cur_alt_file()
  enew
  file http://some.com/file.txt
  call feedkeys(":e %\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e http://some.com/file.txt', @:)
  edit another
  call feedkeys(":e #\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e http://some.com/file.txt', @:)
  bwipe
  bwipe http://some.com/file.txt
endfunc

" using a leading backslash here
set cpo+=C

func Test_cmdline_search_range()
  new
  call setline(1, ['a', 'b', 'c', 'd'])
  /d
  1,\/s/b/B/
  call assert_equal('B', getline(2))

  /a
  $
  \?,4s/c/C/
  call assert_equal('C', getline(3))

  call setline(1, ['a', 'b', 'c', 'd'])
  %s/c/c/
  1,\&s/b/B/
  call assert_equal('B', getline(2))

  let @/ = 'apple'
  call assert_fails('\/print', 'E486:')

  bwipe!
endfunc

" Test for the tick mark (') in an excmd range
func Test_tick_mark_in_range()
  " If only the tick is passed as a range and no command is specified, there
  " should not be an error
  call feedkeys(":'\<CR>", 'xt')
  call assert_equal("'", getreg(':'))
  call assert_fails("',print", 'E78:')
endfunc

" Test for using a line number followed by a search pattern as range
func Test_lnum_and_pattern_as_range()
  new
  call setline(1, ['foo 1', 'foo 2', 'foo 3'])
  let @" = ''
  2/foo/yank
  call assert_equal("foo 3\n", @")
  call assert_equal(1, line('.'))
  close!
endfunc

" Tests for getcmdline(), getcmdpos() and getcmdtype()
func Check_cmdline(cmdtype)
  call assert_equal('MyCmd a', getcmdline())
  call assert_equal(8, getcmdpos())
  call assert_equal(a:cmdtype, getcmdtype())
  return ''
endfunc

set cpo&

func Test_getcmdtype()
  call feedkeys(":MyCmd a\<C-R>=Check_cmdline(':')\<CR>\<Esc>", "xt")

  let cmdtype = ''
  debuggreedy
  call feedkeys(":debug echo 'test'\<CR>", "t")
  call feedkeys("let cmdtype = \<C-R>=string(getcmdtype())\<CR>\<CR>", "t")
  call feedkeys("cont\<CR>", "xt")
  0debuggreedy
  call assert_equal('>', cmdtype)

  call feedkeys("/MyCmd a\<C-R>=Check_cmdline('/')\<CR>\<Esc>", "xt")
  call feedkeys("?MyCmd a\<C-R>=Check_cmdline('?')\<CR>\<Esc>", "xt")

  call feedkeys(":call input('Answer?')\<CR>", "t")
  call feedkeys("MyCmd a\<C-R>=Check_cmdline('@')\<CR>\<C-C>", "xt")

  call feedkeys(":insert\<CR>MyCmd a\<C-R>=Check_cmdline('-')\<CR>\<Esc>", "xt")

  cnoremap <expr> <F6> Check_cmdline('=')
  call feedkeys("a\<C-R>=MyCmd a\<F6>\<Esc>\<Esc>", "xt")
  cunmap <F6>

  call assert_equal('', getcmdline())
endfunc

func Test_getcmdwintype()
  call feedkeys("q/:let a = getcmdwintype()\<CR>:q\<CR>", 'x!')
  call assert_equal('/', a)

  call feedkeys("q?:let a = getcmdwintype()\<CR>:q\<CR>", 'x!')
  call assert_equal('?', a)

  call feedkeys("q::let a = getcmdwintype()\<CR>:q\<CR>", 'x!')
  call assert_equal(':', a)

  call feedkeys(":\<C-F>:let a = getcmdwintype()\<CR>:q\<CR>", 'x!')
  call assert_equal(':', a)

  call assert_equal('', getcmdwintype())
endfunc

func Test_getcmdwin_autocmd()
  let s:seq = []
  augroup CmdWin
  au WinEnter * call add(s:seq, 'WinEnter ' .. win_getid())
  au WinLeave * call add(s:seq, 'WinLeave ' .. win_getid())
  au BufEnter * call add(s:seq, 'BufEnter ' .. bufnr())
  au BufLeave * call add(s:seq, 'BufLeave ' .. bufnr())
  au CmdWinEnter * call add(s:seq, 'CmdWinEnter ' .. win_getid())
  au CmdWinLeave * call add(s:seq, 'CmdWinLeave ' .. win_getid())

  let org_winid = win_getid()
  let org_bufnr = bufnr()
  call feedkeys("q::let a = getcmdwintype()\<CR>:let s:cmd_winid = win_getid()\<CR>:let s:cmd_bufnr = bufnr()\<CR>:q\<CR>", 'x!')
  call assert_equal(':', a)
  call assert_equal([
	\ 'WinLeave ' .. org_winid,
	\ 'WinEnter ' .. s:cmd_winid,
	\ 'BufLeave ' .. org_bufnr,
	\ 'BufEnter ' .. s:cmd_bufnr,
	\ 'CmdWinEnter ' .. s:cmd_winid,
	\ 'CmdWinLeave ' .. s:cmd_winid,
	\ 'BufLeave ' .. s:cmd_bufnr,
	\ 'WinLeave ' .. s:cmd_winid,
	\ 'WinEnter ' .. org_winid,
	\ 'BufEnter ' .. org_bufnr,
	\ ], s:seq)

  au!
  augroup END
endfunc

func Test_verbosefile()
  set verbosefile=Xlog
  echomsg 'foo'
  echomsg 'bar'
  set verbosefile=
  let log = readfile('Xlog')
  call assert_match("foo\nbar", join(log, "\n"))
  call delete('Xlog')
endfunc

func Test_verbose_option()
  " See test/functional/legacy/cmdline_spec.lua
  CheckScreendump

  let lines =<< trim [SCRIPT]
    command DoSomething echo 'hello' |set ts=4 |let v = '123' |echo v
    call feedkeys("\r", 't') " for the hit-enter prompt
    set verbose=20
  [SCRIPT]
  call writefile(lines, 'XTest_verbose')

  let buf = RunVimInTerminal('-S XTest_verbose', {'rows': 12})
  call term_wait(buf, 100)
  call term_sendkeys(buf, ":DoSomething\<CR>")
  call VerifyScreenDump(buf, 'Test_verbose_option_1', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_verbose')
endfunc

func Test_setcmdpos()
  func InsertTextAtPos(text, pos)
    call assert_equal(0, setcmdpos(a:pos))
    return a:text
  endfunc

  " setcmdpos() with position in the middle of the command line.
  call feedkeys(":\"12\<C-R>=InsertTextAtPos('a', 3)\<CR>b\<CR>", 'xt')
  call assert_equal('"1ab2', @:)

  call feedkeys(":\"12\<C-R>\<C-R>=InsertTextAtPos('a', 3)\<CR>b\<CR>", 'xt')
  call assert_equal('"1b2a', @:)

  " setcmdpos() with position beyond the end of the command line.
  call feedkeys(":\"12\<C-B>\<C-R>=InsertTextAtPos('a', 10)\<CR>b\<CR>", 'xt')
  call assert_equal('"12ab', @:)

  " setcmdpos() returns 1 when not editing the command line.
  call assert_equal(1, 3->setcmdpos())
endfunc

func Test_cmdline_overstrike()
  " Nvim: only utf8 is supported.
  let encodings = ['utf8']
  let encoding_save = &encoding

  for e in encodings
    exe 'set encoding=' . e

    " Test overstrike in the middle of the command line.
    call feedkeys(":\"01234\<home>\<right>\<right>ab\<right>\<insert>cd\<enter>", 'xt')
    call assert_equal('"0ab1cd4', @:, e)

    " Test overstrike going beyond end of command line.
    call feedkeys(":\"01234\<home>\<right>\<right>ab\<right>\<insert>cdefgh\<enter>", 'xt')
    call assert_equal('"0ab1cdefgh', @:, e)

    " Test toggling insert/overstrike a few times.
    call feedkeys(":\"01234\<home>\<right>ab\<right>\<insert>cd\<right>\<insert>ef\<enter>", 'xt')
    call assert_equal('"ab0cd3ef4', @:, e)
  endfor

  " Test overstrike with multi-byte characters.
  call feedkeys(":\"テキストエディタ\<home>\<right>\<right>ab\<right>\<insert>cd\<enter>", 'xt')
  call assert_equal('"テabキcdエディタ', @:, e)

  let &encoding = encoding_save
endfunc

func Test_cmdwin_bug()
  let winid = win_getid()
  sp
  try
    call feedkeys("q::call win_gotoid(" .. winid .. ")\<CR>:q\<CR>", 'x!')
  catch /^Vim\%((\a\+)\)\=:E11/
  endtry
  bw!
endfunc

func Test_cmdwin_restore()
  CheckScreendump

  let lines =<< trim [SCRIPT]
    call setline(1, range(30))
    2split
  [SCRIPT]
  call writefile(lines, 'XTest_restore')

  let buf = RunVimInTerminal('-S XTest_restore', {'rows': 12})
  call term_wait(buf, 100)
  call term_sendkeys(buf, "q:")
  call VerifyScreenDump(buf, 'Test_cmdwin_restore_1', {})

  " normal restore
  call term_sendkeys(buf, ":q\<CR>")
  call VerifyScreenDump(buf, 'Test_cmdwin_restore_2', {})

  " restore after setting 'lines' with one window
  call term_sendkeys(buf, ":close\<CR>")
  call term_sendkeys(buf, "q:")
  call term_sendkeys(buf, ":set lines=18\<CR>")
  call term_sendkeys(buf, ":q\<CR>")
  call VerifyScreenDump(buf, 'Test_cmdwin_restore_3', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_restore')
endfunc

func Test_buffers_lastused()
  " check that buffers are sorted by time when wildmode has lastused
  edit bufc " oldest

  sleep 1200m
  enew
  edit bufa " middle

  sleep 1200m
  enew
  edit bufb " newest

  enew

  call assert_equal(['bufc', 'bufa', 'bufb'],
	\ getcompletion('', 'buffer'))

  let save_wildmode = &wildmode
  set wildmode=full:lastused

  let cap = "\<c-r>=execute('let X=getcmdline()')\<cr>"
  call feedkeys(":b \<tab>" .. cap .. "\<esc>", 'xt')
  call assert_equal('b bufb', X)
  call feedkeys(":b \<tab>\<tab>" .. cap .. "\<esc>", 'xt')
  call assert_equal('b bufa', X)
  call feedkeys(":b \<tab>\<tab>\<tab>" .. cap .. "\<esc>", 'xt')
  call assert_equal('b bufc', X)
  enew

  sleep 1200m
  edit other
  call feedkeys(":b \<tab>" .. cap .. "\<esc>", 'xt')
  call assert_equal('b bufb', X)
  call feedkeys(":b \<tab>\<tab>" .. cap .. "\<esc>", 'xt')
  call assert_equal('b bufa', X)
  call feedkeys(":b \<tab>\<tab>\<tab>" .. cap .. "\<esc>", 'xt')
  call assert_equal('b bufc', X)
  enew

  let &wildmode = save_wildmode

  bwipeout bufa
  bwipeout bufb
  bwipeout bufc
endfunc

func Test_cmdwin_feedkeys()
  " This should not generate E488
  call feedkeys("q:\<CR>", 'x')
  " Using feedkeys with q: only should automatically close the cmd window
  call feedkeys('q:', 'xt')
  call assert_equal(1, winnr('$'))
  call assert_equal('', getcmdwintype())
endfunc

" Tests for the issues fixed in 7.4.441.
" When 'cedit' is set to Ctrl-C, opening the command window hangs Vim
func Test_cmdwin_cedit()
  exe "set cedit=\<C-c>"
  normal! :
  call assert_equal(1, winnr('$'))

  let g:cmd_wintype = ''
  func CmdWinType()
      let g:cmd_wintype = getcmdwintype()
      let g:wintype = win_gettype()
      return ''
  endfunc

  call feedkeys("\<C-c>a\<C-R>=CmdWinType()\<CR>\<CR>")
  echo input('')
  call assert_equal('@', g:cmd_wintype)
  call assert_equal('command', g:wintype)

  set cedit&vim
  delfunc CmdWinType
endfunc

" Test for CmdwinEnter autocmd
func Test_cmdwin_autocmd()
  CheckFeature cmdwin

  augroup CmdWin
    au!
    autocmd BufLeave * if &buftype == '' | update | endif
    autocmd CmdwinEnter * startinsert
  augroup END

  call assert_fails('call feedkeys("q:xyz\<CR>", "xt")', 'E492:')
  call assert_equal('xyz', @:)

  augroup CmdWin
    au!
  augroup END
  augroup! CmdWin
endfunc

func Test_cmdlineclear_tabenter()
  " See test/functional/legacy/cmdline_spec.lua
  CheckScreendump

  let lines =<< trim [SCRIPT]
    call setline(1, range(30))
  [SCRIPT]

  call writefile(lines, 'XtestCmdlineClearTabenter')
  let buf = RunVimInTerminal('-S XtestCmdlineClearTabenter', #{rows: 10})
  call term_wait(buf, 50)
  " in one tab make the command line higher with CTRL-W -
  call term_sendkeys(buf, ":tabnew\<cr>\<C-w>-\<C-w>-gtgt")
  call VerifyScreenDump(buf, 'Test_cmdlineclear_tabenter', {})

  call StopVimInTerminal(buf)
  call delete('XtestCmdlineClearTabenter')
endfunc

" Test for expanding special keywords in cmdline
func Test_cmdline_expand_special()
  new
  %bwipe!
  call assert_fails('e #', 'E194:')
  call assert_fails('e <afile>', 'E495:')
  call assert_fails('e <abuf>', 'E496:')
  call assert_fails('e <amatch>', 'E497:')
  call writefile([], 'Xfile.cpp')
  call writefile([], 'Xfile.java')
  new Xfile.cpp
  call feedkeys(":e %:r\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xfile.cpp Xfile.java', @:)
  close
  call delete('Xfile.cpp')
  call delete('Xfile.java')
endfunc

func Test_cmdwin_jump_to_win()
  call assert_fails('call feedkeys("q:\<C-W>\<C-W>\<CR>", "xt")', 'E11:')
  new
  set modified
  call assert_fails('call feedkeys("q/:qall\<CR>", "xt")', 'E162:')
  close!
  call feedkeys("q/:close\<CR>", "xt")
  call assert_equal(1, winnr('$'))
  call feedkeys("q/:exit\<CR>", "xt")
  call assert_equal(1, winnr('$'))

  " opening command window twice should fail
  call assert_beeps('call feedkeys("q:q:\<CR>\<CR>", "xt")')
  call assert_equal(1, winnr('$'))
endfunc

func Test_cmdwin_tabpage()
  tabedit
  " v8.2.1919 isn't ported yet, so E492 is thrown after E11 here.
  " v8.2.1183 also isn't ported yet, so we also can't assert E11 directly.
  " For now, assert E11 and E492 separately. When v8.2.1183 is ported, the
  " assert for E492 will fail and this workaround should be removed.
  " call assert_fails("silent norm q/g	:I\<Esc>", 'E11:')
  call assert_fails("silent norm q/g	", 'E11:')
  call assert_fails("silent norm q/g	:I\<Esc>", 'E492:')
  tabclose!
endfunc

func Test_cmdwin_interrupted()
  CheckScreendump

  " aborting the :smile output caused the cmdline window to use the current
  " buffer.
  let lines =<< trim [SCRIPT]
    au WinNew * smile
  [SCRIPT]
  call writefile(lines, 'XTest_cmdwin')

  let buf = RunVimInTerminal('-S XTest_cmdwin', {'rows': 18})
  " open cmdwin
  call term_sendkeys(buf, "q:")
  call WaitForAssert({-> assert_match('-- More --', term_getline(buf, 18))})
  " quit more prompt for :smile command
  call term_sendkeys(buf, "q")
  call WaitForAssert({-> assert_match('^$', term_getline(buf, 18))})
  " execute a simple command
  call term_sendkeys(buf, "aecho 'done'\<CR>")
  call VerifyScreenDump(buf, 'Test_cmdwin_interrupted', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('XTest_cmdwin')
endfunc

" Test for backtick expression in the command line
func Test_cmd_backtick()
  CheckNotMSWindows  " FIXME: see #19297
  %argd
  argadd `=['a', 'b', 'c']`
  call assert_equal(['a', 'b', 'c'], argv())
  %argd

  argadd `echo abc def`
  call assert_equal(['abc def'], argv())
  %argd
endfunc

" Test for the :! command
func Test_cmd_bang()
  CheckUnix

  let lines =<< trim [SCRIPT]
    " Test for no previous command
    call assert_fails('!!', 'E34:')
    set nomore
    " Test for cmdline expansion with :!
    call setline(1, 'foo!')
    silent !echo <cWORD> > Xfile.out
    call assert_equal(['foo!'], readfile('Xfile.out'))
    " Test for using previous command
    silent !echo \! !
    call assert_equal(['! echo foo!'], readfile('Xfile.out'))
    call writefile(v:errors, 'Xresult')
    call delete('Xfile.out')
    qall!
  [SCRIPT]
  call writefile(lines, 'Xscript')
  if RunVim([], [], '--clean -S Xscript')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xscript')
  call delete('Xresult')
endfunc

" Test error: "E135: *Filter* Autocommands must not change current buffer"
func Test_cmd_bang_E135()
  new
  call setline(1, ['a', 'b', 'c', 'd'])
  augroup test_cmd_filter_E135
    au!
    autocmd FilterReadPost * help
  augroup END
  call assert_fails('2,3!echo "x"', 'E135:')

  augroup test_cmd_filter_E135
    au!
  augroup END
  %bwipe!
endfunc

" Test for using ~ for home directory in cmdline completion matches
func Test_cmdline_expand_home()
  call mkdir('Xdir')
  call writefile([], 'Xdir/Xfile1')
  call writefile([], 'Xdir/Xfile2')
  cd Xdir
  let save_HOME = $HOME
  let $HOME = getcwd()
  call feedkeys(":e ~/\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ~/Xfile1 ~/Xfile2', @:)
  let $HOME = save_HOME
  cd ..
  call delete('Xdir', 'rf')
endfunc

" Test for using CTRL-\ CTRL-G in the command line to go back to normal mode
" or insert mode (when 'insertmode' is set)
func Test_cmdline_ctrl_g()
  new
  call setline(1, 'abc')
  call cursor(1, 3)
  " If command line is entered from insert mode, using C-\ C-G should back to
  " insert mode
  call feedkeys("i\<C-O>:\<C-\>\<C-G>xy", 'xt')
  call assert_equal('abxyc', getline(1))
  call assert_equal(4, col('.'))

  " If command line is entered in 'insertmode', using C-\ C-G should back to
  " 'insertmode'
  " call feedkeys(":set im\<cr>\<C-L>:\<C-\>\<C-G>12\<C-L>:set noim\<cr>", 'xt')
  " call assert_equal('ab12xyc', getline(1))
  close!
endfunc

" Test for 'wildmode'
func Test_wildmode()
  func T(a, c, p)
    return "oneA\noneB\noneC"
  endfunc
  command -nargs=1 -complete=custom,T MyCmd

  func SaveScreenLine()
    let g:Sline = Screenline(&lines - 1)
    return ''
  endfunc
  cnoremap <expr> <F2> SaveScreenLine()

  set nowildmenu
  set wildmode=full,list
  let g:Sline = ''
  call feedkeys(":MyCmd \t\t\<F2>\<C-B>\"\<CR>", 'xt')
  call assert_equal('oneA  oneB  oneC', g:Sline)
  call assert_equal('"MyCmd oneA', @:)

  set wildmode=longest,full
  call feedkeys(":MyCmd o\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd one', @:)
  call feedkeys(":MyCmd o\t\t\t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneC', @:)

  set wildmode=longest
  call feedkeys(":MyCmd one\t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd one', @:)

  set wildmode=list:longest
  let g:Sline = ''
  call feedkeys(":MyCmd \t\<F2>\<C-B>\"\<CR>", 'xt')
  call assert_equal('oneA  oneB  oneC', g:Sline)
  call assert_equal('"MyCmd one', @:)

  set wildmode=""
  call feedkeys(":MyCmd \t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneA', @:)

  " Test for wildmode=longest with 'fileignorecase' set
  set wildmode=longest
  set fileignorecase
  argadd AA AAA AAAA
  call feedkeys(":buffer \t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"buffer AA', @:)
  set fileignorecase&

  " Test for listing files with wildmode=list
  set wildmode=list
  let g:Sline = ''
  call feedkeys(":b A\t\t\<F2>\<C-B>\"\<CR>", 'xt')
  call assert_equal('AA    AAA   AAAA', g:Sline)
  call assert_equal('"b A', @:)

  %argdelete
  delcommand MyCmd
  delfunc T
  delfunc SaveScreenLine
  cunmap <F2>
  set wildmode&
  %bwipe!
endfunc

" Test for interrupting the command-line completion
func Test_interrupt_compl()
  func F(lead, cmdl, p)
    if a:lead =~ 'tw'
      call interrupt()
      return
    endif
    return "one\ntwo\nthree"
  endfunc
  command -nargs=1 -complete=custom,F Tcmd

  set nowildmenu
  set wildmode=full
  let interrupted = 0
  try
    call feedkeys(":Tcmd tw\<Tab>\<C-B>\"\<CR>", 'xt')
  catch /^Vim:Interrupt$/
    let interrupted = 1
  endtry
  call assert_equal(1, interrupted)

  delcommand Tcmd
  delfunc F
  set wildmode&
endfunc

" Test for moving the cursor on the : command line
func Test_cmdline_edit()
  let str = ":one two\<C-U>"
  let str ..= "one two\<C-W>\<C-W>"
  let str ..= "four\<BS>\<C-H>\<Del>\<kDel>"
  let str ..= "\<Left>five\<Right>"
  let str ..= "\<Home>two "
  let str ..= "\<C-Left>one "
  let str ..= "\<C-Right> three"
  let str ..= "\<End>\<S-Left>four "
  let str ..= "\<S-Right> six"
  let str ..= "\<C-B>\"\<C-E> seven\<CR>"
  call feedkeys(str, 'xt')
  call assert_equal("\"one two three four five six seven", @:)
endfunc

" Test for moving the cursor on the / command line in 'rightleft' mode
func Test_cmdline_edit_rightleft()
  CheckFeature rightleft
  set rightleft
  set rightleftcmd=search
  let str = "/one two\<C-U>"
  let str ..= "one two\<C-W>\<C-W>"
  let str ..= "four\<BS>\<C-H>\<Del>\<kDel>"
  let str ..= "\<Right>five\<Left>"
  let str ..= "\<Home>two "
  let str ..= "\<C-Right>one "
  let str ..= "\<C-Left> three"
  let str ..= "\<End>\<S-Right>four "
  let str ..= "\<S-Left> six"
  let str ..= "\<C-B>\"\<C-E> seven\<CR>"
  call assert_fails("call feedkeys(str, 'xt')", 'E486:')
  call assert_equal("\"one two three four five six seven", @/)
  set rightleftcmd&
  set rightleft&
endfunc

" Test for using <C-\>e in the command line to evaluate an expression
func Test_cmdline_expr()
  " Evaluate an expression from the beginning of a command line
  call feedkeys(":abc\<C-B>\<C-\>e\"\\\"hello\"\<CR>\<CR>", 'xt')
  call assert_equal('"hello', @:)

  " Use an invalid expression for <C-\>e
  call assert_beeps('call feedkeys(":\<C-\>einvalid\<CR>", "tx")')

  " Insert literal <CTRL-\> in the command line
  call feedkeys(":\"e \<C-\>\<C-Y>\<CR>", 'xt')
  call assert_equal("\"e \<C-\>\<C-Y>", @:)
endfunc

" Test for 'imcmdline' and 'imsearch'
" This test doesn't actually test the input method functionality.
func Test_cmdline_inputmethod()
  new
  call setline(1, ['', 'abc', ''])
  set imcmdline

  call feedkeys(":\"abc\<CR>", 'xt')
  call assert_equal("\"abc", @:)
  call feedkeys(":\"\<C-^>abc\<C-^>\<CR>", 'xt')
  call assert_equal("\"abc", @:)
  call feedkeys("/abc\<CR>", 'xt')
  call assert_equal([2, 1], [line('.'), col('.')])
  call feedkeys("/\<C-^>abc\<C-^>\<CR>", 'xt')
  call assert_equal([2, 1], [line('.'), col('.')])

  " set imsearch=2
  call cursor(1, 1)
  call feedkeys("/abc\<CR>", 'xt')
  call assert_equal([2, 1], [line('.'), col('.')])
  call cursor(1, 1)
  call feedkeys("/\<C-^>abc\<C-^>\<CR>", 'xt')
  call assert_equal([2, 1], [line('.'), col('.')])
  set imdisable
  call feedkeys("/\<C-^>abc\<C-^>\<CR>", 'xt')
  call assert_equal([2, 1], [line('.'), col('.')])
  set imdisable&
  set imsearch&

  set imcmdline&
  %bwipe!
endfunc

" Test for recursively getting multiple command line inputs
func Test_cmdwin_multi_input()
  call feedkeys(":\<C-R>=input('P: ')\<CR>\"cyan\<CR>\<CR>", 'xt')
  call assert_equal('"cyan', @:)
endfunc

" Test for using CTRL-_ in the command line with 'allowrevins'
func Test_cmdline_revins()
  CheckNotMSWindows
  CheckFeature rightleft
  call feedkeys(":\"abc\<c-_>\<cr>", 'xt')
  call assert_equal("\"abc\<c-_>", @:)
  set allowrevins
  call feedkeys(":\"abc\<c-_>xyz\<c-_>\<CR>", 'xt')
  call assert_equal('"abcñèæ', @:)
  set allowrevins&
endfunc

" Test for typing UTF-8 composing characters in the command line
func Test_cmdline_composing_chars()
  call feedkeys(":\"\<C-V>u3046\<C-V>u3099\<CR>", 'xt')
  call assert_equal('"ゔ', @:)
endfunc

" Test for normal mode commands not supported in the cmd window
func Test_cmdwin_blocked_commands()
  call assert_fails('call feedkeys("q:\<C-T>\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-]>\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-^>\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:Q\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:Z\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<F1>\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>s\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>v\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>^\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>n\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>z\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>o\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>w\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>j\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>k\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>h\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>l\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>T\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>x\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>r\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>R\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>K\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>}\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>]\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>f\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>d\<CR>", "xt")', 'E11:')
  call assert_fails('call feedkeys("q:\<C-W>g\<CR>", "xt")', 'E11:')
endfunc

" Close the Cmd-line window in insert mode using CTRL-C
func Test_cmdwin_insert_mode_close()
  %bw!
  let s = ''
  exe "normal q:a\<C-C>let s='Hello'\<CR>"
  call assert_equal('Hello', s)
  call assert_equal(1, winnr('$'))
endfunc

" test that ";" works to find a match at the start of the first line
func Test_zero_line_search()
  new
  call setline(1, ["1, pattern", "2, ", "3, pattern"])
  call cursor(1,1)
  0;/pattern/d
  call assert_equal(["2, ", "3, pattern"], getline(1,'$'))
  q!
endfunc

func Test_read_shellcmd()
  CheckUnix
  if executable('ls')
    " There should be ls in the $PATH
    call feedkeys(":r! l\<c-a>\<c-b>\"\<cr>", 'tx')
    call assert_match('^"r! .*\<ls\>', @:)
  endif

  if executable('rm')
    call feedkeys(":r! ++enc=utf-8 r\<c-a>\<c-b>\"\<cr>", 'tx')
    call assert_notmatch('^"r!.*\<runtest.vim\>', @:)
    call assert_match('^"r!.*\<rm\>', @:)

    call feedkeys(":r ++enc=utf-8 !rm\<c-a>\<c-b>\"\<cr>", 'tx')
    call assert_notmatch('^"r.*\<runtest.vim\>', @:)
    call assert_match('^"r ++enc\S\+ !.*\<rm\>', @:)
  endif
endfunc

" Test for going up and down the directory tree using 'wildmenu'
func Test_wildmenu_dirstack()
  CheckUnix
  %bw!
  call mkdir('Xdir1/dir2/dir3', 'p')
  call writefile([], 'Xdir1/file1_1.txt')
  call writefile([], 'Xdir1/file1_2.txt')
  call writefile([], 'Xdir1/dir2/file2_1.txt')
  call writefile([], 'Xdir1/dir2/file2_2.txt')
  call writefile([], 'Xdir1/dir2/dir3/file3_1.txt')
  call writefile([], 'Xdir1/dir2/dir3/file3_2.txt')
  cd Xdir1/dir2/dir3
  set wildmenu

  call feedkeys(":e \<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e file3_1.txt', @:)
  call feedkeys(":e \<Tab>\<Up>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../dir3/', @:)
  call feedkeys(":e \<Tab>\<Up>\<Up>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../../dir2/', @:)
  call feedkeys(":e \<Tab>\<Up>\<Up>\<Down>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../../dir2/dir3/', @:)
  call feedkeys(":e \<Tab>\<Up>\<Up>\<Down>\<Down>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../../dir2/dir3/file3_1.txt', @:)

  cd -
  call delete('Xdir1', 'rf')
  set wildmenu&
endfunc

" Test for recalling newer or older cmdline from history with <Up>, <Down>,
" <S-Up>, <S-Down>, <PageUp>, <PageDown>, <C-p>, or <C-n>.
func Test_recalling_cmdline()
  CheckFeature cmdline_hist

  let g:cmdlines = []
  cnoremap <Plug>(save-cmdline) <Cmd>let g:cmdlines += [getcmdline()]<CR>

  let histories = [
  \  {'name': 'cmd',    'enter': ':',                    'exit': "\<Esc>"},
  \  {'name': 'search', 'enter': '/',                    'exit': "\<Esc>"},
  \  {'name': 'expr',   'enter': ":\<C-r>=",             'exit': "\<Esc>\<Esc>"},
  \  {'name': 'input',  'enter': ":call input('')\<CR>", 'exit': "\<CR>"},
  "\ TODO: {'name': 'debug', ...}
  \]
  let keypairs = [
  \  {'older': "\<Up>",     'newer': "\<Down>",     'prefixmatch': v:true},
  \  {'older': "\<S-Up>",   'newer': "\<S-Down>",   'prefixmatch': v:false},
  \  {'older': "\<PageUp>", 'newer': "\<PageDown>", 'prefixmatch': v:false},
  \  {'older': "\<C-p>",    'newer': "\<C-n>",      'prefixmatch': v:false},
  \]
  let prefix = 'vi'
  for h in histories
    call histadd(h.name, 'vim')
    call histadd(h.name, 'virtue')
    call histadd(h.name, 'Virgo')
    call histadd(h.name, 'vogue')
    call histadd(h.name, 'emacs')
    for k in keypairs
      let g:cmdlines = []
      let keyseqs = h.enter
      \          .. prefix
      \          .. repeat(k.older .. "\<Plug>(save-cmdline)", 2)
      \          .. repeat(k.newer .. "\<Plug>(save-cmdline)", 2)
      \          .. h.exit
      call feedkeys(keyseqs, 'xt')
      call histdel(h.name, -1) " delete the history added by feedkeys above
      let expect = k.prefixmatch
      \          ? ['virtue', 'vim',   'virtue', prefix]
      \          : ['emacs',  'vogue', 'emacs',  prefix]
      call assert_equal(expect, g:cmdlines)
    endfor
  endfor

  unlet g:cmdlines
  cunmap <Plug>(save-cmdline)
endfunc

" Test for using a popup menu for the command line completion matches
" (wildoptions=pum)
func Test_wildmenu_pum()
  CheckRunVimInTerminal

  let commands =<< trim [CODE]
    set wildmenu
    set wildoptions=pum
    set shm+=I
    set noruler
    set noshowcmd
  [CODE]
  call writefile(commands, 'Xtest')

  let buf = RunVimInTerminal('-S Xtest', #{rows: 10})

  call term_sendkeys(buf, ":sign \<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_01', {})

  call term_sendkeys(buf, "\<Down>\<Down>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_02', {})

  call term_sendkeys(buf, "\<C-N>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_03', {})

  call term_sendkeys(buf, "\<C-P>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_04', {})

  call term_sendkeys(buf, "\<Up>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_05', {})

  " pressing <C-E> should end completion and go back to the original match
  call term_sendkeys(buf, "\<C-E>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_06', {})

  " pressing <C-Y> should select the current match and end completion
  call term_sendkeys(buf, "\<Tab>\<C-P>\<C-P>\<C-Y>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_07', {})

  " With 'wildmode' set to 'longest,full', completing a match should display
  " the longest match, the wildmenu should not be displayed.
  call term_sendkeys(buf, ":\<C-U>set wildmode=longest,full\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, ":sign u\<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_08', {})

  " pressing <Tab> should display the wildmenu
  call term_sendkeys(buf, "\<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_09', {})

  " pressing <Tab> second time should select the next entry in the menu
  call term_sendkeys(buf, "\<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_10', {})

  call term_sendkeys(buf, ":\<C-U>set wildmode=full\<CR>")
  " " showing popup menu in different columns in the cmdline
  call term_sendkeys(buf, ":sign define \<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_11', {})

  call term_sendkeys(buf, " \<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_12', {})

  call term_sendkeys(buf, " \<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_13', {})

  " Directory name completion
  call mkdir('Xdir/XdirA/XdirB', 'p')
  call writefile([], 'Xdir/XfileA')
  call writefile([], 'Xdir/XdirA/XfileB')
  call writefile([], 'Xdir/XdirA/XdirB/XfileC')

  call term_sendkeys(buf, "\<C-U>e Xdi\<Tab>\<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_14', {})

  " Pressing <Right> on a directory name should go into that directory
  call term_sendkeys(buf, "\<Right>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_15', {})

  " Pressing <Left> on a directory name should go to the parent directory
  call term_sendkeys(buf, "\<Left>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_16', {})

  " Pressing <C-A> when the popup menu is displayed should list all the
  " matches and remove the popup menu
  call term_sendkeys(buf, "\<C-U>sign \<Tab>\<C-A>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_17', {})

  " Pressing <C-D> when the popup menu is displayed should remove the popup
  " menu
  call term_sendkeys(buf, "\<C-U>sign \<Tab>\<C-D>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_18', {})

  " Pressing <S-Tab> should open the popup menu with the last entry selected
  call term_sendkeys(buf, "\<C-U>\<CR>:sign \<S-Tab>\<C-P>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_19', {})

  " Pressing <Esc> should close the popup menu and cancel the cmd line
  call term_sendkeys(buf, "\<C-U>\<CR>:sign \<Tab>\<Esc>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_20', {})

  " Typing a character when the popup is open, should close the popup
  call term_sendkeys(buf, ":sign \<Tab>x")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_21', {})

  " When the popup is open, entering the cmdline window should close the popup
  call term_sendkeys(buf, "\<C-U>sign \<Tab>\<C-F>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_22', {})
  call term_sendkeys(buf, ":q\<CR>")

  " After the last popup menu item, <C-N> should show the original string
  call term_sendkeys(buf, ":sign u\<Tab>\<C-N>\<C-N>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_23', {})

  " Use the popup menu for the command name
  call term_sendkeys(buf, "\<C-U>bu\<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_24', {})

  " Pressing the left arrow should remove the popup menu
  call term_sendkeys(buf, "\<Left>\<Left>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_25', {})

  " Pressing <BS> should remove the popup menu and erase the last character
  call term_sendkeys(buf, "\<C-E>\<C-U>sign \<Tab>\<BS>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_26', {})

  " Pressing <C-W> should remove the popup menu and erase the previous word
  call term_sendkeys(buf, "\<C-E>\<C-U>sign \<Tab>\<C-W>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_27', {})

  " Pressing <C-U> should remove the popup menu and erase the entire line
  call term_sendkeys(buf, "\<C-E>\<C-U>sign \<Tab>\<C-U>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_28', {})

  " Using <C-E> to cancel the popup menu and then pressing <Up> should recall
  " the cmdline from history
  call term_sendkeys(buf, "sign xyz\<Esc>:sign \<Tab>\<C-E>\<Up>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_29', {})

  " Check "list" still works
  call term_sendkeys(buf, "\<C-U>set wildmode=longest,list\<CR>")
  call term_sendkeys(buf, ":cn\<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_30', {})
  call term_sendkeys(buf, "s")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_31', {})

  " Tests a directory name contained full-width characters.
  call mkdir('Xdir/あいう', 'p')
  call writefile([], 'Xdir/あいう/abc')
  call writefile([], 'Xdir/あいう/xyz')
  call writefile([], 'Xdir/あいう/123')

  call term_sendkeys(buf, "\<C-U>set wildmode&\<CR>")
  call term_sendkeys(buf, ":\<C-U>e Xdir/あいう/\<Tab>")
  call TermWait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_32', {})

  call term_sendkeys(buf, "\<C-U>\<CR>")
  call StopVimInTerminal(buf)
  call delete('Xtest')
  call delete('Xdir', 'rf')
endfunc

func Test_wildmenu_pum_clear_entries()
  CheckRunVimInTerminal

  " This was using freed memory.  Run in a terminal to get the pum to update.
  let lines =<< trim END
    set wildoptions=pum
    set wildchar=<C-E>
  END
  call writefile(lines, 'XwildmenuTest', 'D')
  let buf = RunVimInTerminal('-S XwildmenuTest', #{rows: 10})

  call term_sendkeys(buf, ":\<C-E>\<C-E>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_clear_entries_1', {})

  set wildoptions& wildchar&
endfunc

" this was going over the end of IObuff
func Test_report_error_with_composing()
  let caught = 'no'
  try
    exe repeat('0', 987) .. "0\xdd\x80\xdd\x80\xdd\x80\xdd\x80"
  catch /E492:/
    let caught = 'yes'
  endtry
  call assert_equal('yes', caught)
endfunc

" Test for expanding 2-letter and 3-letter :substitute command arguments.
" These commands don't accept an argument.
func Test_cmdline_complete_substitute_short()
  for cmd in ['sc', 'sce', 'scg', 'sci', 'scI', 'scn', 'scp', 'scl',
        \ 'sgc', 'sge', 'sg', 'sgi', 'sgI', 'sgn', 'sgp', 'sgl', 'sgr',
        \ 'sic', 'sie', 'si', 'siI', 'sin', 'sip', 'sir',
        \ 'sIc', 'sIe', 'sIg', 'sIi', 'sI', 'sIn', 'sIp', 'sIl', 'sIr',
        \ 'src', 'srg', 'sri', 'srI', 'srn', 'srp', 'srl', 'sr']
    call feedkeys(':' .. cmd .. " \<Tab>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"' .. cmd .. " \<Tab>", @:)
  endfor
endfunc

func Check_completion()
  call assert_equal('let a', getcmdline())
  call assert_equal(6, getcmdpos())
  call assert_equal(7, getcmdscreenpos())
  call assert_equal('var', getcmdcompltype())
  return ''
endfunc

func Test_screenpos_and_completion()
  call feedkeys(":let a\<C-R>=Check_completion()\<CR>\<Esc>", "xt")
endfunc

func Test_recursive_register()
  let @= = ''
  silent! ?e/
  let caught = 'no'
  try
    normal // 
  catch /E169:/
    let caught = 'yes'
  endtry
  call assert_equal('yes', caught)
endfunc

func Test_long_error_message()
  " the error should be truncated, not overrun IObuff
  silent! norm Q00000000000000     000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000                                                                                                                                                                                                                        
endfunc

func Test_cmdline_redraw_tabline()
  CheckRunVimInTerminal

  let lines =<< trim END
      set showtabline=2
      autocmd CmdlineEnter * set tabline=foo
  END
  call writefile(lines, 'Xcmdline_redraw_tabline')
  let buf = RunVimInTerminal('-S Xcmdline_redraw_tabline', #{rows: 6})
  call term_sendkeys(buf, ':')
  call WaitForAssert({-> assert_match('^foo', term_getline(buf, 1))})

  call StopVimInTerminal(buf)
  call delete('Xcmdline_redraw_tabline')
endfunc

func Test_wildmenu_pum_disable_while_shown()
  set wildoptions=pum
  set wildmenu
  cnoremap <F2> <Cmd>set nowildmenu<CR>
  call feedkeys(":sign \<Tab>\<F2>\<Esc>", 'tx')
  call assert_equal(0, pumvisible())
  cunmap <F2>
  set wildoptions& wildmenu&
endfunc

func Test_setcmdline()
  func SetText(text, pos)
    autocmd CmdlineChanged * let g:cmdtype = expand('<afile>')
    call assert_equal(0, setcmdline(a:text))
    call assert_equal(a:text, getcmdline())
    call assert_equal(len(a:text) + 1, getcmdpos())
    call assert_equal(getcmdtype(), g:cmdtype)
    unlet g:cmdtype
    autocmd! CmdlineChanged

    call assert_equal(0, setcmdline(a:text, a:pos))
    call assert_equal(a:text, getcmdline())
    call assert_equal(a:pos, getcmdpos())

    call assert_fails('call setcmdline("' .. a:text .. '", -1)', 'E487:')
    call assert_fails('call setcmdline({}, 0)', 'E1174:')
    call assert_fails('call setcmdline("' .. a:text .. '", {})', 'E1210:')

    return ''
  endfunc

  call feedkeys(":\<C-R>=SetText('set rtp?', 2)\<CR>\<CR>", 'xt')
  call assert_equal('set rtp?', @:)

  call feedkeys(":let g:str = input('? ')\<CR>", 't')
  call feedkeys("\<C-R>=SetText('foo', 4)\<CR>\<CR>", 'xt')
  call assert_equal('foo', g:str)
  unlet g:str

  delfunc SetText

  " setcmdline() returns 1 when not editing the command line.
  call assert_equal(1, 'foo'->setcmdline())

  " Called in custom function
  func CustomComplete(A, L, P)
    call assert_equal(0, setcmdline("DoCmd "))
    return "January\nFebruary\nMars\n"
  endfunc

  com! -nargs=* -complete=custom,CustomComplete DoCmd :
  call feedkeys(":DoCmd \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"DoCmd January February Mars', @:)
  delcom DoCmd
  delfunc CustomComplete

  " Called in <expr>
  cnoremap <expr>a setcmdline('let foo=')
  call feedkeys(":a\<CR>", 'tx')
  call assert_equal('let foo=0', @:)
  cunmap a
endfunc

" vim: shiftwidth=2 sts=2 expandtab
