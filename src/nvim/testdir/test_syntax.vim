" Test for syntax and syntax iskeyword option

source view_util.vim

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

  " Check that clearing "Aap" avoids it showing up before Boolean.
  hi Aap ctermfg=blue
  call feedkeys(":syn list \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn list Aap Boolean Character ', @:)
  hi clear Aap

  call feedkeys(":syn list \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn list Boolean Character ', @:)

  call feedkeys(":syn match \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn match Boolean Character ', @:)
endfunc

func Test_syntax_arg_skipped()
  syn clear
  syntax case ignore
  if 0
    syntax case match
  endif
  call assert_match('case ignore', execute('syntax case'))

  syn keyword Foo foo
  call assert_match('Foo', execute('syntax'))
  syn clear
  call assert_match('case match', execute('syntax case'))
  call assert_notmatch('Foo', execute('syntax'))

  if has('conceal')
    syn clear
    syntax conceal on
    if 0
      syntax conceal off
    endif
    call assert_match('conceal on', execute('syntax conceal'))
    syn clear
    call assert_match('conceal off', execute('syntax conceal'))
  endif

  syntax conceal on
  syntax conceal off
  call assert_match('conceal off', execute('syntax conceal'))

  syntax region Bar start=/</ end=/>/
  if 0
    syntax region NotTest start=/</ end=/>/ contains=@Spell
  endif
  call assert_match('Bar', execute('syntax'))
  call assert_notmatch('NotTest', execute('syntax'))
  call assert_notmatch('Spell', execute('syntax'))

  hi Foo ctermfg=blue
  let a = execute('hi Foo')
  if 0
    syntax rest
  endif
  call assert_equal(a, execute('hi Foo'))
  hi clear Bar
  hi clear Foo

  set ft=tags
  syn off
  if 0
    syntax enable
  endif
  call assert_match('No Syntax items defined', execute('syntax'))
  syntax enable
  call assert_match('tagComment', execute('syntax'))
  set ft=

  syn clear
  if 0
    syntax include @Spell nothing
  endif
  call assert_notmatch('Spell', execute('syntax'))

  syn clear
  syn iskeyword 48-57,$,_
  call assert_match('48-57,$,_', execute('syntax iskeyword'))
  if 0
    syn clear
    syn iskeyword clear
  endif
  call assert_match('48-57,$,_', execute('syntax iskeyword'))
  syn iskeyword clear
  call assert_match('not set', execute('syntax iskeyword'))
  syn iskeyword 48-57,$,_
  syn clear
  call assert_match('not set', execute('syntax iskeyword'))

  syn clear
  syn keyword Foo foo
  if 0
    syn keyword NotAdded bar
  endif
  call assert_match('Foo', execute('syntax'))
  call assert_notmatch('NotAdded', execute('highlight'))

  syn clear
  syn keyword Foo foo
  call assert_match('Foo', execute('syntax'))
  call assert_match('Foo', execute('syntax list'))
  call assert_notmatch('Foo', execute('if 0 | syntax | endif'))
  call assert_notmatch('Foo', execute('if 0 | syntax list | endif'))

  syn clear
  syn match Fopi /asdf/
  if 0
    syn match Fopx /asdf/
  endif
  call assert_match('Fopi', execute('syntax'))
  call assert_notmatch('Fopx', execute('syntax'))

  syn clear
  syn spell toplevel
  call assert_match('spell toplevel', execute('syntax spell'))
  if 0
    syn spell notoplevel
  endif
  call assert_match('spell toplevel', execute('syntax spell'))
  syn spell notoplevel
  call assert_match('spell notoplevel', execute('syntax spell'))
  syn spell default
  call assert_match('spell default', execute('syntax spell'))

  syn clear
  if 0
    syntax cluster Spell
  endif
  call assert_notmatch('Spell', execute('syntax'))

  syn clear
  syn keyword Foo foo
  syn sync ccomment
  syn sync maxlines=5
  if 0
    syn sync maxlines=11
  endif
  call assert_match('on C-style comments', execute('syntax sync'))
  call assert_match('maximal 5 lines', execute('syntax sync'))
  syn sync clear
  if 0
    syn sync ccomment
  endif
  call assert_notmatch('on C-style comments', execute('syntax sync'))

  syn clear
endfunc
 
func Test_invalid_arg()
  call assert_fails('syntax case asdf', 'E390:')
  call assert_fails('syntax conceal asdf', 'E390:')
  call assert_fails('syntax spell asdf', 'E390:')
endfunc

func Test_syn_sync()
  syntax region HereGroup start=/this/ end=/that/
  syntax sync match SyncHere grouphere HereGroup "pattern"
  call assert_match('SyncHere', execute('syntax sync'))
  syn sync clear
  call assert_notmatch('SyncHere', execute('syntax sync'))
  syn clear
endfunc

func Test_syn_clear()
  syntax keyword Foo foo
  syntax keyword Bar tar
  call assert_match('Foo', execute('syntax'))
  call assert_match('Bar', execute('syntax'))
  call assert_equal('Foo', synIDattr(hlID("Foo"), "name"))
  syn clear Foo
  call assert_notmatch('Foo', execute('syntax'))
  call assert_match('Bar', execute('syntax'))
  call assert_equal('Foo', synIDattr(hlID("Foo"), "name"))
  syn clear Foo Bar
  call assert_notmatch('Foo', execute('syntax'))
  call assert_notmatch('Bar', execute('syntax'))
  hi clear Foo
  call assert_equal('Foo', synIDattr(hlID("Foo"), "name"))
  hi clear Bar
endfunc

func Test_invalid_name()
  syn clear
  syn keyword Nop yes
  call assert_fails("syntax keyword Wr\x17ong bar", 'E669:')
  syntax keyword @Wrong bar
  call assert_match('W18:', execute('1messages'))
  syn clear
  hi clear Nop
  hi clear @Wrong
endfunc


func Test_conceal()
  if !has('conceal')
    return
  endif

  new
  call setline(1, ['', '123456'])
  syn match test23 "23" conceal cchar=X
  syn match test45 "45" conceal

  set conceallevel=0
  call assert_equal('123456 ', ScreenLines(2, 7)[0])
  call assert_equal([[0, '', 0], [0, '', 0], [0, '', 0], [0, '', 0], [0, '', 0], [0, '', 0]], map(range(1, 6), 'synconcealed(2, v:val)'))

  set conceallevel=1
  call assert_equal('1X 6   ', ScreenLines(2, 7)[0])
  call assert_equal([[0, '', 0], [1, 'X', 1], [1, 'X', 1], [1, ' ', 2], [1, ' ', 2], [0, '', 0]], map(range(1, 6), 'synconcealed(2, v:val)'))

  set conceallevel=1
  set listchars=conceal:Y
  call assert_equal([[0, '', 0], [1, 'X', 1], [1, 'X', 1], [1, 'Y', 2], [1, 'Y', 2], [0, '', 0]], map(range(1, 6), 'synconcealed(2, v:val)'))
  call assert_equal('1XY6   ', ScreenLines(2, 7)[0])

  set conceallevel=2
  call assert_match('1X6    ', ScreenLines(2, 7)[0])
  call assert_equal([[0, '', 0], [1, 'X', 1], [1, 'X', 1], [1, '', 2], [1, '', 2], [0, '', 0]], map(range(1, 6), 'synconcealed(2, v:val)'))

  set conceallevel=3
  call assert_match('16     ', ScreenLines(2, 7)[0])
  call assert_equal([[0, '', 0], [1, '', 1], [1, '', 1], [1, '', 2], [1, '', 2], [0, '', 0]], map(range(1, 6), 'synconcealed(2, v:val)'))

  syn clear
  set conceallevel&
  bw!
endfunc
