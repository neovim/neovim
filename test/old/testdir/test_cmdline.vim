" Tests for editing the command line.

source check.vim
source screendump.vim
source view_util.vim
source shared.vim

func SetUp()
  func SaveLastScreenLine()
    let g:Sline = Screenline(&lines - 1)
    return ''
  endfunc
  cnoremap <expr> <F4> SaveLastScreenLine()
endfunc

func TearDown()
  delfunc SaveLastScreenLine
  cunmap <F4>
endfunc

func Test_complete_tab()
  call writefile(['testfile'], 'Xtestfile')
  call feedkeys(":e Xtest\t\r", "tx")
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

  " Test for displaying the tail of the completion matches
  set wildmode=longest,full
  call mkdir('Xtest')
  call writefile([], 'Xtest/a.c')
  call writefile([], 'Xtest/a.h')
  let g:Sline = ''
  call feedkeys(":e Xtest/\<C-D>\<F4>\<C-B>\"\<CR>", 'xt')
  call assert_equal('a.c  a.h', g:Sline)
  call assert_equal('"e Xtest/', @:)
  if has('win32')
    " Test for 'completeslash'
    set completeslash=backslash
    call feedkeys(":e Xtest\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e Xtest\', @:)
    call feedkeys(":e Xtest/\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e Xtest\a.', @:)
    set completeslash=slash
    call feedkeys(":e Xtest\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e Xtest/', @:)
    call feedkeys(":e Xtest\\\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e Xtest/a.', @:)
    set completeslash&
  endif

  " Test for displaying the tail with wildcards
  let g:Sline = ''
  call feedkeys(":e Xtes?/\<C-D>\<F4>\<C-B>\"\<CR>", 'xt')
  call assert_equal('Xtest/a.c  Xtest/a.h', g:Sline)
  call assert_equal('"e Xtes?/', @:)
  let g:Sline = ''
  call feedkeys(":e Xtes*/\<C-D>\<F4>\<C-B>\"\<CR>", 'xt')
  call assert_equal('Xtest/a.c  Xtest/a.h', g:Sline)
  call assert_equal('"e Xtes*/', @:)
  let g:Sline = ''
  call feedkeys(":e Xtes[/\<C-D>\<F4>\<C-B>\"\<CR>", 'xt')
  call assert_equal(':e Xtes[/', g:Sline)
  call assert_equal('"e Xtes[/', @:)

  call delete('Xtest', 'rf')
  set wildmode&
endfunc

func Test_complete_wildmenu()
  call mkdir('Xwilddir1/Xdir2', 'pR')
  call writefile(['testfile1'], 'Xwilddir1/Xtestfile1')
  call writefile(['testfile2'], 'Xwilddir1/Xtestfile2')
  call writefile(['testfile3'], 'Xwilddir1/Xdir2/Xtestfile3')
  call writefile(['testfile3'], 'Xwilddir1/Xdir2/Xtestfile4')
  set wildmenu

  " Pressing <Tab> completes, and moves to next files when pressing again.
  call feedkeys(":e Xwilddir1/\<Tab>\<Tab>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))
  call feedkeys(":e Xwilddir1/\<Tab>\<Tab>\<Tab>\<CR>", 'tx')
  call assert_equal('testfile2', getline(1))

  " <S-Tab> is like <Tab> but begin with the last match and then go to
  " previous.
  call feedkeys(":e Xwilddir1/Xtest\<S-Tab>\<CR>", 'tx')
  call assert_equal('testfile2', getline(1))
  call feedkeys(":e Xwilddir1/Xtest\<S-Tab>\<S-Tab>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))

  " <Left>/<Right> to move to previous/next file.
  call feedkeys(":e Xwilddir1/\<Tab>\<Right>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))
  call feedkeys(":e Xwilddir1/\<Tab>\<Right>\<Right>\<CR>", 'tx')
  call assert_equal('testfile2', getline(1))
  call feedkeys(":e Xwilddir1/\<Tab>\<Right>\<Right>\<Left>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))

  " <Up>/<Down> to go up/down directories.
  call feedkeys(":e Xwilddir1/\<Tab>\<Down>\<CR>", 'tx')
  call assert_equal('testfile3', getline(1))
  call feedkeys(":e Xwilddir1/\<Tab>\<Down>\<Up>\<Right>\<CR>", 'tx')
  call assert_equal('testfile1', getline(1))

  " this fails in some Unix GUIs, not sure why
  if !has('unix') || !has('gui_running')
    " <C-J>/<C-K> mappings to go up/down directories when 'wildcharm' is
    " different than 'wildchar'.
    set wildcharm=<C-Z>
    cnoremap <C-J> <Down><C-Z>
    cnoremap <C-K> <Up><C-Z>
    call feedkeys(":e Xwilddir1/\<Tab>\<C-J>\<CR>", 'tx')
    call assert_equal('testfile3', getline(1))
    call feedkeys(":e Xwilddir1/\<Tab>\<C-J>\<C-K>\<CR>", 'tx')
    call assert_equal('testfile1', getline(1))
    set wildcharm=0
    cunmap <C-J>
    cunmap <C-K>
  endif

  " Test for canceling the wild menu by adding a character
  redrawstatus
  call feedkeys(":e Xwilddir1/\<Tab>x\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xwilddir1/Xdir2/x', @:)

  " Completion using a relative path
  cd Xwilddir1/Xdir2
  call feedkeys(":e ../\<Tab>\<Right>\<Down>\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"e Xtestfile3 Xtestfile4', @:)
  cd -

  " test for wildmenumode()
  cnoremap <expr> <F2> wildmenumode()
  call feedkeys(":cd Xwilddir\<Tab>\<F2>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"cd Xwilddir1/0', @:)
  call feedkeys(":e Xwilddir1/\<Tab>\<F2>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"e Xwilddir1/Xdir2/1', @:)
  cunmap <F2>

  " Test for canceling the wild menu by pressing <PageDown> or <PageUp>.
  " After this pressing <Left> or <Right> should not change the selection.
  call feedkeys(":sign \<Tab>\<PageDown>\<Left>\<Right>\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign define', @:)
  call histadd('cmd', 'TestWildMenu')
  call feedkeys(":sign \<Tab>\<PageUp>\<Left>\<Right>\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"TestWildMenu', @:)

  " Test for Ctrl-E/Ctrl-Y being able to cancel / accept a match
  call feedkeys(":sign un zz\<Left>\<Left>\<Left>\<Tab>\<C-E> yy\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign un yy zz', @:)

  call feedkeys(":sign un zz\<Left>\<Left>\<Left>\<Tab>\<Tab>\<C-Y> yy\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign unplace yy zz', @:)

  " cleanup
  %bwipe
  set nowildmenu
endfunc

func Test_wildmenu_screendump()
  CheckScreendump

  let lines =<< trim [SCRIPT]
    set wildmenu hlsearch
  [SCRIPT]
  call writefile(lines, 'XTest_wildmenu', 'D')

  " Test simple wildmenu
  let buf = RunVimInTerminal('-S XTest_wildmenu', {'rows': 8})
  call term_sendkeys(buf, ":vim\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_1', {})

  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_2', {})

  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_3', {})

  " Looped back to the original value
  call term_sendkeys(buf, "\<Tab>\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_4', {})

  " Test that the wild menu is cleared properly
  call term_sendkeys(buf, " ")
  call VerifyScreenDump(buf, 'Test_wildmenu_5', {})

  " Test that a different wildchar still works
  call term_sendkeys(buf, "\<Esc>:set wildchar=<Esc>\<CR>")
  call term_sendkeys(buf, ":vim\<Esc>")
  call VerifyScreenDump(buf, 'Test_wildmenu_1', {})

  " Double-<Esc> is a hard-coded method to escape while wildchar=<Esc>. Make
  " sure clean up is properly done in edge case like this.
  call term_sendkeys(buf, "\<Esc>")
  call VerifyScreenDump(buf, 'Test_wildmenu_6', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_wildmenu_with_input_func()
  CheckScreendump

  let buf = RunVimInTerminal('-c "set wildmenu"', {'rows': 8})

  call term_sendkeys(buf, ":call input('Command? ', '', 'command')\<CR>")
  call VerifyScreenDump(buf, 'Test_wildmenu_input_func_1', {})
  call term_sendkeys(buf, "ech\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_input_func_2', {})
  call term_sendkeys(buf, "\<Space>")
  call VerifyScreenDump(buf, 'Test_wildmenu_input_func_3', {})
  call term_sendkeys(buf, "bufn\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_input_func_4', {})
  call term_sendkeys(buf, "\<CR>")

  call term_sendkeys(buf, ":set wildoptions+=pum\<CR>")

  call term_sendkeys(buf, ":call input('Command? ', '', 'command')\<CR>")
  call VerifyScreenDump(buf, 'Test_wildmenu_input_func_5', {})
  call term_sendkeys(buf, "ech\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_input_func_6', {})
  call term_sendkeys(buf, "\<Space>")
  call VerifyScreenDump(buf, 'Test_wildmenu_input_func_7', {})
  call term_sendkeys(buf, "bufn\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_input_func_8', {})
  call term_sendkeys(buf, "\<CR>")

  " clean up
  call StopVimInTerminal(buf)
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
      func EchoOne()
        set laststatus=2 cmdheight=1
        echo 'foo'
        echo 'bar'
        set cmdheight=2
      endfunc
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

  " :resize now also changes 'cmdheight' accordingly
  call term_sendkeys(buf, ":set cmdheight+=1\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_2', {})

  " using more space moves the status line up
  call term_sendkeys(buf, ":set cmdheight+=1\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_3', {})

  " reducing cmdheight moves status line down
  call term_sendkeys(buf, ":set cmdheight-=3\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_4', {})

  " reducing window size and then setting cmdheight
  call term_sendkeys(buf, ":resize -1\<CR>")
  call term_sendkeys(buf, ":set cmdheight=1\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_5', {})

  " setting 'cmdheight' works after outputting two messages
  call term_sendkeys(buf, ":call EchoTwo()\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_6', {})

  " increasing 'cmdheight' doesn't clear the messages that need hit-enter
  call term_sendkeys(buf, ":call EchoOne()\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_7', {})

  " window commands do not reduce 'cmdheight' to value lower than :set by user
  call term_sendkeys(buf, "\<CR>:wincmd _\<CR>")
  call VerifyScreenDump(buf, 'Test_changing_cmdheight_8', {})

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
  call feedkeys(":map <M-Left>\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal("\"map <M-Left>x", getreg(':'))
  unmap ,f
  unmap ,g
  unmap <Left>
  unmap <A-Left>x

  set cpo-=< cpo-=k
  map <Left> left
  call feedkeys(":map <L\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"map <Left>', getreg(':'))
  call feedkeys(":map <M\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal("\"map <M\<Tab>", getreg(':'))
  call feedkeys(":map \<C-V>\<C-V><M\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal("\"map \<C-V><Middle>x", getreg(':'))
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
  set cpo-=k

  call assert_fails('call feedkeys(":map \\\\%(\<Tab>\<Home>\"\<CR>", "xt")', 'E53:')

  unmap <Middle>x
  set cpo&vim
endfunc

func Test_match_completion()
  hi Aardig ctermfg=green
  " call feedkeys(":match \<Tab>\<Home>\"\<CR>", 'xt')
  call feedkeys(":match A\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"match Aardig', @:)
  call feedkeys(":match \<S-Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"match none', @:)
  call feedkeys(":match | chist\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"match | chistory', @:)
endfunc

func Test_highlight_completion()
  hi Aardig ctermfg=green
  " call feedkeys(":hi \<Tab>\<Home>\"\<CR>", 'xt')
  call feedkeys(":hi A\<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"hi Aardig', getreg(':'))
  " call feedkeys(":hi default \<Tab>\<Home>\"\<CR>", 'xt')
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
  call assert_equal(['Aardig', 'Added', 'Anders'], getcompletion('A', 'highlight'))
  hi clear Aardig
  call assert_equal(['Added', 'Anders'], getcompletion('A', 'highlight'))
  hi clear Anders
  call assert_equal(['Added'], getcompletion('A', 'highlight'))
endfunc

func Test_getcompletion()
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
    source $VIMRUNTIME/delmenu.vim
  endif

  let l = getcompletion('v:n', 'var')
  call assert_true(index(l, 'v:null') >= 0)
  let l = getcompletion('v:notexists', 'var')
  call assert_equal([], l)

  args a.c b.c
  let l = getcompletion('', 'arglist')
  call assert_equal(['a.c', 'b.c'], l)
  let l = getcompletion('a.', 'buffer')
  call assert_equal(['a.c'], l)
  %argdelete

  let l = getcompletion('', 'augroup')
  call assert_true(index(l, 'END') >= 0)
  let l = getcompletion('blahblah', 'augroup')
  call assert_equal([], l)

  " let l = getcompletion('', 'behave')
  " call assert_true(index(l, 'mswin') >= 0)
  " let l = getcompletion('not', 'behave')
  " call assert_equal([], l)

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

  let l = getcompletion('', 'filetypecmd')
  call assert_equal(["indent", "off", "on", "plugin"], l)
  let l = getcompletion('not', 'filetypecmd')
  call assert_equal([], l)
  let l = getcompletion('o', 'filetypecmd')
  call assert_equal(['off', 'on'], l)

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
  " Directory name with space character
  call mkdir('Xdir with space')
  call assert_equal(['Xdir with space/'], getcompletion('Xdir\ w', 'shellcmd'))
  call assert_equal(['./Xdir with space/'], getcompletion('./Xdir', 'shellcmd'))
  call delete('Xdir with space', 'd')

  let l = getcompletion('ha', 'filetype')
  call assert_true(index(l, 'hamster') >= 0)
  let l = getcompletion('horse', 'filetype')
  call assert_equal([], l)

  if has('keymap')
    let l = getcompletion('acc', 'keymap')
    call assert_true(index(l, 'accents') >= 0)
    let l = getcompletion('nullkeymap', 'keymap')
    call assert_equal([], l)
  endif

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
    let l = getcompletion('de*', 'sign')
    call assert_equal(['define'], l)
    let l = getcompletion('p?', 'sign')
    call assert_equal(['place'], l)
    let l = getcompletion('j.', 'sign')
    call assert_equal(['jump'], l)
  endif

  " Command line completion tests
  let l = getcompletion('cd ', 'cmdline')
  call assert_true(index(l, 'samples/') >= 0)
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
  let l = getcompletion('autocmd BufEnter * map <bu', 'cmdline')
  call assert_equal(['<buffer>'], l)

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
  let names = ['buffer', 'environment', 'file_in_path', 'dir_in_path', 'mapping', 'tag',
      \ 'tag_listfiles', 'user']
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

  edit a~b
  enew
  call assert_equal(['a~b'], getcompletion('a~', 'buffer'))
  bw a~b

  if has('unix')
    edit Xtest\
    enew
    call assert_equal(['Xtest\'], getcompletion('Xtest\', 'buffer'))
    bw Xtest\
  endif

  call assert_fails("call getcompletion('\\\\@!\\\\@=', 'buffer')", 'E866:')
  call assert_fails('call getcompletion("", "burp")', 'E475:')
  call assert_fails('call getcompletion("abc", [])', 'E1174:')
endfunc

" Test for getcompletion() with "fuzzy" in 'wildoptions'
func Test_getcompletion_wildoptions()
  let save_wildoptions = &wildoptions
  set wildoptions&
  let l = getcompletion('space', 'option')
  call assert_equal([], l)
  let l = getcompletion('ier', 'command')
  call assert_equal([], l)
  set wildoptions=fuzzy
  let l = getcompletion('space', 'option')
  call assert_true(index(l, 'backspace') >= 0)
  let l = getcompletion('ier', 'command')
  call assert_true(index(l, 'compiler') >= 0)
  let &wildoptions = save_wildoptions
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
        \ 'CheckLin':   'CheckLinux',
        \ 'CheckLinux': 'CheckLinux',
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

  call mkdir('Xpathdir/Xpathsubdir', 'pR')
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

  let $PATH = save_path
endfunc

func Test_expand_star_star()
  call mkdir('a/b/c', 'pR')
  call writefile(['asdfasdf'], 'a/b/c/fileXname')
  call feedkeys(":find a/**/fileXname\<Tab>\<CR>", 'xt')
  call assert_equal('find a/b/c/fileXname', @:)
  bwipe!
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

func Test_cmdline_del_utf8()
  let @s = '⒌'
  call feedkeys(":\"\<C-R>s,,\<C-B>\<Right>\<Del>\<CR>", 'tx')
  call assert_equal('",,', @:)

  let @s = 'a̳'
  call feedkeys(":\"\<C-R>s,,\<C-B>\<Right>\<Del>\<CR>", 'tx')
  call assert_equal('",,', @:)

  let @s = 'β̳'
  call feedkeys(":\"\<C-R>s,,\<C-B>\<Right>\<Del>\<CR>", 'tx')
  call assert_equal('",,', @:)

  if has('arabic')
    let @s = 'لا'
    call feedkeys(":\"\<C-R>s,,\<C-B>\<Right>\<Del>\<CR>", 'tx')
    call assert_equal('",,', @:)
  endif
endfunc

func Test_cmdline_keymap_ctrl_hat()
  CheckFeature keymap

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
  call feedkeys(":Foo a b\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_equal('"Foo a blue', @:)
  call feedkeys(":Foo b\\\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_equal('"Foo b\', @:)
  call feedkeys(":Foo b\\x\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_equal('"Foo b\x', @:)
  delcommand Foo

  redraw
  call assert_equal('~', Screenline(&lines - 1))
  command! FooOne :
  command! FooTwo :

  set nowildmenu
  call feedkeys(":Foo\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_equal('"FooOne', @:)
  call assert_equal('~', Screenline(&lines - 1))

  call feedkeys(":Foo\<S-Tab>\<Home>\"\<cr>", 'tx')
  call assert_equal('"FooTwo', @:)
  call assert_equal('~', Screenline(&lines - 1))

  delcommand FooOne
  delcommand FooTwo
  set wildmenu&
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
  elseif has('win32')
    " Just in case: check that the system has an Administrator account.
    let names = system('net user')
    if names =~ 'Administrator'
      " Trying completion of  :e ~A  should complete to Administrator.
      " There could be other names starting with "A" before Administrator.
      call feedkeys(':e ~A' . "\<c-a>\<c-B>\"\<cr>", 'tx')
      call assert_match('^"e \~.*Administrator', @:)
    endif
  else
    throw 'Skipped: does not work on this platform'
  endif
endfunc

func Test_cmdline_complete_shellcmdline()
  CheckExecutable whoami
  command -nargs=1 -complete=shellcmdline MyCmd

  call feedkeys(":MyCmd whoam\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^".*\<whoami\>', @:)
  let l = getcompletion('whoam', 'shellcmdline')
  call assert_match('\<whoami\>', join(l, ' '))

  delcommand MyCmd
endfunc

func Test_cmdline_complete_bang()
  CheckExecutable whoami
  call feedkeys(":!whoam\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^".*\<whoami\>', @:)
endfunc

func Test_cmdline_complete_languages()
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

func Test_cmdline_complete_argopt()
  " completion for ++opt=arg for file commands
  call assert_equal('fileformat=', getcompletion('edit ++', 'cmdline')[0])
  call assert_equal('encoding=', getcompletion('read ++e', 'cmdline')[0])
  call assert_equal('edit', getcompletion('read ++bin ++edi', 'cmdline')[0])

  call assert_equal(['fileformat='], getcompletion('edit ++ff', 'cmdline'))
  " Test ++ff in the middle of the cmdline
  call feedkeys(":edit ++ff zz\<Left>\<Left>\<Left>\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"edit ++fileformat= zz", @:)

  call assert_equal('dos', getcompletion('write ++ff=d', 'cmdline')[0])
  call assert_equal('mac', getcompletion('args ++fileformat=m', 'cmdline')[0])
  call assert_equal('utf-8', getcompletion('split ++enc=ut*-8', 'cmdline')[0])
  call assert_equal('latin1', getcompletion('tabedit ++encoding=lati', 'cmdline')[0])
  call assert_equal('keep', getcompletion('edit ++bad=k', 'cmdline')[0])

  call assert_equal([], getcompletion('edit ++bogus=', 'cmdline'))

  " completion should skip the ++opt and continue
  call writefile([], 'Xaaaaa.txt', 'D')
  call feedkeys(":split ++enc=latin1 Xaaa\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"split ++enc=latin1 Xaaaaa.txt', @:)

  if has('terminal')
    " completion for terminal's [options]
    call assert_equal('close', getcompletion('terminal ++cl*e', 'cmdline')[0])
    call assert_equal('hidden', getcompletion('terminal ++open ++hidd', 'cmdline')[0])
    call assert_equal('term', getcompletion('terminal ++kill=ter', 'cmdline')[0])

    call assert_equal([], getcompletion('terminal ++bogus=', 'cmdline'))

    " :terminal completion should skip the ++opt when considering what is the
    " first option, which is a list of shell commands, unlike second option
    " onwards.
    let first_param = getcompletion('terminal ', 'cmdline')
    let second_param = getcompletion('terminal foo ', 'cmdline')
    let skipped_opt_param = getcompletion('terminal ++close ', 'cmdline')
    call assert_equal(first_param, skipped_opt_param)
    call assert_notequal(first_param, second_param)
  endif
endfunc

" Unique function name for completion below
func s:WeirdFunc()
  echo 'weird'
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
  call mkdir('Xcwdir')
  call writefile(['one'], 'Xcwdir/Xfile1')
  let save_cwd = getcwd()
  cd Xcwdir
  call feedkeys(":w >> \<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"w >> Xfile1", @:)
  call chdir(save_cwd)
  call delete('Xcwdir', 'rf')

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

  " completion for the :doautocmd command
  call feedkeys(":doautocmd User MyCmd a.c\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"doautocmd User MyCmd a.c\<C-A>", @:)

  " completion of autocmd group after comma
  call feedkeys(":doautocmd BufNew,BufEn\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"doautocmd BufNew,BufEnter", @:)

  " completion of file name in :doautocmd
  call writefile([], 'Xvarfile1')
  call writefile([], 'Xvarfile2')
  call feedkeys(":doautocmd BufEnter Xvarfi\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"doautocmd BufEnter Xvarfile1 Xvarfile2", @:)
  call delete('Xvarfile1')
  call delete('Xvarfile2')

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
  call assert_equal('"MyCmd <F3> <F4>', @:)
  mapclear
  delcom MyCmd

  " Prepare for path completion
  call mkdir('Xa b c', 'D')
  defer delete('Xcomma,foobar.txt')
  call writefile([], 'Xcomma,foobar.txt')

  " completion for :set path= with multiple backslashes
  call feedkeys(':set path=Xa\\\ b' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set path=Xa\\\ b\\\ c/', @:)
  set path&

  " completion for :set dir= with a backslash
  call feedkeys(':set dir=Xa\ b' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set dir=Xa\ b\ c/', @:)
  set dir&

  " completion for :set tags= / set dictionary= with escaped commas
  if has('win32')
    " In Windows backslashes are rounded up, so both '\,' and '\\,' escape to
    " '\,'
    call feedkeys(':set dictionary=Xcomma\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set dictionary=Xcomma\,foobar.txt', @:)

    call feedkeys(':set tags=Xcomma\\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set tags=Xcomma\,foobar.txt', @:)

    call feedkeys(':set tags=Xcomma\\\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set tags=Xcomma\\\,foo', @:) " Didn't find a match

    " completion for :set dictionary= with escaped commas (same behavior, but
    " different internal code path from 'set tags=' for escaping the output)
    call feedkeys(':set tags=Xcomma\\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set tags=Xcomma\,foobar.txt', @:)
  else
    " In other platforms, backslashes are rounded down (since '\,' itself will
    " be escaped into ','). As a result '\\,' and '\\\,' escape to '\,'.
    call feedkeys(':set tags=Xcomma\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set tags=Xcomma\,foo', @:) " Didn't find a match

    call feedkeys(':set tags=Xcomma\\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set tags=Xcomma\\,foobar.txt', @:)

    call feedkeys(':set dictionary=Xcomma\\\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set dictionary=Xcomma\\,foobar.txt', @:)

    " completion for :set dictionary= with escaped commas (same behavior, but
    " different internal code path from 'set tags=' for escaping the output)
    call feedkeys(':set dictionary=Xcomma\\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set dictionary=Xcomma\\,foobar.txt', @:)
  endif
  set tags&
  set dictionary&

  " completion for :set makeprg= with no escaped commas
  call feedkeys(':set makeprg=Xcomma,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set makeprg=Xcomma,foobar.txt', @:)

  if !has('win32')
    " Cannot create file with backslash in file name in Windows, so only test
    " this elsewhere.
    defer delete('Xcomma\,fooslash.txt')
    call writefile([], 'Xcomma\,fooslash.txt')
    call feedkeys(':set makeprg=Xcomma\\,foo' .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set makeprg=Xcomma\\,fooslash.txt', @:)
  endif
  set makeprg&

  " completion for the :py3 commands
  call feedkeys(":py3\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"py3 py3do py3file', @:)

  " redir @" is not the start of a comment. So complete after that
  call feedkeys(":redir @\" | cwin\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"redir @" | cwindow', @:)

  " completion after a backtick
  call feedkeys(":e `a1b2c\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e `a1b2c', @:)

  " completion for :language command with an invalid argument
  call feedkeys(":language dummy \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"language dummy \t", @:)

  " completion for commands after a :global command
  call feedkeys(":g/a\\xb/clearj\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"g/a\xb/clearjumps', @:)

  " completion with ambiguous user defined commands
  com TCmd1 echo 'TCmd1'
  com TCmd2 echo 'TCmd2'
  call feedkeys(":TCmd \t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"TCmd ', @:)
  delcom TCmd1
  delcom TCmd2

  " completion after a range followed by a pipe (|) character
  call feedkeys(":1,10 | chist\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"1,10 | chistory', @:)

  " completion after a :global command
  call feedkeys(":g/a/chist\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"g/a/chistory', @:)
  call feedkeys(":g/a\\/chist\t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"g/a\\/chist\t", @:)

  " use <Esc> as the 'wildchar' for completion
  set wildchar=<Esc>
  call feedkeys(":g/a\\xb/clearj\<Esc>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"g/a\xb/clearjumps', @:)
  " pressing <esc> twice should cancel the command
  call feedkeys(":chist\<Esc>\<Esc>", 'xt')
  call assert_equal('"g/a\xb/clearjumps', @:)
  set wildchar&

  if has('unix')
    " should be able to complete a file name that starts with a '~'.
    call writefile([], '~Xtest')
    call feedkeys(":e \\~X\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e \~Xtest', @:)
    call delete('~Xtest')

    " should be able to complete a file name that has a '*'
    call writefile([], 'Xx*Yy')
    call feedkeys(":e Xx\*\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e Xx\*Yy', @:)
    call delete('Xx*Yy')

    " use a literal star
    call feedkeys(":e \\*\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e \*', @:)
  endif

  call feedkeys(":py3f\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"py3file', @:)
endfunc

" Test that expanding a pattern doesn't interfere with cmdline completion.
func Test_expand_during_cmdline_completion()
  func ExpandStuff()
    badd <script>:p:h/README.*
    call assert_equal(expand('<script>:p:h') .. '/README.txt', bufname('$'))
    $bwipe
    call assert_equal('README.txt', expand('README.*'))
    call assert_equal(['README.txt'], getcompletion('README.*', 'file'))
  endfunc
  augroup test_CmdlineChanged
    autocmd!
    autocmd CmdlineChanged * call ExpandStuff()
  augroup END

  call feedkeys(":sign \<Tab>\<Tab>\<Tab>\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"sign place', @:)

  augroup test_CmdlineChanged
    au!
  augroup END
  augroup! test_CmdlineChanged
  delfunc ExpandStuff
endfunc

" Test for 'wildignorecase'
func Test_cmdline_wildignorecase()
  CheckUnix
  call writefile([], 'XTEST')
  set wildignorecase
  call feedkeys(":e xt\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e XTEST', @:)
  call assert_equal(['XTEST'], getcompletion('xt', 'file'))
  let g:Sline = ''
  call feedkeys(":e xt\<C-d>\<F4>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e xt', @:)
  call assert_equal('XTEST', g:Sline)
  set wildignorecase&
  call delete('XTEST')
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
  call assert_fails('\/print', ['E486:.*apple'])

  bwipe!
endfunc

" Test for the tick mark (') in an excmd range
func Test_tick_mark_in_range()
  " If only the tick is passed as a range and no command is specified, there
  " should not be an error
  call feedkeys(":'\<CR>", 'xt')
  call assert_equal("'", @:)
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

func Test_getcmdtype_getcmdprompt()
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

  call assert_equal('', getcmdprompt())
  augroup test_CmdlineEnter
    autocmd!
    autocmd CmdlineEnter * let g:cmdprompt=getcmdprompt()
  augroup END
  call feedkeys(":call input('Answer?')\<CR>a\<CR>\<ESC>", "xt")
  call assert_equal('Answer?', g:cmdprompt)
  call assert_equal('', getcmdprompt())
  call feedkeys(":\<CR>\<ESC>", "xt")
  call assert_equal('', g:cmdprompt)
  call assert_equal('', getcmdprompt())

  let str = "C" .. repeat("c", 1023) .. "xyz"
  call feedkeys(":call input('" .. str .. "')\<CR>\<CR>\<ESC>", "xt")
  call assert_equal(str, g:cmdprompt)

  call feedkeys(':call input("Msg1\nMessage2\nAns?")' .. "\<CR>b\<CR>\<ESC>", "xt")
  call assert_equal('Ans?', g:cmdprompt)
  call assert_equal('', getcmdprompt())

  augroup test_CmdlineEnter
    au!
  augroup END
  augroup! test_CmdlineEnter
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
  call mkdir('Xdir')
  if !has('win32')  " FIXME: no error on Windows, libuv bug?
  call assert_fails('set verbosefile=Xdir', ['E484:.*Xdir', 'E474:'])
  endif
  call delete('Xdir', 'd')
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
  call TermWait(buf, 50)
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
  call TermWait(buf, 50)
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

func Test_cmdwin_no_terminal()
  CheckFeature cmdwin
  CheckFeature terminal
  CheckNotMSWindows

  let buf = RunVimInTerminal('', {'rows': 12})
  call TermWait(buf, 50)
  call term_sendkeys(buf, ":set cmdheight=2\<CR>")
  call term_sendkeys(buf, "q:")
  call term_sendkeys(buf, ":let buf = term_start(['/bin/echo'], #{hidden: 1})\<CR>")
  call VerifyScreenDump(buf, 'Test_cmdwin_no_terminal', {})
  call term_sendkeys(buf, ":q\<CR>")
  call StopVimInTerminal(buf)
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
  call TermWait(buf, 25)
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
  call assert_fails('call feedkeys("q/:qall\<CR>", "xt")', ['E37:', 'E162:'])
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
  call assert_fails("silent norm q/g	:I\<Esc>", 'E11:')
  tabclose!
endfunc

func Test_cmdwin_interrupted_more_prompt()
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
  augroup! test_cmd_filter_E135
  %bwipe!
endfunc

func Test_cmd_bang_args()
  new
  :.!
  call assert_equal(0, v:shell_error)

  " Note that below there is one space char after the '!'.  This caused a
  " shell error in the past, see https://github.com/vim/vim/issues/11495.
  :.! 
  call assert_equal(0, v:shell_error)
  bwipe!

  CheckUnix
  :.!pwd
  call assert_equal(0, v:shell_error)
  :.! pwd
  call assert_equal(0, v:shell_error)

  " Note there is one space after 'pwd'.
  :.! pwd 
  call assert_equal(0, v:shell_error)

  " Note there are two spaces after 'pwd'.
  :.!  pwd  
  call assert_equal(0, v:shell_error)
  :.!ls ~
  call assert_equal(0, v:shell_error)

  " Note there is one space char after '~'.
  :.!ls  ~ 
  call assert_equal(0, v:shell_error)

  " Note there are two spaces after '~'.
  :.!ls  ~  
  call assert_equal(0, v:shell_error)

  :.!echo "foo"
  call assert_equal(getline('.'), "foo")
  :.!echo "foo  "
  call assert_equal(getline('.'), "foo  ")
  :.!echo " foo  "
  call assert_equal(getline('.'), " foo  ")
  :.!echo  " foo  "
  call assert_equal(getline('.'), " foo  ")

  %bwipe!
endfunc

" Test for using ~ for home directory in cmdline completion matches
func Test_cmdline_expand_home()
  call mkdir('Xexpdir')
  call writefile([], 'Xexpdir/Xfile1')
  call writefile([], 'Xexpdir/Xfile2')
  cd Xexpdir
  let save_HOME = $HOME
  let $HOME = getcwd()
  call feedkeys(":e ~/\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ~/Xfile1 ~/Xfile2', @:)
  let $HOME = save_HOME
  cd ..
  call delete('Xexpdir', 'rf')
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
func Wildmode_tests()
  func T(a, c, p)
    return "oneA\noneB\noneC"
  endfunc
  command -nargs=1 -complete=custom,T MyCmd

  set nowildmenu
  set wildmode=full,list
  let g:Sline = ''
  call feedkeys(":MyCmd \t\t\<F4>\<C-B>\"\<CR>", 'xt')
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
  call feedkeys(":MyCmd \t\<F4>\<C-B>\"\<CR>", 'xt')
  call assert_equal('oneA  oneB  oneC', g:Sline)
  call assert_equal('"MyCmd one', @:)

  set wildmode=""
  call feedkeys(":MyCmd \t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneA', @:)

  " Test for wildmode=longest with 'fileignorecase' set
  set wildmode=longest
  set fileignorecase
  argadd AAA AAAA AAAAA
  call feedkeys(":buffer a\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"buffer AAA', @:)
  set fileignorecase&

  " Test for listing files with wildmode=list
  set wildmode=list
  let g:Sline = ''
  call feedkeys(":b A\t\t\<F4>\<C-B>\"\<CR>", 'xt')
  call assert_equal('AAA    AAAA   AAAAA', g:Sline)
  call assert_equal('"b A', @:)

  " When 'wildmenu' is not set, 'noselect' completes first item
  set wildmode=noselect
  call feedkeys(":MyCmd o\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneA', @:)

  " When 'noselect' is present, do not complete first <tab>.
  set wildmenu
  set wildmode=noselect
  call feedkeys(":MyCmd o\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd o', @:)
  call feedkeys(":MyCmd o\t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd o', @:)
  call feedkeys(":MyCmd o\t\t\<C-Y>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd o', @:)

  " When 'full' is present, complete after first <tab>.
  set wildmode=noselect,full
  call feedkeys(":MyCmd o\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd o', @:)
  call feedkeys(":MyCmd o\t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneA', @:)
  call feedkeys(":MyCmd o\t\t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneB', @:)
  call feedkeys(":MyCmd o\t\t\t\<C-Y>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneB', @:)

  " 'noselect' has no effect when 'longest' is present.
  set wildmode=noselect:longest
  call feedkeys(":MyCmd o\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd one', @:)

  " Complete 'noselect' value in 'wildmode' option
  set wildmode&
  call feedkeys(":set wildmode=n\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set wildmode=noselect', @:)
  call feedkeys(":set wildmode=\t\t\t\t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set wildmode=noselect', @:)

  " when using longest completion match, matches shorter than the argument
  " should be ignored (happens with :help)
  set wildmode=longest,full
  call feedkeys(":help a*\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"help a', @:)
  " non existing file
  call feedkeys(":e a1b2y3z4\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e a1b2y3z4', @:)

  " Test for longest file name completion with 'fileignorecase'
  " On MS-Windows, file names are case insensitive.
  if has('unix')
    call writefile([], 'XTESTfoo', 'D')
    call writefile([], 'Xtestbar', 'D')
    set nofileignorecase
    call feedkeys(":e XT\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e XTESTfoo', @:)
    call feedkeys(":e Xt\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e Xtestbar', @:)
    set fileignorecase
    call feedkeys(":e XT\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e Xtest', @:)
    call feedkeys(":e Xt\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"e Xtest', @:)
    set fileignorecase&
  endif

  " If 'noselect' is present, single item menu should not insert item
  func! T(a, c, p)
    return "oneA"
  endfunc
  command! -nargs=1 -complete=custom,T MyCmd
  set wildmode=noselect,full
  call feedkeys(":MyCmd o\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd o', @:)
  call feedkeys(":MyCmd o\t\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneA', @:)
  " 'nowildmenu' should make 'noselect' ineffective
  set nowildmenu
  call feedkeys(":MyCmd o\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneA', @:)

  %argdelete
  delcommand MyCmd
  delfunc T
  set wildmode&
  %bwipe!
endfunc

func Test_wildmode()
  " Test with utf-8 encoding
  call Wildmode_tests()

  " Test with latin1 encoding
  let save_encoding = &encoding
  " set encoding=latin1
  " call Wildmode_tests()
  let &encoding = save_encoding
endfunc

func Test_custom_complete_autoload()
  call mkdir('Xcustdir/autoload', 'p')
  let save_rtp = &rtp
  exe 'set rtp=' .. getcwd() .. '/Xcustdir'
  let lines =<< trim END
      func vim8#Complete(a, c, p)
        return "oneA\noneB\noneC"
      endfunc
  END
  call writefile(lines, 'Xcustdir/autoload/vim8.vim')

  command -nargs=1 -complete=custom,vim8#Complete MyCmd
  set nowildmenu
  set wildmode=full,list
  call feedkeys(":MyCmd \<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd oneA oneB oneC', @:)

  let &rtp = save_rtp
  set wildmode& wildmenu&
  delcommand MyCmd
  call delete('Xcustdir', 'rf')
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

  let interrupted = 0
  try
    call feedkeys(":Tcmd tw\<C-d>\<C-B>\"\<CR>", 'xt')
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

" This was making the insert position negative
func Test_cmdline_expr_register()
  exe "sil! norm! ?\<C-\>e0\<C-R>0\<Esc>?\<C-\>e0\<CR>"
endfunc

" Test for 'imcmdline' and 'imsearch'
" This test doesn't actually test the input method functionality.
func Test_cmdline_inputmethod()
  throw 'Skipped: Nvim does not allow setting the value of a hidden option'
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
  " call assert_equal('"abcñèæ', @:)
  call assert_equal('"abcxyz', @:)
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
  call mkdir('Xdir1/dir2/dir3/dir4', 'p')
  call writefile([], 'Xdir1/file1_1.txt')
  call writefile([], 'Xdir1/file1_2.txt')
  call writefile([], 'Xdir1/dir2/file2_1.txt')
  call writefile([], 'Xdir1/dir2/file2_2.txt')
  call writefile([], 'Xdir1/dir2/dir3/file3_1.txt')
  call writefile([], 'Xdir1/dir2/dir3/file3_2.txt')
  call writefile([], 'Xdir1/dir2/dir3/dir4/file4_1.txt')
  call writefile([], 'Xdir1/dir2/dir3/dir4/file4_2.txt')
  set wildmenu

  cd Xdir1/dir2/dir3/dir4
  call feedkeys(":e \<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e file4_1.txt', @:)
  call feedkeys(":e \<Tab>\<Up>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../dir4/', @:)
  call feedkeys(":e \<Tab>\<Up>\<Up>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../../dir3/', @:)
  call feedkeys(":e \<Tab>\<Up>\<Up>\<Up>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../../../dir2/', @:)
  call feedkeys(":e \<Tab>\<Up>\<Up>\<Down>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../../dir3/dir4/', @:)
  call feedkeys(":e \<Tab>\<Up>\<Up>\<Down>\<Down>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e ../../dir3/dir4/file4_1.txt', @:)
  cd -
  call feedkeys(":e Xdir1/\<Tab>\<Down>\<Down>\<Down>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xdir1/dir2/dir3/dir4/file4_1.txt', @:)

  call delete('Xdir1', 'rf')
  set wildmenu&
endfunc

" Test for recalling newer or older cmdline from history with <Up>, <Down>,
" <S-Up>, <S-Down>, <PageUp>, <PageDown>, <kPageUp>, <kPageDown>, <C-p>, or
" <C-n>.
func Test_recalling_cmdline()
  CheckFeature cmdline_hist

  let g:cmdlines = []
  cnoremap <Plug>(save-cmdline) <Cmd>let g:cmdlines += [getcmdline()]<CR>

  let histories = [
  \  #{name: 'cmd',    enter: ':',                    exit: "\<Esc>"},
  \  #{name: 'search', enter: '/',                    exit: "\<Esc>"},
  \  #{name: 'expr',   enter: ":\<C-r>=",             exit: "\<Esc>\<Esc>"},
  \  #{name: 'input',  enter: ":call input('')\<CR>", exit: "\<CR>"},
  "\ TODO: {'name': 'debug', ...}
  \]
  let keypairs = [
  \  #{older: "\<Up>",     newer: "\<Down>",     prefixmatch: v:true},
  \  #{older: "\<S-Up>",   newer: "\<S-Down>",   prefixmatch: v:false},
  \  #{older: "\<PageUp>", newer: "\<PageDown>", prefixmatch: v:false},
  \  #{older: "\<kPageUp>", newer: "\<kPageDown>", prefixmatch: v:false},
  \  #{older: "\<C-p>",    newer: "\<C-n>",      prefixmatch: v:false},
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

func Test_cmd_map_cmdlineChanged()
  let g:log = []
  cnoremap <F1> l<Cmd><CR>s
  augroup test_CmdlineChanged
    autocmd!
    autocmd CmdlineChanged : let g:log += [getcmdline()]
  augroup END

  call feedkeys(":\<F1>\<CR>", 'xt')
  call assert_equal(['l', 'ls'], g:log)

  let @b = 'b'
  cnoremap <F1> a<C-R>b
  let g:log = []
  call feedkeys(":\<F1>\<CR>", 'xt')
  call assert_equal(['a', 'ab'], g:log)

  unlet g:log
  cunmap <F1>
  augroup test_CmdlineChanged
    autocmd!
  augroup END
  augroup! test_CmdlineChanged
endfunc

" Test for the 'suffixes' option
func Test_suffixes_opt()
  call writefile([], 'Xsuffile')
  call writefile([], 'Xsuffile.c')
  call writefile([], 'Xsuffile.o')
  set suffixes=
  call feedkeys(":e Xsuffi*\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xsuffile Xsuffile.c Xsuffile.o', @:)
  call feedkeys(":e Xsuffi*\<Tab>\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xsuffile.c', @:)
  set suffixes=.c
  call feedkeys(":e Xsuffi*\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xsuffile Xsuffile.o Xsuffile.c', @:)
  call feedkeys(":e Xsuffi*\<Tab>\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xsuffile.o', @:)
  set suffixes=,,
  call feedkeys(":e Xsuffi*\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xsuffile.c Xsuffile.o Xsuffile', @:)
  call feedkeys(":e Xsuffi*\<Tab>\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"e Xsuffile.o', @:)
  set suffixes&
  " Test for getcompletion() with different patterns
  call assert_equal(['Xsuffile', 'Xsuffile.c', 'Xsuffile.o'], getcompletion('Xsuffile', 'file'))
  call assert_equal(['Xsuffile'], getcompletion('Xsuffile$', 'file'))
  call delete('Xsuffile')
  call delete('Xsuffile.c')
  call delete('Xsuffile.o')
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

    func CmdCompl(a, b, c)
      return repeat(['aaaa'], 120)
    endfunc
    command -nargs=* -complete=customlist,CmdCompl Tcmd

    func MyStatusLine() abort
      return 'status'
    endfunc
    func SetupStatusline()
      set statusline=%!MyStatusLine()
      set laststatus=2
    endfunc

    func MyTabLine()
      return 'my tab line'
    endfunc
    func SetupTabline()
      set statusline=
      set tabline=%!MyTabLine()
      set showtabline=2
    endfunc

    func DoFeedKeys()
      let &wildcharm = char2nr("\t")
      call feedkeys(":edit $VIMRUNTIME/\<Tab>\<Left>\<C-U>ab\<Tab>")
    endfunc
  [CODE]
  call writefile(commands, 'Xtest', 'D')

  let buf = RunVimInTerminal('-S Xtest', #{rows: 10})

  call term_sendkeys(buf, ":sign \<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_01', {})

  " going down the popup menu using <Down>
  call term_sendkeys(buf, "\<Down>\<Down>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_02', {})

  " going down the popup menu using <C-N>
  call term_sendkeys(buf, "\<C-N>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_03', {})

  " going up the popup menu using <C-P>
  call term_sendkeys(buf, "\<C-P>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_04', {})

  " going up the popup menu using <Up>
  call term_sendkeys(buf, "\<Up>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_05', {})

  " pressing <C-E> should end completion and go back to the original match
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_06', {})

  " pressing <C-Y> should select the current match and end completion
  call term_sendkeys(buf, "\<Tab>\<C-P>\<C-P>\<C-Y>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_07', {})

  " With 'wildmode' set to 'longest,full', completing a match should display
  " the longest match, the wildmenu should not be displayed.
  call term_sendkeys(buf, ":\<C-U>set wildmode=longest,full\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, ":sign u\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_08', {})

  " pressing <Tab> should display the wildmenu
  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_09', {})

  " pressing <Tab> second time should select the next entry in the menu
  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_10', {})

  call term_sendkeys(buf, ":\<C-U>set wildmode=full\<CR>")
  " showing popup menu in different columns in the cmdline
  call term_sendkeys(buf, ":sign define \<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_11', {})

  call term_sendkeys(buf, " \<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_12', {})

  call term_sendkeys(buf, " \<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_13', {})

  " Directory name completion
  call mkdir('Xnamedir/XdirA/XdirB', 'pR')
  call writefile([], 'Xnamedir/XfileA')
  call writefile([], 'Xnamedir/XdirA/XfileB')
  call writefile([], 'Xnamedir/XdirA/XdirB/XfileC')

  call term_sendkeys(buf, "\<C-U>e Xnamedi\<Tab>\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_14', {})

  " Pressing <Right> on a directory name should go into that directory
  call term_sendkeys(buf, "\<Right>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_15', {})

  " Pressing <Left> on a directory name should go to the parent directory
  call term_sendkeys(buf, "\<Left>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_16', {})

  " Pressing <C-A> when the popup menu is displayed should list all the
  " matches but the popup menu should still remain
  call term_sendkeys(buf, "\<C-U>sign \<Tab>\<C-A>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_17', {})

  " Pressing <C-D> when the popup menu is displayed should remove the popup
  " menu
  call term_sendkeys(buf, "\<C-U>sign \<Tab>\<C-D>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_18', {})

  " Pressing <S-Tab> should open the popup menu with the last entry selected
  call term_sendkeys(buf, "\<C-U>\<CR>:sign \<S-Tab>\<C-P>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_19', {})

  " Pressing <Esc> should close the popup menu and cancel the cmd line
  call term_sendkeys(buf, "\<C-U>\<CR>:sign \<Tab>\<Esc>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_20', {})

  " Typing a character when the popup is open, should close the popup
  call term_sendkeys(buf, ":sign \<Tab>x")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_21', {})

  " When the popup is open, entering the cmdline window should close the popup
  call term_sendkeys(buf, "\<C-U>sign \<Tab>\<C-F>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_22', {})
  call term_sendkeys(buf, ":q\<CR>")

  " After the last popup menu item, <C-N> should show the original string
  call term_sendkeys(buf, ":sign u\<Tab>\<C-N>\<C-N>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_23', {})

  " Use the popup menu for the command name
  call term_sendkeys(buf, "\<C-U>bu\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_24', {})

  " Pressing the left arrow should remove the popup menu
  call term_sendkeys(buf, "\<Left>\<Left>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_25', {})

  " Pressing <BS> should remove the popup menu and erase the last character
  call term_sendkeys(buf, "\<C-E>\<C-U>sign \<Tab>\<BS>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_26', {})

  " Pressing <C-W> should remove the popup menu and erase the previous word
  call term_sendkeys(buf, "\<C-E>\<C-U>sign \<Tab>\<C-W>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_27', {})

  " Pressing <C-U> should remove the popup menu and erase the entire line
  call term_sendkeys(buf, "\<C-E>\<C-U>sign \<Tab>\<C-U>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_28', {})

  " Using <C-E> to cancel the popup menu and then pressing <Up> should recall
  " the cmdline from history
  call term_sendkeys(buf, "sign xyz\<Esc>:sign \<Tab>\<C-E>\<Up>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_29', {})

  " Check "list" still works
  call term_sendkeys(buf, "\<C-U>set wildmode=longest,list\<CR>")
  call term_sendkeys(buf, ":cn\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_30', {})
  call term_sendkeys(buf, "s")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_31', {})

  " Tests a directory name contained full-width characters.
  call mkdir('Xnamedir/あいう', 'p')
  call writefile([], 'Xnamedir/あいう/abc')
  call writefile([], 'Xnamedir/あいう/xyz')
  call writefile([], 'Xnamedir/あいう/123')

  call term_sendkeys(buf, "\<C-U>set wildmode&\<CR>")
  call term_sendkeys(buf, ":\<C-U>e Xnamedir/あいう/\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_32', {})

  " Pressing <C-A> when the popup menu is displayed should list all the
  " matches and pressing a key after that should remove the popup menu
  call term_sendkeys(buf, "\<C-U>set wildmode=full\<CR>")
  call term_sendkeys(buf, ":sign \<Tab>\<C-A>x")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_33', {})

  " Pressing <C-A> when the popup menu is displayed should list all the
  " matches and pressing <Left> after that should move the cursor
  call term_sendkeys(buf, "\<C-U>abc\<Esc>")
  call term_sendkeys(buf, ":sign \<Tab>\<C-A>\<Left>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_34', {})

  " When <C-A> displays a lot of matches (screen scrolls), all the matches
  " should be displayed correctly on the screen.
  call term_sendkeys(buf, "\<End>\<C-U>Tcmd \<Tab>\<C-A>\<Left>\<Left>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_35', {})

  " After using <C-A> to expand all the filename matches, pressing <Up>
  " should not open the popup menu again.
  call term_sendkeys(buf, "\<C-E>\<C-U>:cd Xnamedir/XdirA\<CR>")
  call term_sendkeys(buf, ":e \<Tab>\<C-A>\<Up>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_36', {})
  call term_sendkeys(buf, "\<C-E>\<C-U>:cd -\<CR>")

  " After using <C-A> to expand all the matches, pressing <S-Tab> used to
  " crash Vim
  call term_sendkeys(buf, ":sign \<Tab>\<C-A>\<S-Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_37', {})

  " After removing the pum the command line is redrawn
  call term_sendkeys(buf, ":edit foo\<CR>")
  call term_sendkeys(buf, ":edit bar\<CR>")
  call term_sendkeys(buf, ":ls\<CR>")
  call term_sendkeys(buf, ":com\<Tab> ")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_38', {})
  call term_sendkeys(buf, "\<C-U>\<CR>")

  " Esc still works to abort the command when 'statusline' is set
  call term_sendkeys(buf, ":call SetupStatusline()\<CR>")
  call term_sendkeys(buf, ":si\<Tab>")
  call term_sendkeys(buf, "\<Esc>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_39', {})

  " Esc still works to abort the command when 'tabline' is set
  call term_sendkeys(buf, ":call SetupTabline()\<CR>")
  call term_sendkeys(buf, ":si\<Tab>")
  call term_sendkeys(buf, "\<Esc>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_40', {})

  " popup is cleared also when 'lazyredraw' is set
  call term_sendkeys(buf, ":set showtabline=1 laststatus=1 lazyredraw\<CR>")
  call term_sendkeys(buf, ":call DoFeedKeys()\<CR>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_41', {})
  call term_sendkeys(buf, "\<Esc>")

  " Pressing <PageDown> should scroll the menu downward
  call term_sendkeys(buf, ":sign \<Tab>\<PageDown>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_42', {})
  call term_sendkeys(buf, "\<PageDown>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_43', {})
  call term_sendkeys(buf, "\<PageDown>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_44', {})
  call term_sendkeys(buf, "\<PageDown>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_45', {})
  call term_sendkeys(buf, "\<C-U>sign \<Tab>\<Down>\<Down>\<PageDown>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_46', {})

  " Pressing <PageUp> should scroll the menu upward
  call term_sendkeys(buf, "\<C-U>sign \<Tab>\<PageUp>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_47', {})
  call term_sendkeys(buf, "\<PageUp>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_48', {})
  call term_sendkeys(buf, "\<PageUp>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_49', {})
  call term_sendkeys(buf, "\<PageUp>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_50', {})

  " pressing <C-E> to end completion should work in middle of the line too
  call term_sendkeys(buf, "\<Esc>:set wildchazz\<Left>\<Left>\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_51', {})
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_52', {})

  " pressing <C-Y> should select the current match and end completion
  call term_sendkeys(buf, "\<Esc>:set wildchazz\<Left>\<Left>\<Tab>\<C-Y>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_53', {})

  call term_sendkeys(buf, "\<C-U>\<CR>")
  call StopVimInTerminal(buf)
endfunc

" Test for wildmenumode() with the cmdline popup menu
func Test_wildmenumode_with_pum()
  set wildmenu
  set wildoptions=pum
  cnoremap <expr> <F2> wildmenumode()
  call feedkeys(":sign \<Tab>\<F2>\<F2>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"sign define10', @:)
  call feedkeys(":sign \<Tab>\<C-A>\<F2>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"sign define jump list place undefine unplace0', @:)
  call feedkeys(":sign \<Tab>\<C-E>\<F2>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"sign 0', @:)
  call feedkeys(":sign \<Tab>\<C-Y>\<F2>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"sign define0', @:)
  set nowildmenu wildoptions&
  cunmap <F2>
endfunc

" Test for opening the cmdline completion popup menu from the terminal window.
" The popup menu should be positioned correctly over the status line of the
" bottom-most window.
func Test_wildmenu_pum_from_terminal()
  CheckRunVimInTerminal
  let python = PythonProg()
  call CheckPython(python)

  %bw!
  let cmds = ['set wildmenu wildoptions=pum']
  let pcmd = python .. ' -c "import sys; sys.stdout.write(sys.stdin.read())"'
  call add(cmds, "call term_start('" .. pcmd .. "')")
  call writefile(cmds, 'Xtest', 'D')
  let buf = RunVimInTerminal('-S Xtest', #{rows: 10})
  call term_sendkeys(buf, "\r\r\r")
  call term_wait(buf)
  call term_sendkeys(buf, "\<C-W>:sign \<Tab>")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_term_01', {})
  call term_wait(buf)
  call StopVimInTerminal(buf)
endfunc

func Test_wildmenu_pum_odd_wildchar()
  CheckRunVimInTerminal

  " Test odd wildchar interactions with pum. Make sure they behave properly
  " and don't lead to memory corruption due to improperly cleaned up memory.
  let lines =<< trim END
    set wildoptions=pum
    set wildchar=<C-E>
  END
  call writefile(lines, 'XwildmenuTest', 'D')
  let buf = RunVimInTerminal('-S XwildmenuTest', #{rows: 10})

  call term_sendkeys(buf, ":\<C-E>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_odd_wildchar_1', {})

  " <C-E> being a wildchar takes priority over its original functionality
  call term_sendkeys(buf, "\<C-E>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_odd_wildchar_2', {})

  call term_sendkeys(buf, "\<Esc>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_odd_wildchar_3', {})

  " Escape key can be wildchar too. Double-<Esc> is hard-coded to escape
  " command-line, and we need to make sure to clean up properly.
  call term_sendkeys(buf, ":set wildchar=<Esc>\<CR>")
  call term_sendkeys(buf, ":\<Esc>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_odd_wildchar_1', {})

  call term_sendkeys(buf, "\<Esc>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_odd_wildchar_3', {})

  " <C-\> can also be wildchar. <C-\><C-N> however will still escape cmdline
  " and we again need to make sure we clean up properly.
  call term_sendkeys(buf, ":set wildchar=<C-\\>\<CR>")
  call term_sendkeys(buf, ":\<C-\>\<C-\>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_odd_wildchar_1', {})

  call term_sendkeys(buf, "\<C-N>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_odd_wildchar_3', {})

  call StopVimInTerminal(buf)
endfunc

" Test that 'rightleft' should not affect cmdline completion popup menu.
func Test_wildmenu_pum_rightleft()
  CheckFeature rightleft
  CheckScreendump

  let lines =<< trim END
    set wildoptions=pum
    set rightleft
  END
  call writefile(lines, 'Xwildmenu_pum_rl', 'D')
  let buf = RunVimInTerminal('-S Xwildmenu_pum_rl', #{rows: 10, cols: 50})

  call term_sendkeys(buf, ":sign \<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_rl', {})

  call StopVimInTerminal(buf)
endfunc

" Test highlighting when pattern matches non-first character of item
func Test_wildmenu_pum_hl_nonfirst()
  CheckScreendump
  let lines =<< trim END
    set wildoptions=pum wildchar=<tab> wildmode=noselect,full
    hi PmenuMatchSel  ctermfg=6 ctermbg=7
    hi PmenuMatch     ctermfg=4 ctermbg=225
    func T(a, c, p)
      return ["oneA", "o neBneB", "aoneC"]
    endfunc
    command -nargs=1 -complete=customlist,T MyCmd
  END

  call writefile(lines, 'Xwildmenu_pum_hl_nonf', 'D')
  let buf = RunVimInTerminal('-S Xwildmenu_pum_hl_nonf', #{rows: 10, cols: 50})

  call term_sendkeys(buf, ":MyCmd ne\<tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_hl_match_nonf', {})
  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
endfunc

" Test highlighting matched text in cmdline completion popup menu.
func Test_wildmenu_pum_hl_match()
  CheckScreendump

  let lines =<< trim END
    set wildoptions=pum,fuzzy
    hi PmenuMatchSel  ctermfg=6 ctermbg=7
    hi PmenuMatch     ctermfg=4 ctermbg=225
  END
  call writefile(lines, 'Xwildmenu_pum_hl', 'D')
  let buf = RunVimInTerminal('-S Xwildmenu_pum_hl', #{rows: 10, cols: 50})

  call term_sendkeys(buf, ":sign plc\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_hl_match_1', {})
  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_hl_match_2', {})
  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_hl_match_3', {})
  call term_sendkeys(buf, "\<Esc>:set wildoptions-=fuzzy\<CR>")
  call TermWait(buf)
  call term_sendkeys(buf, ":sign un\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_hl_match_4', {})
  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_hl_match_5', {})
  call term_sendkeys(buf, "\<Tab>")
  call VerifyScreenDump(buf, 'Test_wildmenu_pum_hl_match_6', {})
  call term_sendkeys(buf, "\<Esc>")

  call StopVimInTerminal(buf)
endfunc

" Test for completion after a :substitute command followed by a pipe (|)
" character
func Test_cmdline_complete_substitute()
  call feedkeys(":s | \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s | \t", @:)
  call feedkeys(":s/ | \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s/ | \t", @:)
  call feedkeys(":s/one | \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s/one | \t", @:)
  call feedkeys(":s/one/ | \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s/one/ | \t", @:)
  call feedkeys(":s/one/two | \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s/one/two | \t", @:)
  call feedkeys(":s/one/two/ | chist\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"s/one/two/ | chistory', @:)
  call feedkeys(":s/one/two/g \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s/one/two/g \t", @:)
  call feedkeys(":s/one/two/g | chist\t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s/one/two/g | chistory", @:)
  call feedkeys(":s/one/t\\/ | \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"s/one/t\\/ | \t", @:)
  call feedkeys(":s/one/t\"o/ | chist\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"s/one/t"o/ | chistory', @:)
  call feedkeys(":s/one/t|o/ | chist\t\<C-B>\"\<CR>", 'xt')
  call assert_equal('"s/one/t|o/ | chistory', @:)
  call feedkeys(":&\t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"&\t", @:)
endfunc

" Test for the :dlist command completion
func Test_cmdline_complete_dlist()
  call feedkeys(":dlist 10 /pat/ a\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"dlist 10 /pat/ a\<C-A>", @:)
  call feedkeys(":dlist 10 /pat/ \t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"dlist 10 /pat/ \t", @:)
  call feedkeys(":dlist 10 /pa\\t/\t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"dlist 10 /pa\\t/\t", @:)
  call feedkeys(":dlist 10 /pat\\\t\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"dlist 10 /pat\\\t", @:)
  call feedkeys(":dlist 10 /pat/ | chist\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"dlist 10 /pat/ | chistory", @:)
endfunc

" argument list (only for :argdel) fuzzy completion
func Test_fuzzy_completion_arglist()
  argadd change.py count.py charge.py
  set wildoptions&
  call feedkeys(":argdel cge\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"argdel cge', @:)
  set wildoptions=fuzzy
  call feedkeys(":argdel cge\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"argdel change.py charge.py', @:)
  %argdelete
  set wildoptions&
endfunc

" autocmd group name fuzzy completion
func Test_fuzzy_completion_autocmd()
  set wildoptions&
  augroup MyFuzzyGroup
  augroup END
  call feedkeys(":augroup mfg\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"augroup mfg', @:)
  call feedkeys(":augroup My*p\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"augroup MyFuzzyGroup', @:)
  set wildoptions=fuzzy
  call feedkeys(":augroup mfg\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"augroup MyFuzzyGroup', @:)
  call feedkeys(":augroup My*p\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"augroup My*p', @:)
  augroup! MyFuzzyGroup
  set wildoptions&
endfunc

" buffer name fuzzy completion
func Test_fuzzy_completion_bufname()
  set wildoptions&
  " Use a long name to reduce the risk of matching a random directory name
  edit SomeRandomFileWithLetters.txt
  enew
  call feedkeys(":b SRFWL\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"b SRFWL', @:)
  call feedkeys(":b S*FileWithLetters.txt\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"b SomeRandomFileWithLetters.txt', @:)
  set wildoptions=fuzzy
  call feedkeys(":b SRFWL\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"b SomeRandomFileWithLetters.txt', @:)
  call feedkeys(":b S*FileWithLetters.txt\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"b S*FileWithLetters.txt', @:)
  %bw!
  set wildoptions&
endfunc

" buffer name (full path) fuzzy completion
func Test_fuzzy_completion_bufname_fullpath()
  CheckUnix
  set wildoptions&
  call mkdir('Xcmd/Xstate/Xfile.js', 'p')
  edit Xcmd/Xstate/Xfile.js
  cd Xcmd/Xstate
  enew
  call feedkeys(":b CmdStateFile\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"b CmdStateFile', @:)
  set wildoptions=fuzzy
  call feedkeys(":b CmdStateFile\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_match('Xcmd/Xstate/Xfile.js$', @:)
  cd -
  call delete('Xcmd', 'rf')
  set wildoptions&
endfunc

" :behave suboptions fuzzy completion
func Test_fuzzy_completion_behave()
  throw 'Skipped: Nvim removed :behave'
  set wildoptions&
  call feedkeys(":behave xm\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"behave xm', @:)
  call feedkeys(":behave xt*m\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"behave xterm', @:)
  set wildoptions=fuzzy
  call feedkeys(":behave xm\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"behave xterm', @:)
  call feedkeys(":behave xt*m\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"behave xt*m', @:)
  let g:Sline = ''
  call feedkeys(":behave win\<C-D>\<F4>\<C-B>\"\<CR>", 'tx')
  call assert_equal('mswin', g:Sline)
  call assert_equal('"behave win', @:)
  set wildoptions&
endfunc

" :filetype suboptions completion
func Test_completion_filetypecmd()
  set wildoptions&
  call feedkeys(":filetype \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"filetype indent off on plugin', @:)
  call feedkeys(":filetype plugin \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"filetype plugin indent off on', @:)
  call feedkeys(":filetype indent \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"filetype indent off on plugin', @:)
  call feedkeys(":filetype i\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"filetype indent', @:)
  call feedkeys(":filetype p\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"filetype plugin', @:)
  call feedkeys(":filetype o\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"filetype off on', @:)
  call feedkeys(":filetype indent of\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"filetype indent off', @:)
  set wildoptions&
endfunc

" " colorscheme name fuzzy completion - NOT supported
" func Test_fuzzy_completion_colorscheme()
" endfunc

" built-in command name fuzzy completion
func Test_fuzzy_completion_cmdname()
  set wildoptions&
  call feedkeys(":sbwin\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sbwin', @:)
  call feedkeys(":sbr*d\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sbrewind', @:)
  set wildoptions=fuzzy
  call feedkeys(":sbwin\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sbrewind', @:)
  call feedkeys(":sbr*d\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sbr*d', @:)
  set wildoptions&
endfunc

" " compiler name fuzzy completion - NOT supported
" func Test_fuzzy_completion_compiler()
" endfunc

" :cscope suboptions fuzzy completion
func Test_fuzzy_completion_cscope()
  CheckFeature cscope
  set wildoptions&
  call feedkeys(":cscope ret\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"cscope ret', @:)
  call feedkeys(":cscope re*t\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"cscope reset', @:)
  set wildoptions=fuzzy
  call feedkeys(":cscope ret\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"cscope reset', @:)
  call feedkeys(":cscope re*t\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"cscope re*t', @:)
  set wildoptions&
endfunc

" :diffget/:diffput buffer name fuzzy completion
func Test_fuzzy_completion_diff()
  new SomeBuffer
  diffthis
  new OtherBuffer
  diffthis
  set wildoptions&
  call feedkeys(":diffget sbuf\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffget sbuf', @:)
  call feedkeys(":diffput sbuf\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffput sbuf', @:)
  set wildoptions=fuzzy
  call feedkeys(":diffget sbuf\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffget SomeBuffer', @:)
  call feedkeys(":diffput sbuf\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"diffput SomeBuffer', @:)
  %bw!
  set wildoptions&
endfunc

" " directory name fuzzy completion - NOT supported
" func Test_fuzzy_completion_dirname()
" endfunc

" environment variable name fuzzy completion
func Test_fuzzy_completion_env()
  set wildoptions&
  call feedkeys(":echo $VUT\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"echo $VUT', @:)
  set wildoptions=fuzzy
  call feedkeys(":echo $VUT\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"echo $VIMRUNTIME', @:)
  set wildoptions&
endfunc

" autocmd event fuzzy completion
func Test_fuzzy_completion_autocmd_event()
  set wildoptions&
  call feedkeys(":autocmd BWout\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"autocmd BWout', @:)
  set wildoptions=fuzzy
  call feedkeys(":autocmd BWout\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"autocmd BufWipeout', @:)
  set wildoptions&
endfunc

" vim expression fuzzy completion
func Test_fuzzy_completion_expr()
  let g:PerPlaceCount = 10
  set wildoptions&
  call feedkeys(":let c = ppc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"let c = ppc', @:)
  set wildoptions=fuzzy
  call feedkeys(":let c = ppc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"let c = PerPlaceCount', @:)
  set wildoptions&
endfunc

" " file name fuzzy completion - NOT supported
" func Test_fuzzy_completion_filename()
" endfunc

" " files in path fuzzy completion - NOT supported
" func Test_fuzzy_completion_filesinpath()
" endfunc

" " filetype name fuzzy completion - NOT supported
" func Test_fuzzy_completion_filetype()
" endfunc

" user defined function name completion
func Test_fuzzy_completion_userdefined_func()
  set wildoptions&
  call feedkeys(":call Test_f_u_f\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"call Test_f_u_f', @:)
  set wildoptions=fuzzy
  call feedkeys(":call Test_f_u_f\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"call Test_fuzzy_completion_userdefined_func()', @:)
  set wildoptions&
endfunc

" <SNR> functions should be sorted to the end
func Test_fuzzy_completion_userdefined_snr_func()
  func s:Sendmail()
  endfunc
  func SendSomemail()
  endfunc
  func S1e2n3dmail()
  endfunc
  set wildoptions=fuzzy
  call feedkeys(":call sendmail\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"call SendSomemail() S1e2n3dmail() '
        \ .. expand("<SID>") .. 'Sendmail()', @:)
  set wildoptions&
  delfunc s:Sendmail
  delfunc SendSomemail
  delfunc S1e2n3dmail
endfunc

" user defined command name completion
func Test_fuzzy_completion_userdefined_cmd()
  set wildoptions&
  call feedkeys(":MsFeat\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"MsFeat', @:)
  set wildoptions=fuzzy
  call feedkeys(":MsFeat\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"MissingFeature', @:)
  set wildoptions&
endfunc

" " :help tag fuzzy completion - NOT supported
" func Test_fuzzy_completion_helptag()
" endfunc

" highlight group name fuzzy completion
func Test_fuzzy_completion_hlgroup()
  set wildoptions&
  call feedkeys(":highlight SKey\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"highlight SKey', @:)
  call feedkeys(":highlight Sp*Key\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"highlight SpecialKey', @:)
  set wildoptions=fuzzy
  call feedkeys(":highlight SKey\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"highlight SpecialKey', @:)
  call feedkeys(":highlight Sp*Key\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"highlight Sp*Key', @:)
  set wildoptions&
endfunc

" :history suboptions fuzzy completion
func Test_fuzzy_completion_history()
  set wildoptions&
  call feedkeys(":history dg\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"history dg', @:)
  call feedkeys(":history se*h\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"history search', @:)
  set wildoptions=fuzzy
  call feedkeys(":history dg\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"history debug', @:)
  call feedkeys(":history se*h\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"history se*h', @:)
  set wildoptions&
endfunc

" :language locale name fuzzy completion
func Test_fuzzy_completion_lang()
  CheckUnix
  set wildoptions&
  call feedkeys(":lang psx\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"lang psx', @:)
  set wildoptions=fuzzy
  call feedkeys(":lang psx\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"lang POSIX', @:)
  set wildoptions&
endfunc

" :mapclear buffer argument fuzzy completion
func Test_fuzzy_completion_mapclear()
  set wildoptions&
  call feedkeys(":mapclear buf\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"mapclear buf', @:)
  set wildoptions=fuzzy
  call feedkeys(":mapclear buf\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"mapclear <buffer>', @:)
  set wildoptions&
endfunc

" map name fuzzy completion
func Test_fuzzy_completion_mapname()
  " test regex completion works
  set wildoptions=fuzzy
  call feedkeys(":cnoremap <ex\<Tab> <esc> \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"cnoremap <expr> <esc> \<Tab>", @:)
  nmap <plug>MyLongMap :p<CR>
  call feedkeys(":nmap MLM\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"nmap <Plug>MyLongMap", @:)
  call feedkeys(":nmap MLM \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"nmap MLM \t", @:)
  call feedkeys(":nmap <F2> one two \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"nmap <F2> one two \t", @:)
  " duplicate entries should be removed
  vmap <plug>MyLongMap :<C-U>#<CR>
  call feedkeys(":nmap MLM\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"nmap <Plug>MyLongMap", @:)
  nunmap <plug>MyLongMap
  vunmap <plug>MyLongMap
  call feedkeys(":nmap ABC\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"nmap ABC\t", @:)
  " results should be sorted by best match
  nmap <Plug>format :
  nmap <Plug>goformat :
  nmap <Plug>TestFOrmat :
  nmap <Plug>fendoff :
  nmap <Plug>state :
  nmap <Plug>FendingOff :
  call feedkeys(":nmap <Plug>fo\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"nmap <Plug>format <Plug>TestFOrmat <Plug>FendingOff <Plug>goformat <Plug>fendoff", @:)
  nunmap <Plug>format
  nunmap <Plug>goformat
  nunmap <Plug>TestFOrmat
  nunmap <Plug>fendoff
  nunmap <Plug>state
  nunmap <Plug>FendingOff
  set wildoptions&
endfunc

" abbreviation fuzzy completion
func Test_fuzzy_completion_abbr()
  set wildoptions=fuzzy
  call feedkeys(":iabbr wait\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"iabbr <nowait>", @:)
  iabbr WaitForCompletion WFC
  call feedkeys(":iabbr fcl\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"iabbr WaitForCompletion", @:)
  call feedkeys(":iabbr a1z\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"iabbr a1z\t", @:)

  iunabbrev WaitForCompletion
  set wildoptions&
endfunc

" menu name fuzzy completion
func Test_fuzzy_completion_menu()
  CheckFeature menu

  source $VIMRUNTIME/menu.vim
  set wildoptions&
  call feedkeys(":menu pup\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"menu pup', @:)
  set wildoptions=fuzzy
  call feedkeys(":menu pup\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"menu PopUp.', @:)

  set wildoptions&
  source $VIMRUNTIME/delmenu.vim
endfunc

" :messages suboptions fuzzy completion
func Test_fuzzy_completion_messages()
  set wildoptions&
  call feedkeys(":messages clr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"messages clr', @:)
  set wildoptions=fuzzy
  call feedkeys(":messages clr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"messages clear', @:)
  set wildoptions&
endfunc

" :set option name fuzzy completion
func Test_fuzzy_completion_option()
  set wildoptions&
  call feedkeys(":set brkopt\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set brkopt', @:)
  set wildoptions=fuzzy
  call feedkeys(":set brkopt\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set breakindentopt', @:)
  set wildoptions&
  call feedkeys(":set fixeol\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set fixendofline', @:)
  set wildoptions=fuzzy
  call feedkeys(":set fixeol\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set fixendofline', @:)
  set wildoptions&
endfunc

" :set <term_option>
func Test_fuzzy_completion_term_option()
  throw 'Skipped: Nvim does not support term options'
  set wildoptions&
  call feedkeys(":set t_E\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set t_EC', @:)
  call feedkeys(":set <t_E\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set <t_EC>', @:)
  set wildoptions=fuzzy
  call feedkeys(":set t_E\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set t_EC', @:)
  call feedkeys(":set <t_E\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set <t_EC>', @:)
  set wildoptions&
endfunc

" " :packadd directory name fuzzy completion - NOT supported
" func Test_fuzzy_completion_packadd()
" endfunc

" " shell command name fuzzy completion - NOT supported
" func Test_fuzzy_completion_shellcmd()
" endfunc

" :sign suboptions fuzzy completion
func Test_fuzzy_completion_sign()
  set wildoptions&
  call feedkeys(":sign ufe\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign ufe', @:)
  set wildoptions=fuzzy
  call feedkeys(":sign ufe\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"sign undefine', @:)
  set wildoptions&
endfunc

" :syntax suboptions fuzzy completion
func Test_fuzzy_completion_syntax_cmd()
  set wildoptions&
  call feedkeys(":syntax kwd\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syntax kwd', @:)
  set wildoptions=fuzzy
  call feedkeys(":syntax kwd\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syntax keyword', @:)
  set wildoptions&
endfunc

" syntax group name fuzzy completion
func Test_fuzzy_completion_syntax_group()
  set wildoptions&
  call feedkeys(":syntax list mpar\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syntax list mpar', @:)
  set wildoptions=fuzzy
  call feedkeys(":syntax list mpar\<Tab>\<C-B>\"\<CR>", 'tx')
  " Fuzzy match prefers NvimParenthesis over MatchParen
  " call assert_equal('"syntax list MatchParen', @:)
  call assert_equal('"syntax list NvimParenthesis', @:)
  set wildoptions&
endfunc

" :syntime suboptions fuzzy completion
func Test_fuzzy_completion_syntime()
  CheckFeature profile
  set wildoptions&
  call feedkeys(":syntime clr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syntime clr', @:)
  set wildoptions=fuzzy
  call feedkeys(":syntime clr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syntime clear', @:)
  set wildoptions&
endfunc

" " tag name fuzzy completion - NOT supported
" func Test_fuzzy_completion_tagname()
" endfunc

" " tag name and file fuzzy completion - NOT supported
" func Test_fuzzy_completion_tagfile()
" endfunc

" " user names fuzzy completion - how to test this functionality?
" func Test_fuzzy_completion_username()
" endfunc

" user defined variable name fuzzy completion
func Test_fuzzy_completion_userdefined_var()
  let g:SomeVariable=10
  set wildoptions&
  call feedkeys(":let SVar\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"let SVar', @:)
  set wildoptions=fuzzy
  call feedkeys(":let SVar\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"let SomeVariable', @:)
  set wildoptions&
endfunc

" Test for sorting the results by the best match
func Test_fuzzy_completion_cmd_sort_results()
  %bw!
  command T123format :
  command T123goformat :
  command T123TestFOrmat :
  command T123fendoff :
  command T123state :
  command T123FendingOff :
  set wildoptions=fuzzy
  call feedkeys(":T123fo\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"T123format T123TestFOrmat T123FendingOff T123goformat T123fendoff', @:)
  delcommand T123format
  delcommand T123goformat
  delcommand T123TestFOrmat
  delcommand T123fendoff
  delcommand T123state
  delcommand T123FendingOff
  %bw
  set wildoptions&
endfunc

" Test for fuzzy completion of a command with lower case letters and a number
func Test_fuzzy_completion_cmd_alnum()
  command Foo2Bar :
  set wildoptions=fuzzy
  call feedkeys(":foo2\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"Foo2Bar', @:)
  call feedkeys(":foo\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"Foo2Bar', @:)
  call feedkeys(":bar\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"Foo2Bar', @:)
  delcommand Foo2Bar
  set wildoptions&
endfunc

" Test for command completion for a command starting with 'k'
func Test_fuzzy_completion_cmd_k()
  command KillKillKill :
  set wildoptions&
  call feedkeys(":killkill\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"killkill\<Tab>", @:)
  set wildoptions=fuzzy
  call feedkeys(":killkill\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"KillKillKill', @:)
  delcom KillKillKill
  set wildoptions&
endfunc

" Test for fuzzy completion for user defined custom completion function
func Test_fuzzy_completion_custom_func()
  func Tcompl(a, c, p)
    return "format\ngoformat\nTestFOrmat\nfendoff\nstate"
  endfunc
  command -nargs=* -complete=custom,Tcompl Fuzzy :
  set wildoptions&
  call feedkeys(":Fuzzy fo\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"Fuzzy format", @:)
  call feedkeys(":Fuzzy xy\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"Fuzzy xy", @:)
  call feedkeys(":Fuzzy ttt\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"Fuzzy ttt", @:)
  set wildoptions=fuzzy
  call feedkeys(":Fuzzy \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"Fuzzy format goformat TestFOrmat fendoff state", @:)
  call feedkeys(":Fuzzy fo\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"Fuzzy format TestFOrmat goformat fendoff", @:)
  call feedkeys(":Fuzzy xy\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"Fuzzy xy", @:)
  call feedkeys(":Fuzzy ttt\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"Fuzzy TestFOrmat", @:)
  delcom Fuzzy
  set wildoptions&
endfunc

" Test for fuzzy completion in the middle of a cmdline instead of at the end
func Test_fuzzy_completion_in_middle()
  set wildoptions=fuzzy
  call feedkeys(":set ildar wrap\<Left>\<Left>\<Left>\<Left>\<Left>\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"set wildchar wildcharm wrap", @:)

  call feedkeys(":args ++odng zz\<Left>\<Left>\<Left>\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"args ++encoding= zz", @:)
  set wildoptions&
endfunc

" Test for :breakadd argument completion
func Test_cmdline_complete_breakadd()
  call feedkeys(":breakadd \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd expr file func here", @:)
  call feedkeys(":breakadd \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd expr", @:)
  call feedkeys(":breakadd    \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd    expr", @:)
  call feedkeys(":breakadd he\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd here", @:)
  call feedkeys(":breakadd    he\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd    here", @:)
  call feedkeys(":breakadd abc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd abc", @:)
  call assert_equal(['expr', 'file', 'func', 'here'], getcompletion('', 'breakpoint'))
  let l = getcompletion('not', 'breakpoint')
  call assert_equal([], l)

  " Test for :breakadd file [lnum] <file>
  call writefile([], 'Xscript')
  call feedkeys(":breakadd file Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd file Xscript", @:)
  call feedkeys(":breakadd   file   Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd   file   Xscript", @:)
  call feedkeys(":breakadd file 20 Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd file 20 Xscript", @:)
  call feedkeys(":breakadd   file   20   Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd   file   20   Xscript", @:)
  call feedkeys(":breakadd file 20x Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd file 20x Xsc\t", @:)
  call feedkeys(":breakadd file 20\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd file 20\t", @:)
  call feedkeys(":breakadd file 20x\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd file 20x\t", @:)
  call feedkeys(":breakadd file Xscript  \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd file Xscript  ", @:)
  call feedkeys(":breakadd file X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd file X1B2C3", @:)
  call delete('Xscript')

  " Test for :breakadd func [lnum] <function>
  func Xbreak_func()
  endfunc
  call feedkeys(":breakadd func Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd func Xbreak_func", @:)
  call feedkeys(":breakadd    func    Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd    func    Xbreak_func", @:)
  call feedkeys(":breakadd func 20 Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd func 20 Xbreak_func", @:)
  call feedkeys(":breakadd   func   20   Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd   func   20   Xbreak_func", @:)
  call feedkeys(":breakadd func 20x Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd func 20x Xbr\t", @:)
  call feedkeys(":breakadd func 20\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd func 20\t", @:)
  call feedkeys(":breakadd func 20x\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd func 20x\t", @:)
  call feedkeys(":breakadd func Xbreak_func  \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd func Xbreak_func  ", @:)
  call feedkeys(":breakadd func X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd func X1B2C3", @:)
  delfunc Xbreak_func

  " Test for :breakadd expr <expression>
  let g:Xtest_var = 10
  call feedkeys(":breakadd expr Xtest\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd expr Xtest_var", @:)
  call feedkeys(":breakadd    expr    Xtest\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd    expr    Xtest_var", @:)
  call feedkeys(":breakadd expr Xtest_var  \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd expr Xtest_var  ", @:)
  call feedkeys(":breakadd expr X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd expr X1B2C3", @:)
  unlet g:Xtest_var

  " Test for :breakadd here
  call feedkeys(":breakadd here Xtest\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd here Xtest", @:)
  call feedkeys(":breakadd   here   Xtest\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd   here   Xtest", @:)
  call feedkeys(":breakadd here \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakadd here ", @:)
endfunc

" Test for :breakdel argument completion
func Test_cmdline_complete_breakdel()
  call feedkeys(":breakdel \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file func here", @:)
  call feedkeys(":breakdel \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file", @:)
  call feedkeys(":breakdel    \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel    file", @:)
  call feedkeys(":breakdel he\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel here", @:)
  call feedkeys(":breakdel    he\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel    here", @:)
  call feedkeys(":breakdel abc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel abc", @:)

  " Test for :breakdel file [lnum] <file>
  call writefile([], 'Xscript')
  call feedkeys(":breakdel file Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file Xscript", @:)
  call feedkeys(":breakdel   file   Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel   file   Xscript", @:)
  call feedkeys(":breakdel file 20 Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file 20 Xscript", @:)
  call feedkeys(":breakdel   file   20   Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel   file   20   Xscript", @:)
  call feedkeys(":breakdel file 20x Xsc\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file 20x Xsc\t", @:)
  call feedkeys(":breakdel file 20\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file 20\t", @:)
  call feedkeys(":breakdel file 20x\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file 20x\t", @:)
  call feedkeys(":breakdel file Xscript  \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file Xscript  ", @:)
  call feedkeys(":breakdel file X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel file X1B2C3", @:)
  call delete('Xscript')

  " Test for :breakdel func [lnum] <function>
  func Xbreak_func()
  endfunc
  call feedkeys(":breakdel func Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel func Xbreak_func", @:)
  call feedkeys(":breakdel   func   Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel   func   Xbreak_func", @:)
  call feedkeys(":breakdel func 20 Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel func 20 Xbreak_func", @:)
  call feedkeys(":breakdel   func   20   Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel   func   20   Xbreak_func", @:)
  call feedkeys(":breakdel func 20x Xbr\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel func 20x Xbr\t", @:)
  call feedkeys(":breakdel func 20\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel func 20\t", @:)
  call feedkeys(":breakdel func 20x\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel func 20x\t", @:)
  call feedkeys(":breakdel func Xbreak_func  \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel func Xbreak_func  ", @:)
  call feedkeys(":breakdel func X1B2C3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel func X1B2C3", @:)
  delfunc Xbreak_func

  " Test for :breakdel here
  call feedkeys(":breakdel here Xtest\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel here Xtest", @:)
  call feedkeys(":breakdel   here   Xtest\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel   here   Xtest", @:)
  call feedkeys(":breakdel here \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"breakdel here ", @:)
endfunc

" Test for :scriptnames argument completion
func Test_cmdline_complete_scriptnames()
  set wildmenu
  call writefile(['let a = 1'], 'Xa1b2c3.vim')
  source Xa1b2c3.vim
  call feedkeys(":script \<Tab>\<Left>\<Left>\<C-B>\"\<CR>", 'tx')
  call assert_match("\"script .*Xa1b2c3.vim$", @:)
  call feedkeys(":script    \<Tab>\<Left>\<Left>\<C-B>\"\<CR>", 'tx')
  call assert_match("\"script .*Xa1b2c3.vim$", @:)
  call feedkeys(":script b2c3\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"script b2c3", @:)
  call feedkeys(":script 2\<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_match("\"script 2\<Tab>$", @:)
  call feedkeys(":script \<Tab>\<Left>\<Left> \<Tab>\<C-B>\"\<CR>", 'tx')
  call assert_match("\"script .*Xa1b2c3.vim $", @:)
  call feedkeys(":script \<Tab>\<Left>\<C-B>\"\<CR>", 'tx')
  call assert_equal("\"script ", @:)
  call assert_match('Xa1b2c3.vim$', getcompletion('.*Xa1b2.*', 'scriptnames')[0])
  call assert_equal([], getcompletion('Xa1b2', 'scriptnames'))
  new
  call feedkeys(":script \<Tab>\<Left>\<Left>\<CR>", 'tx')
  call assert_equal('Xa1b2c3.vim', fnamemodify(@%, ':t'))
  bw!
  call delete('Xa1b2c3.vim')
  set wildmenu&
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

" Test for shellcmdline command argument completion
func Test_cmdline_complete_shellcmdline_argument()
  command -nargs=+ -complete=shellcmdline MyCmd

  set wildoptions=fuzzy

  call feedkeys(":MyCmd vim test_cmdline.\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim test_cmdline.vim', @:)
  call assert_equal(['test_cmdline.vim'],
        \ getcompletion('vim test_cmdline.', 'shellcmdline'))

  call feedkeys(":MyCmd vim nonexistentfile\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim nonexistentfile', @:)
  call assert_equal([],
        \ getcompletion('vim nonexistentfile', 'shellcmdline'))

  let compl1 = getcompletion('', 'file')[0]
  let compl2 = getcompletion('', 'file')[1]
  call feedkeys(":MyCmd vim \<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim ' .. compl1, @:)

  call feedkeys(":MyCmd vim \<Tab> \<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim ' .. compl1 .. ' ' .. compl1, @:)

  let compl = getcompletion('', 'file')[1]
  call feedkeys(":MyCmd vim \<Tab> \<Tab>\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim ' .. compl1 .. ' ' .. compl2, @:)

  set wildoptions&
  call feedkeys(":MyCmd vim test_cmdline.\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim test_cmdline.vim', @:)
  call assert_equal(['test_cmdline.vim'],
        \ getcompletion('vim test_cmdline.', 'shellcmdline'))

  call feedkeys(":MyCmd vim nonexistentfile\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim nonexistentfile', @:)
  call assert_equal([],
        \ getcompletion('vim nonexistentfile', 'shellcmdline'))

  let compl1 = getcompletion('', 'file')[0]
  let compl2 = getcompletion('', 'file')[1]
  call feedkeys(":MyCmd vim \<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim ' .. compl1, @:)

  call feedkeys(":MyCmd vim \<Tab> \<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim ' .. compl1 .. ' ' .. compl1, @:)

  let compl = getcompletion('', 'file')[1]
  call feedkeys(":MyCmd vim \<Tab> \<Tab>\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"MyCmd vim ' .. compl1 .. ' ' .. compl2, @:)

  delcommand MyCmd
endfunc

" Test for :! shell command argument completion
func Test_cmdline_complete_bang_cmd_argument()
  set wildoptions=fuzzy
  call feedkeys(":!vim test_cmdline.\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"!vim test_cmdline.vim', @:)
  set wildoptions&
  call feedkeys(":!vim test_cmdline.\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"!vim test_cmdline.vim', @:)
endfunc

func Call_cmd_funcs()
  return [getcmdpos(), getcmdscreenpos(), getcmdcompltype(), getcmdcomplpat()]
endfunc

func Test_screenpos_and_completion()
  call assert_equal(0, getcmdpos())
  call assert_equal(0, getcmdscreenpos())
  call assert_equal('', getcmdcompltype())
  call assert_equal('', getcmdcomplpat())

  cnoremap <expr> <F2> string(Call_cmd_funcs())
  call feedkeys(":let a\<F2>\<C-B>\"\<CR>", "xt")
  call assert_equal("\"let a[6, 7, 'var', 'a']", @:)
  call feedkeys(":quit \<F2>\<C-B>\"\<CR>", "xt")
  call assert_equal("\"quit [6, 7, '', '']", @:)
  call feedkeys(":nosuchcommand \<F2>\<C-B>\"\<CR>", "xt")
  call assert_equal("\"nosuchcommand [15, 16, '', '']", @:)

  " Check that getcmdcompltype() and getcmdcomplpat() don't interfere with
  " cmdline completion.
  let g:results = []
  cnoremap <F2> <Cmd>let g:results += [[getcmdline()] + Call_cmd_funcs()]<CR>
  call feedkeys(":sign un\<Tab>\<F2>\<Tab>\<F2>\<Tab>\<F2>\<C-C>", "xt")
  call assert_equal([
        \ ['sign undefine', 14, 15, 'sign', 'undefine'],
        \ ['sign unplace', 13, 14, 'sign', 'unplace'],
        \ ['sign un', 8, 9, 'sign', 'un']], g:results)

  unlet g:results
  cunmap <F2>
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
    call assert_equal(0, setcmdline(v:_null_string))
    call assert_equal('', getcmdline())
    call assert_equal(1, getcmdpos())

    call assert_equal(0, setcmdline(''[: -1]))
    call assert_equal('', getcmdline())
    call assert_equal(1, getcmdpos())

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

func Test_rulerformat_position()
  CheckScreendump

  let buf = RunVimInTerminal('', #{rows: 2, cols: 20})
  call term_sendkeys(buf, ":set ruler rulerformat=longish\<CR>")
  call term_sendkeys(buf, ":set laststatus=0 winwidth=1\<CR>")
  call term_sendkeys(buf, "\<C-W>v\<C-W>|\<C-W>p")
  call VerifyScreenDump(buf, 'Test_rulerformat_position', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

" Test for using "%!" in 'rulerformat' to use a function
func Test_rulerformat_function()
  CheckScreendump

  let lines =<< trim END
    func TestRulerFn()
      return '10,20%=30%%'
    endfunc
  END
  call writefile(lines, 'Xrulerformat_function', 'D')

  let buf = RunVimInTerminal('-S Xrulerformat_function', #{rows: 2, cols: 40})
  call term_sendkeys(buf, ":set ruler rulerformat=%!TestRulerFn()\<CR>")
  call term_sendkeys(buf, ":redraw!\<CR>")
  call term_wait(buf)
  call VerifyScreenDump(buf, 'Test_rulerformat_function', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_getcompletion_usercmd()
  command! -nargs=* -complete=command TestCompletion echo <q-args>

  call assert_equal(getcompletion('', 'cmdline'),
        \ getcompletion('TestCompletion ', 'cmdline'))
  call assert_equal(['<buffer>'],
        \ getcompletion('TestCompletion map <bu', 'cmdline'))

  delcom TestCompletion
endfunc

func Test_custom_completion()
  func CustomComplete1(lead, line, pos)
    return "a\nb\nc"
  endfunc
  func CustomComplete2(lead, line, pos)
    return ['a', 'b']->filter({ _, val -> val->stridx(a:lead) == 0 })
  endfunc
  func Check_custom_completion()
    call assert_equal('custom,CustomComplete1', getcmdcompltype())
    return ''
  endfunc
  func Check_customlist_completion()
    call assert_equal('customlist,CustomComplete2', getcmdcompltype())
    return ''
  endfunc

  command -nargs=1 -complete=custom,CustomComplete1 Test1 echo
  command -nargs=1 -complete=customlist,CustomComplete2 Test2 echo

  call feedkeys(":Test1 \<C-R>=Check_custom_completion()\<CR>\<Esc>", "xt")
  call feedkeys(":Test2 \<C-R>=Check_customlist_completion()\<CR>\<Esc>", "xt")

  call assert_fails("call getcompletion('', 'custom')", 'E475:')
  call assert_fails("call getcompletion('', 'customlist')", 'E475:')

  call assert_equal(['a', 'b', 'c'], getcompletion('', 'custom,CustomComplete1'))
  call assert_equal(['a', 'b'], getcompletion('', 'customlist,CustomComplete2'))
  call assert_equal(['b'], getcompletion('b', 'customlist,CustomComplete2'))

  delcom Test1
  delcom Test2

  delfunc CustomComplete1
  delfunc CustomComplete2
  delfunc Check_custom_completion
  delfunc Check_customlist_completion
endfunc

func Test_custom_completion_with_glob()
  func TestGlobComplete(A, L, P)
    return split(glob('Xglob*'), "\n")
  endfunc

  command -nargs=* -complete=customlist,TestGlobComplete TestGlobComplete :
  call writefile([], 'Xglob1', 'D')
  call writefile([], 'Xglob2', 'D')

  call feedkeys(":TestGlobComplete \<Tab> \<Tab>\<C-N> \<Tab>\<C-P>;\<C-B>\"\<CR>", 'xt')
  call assert_equal('"TestGlobComplete Xglob1 Xglob2 ;', @:)

  delcommand TestGlobComplete
  delfunc TestGlobComplete
endfunc

func Test_window_size_stays_same_after_changing_cmdheight()
  set laststatus=2
  let expected = winheight(0)
  function! Function_name() abort
    call feedkeys(":"..repeat('x', &columns), 'x')
    let &cmdheight=2
    let &cmdheight=1
    redraw
  endfunction
  call Function_name()
  call assert_equal(expected, winheight(0))
endfunc

" verify that buffer-completion finds all buffer names matching a pattern
func Test_buffer_completion()
  " should return empty list
  call assert_equal([], getcompletion('', 'buffer'))

  call mkdir('Xbuf_complete', 'R')
  e Xbuf_complete/Foobar.c
  e Xbuf_complete/MyFoobar.c
  e AFoobar.h
  let expected = ["Xbuf_complete/Foobar.c", "Xbuf_complete/MyFoobar.c", "AFoobar.h"]

  call assert_equal(3, len(getcompletion('Foo', 'buffer')))
  call assert_equal(expected, getcompletion('Foo', 'buffer'))
  call feedkeys(":b Foo\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"b Xbuf_complete/Foobar.c Xbuf_complete/MyFoobar.c AFoobar.h", @:)
endfunc

" :set t_??
func Test_term_option()
  throw 'Skipped: Nvim does not support termcap options'
  set wildoptions&
  let _cpo = &cpo
  set cpo-=C
  " There may be more, test only until t_xo
  let expected='"set t_AB t_AF t_AU t_AL t_al t_bc t_BE t_BD t_cd t_ce t_Ce t_CF t_cl t_cm'
        \ .. ' t_Co t_CS t_Cs t_cs t_CV t_da t_db t_DL t_dl t_ds t_Ds t_EC t_EI t_fs t_fd t_fe'
        \ .. ' t_GP t_IE t_IS t_ke t_ks t_le t_mb t_md t_me t_mr t_ms t_nd t_op t_RF t_RB t_RC'
        \ .. ' t_RI t_Ri t_RK t_RS t_RT t_RV t_Sb t_SC t_se t_Sf t_SH t_SI t_Si t_so t_SR t_sr'
        \ .. ' t_ST t_Te t_te t_TE t_ti t_TI t_Ts t_ts t_u7 t_ue t_us t_Us t_ut t_vb t_ve t_vi'
        \ .. ' t_VS t_vs t_WP t_WS t_XM t_xn t_xs t_ZH t_ZR t_8f t_8b t_8u t_xo .*'
  call feedkeys(":set t_\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match(expected, @:)
  let &cpo = _cpo
endfunc

func Test_cd_bslash_completion_windows()
  CheckMSWindows
  let save_shellslash = &shellslash
  set noshellslash
  call system('mkdir XXXa\_b')
  defer delete('XXXa', 'rf')
  call feedkeys(":cd XXXa\\_b\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"cd XXXa\_b\', @:)
  let &shellslash = save_shellslash
endfunc

" Test cmdcomplete_info() with CmdlineLeavePre autocmd
func Test_cmdcomplete_info()
  augroup test_CmdlineLeavePre
    autocmd!
    " Calling expand() should not interfere with cmdcomplete_info().
    autocmd CmdlineLeavePre * call expand('test_cmdline.*')
    autocmd CmdlineLeavePre * let g:cmdcomplete_info = string(cmdcomplete_info())
  augroup END
  new
  call assert_equal({}, cmdcomplete_info())
  call feedkeys(":h echom\<cr>", "tx") " No expansion
  call assert_equal('{}', g:cmdcomplete_info)
  call feedkeys(":h echoms\<tab>\<cr>", "tx")
  call assert_equal('{''cmdline_orig'': '''', ''pum_visible'': 0, ''matches'': [], ''selected'': 0}', g:cmdcomplete_info)
  call feedkeys(":h echom\<tab>\<cr>", "tx")
  call assert_equal(
        \ '{''cmdline_orig'': ''h echom'', ''pum_visible'': 0, ''matches'': ['':echom'', '':echomsg''], ''selected'': 0}',
        \ g:cmdcomplete_info)
  call feedkeys(":h echom\<tab>\<tab>\<cr>", "tx")
  call assert_equal(
        \ '{''cmdline_orig'': ''h echom'', ''pum_visible'': 0, ''matches'': ['':echom'', '':echomsg''], ''selected'': 1}',
        \ g:cmdcomplete_info)
  call feedkeys(":h echom\<tab>\<tab>\<tab>\<cr>", "tx")
  call assert_equal(
        \ '{''cmdline_orig'': ''h echom'', ''pum_visible'': 0, ''matches'': ['':echom'', '':echomsg''], ''selected'': -1}',
        \ g:cmdcomplete_info)

  set wildoptions=pum
  call feedkeys(":h echoms\<tab>\<cr>", "tx")
  call assert_equal('{''cmdline_orig'': '''', ''pum_visible'': 0, ''matches'': [], ''selected'': 0}', g:cmdcomplete_info)
  call feedkeys(":h echom\<tab>\<cr>", "tx")
  call assert_equal(
        \ '{''cmdline_orig'': ''h echom'', ''pum_visible'': 1, ''matches'': ['':echom'', '':echomsg''], ''selected'': 0}',
        \ g:cmdcomplete_info)
  call feedkeys(":h echom\<tab>\<tab>\<cr>", "tx")
  call assert_equal(
        \ '{''cmdline_orig'': ''h echom'', ''pum_visible'': 1, ''matches'': ['':echom'', '':echomsg''], ''selected'': 1}',
        \ g:cmdcomplete_info)
  call feedkeys(":h echom\<tab>\<tab>\<tab>\<cr>", "tx")
  call assert_equal(
        \ '{''cmdline_orig'': ''h echom'', ''pum_visible'': 1, ''matches'': ['':echom'', '':echomsg''], ''selected'': -1}',
        \ g:cmdcomplete_info)
  bw!
  set wildoptions&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
