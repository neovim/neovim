" Tests for the :source command.

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
endfunc
