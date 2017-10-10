" Test for syntax and syntax iskeyword option

func GetSyntaxItem(pat)
  let c = ''
  let a = ['a', getreg('a'), getregtype('a')]
  0
  redraw!
  call search(a:pat, 'W')
  let synid = synID(line('.'), col('.'), 1)
  while synid == synID(line('.'), col('.'), 1)
    norm! v"ay
    " stop at whitespace
    if @a =~# '\s'
      break
    endif
    let c .= @a
    norm! l
  endw
  call call('setreg', a)
  0
  return c
endfunc

func Test_syn_iskeyword()
  new
  call setline(1, [
	\ 'CREATE TABLE FOOBAR(',
	\ '    DLTD_BY VARCHAR2(100)',
	\ ');',
  	\ ''])

  syntax on
  set ft=sql
  syn match SYN /C\k\+\>/
  hi link SYN ErrorMsg
  call assert_equal('DLTD_BY', GetSyntaxItem('DLTD'))
  /\<D\k\+\>/:norm! ygn
  call assert_equal('DLTD_BY', @0)
  redir @c
  syn iskeyword
  redir END
  call assert_equal("\nsyntax iskeyword not set", @c)

  syn iskeyword @,48-57,_,192-255
  redir @c
  syn iskeyword
  redir END
  call assert_equal("\nsyntax iskeyword @,48-57,_,192-255", @c)

  setlocal isk-=_
  call assert_equal('DLTD_BY', GetSyntaxItem('DLTD'))
  /\<D\k\+\>/:norm! ygn
  let b2 = @0
  call assert_equal('DLTD', @0)

  syn iskeyword clear
  redir @c
  syn iskeyword
  redir END
  call assert_equal("\nsyntax iskeyword not set", @c)

  quit!
endfunc

func Test_syntax_after_reload()
  split Xsomefile
  call setline(1, ['hello', 'there'])
  w!
  only!
  setl filetype=hello
  au FileType hello let g:gotit = 1
  call assert_false(exists('g:gotit'))
  edit other
  buf Xsomefile
  call assert_equal('hello', &filetype)
  call assert_true(exists('g:gotit'))
  call delete('Xsomefile')
endfunc

func Test_syntime()
  if !has('profile')
    return
  endif

  syntax on
  syntime on
  let a = execute('syntime report')
  call assert_equal("\nNo Syntax items defined for this buffer", a)

  view ../memfile_test.c
  setfiletype cpp
  redraw
  let a = execute('syntime report')
  call assert_match('^  TOTAL *COUNT *MATCH *SLOWEST *AVERAGE *NAME *PATTERN', a)
  call assert_match(' \d*\.\d* \+[^0]\d* .* cppRawString ', a)
  call assert_match(' \d*\.\d* \+[^0]\d* .* cppNumber ', a)

  syntime off
  syntime clear
  let a = execute('syntime report')
  call assert_match('^  TOTAL *COUNT *MATCH *SLOWEST *AVERAGE *NAME *PATTERN', a)
  call assert_notmatch('.* cppRawString *', a)
  call assert_notmatch('.* cppNumber*', a)
  call assert_notmatch('[1-9]', a)

  call assert_fails('syntime abc', 'E475')

  syntax clear
  let a = execute('syntime report')
  call assert_equal("\nNo Syntax items defined for this buffer", a)

  bd
endfunc

func Test_syntax_list()
  syntax on
  let a = execute('syntax list')
  call assert_equal("\nNo Syntax items defined for this buffer", a)

  view ../memfile_test.c
  setfiletype c

  let a = execute('syntax list')
  call assert_match('cInclude*', a)
  call assert_match('cDefine', a)

  let a = execute('syntax list cDefine')
  call assert_notmatch('cInclude*', a)
  call assert_match('cDefine', a)
  call assert_match(' links to Macro$', a)

  call assert_fails('syntax list ABCD', 'E28:')
  call assert_fails('syntax list @ABCD', 'E392:')

  syntax clear
  let a = execute('syntax list')
  call assert_equal("\nNo Syntax items defined for this buffer", a)

  bd
endfunc

func Test_syntax_completion()
  call feedkeys(":syn \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syn case clear cluster conceal enable include iskeyword keyword list manual match off on region reset spell sync', @:)

  call feedkeys(":syn case \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syn case ignore match', @:)

  call feedkeys(":syn spell \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syn spell default notoplevel toplevel', @:)

  call feedkeys(":syn sync \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syn sync ccomment clear fromstart linebreaks= linecont lines= match maxlines= minlines= region', @:)

  call feedkeys(":syn list \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn list Boolean Character ', @:)

  call feedkeys(":syn match \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn match Boolean Character ', @:)
endfunc