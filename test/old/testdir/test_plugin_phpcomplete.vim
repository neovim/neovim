" Tests for the PHP omni-completion plugin (runtime/autoload/phpcomplete.vim).

" A buffer class name is interpolated into a search() pattern run via
" win_execute().  Without escaping, "'" closes the string and "|" starts a new
" Ex command, so the name runs as an Ex command during completion.
func Test_phpcomplete_no_exec_via_class_name()
  unlet! g:phpcomplete_injected
  let lines = ['<?php', 'class x {}', '']
  let payload = "x')|let g:phpcomplete_injected = 1|call search('"

  try
    call phpcomplete#GetClassContentsStructure('x.php', lines, payload)
  catch
  endtry

  call assert_false(exists('g:phpcomplete_injected'),
        \ 'class name was executed as an Ex command during completion')

  unlet! g:phpcomplete_injected
endfunc

func Test_phpcomplete_class_lookup_still_works()
  let lines = ['<?php', 'class Foo {', '    public $bar;', '}', '']
  let result = phpcomplete#GetClassContentsStructure('Foo.php', lines, 'Foo')

  call assert_equal(type([]), type(result),
        \ 'GetClassContentsStructure did not return a list')
  call assert_true(len(result) > 0, 'no class structure returned')
  call assert_match('class Foo', result[0].content,
        \ 'class body missing from returned content')
  call assert_match('bar', result[0].content,
        \ 'class member missing from returned content')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
