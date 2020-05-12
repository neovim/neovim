" Tests for :help! {subject}

func SetUp()
  " v:progpath is …/build/bin/nvim and we need …/build/runtime
  " to be added to &rtp
  let builddir = fnamemodify(exepath(v:progpath), ':h:h')
  let s:rtp = &rtp
  let &rtp .= printf(',%s/runtime', builddir)
endfunc

func TearDown()
  let &rtp = s:rtp
endfunc

func Test_help_tagjump()
  help
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*help.txt\*')
  helpclose

  help |
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*bar\*')
  helpclose

  help "*
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*quotestar\*')
  helpclose

  help ch?ckhealth
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*:checkhealth\*')
  helpclose

  help :?
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*:?\*')
  helpclose

  help q?
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*q?\*')
  call assert_true(expand('<cword>') == 'q?')
  helpclose

  help -?
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*-?\*')
  helpclose

  help v_g?
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*v_g?\*')
  helpclose

  help expr-!=?
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*expr-!=?\*')
  call assert_true(expand('<cword>') == 'expr-!=?')
  helpclose

  help expr-isnot?
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*expr-isnot?\*')
  call assert_true(expand('<cword>') == 'expr-isnot?')
  helpclose

  help FileW*Post
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*FileWritePost\*')
  helpclose

  help `ls`
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*:ls\*')
  helpclose

  help ^X
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*CTRL-X\*')
  helpclose

  help i_^_CTRL-D
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*i_^_CTRL-D\*')
  helpclose

  exec "help \<C-V>"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*CTRL-V\*')
  helpclose


  exec "help! ('textwidth'"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ "\\*'textwidth'\\*")
  helpclose

  exec "help! ('buflisted'),"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ "\\*'buflisted'\\*")
  helpclose

  exec "help! abs({expr})"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*abs()\*')
  helpclose

  exec "help! arglistid([{winnr})"
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*arglistid()\*')
  helpclose

  exec "help! 'autoindent'."
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ "\\*'autoindent'\\*")
  helpclose

  exec "help! {address}."
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*{address}\*')
  helpclose

  exusage
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*:index\*')
  helpclose

  viusage
  call assert_equal("help", &filetype)
  call assert_true(getline('.') =~ '\*normal-index\*')
  helpclose
endfunc

let s:langs = ['en', 'ab', 'ja']

func s:doc_config_setup()
  let s:helpfile_save = &helpfile
  let &helpfile="Xdir1/doc-en/doc/testdoc.txt"
  let s:rtp_save = &rtp
  let &rtp="Xdir1/doc-en"
  if has('multi_lang')
    let s:helplang_save=&helplang
  endif

  call delete('Xdir1', 'rf')

  for lang in s:langs
    if lang ==# 'en'
      let tagfname = 'tags'
      let docfname = 'testdoc.txt'
    else
      let tagfname = 'tags-' . lang
      let docfname = 'testdoc.' . lang . 'x'
    endif
    let docdir = "Xdir1/doc-" . lang . "/doc"
    call mkdir(docdir, "p")
    call writefile(["\t*test-char*", "\t*test-col*"], docdir . '/' . docfname)
    call writefile(["test-char\t" . docfname . "\t/*test-char*",
          \         "test-col\t" . docfname . "\t/*test-col*"],
          \         docdir . '/' . tagfname)
  endfor
endfunc

func s:doc_config_teardown()
  call delete('Xdir1', 'rf')

  let &helpfile = s:helpfile_save
  let &rtp = s:rtp_save
  if has('multi_lang')
    let &helplang = s:helplang_save
  endif
endfunc

func s:get_help_compl_list(cmd)
  return getcompletion(a:cmd, 'help')
endfunc

func Test_help_complete()
  try
    let list = []
    call s:doc_config_setup()

    " 'helplang=' and help file lang is 'en'
    if has('multi_lang')
      set helplang=
    endif
    let list = s:get_help_compl_list("test")
    call assert_equal(['test-col', 'test-char'], list)

    if has('multi_lang')
      " 'helplang=ab' and help file lang is 'en'
      set helplang=ab
      let list = s:get_help_compl_list("test")
      call assert_equal(['test-col', 'test-char'], list)

      " 'helplang=' and help file lang is 'en' and 'ab'
      set rtp+=Xdir1/doc-ab
      set helplang=
      let list = s:get_help_compl_list("test")
      call assert_equal(sort(['test-col@en', 'test-col@ab',
            \             'test-char@en', 'test-char@ab']), sort(list))

      " 'helplang=ab' and help file lang is 'en' and 'ab'
      set helplang=ab
      let list = s:get_help_compl_list("test")
      call assert_equal(sort(['test-col', 'test-col@en',
            \             'test-char', 'test-char@en']), sort(list))

      " 'helplang=' and help file lang is 'en', 'ab' and 'ja'
      set rtp+=Xdir1/doc-ja
      set helplang=
      let list = s:get_help_compl_list("test")
      call assert_equal(sort(['test-col@en', 'test-col@ab',
            \             'test-col@ja', 'test-char@en',
            \             'test-char@ab', 'test-char@ja']), sort(list))

      " 'helplang=ab' and help file lang is 'en', 'ab' and 'ja'
      set helplang=ab
      let list = s:get_help_compl_list("test")
      call assert_equal(sort(['test-col', 'test-col@en',
            \             'test-col@ja', 'test-char',
            \             'test-char@en', 'test-char@ja']), sort(list))

      " 'helplang=ab,ja' and help file lang is 'en', 'ab' and 'ja'
      set helplang=ab,ja
      let list = s:get_help_compl_list("test")
      call assert_equal(sort(['test-col', 'test-col@ja',
            \             'test-col@en', 'test-char',
            \             'test-char@ja', 'test-char@en']), sort(list))
    endif
  catch
    call assert_exception('X')
  finally
    call s:doc_config_teardown()
  endtry
endfunc

func Test_help_respect_current_file_lang()
  try
    let list = []
    call s:doc_config_setup()

    if has('multi_lang')
      function s:check_help_file_ext(help_keyword, ext)
        exec 'help ' . a:help_keyword
        call assert_equal(a:ext, expand('%:e'))
        call feedkeys("\<C-]>", 'tx')
        call assert_equal(a:ext, expand('%:e'))
        pop
        helpclose
      endfunc

      set rtp+=Xdir1/doc-ab
      set rtp+=Xdir1/doc-ja

      set helplang=ab
      call s:check_help_file_ext('test-char', 'abx')
      call s:check_help_file_ext('test-char@ja', 'jax')
      set helplang=ab,ja
      call s:check_help_file_ext('test-char@ja', 'jax')
      call s:check_help_file_ext('test-char@en', 'txt')
    endif
  catch
    call assert_exception('X')
  finally
    call s:doc_config_teardown()
  endtry
endfunc

" vim: shiftwidth=2 sts=2 expandtab
