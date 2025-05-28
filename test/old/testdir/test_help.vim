" Tests for :help

source check.vim
source vim9.vim

func SetUp()
  let s:vimruntime = $VIMRUNTIME
  let s:runtimepath = &runtimepath
  " Set $VIMRUNTIME to $BUILD_DIR/runtime and remove the original $VIMRUNTIME
  " path from &runtimepath so that ":h local-additions" won't pick up builtin
  " help files.
  let $VIMRUNTIME = expand($BUILD_DIR) .. '/runtime'
  set runtimepath-=../../../runtime
endfunc

func TearDown()
  let $VIMRUNTIME = s:vimruntime
  let &runtimepath = s:runtimepath
endfunc

func Test_help_restore_snapshot()
  help
  set buftype=
  help
  edit x
  help
  helpclose
endfunc

func Test_help_restore_snapshot_split()
  " Squeeze the unnamed buffer, Xfoo and the help one side-by-side and focus
  " the first one before calling :help.
  let bnr = bufnr()
  botright vsp Xfoo
  wincmd h
  help
  wincmd L
  let g:did_bufenter = v:false
  augroup T
    au!
    au BufEnter Xfoo let g:did_bufenter = v:true
  augroup END
  helpclose
  augroup! T
  " We're back to the unnamed buffer.
  call assert_equal(bnr, bufnr())
  " No BufEnter was triggered for Xfoo.
  call assert_equal(v:false, g:did_bufenter)

  close!
  bwipe!
endfunc

func Test_help_errors()
  call assert_fails('help doesnotexist', 'E149:')
  call assert_fails('help!', 'E478:')
  if has('multi_lang')
    call assert_fails('help help@xy', 'E661:')
  endif

  let save_hf = &helpfile
  set helpfile=help_missing
  help
  call assert_equal(1, winnr('$'))
  call assert_notequal('help', &buftype)
  let &helpfile = save_hf

  call assert_fails('help ' . repeat('a', 1048), 'E149:')

  new
  set keywordprg=:help
  call setline(1, "   ")
  call assert_fails('normal VK', 'E349:')
  bwipe!
endfunc

func Test_help_expr()
  help expr-!~?
  call assert_equal('vimeval.txt', expand('%:t'))
  close
endfunc

func Test_help_keyword()
  new
  set keywordprg=:help
  call setline(1, "  Visual ")
  normal VK
  call assert_match('^Visual mode', getline('.'))
  call assert_equal('help', &ft)
  close
  bwipe!
endfunc

func Test_help_local_additions()
  call mkdir('Xruntime/doc', 'p')
  call writefile(['*mydoc.txt* my awesome doc'], 'Xruntime/doc/mydoc.txt')
  call writefile(['*mydoc-ext.txt* my extended awesome doc'], 'Xruntime/doc/mydoc-ext.txt')
  let rtp_save = &rtp
  set rtp+=./Xruntime
  help local-additions
  let lines = getline(line(".") + 1, search("^$") - 1)
  call assert_equal([
  \ '|mydoc-ext.txt| my extended awesome doc',
  \ '|mydoc.txt| my awesome doc'
  \ ], lines)
  call delete('Xruntime/doc/mydoc-ext.txt')
  close

  call mkdir('Xruntime-ja/doc', 'p')
  call writefile(["local-additions\thelp.jax\t/*local-additions*"], 'Xruntime-ja/doc/tags-ja')
  call writefile(['*help.txt* This is jax file', '',
  \ 'LOCAL ADDITIONS: *local-additions*', ''], 'Xruntime-ja/doc/help.jax')
  call writefile(['*work.txt* This is jax file'], 'Xruntime-ja/doc/work.jax')
  call writefile(['*work2.txt* This is jax file'], 'Xruntime-ja/doc/work2.jax')
  set rtp+=./Xruntime-ja

  help local-additions@en
  let lines = getline(line(".") + 1, search("^$") - 1)
  call assert_equal([
  \ '|mydoc.txt| my awesome doc'
  \ ], lines)
  close

  help local-additions@ja
  let lines = getline(line(".") + 1, search("^$") - 1)
  call assert_equal([
  \ '|mydoc.txt| my awesome doc',
  \ '|help.txt| This is jax file',
  \ '|work.txt| This is jax file',
  \ '|work2.txt| This is jax file',
  \ ], lines)
  close

  call delete('Xruntime', 'rf')
  call delete('Xruntime-ja', 'rf')
  let &rtp = rtp_save
