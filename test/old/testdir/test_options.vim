" Test for options

source check.vim
source view_util.vim

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

  " For compatibility with Vim 3.0 and before, number values are also
  " supported for 'whichwrap'
  set whichwrap=1
  call assert_equal('b', &whichwrap)
  set whichwrap=2
  call assert_equal('s', &whichwrap)
  set whichwrap=4
  call assert_equal('h,l', &whichwrap)
  set whichwrap=8
  call assert_equal('<,>', &whichwrap)
  set whichwrap=16
  call assert_equal('[,]', &whichwrap)
  set whichwrap=31
  call assert_equal('b,s,h,l,<,>,[,]', &whichwrap)

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
  call feedkeys(":set fileencodings=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set fileencodings=ucs-bom,utf-8,default,latin1', @:)

  call feedkeys(":set fileencodings:\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set fileencodings:ucs-bom,utf-8,default,latin1', @:)

  " Expand key codes.
  " call feedkeys(":set <H\<C-A>\<C-B>\"\<CR>", 'tx')
  " call assert_equal('"set <Help> <Home>', @:)

  " Expand terminal options.
  " call feedkeys(":set t_A\<C-A>\<C-B>\"\<CR>", 'tx')
  " call assert_equal('"set t_AB t_AF t_AU t_AL', @:)
  " call assert_fails('call feedkeys(":set <t_afoo>=\<C-A>\<CR>", "xt")', 'E474:')

  " Expand directories.
  call feedkeys(":set cdpath=./\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('./samples/ ', @:)
  call assert_notmatch('./small.vim ', @:)

  " Expand files and directories.
  call feedkeys(":set tags=./\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('./samples/ ./sautest/ ./screendump.vim ./script_util.vim ./setup.vim ./shared.vim', @:)

  call feedkeys(":set tags=./\\\\ dif\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set tags=./\\ diff diffexpr diffopt', @:)
  set tags&

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
  call feedkeys(":set spellsuggest=best,file:xyz\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"set spellsuggest=best,file:xyz", @:)

  " Expand value for 'key'
  " set key=abcd
  " call feedkeys(":set key=\<Tab>\<C-B>\"\<CR>", 'xt')
  " call assert_equal('"set key=*****', @:)
  " set key=

  " Expand values for 'filetype'
  call feedkeys(":set filetype=sshdconfi\<Tab>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set filetype=sshdconfig', @:)
  call feedkeys(":set filetype=a\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"set filetype=' .. getcompletion('a*', 'filetype')->join(), @:)
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
  call assert_fails('set xxx', 'E518:')
  call assert_fails('set beautify?', 'E518:')
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
  call assert_fails('set statusline=%$', 'E539:')
  call assert_fails('set statusline=%{', 'E540:')
  call assert_fails('set statusline=%{%', 'E540:')
  call assert_fails('set statusline=%{%}', 'E539:')
  call assert_fails('set statusline=%(', 'E542:')
  call assert_fails('set statusline=%)', 'E542:')
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

  call assert_fails('set winminheight=10 winheight=9', 'E591:')
  set winminheight& winheight&
  set winheight=10 winminheight=10
  call assert_fails('set winheight=9', 'E591:')
  set winminheight& winheight&
  call assert_fails('set winminwidth=10 winwidth=9', 'E592:')
  set winminwidth& winwidth&
  call assert_fails('set winwidth=9 winminwidth=10', 'E592:')
  set winwidth& winminwidth&
  call assert_fails("set showbreak=\x01", 'E595:')
  call assert_fails('set t_foo=', 'E846:')
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
  setlocal listchars=trail:·
  call assert_fails('set ambiwidth=double', 'E834:')
  setlocal listchars=trail:-
  setglobal listchars=trail:·
  call assert_fails('set ambiwidth=double', 'E834:')
  set listchars&
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

func Test_set_one_column()
  let out_mult = execute('set all')->split("\n")
  let out_one = execute('set! all')->split("\n")
  " one column should be two to four times as many lines
  call assert_inrange(len(out_mult) * 2, len(out_mult) * 4, len(out_one))
endfunc

func Test_set_values()
  " opt_test.vim is generated from ../optiondefs.h using gen_opt_test.vim
  if filereadable('opt_test.vim')
    source opt_test.vim
  else
    throw 'Skipped: opt_test.vim does not exist'
  endif
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
  setlocal so<
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
  setlocal siso<
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
  call assert_fails('write Xfile', 'E142:')
  set write
  close!
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

" Test for the 'shell' option
func Test_shell()
  throw 'Skipped: Nvim does not have :shell'
  CheckUnix
  let save_shell = &shell
  set shell=
  let caught_e91 = 0
  try
    shell
  catch /E91:/
    let caught_e91 = 1
  endtry
  call assert_equal(1, caught_e91)
  let &shell = save_shell
endfunc

" Test for the 'shellquote' option
func Test_shellquote()
  CheckUnix
  set shellquote=#
  set verbose=20
  redir => v
  silent! !echo Hello
  redir END
  set verbose&
  set shellquote&
  call assert_match(': "#echo Hello#"', v)
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
  call assert_fails('set <t_k1=l', 'E474:')
  call assert_fails('set <Home=l', 'E474:')
  set <t_k9>=abcd
  " call assert_equal('abcd', &t_k9)
  set <t_k9>&
  set <F9>=xyz
  " call assert_equal('xyz', &t_k9)
  set <t_k9>&
endfunc

" Test for changing options in a sandbox
func Test_opt_sandbox()
  for opt in ['backupdir', 'cdpath', 'exrc']
    call assert_fails('sandbox set ' .. opt .. '?', 'E48:')
    call assert_fails('sandbox let &' .. opt .. ' = 1', 'E48:')
  endfor
  call assert_fails('sandbox let &modelineexpr = 1', 'E48:')
endfunc

" Test for setting an option with local value to global value
func Test_opt_local_to_global()
  setglobal equalprg=gprg
  setlocal equalprg=lprg
  call assert_equal('gprg', &g:equalprg)
  call assert_equal('lprg', &l:equalprg)
  call assert_equal('lprg', &equalprg)
  set equalprg<
  call assert_equal('', &l:equalprg)
  call assert_equal('gprg', &equalprg)
  setglobal equalprg=gnewprg
  setlocal equalprg=lnewprg
  setlocal equalprg<
  call assert_equal('gnewprg', &l:equalprg)
  call assert_equal('gnewprg', &equalprg)
  set equalprg&

  " Test for setting the global/local value of a boolean option
  setglobal autoread
  setlocal noautoread
  call assert_false(&autoread)
  set autoread<
  call assert_true(&autoread)
  setglobal noautoread
  setlocal autoread
  setlocal autoread<
  call assert_false(&autoread)
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

" Test for incrementing, decrementing and multiplying a number option value
func Test_opt_num_op()
  set shiftwidth=4
  set sw+=2
  call assert_equal(6, &sw)
  set sw-=2
  call assert_equal(4, &sw)
  set sw^=2
  call assert_equal(8, &sw)
  set shiftwidth&
endfunc

" Test for setting option values using v:false and v:true
func Test_opt_boolean()
  set number&
  set number
  call assert_equal(1, &nu)
  set nonu
  call assert_equal(0, &nu)
  let &nu = v:true
  call assert_equal(1, &nu)
  let &nu = v:false
  call assert_equal(0, &nu)
  set number&
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
endfunc

" Test for the 'cmdheight' option
func Test_cmdheight()
  %bw!
  let ht = &lines
  set cmdheight=9999
  call assert_equal(1, winheight(0))
  call assert_equal(ht - 1, &cmdheight)
  set cmdheight&
endfunc

" To specify a control character as a option value, '^' can be used
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

func Test_set_completion_2()
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

" vim: shiftwidth=2 sts=2 expandtab
