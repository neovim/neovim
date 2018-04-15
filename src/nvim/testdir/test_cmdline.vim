" Tests for editing the command line.


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
  call writefile(['testfile1'], 'Xtestfile1')
  call writefile(['testfile2'], 'Xtestfile2')
  set wildmenu
  call feedkeys(":e Xtestf\t\t\r", "tx")
  call assert_equal('testfile2', getline(1))

  call delete('Xtestfile1')
  call delete('Xtestfile2')
  set nowildmenu
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

  helptags ALL
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
  let names = ['buffer', 'environment', 'file_in_path',
	\ 'mapping', 'shellcmd', 'tag', 'tag_listfiles', 'user']
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

  call assert_fails('call getcompletion("", "burp")', 'E475:')
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

  set incsearch
  call feedkeys("fy:aaa veryl\<C-R>\<C-W> bbb\<C-B>\"\<CR>", 'tx')
  call assert_equal('"aaa verylongword bbb', @:)

  call feedkeys("f;:aaa \<C-R>\<C-A> bbb\<C-B>\"\<CR>", 'tx')
  call assert_equal('"aaa a;b-c*d bbb', @:)

  call feedkeys(":\<C-\>etoupper(getline(1))\<CR>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"ASDF.X /TMP/SOME VERYLONGWORD A;B-C*D ', @:)
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

set cpo&
