" Tests for the :source command.

source check.vim
source view_util.vim

func Test_source_autocmd()
  call writefile([
	\ 'let did_source = 1',
	\ ], 'Xsourced')
  au SourcePre *source* let did_source_pre = 1
  au SourcePost *source* let did_source_post = 1

  source Xsourced

  call assert_equal(g:did_source, 1)
  call assert_equal(g:did_source_pre, 1)
  call assert_equal(g:did_source_post, 1)

  call delete('Xsourced')
  au! SourcePre
  au! SourcePost
  unlet g:did_source
  unlet g:did_source_pre
  unlet g:did_source_post
endfunc

func Test_source_cmd()
  au SourceCmd *source* let did_source = expand('<afile>')
  au SourcePre *source* let did_source_pre = 2
  au SourcePost *source* let did_source_post = 2

  source Xsourced

  call assert_equal(g:did_source, 'Xsourced')
  call assert_false(exists('g:did_source_pre'))
  call assert_equal(g:did_source_post, 2)

  au! SourceCmd
  au! SourcePre
  au! SourcePost
endfunc

func Test_source_sandbox()
  new
  call writefile(["Ohello\<Esc>"], 'Xsourcehello')
  source! Xsourcehello | echo
  call assert_equal('hello', getline(1))
  call assert_fails('sandbox source! Xsourcehello', 'E48:')
  bwipe!
  call delete('Xsourcehello')
endfunc

" When deleting a file and immediately creating a new one the inode may be
" recycled.  Vim should not recognize it as the same script.
func Test_different_script()
  call writefile(['let s:var = "asdf"'], 'XoneScript', 'D')
  source XoneScript
  call writefile(['let g:var = s:var'], 'XtwoScript', 'D')
  call assert_fails('source XtwoScript', 'E121:')
endfunc

" When sourcing a vim script, shebang should be ignored.
func Test_source_ignore_shebang()
  call writefile(['#!./xyzabc', 'let g:val=369'], 'Xfile.vim')
  source Xfile.vim
  call assert_equal(g:val, 369)
  call delete('Xfile.vim')
endfunc

" Test for expanding <sfile> in a autocmd and for <slnum> and <sflnum>
func Test_source_autocmd_sfile()
  let code =<< trim [CODE]
    let g:SfileName = ''
    augroup sfiletest
      au!
      autocmd User UserAutoCmd let g:Sfile = '<sfile>:t'
    augroup END
    doautocmd User UserAutoCmd
    let g:Slnum = expand('<slnum>')
    let g:Sflnum = expand('<sflnum>')
    augroup! sfiletest
  [CODE]
  call writefile(code, 'Xscript.vim')
  source Xscript.vim
  call assert_equal('Xscript.vim', g:Sfile)
  call assert_equal('7', g:Slnum)
  call assert_equal('8', g:Sflnum)
  call delete('Xscript.vim')
endfunc

func Test_source_error()
  call assert_fails('scriptencoding utf-8', 'E167:')
  call assert_fails('finish', 'E168:')
  " call assert_fails('scriptversion 2', 'E984:')
endfunc

" Test for sourcing a script recursively
func Test_nested_script()
  CheckRunVimInTerminal
  call writefile([':source! Xscript.vim', ''], 'Xscript.vim')
  let buf = RunVimInTerminal('', {'rows': 6})
  call term_wait(buf)
  call term_sendkeys(buf, ":set noruler\n")
  call term_sendkeys(buf, ":source! Xscript.vim\n")
  call term_wait(buf)
  call WaitForAssert({-> assert_match('E22: Scripts nested too deep\s*', term_getline(buf, 6))})
  call delete('Xscript.vim')
  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
