-- Test for linebreak and list option (non-utf8)

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('listlbr', function()
  setup(clear)

  it('is working', function()
    insert([[
      dummy text]])

    execute('set wildchar=^E')
    execute('10new')
    execute('vsp')
    execute('vert resize 20')
    execute([[put =\"\tabcdef hijklmn\tpqrstuvwxyz_1060ABCDEFGHIJKLMNOP \"]])
    execute('norm! zt')
    execute('set ts=4 sw=4 sts=4 linebreak sbr=+ wrap')
    source([[
      fu! ScreenChar(width)
      	let c=''
      	for j in range(1,4)
	  for i in range(1,a:width)
	    let c.=nr2char(screenchar(j, i))
	  endfor
	  let c.="\n"
      	endfor
      	return c
      endfu
      fu! DoRecordScreen()
      	wincmd l
      	$put =printf(\"\n%s\", g:test)
      	$put =g:line
      	wincmd p
      endfu
    ]])
    execute('let g:test="Test 1: set linebreak"')
    execute('redraw!')
    execute('let line=ScreenChar(winwidth(0))')
    execute('call DoRecordScreen()')

    execute('let g:test="Test 2: set linebreak + set list"')
    execute('set linebreak list listchars=')
    execute('redraw!')
    execute('let line=ScreenChar(winwidth(0))')
    execute('call DoRecordScreen()')

    execute('let g:test ="Test 3: set linebreak nolist"')
    execute('set nolist linebreak')
    execute('redraw!')
    execute('let line=ScreenChar(winwidth(0))')
    execute('call DoRecordScreen()')

    execute('let g:test ="Test 4: set linebreak with tab and 1 line as long as screen: should break!"')
    execute('set nolist linebreak ts=8')
    execute([[let line="1\t".repeat('a', winwidth(0)-2)]])
    execute('$put =line')
    execute('$')
    execute('norm! zt')
    execute('redraw!')
    execute('let line=ScreenChar(winwidth(0))')
    execute('call DoRecordScreen()')
    execute([[let line="_S_\t bla"]])
    execute('$put =line')
    execute('$')
    execute('norm! zt')

    execute('let g:test ="Test 5: set linebreak with conceal and set list and tab displayed by different char (line may not be truncated)"')
    execute('set cpo&vim list linebreak conceallevel=2 concealcursor=nv listchars=tab:ab')
    execute('syn match ConcealVar contained /_/ conceal')
    execute('syn match All /.*/ contains=ConcealVar')
    execute('let line=ScreenChar(winwidth(0))')
    execute('call DoRecordScreen()')
    execute('set cpo&vim linebreak')

    execute('let g:test ="Test 6: set linebreak with visual block mode"')
    execute('let line="REMOVE: this not"')
    execute('$put =g:test')
    execute('$put =line')
    execute('let line="REMOVE: aaaaaaaaaaaaa"')
    execute('$put =line')
    execute('1/^REMOVE:')
    feed('0<C-V>jf x')
    execute('$put')
    execute('set cpo&vim linebreak')

    execute('let g:test ="Test 7: set linebreak with visual block mode and v_b_A"')
    execute('$put =g:test')
    feed('Golong line: <esc>40afoobar <esc>aTARGET at end<esc>')
    execute([[exe "norm! $3B\<C-v>eAx\<Esc>"]])
    execute('set cpo&vim linebreak sbr=')

    execute('let g:test ="Test 8: set linebreak with visual char mode and changing block"')
    execute('$put =g:test')
    feed('Go1111-1111-1111-11-1111-1111-1111<esc>0f-lv3lc2222<esc>bgj.')

    execute('let g:test ="Test 9: using redo after block visual mode"')
    execute('$put =g:test')
    feed('Go<CR>')
    feed('aaa<CR>')
    feed('aaa<CR>')
    feed('a<ESC>2k<C-V>2j~e.<CR>')

    execute('let g:test ="Test 10: using normal commands after block-visual"')
    execute('$put =g:test')
    execute('set linebreak')
    feed('Go<cr>')
    feed('abcd{ef<cr>')
    feed('ghijklm<cr>')
    feed('no}pqrs<esc>2k0f{<C-V><C-V>c%<esc>')

    execute('let g:test ="Test 11: using block replace mode after wrapping"')
    execute('$put =g:test')
    execute('set linebreak wrap')
    feed('Go<esc>150aa<esc>yypk147|<C-V>jr0<cr>')

    execute('let g:test ="Test 12: set linebreak list listchars=space:_,tab:>-,tail:-,eol:$"')
    execute('set list listchars=space:_,trail:-,tab:>-,eol:$')
    execute('$put =g:test')
    execute([[let line="a aaaaaaaaaaaaaaaaaaaaaa\ta "]])
    execute('$put =line')
    execute('$')
    execute('norm! zt')
    execute('redraw!')
    execute('let line=ScreenChar(winwidth(0))')
    execute('call DoRecordScreen()')

    -- Assert buffer contents.
    expect([[
      
      	abcdef hijklmn	pqrstuvwxyz_1060ABCDEFGHIJKLMNOP 
      
      Test 1: set linebreak
          abcdef          
      +hijklmn            
      +pqrstuvwxyz_1060ABC
      +DEFGHIJKLMNOP      
      
      Test 2: set linebreak + set list
      ^Iabcdef hijklmn^I  
      +pqrstuvwxyz_1060ABC
      +DEFGHIJKLMNOP      
                          
      
      Test 3: set linebreak nolist
          abcdef          
      +hijklmn            
      +pqrstuvwxyz_1060ABC
      +DEFGHIJKLMNOP      
      1	aaaaaaaaaaaaaaaaaa
      
      Test 4: set linebreak with tab and 1 line as long as screen: should break!
      1                   
      +aaaaaaaaaaaaaaaaaa 
      ~                   
      ~                   
      _S_	 bla
      
      Test 5: set linebreak with conceal and set list and tab displayed by different char (line may not be truncated)
      Sabbbbbb bla        
      ~                   
      ~                   
      ~                   
      Test 6: set linebreak with visual block mode
      this not
      aaaaaaaaaaaaa
      REMOVE: 
      REMOVE: 
      Test 7: set linebreak with visual block mode and v_b_A
      long line: foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar TARGETx at end
      Test 8: set linebreak with visual char mode and changing block
      1111-2222-1111-11-1111-2222-1111
      Test 9: using redo after block visual mode
      
      AaA
      AaA
      A
      Test 10: using normal commands after block-visual
      
      abcdpqrs
      Test 11: using block replace mode after wrapping
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0aaa
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0aaa
      Test 12: set linebreak list listchars=space:_,tab:>-,tail:-,eol:$
      a aaaaaaaaaaaaaaaaaaaaaa	a 
      
      Test 12: set linebreak list listchars=space:_,tab:>-,tail:-,eol:$
      a_                  
      aaaaaaaaaaaaaaaaaaaa
      aa>-----a-$         
      ~                   ]])
  end)
end)
