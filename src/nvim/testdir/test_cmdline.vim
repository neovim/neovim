" Tests for editing the command line.

func Test_complete_tab()
  call writefile(['testfile'], 'Xtestfile')
  call feedkeys(":e Xtest\t\r", "tx")
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
  call feedkeys(":e Xtest\t\t\r", "tx")
  call assert_equal('testfile2', getline(1))

  call delete('Xtestfile1')
  call delete('Xtestfile2')
  set nowildmenu
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
  call assert_true(index(l, 'sautest/') >= 0)
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
  call assert_equal('find a/b/fileXname', getreg(':'))
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
  bwipe!
endfunc

func Test_illegal_address()
  new
  2;'(
  2;')
  quit
endfunc
