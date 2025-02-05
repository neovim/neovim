" Test for syntax and syntax iskeyword option

source check.vim
CheckFeature syntax

source view_util.vim
source screendump.vim

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

func AssertHighlightGroups(lnum, startcol, expected, trans = 1, msg = "")
  " Assert that the characters starting at a given (line, col)
  " sequentially match the expected highlight groups.
  " If groups are provided as a string, each character is assumed to be a
  " group and spaces represent no group, useful for visually describing tests.
  let l:expectedGroups = type(a:expected) == v:t_string
        \ ? a:expected->split('\zs')->map({_, v -> trim(v)})
        \ : a:expected
  let l:errors = 0
  let l:msg = (a:msg->empty() ? "" : a:msg .. ": ")
        \ .. "Wrong highlight group at " .. a:lnum .. ","

  for l:i in range(a:startcol, a:startcol + l:expectedGroups->len() - 1)
    let l:errors += synID(a:lnum, l:i, a:trans)
          \ ->synIDattr("name")
          \ ->assert_equal(l:expectedGroups[l:i - 1],
          \    l:msg .. l:i)
  endfor
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

  let a = execute('syntime clear')
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

func Test_syntime_completion()
  if !has('profile')
    return
  endif

  call feedkeys(":syntime \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syntime clear off on report', @:)
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

  syntax keyword Type int containedin=g1 skipwhite skipempty skipnl nextgroup=Abc
  let exp = "Type           xxx containedin=g1  nextgroup=Abc  skipnl skipwhite skipempty int"
  call assert_equal(exp, split(execute("syntax list"), "\n")[1])

  bd
endfunc

func Test_syntax_completion()
  call feedkeys(":syn \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syn case clear cluster conceal enable foldlevel include iskeyword keyword list manual match off on region reset spell sync', @:)

  call feedkeys(":syn case \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syn case ignore match', @:)

  call feedkeys(":syn spell \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syn spell default notoplevel toplevel', @:)

  call feedkeys(":syn sync \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"syn sync ccomment clear fromstart linebreaks= linecont lines= match maxlines= minlines= region', @:)

  " Check that clearing "Aap" avoids it showing up before Boolean.
  hi @Aap ctermfg=blue
  call feedkeys(":syn list \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn list @Aap @attribute @attribute.builtin @boolean @character ', @:)
  hi clear @Aap

  call feedkeys(":syn list \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn list @attribute @attribute.builtin @boolean @character ', @:)

  call feedkeys(":syn match \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn match @attribute @attribute.builtin @boolean @character ', @:)

  syn cluster Aax contains=Aap
  call feedkeys(":syn list @A\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"syn list @Aax', @:)
endfunc

func Test_echohl_completion()
  call feedkeys(":echohl no\<C-A>\<C-B>\"\<CR>", 'tx')
  " call assert_equal('"echohl NonText Normal none', @:)
  call assert_equal('"echohl NonText Normal NormalFloat NormalNC none', @:)
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
  syn sync fromstart
  call assert_match('syncing starts at the first line', execute('syntax sync'))

  syn clear
endfunc

" Check for an error. Used when multiple errors are thrown and we are checking
" for an earliest error.
func AssertFails(cmd, errcode)
  let save_exception = ''
  try
    exe a:cmd
  catch
    let save_exception = v:exception
  endtry
  call assert_match(a:errcode, save_exception)
endfunc

func Test_syntax_invalid_arg()
  call assert_fails('syntax case asdf', 'E390:')
  if has('conceal')
    call assert_fails('syntax conceal asdf', 'E390:')
  endif
  call assert_fails('syntax spell asdf', 'E390:')
  call assert_fails('syntax clear @ABCD', 'E391:')
  call assert_fails('syntax include random_file', 'E484:')
  call assert_fails('syntax include <afile>', 'E495:')
  call assert_fails('syntax sync x', 'E404:')
  call assert_fails('syntax keyword Abc a[', 'E789:')
  call assert_fails('syntax keyword Abc a[bc]d', 'E890:')
  call assert_fails('syntax cluster Abc add=A add=', 'E406:')

  " Test for too many \z\( and unmatched \z\(
  " Not able to use assert_fails() here because both E50:/E879: and E475:
  " messages are emitted.
  set regexpengine=1
  call AssertFails("syntax region MyRegion start='\\z\\(' end='\\*/'", 'E52:')

  let cmd = "syntax region MyRegion start='"
  let cmd ..= repeat("\\z\\(.\\)", 10) .. "' end='\*/'"
  call AssertFails(cmd, 'E50:')

  set regexpengine=2
  call AssertFails("syntax region MyRegion start='\\z\\(' end='\\*/'", 'E54:')

  let cmd = "syntax region MyRegion start='"
  let cmd ..= repeat("\\z\\(.\\)", 10) .. "' end='\*/'"
  call AssertFails(cmd, 'E879:')
  set regexpengine&

  call AssertFails('syntax keyword cMyItem grouphere G1', 'E393:')
  call AssertFails('syntax sync match Abc grouphere MyItem "abc"', 'E394:')
  call AssertFails('syn keyword Type contains int', 'E395:')
  call assert_fails('syntax include @Xxx', 'E397:')
  call AssertFails('syntax region X start', 'E398:')
  call assert_fails('syntax region X start="{"', 'E399:')
  call AssertFails('syntax cluster contains=Abc', 'E400:')
  call AssertFails("syntax match Character /'.'", 'E401:')
  call AssertFails("syntax match Character /'.'/a", 'E402:')
  call assert_fails('syntax sync linecont /\%(/', 'E53:')
  call assert_fails('syntax sync linecont /pat', 'E404:')
  call assert_fails('syntax sync linecont', 'E404:')
  call assert_fails('syntax sync linecont /pat1/ linecont /pat2/', 'E403:')
  call assert_fails('syntax sync minlines=a', 'E404:')
  call AssertFails('syntax match ABC /x/ contains=', 'E406:')
  call AssertFails("syntax match Character contains /'.'/", 'E405:')
  call AssertFails('syntax match ccFoo "Foo" nextgroup=ALLBUT,F', 'E407:')
  call AssertFails('syntax region Block start="{" contains=F,ALLBUT', 'E408:')
  call AssertFails("syntax match Characters contains=a.*x /'.'/", 'E409:')
  call assert_fails('syntax match Search /abc/ contains=ALLBUT,/\%(/', 'E53:')
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
  call assert_fails('syntax clear invalid_syngroup', 'E28:')
endfunc

func Test_invalid_name()
  syn clear
  syn keyword Nop yes
  call assert_fails("syntax keyword Wr\x17ong bar", 'E669:')
  syntax keyword @Wrong bar
  call assert_fails("syntax keyword @#Wrong bar", 'E5248:')
  syn clear
  hi clear Nop
  hi clear @Wrong
endfunc

func Test_ownsyntax()
  new XfooOwnSyntax
  call setline(1, '#define FOO')
  syntax on
  set filetype=c

  ownsyntax perl
  " this should not crash
  set

  call assert_equal('perlComment', synIDattr(synID(line('.'), col('.'), 1), 'name'))
  call assert_equal('c',    b:current_syntax)
  call assert_equal('perl', w:current_syntax)

  " A new split window should have the original syntax.
  split
  call assert_equal('cDefine', synIDattr(synID(line('.'), col('.'), 1), 'name'))
  call assert_equal('c', b:current_syntax)
  call assert_equal(0, exists('w:current_syntax'))

  wincmd x
  call assert_equal('perlComment', synIDattr(synID(line("."), col("."), 1), "name"))

  syntax off
  set filetype&
  %bw!
endfunc

func Test_ownsyntax_completion()
  call feedkeys(":ownsyntax java\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"ownsyntax java javacc javascript javascriptreact', @:)
endfunc

func Test_highlight_invalid_arg()
  if has('gui_running')
    call assert_fails('hi XXX guifg=xxx', 'E254:')
  endif
  call assert_fails('hi DoesNotExist', 'E411:')
  call assert_fails('hi link', 'E412:')
  call assert_fails('hi link a', 'E412:')
  call assert_fails('hi link a b c', 'E413:')
  call assert_fails('hi XXX =', 'E415:')
  call assert_fails('hi XXX cterm', 'E416:')
  call assert_fails('hi XXX cterm=', 'E417:')
  call assert_fails('hi XXX cterm=DoesNotExist', 'E418:')
  call assert_fails('hi XXX ctermfg=DoesNotExist', 'E421:')
  call assert_fails('hi XXX xxx=White', 'E423:')
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

  call AssertFails("syntax match Entity '&amp;' conceal cchar=\<Tab>", 'E844:')

  syn clear
  set conceallevel&
  bw!
endfunc

func Test_bg_detection()
  CheckNotGui

  " auto-detection of &bg, make sure it isn't set anywhere before this test
  hi Normal ctermbg=0
  call assert_equal('dark', &bg)
  hi Normal ctermbg=4
  call assert_equal('dark', &bg)
  hi Normal ctermbg=12
  call assert_equal('light', &bg)
  hi Normal ctermbg=15
  call assert_equal('light', &bg)

  " manually-set &bg takes precedence over auto-detection
  set bg=light
  hi Normal ctermbg=4
  call assert_equal('light', &bg)
  set bg=dark
  hi Normal ctermbg=12
  call assert_equal('dark', &bg)

  hi Normal ctermbg=NONE
endfunc

func Test_syntax_hangs()
  if !has('reltime') || !has('float') || !has('syntax')
    return
  endif

  " This pattern takes a long time to match, it should timeout.
  new
  call setline(1, ['aaa', repeat('abc ', 1000), 'ccc'])
  let start = reltime()
  set nolazyredraw redrawtime=101
  syn match Error /\%#=1a*.*X\@<=b*/
  redraw
  let elapsed = reltimefloat(reltime(start))
  call assert_true(elapsed > 0.1)
  call assert_true(elapsed < 1.0)

  " second time syntax HL is disabled
  let start = reltime()
  redraw
  let elapsed = reltimefloat(reltime(start))
  call assert_true(elapsed < 0.1)

  " after CTRL-L the timeout flag is reset
  let start = reltime()
  exe "normal \<C-L>"
  redraw
  let elapsed = reltimefloat(reltime(start))
  call assert_true(elapsed > 0.1)
  call assert_true(elapsed < 1.0)

  set redrawtime&
  bwipe!
endfunc

func Test_synstack_synIDtrans()
  new
  setfiletype c
  syntax on
  call setline(1, ' /* A comment with a TODO */')

  call assert_equal([], synstack(1, 1))

  norm f/
  eval synstack(line("."), col("."))->map('synIDattr(v:val, "name")')->assert_equal(['cComment', 'cCommentStart'])
  eval synstack(line("."), col("."))->map('synIDattr(synIDtrans(v:val), "name")')->assert_equal(['Comment', 'Comment'])

  norm fA
  call assert_equal(['cComment'], map(synstack(line("."), col(".")), 'synIDattr(v:val, "name")'))
  call assert_equal(['Comment'],  map(synstack(line("."), col(".")), 'synIDattr(synIDtrans(v:val), "name")'))

  norm fT
  call assert_equal(['cComment', 'cTodo'], map(synstack(line("."), col(".")), 'synIDattr(v:val, "name")'))
  call assert_equal(['Comment', 'Todo'],   map(synstack(line("."), col(".")), 'synIDattr(synIDtrans(v:val), "name")'))

  call assert_fails("let n=synIDtrans([])", 'E745:')

  syn clear
  bw!
endfunc

" Check highlighting for a small piece of C code with a screen dump.
func Test_syntax_c()
  CheckRunVimInTerminal
  call writefile([
	\ '/* comment line at the top */',
	\ 'int main(int argc, char **argv) { // another comment',
	\ '#if 0',
	\ '   int   not_used;',
	\ '#else',
	\ '   int   used;',
	\ '#endif',
	\ '   printf("Just an example piece of C code\n");',
	\ '   return 0x0ff;',
	\ '}',
	\ "\t\t ",
	\ '   static void',
	\ 'myFunction(const double count, struct nothing, long there) {',
	\ "\t// 123: nothing to endif here",
	\ "\tfor (int i = 0; i < count; ++i) {",
	\ "\t   break;",
	\ "\t}",
	\ "\tNote: asdf",
	\ '}',
	\ ], 'Xtest.c', 'D')

  " This makes the default for 'background' use "dark", check that the
  " response to t_RB corrects it to "light".
  let $COLORFGBG = '15;0'

  let buf = RunVimInTerminal('Xtest.c', {})
  call term_sendkeys(buf, ":syn keyword Search Note\r")
  call VerifyScreenDump(buf, 'Test_syntax_c_01', {})
  call StopVimInTerminal(buf)

  let $COLORFGBG = ''
endfun

" Test \z(...) along with \z1
func Test_syn_zsub()
  new
  syntax on
  call setline(1,  'xxx start foo xxx not end foo xxx end foo xxx')
  let l:expected = '    ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ    '

  for l:re in [0, 1, 2]
    " Example taken from :help :syn-ext-match
    syntax region Z start="start \z(\I\i*\)" skip="not end \z1" end="end \z1"
    eval AssertHighlightGroups(1, 1, l:expected, 1, 'regexp=' .. l:re)
    syntax clear Z
  endfor

  set re&
  bw!
endfunc

" Using \z() in a region with NFA failing should not crash.
func Test_syn_wrong_z_one()
  new
  call setline(1, ['just some text', 'with foo and bar to match with'])
  syn region FooBar start="foo\z(.*\)bar" end="\z1"
  " call test_override("nfa_fail", 1)
  redraw!
  redraw!
  " call test_override("ALL", 0)
  bwipe!
endfunc

func Test_syntax_after_bufdo()
  call writefile(['/* aaa comment */'], 'Xaaa.c', 'D')
  call writefile(['/* bbb comment */'], 'Xbbb.c', 'D')
  call writefile(['/* ccc comment */'], 'Xccc.c', 'D')
  call writefile(['/* ddd comment */'], 'Xddd.c', 'D')

  let bnr = bufnr('%')
  new Xaaa.c
  badd Xbbb.c
  badd Xccc.c
  badd Xddd.c
  exe "bwipe " . bnr
  let l = []
  bufdo call add(l, bufnr('%'))
  call assert_equal(4, len(l))

  syntax on

  " This used to only enable syntax HL in the last buffer.
  bufdo tab split
  tabrewind
  for tab in range(1, 4)
    norm fm
    call assert_equal(['cComment'], map(synstack(line("."), col(".")), 'synIDattr(v:val, "name")'))
    tabnext
  endfor

  bwipe! Xaaa.c
  bwipe! Xbbb.c
  bwipe! Xccc.c
  bwipe! Xddd.c
  syntax off
endfunc

func Test_syntax_foldlevel()
  new
  call setline(1, [
   \ 'void f(int a)',
   \ '{',
   \ '    if (a == 1) {',
   \ '        a = 0;',
   \ '    } else if (a == 2) {',
   \ '        a = 1;',
   \ '    } else {',
   \ '        a = 2;',
   \ '    }',
   \ '    if (a > 0) {',
   \ '        if (a == 1) {',
   \ '            a = 0;',
   \ '        } /* missing newline */ } /* end of outer if */ else {',
   \ '        a = 1;',
   \ '    }',
   \ '    if (a == 1)',
   \ '    {',
   \ '        a = 0;',
   \ '    }',
   \ '    else if (a == 2)',
   \ '    {',
   \ '        a = 1;',
   \ '    }',
   \ '    else',
   \ '    {',
   \ '        a = 2;',
   \ '    }',
   \ '}',
   \ ])
  setfiletype c
  syntax on
  set foldmethod=syntax

  call assert_fails('syn foldlevel start start', 'E390')
  call assert_fails('syn foldlevel not_an_option', 'E390')

  set foldlevel=1

  syn foldlevel start
  redir @c
  syn foldlevel
  redir END
  call assert_equal("\nsyntax foldlevel start", @c)
  syn sync fromstart
  call assert_match('from the first line$', execute('syn sync'))
  let a = map(range(3,9), 'foldclosed(v:val)')
  call assert_equal([3,3,3,3,3,3,3], a) " attached cascade folds together
  let a = map(range(10,15), 'foldclosed(v:val)')
  call assert_equal([10,10,10,10,10,10], a) " over-attached 'else' hidden
  let a = map(range(16,27), 'foldclosed(v:val)')
  let unattached_results = [-1,17,17,17,-1,21,21,21,-1,25,25,25]
  call assert_equal(unattached_results, a) " unattached cascade folds separately

  syn foldlevel minimum
  redir @c
  syn foldlevel
  redir END
  call assert_equal("\nsyntax foldlevel minimum", @c)
  syn sync fromstart
  let a = map(range(3,9), 'foldclosed(v:val)')
  call assert_equal([3,3,5,5,7,7,7], a) " attached cascade folds separately
  let a = map(range(10,15), 'foldclosed(v:val)')
  call assert_equal([10,10,10,13,13,13], a) " over-attached 'else' visible
  let a = map(range(16,27), 'foldclosed(v:val)')
  call assert_equal(unattached_results, a) " unattached cascade folds separately

  set foldlevel=2

  syn foldlevel start
  syn sync fromstart
  let a = map(range(11,14), 'foldclosed(v:val)')
  call assert_equal([11,11,11,-1], a) " over-attached 'else' hidden

  syn foldlevel minimum
  syn sync fromstart
  let a = map(range(11,14), 'foldclosed(v:val)')
  call assert_equal([11,11,-1,-1], a) " over-attached 'else' visible

  quit!
endfunc

func Test_search_syntax_skip()
  new
  let lines =<< trim END

        /* This is VIM */
        Another Text for VIM
         let a = "VIM"
  END
  call setline(1, lines)
  syntax on
  syntax match Comment "^/\*.*\*/"
  syntax match String '".*"'

  " Skip argument using string evaluation.
  1
  call search('VIM', 'w', '', 0, 'synIDattr(synID(line("."), col("."), 1), "name") =~? "comment"')
  call assert_equal('Another Text for VIM', getline('.'))

  1
  call search('VIM', 'cw', '', 0, 'synIDattr(synID(line("."), col("."), 1), "name") !~? "string"')
  call assert_equal(' let a = "VIM"', getline('.'))

  " Skip argument using Lambda.
  1
  call search('VIM', 'w', '', 0, { -> synIDattr(synID(line("."), col("."), 1), "name") =~? "comment"})
  call assert_equal('Another Text for VIM', getline('.'))

  1
  call search('VIM', 'cw', '', 0, { -> synIDattr(synID(line("."), col("."), 1), "name") !~? "string"})
  call assert_equal(' let a = "VIM"', getline('.'))

  " Skip argument using funcref.
  func InComment()
    return synIDattr(synID(line("."), col("."), 1), "name") =~? "comment"
  endfunc
  func NotInString()
    return synIDattr(synID(line("."), col("."), 1), "name") !~? "string"
  endfunc

  1
  call search('VIM', 'w', '', 0, function('InComment'))
  call assert_equal('Another Text for VIM', getline('.'))

  1
  call search('VIM', 'cw', '', 0, function('NotInString'))
  call assert_equal(' let a = "VIM"', getline('.'))

  delfunc InComment
  delfunc NotInString
  bwipe!
endfunc

func Test_syn_contained_transparent()
  " Comments starting with "Regression:" show the result when the highlighting
  " span of the containing item is assigned to the contained region.
  syntax on

  let l:case = "Transparent region contained in region"
  new
  syntax region X start=/\[/ end=/\]/ contained transparent
  syntax region Y start=/(/ end=/)/ contains=X

  call setline(1,  "==(--[~~]--)==")
  let l:expected = "  YYYYYYYYYY  "
  eval AssertHighlightGroups(1, 1, l:expected, 1, l:case)
  syntax clear Y X
  bw!

  let l:case = "Transparent region extends region"
  new
  syntax region X start=/\[/ end=/\]/ contained transparent
  syntax region Y start=/(/ end=/)/ end=/e/ contains=X

  call setline(1,  "==(--[~~e~~]--)==")
  let l:expected = "  YYYYYYYYYYYYY  "
  " Regression:    "  YYYYYYY   YYY  "
  eval AssertHighlightGroups(1, 1, l:expected, 1, l:case)
  syntax clear Y X
  bw!

  let l:case = "Nested transparent regions extend region"
  new
  syntax region X start=/\[/ end=/\]/ contained transparent
  syntax region Y start=/(/ end=/)/ end=/e/ contains=X

  call setline(1,  "==(--[~~e~~[~~e~~]~~e~~]--)==")
  let l:expected = "  YYYYYYYYYYYYYYYYYYYYYYYYY  "
  " Regression:    "  YYYYYYY         YYYYYYYYY  "
  eval AssertHighlightGroups(1, 1, l:expected, 1, l:case)
  syntax clear Y X
  bw!

  let l:case = "Transparent region contained in match"
  new
  syntax region X start=/\[/ end=/\]/ contained transparent
  syntax match Y /(.\{-})/ contains=X

  call setline(1,  "==(--[~~]--)==")
  let l:expected = "  YYYYYYYYYY  "
  eval AssertHighlightGroups(1, 1, l:expected, 1, l:case)
  syntax clear Y X
  bw!

  let l:case = "Transparent region extends match"
  new
  syntax region X start=/\[/ end=/\]/ contained transparent
  syntax match Y /(.\{-}[e)]/ contains=X

  call setline(1,  "==(--[~~e~~]--)==")
  let l:expected = "  YYYYYYYYYY     "
  " Regression:    "  YYYYYYY        "
  eval AssertHighlightGroups(1, 1, l:expected, 1, l:case)
  syntax clear Y X
  bw!

  let l:case = "Nested transparent regions extend match"
  new
  syntax region X start=/\[/ end=/\]/ contained transparent
  syntax match Y /(.\{-}[e)]/ contains=X

  call setline(1,  "==(--[~~e~~[~~e~~]~~e~~]--)==")
  let l:expected = "  YYYYYYYYYYYYYYYYYYYYYY     "
  " Regression:    "  YYYYYYY         YYYYYY     "
  eval AssertHighlightGroups(1, 1, l:expected, 1, l:case)
  syntax clear Y X
  bw!
endfunc

func Test_syn_include_contains_TOP()
  let l:case = "TOP in included syntax refers to top level of that included syntax"
  new
  syntax include @INCLUDED syntax/c.vim
  syntax region FencedCodeBlockC start=/```c/ end=/```/ contains=@INCLUDED

  call setline(1,  ['```c', '#if 0', 'int', '#else', 'int', '#endif', '```' ])
  let l:expected = ["cCppOutIf2"]
  eval AssertHighlightGroups(3, 1, l:expected, 1)
  " cCppOutElse has contains=TOP
  let l:expected = ["cType"]
  eval AssertHighlightGroups(5, 1, l:expected, 1, l:case)
  syntax clear
  bw!
endfunc

func Test_syn_include_contains_TOP_excluding()
  new
  syntax include @INCLUDED syntax/c.vim
  syntax region FencedCodeBlockC start=/```c/ end=/```/ contains=@INCLUDED

  call setline(1,  ['```c', '#if 0', 'int', '#else', 'int', '#if', '#endif', '```' ])
  let l:expected = ["cCppOutElse", "cConditional"]
  eval AssertHighlightGroups(6, 1, l:expected, 1)
  syntax clear
  bw!
endfunc

" This was using freed memory
func Test_WinEnter_synstack_synID()
  autocmd WinEnter * call synstack(line("."), col("."))
  autocmd WinEnter * call synID(line('.'), col('.') - 1, 1)
  call setline(1, 'aaaaa')
  normal! $
  new
  close

  au! WinEnter
  bw!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
