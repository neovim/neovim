-- Test for breakindent

local helpers = require('test.functional.helpers')(after_each)
local feed, insert = helpers.feed, helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('breakindent', function()
  setup(clear)

  it('is working', function()
    insert('dummy text')

    execute('set wildchar=^E')
    execute('10new')
    execute('vsp')
    execute('vert resize 20')
    execute([[put =\"\tabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP\"]])
    execute('set ts=4 sw=4 sts=4 breakindent')
    execute('fu! ScreenChar(line, width)')
    execute('	let c=""')
    execute('	for i in range(1,a:width)')
    execute('		let c.=nr2char(screenchar(a:line, i))')
    execute('	endfor')
    execute([[       let c.="\n"]])
    execute('	for i in range(1,a:width)')
    execute('		let c.=nr2char(screenchar(a:line+1, i))')
    execute('	endfor')
    execute([[       let c.="\n"]])
    execute('	for i in range(1,a:width)')
    execute('		let c.=nr2char(screenchar(a:line+2, i))')
    execute('	endfor')
    execute('	return c')
    execute('endfu')
    execute('fu DoRecordScreen()')
    execute('	wincmd l')
    execute([[	$put =printf(\"\n%s\", g:test)]])
    execute('	$put =g:line1')
    execute('	wincmd p')
    execute('endfu')
    execute('set briopt=min:0')
    execute('let g:test="Test 1: Simple breakindent"')
    execute('let line1=ScreenChar(line("."),8)')
    execute('call DoRecordScreen()')
    execute('let g:test="Test 2: Simple breakindent + sbr=>>"')
    execute('set sbr=>>')
    execute('let line1=ScreenChar(line("."),8)')
    execute('call DoRecordScreen()')
    execute('let g:test ="Test 3: Simple breakindent + briopt:sbr"')
    execute('set briopt=sbr,min:0 sbr=++')
    execute('let line1=ScreenChar(line("."),8)')
    execute('call DoRecordScreen()')
    execute('let g:test ="Test 4: Simple breakindent + min width: 18"')
    execute('set sbr= briopt=min:18')
    execute('let line1=ScreenChar(line("."),8)')
    execute('call DoRecordScreen()')
    execute('let g:test =" Test 5: Simple breakindent + shift by 2"')
    execute('set briopt=shift:2,min:0')
    execute('let line1=ScreenChar(line("."),8)')
    execute('call DoRecordScreen()')
    execute('let g:test=" Test 6: Simple breakindent + shift by -1"')
    execute('set briopt=shift:-1,min:0')
    execute('let line1=ScreenChar(line("."),8)')
    execute('call DoRecordScreen()')
    execute('let g:test=" Test 7: breakindent + shift by +1 + nu + sbr=? briopt:sbr"')
    execute('set briopt=shift:1,sbr,min:0 nu sbr=? nuw=4')
    execute('let line1=ScreenChar(line("."),10)')
    execute('call DoRecordScreen()')
    execute('let g:test=" Test 8: breakindent + shift:1 + nu + sbr=# list briopt:sbr"')
    execute('set briopt=shift:1,sbr,min:0 nu sbr=# list lcs&vi')
    execute('let line1=ScreenChar(line("."),10)')
    execute('call DoRecordScreen()')
    execute([[let g:test=" Test 9: breakindent + shift by +1 + 'nu' + sbr=# list"]])
    execute('set briopt-=sbr')
    execute('let line1=ScreenChar(line("."),10)')
    execute('call DoRecordScreen()')
    execute([[let g:test=" Test 10: breakindent + shift by +1 + 'nu' + sbr=~ cpo+=n"]])
    execute('set cpo+=n sbr=~ nu nuw=4 nolist briopt=sbr,min:0')
    execute('let line1=ScreenChar(line("."),10)')
    execute('call DoRecordScreen()')
    execute('wincmd p')
    execute([[let g:test="\n Test 11: strdisplaywidth when breakindent is on"]])
    execute('set cpo-=n sbr=>> nu nuw=4 nolist briopt= ts=4')
    -- Skip leading tab when calculating text width.
    execute('let text=getline(2)')
    -- Text wraps 3 times.
    execute('let width = strlen(text[1:])+indent(2)*4+strlen(&sbr)*3')
    execute('$put =g:test')
    execute([[$put =printf(\"strdisplaywidth: %d == calculated: %d\", strdisplaywidth(text), width)]])
    execute([[let g:str="\t\t\t\t\t{"]])
    execute('let g:test=" Test 12: breakindent + long indent"')
    execute('wincmd p')
    execute('set all& breakindent linebreak briopt=min:10 nu numberwidth=3 ts=4')
    execute('$put =g:str')
    feed('zt')
    execute('let line1=ScreenChar(1,10)')
    execute('wincmd p')
    execute('call DoRecordScreen()')

    -- Test, that the string "    a\tb\tc\td\te" is correctly displayed in a
    -- 20 column wide window (see bug report
    -- https://groups.google.com/d/msg/vim_dev/ZOdg2mc9c9Y/TT8EhFjEy0IJ ).
    execute('only')
    execute('vert 20new')
    execute('set all& breakindent briopt=min:10')
    execute([[call setline(1, ["    a\tb\tc\td\te", "    z   y       x       w       v"])]])
    execute([[/^\s*a]])
    feed('fbgjyl')
    execute('let line1 = @0')
    execute([[?^\s*z]])
    feed('fygjyl')
    execute('let line2 = @0')
    execute('quit!')
    execute([[$put ='Test 13: breakindent with wrapping Tab']])
    execute('$put =line1')
    execute('$put =line2')

    execute('let g:test="Test 14: breakindent + visual blockwise delete #1"')
    execute('set all& breakindent shada+=nX-test-breakindent.shada')
    execute('30vnew')
    execute('normal! 3a1234567890')
    execute('normal! a    abcde')
    execute([[exec "normal! 0\<C-V>tex"]])
    execute('let line1=ScreenChar(line("."),8)')
    execute('call DoRecordScreen()')

    execute('let g:test="Test 15: breakindent + visual blockwise delete #2"')
    execute('%d')
    execute('normal! 4a1234567890')
    execute([[exec "normal! >>\<C-V>3f0x"]])
    execute('let line1=ScreenChar(line("."),20)')
    execute('call DoRecordScreen()')
    execute('quit!')

    -- Assert buffer contents.
    expect([[
      
      	abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP
      
      Test 1: Simple breakindent
          abcd
          qrst
          GHIJ
      
      Test 2: Simple breakindent + sbr=>>
          abcd
          >>qr
          >>EF
      
      Test 3: Simple breakindent + briopt:sbr
          abcd
      ++  qrst
      ++  GHIJ
      
      Test 4: Simple breakindent + min width: 18
          abcd
        qrstuv
        IJKLMN
      
       Test 5: Simple breakindent + shift by 2
          abcd
            qr
            EF
      
       Test 6: Simple breakindent + shift by -1
          abcd
         qrstu
         HIJKL
      
       Test 7: breakindent + shift by +1 + nu + sbr=? briopt:sbr
        2     ab
          ?    m
          ?    x
      
       Test 8: breakindent + shift:1 + nu + sbr=# list briopt:sbr
        2 ^Iabcd
          #  opq
          #  BCD
      
       Test 9: breakindent + shift by +1 + 'nu' + sbr=# list
        2 ^Iabcd
             #op
             #AB
      
       Test 10: breakindent + shift by +1 + 'nu' + sbr=~ cpo+=n
        2     ab
      ~       mn
      ~       yz
      
       Test 11: strdisplaywidth when breakindent is on
      strdisplaywidth: 46 == calculated: 64
      					{
      
       Test 12: breakindent + long indent
      56        
                
      ~         
      Test 13: breakindent with wrapping Tab
      d
      w
      
      Test 14: breakindent + visual blockwise delete #1
      e       
      ~       
      ~       
      
      Test 15: breakindent + visual blockwise delete #2
              1234567890  
      ~                   
      ~                   ]])
  end)
end)
