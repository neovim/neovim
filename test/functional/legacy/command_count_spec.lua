-- Test for user command counts

local helpers = require('test.functional.helpers')
local source = helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('command_count', function()
  setup(clear)
  teardown(function()
    os.remove('test.out')
  end)

  it('is working', function()
    execute('lang C')
    execute('let g:lines = []')
    execute([[com -range=% RangeLines :call add(g:lines, 'RangeLines '.<line1>.' '.<line2>)]])
    execute([[com -range -addr=arguments RangeArguments :call add(g:lines, 'RangeArguments '.<line1>.' '.<line2>)]])
    execute([[com -range=% -addr=arguments RangeArgumentsAll :call add(g:lines, 'RangeArgumentsAll '.<line1>.' '.<line2>)]])
    execute([[com -range -addr=loaded_buffers RangeLoadedBuffers :call add(g:lines, 'RangeLoadedBuffers '.<line1>.' '.<line2>)]])
    execute([[com -range=% -addr=loaded_buffers RangeLoadedBuffersAll :call add(g:lines, 'RangeLoadedBuffersAll '.<line1>.' '.<line2>)]])
    execute([[com -range -addr=buffers RangeBuffers :call add(g:lines, 'RangeBuffers '.<line1>.' '.<line2>)]])
    execute([[com -range=% -addr=buffers RangeBuffersAll :call add(g:lines, 'RangeBuffersAll '.<line1>.' '.<line2>)]])
    execute([[com -range -addr=windows RangeWindows :call add(g:lines, 'RangeWindows '.<line1>.' '.<line2>)]])
    execute([[com -range=% -addr=windows RangeWindowsAll :call add(g:lines, 'RangeWindowsAll '.<line1>.' '.<line2>)]])
    execute([[com -range -addr=tabs RangeTabs :call add(g:lines, 'RangeTabs '.<line1>.' '.<line2>)]])
    execute([[com -range=% -addr=tabs RangeTabsAll :call add(g:lines, 'RangeTabsAll '.<line1>.' '.<line2>)]])
    execute('set hidden')
    execute('arga a b c d')
    execute('argdo echo "loading buffers"')
    execute('argu 3')
    execute('.-,$-RangeArguments')
    execute('%RangeArguments')
    execute('RangeArgumentsAll')
    execute('N')
    execute('.RangeArguments')
    execute('split|split|split|split')
    execute('3wincmd w')
    execute('.,$RangeWindows')
    execute('%RangeWindows')
    execute('RangeWindowsAll')
    execute('only')
    execute('blast|bd')
    execute('.,$RangeLoadedBuffers')
    execute('%RangeLoadedBuffers')
    execute('RangeLoadedBuffersAll')
    execute('.,$RangeBuffers')
    execute('%RangeBuffers')
    execute('RangeBuffersAll')
    execute('tabe|tabe|tabe|tabe')
    execute('normal 2gt')
    execute('.,$RangeTabs')
    execute('%RangeTabs')
    execute('RangeTabsAll')
    execute('1tabonly')
    execute([[s/\n/\r\r\r\r\r/]])
    execute('2ma<')
    execute('$-ma>')
    execute([['<,'>RangeLines]])
    execute([[com -range=% -buffer LocalRangeLines :call add(g:lines, 'LocalRangeLines '.<line1>.' '.<line2>)]])
    execute([['<,'>LocalRangeLines]])
    execute('b1')
    execute([[call add(g:lines, '')]])
    execute('%argd')
    execute('arga a b c d')
    execute([[let v:errmsg = '']])
    execute('5argu')
    execute([[call add(g:lines, '5argu ' . v:errmsg)]])
    execute('$argu')
    execute([[call add(g:lines, '4argu ' . expand('%:t'))]])
    execute([[let v:errmsg = '']])
    execute('1argu')
    execute([[call add(g:lines, '1argu ' . expand('%:t'))]])
    execute([[let v:errmsg = '']])
    execute('100b')
    execute([[call add(g:lines, '100b ' . v:errmsg)]])
    execute('split|split|split|split')
    execute([[let v:errmsg = '']])
    execute('0close')
    execute([[call add(g:lines, '0close ' . v:errmsg)]])
    execute('$wincmd w')
    execute('$close')
    execute([[call add(g:lines, '$close ' . winnr())]])
    execute([[let v:errmsg = '']])
    execute('$+close')
    execute([[call add(g:lines, '$+close ' . v:errmsg)]])
    execute('$tabe')
    execute([[call add(g:lines, '$tabe ' . tabpagenr())]])
    execute([[let v:errmsg = '']])
    execute('$+tabe')
    execute([[call add(g:lines, '$+tabe ' . v:errmsg)]])
    execute('only!')
    execute('e x')
    execute('0tabm')
    execute('normal 1gt')
    execute([[call add(g:lines, '0tabm ' . expand('%:t'))]])
    execute('tabonly!')
    execute('only!')
    execute('e! test.out')
    execute('call append(0, g:lines)')
    execute('unlet g:lines')
    execute('w|bd')
    execute('b1')
    execute('let g:lines = []')
    execute('func BufStatus()')
    execute([[  call add(g:lines, 'aaa: ' . buflisted(g:buf_aaa) . ' bbb: ' . buflisted(g:buf_bbb) . ' ccc: ' . buflisted(g:buf_ccc))]])
    execute('endfunc')
    execute('se nohidden')
    execute('e aaa')
    execute([[let buf_aaa = bufnr('%')]])
    execute('e bbb')
    execute([[let buf_bbb = bufnr('%')]])
    execute('e ccc')
    execute([[let buf_ccc = bufnr('%')]])
    execute('b1')
    execute('call BufStatus()')
    execute('exe buf_bbb . "," . buf_ccc . "bdelete"')
    execute('call BufStatus()')
    execute('exe buf_aaa . "bdelete"')
    execute('call BufStatus()')
    execute('e! test.out')
    execute([[call append('$', g:lines)]])
    execute('unlet g:lines')
    execute('delfunc BufStatus')
    execute('w|bd')
    execute('b1')
    execute('se hidden')
    execute('only!')
    execute('let g:lines = []')
    execute('%argd')
    execute('arga a b c d e f')
    execute('3argu')
    execute([[let args = '']])
    execute([[.,$-argdo let args .= ' '.expand('%')]])
    execute([[call add(g:lines, 'argdo:' . args)]])
    execute('split|split|split|split')
    execute('2wincmd w')
    execute([[let windows = '']])
    execute([[.,$-windo let windows .= ' '.winnr()]])
    execute([[call add(g:lines, 'windo:'. windows)]])
    execute('b2')
    execute([[let buffers = '']])
    execute([[.,$-bufdo let buffers .= ' '.bufnr('%')]])
    execute([[call add(g:lines, 'bufdo:' . buffers)]])
    execute([[let buffers = '']])
    execute([[3,7bufdo let buffers .= ' '.bufnr('%')]])
    execute([[call add(g:lines, 'bufdo:' . buffers)]])
    execute('tabe|tabe|tabe|tabe')
    execute('normal! 2gt')
    execute([[let tabpages = '']])
    execute([[.,$-tabdo let tabpages .= ' '.tabpagenr()]])
    execute([[call add(g:lines, 'tabdo:' . tabpages)]])
    execute('e! test.out')
    execute([[call append('$', g:lines)]])

    -- Assert buffer contents.
    expect([=[
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
      bufdo: 3 4 5 6 7
      tabdo: 2 3 4]=])
  end)
end)
