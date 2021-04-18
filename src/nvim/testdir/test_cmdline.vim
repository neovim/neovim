" Tests for editing the command line.

source check.vim
source screendump.vim

func Test_complete_tab()
  call writefile(['testfile'], 'Xtestfile')
  call feedkeys(":e Xtestf\t\r", "tx")
  call assert_equal('testfile', getline(1))
  call delete('Xtestfile')
endfunc

func Test_complete_list()
  " We can't see the output, but at least we check the code runs properly.
  call feedkeys(":e test\<C-D>\r", "tx")
  call assert_equal('test', expand('%:t'))
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
  call feedkeys(":match \<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"match Aardig', getreg(':'))
  call feedkeys(":match \<S-Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"match none', getreg(':'))
endfunc

func Test_highlight_completion()
  if !has('cmdline_compl')
    return
  endif
  hi Aardig ctermfg=green
  call feedkeys(":hi \<Tab>\<Home>\"\<CR>", 'xt')
  call assert_equal('"hi Aardig', getreg(':'))
  call feedkeys(":hi default \<Tab>\<Home>\"\<CR>", 'xt')
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
  let matchcount = len(getcompletion('File', 'event'))
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
  call assert_true(index(l, expand('sautest/')) >= 0)
  let l = getcompletion('NoMatch', 'dir')
  call assert_equal([], l)

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
  call assert_true(index(l, expand('sautest/')) >= 0)
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

  call assert_fails('call getcompletion("", "burp")', 'E475:')
  call assert_fails('call getcompletion("abc", [])', 'E475:')
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
  call assert_equal('find '.expand('a/b/fileXname'), getreg(':'))
  bwipe!
  call delete('a', 'rf')
endfunc

func Test_paste_in_cmdline()
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
  bwipe!
endfunc

func Test_remove_char_in_cmdline()
  call feedkeys(":abc def\<S-Left>\<Del>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"abc ef', @:)

  call feedkeys(":abc def\<S-Left>\<BS>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"abcdef', @:)

  call feedkeys(":abc def ghi\<S-Left>\<C-W>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"abc ghi', @:)

  call feedkeys(":abc def\<S-Left>\<C-U>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"def', @:)
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

func s:ScriptLocalFunction()
  echo 'yes'
endfunc

func Test_cmdline_complete_user_func()
  call feedkeys(":func Test_cmdline_complete_user\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_match('"func Test_cmdline_complete_user', @:)
  call feedkeys(":func s:ScriptL\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_match('"func <SNR>\d\+_ScriptLocalFunction', @:)

  " g: prefix also works
  call feedkeys(":echo g:Test_cmdline_complete_user_f\<Tab>\<Home>\"\<cr>", 'tx')
  call assert_match('"echo g:Test_cmdline_complete_user_func', @:)
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
  let lang = substitute(execute('language messages'), '.*"\(.*\)"$', '\1', '')

  call feedkeys(":language \<c-a>\<c-b>\"\<cr>", 'tx')
  call assert_match('^"language .*\<ctype\>.*\<messages\>.*\<time\>', @:)

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
  endif
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

  bwipe!
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
  call assert_equal(1, setcmdpos(3))
endfunc

func Test_cmdline_overstrike()
  " Nvim: only utf8 is supported.
  let encodings = ['utf8']
  let encoding_save = &encoding

  for e in encodings
    exe 'set encoding=' . e

    " Test overstrike in the middle of the command line.
    call feedkeys(":\"01234\<home>\<right>\<right>ab\<right>\<insert>cd\<enter>", 'xt')
    call assert_equal('"0ab1cd4', @:)

    " Test overstrike going beyond end of command line.
    call feedkeys(":\"01234\<home>\<right>\<right>ab\<right>\<insert>cdefgh\<enter>", 'xt')
    call assert_equal('"0ab1cdefgh', @:)

    " Test toggling insert/overstrike a few times.
    call feedkeys(":\"01234\<home>\<right>ab\<right>\<insert>cd\<right>\<insert>ef\<enter>", 'xt')
    call assert_equal('"ab0cd3ef4', @:)
  endfor

  " Test overstrike with multi-byte characters.
  call feedkeys(":\"テキストエディタ\<home>\<right>\<right>ab\<right>\<insert>cd\<enter>", 'xt')
  call assert_equal('"テabキcdエディタ', @:)

  let &encoding = encoding_save
endfunc

func Test_cmdwin_feedkeys()
  " This should not generate E488
  call feedkeys("q:\<CR>", 'x')
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

" vim: shiftwidth=2 sts=2 expandtab
