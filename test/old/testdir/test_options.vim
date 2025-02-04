" Test for options

source shared.vim
source check.vim
source view_util.vim

scriptencoding utf-8

func Test_whichwrap()
  set whichwrap=b,s
  call assert_equal('b,s', &whichwrap)

  set whichwrap+=h,l
  call assert_equal('b,s,h,l', &whichwrap)

  set whichwrap+=h,l
  call assert_equal('b,s,h,l', &whichwrap)

  set whichwrap+=h,l
  call assert_equal('b,s,h,l', &whichwrap)

  set whichwrap=h,h
  call assert_equal('h', &whichwrap)

  set whichwrap=h,h,h
  call assert_equal('h', &whichwrap)

  " " For compatibility with Vim 3.0 and before, number values are also
  " " supported for 'whichwrap'
  " set whichwrap=1
  " call assert_equal('b', &whichwrap)
  " set whichwrap=2
  " call assert_equal('s', &whichwrap)
  " set whichwrap=4
  " call assert_equal('h,l', &whichwrap)
  " set whichwrap=8
  " call assert_equal('<,>', &whichwrap)
  " set whichwrap=16
  " call assert_equal('[,]', &whichwrap)
  " set whichwrap=31
  " call assert_equal('b,s,h,l,<,>,[,]', &whichwrap)

  set whichwrap&
endfunc

func Test_isfname()
  " This used to cause Vim to access uninitialized memory.
  set isfname=
  call assert_equal("~X", expand("~X"))
  set isfname&
  " Test for setting 'isfname' to an unsupported character
  let save_isfname = &isfname
  call assert_fails('exe $"set isfname+={"\u1234"}"', 'E474:')
  call assert_equal(save_isfname, &isfname)
endfunc

" Test for getting the value of 'pastetoggle'
func Test_pastetoggle()
  throw "Skipped: 'pastetoggle' is removed from Nvim"
  " character with K_SPECIAL byte
  let &pastetoggle = '…'
  call assert_equal('…', &pastetoggle)
  call assert_equal("\n  pastetoggle=…", execute('set pastetoggle?'))

  " modified character with K_SPECIAL byte
  let &pastetoggle = '<M-…>'
  call assert_equal('<M-…>', &pastetoggle)
  call assert_equal("\n  pastetoggle=<M-…>", execute('set pastetoggle?'))

  " illegal bytes
  let str = ":\x7f:\x80:\x90:\xd0:"
  let &pastetoggle = str
  call assert_equal(str, &pastetoggle)
  call assert_equal("\n  pastetoggle=" .. strtrans(str), execute('set pastetoggle?'))

  unlet str
  set pastetoggle&
endfunc

func Test_wildchar()
  " Empty 'wildchar' used to access invalid memory.
  call assert_fails('set wildchar=', 'E521:')
  call assert_fails('set wildchar=abc', 'E521:')
  set wildchar=<Esc>
  let a=execute('set wildchar?')
  call assert_equal("\n  wildchar=<Esc>", a)
  set wildchar=27
  let a=execute('set wildchar?')
  call assert_equal("\n  wildchar=<Esc>", a)
  set wildchar&
endfunc

func Test_wildoptions()
  set wildoptions=
  set wildoptions+=tagfile
  set wildoptions+=tagfile
  call assert_equal('tagfile', &wildoptions)
endfunc

func Test_options_command()
  let caught = 'ok'
  try
    options
  catch
    let caught = v:throwpoint . "\n" . v:exception
  endtry
  call assert_equal('ok', caught)

  " Check if the option-window is opened horizontally.
  wincmd j
  call assert_notequal('option-window', bufname(''))
  wincmd k
  call assert_equal('option-window', bufname(''))
  " close option-window
  close

  " Open the option-window vertically.
  vert options
  " Check if the option-window is opened vertically.
  wincmd l
  call assert_notequal('option-window', bufname(''))
  wincmd h
  call assert_equal('option-window', bufname(''))
  " close option-window
  close

  " Open the option-window at the top.
  set splitbelow
  topleft options
  call assert_equal(1, winnr())
  close

  " Open the option-window at the bottom.
  set nosplitbelow
  botright options
  call assert_equal(winnr('$'), winnr())
  close
  set splitbelow&

  " Open the option-window in a new tab.
  tab options
  " Check if the option-window is opened in a tab.
  normal gT
  call assert_notequal('option-window', bufname(''))
  normal gt
  call assert_equal('option-window', bufname(''))
  " close option-window
  close

  " Open the options window browse
  if has('browse')
    browse set
    call assert_equal('option-window', bufname(''))
    close
  endif
endfunc

func Test_path_keep_commas()
  " Test that changing 'path' keeps two commas.
  set path=foo,,bar
  set path-=bar
  set path+=bar
  call assert_equal('foo,,bar', &path)

  set path&
endfunc

func Test_path_too_long()
  exe 'set path=' .. repeat('x', 10000)
  call assert_fails('find x', 'E854:')
  set path&
endfunc

func Test_signcolumn()
  CheckFeature signs
  call assert_equal("auto", &signcolumn)
  set signcolumn=yes
  set signcolumn=no
  call assert_fails('set signcolumn=nope')
endfunc

func Test_filetype_valid()
  set ft=valid_name
  call assert_equal("valid_name", &filetype)
  set ft=valid-name
  call assert_equal("valid-name", &filetype)

  call assert_fails(":set ft=wrong;name", "E474:")
  call assert_fails(":set ft=wrong\\\\name", "E474:")
  call assert_fails(":set ft=wrong\\|name", "E474:")
  call assert_fails(":set ft=wrong/name", "E474:")
  call assert_fails(":set ft=wrong\\\nname", "E474:")
  call assert_equal("valid-name", &filetype)

  exe "set ft=trunc\x00name"
  call assert_equal("trunc", &filetype)
endfunc

func Test_syntax_valid()
  if !has('syntax')
    return
  endif
  set syn=valid_name
  call assert_equal("valid_name", &syntax)
  set syn=valid-name
  call assert_equal("valid-name", &syntax)

  call assert_fails(":set syn=wrong;name", "E474:")
  call assert_fails(":set syn=wrong\\\\name", "E474:")
  call assert_fails(":set syn=wrong\\|name", "E474:")
  call assert_fails(":set syn=wrong/name", "E474:")
  call assert_fails(":set syn=wrong\\\nname", "E474:")
  call assert_equal("valid-name", &syntax)

  exe "set syn=trunc\x00name"
  call assert_equal("trunc", &syntax)
endfunc

func Test_keymap_valid()
  if !has('keymap')
    return
  endif
  call assert_fails(":set kmp=valid_name", "E544:")
  call assert_fails(":set kmp=valid_name", "valid_name")
  call assert_fails(":set kmp=valid-name", "E544:")
  call assert_fails(":set kmp=valid-name", "valid-name")

  call assert_fails(":set kmp=wrong;name", "E474:")
  call assert_fails(":set kmp=wrong\\\\name", "E474:")
  call assert_fails(":set kmp=wrong\\|name", "E474:")
  call assert_fails(":set kmp=wrong/name", "E474:")
  call assert_fails(":set kmp=wrong\\\nname", "E474:")

  call assert_fails(":set kmp=trunc\x00name", "E544:")
  call assert_fails(":set kmp=trunc\x00name", "trunc")
endfunc

func Test_wildchar_valid()
  call assert_fails("set wildchar=<CR>", "E474:")
  call assert_fails("set wildcharm=<C-C>", "E474:")
endfunc

func Check_dir_option(name)
  " Check that it's possible to set the option.
  exe 'set ' . a:name . '=/usr/share/dict/words'
  call assert_equal('/usr/share/dict/words', eval('&' . a:name))
  exe 'set ' . a:name . '=/usr/share/dict/words,/and/there'
  call assert_equal('/usr/share/dict/words,/and/there', eval('&' . a:name))
  exe 'set ' . a:name . '=/usr/share/dict\ words'
  call assert_equal('/usr/share/dict words', eval('&' . a:name))

  " Check rejecting weird characters.
  call assert_fails("set " . a:name . "=/not&there", "E474:")
  call assert_fails("set " . a:name . "=/not>there", "E474:")
  call assert_fails("set " . a:name . "=/not.*there", "E474:")
endfunc

func Test_cinkeys()
  " This used to cause invalid memory access
  set cindent cinkeys=0
  norm a
  set cindent& cinkeys&
endfunc

func Test_dictionary()
  call Check_dir_option('dictionary')
endfunc

func Test_thesaurus()
  call Check_dir_option('thesaurus')
endfun

func Test_complete()
  " Trailing single backslash used to cause invalid memory access.
  set complete=s\
  new
  call feedkeys("i\<C-N>\<Esc>", 'xt')
  bwipe!
  call assert_fails('set complete=ix', 'E535:')
  set complete&
endfun

