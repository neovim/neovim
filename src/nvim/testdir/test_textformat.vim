" Tests for the various 'formatoptions' settings
func Test_text_format()
  enew!

  setl noai tw=2 fo=t
  call append('$', [
	      \ '{',
	      \ '    ',
	      \ '',
	      \ '}'])
  exe "normal /^{/+1\n0"
  normal gRa b
  let lnum = line('.')
  call assert_equal([
	      \ 'a',
	      \ 'b'], getline(lnum - 1, lnum))

  normal ggdG
  setl ai tw=2 fo=tw
  call append('$', [
	      \ '{',
	      \ 'a  b  ',
	      \ '',
	      \ 'a    ',
	      \ '}'])
  exe "normal /^{/+1\n0"
  normal gqgqjjllab
  let lnum = line('.')
  call assert_equal([
	      \ 'a  ',
	      \ 'b  ',
	      \ '',
	      \ 'a  ',
	      \ 'b'], getline(lnum - 4, lnum))

  normal ggdG
  setl tw=3 fo=t
  call append('$', [
	      \ '{',
	      \ "a \<C-A>",
	      \ '}'])
  exe "normal /^{/+1\n0"
  exe "normal gqgqo\na \<C-V>\<C-A>"
  let lnum = line('.')
  call assert_equal([
	      \ 'a',
	      \ "\<C-A>",
	      \ '',
	      \ 'a',
	      \ "\<C-A>"], getline(lnum - 4, lnum))

  normal ggdG
  setl tw=2 fo=tcq1 comments=:#
  call append('$', [
	      \ '{',
	      \ 'a b',
	      \ '#a b',
	      \ '}'])
  exe "normal /^{/+1\n0"
  exe "normal gqgqjgqgqo\na b\n#a b"
  let lnum = line('.')
  call assert_equal([
	      \ 'a b',
	      \ '#a b',
	      \ '',
	      \ 'a b',
	      \ '#a b'], getline(lnum - 4, lnum))

  normal ggdG
  setl tw=5 fo=tcn comments=:#
  call append('$', [
	      \ '{',
	      \ '  1 a',
	      \ '# 1 a',
	      \ '}'])
  exe "normal /^{/+1\n0"
  exe "normal A b\<Esc>jA b"
  let lnum = line('.')
  call assert_equal([
	      \ '  1 a',
	      \ '    b',
	      \ '# 1 a',
	      \ '#   b'], getline(lnum - 3, lnum))

  normal ggdG
  setl tw=5 fo=t2a si
  call append('$', [
	      \ '{',
	      \ '',
	      \ '  x a',
	      \ '  b',
	      \ ' c',
	      \ '',
	      \ '}'])
  exe "normal /^{/+3\n0"
  exe "normal i  \<Esc>A_"
  let lnum = line('.')
  call assert_equal([
	      \ '',
	      \ '  x a',
	      \ '    b_',
	      \ '    c',
	      \ ''], getline(lnum - 2, lnum + 2))

  normal ggdG
  setl tw=5 fo=qn comments=:#
  call append('$', [
	      \ '{',
	      \ '# 1 a b',
	      \ '}'])
  exe "normal /^{/+1\n5|"
  normal gwap
  call assert_equal(5, col('.'))
  let lnum = line('.')
  call assert_equal([
	      \ '# 1 a',
	      \ '#   b'], getline(lnum, lnum + 1))

  normal ggdG
  setl tw=5 fo=q2 comments=:#
  call append('$', [
	      \ '{',
	      \ '# x',
	      \ '#   a b',
	      \ '}'])
  exe "normal /^{/+1\n0"
  normal gwap
  let lnum = line('.')
  call assert_equal([
	      \ '# x a',
	      \ '#   b'], getline(lnum, lnum + 1))

  normal ggdG
  setl tw& fo=a
  call append('$', [
	      \ '{',
	      \ '   1aa',
	      \ '   2bb',
	      \ '}'])
  exe "normal /^{/+2\n0"
  normal I^^
  call assert_equal('{ 1aa ^^2bb }', getline('.'))

  normal ggdG
  setl tw=20 fo=an12wcq comments=s1:/*,mb:*,ex:*/
  call append('$', [
	      \ '/* abc def ghi jkl ',
	      \ ' *    mno pqr stu',
	      \ ' */'])
  exe "normal /mno pqr/\n"
  normal A vwx yz
  let lnum = line('.')
  call assert_equal([
	      \ ' *    mno pqr stu ',
	      \ ' *    vwx yz',
	      \ ' */'], getline(lnum - 1, lnum + 1))

  normal ggdG
  setl tw=12 fo=tqnc comments=:#
  call setline('.', '# 1 xxxxx')
  normal A foobar
  call assert_equal([
	      \ '# 1 xxxxx',
	      \ '#   foobar'], getline(1, 2))

  setl ai& tw& fo& si& comments&
  enew!
endfunc
