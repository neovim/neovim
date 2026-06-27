" Tests for the C omni-completion plugin (runtime/autoload/ccomplete.vim).

func s:WriteTags(lines)
  " Mark unsorted so lookup is a linear scan regardless of entry order.
  let tagsfile = tempname()
  call writefile(["!_TAG_FILE_SORTED\t0\t/0/"] + a:lines, tagsfile)
  return tagsfile
endfunc

" A crafted typeref field is interpolated into the :vimgrep pattern in
" StructMembers().  Without escaping, "/" closes the pattern and "|" starts a
" new Ex command, so the field runs as an Ex command during completion.
func Test_ccomplete_no_exec_via_typeref()
  unlet! g:ccomplete_injected
  let tagsfile = s:WriteTags([
        \ "myvar\tmain.c\t/^x$/;\"\tv\ttyperef:x/|let g:ccomplete_injected = 1|\"",
        \ ])

  let save_tags = &tags
  let &tags = tagsfile

  new
  call ccomplete#Complete(1, '')
  call ccomplete#Complete(0, 'myvar.x')

  call assert_false(exists('g:ccomplete_injected'),
        \ 'typeref field was executed as an Ex command during omni-completion')

  bwipe!
  let &tags = save_tags
  unlet! g:ccomplete_injected
endfunc

" A legitimate typeref must still drive struct-member completion: escaping the
" field value must not break the normal path.
func Test_ccomplete_typeref_completion_still_works()
  let tagsfile = s:WriteTags([
        \ "myvar\tmain.c\t/^x$/;\"\tv\ttyperef:struct:mystruct",
        \ "alpha\tmain.c\t/^x$/;\"\tm\tstruct:mystruct",
        \ "beta\tmain.c\t/^x$/;\"\tm\tstruct:mystruct",
        \ ])

  let save_tags = &tags
  let &tags = tagsfile

  new
  call ccomplete#Complete(1, '')
  let items = ccomplete#Complete(0, 'myvar.')

  call assert_equal(type([]), type(items),
        \ 'ccomplete#Complete did not return a list')
  let names = map(copy(items), 'v:val.word')
  call assert_true(index(names, 'alpha') >= 0,
        \ 'struct member "alpha" missing from completion: ' . string(names))
  call assert_true(index(names, 'beta') >= 0,
        \ 'struct member "beta" missing from completion: ' . string(names))

  bwipe!
  let &tags = save_tags
endfunc

" vim: shiftwidth=2 sts=2 expandtab
