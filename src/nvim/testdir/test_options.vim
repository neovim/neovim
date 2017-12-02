" Test for options

function! Test_whichwrap()
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

  set whichwrap&
endfunction

function! Test_options()
  let caught = 'ok'
  try
    options
  catch
    let caught = v:throwpoint . "\n" . v:exception
  endtry
  call assert_equal('ok', caught)

  " close option-window
  close
endfunction

function! Test_path_keep_commas()
  " Test that changing 'path' keeps two commas.
  set path=foo,,bar
  set path-=bar
  set path+=bar
  call assert_equal('foo,,bar', &path)

  set path&
endfunction

func Test_filetype_valid()
  if !has('autocmd')
    return
  endif
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

func Test_dictionary()
  call Check_dir_option('dictionary')
endfunc

func Test_thesaurus()
  call Check_dir_option('thesaurus')
endfun

func Test_set_completion()
  call feedkeys(":set di\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set dictionary diff diffexpr diffopt digraph directory display', @:)

  " Expand boolan options. When doing :set no<Tab>
  " vim displays the options names without "no" but completion uses "no...".
  call feedkeys(":set nodi\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set nodiff digraph', @:)

  call feedkeys(":set invdi\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set invdiff digraph', @:)

  " Expand abbreviation of options.
  call feedkeys(":set ts\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set tabstop thesaurus', @:)

  " Expand current value
  call feedkeys(":set fileencodings=\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set fileencodings=ucs-bom,utf-8,default,latin1', @:)

  call feedkeys(":set fileencodings:\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set fileencodings:ucs-bom,utf-8,default,latin1', @:)

  " Expand directories.
  call feedkeys(":set cdpath=./\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match(' ./samples/ ', @:)
  call assert_notmatch(' ./small.vim ', @:)

  " Expand files and directories.
  call feedkeys(":set tags=./\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('./samples/ ./sautest/ ./setup.vim ./shared.vim', @:)

  call feedkeys(":set tags=./\\\\ dif\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"set tags=./\\ diff diffexpr diffopt', @:)
endfunc

func Test_set_errors()
  call assert_fails('set scroll=-1', 'E49:')
  call assert_fails('set backupcopy=', 'E474:')
  call assert_fails('set regexpengine=3', 'E474:')
  call assert_fails('set history=10001', 'E474:')
  call assert_fails('set numberwidth=11', 'E474:')
  call assert_fails('set colorcolumn=-a')
  call assert_fails('set colorcolumn=a')
  call assert_fails('set colorcolumn=1,')
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
  call assert_fails('set complete=x', 'E539:')
  call assert_fails('set statusline=%{', 'E540:')
  call assert_fails('set statusline=' . repeat("%p", 81), 'E541:')
  call assert_fails('set statusline=%(', 'E542:')
  call assert_fails('set guicursor=x', 'E545:')
  call assert_fails('set backupext=~ patchmode=~', 'E589:')
  call assert_fails('set winminheight=10 winheight=9', 'E591:')
  call assert_fails('set winminwidth=10 winwidth=9', 'E592:')
  call assert_fails("set showbreak=\x01", 'E595:')
  call assert_fails('set t_foo=', 'E846:')
endfunc

func Test_complete()
  " Trailing single backslash used to cause invalid memory access.
  set complete=s\
  new
  call feedkeys("i\<C-N>\<Esc>", 'xt')
  bwipe!
  set complete&
endfun