func Test_set_completion()
  call feedkeys(":set di\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set dictionary diff diffexpr diffopt digraph directory display', @:)

  call feedkeys(":setlocal di\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"setlocal dictionary diff diffexpr diffopt digraph directory display', @:)

  call feedkeys(":setglobal di\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"setglobal dictionary diff diffexpr diffopt digraph directory display', @:)

  " Expand boolean options. When doing :set no<Tab> Vim prefixes the option
  " names with "no".
  call feedkeys(":set nodi\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set nodiff nodigraph', @:)

  call feedkeys(":set invdi\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set invdiff invdigraph', @:)

  " Expanding "set noinv" does nothing.
  call feedkeys(":set noinv\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set noinv', @:)

  " Expand abbreviation of options.
  call feedkeys(":set ts\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set tabstop thesaurus thesaurusfunc', @:)

  " Expand current value
  call feedkeys(":set suffixes=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set suffixes=.bak,~,.o,.h,.info,.swp,.obj', @:)

  call feedkeys(":set suffixes:\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set suffixes:.bak,~,.o,.h,.info,.swp,.obj', @:)

  " Expand key codes.
  " call feedkeys(":set <H\<C-A>\<C-B>\"\<CR>", 'tx')
  " call assert_equal('"set <Help> <Home>', @:)

  " Expand terminal options.
  " call feedkeys(":set t_A\<C-A>\<C-B>\"\<CR>", 'tx')
  " call assert_equal('"set t_AB t_AF t_AU t_AL', @:)
  " call assert_fails('call feedkeys(":set <t_afoo>=\<C-A>\<CR>", "xt")', 'E474:')

  " Expand directories.
  call feedkeys(":set cdpath=./\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match(' ./samples/ ', @:)
  call assert_notmatch(' ./summarize.vim ', @:)
  set cdpath&

  " Expand files and directories.
  call feedkeys(":set tags=./\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match(' ./samples/.* ./summarize.vim', @:)

  call feedkeys(":set tags=./\\\\ dif\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set tags=./\\ diff diffexpr diffopt', @:)

  " Expand files with spaces/commas in them. Make sure we delimit correctly.
  "
  " 'tags' allow for for spaces/commas to both act as delimiters, with actual
  " spaces requiring double escape, and commas need a single escape.
  " 'dictionary' is a normal comma-separated option where only commas act as
  " delimiters, and both space/comma need one single escape.
  " 'makeprg' is a non-comma-separated option. Commas don't need escape.
  defer delete('Xfoo Xspace.txt')
  defer delete('Xsp_dummy')
  defer delete('Xbar,Xcomma.txt')
  defer delete('Xcom_dummy')
  call writefile([], 'Xfoo Xspace.txt')
  call writefile([], 'Xsp_dummy')
  call writefile([], 'Xbar,Xcomma.txt')
  call writefile([], 'Xcom_dummy')

  call feedkeys(':set tags=./Xfoo\ Xsp' .. "\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set tags=./Xfoo\ Xsp_dummy', @:)
  call feedkeys(':set tags=./Xfoo\\\ Xsp' .. "\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set tags=./Xfoo\\\ Xspace.txt', @:)
  call feedkeys(':set dictionary=./Xfoo\ Xsp' .. "\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set dictionary=./Xfoo\ Xspace.txt', @:)

  call feedkeys(':set dictionary=./Xbar,Xcom' .. "\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set dictionary=./Xbar,Xcom_dummy', @:)
  if has('win32')
    " In Windows, '\,' is literal, see `:help filename-backslash`, so this
    " means we treat it as one file name.
    call feedkeys(':set dictionary=Xbar\,Xcom' .. "\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"set dictionary=Xbar\,Xcomma.txt', @:)
  else
    " In other platforms, '\,' simply escape to ',', and indicate a delimiter
    " to split into a separate file name. You need '\\,' to escape the comma
    " as part of the file name.
    call feedkeys(':set dictionary=Xbar\,Xcom' .. "\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"set dictionary=Xbar\,Xcom_dummy', @:)

    call feedkeys(':set dictionary=Xbar\\,Xcom' .. "\<C-A>\<C-B>\"\<CR>", 'tx')
    call assert_equal('"set dictionary=Xbar\\,Xcomma.txt', @:)
  endif
  call feedkeys(":set makeprg=./Xbar,Xcom\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set makeprg=./Xbar,Xcomma.txt', @:)
  set tags& dictionary& makeprg&

  " Expanding the option names
  call feedkeys(":set \<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set all', @:)

  " Expanding a second set of option names
  call feedkeys(":set wrapscan \<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set wrapscan all', @:)

  " Expanding a special keycode
  " call feedkeys(":set <Home>\<Tab>\<C-B>\"\<CR>", 'xt')
  " call assert_equal('"set <Home>', @:)

  " Expanding an invalid special keycode
  call feedkeys(":set <abcd>\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"set <abcd>\<Tab>", @:)

  " Expanding a terminal keycode
  " call feedkeys(":set t_AB\<Tab>\<C-B>\"\<CR>", 'xt')
  " call assert_equal("\"set t_AB", @:)

  " Expanding an invalid option name
  call feedkeys(":set abcde=\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"set abcde=\<Tab>", @:)

  " Expanding after a = for a boolean option
  call feedkeys(":set wrapscan=\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"set wrapscan=\<Tab>", @:)

  " Expanding a numeric option
  call feedkeys(":set tabstop+=\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"set tabstop+=" .. &tabstop, @:)

  " Expanding a non-boolean option
  call feedkeys(":set invtabstop=\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"set invtabstop=", @:)

  " Expand options for 'spellsuggest'
  call feedkeys(":set spellsuggest=file:test_options.v\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"set spellsuggest=file:test_options.vim", @:)
  call feedkeys(":set spellsuggest=best,file:test_options.v\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"set spellsuggest=best,file:test_options.vim", @:)

  " Expanding value for 'key' is disallowed
  if exists('+key')
    set key=abcd
    call feedkeys(":set key=\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set key=', @:)
    call feedkeys(":set key-=\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set key-=', @:)
    set key=
  endif

  " Expand values for 'filetype'
  call feedkeys(":set filetype=sshdconfi\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set filetype=sshdconfig', @:)
  call feedkeys(":set filetype=a\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set filetype=' .. getcompletion('a*', 'filetype')->join(), @:)

  " Expand values for 'syntax'
  call feedkeys(":set syntax=sshdconfi\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set syntax=sshdconfig', @:)
  call feedkeys(":set syntax=a\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set syntax=' .. getcompletion('a*', 'syntax')->join(), @:)

  if has('keymap')
    " Expand values for 'keymap'
    call feedkeys(":set keymap=acc\<Tab>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set keymap=accents', @:)
    call feedkeys(":set keymap=a\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"set keymap=' .. getcompletion('a*', 'keymap')->join(), @:)
  endif
endfunc

" Test handling of expanding individual string option values
func Test_set_completion_string_values()
  "
  " Test basic enum string options that have well-defined enum names
  "

  " call assert_equal(['lastline', 'truncate', 'uhex'], getcompletion('set display=', 'cmdline'))
  call assert_equal(['lastline', 'truncate', 'uhex', 'msgsep'], getcompletion('set display=', 'cmdline'))
  call assert_equal(['truncate'], getcompletion('set display=t', 'cmdline'))
  call assert_equal(['uhex'], getcompletion('set display=*ex*', 'cmdline'))

  " Test that if a value is set, it will populate the results, but only if
  " typed value is empty.
  set display=uhex,lastline
  " call assert_equal(['uhex,lastline', 'lastline', 'truncate', 'uhex'], getcompletion('set display=', 'cmdline'))
  call assert_equal(['uhex,lastline', 'lastline', 'truncate', 'uhex', 'msgsep'], getcompletion('set display=', 'cmdline'))
  call assert_equal(['uhex'], getcompletion('set display=u', 'cmdline'))
  " If the set value is part of the enum list, it will show as the first
  " result with no duplicate.
  set display=uhex
  " call assert_equal(['uhex', 'lastline', 'truncate'], getcompletion('set display=', 'cmdline'))
  call assert_equal(['uhex', 'lastline', 'truncate', 'msgsep'], getcompletion('set display=', 'cmdline'))
  " If empty value, will just show the normal list without an empty item
  set display=
  " call assert_equal(['lastline', 'truncate', 'uhex'], getcompletion('set display=', 'cmdline'))
  call assert_equal(['lastline', 'truncate', 'uhex', 'msgsep'], getcompletion('set display=', 'cmdline'))
  " Test escaping of the values
  " call assert_equal('vert:\|,fold:-,eob:~,lastline:@', getcompletion('set fillchars=', 'cmdline')[0])
  call assert_equal('vert:\|,foldsep:\|,fold:-', getcompletion('set fillchars=', 'cmdline')[0])

  " Test comma-separated lists will expand after a comma.
  call assert_equal(['uhex'], getcompletion('set display=truncate,*ex*', 'cmdline'))
  " Also test the positioning of the expansion is correct
  call feedkeys(":set display=truncate,l\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set display=truncate,lastline', @:)
  set display&

  " Test single-value options will not expand after a comma
  call assert_equal([], getcompletion('set ambw=single,', 'cmdline'))

  " Test the other simple options to make sure they have basic auto-complete,
  " but don't exhaustively validate their results.
  call assert_equal('single', getcompletion('set ambw=', 'cmdline')[0])
  call assert_match('light\|dark', getcompletion('set bg=', 'cmdline')[1])
  call assert_equal('indent,eol,start', getcompletion('set backspace=', 'cmdline')[0])
  call assert_equal('yes', getcompletion('set backupcopy=', 'cmdline')[1])
  call assert_equal('backspace', getcompletion('set belloff=', 'cmdline')[1])
  call assert_equal('min:', getcompletion('set briopt=', 'cmdline')[1])
  if exists('+browsedir')
    call assert_equal('current', getcompletion('set browsedir=', 'cmdline')[1])
  endif
  call assert_equal('unload', getcompletion('set bufhidden=', 'cmdline')[1])
  "call assert_equal('nowrite', getcompletion('set buftype=', 'cmdline')[1])
  call assert_equal('help', getcompletion('set buftype=', 'cmdline')[1])
  call assert_equal('internal', getcompletion('set casemap=', 'cmdline')[1])
  if exists('+clipboard')
    " call assert_match('unnamed', getcompletion('set clipboard=', 'cmdline')[1])
    call assert_match('unnamed', getcompletion('set clipboard=', 'cmdline')[0])
  endif
  call assert_equal('.', getcompletion('set complete=', 'cmdline')[1])
  call assert_equal('menu', getcompletion('set completeopt=', 'cmdline')[1])
  if exists('+completeslash')
    call assert_equal('backslash', getcompletion('set completeslash=', 'cmdline')[1])
  endif
  if exists('+cryptmethod')
    call assert_equal('zip', getcompletion('set cryptmethod=', 'cmdline')[1])
  endif
  if exists('+cursorlineopt')
    call assert_equal('line', getcompletion('set cursorlineopt=', 'cmdline')[1])
  endif
  call assert_equal('throw', getcompletion('set debug=', 'cmdline')[1])
  call assert_equal('ver', getcompletion('set eadirection=', 'cmdline')[1])
  call assert_equal('mac', getcompletion('set fileformat=', 'cmdline')[2])
  if exists('+foldclose')
    call assert_equal('all', getcompletion('set foldclose=', 'cmdline')[0])
  endif
  if exists('+foldmethod')
    call assert_equal('expr', getcompletion('set foldmethod=', 'cmdline')[1])
  endif
  if exists('+foldopen')
    call assert_equal('all', getcompletion('set foldopen=', 'cmdline')[1])
  endif
  call assert_equal('stack', getcompletion('set jumpoptions=', 'cmdline')[0])
  call assert_equal('stopsel', getcompletion('set keymodel=', 'cmdline')[1])
  call assert_equal('expr:1', getcompletion('set lispoptions=', 'cmdline')[1])
  call assert_match('popup', getcompletion('set mousemodel=', 'cmdline')[2])
  call assert_equal('bin', getcompletion('set nrformats=', 'cmdline')[1])
  if exists('+rightleftcmd')
    call assert_equal('search', getcompletion('set rightleftcmd=', 'cmdline')[0])
  endif
  call assert_equal('ver', getcompletion('set scrollopt=', 'cmdline')[1])
  call assert_equal('exclusive', getcompletion('set selection=', 'cmdline')[1])
  call assert_equal('key', getcompletion('set selectmode=', 'cmdline')[1])
  if exists('+ssop')
    call assert_equal('buffers', getcompletion('set ssop=', 'cmdline')[1])
  endif
  call assert_equal('statusline', getcompletion('set showcmdloc=', 'cmdline')[1])
  if exists('+signcolumn')
    call assert_equal('yes', getcompletion('set signcolumn=', 'cmdline')[1])
  endif
  if exists('+spelloptions')
    call assert_equal('camel', getcompletion('set spelloptions=', 'cmdline')[0])
  endif
  if exists('+spellsuggest')
    call assert_equal('best', getcompletion('set spellsuggest+=', 'cmdline')[0])
  endif
  call assert_equal('screen', getcompletion('set splitkeep=', 'cmdline')[1])
  " call assert_equal('sync', getcompletion('set swapsync=', 'cmdline')[1])
  call assert_equal('usetab', getcompletion('set switchbuf=', 'cmdline')[1])
  call assert_equal('ignore', getcompletion('set tagcase=', 'cmdline')[1])
  if exists('+tabclose')
    call assert_equal('left uselast', join(sort(getcompletion('set tabclose=', 'cmdline'))), ' ')
  endif
  if exists('+termwintype')
    call assert_equal('conpty', getcompletion('set termwintype=', 'cmdline')[1])
  endif
  if exists('+toolbar')
    call assert_equal('text', getcompletion('set toolbar=', 'cmdline')[1])
  endif
  if exists('+tbis')
    call assert_equal('medium', getcompletion('set tbis=', 'cmdline')[2])
  endif
  if exists('+ttymouse')
    set ttymouse=
    call assert_equal('xterm2', getcompletion('set ttymouse=', 'cmdline')[1])
    set ttymouse&
  endif
  call assert_equal('insert', getcompletion('set virtualedit=', 'cmdline')[1])
  call assert_equal('longest', getcompletion('set wildmode=', 'cmdline')[1])
  call assert_equal('full', getcompletion('set wildmode=list,longest:', 'cmdline')[0])
  call assert_equal('tagfile', getcompletion('set wildoptions=', 'cmdline')[1])
  if exists('+winaltkeys')
    call assert_equal('yes', getcompletion('set winaltkeys=', 'cmdline')[1])
  endif

  " Other string options that queries the system rather than fixed enum names
  call assert_equal(['all', 'BufAdd'], getcompletion('set eventignore=', 'cmdline')[0:1])
  call assert_equal('latin1', getcompletion('set fileencodings=', 'cmdline')[1])
  " call assert_equal('top', getcompletion('set printoptions=', 'cmdline')[0])
  " call assert_equal('SpecialKey', getcompletion('set wincolor=', 'cmdline')[0])

  call assert_equal('eol', getcompletion('set listchars+=', 'cmdline')[0])
  call assert_equal(['multispace', 'leadmultispace'], getcompletion('set listchars+=', 'cmdline')[-2:])
  call assert_equal('eol', getcompletion('setl listchars+=', 'cmdline')[0])
  call assert_equal(['multispace', 'leadmultispace'], getcompletion('setl listchars+=', 'cmdline')[-2:])
  call assert_equal('stl', getcompletion('set fillchars+=', 'cmdline')[0])
  call assert_equal('stl', getcompletion('setl fillchars+=', 'cmdline')[0])

  "
  " Unique string options below
  "

  " keyprotocol: only auto-complete when after ':' with known protocol types
  " call assert_equal([&keyprotocol], getcompletion('set keyprotocol=', 'cmdline'))
  " call feedkeys(":set keyprotocol+=someterm:m\<Tab>\<C-B>\"\<CR>", 'xt')
  " call assert_equal('"set keyprotocol+=someterm:mok2', @:)
  " set keyprotocol&

  " previewpopup / completepopup
  " call assert_equal('height:', getcompletion('set previewpopup=', 'cmdline')[0])
  " call assert_equal('EndOfBuffer', getcompletion('set previewpopup=highlight:End*Buffer', 'cmdline')[0])
  " call feedkeys(":set previewpopup+=border:\<Tab>\<C-B>\"\<CR>", 'xt')
  " call assert_equal('"set previewpopup+=border:on', @:)
  " call feedkeys(":set completepopup=height:10,align:\<Tab>\<C-B>\"\<CR>", 'xt')
  " call assert_equal('"set completepopup=height:10,align:item', @:)
  " call assert_equal([], getcompletion('set completepopup=bogusname:', 'cmdline'))
  " set previewpopup& completepopup&

  " diffopt: special handling of algorithm:<alg_list>
  call assert_equal('filler', getcompletion('set diffopt+=', 'cmdline')[0])
  call assert_equal([], getcompletion('set diffopt+=iblank,foldcolumn:', 'cmdline'))
  call assert_equal('patience', getcompletion('set diffopt+=iblank,algorithm:pat*', 'cmdline')[0])

  " highlight: special parsing, including auto-completing highlight groups
  " after ':'
  " call assert_equal([&hl, '8'], getcompletion('set hl=', 'cmdline')[0:1])
  " call assert_equal('8', getcompletion('set hl+=', 'cmdline')[0])
  " call assert_equal(['8:', '8b', '8i'], getcompletion('set hl+=8', 'cmdline')[0:2])
  " call assert_equal('8bi', getcompletion('set hl+=8b', 'cmdline')[0])
  " call assert_equal('NonText', getcompletion('set hl+=8:No*ext', 'cmdline')[0])
  " If all the display modes are used up we should be suggesting nothing. Make
  " a hl typed option with all the modes which will look like '8bi-nrsuc2d=t',
  " and make sure nothing is suggested from that.
  " let hl_display_modes = join(
  "       \ filter(map(getcompletion('set hl+=8', 'cmdline'),
  "       \            {idx, val -> val[1]}),
  "       \        {idx, val -> val != ':'}),
  "       \ '')
  " call assert_equal([], getcompletion('set hl+=8'..hl_display_modes, 'cmdline'))
  " Test completion in middle of the line
  " call feedkeys(":set hl=8b i\<Left>\<Left>\<Tab>\<C-B>\"\<CR>", 'xt')
  " call assert_equal("\"set hl=8bi i", @:)

  " messagesopt
  call assert_equal(['history:', 'hit-enter', 'wait:'],
        \ getcompletion('set messagesopt+=', 'cmdline')->sort())

  "
  " Test flag lists
  "

  " Test set=. Show the original value if nothing is typed after '='.
  " Otherwise, the list should avoid showing what's already typed.
  set mouse=v
  call assert_equal(['v','a','n','i','c','h','r'], getcompletion('set mouse=', 'cmdline'))
  set mouse=nvi
  call assert_equal(['nvi','a','n','v','i','c','h','r'], getcompletion('set mouse=', 'cmdline'))
  call assert_equal(['a','v','i','c','r'], getcompletion('set mouse=hn', 'cmdline'))

  " Test set+=. Never show original value, and it also tries to avoid listing
  " flags that's already in the option value.
  call assert_equal(['a','c','h','r'], getcompletion('set mouse+=', 'cmdline'))
  call assert_equal(['a','c','r'], getcompletion('set mouse+=hn', 'cmdline'))
  call assert_equal([], getcompletion('set mouse+=acrhn', 'cmdline'))

  " Test that the position of the expansion is correct (even if there are
  " additional values after the current cursor)
  call feedkeys(":set mouse=hn\<Left>\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set mouse=han', @:)
  set mouse&

  " Test that other flag list options have auto-complete, but don't
  " exhaustively validate their results.
  if exists('+concealcursor')
    call assert_equal('n', getcompletion('set cocu=', 'cmdline')[0])
  endif
  call assert_equal('a', getcompletion('set cpo=', 'cmdline')[1])
  call assert_equal('t', getcompletion('set fo=', 'cmdline')[1])
  if exists('+guioptions')
    call assert_equal('!', getcompletion('set go=', 'cmdline')[1])
  endif
  call assert_equal('r', getcompletion('set shortmess=', 'cmdline')[1])
  call assert_equal('b', getcompletion('set whichwrap=', 'cmdline')[1])

  "
  "Test set-=
  "

  " Normal single-value option just shows the existing value
  set ambiwidth=double
  call assert_equal(['double'], getcompletion('set ambw-=', 'cmdline'))
  set ambiwidth&

  " Works on numbers and term options as well
  call assert_equal([string(&laststatus)], getcompletion('set laststatus-=', 'cmdline'))
  set t_Ce=testCe
  " call assert_equal(['testCe'], getcompletion('set t_Ce-=', 'cmdline'))
  set t_Ce&

  " Comma-separated lists should present each option
  set diffopt=context:123,,,,,iblank,iwhiteall
  call assert_equal(['context:123', 'iblank', 'iwhiteall'], getcompletion('set diffopt-=', 'cmdline'))
  call assert_equal(['context:123', 'iblank'], getcompletion('set diffopt-=*n*', 'cmdline'))
  call assert_equal(['iblank', 'iwhiteall'], getcompletion('set diffopt-=i', 'cmdline'))
  " Don't present more than one option as it doesn't make sense in set-=
  call assert_equal([], getcompletion('set diffopt-=iblank,', 'cmdline'))
  " Test empty option
  set diffopt=
  call assert_equal([], getcompletion('set diffopt-=', 'cmdline'))
  " Test all possible values
  call assert_equal(['filler', 'context:', 'iblank', 'icase', 'iwhite', 'iwhiteall', 'iwhiteeol', 'horizontal',
        \ 'vertical', 'closeoff', 'hiddenoff', 'foldcolumn:', 'followwrap', 'internal', 'indent-heuristic', 'algorithm:', 'linematch:'],
        \ getcompletion('set diffopt=', 'cmdline'))
  set diffopt&

  " Test escaping output
  call assert_equal('vert:\|', getcompletion('set fillchars-=', 'cmdline')[0])

  " Test files with commas in name are being parsed and escaped properly
  set path=has\\\ space,file\\,with\\,comma,normal_file
  if exists('+completeslash')
    call assert_equal(['has\\\ space', 'file\,with\,comma', 'normal_file'], getcompletion('set path-=', 'cmdline'))
  else
    call assert_equal(['has\\\ space', 'file\\,with\\,comma', 'normal_file'], getcompletion('set path-=', 'cmdline'))
  endif
  set path&

  " Flag list should present orig value, then individual flags
  set mouse=v
  call assert_equal(['v'], getcompletion('set mouse-=', 'cmdline'))
  set mouse=avn
  call assert_equal(['avn','a','v','n'], getcompletion('set mouse-=', 'cmdline'))
  " Don't auto-complete when we have at least one flags already
  call assert_equal([], getcompletion('set mouse-=n', 'cmdline'))
  " Test empty option
  set mouse=
  call assert_equal([], getcompletion('set mouse-=', 'cmdline'))
  set mouse&

  " 'whichwrap' is an odd case where it's both flag list and comma-separated
  set ww=b,h
  call assert_equal(['b','h'], getcompletion('set ww-=', 'cmdline'))
  set ww&
endfunc

func Test_set_option_errors()
  call assert_fails('set scroll=-1', 'E49:')
  call assert_fails('set backupcopy=', 'E474:')
  call assert_fails('set regexpengine=3', 'E474:')
  call assert_fails('set history=10001', 'E474:')
  call assert_fails('set numberwidth=21', 'E474:')
  call assert_fails('set colorcolumn=-a', 'E474:')
  call assert_fails('set colorcolumn=a', 'E474:')
  call assert_fails('set colorcolumn=1,', 'E474:')
  call assert_fails('set colorcolumn=1;', 'E474:')
  call assert_fails('set cmdheight=-1', 'E487:')
  call assert_fails('set cmdwinheight=-1', 'E487:')
  if has('conceal')
    call assert_fails('set conceallevel=-1', 'E487:')
    call assert_fails('set conceallevel=4', 'E474:')
  endif
  call assert_fails('set helpheight=-1', 'E487:')
  call assert_fails('set history=-1', 'E487:')
  call assert_fails('set report=-1', 'E487:')
  call assert_fails('set shiftwidth=-1', 'E487:')
  call assert_fails('set sidescroll=-1', 'E487:')
  call assert_fails('set tabstop=-1', 'E487:')
  call assert_fails('set tabstop=10000', 'E474:')
  call assert_fails('let &tabstop = 10000', 'E474:')
  call assert_fails('set tabstop=5500000000', 'E474:')
  call assert_fails('set textwidth=-1', 'E487:')
  call assert_fails('set timeoutlen=-1', 'E487:')
  call assert_fails('set updatecount=-1', 'E487:')
  call assert_fails('set updatetime=-1', 'E487:')
  call assert_fails('set winheight=-1', 'E487:')
  call assert_fails('set tabstop!', 'E488:')

  " Test for setting unknown option errors
  call assert_fails('set xxx', 'E518:')
  call assert_fails('setlocal xxx', 'E518:')
  call assert_fails('setglobal xxx', 'E518:')
  call assert_fails('set xxx=', 'E518:')
  call assert_fails('setlocal xxx=', 'E518:')
  call assert_fails('setglobal xxx=', 'E518:')
  call assert_fails('set xxx:', 'E518:')
  call assert_fails('setlocal xxx:', 'E518:')
  call assert_fails('setglobal xxx:', 'E518:')
  call assert_fails('set xxx!', 'E518:')
  call assert_fails('setlocal xxx!', 'E518:')
  call assert_fails('setglobal xxx!', 'E518:')
  call assert_fails('set xxx?', 'E518:')
  call assert_fails('setlocal xxx?', 'E518:')
  call assert_fails('setglobal xxx?', 'E518:')
  call assert_fails('set xxx&', 'E518:')
  call assert_fails('setlocal xxx&', 'E518:')
  call assert_fails('setglobal xxx&', 'E518:')
  call assert_fails('set xxx<', 'E518:')
  call assert_fails('setlocal xxx<', 'E518:')
  call assert_fails('setglobal xxx<', 'E518:')

  " Test for missing-options errors.
  " call assert_fails('set autoprint?', 'E519:')
  " call assert_fails('set beautify?', 'E519:')
  " call assert_fails('set flash?', 'E519:')
  " call assert_fails('set graphic?', 'E519:')
  " call assert_fails('set hardtabs?', 'E519:')
  " call assert_fails('set mesg?', 'E519:')
  " call assert_fails('set novice?', 'E519:')
  " call assert_fails('set open?', 'E519:')
  " call assert_fails('set optimize?', 'E519:')
  " call assert_fails('set redraw?', 'E519:')
  " call assert_fails('set slowopen?', 'E519:')
  " call assert_fails('set sourceany?', 'E519:')
  " call assert_fails('set w300?', 'E519:')
  " call assert_fails('set w1200?', 'E519:')
  " call assert_fails('set w9600?', 'E519:')

  call assert_fails('set undolevels=x', 'E521:')
  call assert_fails('set tabstop=', 'E521:')
  call assert_fails('set comments=-', 'E524:')
  call assert_fails('set comments=a', 'E525:')
  call assert_fails('set foldmarker=x', 'E536:')
  call assert_fails('set commentstring=x', 'E537:')
  call assert_fails('let &commentstring = "x"', 'E537:')
  call assert_fails('set complete=x', 'E539:')
  call assert_fails('set rulerformat=%-', 'E539:')
  call assert_fails('set rulerformat=%(', 'E542:')
  call assert_fails('set rulerformat=%15(%%', 'E542:')

  " Test for 'statusline' errors
  call assert_fails('set statusline=%$', 'E539:')
  call assert_fails('set statusline=%{', 'E540:')
  call assert_fails('set statusline=%{%', 'E540:')
  call assert_fails('set statusline=%{%}', 'E539:')
  call assert_fails('set statusline=%(', 'E542:')
  call assert_fails('set statusline=%)', 'E542:')

  " Test for 'tabline' errors
  call assert_fails('set tabline=%$', 'E539:')
  call assert_fails('set tabline=%{', 'E540:')
  call assert_fails('set tabline=%{%', 'E540:')
  call assert_fails('set tabline=%{%}', 'E539:')
  call assert_fails('set tabline=%(', 'E542:')
  call assert_fails('set tabline=%)', 'E542:')

  if has('cursorshape')
    " This invalid value for 'guicursor' used to cause Vim to crash.
    call assert_fails('set guicursor=i-ci,r-cr:h', 'E545:')
    call assert_fails('set guicursor=i-ci', 'E545:')
    call assert_fails('set guicursor=x', 'E545:')
    call assert_fails('set guicursor=x:', 'E546:')
    call assert_fails('set guicursor=r-cr:horx', 'E548:')
    call assert_fails('set guicursor=r-cr:hor0', 'E549:')
  endif

  if has('mouseshape')
    call assert_fails('se mouseshape=i-r:x', 'E547:')
  endif

  " Test for 'backupext' and 'patchmode' set to the same value
  set backupext=.bak
  set patchmode=.patch
  call assert_fails('set patchmode=.bak', 'E589:')
  call assert_equal('.patch', &patchmode)
  call assert_fails('set backupext=.patch', 'E589:')
  call assert_equal('.bak', &backupext)
  set backupext& patchmode&

  " 'winheight' cannot be smaller than 'winminheight'
  call assert_fails('set winminheight=10 winheight=9', 'E591:')
  set winminheight& winheight&
  set winheight=10 winminheight=10
  call assert_fails('set winheight=9', 'E591:')
  set winminheight& winheight&

  " 'winwidth' cannot be smaller than 'winminwidth'
  call assert_fails('set winminwidth=10 winwidth=9', 'E592:')
  set winminwidth& winwidth&
  call assert_fails('set winwidth=9 winminwidth=10', 'E592:')
  set winwidth& winminwidth&

  call assert_fails("set showbreak=\x01", 'E595:')
  " call assert_fails('set t_foo=', 'E846:')
  call assert_fails('set tabstop??', 'E488:')
  call assert_fails('set wrapscan!!', 'E488:')
  call assert_fails('set tabstop&&', 'E488:')
  call assert_fails('set wrapscan<<', 'E488:')
  call assert_fails('set wrapscan=1', 'E474:')
  call assert_fails('set autoindent@', 'E488:')
  call assert_fails('set wildchar=<abc>', 'E474:')
  call assert_fails('set cmdheight=1a', 'E521:')
  call assert_fails('set invcmdheight', 'E474:')
  if has('python') || has('python3')
    call assert_fails('set pyxversion=6', 'E474:')
  endif
  call assert_fails("let &tabstop='ab'", ['E521:', 'E521:'])
  call assert_fails('set spellcapcheck=%\\(', 'E54:')
  call assert_fails('set sessionoptions=curdir,sesdir', 'E474:')
  call assert_fails('set foldmarker={{{,', 'E474:')
  call assert_fails('set sessionoptions=sesdir,curdir', 'E474:')

  " 'ambiwidth' conflict 'listchars'
  setlocal listchars=trail:·
  call assert_fails('set ambiwidth=double', 'E834:')
  setlocal listchars=trail:-
  setglobal listchars=trail:·
  call assert_fails('set ambiwidth=double', 'E834:')
  set listchars&

  " 'ambiwidth' conflict 'fillchars'
  setlocal fillchars=stl:·
  call assert_fails('set ambiwidth=double', 'E835:')
  setlocal fillchars=stl:-
  setglobal fillchars=stl:·
  call assert_fails('set ambiwidth=double', 'E835:')
  set fillchars&

  call assert_fails('set fileencoding=latin1,utf-8', 'E474:')
  set nomodifiable
  call assert_fails('set fileencoding=latin1', 'E21:')
  set modifiable&
  " call assert_fails('set t_#-&', 'E522:')
  call assert_fails('let &formatoptions = "?"', 'E539:')
  call assert_fails('call setbufvar("", "&formatoptions", "?")', 'E539:')

  " Should raises only one error if passing a wrong variable type.
  call assert_fails('call setwinvar(0, "&scrolloff", [])', ['E745:', 'E745:'])
  call assert_fails('call setwinvar(0, "&list", [])', ['E745:', 'E745:'])
  call assert_fails('call setwinvar(0, "&listchars", [])', ['E730:', 'E730:'])
  call assert_fails('call setwinvar(0, "&nosuchoption", 0)', ['E355:', 'E355:'])
  call assert_fails('call setwinvar(0, "&nosuchoption", "")', ['E355:', 'E355:'])
  call assert_fails('call setwinvar(0, "&nosuchoption", [])', ['E355:', 'E355:'])
endfunc

func CheckWasSet(name)
  let verb_cm = execute('verbose set ' .. a:name .. '?')
  call assert_match('Last set from.*test_options.vim', verb_cm)
endfunc
func CheckWasNotSet(name)
  let verb_cm = execute('verbose set ' .. a:name .. '?')
  call assert_notmatch('Last set from', verb_cm)
endfunc

" Must be executed before other tests that set 'term'.
func Test_000_term_option_verbose()
  throw "Skipped: Nvim does not support setting 'term'"
  CheckNotGui

  call CheckWasNotSet('t_cm')

  let term_save = &term
  set term=ansi
  call CheckWasSet('t_cm')
  let &term = term_save
endfunc

func Test_copy_context()
  setlocal list
  call CheckWasSet('list')
  split
  call CheckWasSet('list')
  quit
  setlocal nolist

  set ai
  call CheckWasSet('ai')
  set filetype=perl
  call CheckWasSet('filetype')
  set fo=tcroq
  call CheckWasSet('fo')

  split Xsomebuf
  call CheckWasSet('ai')
  call CheckWasNotSet('filetype')
  call CheckWasSet('fo')
endfunc

func Test_set_ttytype()
  throw "Skipped: Nvim does not support 'ttytype'"
  CheckUnix
  CheckNotGui

  " Setting 'ttytype' used to cause a double-free when exiting vim and
  " when vim is compiled with -DEXITFREE.
  set ttytype=ansi
  call assert_equal('ansi', &ttytype)
  call assert_equal(&ttytype, &term)
  set ttytype=xterm
  call assert_equal('xterm', &ttytype)
  call assert_equal(&ttytype, &term)
  try
    set ttytype=
    call assert_report('set ttytype= did not fail')
  catch /E529/
  endtry

  " Some systems accept any terminal name and return dumb settings,
  " check for failure of finding the entry and for missing 'cm' entry.
  try
    set ttytype=xxx
    call assert_report('set ttytype=xxx did not fail')
  catch /E522\|E437/
  endtry

  set ttytype&
  call assert_equal(&ttytype, &term)

  if has('gui') && !has('gui_running')
    call assert_fails('set term=gui', 'E531:')
  endif
endfunc

" Test for :set all
func Test_set_all()
  set tw=75
  set iskeyword=a-z,A-Z
  set nosplitbelow
  let out = execute('set all')
  call assert_match('textwidth=75', out)
  call assert_match('iskeyword=a-z,A-Z', out)
  call assert_match('nosplitbelow', out)
  set tw& iskeyword& splitbelow&
endfunc

" Test for :set! all
func Test_set_all_one_column()
  let out_mult = execute('set all')->split("\n")
  let out_one = execute('set! all')->split("\n")
  call assert_true(len(out_mult) < len(out_one))
  call assert_equal(out_one[0], '--- Options ---')
  let options = out_one[1:]->mapnew({_, line -> line[2:]})
  call assert_equal(sort(copy(options)), options)
endfunc

func Test_renderoptions()
  throw 'skipped: Nvim does not support renderoptions'
  " Only do this for Windows Vista and later, fails on Windows XP and earlier.
  " Doesn't hurt to do this on a non-Windows system.
  if windowsversion() !~ '^[345]\.'
    set renderoptions=type:directx
    set rop=type:directx
  endif
endfunc

func ResetIndentexpr()
  set indentexpr=
endfunc

func Test_set_indentexpr()
  " this was causing usage of freed memory
  set indentexpr=ResetIndentexpr()
  new
  call feedkeys("i\<c-f>", 'x')
  call assert_equal('', &indentexpr)
  bwipe!
endfunc

func Test_backupskip()
  " Option 'backupskip' may contain several comma-separated path
  " specifications if one or more of the environment variables TMPDIR, TMP,
  " or TEMP is defined.  To simplify testing, convert the string value into a
  " list.
  let bsklist = split(&bsk, ',')

  if has("mac")
    let found = (index(bsklist, '/private/tmp/*') >= 0)
    call assert_true(found, '/private/tmp not in option bsk: ' . &bsk)
  elseif has("unix")
    let found = (index(bsklist, '/tmp/*') >= 0)
    call assert_true(found, '/tmp not in option bsk: ' . &bsk)
  endif

  " If our test platform is Windows, the path(s) in option bsk will use
  " backslash for the path separator and the components could be in short
  " (8.3) format.  As such, we need to replace the backslashes with forward
  " slashes and convert the path components to long format.  The expand()
  " function will do this but it cannot handle comma-separated paths.  This is
  " why bsk was converted from a string into a list of strings above.
  "
  " One final complication is that the wildcard "/*" is at the end of each
  " path and so expand() might return a list of matching files.  To prevent
  " this, we need to remove the wildcard before calling expand() and then
  " append it afterwards.
  if has('win32')
    let item_nbr = 0
    while item_nbr < len(bsklist)
      let path_spec = bsklist[item_nbr]
      let path_spec = strcharpart(path_spec, 0, strlen(path_spec)-2)
      let path_spec = substitute(expand(path_spec), '\\', '/', 'g')
      let bsklist[item_nbr] = path_spec . '/*'
      let item_nbr += 1
    endwhile
  endif

  " Option bsk will also include these environment variables if defined.
  " If they're defined, verify they appear in the option value.
  for var in  ['$TMPDIR', '$TMP', '$TEMP']
    if exists(var)
      let varvalue = substitute(expand(var), '\\', '/', 'g')
      let varvalue = substitute(varvalue, '/$', '', '')
      let varvalue .= '/*'
      let found = (index(bsklist, varvalue) >= 0)
      call assert_true(found, var . ' (' . varvalue . ') not in option bsk: ' . &bsk)
    endif
  endfor

  " Duplicates from environment variables should be filtered out (option has
  " P_NODUP).  Run this in a separate instance and write v:errors in a file,
  " so that we see what happens on startup.
  let after =<< trim [CODE]
      let bsklist = split(&backupskip, ',')
      call assert_equal(uniq(copy(bsklist)), bsklist)
      call writefile(['errors:'] + v:errors, 'Xtestout')
      qall
  [CODE]
  call writefile(after, 'Xafter')
  " let cmd = GetVimProg() . ' --not-a-term -S Xafter --cmd "set enc=utf8"'
  let cmd = GetVimProg() . ' -S Xafter --cmd "set enc=utf8"'

  let saveenv = {}
  for var in ['TMPDIR', 'TMP', 'TEMP']
    let saveenv[var] = getenv(var)
    call setenv(var, '/duplicate/path')
  endfor

  exe 'silent !' . cmd
  call assert_equal(['errors:'], readfile('Xtestout'))

  " restore environment variables
  for var in ['TMPDIR', 'TMP', 'TEMP']
    call setenv(var, saveenv[var])
  endfor

  call delete('Xtestout')
  call delete('Xafter')

  " Duplicates should be filtered out (option has P_NODUP)
  let backupskip = &backupskip
  set backupskip=
  set backupskip+=/test/dir
  set backupskip+=/other/dir
  set backupskip+=/test/dir
  call assert_equal('/test/dir,/other/dir', &backupskip)
  let &backupskip = backupskip
endfunc

func Test_buf_copy_winopt()
  set hidden

  " Test copy option from current buffer in window
  split
  enew
  setlocal numberwidth=5
  wincmd w
  call assert_equal(4,&numberwidth)
  bnext
  call assert_equal(5,&numberwidth)
  bw!
  call assert_equal(4,&numberwidth)

  " Test copy value from window that used to be display the buffer
  split
  enew
  setlocal numberwidth=6
  bnext
  wincmd w
  call assert_equal(4,&numberwidth)
  bnext
  call assert_equal(6,&numberwidth)
  bw!

  " Test that if buffer is current, don't use the stale cached value
  " from the last time the buffer was displayed.
  split
  enew
  setlocal numberwidth=7
  bnext
  bnext
  setlocal numberwidth=8
  wincmd w
  call assert_equal(4,&numberwidth)
  bnext
  call assert_equal(8,&numberwidth)
  bw!

  " Test value is not copied if window already has seen the buffer
  enew
  split
  setlocal numberwidth=9
  bnext
  setlocal numberwidth=10
  wincmd w
  call assert_equal(4,&numberwidth)
  bnext
  call assert_equal(4,&numberwidth)
  bw!

  set hidden&
endfunc

func Test_split_copy_options()
  let values = [
    \['cursorbind', 1, 0],
    \['fillchars', '"vert:-"', '"' .. &fillchars .. '"'],
    \['list', 1, 0],
    \['listchars', '"space:-"', '"' .. &listchars .. '"'],
    \['number', 1, 0],
    \['relativenumber', 1, 0],
    \['scrollbind', 1, 0],
    \['smoothscroll', 1, 0],
    \['virtualedit', '"block"', '"' .. &virtualedit .. '"'],
    "\ ['wincolor', '"Search"', '"' .. &wincolor .. '"'],
    \['wrap', 0, 1],
  \]
  if has('linebreak')
    let values += [
      \['breakindent', 1, 0],
      \['breakindentopt', '"min:5"', '"' .. &breakindentopt .. '"'],
      \['linebreak', 1, 0],
      \['numberwidth', 7, 4],
      \['showbreak', '"++"', '"' .. &showbreak .. '"'],
    \]
  endif
  if has('rightleft')
    let values += [
      \['rightleft', 1, 0],
      \['rightleftcmd', '"search"', '"' .. &rightleftcmd .. '"'],
    \]
  endif
  if has('statusline')
    let values += [
      \['statusline', '"---%f---"', '"' .. &statusline .. '"'],
    \]
  endif
  if has('spell')
    let values += [
      \['spell', 1, 0],
    \]
  endif
  if has('syntax')
    let values += [
      \['cursorcolumn', 1, 0],
      \['cursorline', 1, 0],
      \['cursorlineopt', '"screenline"', '"' .. &cursorlineopt .. '"'],
      \['colorcolumn', '"+1"', '"' .. &colorcolumn .. '"'],
    \]
  endif
  if has('diff')
    let values += [
      \['diff', 1, 0],
    \]
  endif
  if has('conceal')
    let values += [
      \['concealcursor', '"nv"', '"' .. &concealcursor .. '"'],
      \['conceallevel', '3', &conceallevel],
    \]
  endif
  if has('terminal')
    let values += [
      \['termwinkey', '"<C-X>"', '"' .. &termwinkey .. '"'],
      \['termwinsize', '"10x20"', '"' .. &termwinsize .. '"'],
    \]
  endif
  if has('folding')
    let values += [
      \['foldcolumn', '"5"',  &foldcolumn],
      \['foldenable', 0, 1],
      \['foldexpr', '"2 + 3"', '"' .. &foldexpr .. '"'],
      \['foldignore', '"+="', '"' .. &foldignore .. '"'],
      \['foldlevel', 4,  &foldlevel],
      \['foldmarker', '">>,<<"', '"' .. &foldmarker .. '"'],
      \['foldmethod', '"marker"', '"' .. &foldmethod .. '"'],
      \['foldminlines', 3,  &foldminlines],
      \['foldnestmax', 17,  &foldnestmax],
      \['foldtext', '"closed"', '"' .. &foldtext .. '"'],
    \]
  endif
  if has('signs')
    let values += [
      \['signcolumn', '"number"', '"' .. &signcolumn .. '"'],
    \]
  endif

  " set options to non-default value
  for item in values
    exe $"let &{item[0]} = {item[1]}"
  endfor

  " check values are set in new window
  split
  for item in values
    exe $'call assert_equal({item[1]}, &{item[0]}, "{item[0]}")'
  endfor

  " restore
  close
  for item in values
    exe $"let &{item[0]} = {item[1]}"
  endfor
endfunc

func Test_shortmess_F()
  new
  call assert_match('\[No Name\]', execute('file'))
  set shortmess+=F
  call assert_match('\[No Name\]', execute('file'))
  call assert_match('^\s*$', execute('file foo'))
  call assert_match('foo', execute('file'))
  set shortmess-=F
  call assert_match('bar', execute('file bar'))
  call assert_match('bar', execute('file'))
  set shortmess&
  bwipe
endfunc

func Test_shortmess_F2()
  e file1
  e file2
  call assert_match('file1', execute('bn', ''))
  call assert_match('file2', execute('bn', ''))
  set shortmess+=F
  call assert_true(empty(execute('bn', '')))
  " call assert_false(test_getvalue('need_fileinfo'))
  call assert_true(empty(execute('bn', '')))
  " call assert_false(test_getvalue('need_fileinfo'))
  set hidden
  call assert_true(empty(execute('bn', '')))
  " call assert_false(test_getvalue('need_fileinfo'))
  call assert_true(empty(execute('bn', '')))
  " call assert_false(test_getvalue('need_fileinfo'))
  set nohidden
  call assert_true(empty(execute('bn', '')))
  " call assert_false(test_getvalue('need_fileinfo'))
  call assert_true(empty(execute('bn', '')))
  " call assert_false(test_getvalue('need_fileinfo'))
  set shortmess-=F  " Accommodate Nvim default.
  call assert_match('file1', execute('bn', ''))
  call assert_match('file2', execute('bn', ''))
  bwipe
  bwipe
  " call assert_fails('call test_getvalue("abc")', 'E475:')
endfunc

func Test_shortmess_F3()
  call writefile(['foo'], 'X_dummy', 'D')

  set hidden
  set autoread
  e X_dummy
  e Xotherfile
  call assert_equal(['foo'], getbufline('X_dummy', 1, '$'))
  set shortmess+=F
  echo ''

  if has('nanotime')
    sleep 10m
  else
    sleep 2
  endif
  call writefile(['bar'], 'X_dummy')
  bprev
  call assert_equal('', Screenline(&lines))
  call assert_equal(['bar'], getbufline('X_dummy', 1, '$'))

  if has('nanotime')
    sleep 10m
  else
    sleep 2
  endif
  call writefile(['baz'], 'X_dummy')
  checktime
  call assert_equal('', Screenline(&lines))
  call assert_equal(['baz'], getbufline('X_dummy', 1, '$'))

  set shortmess&
  set autoread&
  set hidden&
  bwipe X_dummy
  bwipe Xotherfile
endfunc

func Test_local_scrolloff()
  set so=5
  set siso=7
  split
  call assert_equal(5, &so)
  setlocal so=3
  call assert_equal(3, &so)
  wincmd w
  call assert_equal(5, &so)
  wincmd w
  call assert_equal(3, &so)
  "setlocal so<
  set so<
  call assert_equal(5, &so)
  setglob so=8
  call assert_equal(8, &so)
  call assert_equal(-1, &l:so)
  setlocal so=0
  call assert_equal(0, &so)
  setlocal so=-1
  call assert_equal(8, &so)

  call assert_equal(7, &siso)
  setlocal siso=3
  call assert_equal(3, &siso)
  wincmd w
  call assert_equal(7, &siso)
  wincmd w
  call assert_equal(3, &siso)
  "setlocal siso<
  set siso<
  call assert_equal(7, &siso)
  setglob siso=4
  call assert_equal(4, &siso)
  call assert_equal(-1, &l:siso)
  setlocal siso=0
  call assert_equal(0, &siso)
  setlocal siso=-1
  call assert_equal(4, &siso)

  close
  set so&
  set siso&
endfunc

func Test_writedelay()
  CheckFunction reltimefloat

  new
  call setline(1, 'empty')
  " Nvim: 'writedelay' is applied per screen line.
  " Create 7 vertical splits first.
  vs | vs | vs | vs | vs | vs
  redraw
  set writedelay=10
  let start = reltime()
  " call setline(1, repeat('x', 70))
  " Nvim: enable 'writedelay' per screen line.
  " In each of the 7 vertical splits, 10 screen lines need to be drawn.
  set redrawdebug+=line
  call setline(1, repeat(['x'], 10))
  redraw
  let elapsed = reltimefloat(reltime(start))
  set writedelay=0
  " With 'writedelay' set should take at least 30 * 10 msec
  call assert_inrange(30 * 0.01, 999.0, elapsed)

  bwipe!
endfunc

func Test_visualbell()
  set belloff=
  set visualbell
  call assert_beeps('normal 0h')
  set novisualbell
  set belloff=all
endfunc

" Test for the 'write' option
func Test_write()
  new
  call setline(1, ['L1'])
  set nowrite
  call assert_fails('write Xwrfile', 'E142:')
  set write
  " close swapfile
  bw!
endfunc

" Test for 'buftype' option
func Test_buftype()
  new
  call setline(1, ['L1'])
  set buftype=nowrite
  call assert_fails('write', 'E382:')

  " for val in ['', 'nofile', 'nowrite', 'acwrite', 'quickfix', 'help', 'terminal', 'prompt', 'popup']
  for val in ['', 'nofile', 'nowrite', 'acwrite', 'quickfix', 'help', 'prompt']
    exe 'set buftype=' .. val
    call writefile(['something'], 'XBuftype')
    call assert_fails('write XBuftype', 'E13:', 'with buftype=' .. val)
  endfor

  call delete('XBuftype')
  bwipe!
endfunc

" Test for the 'rightleftcmd' option
func Test_rightleftcmd()
  CheckFeature rightleft
  set rightleft

  let g:l = []
  func AddPos()
    call add(g:l, screencol())
    return ''
  endfunc
  cmap <expr> <F2> AddPos()

  set rightleftcmd=
  call feedkeys("/\<F2>abc\<Right>\<F2>\<Left>\<Left>\<F2>" ..
        \ "\<Right>\<F2>\<Esc>", 'xt')
  call assert_equal([2, 5, 3, 4], g:l)

  let g:l = []
  set rightleftcmd=search
  call feedkeys("/\<F2>abc\<Left>\<F2>\<Right>\<Right>\<F2>" ..
        \ "\<Left>\<F2>\<Esc>", 'xt')
  call assert_equal([&co - 1, &co - 4, &co - 2, &co - 3], g:l)

  cunmap <F2>
  unlet g:l
  set rightleftcmd&
  set rightleft&
endfunc

" Test for the 'debug' option
func Test_debug_option()
  " redraw to avoid matching previous messages
  redraw
  set debug=beep
  exe "normal \<C-c>"
  call assert_equal('Beep!', Screenline(&lines))
  call assert_equal('line    4:', Screenline(&lines - 1))
  " also check a line above, with a certain window width the colon is there
  call assert_match('Test_debug_option:$',
        \ Screenline(&lines - 3) .. Screenline(&lines - 2))
  set debug&
endfunc

" Test for the default CDPATH option
func Test_opt_default_cdpath()
  let after =<< trim [CODE]
    call assert_equal(',/path/to/dir1,/path/to/dir2', &cdpath)
    call writefile(v:errors, 'Xtestout')
    qall
  [CODE]
  if has('unix')
    let $CDPATH='/path/to/dir1:/path/to/dir2'
  else
    let $CDPATH='/path/to/dir1;/path/to/dir2'
  endif
  if RunVim([], after, '')
    call assert_equal([], readfile('Xtestout'))
    call delete('Xtestout')
  endif
endfunc

" Test for setting keycodes using set
func Test_opt_set_keycode()
  " call assert_fails('set <t_k1=l', 'E474:')
  " call assert_fails('set <Home=l', 'E474:')
  call assert_fails('set <t_k1=l', 'E518:')
  call assert_fails('set <Home=l', 'E518:')
  set <t_k9>=abcd
  " call assert_equal('abcd', &t_k9)
  set <t_k9>&
  set <F9>=xyz
  " call assert_equal('xyz', &t_k9)
  set <t_k9>&
endfunc

" Test for changing options in a sandbox
func Test_opt_sandbox()
  for opt in ['backupdir', 'cdpath', 'exrc', 'findfunc']
    call assert_fails('sandbox set ' .. opt .. '?', 'E48:')
    call assert_fails('sandbox let &' .. opt .. ' = 1', 'E48:')
  endfor
  call assert_fails('sandbox let &modelineexpr = 1', 'E48:')
endfunc

" Test for setting string global-local option value
func Test_set_string_global_local_option()
  setglobal equalprg=gprg
  setlocal equalprg=lprg
  call assert_equal('gprg', &g:equalprg)
  call assert_equal('lprg', &l:equalprg)
  call assert_equal('lprg', &equalprg)

  " :set {option}< removes the local value, so that the global value will be used.
  set equalprg<
  call assert_equal('', &l:equalprg)
  call assert_equal('gprg', &equalprg)

  " :setlocal {option}< set the effective value of {option} to its global value.
  setglobal equalprg=gnewprg
  setlocal equalprg=lnewprg
  setlocal equalprg<
  call assert_equal('gnewprg', &l:equalprg)
  call assert_equal('gnewprg', &equalprg)

  set equalprg&
endfunc

" Test for setting number global-local option value
func Test_set_number_global_local_option()
  setglobal scrolloff=10
  setlocal scrolloff=12
  call assert_equal(10, &g:scrolloff)
  call assert_equal(12, &l:scrolloff)
  call assert_equal(12, &scrolloff)

  " :setlocal {option}< set the effective value of {option} to its global value.
  "set scrolloff<
  setlocal scrolloff<
  call assert_equal(10, &l:scrolloff)
  call assert_equal(10, &scrolloff)

  " :set {option}< removes the local value, so that the global value will be used.
  setglobal scrolloff=15
  setlocal scrolloff=18
  "setlocal scrolloff<
  set scrolloff<
  call assert_equal(-1, &l:scrolloff)
  call assert_equal(15, &scrolloff)

  set scrolloff&
endfunc

" Test for setting boolean global-local option value
func Test_set_boolean_global_local_option()
  setglobal autoread
  setlocal noautoread
  call assert_equal(1, &g:autoread)
  call assert_equal(0, &l:autoread)
  call assert_equal(0, &autoread)

  " :setlocal {option}< set the effective value of {option} to its global value.
  "set autoread<
  setlocal autoread<
  call assert_equal(1, &l:autoread)
  call assert_equal(1, &autoread)

  " :set {option}< removes the local value, so that the global value will be used.
  setglobal noautoread
  setlocal autoread
  "setlocal autoread<
  set autoread<
  call assert_equal(-1, &l:autoread)
  call assert_equal(0, &autoread)

  set autoread&
endfunc

func Test_set_in_sandbox()
  " Some boolean options cannot be set in sandbox, some can.
  call assert_fails('sandbox set modelineexpr', 'E48:')
  sandbox set number
  call assert_true(&number)
  set number&

  " Some boolean options cannot be set in sandbox, some can.
  if has('python') || has('python3')
    call assert_fails('sandbox set pyxversion=3', 'E48:')
  endif
  sandbox set tabstop=4
  call assert_equal(4, &tabstop)
  set tabstop&

  " Some string options cannot be set in sandbox, some can.
  call assert_fails('sandbox set backupdir=/tmp', 'E48:')
  sandbox set filetype=perl
  call assert_equal('perl', &filetype)
  set filetype&
endfunc

" Test for setting string option value
func Test_set_string_option()
  " :set {option}=
  set makeprg=
  call assert_equal('', &mp)
  set makeprg=abc
  call assert_equal('abc', &mp)

  " :set {option}:
  set makeprg:
  call assert_equal('', &mp)
  set makeprg:abc
  call assert_equal('abc', &mp)

  " Let string
  let &makeprg = ''
  call assert_equal('', &mp)
  let &makeprg = 'abc'
  call assert_equal('abc', &mp)

  " Let number converts to string
  let &makeprg = 42
  call assert_equal('42', &mp)

  " Appending
  set makeprg=abc
  set makeprg+=def
  call assert_equal('abcdef', &mp)
  set makeprg+=def
  call assert_equal('abcdefdef', &mp, ':set+= appends a value even if it already contained')
  let &makeprg .= 'gh'
  call assert_equal('abcdefdefgh', &mp)
  let &makeprg ..= 'ij'
  call assert_equal('abcdefdefghij', &mp)

  " Removing
  set makeprg=abcdefghi
  set makeprg-=def
  call assert_equal('abcghi', &mp)
  set makeprg-=def
  call assert_equal('abcghi', &mp, ':set-= does not remove a value if it is not contained')

  " Prepending
  set makeprg=abc
  set makeprg^=def
  call assert_equal('defabc', &mp)
  set makeprg^=def
  call assert_equal('defdefabc', &mp, ':set+= prepends a value even if it already contained')

  set makeprg&
endfunc

" Test for setting string comma-separated list option value
func Test_set_string_comma_list_option()
  " :set {option}=
  set wildignore=
  call assert_equal('', &wildignore)
  set wildignore=*.png
  call assert_equal('*.png', &wildignore)

  " :set {option}:
  set wildignore:
  call assert_equal('', &wildignore)
  set wildignore:*.png
  call assert_equal('*.png', &wildignore)

  " Let string
  let &wildignore = ''
  call assert_equal('', &wildignore)
  let &wildignore = '*.png'
  call assert_equal('*.png', &wildignore)

  " Let number converts to string
  let &wildignore = 42
  call assert_equal('42', &wildignore)

  " Appending
  set wildignore=*.png
  set wildignore+=*.jpg
  call assert_equal('*.png,*.jpg', &wildignore, ':set+= prepends a comma to append a value')
  set wildignore+=*.jpg
  call assert_equal('*.png,*.jpg', &wildignore, ':set+= does not append a value if it already contained')
  set wildignore+=jpg
  call assert_equal('*.png,*.jpg,jpg', &wildignore, ':set+= prepends a comma to append a value if it is not exactly match to item')
  let &wildignore .= 'foo'
  call assert_equal('*.png,*.jpg,jpgfoo', &wildignore, ':let-& .= appends a value without a comma')
  let &wildignore ..= 'bar'
  call assert_equal('*.png,*.jpg,jpgfoobar', &wildignore, ':let-& ..= appends a value without a comma')

  " Removing
  set wildignore=*.png,*.jpg,*.obj
  set wildignore-=*.jpg
  call assert_equal('*.png,*.obj', &wildignore)
  set wildignore-=*.jpg
  call assert_equal('*.png,*.obj', &wildignore, ':set-= does not remove a value if it is not contained')
  set wildignore-=jpg
  call assert_equal('*.png,*.obj', &wildignore, ':set-= does not remove a value if it is not exactly match to item')

  " Prepending
  set wildignore=*.png
  set wildignore^=*.jpg
  call assert_equal('*.jpg,*.png', &wildignore)
  set wildignore^=*.jpg
  call assert_equal('*.jpg,*.png', &wildignore, ':set+= does not prepend a value if it already contained')
  set wildignore^=jpg
  call assert_equal('jpg,*.jpg,*.png', &wildignore, ':set+= prepend a value if it is not exactly match to item')

  set wildignore&
endfunc

" Test for setting string flags option value
func Test_set_string_flags_option()
  " :set {option}=
  set formatoptions=
  call assert_equal('', &fo)
  set formatoptions=abc
  call assert_equal('abc', &fo)

  " :set {option}:
  set formatoptions:
  call assert_equal('', &fo)
  set formatoptions:abc
  call assert_equal('abc', &fo)

  " Let string
  let &formatoptions = ''
  call assert_equal('', &fo)
  let &formatoptions = 'abc'
  call assert_equal('abc', &fo)

  " Let number converts to string
  let &formatoptions = 12
  call assert_equal('12', &fo)

  " Appending
  set formatoptions=abc
  set formatoptions+=pqr
  call assert_equal('abcpqr', &fo)
  set formatoptions+=pqr
  call assert_equal('abcpqr', &fo, ':set+= does not append a value if it already contained')
  let &formatoptions .= 'r'
  call assert_equal('abcpqrr', &fo, ':let-& .= appends a value even if it already contained')
  let &formatoptions ..= 'r'
  call assert_equal('abcpqrrr', &fo, ':let-& ..= appends a value even if it already contained')

  " Removing
  set formatoptions=abcpqr
  set formatoptions-=cp
  call assert_equal('abqr', &fo)
  set formatoptions-=cp
  call assert_equal('abqr', &fo, ':set-= does not remove a value if it is not contained')
  set formatoptions-=ar
  call assert_equal('abqr', &fo, ':set-= does not remove a value if it is not exactly match')

  " Prepending
  set formatoptions=abc
  set formatoptions^=pqr
  call assert_equal('pqrabc', &fo)
  set formatoptions^=qr
  call assert_equal('pqrabc', &fo, ':set+= does not prepend a value if it already contained')

  set formatoptions&
endfunc

" Test for setting number option value
func Test_set_number_option()
  " :set {option}=
  set scrolljump=5
  call assert_equal(5, &sj)
  set scrolljump=-3
  call assert_equal(-3, &sj)

  " :set {option}:
  set scrolljump:7
  call assert_equal(7, &sj)
  set scrolljump:-5
  call assert_equal(-5, &sj)

  " Set hex
  set scrolljump=0x10
  call assert_equal(16, &sj)
  set scrolljump=-0x10
  call assert_equal(-16, &sj)
  set scrolljump=0X12
  call assert_equal(18, &sj)
  set scrolljump=-0X12
  call assert_equal(-18, &sj)

  " Set octal
  set scrolljump=010
  call assert_equal(8, &sj)
  set scrolljump=-010
  call assert_equal(-8, &sj)
  set scrolljump=0o12
  call assert_equal(10, &sj)
  set scrolljump=-0o12
  call assert_equal(-10, &sj)
  set scrolljump=0O15
  call assert_equal(13, &sj)
  set scrolljump=-0O15
  call assert_equal(-13, &sj)

  " Let number
  let &scrolljump = 4
  call assert_equal(4, &sj)
  let &scrolljump = -6
  call assert_equal(-6, &sj)

  " Let numeric string converts to number
  let &scrolljump = '7'
  call assert_equal(7, &sj)
  let &scrolljump = '-9'
  call assert_equal(-9, &sj)

  " Incrementing
  set shiftwidth=4
  set sw+=2
  call assert_equal(6, &sw)
  let &shiftwidth += 2
  call assert_equal(8, &sw)

  " Decrementing
  set shiftwidth=6
  set sw-=2
  call assert_equal(4, &sw)
  let &shiftwidth -= 2
  call assert_equal(2, &sw)

  " Multiplying
  set shiftwidth=4
  set sw^=2
  call assert_equal(8, &sw)
  let &shiftwidth *= 2
  call assert_equal(16, &sw)

  set scrolljump&
  set shiftwidth&
endfunc

" Test for setting boolean option value
func Test_set_boolean_option()
  set number&

  " :set {option}
  set number
  call assert_equal(1, &nu)

  " :set no{option}
  set nonu
  call assert_equal(0, &nu)

  " :set {option}!
  set number!
  call assert_equal(1, &nu)
  set number!
  call assert_equal(0, &nu)

  " :set inv{option}
  set invnumber
  call assert_equal(1, &nu)
  set invnumber
  call assert_equal(0, &nu)

  " Let number
  let &number = 1
  call assert_equal(1, &nu)
  let &number = 0
  call assert_equal(0, &nu)

  " Let numeric string converts to number
  let &number = '1'
  call assert_equal(1, &nu)
  let &number = '0'
  call assert_equal(0, &nu)

  " Let v:true and v:false
  let &nu = v:true
  call assert_equal(1, &nu)
  let &nu = v:false
  call assert_equal(0, &nu)

  set number&
endfunc

" Test for setting string option errors
func Test_set_string_option_errors()
  " :set no{option}
  call assert_fails('set nomakeprg', 'E474:')
  call assert_fails('setlocal nomakeprg', 'E474:')
  call assert_fails('setglobal nomakeprg', 'E474:')

  " :set inv{option}
  call assert_fails('set invmakeprg', 'E474:')
  call assert_fails('setlocal invmakeprg', 'E474:')
  call assert_fails('setglobal invmakeprg', 'E474:')

  " :set {option}!
  call assert_fails('set makeprg!', 'E488:')
  call assert_fails('setlocal makeprg!', 'E488:')
  call assert_fails('setglobal makeprg!', 'E488:')

  " Invalid trailing chars
  call assert_fails('set makeprg??', 'E488:')
  call assert_fails('setlocal makeprg??', 'E488:')
  call assert_fails('setglobal makeprg??', 'E488:')
  call assert_fails('set makeprg&&', 'E488:')
  call assert_fails('setlocal makeprg&&', 'E488:')
  call assert_fails('setglobal makeprg&&', 'E488:')
  call assert_fails('set makeprg<<', 'E488:')
  call assert_fails('setlocal makeprg<<', 'E488:')
  call assert_fails('setglobal makeprg<<', 'E488:')
  call assert_fails('set makeprg@', 'E488:')
  call assert_fails('setlocal makeprg@', 'E488:')
  call assert_fails('setglobal makeprg@', 'E488:')

  " Invalid type
  call assert_fails("let &makeprg = ['xxx']", 'E730:')
endfunc

" Test for setting number option errors
func Test_set_number_option_errors()
  " :set no{option}
  call assert_fails('set notabstop', 'E474:')
  call assert_fails('setlocal notabstop', 'E474:')
  call assert_fails('setglobal notabstop', 'E474:')

  " :set inv{option}
  call assert_fails('set invtabstop', 'E474:')
  call assert_fails('setlocal invtabstop', 'E474:')
  call assert_fails('setglobal invtabstop', 'E474:')

  " :set {option}!
  call assert_fails('set tabstop!', 'E488:')
  call assert_fails('setlocal tabstop!', 'E488:')
  call assert_fails('setglobal tabstop!', 'E488:')

  " Invalid trailing chars
  call assert_fails('set tabstop??', 'E488:')
  call assert_fails('setlocal tabstop??', 'E488:')
  call assert_fails('setglobal tabstop??', 'E488:')
  call assert_fails('set tabstop&&', 'E488:')
  call assert_fails('setlocal tabstop&&', 'E488:')
  call assert_fails('setglobal tabstop&&', 'E488:')
  call assert_fails('set tabstop<<', 'E488:')
  call assert_fails('setlocal tabstop<<', 'E488:')
  call assert_fails('setglobal tabstop<<', 'E488:')
  call assert_fails('set tabstop@', 'E488:')
  call assert_fails('setlocal tabstop@', 'E488:')
  call assert_fails('setglobal tabstop@', 'E488:')

  " Not a number
  call assert_fails('set tabstop=', 'E521:')
  call assert_fails('setlocal tabstop=', 'E521:')
  call assert_fails('setglobal tabstop=', 'E521:')
  call assert_fails('set tabstop=x', 'E521:')
  call assert_fails('setlocal tabstop=x', 'E521:')
  call assert_fails('setglobal tabstop=x', 'E521:')
  call assert_fails('set tabstop=1x', 'E521:')
  call assert_fails('setlocal tabstop=1x', 'E521:')
  call assert_fails('setglobal tabstop=1x', 'E521:')
  call assert_fails('set tabstop=-x', 'E521:')
  call assert_fails('setlocal tabstop=-x', 'E521:')
  call assert_fails('setglobal tabstop=-x', 'E521:')
  call assert_fails('set tabstop=0x', 'E521:')
  call assert_fails('setlocal tabstop=0x', 'E521:')
  call assert_fails('setglobal tabstop=0x', 'E521:')
  call assert_fails('set tabstop=0o', 'E521:')
  call assert_fails('setlocal tabstop=0o', 'E521:')
  call assert_fails('setglobal tabstop=0o', 'E521:')
  call assert_fails("let &tabstop = 'x'", 'E521:')
  call assert_fails("let &g:tabstop = 'x'", 'E521:')
  call assert_fails("let &l:tabstop = 'x'", 'E521:')

  " Invalid type
  call assert_fails("let &tabstop = 'xxx'", 'E521:')
endfunc

" Test for setting boolean option errors
func Test_set_boolean_option_errors()
  " :set {option}=
  call assert_fails('set number=', 'E474:')
  call assert_fails('setlocal number=', 'E474:')
  call assert_fails('setglobal number=', 'E474:')
  call assert_fails('set number=1', 'E474:')
  call assert_fails('setlocal number=1', 'E474:')
  call assert_fails('setglobal number=1', 'E474:')

  " :set {option}:
  call assert_fails('set number:', 'E474:')
  call assert_fails('setlocal number:', 'E474:')
  call assert_fails('setglobal number:', 'E474:')
  call assert_fails('set number:1', 'E474:')
  call assert_fails('setlocal number:1', 'E474:')
  call assert_fails('setglobal number:1', 'E474:')

  " :set {option}+=
  call assert_fails('set number+=1', 'E474:')
  call assert_fails('setlocal number+=1', 'E474:')
  call assert_fails('setglobal number+=1', 'E474:')

  " :set {option}^=
  call assert_fails('set number^=1', 'E474:')
  call assert_fails('setlocal number^=1', 'E474:')
  call assert_fails('setglobal number^=1', 'E474:')

  " :set {option}-=
  call assert_fails('set number-=1', 'E474:')
  call assert_fails('setlocal number-=1', 'E474:')
  call assert_fails('setglobal number-=1', 'E474:')

  " Invalid trailing chars
  call assert_fails('set number!!', 'E488:')
  call assert_fails('setlocal number!!', 'E488:')
  call assert_fails('setglobal number!!', 'E488:')
  call assert_fails('set number??', 'E488:')
  call assert_fails('setlocal number??', 'E488:')
  call assert_fails('setglobal number??', 'E488:')
  call assert_fails('set number&&', 'E488:')
  call assert_fails('setlocal number&&', 'E488:')
  call assert_fails('setglobal number&&', 'E488:')
  call assert_fails('set number<<', 'E488:')
  call assert_fails('setlocal number<<', 'E488:')
  call assert_fails('setglobal number<<', 'E488:')
  call assert_fails('set number@', 'E488:')
  call assert_fails('setlocal number@', 'E488:')
  call assert_fails('setglobal number@', 'E488:')

  " Invalid type
  call assert_fails("let &number = 'xxx'", 'E521:')
endfunc

" Test for the 'window' option
func Test_window_opt()
  " Needs only one open widow
  %bw!
  call setline(1, range(1, 8))
  set window=5
  exe "normal \<C-F>"
  call assert_equal(4, line('w0'))
  exe "normal \<C-F>"
  call assert_equal(7, line('w0'))
  exe "normal \<C-F>"
  call assert_equal(8, line('w0'))
  exe "normal \<C-B>"
  call assert_equal(5, line('w0'))
  exe "normal \<C-B>"
  call assert_equal(2, line('w0'))
  exe "normal \<C-B>"
  call assert_equal(1, line('w0'))
  set window=1
  exe "normal gg\<C-F>"
  call assert_equal(2, line('w0'))
  exe "normal \<C-F>"
  call assert_equal(3, line('w0'))
  exe "normal \<C-B>"
  call assert_equal(2, line('w0'))
  exe "normal \<C-B>"
  call assert_equal(1, line('w0'))
  enew!
  set window&
endfunc

" Test for the 'winminheight' option
func Test_opt_winminheight()
  only!
  let &winheight = &lines + 4
  call assert_fails('let &winminheight = &lines + 2', 'E36:')
  call assert_true(&winminheight <= &lines)
  set winminheight&
  set winheight&
endfunc

func Test_opt_winminheight_term()
  " See test/functional/legacy/options_spec.lua
  CheckRunVimInTerminal

  " The tabline should be taken into account.
  let lines =<< trim END
    set wmh=0 stal=2
    below sp | wincmd _
    below sp | wincmd _
    below sp | wincmd _
    below sp
  END
  call writefile(lines, 'Xwinminheight')
  let buf = RunVimInTerminal('-S Xwinminheight', #{rows: 11})
  call term_sendkeys(buf, ":set wmh=1\n")
  call WaitForAssert({-> assert_match('E36: Not enough room', term_getline(buf, 11))})

  call StopVimInTerminal(buf)
  call delete('Xwinminheight')
endfunc

func Test_opt_winminheight_term_tabs()
  " See test/functional/legacy/options_spec.lua
  CheckRunVimInTerminal

  " The tabline should be taken into account.
  let lines =<< trim END
    set wmh=0 stal=2
    split
    split
    split
    split
    tabnew
  END
  call writefile(lines, 'Xwinminheight')
  let buf = RunVimInTerminal('-S Xwinminheight', #{rows: 11})
  call term_sendkeys(buf, ":set wmh=1\n")
  call WaitForAssert({-> assert_match('E36: Not enough room', term_getline(buf, 11))})

  call StopVimInTerminal(buf)
  call delete('Xwinminheight')
endfunc

" Test for the 'winminwidth' option
func Test_opt_winminwidth()
  only!
  let &winwidth = &columns + 4
  call assert_fails('let &winminwidth = &columns + 2', 'E36:')
  call assert_true(&winminwidth <= &columns)
  set winminwidth&
  set winwidth&
endfunc

" Test for setting option value containing spaces with isfname+=32
func Test_isfname_with_options()
  set isfname+=32
  setlocal keywordprg=:term\ help.exe
  call assert_equal(':term help.exe', &keywordprg)
  set isfname&
  setlocal keywordprg&
endfunc

" Test that resetting laststatus does change scroll option
func Test_opt_reset_scroll()
  " See test/functional/legacy/options_spec.lua
  CheckRunVimInTerminal
  let vimrc =<< trim [CODE]
    set scroll=2
    set laststatus=2
  [CODE]
  call writefile(vimrc, 'Xscroll')
  let buf = RunVimInTerminal('-S Xscroll', {'rows': 16, 'cols': 45})
  call term_sendkeys(buf, ":verbose set scroll?\n")
  call WaitForAssert({-> assert_match('Last set.*window size', term_getline(buf, 15))})
  call assert_match('^\s*scroll=7$', term_getline(buf, 14))
  call StopVimInTerminal(buf)

  " clean up
  call delete('Xscroll')
endfunc

" Check that VIM_POSIX env variable influences default value of 'cpo' and 'shm'
func Test_VIM_POSIX()
  throw 'Skipped: Nvim does not support $VIM_POSIX'
  let saved_VIM_POSIX = getenv("VIM_POSIX")

  call setenv('VIM_POSIX', "1")
  let after =<< trim [CODE]
    call writefile([&cpo, &shm], 'X_VIM_POSIX')
    qall
  [CODE]
  if RunVim([], after, '')
    call assert_equal(['aAbBcCdDeEfFgHiIjJkKlLmMnoOpPqrRsStuvwWxXyZ$!%*-+<>#{|&/\.;',
          \            'AS'], readfile('X_VIM_POSIX'))
  endif

  call setenv('VIM_POSIX', v:null)
  let after =<< trim [CODE]
    call writefile([&cpo, &shm], 'X_VIM_POSIX')
    qall
  [CODE]
  if RunVim([], after, '')
    call assert_equal(['aAbBcCdDeEfFgHiIjJkKlLmMnoOpPqrRsStuvwWxXyZ$!%*-+<>;',
          \            'S'], readfile('X_VIM_POSIX'))
  endif

  call delete('X_VIM_POSIX')
  call setenv('VIM_POSIX', saved_VIM_POSIX)
endfunc

" Test for setting an option to a Vi or Vim default
func Test_opt_default()
  throw 'Skipped: Nvim has different defaults'
  set formatoptions&vi
  call assert_equal('vt', &formatoptions)
  set formatoptions&vim
  call assert_equal('tcq', &formatoptions)

  call assert_equal('ucs-bom,utf-8,default,latin1', &fencs)
  set fencs=latin1
  set fencs&
  call assert_equal('ucs-bom,utf-8,default,latin1', &fencs)
  set fencs=latin1
  set all&
  call assert_equal('ucs-bom,utf-8,default,latin1', &fencs)
endfunc

" Test for the 'cmdheight' option
func Test_opt_cmdheight()
  %bw!
  let ht = &lines
  set cmdheight=9999
  call assert_equal(1, winheight(0))
  call assert_equal(ht - 1, &cmdheight)
  set cmdheight&

  " The status line should be taken into account.
  set laststatus=2
  set cmdheight=9999
  call assert_equal(ht - 2, &cmdheight)
  set cmdheight& laststatus=1  " Accommodate Nvim default

  " The tabline should be taken into account only non-GUI.
  set showtabline=2
  set cmdheight=9999
  if has('gui_running')
    call assert_equal(ht - 1, &cmdheight)
  else
    call assert_equal(ht - 2, &cmdheight)
  endif
  set cmdheight& showtabline&

  " The 'winminheight' should be taken into account.
  set winheight=3 winminheight=3
  split
  set cmdheight=9999
  call assert_equal(ht - 8, &cmdheight)
  %bw!
  set cmdheight& winminheight& winheight&

  " Only the windows in the current tabpage are taken into account.
  set winheight=3 winminheight=3 showtabline=0
  split
  tabnew
  set cmdheight=9999
  call assert_equal(ht - 3, &cmdheight)
  %bw!
  set cmdheight& winminheight& winheight& showtabline&
endfunc

" To specify a control character as an option value, '^' can be used
func Test_opt_control_char()
  set wildchar=^v
  call assert_equal("\<C-V>", nr2char(&wildchar))
  set wildcharm=^r
  call assert_equal("\<C-R>", nr2char(&wildcharm))
  " Bug: This doesn't work for the 'cedit' and 'termwinkey' options
  set wildchar& wildcharm&
endfunc

" Test for the 'errorbells' option
func Test_opt_errorbells()
  set errorbells
  call assert_beeps('s/a1b2/x1y2/')
  set noerrorbells
endfunc

func Test_opt_scrolljump()
  help
  resize 10

  " Test with positive 'scrolljump'.
  set scrolljump=2
  norm! Lj
  call assert_equal({'lnum':11, 'leftcol':0, 'col':0, 'topfill':0,
        \            'topline':3, 'coladd':0, 'skipcol':0, 'curswant':0},
        \           winsaveview())

  " Test with negative 'scrolljump' (percentage of window height).
  set scrolljump=-40
  norm! ggLj
  call assert_equal({'lnum':11, 'leftcol':0, 'col':0, 'topfill':0,
         \            'topline':5, 'coladd':0, 'skipcol':0, 'curswant':0},
         \           winsaveview())

  set scrolljump&
  bw
endfunc

" Test for the 'cdhome' option
func Test_opt_cdhome()
  if has('unix') || has('vms')
    throw 'Skipped: only works on non-Unix'
  endif

  set cdhome&
  call assert_equal(0, &cdhome)
  set cdhome

  " This paragraph is copied from Test_cd_no_arg().
  let path = getcwd()
  cd
  call assert_equal($HOME, getcwd())
  call assert_notequal(path, getcwd())
  exe 'cd ' .. fnameescape(path)
  call assert_equal(path, getcwd())

  set cdhome&
endfunc

func Test_set_completion_fuzzy()
  CheckOption termguicolors

  " Test default option completion
  set wildoptions=
  call feedkeys(":set termg\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set termguicolors', @:)

  call feedkeys(":set notermg\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set notermguicolors', @:)

  " Test fuzzy option completion
  set wildoptions=fuzzy
  call feedkeys(":set termg\<C-A>\<C-B>\"\<CR>", 'tx')
  " Nvim doesn't have 'termencoding'
  " call assert_equal('"set termguicolors termencoding', @:)
  call assert_equal('"set termguicolors', @:)

  call feedkeys(":set notermg\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set notermguicolors', @:)

  set wildoptions=
endfunc

func Test_switchbuf_reset()
  set switchbuf=useopen
  sblast
  call assert_equal(1, winnr('$'))
  set all&
  " Nvim has a different default for 'switchbuf'
  " call assert_equal('', &switchbuf)
  call assert_equal('uselast', &switchbuf)
  sblast
  call assert_equal(2, winnr('$'))
  only!
endfunc

" :set empty string for global 'keywordprg' falls back to ":help"
func Test_keywordprg_empty()
  let k = &keywordprg
  set keywordprg=man
  call assert_equal('man', &keywordprg)
  set keywordprg=
  call assert_equal(':help', &keywordprg)
  set keywordprg=man
  call assert_equal('man', &keywordprg)
  call assert_equal("\n  keywordprg=:help", execute('set kp= kp?'))
  let &keywordprg = k
endfunc

" check that the very first buffer created does not have 'endoffile' set
func Test_endoffile_default()
  let after =<< trim [CODE]
    call writefile([execute('set eof?')], 'Xtestout')
    qall!
  [CODE]
  if RunVim([], after, '')
    call assert_equal(["\nnoendoffile"], readfile('Xtestout'))
  endif
  call delete('Xtestout')
endfunc

" Test for setting the 'lines' and 'columns' options to a minimum value
func Test_set_min_lines_columns()
  let save_lines = &lines
  let save_columns = &columns

  let after =<< trim END
    set laststatus=1
    set nomore
    let msg = []
    let v:errmsg = ''
    silent! let &columns=0
    call add(msg, v:errmsg)
    silent! set columns=0
    call add(msg, v:errmsg)
    silent! call setbufvar('', '&columns', 0)
    call add(msg, v:errmsg)
    "call writefile(msg, 'XResultsetminlines')
    silent! let &lines=0
    call add(msg, v:errmsg)
    silent! set lines=0
    call add(msg, v:errmsg)
    silent! call setbufvar('', '&lines', 0)
    call add(msg, v:errmsg)
    call writefile(msg, 'XResultsetminlines')
    qall!
  END
  if RunVim([], after, '')
    call assert_equal(['E594: Need at least 12 columns',
          \ 'E594: Need at least 12 columns: columns=0',
          \ 'E594: Need at least 12 columns',
          \ 'E593: Need at least 2 lines',
          \ 'E593: Need at least 2 lines: lines=0',
          \ 'E593: Need at least 2 lines',], readfile('XResultsetminlines'))
  endif

  call delete('XResultsetminlines')
  let &lines = save_lines
  let &columns = save_columns
endfunc

" Test for reverting a string option value if the new value is invalid.
func Test_string_option_revert_on_failure()
  new
  let optlist = [
        \ ['ambiwidth', 'double', 'a123'],
        \ ['background', 'dark', 'a123'],
        \ ['backspace', 'eol', 'a123'],
        \ ['backupcopy', 'no', 'a123'],
        \ ['belloff', 'showmatch', 'a123'],
        \ ['breakindentopt', 'min:10', 'list'],
        \ ['bufhidden', 'wipe', 'a123'],
        \ ['buftype', 'nowrite', 'a123'],
        \ ['casemap', 'keepascii', 'a123'],
        \ ['cedit', "\<C-Y>", 'z'],
        \ ['colorcolumn', '10', 'z'],
        \ ['commentstring', '#%s', 'a123'],
        \ ['complete', '.,t', 'a'],
        \ ['completefunc', 'MyCmplFunc', '1a-'],
        "\ ['completeopt', 'popup', 'a123'],
        \ ['completeopt', 'preview', 'a123'],
        "\ ['completepopup', 'width:20', 'border'],
        \ ['concealcursor', 'v', 'xyz'],
        "\ ['cpoptions', 'HJ', '~'],
        \ ['cpoptions', 'J', '~'],
        "\ ['cryptmethod', 'zip', 'a123'],
        \ ['cursorlineopt', 'screenline', 'a123'],
        \ ['debug', 'throw', 'a123'],
        \ ['diffopt', 'iwhite', 'a123'],
        \ ['display', 'uhex', 'a123'],
        \ ['eadirection', 'hor', 'a123'],
        \ ['encoding', 'utf-8', 'a123'],
        \ ['eventignore', 'TextYankPost', 'a123'],
        \ ['fileencoding', 'utf-8', 'a123,'],
        \ ['fileformat', 'mac', 'a123'],
        \ ['fileformats', 'mac', 'a123'],
        \ ['filetype', 'abc', 'a^b'],
        \ ['fillchars', 'diff:~', 'a123'],
        \ ['foldclose', 'all', 'a123'],
        \ ['foldmarker', '[[[,]]]', '[[['],
        \ ['foldmethod', 'marker', 'a123'],
        \ ['foldopen', 'percent', 'a123'],
        \ ['formatoptions', 'an', '*'],
        \ ['guicursor', 'n-v-c:block-Cursor/lCursor', 'n-v-c'],
        \ ['helplang', 'en', 'a'],
        "\ ['highlight', '!:CursorColumn', '8:'],
        \ ['keymodel', 'stopsel', 'a123'],
        "\ ['keyprotocol', 'kitty:kitty', 'kitty:'],
        \ ['lispoptions', 'expr:1', 'a123'],
        \ ['listchars', 'tab:->', 'tab:'],
        \ ['matchpairs', '<:>', '<:'],
        \ ['messagesopt', 'hit-enter,history:100', 'a123'],
        \ ['mkspellmem', '100000,1000,100', '100000'],
        \ ['mouse', 'nvi', 'z'],
        \ ['mousemodel', 'extend', 'a123'],
        \ ['nrformats', 'alpha', 'a123'],
        \ ['omnifunc', 'MyOmniFunc', '1a-'],
        \ ['operatorfunc', 'MyOpFunc', '1a-'],
        "\ ['previewpopup', 'width:20', 'a123'],
        "\ ['printoptions', 'paper:A4', 'a123:'],
        \ ['quickfixtextfunc', 'MyQfFunc', '1a-'],
        \ ['rulerformat', '%l', '%['],
        \ ['scrollopt', 'hor,jump', 'a123'],
        \ ['selection', 'exclusive', 'a123'],
        \ ['selectmode', 'cmd', 'a123'],
        \ ['sessionoptions', 'options', 'a123'],
        \ ['shortmess', 'w', '2'],
        \ ['showbreak', '>>', "\x01"],
        \ ['showcmdloc', 'statusline', 'a123'],
        \ ['signcolumn', 'no', 'a123'],
        \ ['spellcapcheck', '[.?!]\+', '%\{'],
        \ ['spellfile', 'MySpell.en.add', "\x01"],
        \ ['spelllang', 'en', "#"],
        \ ['spelloptions', 'camel', 'a123'],
        \ ['spellsuggest', 'double', 'a123'],
        \ ['splitkeep', 'topline', 'a123'],
        \ ['statusline', '%f', '%['],
        "\ ['swapsync', 'sync', 'a123'],
        \ ['switchbuf', 'usetab', 'a123'],
        \ ['syntax', 'abc', 'a^b'],
        \ ['tabline', '%f', '%['],
        \ ['tagcase', 'ignore', 'a123'],
        \ ['tagfunc', 'MyTagFunc', '1a-'],
        \ ['thesaurusfunc', 'MyThesaurusFunc', '1a-'],
        \ ['viewoptions', 'options', 'a123'],
        \ ['virtualedit', 'onemore', 'a123'],
        \ ['whichwrap', '<,>', '{,}'],
        \ ['wildmode', 'list', 'a123'],
        \ ['wildoptions', 'pum', 'a123']
        \ ]
  if has('gui')
    call add(optlist, ['browsedir', 'buffer', 'a123'])
  endif
  if has('clipboard_working')
    call add(optlist, ['clipboard', 'unnamed', 'a123'])
  endif
  if has('win32')
    call add(optlist, ['completeslash', 'slash', 'a123'])
  endif
  if has('cscope')
    call add(optlist, ['cscopequickfix', 't-', 'z-'])
  endif
  if !has('win32') && !has('nvim')
    call add(optlist, ['imactivatefunc', 'MyActFunc', '1a-'])
    call add(optlist, ['imstatusfunc', 'MyStatusFunc', '1a-'])
  endif
  if has('keymap')
    call add(optlist, ['keymap', 'greek', '[]'])
  endif
  if has('mouseshape')
    call add(optlist, ['mouseshape', 'm:no', 'a123:'])
  endif
  if has('win32') && has('gui')
    call add(optlist, ['renderoptions', 'type:directx', 'type:directx,a123'])
  endif
  if has('rightleft')
    call add(optlist, ['rightleftcmd', 'search', 'a123'])
  endif
  if has('terminal')
    call add(optlist, ['termwinkey', '<C-L>', '<C'])
    call add(optlist, ['termwinsize', '24x80', '100'])
  endif
  if has('win32') && has('terminal')
    call add(optlist, ['termwintype', 'winpty', 'a123'])
  endif
  if exists('+toolbar')
    call add(optlist, ['toolbar', 'text', 'a123'])
  endif
  if exists('+toolbariconsize')
    call add(optlist, ['toolbariconsize', 'medium', 'a123'])
  endif
  if exists('+ttymouse') && !has('gui')
    call add(optlist, ['ttymouse', 'xterm', 'a123'])
  endif
  if exists('+vartabs')
    call add(optlist, ['varsofttabstop', '12', 'a123'])
    call add(optlist, ['vartabstop', '4,20', '4,'])
  endif
  if exists('+winaltkeys')
    call add(optlist, ['winaltkeys', 'no', 'a123'])
  endif
  for opt in optlist
    exe $"let save_opt = &{opt[0]}"
    try
      exe $"let &{opt[0]} = '{opt[1]}'"
    catch
      call assert_report($"Caught {v:exception} with {opt->string()}")
    endtry
    call assert_fails($"let &{opt[0]} = '{opt[2]}'", '', opt[0])
    call assert_equal(opt[1], eval($"&{opt[0]}"), opt[0])
    exe $"let &{opt[0]} = save_opt"
  endfor
  bw!
endfunc

func Test_set_option_window_global_local()
  new Xbuffer1
  let [ _gso, _lso ] = [ &g:scrolloff, &l:scrolloff ]
  setlocal scrolloff=2
  setglobal scrolloff=3
  setl modified
  " A new buffer has its own window-local options
  hide enew
  call assert_equal(-1, &l:scrolloff)
  call assert_equal(3, &g:scrolloff)
  " A new window opened with its own buffer-local options
  new
  call assert_equal(-1, &l:scrolloff)
  call assert_equal(3, &g:scrolloff)
  " Re-open Xbuffer1 and it should use
  " the previous set window-local options
  b Xbuffer1
  call assert_equal(2, &l:scrolloff)
  call assert_equal(3, &g:scrolloff)
  bw!
  bw!
  let &g:scrolloff =  _gso
endfunc

func GetGlobalLocalWindowOptions()
  new
  sil! r $VIMRUNTIME/doc/options.txt
  " Filter for global or local to window
  v/^'.*'.*\n.*global or local to window |global-local/d
  " get option value and type
  sil %s/^'\([^']*\)'.*'\s\+\(\w\+\)\s\+(default \%(\(".*"\|\d\+\|empty\)\).*/\1 \2 \3/g
  " sil %s/empty/""/g
  " split the result
  " let result=getline(1,'$')->map({_, val -> split(val, ' ')})
  let result = getline(1, '$')->map({_, val -> matchlist(val, '\([^ ]\+\) \+\([^ ]\+\) \+\(.*\)')[1:3]})
  bw!
  return result
endfunc

func Test_set_option_window_global_local_all()
  new Xbuffer2

  let optionlist = GetGlobalLocalWindowOptions()
  for [opt, type, default] in optionlist
    let _old = eval('&g:' .. opt)
    if type == 'string'
      if opt == 'fillchars'
        exe 'setl ' .. opt .. '=vert:+'
        exe 'setg ' .. opt .. '=vert:+,fold:+'
      elseif opt == 'listchars'
        exe 'setl ' .. opt .. '=tab:>>'
        exe 'setg ' .. opt .. '=tab:++'
      elseif opt == 'virtualedit'
        exe 'setl ' .. opt .. '=all'
        exe 'setg ' .. opt .. '=block'
      else
        exe 'setl ' .. opt .. '=Local'
        exe 'setg ' .. opt .. '=Global'
      endif
    elseif type == 'number'
      exe 'setl ' .. opt .. '=5'
      exe 'setg ' .. opt .. '=10'
    endif
    setl modified
    hide enew
    if type == 'string'
      call assert_equal('', eval('&l:' .. opt))
      if opt == 'fillchars'
        call assert_equal('vert:+,fold:+', eval('&g:' .. opt), 'option:' .. opt)
      elseif opt == 'listchars'
        call assert_equal('tab:++', eval('&g:' .. opt), 'option:' .. opt)
      elseif opt == 'virtualedit'
        call assert_equal('block', eval('&g:' .. opt), 'option:' .. opt)
      else
        call assert_equal('Global', eval('&g:' .. opt), 'option:' .. opt)
      endif
    elseif type == 'number'
      call assert_equal(-1, eval('&l:' .. opt), 'option:' .. opt)
      call assert_equal(10, eval('&g:' .. opt), 'option:' .. opt)
    endif
    bw!
    exe 'let &g:' .. opt .. '=' .. default
  endfor
  bw!
endfunc

func Test_paste_depending_options()
  " setting the paste option, resets all dependent options
  " and will be reported correctly using :verbose set <option>?
  let lines =<< trim [CODE]
    " set paste test
    set autoindent
    set expandtab
    " disabled, because depends on compiled feature set
    " set hkmap
    " set revins
    " set varsofttabstop=8,32,8
    set ruler
    set showmatch
    set smarttab
    set softtabstop=4
    set textwidth=80
    set wrapmargin=10

    source Xvimrc_paste2

    redir > Xoutput_paste
    verbose set expandtab?
    verbose setg expandtab?
    verbose setl expandtab?
    redir END

    qall!
  [CODE]

  call writefile(lines, 'Xvimrc_paste', 'D')
  call writefile(['set paste'], 'Xvimrc_paste2', 'D')
  if !RunVim([], lines, '--clean')
    return
  endif

  let result = readfile('Xoutput_paste')->filter('!empty(v:val)')
  call assert_equal('noexpandtab', result[0])
  call assert_match("^\tLast set from .*Xvimrc_paste2 line 1$", result[1])
  call assert_equal('noexpandtab', result[2])
  call assert_match("^\tLast set from .*Xvimrc_paste2 line 1$", result[3])
  call assert_equal('noexpandtab', result[4])
  call assert_match("^\tLast set from .*Xvimrc_paste2 line 1$", result[5])

  call delete('Xoutput_paste')
endfunc

func Test_binary_depending_options()
  " setting the paste option, resets all dependent options
  " and will be reported correctly using :verbose set <option>?
  let lines =<< trim [CODE]
    " set binary test
    set expandtab

    source Xvimrc_bin2

    redir > Xoutput_bin
    verbose set expandtab?
    verbose setg expandtab?
    verbose setl expandtab?
    redir END

    qall!
  [CODE]

  call writefile(lines, 'Xvimrc_bin', 'D')
  call writefile(['set binary'], 'Xvimrc_bin2', 'D')
  if !RunVim([], lines, '--clean')
    return
  endif

  let result = readfile('Xoutput_bin')->filter('!empty(v:val)')
  call assert_equal('noexpandtab', result[0])
  call assert_match("^\tLast set from .*Xvimrc_bin2 line 1$", result[1])
  call assert_equal('noexpandtab', result[2])
  call assert_match("^\tLast set from .*Xvimrc_bin2 line 1$", result[3])
  call assert_equal('noexpandtab', result[4])
  call assert_match("^\tLast set from .*Xvimrc_bin2 line 1$", result[5])

  call delete('Xoutput_bin')
endfunc

func Test_set_wrap()
  " Unsetting 'wrap' when 'smoothscroll' is set does not result in incorrect
  " cursor position.
  set wrap smoothscroll scrolloff=5

  call setline(1, ['', 'aaaa'->repeat(500)])
  20 split
  20 vsplit
  norm 2G$
  redraw
  set nowrap
  call assert_equal(2, winline())

  set wrap& smoothscroll& scrolloff&
endfunc

func Test_delcombine()
  new
  set backspace=indent,eol,start

  set delcombine
  call setline(1, 'β̳̈:β̳̈')
  normal! 0x
  call assert_equal('β̈:β̳̈', getline(1))
  exe "normal! A\<BS>"
  call assert_equal('β̈:β̈', getline(1))
  normal! 0x
  call assert_equal('β:β̈', getline(1))
  exe "normal! A\<BS>"
  call assert_equal('β:β', getline(1))
  normal! 0x
  call assert_equal(':β', getline(1))
  exe "normal! A\<BS>"
  call assert_equal(':', getline(1))

  set nodelcombine
  call setline(1, 'β̳̈:β̳̈')
  normal! 0x
  call assert_equal(':β̳̈', getline(1))
  exe "normal! A\<BS>"
  call assert_equal(':', getline(1))

  set backspace& delcombine&
  bwipe!
endfunc

" Should not raise errors when set missing-options.
func Test_set_missing_options()
  throw 'Skipped: N/A'
  set autoprint
  set beautify
  set flash
  set graphic
  set hardtabs=8
  set mesg
  set novice
  set open
  set optimize
  set redraw
  set slowopen
  set sourceany
  set w300=23
  set w1200=23
  set w9600=23
endfunc

" vim: shiftwidth=2 sts=2 expandtab
