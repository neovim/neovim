" Tests for multi-line regexps with ":s".

function! Test_multiline_subst()
  enew!
  call append(0, ["1 aa",
	      \ "bb",
	      \ "cc",
	      \ "2 dd",
	      \ "ee",
	      \ "3 ef",
	      \ "gh",
	      \ "4 ij",
	      \ "5 a8",
	      \ "8b c9",
	      \ "9d",
	      \ "6 e7",
	      \ "77f",
	      \ "xxxxx"])

  1
  " test if replacing a line break works with a back reference
  /^1/,/^2/s/\n\(.\)/ \1/
  " test if inserting a line break works with a back reference
  /^3/,/^4/s/\(.\)$/\r\1/
  " test if replacing a line break with another line break works
  /^5/,/^6/s/\(\_d\{3}\)/x\1x/
  call assert_equal('1 aa bb cc 2 dd ee', getline(1))
  call assert_equal('3 e', getline(2))
  call assert_equal('f', getline(3))
  call assert_equal('g', getline(4))
  call assert_equal('h', getline(5))
  call assert_equal('4 i', getline(6))
  call assert_equal('j', getline(7))
  call assert_equal('5 ax8', getline(8))
  call assert_equal('8xb cx9', getline(9))
  call assert_equal('9xd', getline(10))
  call assert_equal('6 ex7', getline(11))
  call assert_equal('7x7f', getline(12))
  call assert_equal('xxxxx', getline(13))
  enew!
endfunction

function! Test_substitute_variants()
  " Validate that all the 2-/3-letter variants which embed the flags into the
  " command name actually work.
  enew!
  let ln = 'Testing string'
  let variants = [
	\ { 'cmd': ':s/Test/test/c', 'exp': 'testing string', 'prompt': 'y' },
	\ { 'cmd': ':s/foo/bar/ce', 'exp': ln },
	\ { 'cmd': ':s/t/r/cg', 'exp': 'Tesring srring', 'prompt': 'a' },
	\ { 'cmd': ':s/t/r/ci', 'exp': 'resting string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/cI', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/cn', 'exp': ln },
	\ { 'cmd': ':s/t/r/cp', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/cl', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/t/r/gc', 'exp': 'Tesring srring', 'prompt': 'a' },
	\ { 'cmd': ':s/foo/bar/ge', 'exp': ln },
	\ { 'cmd': ':s/t/r/g', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s/t/r/gi', 'exp': 'resring srring' },
	\ { 'cmd': ':s/t/r/gI', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s/t/r/gn', 'exp': ln },
	\ { 'cmd': ':s/t/r/gp', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s/t/r/gl', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s//r/gr', 'exp': 'Testr strr' },
	\ { 'cmd': ':s/t/r/ic', 'exp': 'resting string', 'prompt': 'y' },
	\ { 'cmd': ':s/foo/bar/ie', 'exp': ln },
	\ { 'cmd': ':s/t/r/i', 'exp': 'resting string' },
	\ { 'cmd': ':s/t/r/iI', 'exp': 'Tesring string' },
	\ { 'cmd': ':s/t/r/in', 'exp': ln },
	\ { 'cmd': ':s/t/r/ip', 'exp': 'resting string' },
	\ { 'cmd': ':s//r/ir', 'exp': 'Testr string' },
	\ { 'cmd': ':s/t/r/Ic', 'exp': 'Tesring string', 'prompt': 'y' },
	\ { 'cmd': ':s/foo/bar/Ie', 'exp': ln },
	\ { 'cmd': ':s/t/r/Ig', 'exp': 'Tesring srring' },
	\ { 'cmd': ':s/t/r/Ii', 'exp': 'resting string' },
	\ { 'cmd': ':s/t/r/I', 'exp': 'Tesring string' },
	\ { 'cmd': ':s/t/r/Ip', 'exp': 'Tesring string' },
	\ { 'cmd': ':s/t/r/Il', 'exp': 'Tesring string' },
	\ { 'cmd': ':s//r/Ir', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/rc', 'exp': 'Testr string', 'prompt': 'y' },
	\ { 'cmd': ':s//r/rg', 'exp': 'Testr strr' },
	\ { 'cmd': ':s//r/ri', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/rI', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/rn', 'exp': 'Testing string' },
	\ { 'cmd': ':s//r/rp', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/rl', 'exp': 'Testr string' },
	\ { 'cmd': ':s//r/r', 'exp': 'Testr string' },
	\]

  for var in variants
    for run in [1, 2]
      let cmd = var.cmd
      if run == 2 && cmd =~ "/.*/.*/."
	" Change  :s/from/to/{flags}  to  :s{flags}
	let cmd = substitute(cmd, '/.*/', '', '')
      endif
      call setline(1, [ln])
      let msg = printf('using "%s"', cmd)
      let @/='ing'
      let v:errmsg = ''
      call feedkeys(cmd . "\<CR>" . get(var, 'prompt', ''), 'ntx')
      " No error should exist (matters for testing e flag)
      call assert_equal('', v:errmsg, msg)
      call assert_equal(var.exp, getline('.'), msg)
    endfor
  endfor
endfunction

func Test_substitute_repeat()
  " This caused an invalid memory access.
  split Xfile
  s/^/x
  call feedkeys("Qsc\<CR>y", 'tx')
  bwipe!
endfunc
