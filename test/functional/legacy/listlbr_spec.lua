-- Test for linebreak and list option (non-utf8)

local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local feed, insert, source = t.feed, t.insert, t.source
local clear, feed_command, expect = t.clear, t.feed_command, t.expect

describe('listlbr', function()
  before_each(clear)

  -- luacheck: ignore 621 (Indentation)
  -- luacheck: ignore 611 (Line contains only whitespaces)
  -- luacheck: ignore 613 (Trailing whitespaces in a string)
  it('is working', function()
    insert([[
      dummy text]])

    feed_command('set wildchar=^E')
    feed_command('10new')
    feed_command('vsp')
    feed_command('vert resize 20')
    feed_command([[put =\"\tabcdef hijklmn\tpqrstuvwxyz_1060ABCDEFGHIJKLMNOP \"]])
    feed_command('norm! zt')
    feed_command('set ts=4 sw=4 sts=4 linebreak sbr=+ wrap')
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
    feed_command('let g:test="Test 1: set linebreak"')
    feed_command('redraw!')
    feed_command('let line=ScreenChar(winwidth(0))')
    feed_command('call DoRecordScreen()')

    feed_command('let g:test="Test 2: set linebreak + set list"')
    feed_command('set linebreak list listchars=')
    feed_command('redraw!')
    feed_command('let line=ScreenChar(winwidth(0))')
    feed_command('call DoRecordScreen()')

    feed_command('let g:test ="Test 3: set linebreak nolist"')
    feed_command('set nolist linebreak')
    feed_command('redraw!')
    feed_command('let line=ScreenChar(winwidth(0))')
    feed_command('call DoRecordScreen()')

    feed_command(
      'let g:test ="Test 4: set linebreak with tab and 1 line as long as screen: should break!"'
    )
    feed_command('set nolist linebreak ts=8')
    feed_command([[let line="1\t".repeat('a', winwidth(0)-2)]])
    feed_command('$put =line')
    feed_command('$')
    feed_command('norm! zt')
    feed_command('redraw!')
    feed_command('let line=ScreenChar(winwidth(0))')
    feed_command('call DoRecordScreen()')
    feed_command([[let line="_S_\t bla"]])
    feed_command('$put =line')
    feed_command('$')
    feed_command('norm! zt')

    feed_command(
      'let g:test ="Test 5: set linebreak with conceal and set list and tab displayed by different char (line may not be truncated)"'
    )
    feed_command('set cpo&vim list linebreak conceallevel=2 concealcursor=nv listchars=tab:ab')
    feed_command('syn match ConcealVar contained /_/ conceal')
    feed_command('syn match All /.*/ contains=ConcealVar')
    feed_command('let line=ScreenChar(winwidth(0))')
    feed_command('call DoRecordScreen()')
    feed_command('set cpo&vim linebreak')

    feed_command('let g:test ="Test 6: set linebreak with visual block mode"')
    feed_command('let line="REMOVE: this not"')
    feed_command('$put =g:test')
    feed_command('$put =line')
    feed_command('let line="REMOVE: aaaaaaaaaaaaa"')
    feed_command('$put =line')
    feed_command('1/^REMOVE:')
    feed('0<C-V>jf x')
    feed_command('$put')
    feed_command('set cpo&vim linebreak')

    feed_command('let g:test ="Test 7: set linebreak with visual block mode and v_b_A"')
    feed_command('$put =g:test')
    feed('Golong line: <esc>40afoobar <esc>aTARGET at end<esc>')
    feed_command([[exe "norm! $3B\<C-v>eAx\<Esc>"]])
    feed_command('set cpo&vim linebreak sbr=')

    feed_command('let g:test ="Test 8: set linebreak with visual char mode and changing block"')
    feed_command('$put =g:test')
    feed('Go1111-1111-1111-11-1111-1111-1111<esc>0f-lv3lc2222<esc>bgj.')

    feed_command('let g:test ="Test 9: using redo after block visual mode"')
    feed_command('$put =g:test')
    feed('Go<CR>')
    feed('aaa<CR>')
    feed('aaa<CR>')
    feed('a<ESC>2k<C-V>2j~e.<CR>')

    feed_command('let g:test ="Test 10: using normal commands after block-visual"')
    feed_command('$put =g:test')
    feed_command('set linebreak')
    feed('Go<cr>')
    feed('abcd{ef<cr>')
    feed('ghijklm<cr>')
    feed('no}pqrs<esc>2k0f{<C-V><C-V>c%<esc>')

    feed_command('let g:test ="Test 11: using block replace mode after wrapping"')
    feed_command('$put =g:test')
    feed_command('set linebreak wrap')
    feed('Go<esc>150aa<esc>yypk147|<C-V>jr0<cr>')

    feed_command('let g:test ="Test 12: set linebreak list listchars=space:_,tab:>-,tail:-,eol:$"')
    feed_command('set list listchars=space:_,trail:-,tab:>-,eol:$')
    feed_command('$put =g:test')
    feed_command([[let line="a aaaaaaaaaaaaaaaaaaaaaa\ta "]])
    feed_command('$put =line')
    feed_command('$')
    feed_command('norm! zt')
    feed_command('redraw!')
    feed_command('let line=ScreenChar(winwidth(0))')
    feed_command('call DoRecordScreen()')

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

  -- oldtest: Test_linebreak_reset_restore()
  it('cursor position is drawn correctly after operator', function()
    local screen = Screen.new(60, 6)
    screen:attach()

    -- f_wincol() calls validate_cursor()
    source([[
      set linebreak showcmd noshowmode formatexpr=wincol()-wincol()
      call setline(1, repeat('a', &columns - 10) .. ' bbbbbbbbbb c')
    ]])

    feed('$v$')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa          |
      bbbbbbbbbb {17:c}^                                                |
      {1:~                                                           }|*3
                                                       2          |
    ]])
    feed('zo')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa          |
      bbbbbbbbbb ^c                                                |
      {1:~                                                           }|*3
      {9:E490: No fold found}                                         |
    ]])

    feed('$v$')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa          |
      bbbbbbbbbb {17:c}^                                                |
      {1:~                                                           }|*3
      {9:E490: No fold found}                              2          |
    ]])
    feed('gq')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa          |
      bbbbbbbbbb ^c                                                |
      {1:~                                                           }|*3
      {9:E490: No fold found}                                         |
    ]])

    feed('$<C-V>$')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa          |
      bbbbbbbbbb {17:c}^                                                |
      {1:~                                                           }|*3
      {9:E490: No fold found}                              1x2        |
    ]])
    feed('I')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa          |
      bbbbbbbbbb ^c                                                |
      {1:~                                                           }|*3
      {9:E490: No fold found}                                         |
    ]])

    feed('<Esc>$v$')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa          |
      bbbbbbbbbb {17:c}^                                                |
      {1:~                                                           }|*3
      {9:E490: No fold found}                              2          |
    ]])
    feed('s')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa          |
      bbbbbbbbbb ^                                                 |
      {1:~                                                           }|*3
      {9:E490: No fold found}                                         |
    ]])
  end)
end)
