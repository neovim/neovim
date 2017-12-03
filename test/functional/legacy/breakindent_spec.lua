-- Test for breakindent

local helpers = require('test.functional.helpers')(after_each)
local feed, insert = helpers.feed, helpers.insert
local clear, feed_command, expect = helpers.clear, helpers.feed_command, helpers.expect

describe('breakindent', function()
  setup(clear)

  -- luacheck: ignore 621 (Indentation)
  -- luacheck: ignore 613 (Trailing whitespace in a string)
  -- luacheck: ignore 611 (Line contains only whitespaces)
  it('is working', function()
    insert('dummy text')

    feed_command('set wildchar=^E')
    feed_command('10new')
    feed_command('vsp')
    feed_command('vert resize 20')
    feed_command([[put =\"\tabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP\"]])
    feed_command('set ts=4 sw=4 sts=4 breakindent')
    feed_command('fu! ScreenChar(line, width)')
    feed_command('	let c=""')
    feed_command('	for i in range(1,a:width)')
    feed_command('		let c.=nr2char(screenchar(a:line, i))')
    feed_command('	endfor')
    feed_command([[       let c.="\n"]])
    feed_command('	for i in range(1,a:width)')
    feed_command('		let c.=nr2char(screenchar(a:line+1, i))')
    feed_command('	endfor')
    feed_command([[       let c.="\n"]])
    feed_command('	for i in range(1,a:width)')
    feed_command('		let c.=nr2char(screenchar(a:line+2, i))')
    feed_command('	endfor')
    feed_command('	return c')
    feed_command('endfu')
    feed_command('fu DoRecordScreen()')
    feed_command('	wincmd l')
    feed_command([[	$put =printf(\"\n%s\", g:test)]])
    feed_command('	$put =g:line1')
    feed_command('	wincmd p')
    feed_command('endfu')
    feed_command('set briopt=min:0')
    feed_command('let g:test="Test 1: Simple breakindent"')
    feed_command('let line1=ScreenChar(line("."),8)')
    feed_command('call DoRecordScreen()')
    feed_command('let g:test="Test 2: Simple breakindent + sbr=>>"')
    feed_command('set sbr=>>')
    feed_command('let line1=ScreenChar(line("."),8)')
    feed_command('call DoRecordScreen()')
    feed_command('let g:test ="Test 3: Simple breakindent + briopt:sbr"')
    feed_command('set briopt=sbr,min:0 sbr=++')
    feed_command('let line1=ScreenChar(line("."),8)')
    feed_command('call DoRecordScreen()')
    feed_command('let g:test ="Test 4: Simple breakindent + min width: 18"')
    feed_command('set sbr= briopt=min:18')
    feed_command('let line1=ScreenChar(line("."),8)')
    feed_command('call DoRecordScreen()')
    feed_command('let g:test =" Test 5: Simple breakindent + shift by 2"')
    feed_command('set briopt=shift:2,min:0')
    feed_command('let line1=ScreenChar(line("."),8)')
    feed_command('call DoRecordScreen()')
    feed_command('let g:test=" Test 6: Simple breakindent + shift by -1"')
    feed_command('set briopt=shift:-1,min:0')
    feed_command('let line1=ScreenChar(line("."),8)')
    feed_command('call DoRecordScreen()')
    feed_command('let g:test=" Test 7: breakindent + shift by +1 + nu + sbr=? briopt:sbr"')
    feed_command('set briopt=shift:1,sbr,min:0 nu sbr=? nuw=4')
    feed_command('let line1=ScreenChar(line("."),10)')
    feed_command('call DoRecordScreen()')
    feed_command('let g:test=" Test 8: breakindent + shift:1 + nu + sbr=# list briopt:sbr"')
    feed_command('set briopt=shift:1,sbr,min:0 nu sbr=# list lcs&vi')
    feed_command('let line1=ScreenChar(line("."),10)')
    feed_command('call DoRecordScreen()')
    feed_command([[let g:test=" Test 9: breakindent + shift by +1 + 'nu' + sbr=# list"]])
    feed_command('set briopt-=sbr')
    feed_command('let line1=ScreenChar(line("."),10)')
    feed_command('call DoRecordScreen()')
    feed_command([[let g:test=" Test 10: breakindent + shift by +1 + 'nu' + sbr=~ cpo+=n"]])
    feed_command('set cpo+=n sbr=~ nu nuw=4 nolist briopt=sbr,min:0')
    feed_command('let line1=ScreenChar(line("."),10)')
    feed_command('call DoRecordScreen()')
    feed_command('wincmd p')
    feed_command([[let g:test="\n Test 11: strdisplaywidth when breakindent is on"]])
    feed_command('set cpo-=n sbr=>> nu nuw=4 nolist briopt= ts=4')
    -- Skip leading tab when calculating text width.
    feed_command('let text=getline(2)')
    -- Text wraps 3 times.
    feed_command('let width = strlen(text[1:])+indent(2)*4+strlen(&sbr)*3')
    feed_command('$put =g:test')
    feed_command([[$put =printf(\"strdisplaywidth: %d == calculated: %d\", strdisplaywidth(text), width)]])
    feed_command([[let g:str="\t\t\t\t\t{"]])
    feed_command('let g:test=" Test 12: breakindent + long indent"')
    feed_command('wincmd p')
    feed_command('set all& breakindent linebreak briopt=min:10 nu numberwidth=3 ts=4')
    feed_command('$put =g:str')
    feed('zt')
    feed_command('let line1=ScreenChar(1,10)')
    feed_command('wincmd p')
    feed_command('call DoRecordScreen()')

    -- Test, that the string "    a\tb\tc\td\te" is correctly displayed in a
    -- 20 column wide window (see bug report
    -- https://groups.google.com/d/msg/vim_dev/ZOdg2mc9c9Y/TT8EhFjEy0IJ ).
    feed_command('only')
    feed_command('vert 20new')
    feed_command('set all& breakindent briopt=min:10')
    feed_command([[call setline(1, ["    a\tb\tc\td\te", "    z   y       x       w       v"])]])
    feed_command([[/^\s*a]])
    feed('fbgjyl')
    feed_command('let line1 = @0')
    feed_command([[?^\s*z]])
    feed('fygjyl')
    feed_command('let line2 = @0')
    feed_command('quit!')
    feed_command([[$put ='Test 13: breakindent with wrapping Tab']])
    feed_command('$put =line1')
    feed_command('$put =line2')

    feed_command('let g:test="Test 14: breakindent + visual blockwise delete #1"')
    feed_command('set all& breakindent shada+=nX-test-breakindent.shada')
    feed_command('30vnew')
    feed_command('normal! 3a1234567890')
    feed_command('normal! a    abcde')
    feed_command([[exec "normal! 0\<C-V>tex"]])
    feed_command('let line1=ScreenChar(line("."),8)')
    feed_command('call DoRecordScreen()')

    feed_command('let g:test="Test 15: breakindent + visual blockwise delete #2"')
    feed_command('%d')
    feed_command('normal! 4a1234567890')
    feed_command([[exec "normal! >>\<C-V>3f0x"]])
    feed_command('let line1=ScreenChar(line("."),20)')
    feed_command('call DoRecordScreen()')
    feed_command('quit!')

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
