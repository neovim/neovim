" Test for user command counts.

func Test_command_count_0()
  let bufnr = bufnr('%')
  set hidden
  set noswapfile

  split DoesNotExistEver
  let lastbuf = bufnr('$')
  call setline(1, 'asdf')
  quit!

  command! -range -addr=loaded_buffers RangeLoadedBuffers :let lines = [<line1>, <line2>]
  command! -range=% -addr=loaded_buffers RangeLoadedBuffersAll :let lines = [<line1>, <line2>]
  command! -range -addr=buffers RangeBuffers :let lines = [<line1>, <line2>]
  command! -range=% -addr=buffers RangeBuffersAll :let lines = [<line1>, <line2>]

  .,$RangeLoadedBuffers
  call assert_equal([bufnr, bufnr], lines)
  %RangeLoadedBuffers
  call assert_equal([bufnr, bufnr], lines)
  RangeLoadedBuffersAll
  call assert_equal([bufnr, bufnr], lines)
  .,$RangeBuffers
  call assert_equal([bufnr, lastbuf], lines)
  %RangeBuffers
  call assert_equal([bufnr, lastbuf], lines)
  RangeBuffersAll
  call assert_equal([bufnr, lastbuf], lines)

  delcommand RangeLoadedBuffers
  delcommand RangeLoadedBuffersAll
  delcommand RangeBuffers
  delcommand RangeBuffersAll

  set hidden&
  set swapfile&
endfunc

func Test_command_count_1()
  silent! %argd
  arga a b c d e
  argdo echo "loading buffers"
  argu 3
  command! -range -addr=arguments RangeArguments :let lines = [<line1>, <line2>]
  command! -range=% -addr=arguments RangeArgumentsAll :let lines = [<line1>, <line2>]
  .-,$-RangeArguments
  call assert_equal([2, 4], lines)
  %RangeArguments
  call assert_equal([1, 5], lines)
  RangeArgumentsAll
  call assert_equal([1, 5], lines)
  N
  .RangeArguments
  call assert_equal([2, 2], lines)
  delcommand RangeArguments
  delcommand RangeArgumentsAll

  split|split|split|split
  3wincmd w
  command! -range -addr=windows RangeWindows :let lines = [<line1>, <line2>]
  .,$RangeWindows
  call assert_equal([3, 5], lines)
  %RangeWindows
  call assert_equal([1, 5], lines)
  delcommand RangeWindows

  command! -range=% -addr=windows RangeWindowsAll :let lines = [<line1>, <line2>]
  RangeWindowsAll
  call assert_equal([1, 5], lines)
  delcommand RangeWindowsAll
  only
  blast|bd

  tabe|tabe|tabe|tabe
  normal 2gt
  command! -range -addr=tabs RangeTabs :let lines = [<line1>, <line2>]
  .,$RangeTabs
  call assert_equal([2, 5], lines)
  %RangeTabs
  call assert_equal([1, 5], lines)
  delcommand RangeTabs

  command! -range=% -addr=tabs RangeTabsAll :let lines = [<line1>, <line2>]
  RangeTabsAll
  call assert_equal([1, 5], lines)
  delcommand RangeTabsAll
  1tabonly

  s/\n/\r\r\r\r\r/
  2ma<
  $-ma>
  command! -range=% RangeLines :let lines = [<line1>, <line2>]
  '<,'>RangeLines
  call assert_equal([2, 5], lines)
  delcommand RangeLines

  command! -range=% -buffer LocalRangeLines :let lines = [<line1>, <line2>]
  '<,'>LocalRangeLines
  call assert_equal([2, 5], lines)
  delcommand LocalRangeLines
endfunc

func Test_command_count_2()
  silent! %argd
  arga a b c d
  call assert_fails('5argu', 'E16:')

  $argu
  call assert_equal('d', expand('%:t'))

  1argu
  call assert_equal('a', expand('%:t'))

  call assert_fails('300b', 'E16:')

  split|split|split|split
  0close

  $wincmd w
  $close
  call assert_equal(3, winnr())

  call assert_fails('$+close', 'E16:')

  $tabe
  call assert_equal(2, tabpagenr())

  call assert_fails('$+tabe', 'E16:')

  only!
  e x
  0tabm
  normal 1gt
  call assert_equal('x', expand('%:t'))

  tabonly!
  only!
endfunc

func Test_command_count_3()
  let bufnr = bufnr('%')
  se nohidden
  e aaa
  let buf_aaa = bufnr('%')
  e bbb
  let buf_bbb = bufnr('%')
  e ccc
  let buf_ccc = bufnr('%')
  exe bufnr . 'buf'
  call assert_equal([1, 1, 1], [buflisted(buf_aaa), buflisted(buf_bbb), buflisted(buf_ccc)])
  exe buf_bbb . "," . buf_ccc . "bdelete"
  call assert_equal([1, 0, 0], [buflisted(buf_aaa), buflisted(buf_bbb), buflisted(buf_ccc)])
  exe buf_aaa . "bdelete"
  call assert_equal([0, 0, 0], [buflisted(buf_aaa), buflisted(buf_bbb), buflisted(buf_ccc)])
endfunc

func Test_command_count_4()
  %argd
  let bufnr = bufnr('$')
  next aa bb cc dd ee ff
  call assert_equal(bufnr, bufnr('%'))

  3argu
  let args = []
  .,$-argdo call add(args, expand('%'))
  call assert_equal(['cc', 'dd', 'ee'], args)

  " create windows to get 5
  split|split|split|split
  2wincmd w
  let windows = []
  .,$-windo call add(windows, winnr())
  call assert_equal([2, 3, 4], windows)
  only!

  exe bufnr . 'buf'
  let bufnr = bufnr('%')
  let buffers = []
  .,$-bufdo call add(buffers, bufnr('%'))
  call assert_equal([bufnr, bufnr + 1, bufnr + 2, bufnr + 3, bufnr + 4], buffers)

  exe (bufnr + 3) . 'bdel'
  let buffers = []
  exe (bufnr + 2) . ',' . (bufnr + 5) . "bufdo call add(buffers, bufnr('%'))"
  call assert_equal([bufnr + 2, bufnr + 4, bufnr +  5], buffers)

  " create tabpages to get 5
  tabe|tabe|tabe|tabe
  normal! 2gt
  let tabpages = []
  .,$-tabdo call add(tabpages, tabpagenr())
  call assert_equal([2, 3, 4], tabpages)
  tabonly!
  bwipe!
endfunc
