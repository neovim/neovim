-- Test for user command counts

local t = require('test.functional.testutil')(after_each)
local clear, source, expect = t.clear, t.source, t.expect
local feed_command = t.feed_command

-- luacheck: ignore 613 (Trailing whitespace in a string)
describe('command_count', function()
  it('is working', function()
    -- It is relevant for the test to load a file initially.  If this is
    -- emulated with :arg the buffer count is wrong as nvim creates an empty
    -- buffer if it was started without a filename.
    clear('test_command_count.in')

    source([[
      let g:tmpname = tempname()
      call mkdir(g:tmpname)
      execute "cd ".g:tmpname
      lang C
      let g:lines = []
      com -range=% RangeLines
        \ :call add(g:lines, 'RangeLines '.<line1>.' '.<line2>)
      com -range -addr=arguments RangeArguments
        \ :call add(g:lines, 'RangeArguments '.<line1>.' '.<line2>)
      com -range=% -addr=arguments RangeArgumentsAll
        \ :call add(g:lines, 'RangeArgumentsAll '.<line1>.' '.<line2>)
      com -range -addr=loaded_buffers RangeLoadedBuffers
        \ :call add(g:lines, 'RangeLoadedBuffers '.<line1>.' '.<line2>)
      com -range=% -addr=loaded_buffers RangeLoadedBuffersAll
        \ :call add(g:lines, 'RangeLoadedBuffersAll '.<line1>.' '.<line2>)
      com -range -addr=buffers RangeBuffers
        \ :call add(g:lines, 'RangeBuffers '.<line1>.' '.<line2>)
      com -range=% -addr=buffers RangeBuffersAll
        \ :call add(g:lines, 'RangeBuffersAll '.<line1>.' '.<line2>)
      com -range -addr=windows RangeWindows
        \ :call add(g:lines, 'RangeWindows '.<line1>.' '.<line2>)
      com -range=% -addr=windows RangeWindowsAll
        \ :call add(g:lines, 'RangeWindowsAll '.<line1>.' '.<line2>)
      com -range -addr=tabs RangeTabs
        \ :call add(g:lines, 'RangeTabs '.<line1>.' '.<line2>)
      com -range=% -addr=tabs RangeTabsAll
        \ :call add(g:lines, 'RangeTabsAll '.<line1>.' '.<line2>)
      set hidden
      arga a b c d
      argdo echo "loading buffers"
      argu 3
      .-,$-RangeArguments
      %RangeArguments
      RangeArgumentsAll
      N
      .RangeArguments
      split
      split
      split
      split
      3wincmd w
      .,$RangeWindows
      %RangeWindows
      RangeWindowsAll
      only
      blast
      bd
      .,$RangeLoadedBuffers
      %RangeLoadedBuffers
      RangeLoadedBuffersAll
      .,$RangeBuffers
      %RangeBuffers
      RangeBuffersAll
      tabe
      tabe
      tabe
      tabe
      normal 2gt
      .,$RangeTabs
      %RangeTabs
      RangeTabsAll
      1tabonly
      s/\n/\r\r\r\r\r/
      2ma<
      $-ma>
      '<,'>RangeLines
      com -range=% -buffer LocalRangeLines
        \ :call add(g:lines, 'LocalRangeLines '.<line1>.' '.<line2>)
      '<,'>LocalRangeLines
      b1
      call add(g:lines, '')
      %argd
      arga a b c d
      ]])
    -- This can not be in the source() call as it will produce errors.
    feed_command([[let v:errmsg = '']])
    feed_command('5argu')
    feed_command([[call add(g:lines, '5argu ' . v:errmsg)]])
    feed_command('$argu')
    feed_command([[call add(g:lines, '4argu ' . expand('%:t'))]])
    feed_command([[let v:errmsg = '']])
    feed_command('1argu')
    feed_command([[call add(g:lines, '1argu ' . expand('%:t'))]])
    feed_command([[let v:errmsg = '']])
    feed_command('100b')
    feed_command([[call add(g:lines, '100b ' . v:errmsg)]])
    feed_command('split')
    feed_command('split')
    feed_command('split')
    feed_command('split')
    feed_command([[let v:errmsg = '']])
    feed_command('0close')
    feed_command([[call add(g:lines, '0close ' . v:errmsg)]])
    feed_command('$wincmd w')
    feed_command('$close')
    feed_command([[call add(g:lines, '$close ' . winnr())]])
    feed_command([[let v:errmsg = '']])
    feed_command('$+close')
    feed_command([[call add(g:lines, '$+close ' . v:errmsg)]])
    feed_command('$tabe')
    feed_command([[call add(g:lines, '$tabe ' . tabpagenr())]])
    feed_command([[let v:errmsg = '']])
    feed_command('$+tabe')
    feed_command([[call add(g:lines, '$+tabe ' . v:errmsg)]])
    source([[
      only!
      e x
      0tabm
      normal 1gt
      call add(g:lines, '0tabm ' . expand('%:t'))
      tabonly!
      only!
      e! test.out
      call append(0, g:lines)
      unlet g:lines
      w
      bd
      b1
      let g:lines = []
      func BufStatus()
        call add(g:lines,
	  \  'aaa: ' . buflisted(g:buf_aaa) .
	  \ ' bbb: ' . buflisted(g:buf_bbb) .
	  \ ' ccc: ' . buflisted(g:buf_ccc))
      endfunc
      se nohidden
      e aaa
      let buf_aaa = bufnr('%')
      e bbb
      let buf_bbb = bufnr('%')
      e ccc
      let buf_ccc = bufnr('%')
      b1
      call BufStatus()
      exe buf_bbb . "," . buf_ccc . "bdelete"
      call BufStatus()
      exe buf_aaa . "bdelete"
      call BufStatus()
      e! test.out
      call append('$', g:lines)
      unlet g:lines
      delfunc BufStatus
      w
      bd
      b1
      se hidden
      only!
      let g:lines = []
      %argd
      arga a b c d e f
      3argu
      let args = ''
      .,$-argdo let args .= ' '.expand('%')
      call add(g:lines, 'argdo:' . args)
      split
      split
      split
      split
      2wincmd w
      let windows = ''
      .,$-windo let windows .= ' '.winnr()
      call add(g:lines, 'windo:'. windows)
      b2
      let buffers = ''
      .,$-bufdo let buffers .= ' '.bufnr('%')
      call add(g:lines, 'bufdo:' . buffers)
      3bd
      let buffers = ''
      3,7bufdo let buffers .= ' '.bufnr('%')
      call add(g:lines, 'bufdo:' . buffers)
      tabe
      tabe
      tabe
      tabe
      normal! 2gt
      let tabpages = ''
      .,$-tabdo let tabpages .= ' '.tabpagenr()
      call add(g:lines, 'tabdo:' . tabpages)
      e! test.out
      call append('$', g:lines)
    ]])

    -- Assert buffer contents.
    expect([[
      RangeArguments 2 4
      RangeArguments 1 5
      RangeArgumentsAll 1 5
      RangeArguments 2 2
      RangeWindows 3 5
      RangeWindows 1 5
      RangeWindowsAll 1 5
      RangeLoadedBuffers 2 4
      RangeLoadedBuffers 1 4
      RangeLoadedBuffersAll 1 4
      RangeBuffers 2 5
      RangeBuffers 1 5
      RangeBuffersAll 1 5
      RangeTabs 2 5
      RangeTabs 1 5
      RangeTabsAll 1 5
      RangeLines 2 5
      LocalRangeLines 2 5

      5argu E16: Invalid range
      4argu d
      1argu a
      100b E16: Invalid range
      0close 
      $close 3
      $+close E16: Invalid range
      $tabe 2
      $+tabe E16: Invalid range
      0tabm x

      aaa: 1 bbb: 1 ccc: 1
      aaa: 1 bbb: 0 ccc: 0
      aaa: 0 bbb: 0 ccc: 0
      argdo: c d e
      windo: 2 3 4
      bufdo: 2 3 4 5 6 7 8 9 10 15
      bufdo: 4 5 6 7
      tabdo: 2 3 4]])

    source([[
      cd ..
      call delete(g:tmpname, 'rf')
    ]])
  end)
end)
