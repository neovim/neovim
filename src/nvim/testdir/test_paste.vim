" Tests for bracketed paste.

" Bracketed paste only works with "xterm".
set term=xterm

func Test_paste_normal_mode()
  new
  call setline(1, ['a', 'b', 'c'])
  2
  call feedkeys("\<Esc>[200~foo\<CR>bar\<Esc>[201~", 'xt')
  call assert_equal('bfoo', getline(2))
  call assert_equal('bar', getline(3))
  call assert_equal('c', getline(4))

  normal .
  call assert_equal('barfoo', getline(3))
  call assert_equal('bar', getline(4))
  call assert_equal('c', getline(5))
  bwipe!
endfunc

func Test_paste_insert_mode()
  new
  call setline(1, ['a', 'b', 'c'])
  2
  call feedkeys("i\<Esc>[200~foo\<CR>bar\<Esc>[201~ done\<Esc>", 'xt')
  call assert_equal('foo', getline(2))
  call assert_equal('bar doneb', getline(3))
  call assert_equal('c', getline(4))

  normal .
  call assert_equal('bar donfoo', getline(3))
  call assert_equal('bar doneeb', getline(4))
  call assert_equal('c', getline(5))
  bwipe!
endfunc

func Test_paste_cmdline()
  call feedkeys(":a\<Esc>[200~foo\<CR>bar\<Esc>[201~b\<Home>\"\<CR>", 'xt')
  call assert_equal("\"afoo\<CR>barb", getreg(':'))
endfunc
