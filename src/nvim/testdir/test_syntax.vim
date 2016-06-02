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
  let b2=@0
  call assert_equal('DLTD', @0)

  syn iskeyword clear
  redir @c
  syn iskeyword
  redir END
  call assert_equal("\nsyntax iskeyword not set", @c)

  quit!
endfunc
