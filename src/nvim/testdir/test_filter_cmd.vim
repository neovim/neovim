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