endfunc

func Test_help_completion()
  call feedkeys(":help :undo\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"help :undo :undoj :undol :undojoin :undolist', @:)
endfunc

" Test for the :helptags command
" NOTE: if you run tests as root this will fail.  Don't run tests as root!
func Test_helptag_cmd()
  call mkdir('Xdir/a/doc', 'p')

  " No help file to process in the directory
  call assert_fails('helptags Xdir', 'E151:')

  call writefile([], 'Xdir/a/doc/sample.txt')

  " Test for ++t argument
  helptags ++t Xdir
  call assert_equal(["help-tags\ttags\t1"], readfile('Xdir/tags'))
  call delete('Xdir/tags')

  " Test parsing tags
  call writefile(['*tag1*', 'Example: >', '  *notag*', 'Example end: *tag2*'],
    \ 'Xdir/a/doc/sample.txt')
  helptags Xdir
  call assert_equal(["tag1\ta/doc/sample.txt\t/*tag1*",
                  \  "tag2\ta/doc/sample.txt\t/*tag2*"], readfile('Xdir/tags'))

  " Duplicate tags in the help file
  call writefile(['*tag1*', '*tag1*', '*tag2*'], 'Xdir/a/doc/sample.txt')
  call assert_fails('helptags Xdir', 'E154:')

  call delete('Xdir', 'rf')
endfunc

func Test_helptag_cmd_readonly()
  CheckUnix
  CheckNotRoot

  " Read-only tags file
  call mkdir('Xdir/doc', 'p')
  call writefile([''], 'Xdir/doc/tags')
  call writefile([], 'Xdir/doc/sample.txt')
  call setfperm('Xdir/doc/tags', 'r-xr--r--')
  call assert_fails('helptags Xdir/doc', 'E152:', getfperm('Xdir/doc/tags'))

  let rtp = &rtp
  let &rtp = 'Xdir'
  helptags ALL
  let &rtp = rtp

  call delete('Xdir/doc/tags')

  " No permission to read the help file
  call mkdir('Xdir/b/doc', 'p')
  call writefile([], 'Xdir/b/doc/sample.txt')
  call setfperm('Xdir/b/doc/sample.txt', '-w-------')
  call assert_fails('helptags Xdir', 'E153:', getfperm('Xdir/b/doc/sample.txt'))
  call delete('Xdir', 'rf')
endfunc

" Test for setting the 'helpheight' option in the help window
func Test_help_window_height()
  let &cmdheight = &lines - 23
  set helpheight=10
  help
  set helpheight=14
  call assert_equal(14, winheight(0))
  set helpheight& cmdheight=1
  close
endfunc

func Test_help_long_argument()
  try
    exe 'help \%' .. repeat('0', 1021)
  catch
    call assert_match("E149:", v:exception)
  endtry
endfunc

func Test_help_using_visual_match()
  let lines =<< trim END
      call setline(1, ' ')
      /^
      exe "normal \<C-V>\<C-V>"
      h5\%V]
  END
  call CheckScriptFailure(lines, 'E149:')
endfunc

func Test_helptag_navigation()
  let helpdir = tempname()
  let tempfile = helpdir . '/test.txt'
  call mkdir(helpdir, 'pR')
  call writefile(['', '*[tag*', '', '|[tag|'], tempfile)
  exe 'helptags' helpdir
  exe 'sp' tempfile
  exe 'lcd' helpdir
  setl ft=help
  let &l:iskeyword='!-~,^*,^|,^",192-255'
  call cursor(4, 2)
  " Vim must not escape `[` when expanding the tag
  exe "normal! \<C-]>"
  call assert_equal(2, line('.'))
  bw
endfunc


" vim: shiftwidth=2 sts=2 expandtab
