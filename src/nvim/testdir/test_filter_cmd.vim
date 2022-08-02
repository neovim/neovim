" Test the :filter command modifier

func Test_filter()
  edit Xdoesnotmatch
  edit Xwillmatch
  call assert_equal('"Xwillmatch"', substitute(execute('filter willma ls'), '[^"]*\(".*"\)[^"]*', '\1', ''))
  bwipe Xdoesnotmatch
  bwipe Xwillmatch

  new
  call setline(1, ['foo1', 'foo2', 'foo3', 'foo4', 'foo5'])
  call assert_equal("\nfoo2\nfoo4", execute('filter /foo[24]/ 1,$print'))
  call assert_equal("\n  2 foo2\n  4 foo4", execute('filter /foo[24]/ 1,$number'))
  call assert_equal("\nfoo2$\nfoo4$", execute('filter /foo[24]/ 1,$list'))

  call assert_equal("\nfoo1$\nfoo3$\nfoo5$", execute('filter! /foo[24]/ 1,$list'))
  bwipe!

  command XTryThis echo 'this'
  command XTryThat echo 'that'
  command XDoThat echo 'that'
  let lines = split(execute('filter XTry command'), "\n")
  call assert_equal(3, len(lines))
  call assert_match("XTryThat", lines[1])
  call assert_match("XTryThis", lines[2])
  delcommand XTryThis
  delcommand XTryThat
  delcommand XDoThat

  map f1 the first key
  map f2 the second key
  map f3 not a key
  let lines = split(execute('filter the map f'), "\n")
  call assert_equal(2, len(lines))
  call assert_match("f2", lines[0])
  call assert_match("f1", lines[1])
  unmap f1
  unmap f2
  unmap f3
endfunc

func Test_filter_fails()
  call assert_fails('filter', 'E471:')
  call assert_fails('filter pat', 'E476:')
  call assert_fails('filter /pat', 'E476:')
  call assert_fails('filter /pat/', 'E476:')
  call assert_fails('filter /pat/ asdf', 'E492:')
  " Using assert_fails() causes E476 instead of E866. So use a try-catch.
  let caught_e866 = 0
  try
    filter /\@>b/ ls
  catch /E866:/
    let caught_e866 = 1
  endtry
  call assert_equal(1, caught_e866)

  call assert_fails('filter!', 'E471:')
  call assert_fails('filter! pat', 'E476:')
  call assert_fails('filter! /pat', 'E476:')
  call assert_fails('filter! /pat/', 'E476:')
  call assert_fails('filter! /pat/ asdf', 'E492:')
endfunc

function s:complete_filter_cmd(filtcmd)
  let keystroke = "\<TAB>\<C-R>=execute('let cmdline = getcmdline()')\<CR>\<C-C>"
  let cmdline = ''
  call feedkeys(':' . a:filtcmd . keystroke, 'ntx')
  return cmdline
endfunction

func Test_filter_cmd_completion()
  " Do not complete pattern
  call assert_equal("filter \t", s:complete_filter_cmd('filter '))
  call assert_equal("filter pat\t", s:complete_filter_cmd('filter pat'))
  call assert_equal("filter /pat\t", s:complete_filter_cmd('filter /pat'))
  call assert_equal("filter /pat/\t", s:complete_filter_cmd('filter /pat/'))

  " Complete after string pattern
  call assert_equal('filter pat print', s:complete_filter_cmd('filter pat pri'))

  " Complete after regexp pattern
  call assert_equal('filter /pat/ print', s:complete_filter_cmd('filter /pat/ pri'))
  call assert_equal('filter #pat# print', s:complete_filter_cmd('filter #pat# pri'))
endfunc

func Test_filter_cmd_with_filter()
  new
  set shelltemp
  %!echo "a|b"
  let out = getline(1)
  bw!
  if has('win32')
    let out = trim(out, '" ')
  endif
  call assert_equal('a|b', out)
  set shelltemp&
endfunction

func Test_filter_commands()
  let g:test_filter_a = 1
  let b:test_filter_b = 2
  let test_filter_c = 3

  " Test filtering :let command
  let res = split(execute("filter /^test_filter/ let"), "\n")
  call assert_equal(["test_filter_a         #1"], res)

  let res = split(execute("filter /\\v^(b:)?test_filter/ let"), "\n")
  call assert_equal(["test_filter_a         #1", "b:test_filter_b       #2"], res)

  unlet g:test_filter_a
  unlet b:test_filter_b
  unlet test_filter_c

  " Test filtering :set command
  let helplang=&helplang
  set helplang=en
  let res = join(split(execute("filter /^help/ set"), "\n")[1:], " ")
  call assert_match('^\s*helplang=\w*$', res)
  let &helplang=helplang

  " Test filtering :llist command
  call setloclist(0, [{"filename": "/path/vim.c"}, {"filename": "/path/vim.h"}, {"module": "Main.Test"}])
  let res = split(execute("filter /\\.c$/ llist"), "\n")
  call assert_equal([" 1 /path/vim.c:  "], res)

  let res = split(execute("filter /\\.Test$/ llist"), "\n")
  call assert_equal([" 3 Main.Test:  "], res)

  " Test filtering :jump command
  e file.c
  e file.h
  e file.hs
  let res = split(execute("filter /\.c$/ jumps"), "\n")[1:]
  call assert_equal(["   2     1    0 file.c", ">"], res)

  " Test filtering :marks command
  b file.c
  mark A
  b file.h
  mark B
  let res = split(execute("filter /\.c$/ marks"), "\n")[1:]
  call assert_equal([" A      1    0 file.c"], res)

  call setline(1, ['one', 'two', 'three'])
  1mark a
  2mark b
  3mark c
  let res = split(execute("filter /two/ marks abc"), "\n")[1:]
  call assert_equal([" b      2    0 two"], res)

  bwipe! file.c
  bwipe! file.h
  bwipe! file.hs
endfunc

func Test_filter_display()
  edit Xdoesnotmatch
  let @a = '!!willmatch'
  let @b = '!!doesnotmatch'
  let @c = "oneline\ntwoline\nwillmatch\n"
  let @/ = '!!doesnotmatch'
  call feedkeys(":echo '!!doesnotmatch:'\<CR>", 'ntx')
  let lines = map(split(execute('filter /willmatch/ display'), "\n"), 'v:val[5:6]')

  call assert_true(index(lines, '"a') >= 0)
  call assert_false(index(lines, '"b') >= 0)
  call assert_true(index(lines, '"c') >= 0)
  call assert_false(index(lines, '"/') >= 0)
  call assert_false(index(lines, '":') >= 0)
  call assert_false(index(lines, '"%') >= 0)

  let lines = map(split(execute('filter /doesnotmatch/ display'), "\n"), 'v:val[5:6]')
  call assert_true(index(lines, '"a') < 0)
  call assert_false(index(lines, '"b') < 0)
  call assert_true(index(lines, '"c') < 0)
  call assert_false(index(lines, '"/') < 0)
  call assert_false(index(lines, '":') < 0)
  call assert_false(index(lines, '"%') < 0)

  bwipe!
endfunc

func Test_filter_scriptnames()
  let lines = split(execute('filter /test_filter_cmd/ scriptnames'), "\n")
  call assert_equal(1, len(lines))
  call assert_match('filter_cmd', lines[0])
endfunc

" vim: shiftwidth=2 sts=2 expandtab
