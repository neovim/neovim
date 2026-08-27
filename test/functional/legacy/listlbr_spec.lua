-- Test for linebreak and list option (non-utf8)

local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local feed, insert, source = n.feed, n.insert, n.source
local clear, command, feed_command, expect = n.clear, n.command, n.feed_command, n.expect

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

      AAA
      AAA
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

  it('does not bleed match/extmark highlight into the filler before a wrapped word', function()
    local screen = Screen.new(60, 3)
    screen:add_extra_attr_ids({ [100] = { underline = true } })
    source([[
      set wrap linebreak
      call setline(1, '[license-commit]: https://github.com/neovim/neovim/commit/b17d9691a24099c9210289f16afb1a498a89d803')
      highlight TestUL gui=underline cterm=underline
    ]])

    -- Highlight extends past the break point: must not bleed into the filler before the
    -- pushed-down word, whether applied via matchadd() (search_attr) or an extmark (decor_attr).
    local expected = [[
      ^[license-commit]: {100:https://github.com/neovim/neovim/commit/}  |
      {100:b17d9691a24099c9210289f16afb1a498a89d803}                    |
                                                                  |
    ]]

    command([[call matchadd('TestUL', 'https://.*$')]])
    screen:expect(expected)

    -- Confirm the highlight actually toggles off before re-checking via the extmark path below,
    -- so the second `expect(expected)` proves that path redraws correctly instead of coasting on
    -- leftover state from matchadd().
    command('call clearmatches()')
    screen:expect([[
      ^[license-commit]: https://github.com/neovim/neovim/commit/  |
      b17d9691a24099c9210289f16afb1a498a89d803                    |
                                                                  |
    ]])

    command([[call nvim_buf_add_highlight(0, -1, 'TestUL', 0, 18, -1)]])
    screen:expect(expected)
  end)

  it('extends a to-end-of-line syntax highlight through the filler', function()
    local screen = Screen.new(30, 5)
    screen:add_extra_attr_ids({ [100] = { reverse = true } })
    source([[
      set wrap linebreak
      call setline(1, 'section.heading:' . repeat(' ', 40) . 'END')
      syntax match TestBar /^.*$/
      highlight TestBar gui=reverse cterm=reverse
    ]])

    -- Unlike the tests above: the filler here is real trailing padding covered by the same 'to end
    -- of line' match, so it must keep the highlight instead of going blank.
    screen:expect([[
      {100:^section.                      }|
      {100:heading:                      }|
      {100:                  END}         |
      {1:~                             }|
                                    |
    ]])
  end)

  it('extends a background highlight into the filler only with hl_eol', function()
    local screen = Screen.new(20, 5)
    screen:add_extra_attr_ids({ [100] = { background = Screen.colors.Red } })
    source([[
      set wrap linebreak
      call setline(1, 'word1.word2verylongwordthatpushesdown')
      highlight TestBg guibg=Red ctermbg=Red
      let g:ns = nvim_create_namespace('')
    ]])

    -- 'hl_eol' covers cells with no text behind them, so the filler is covered too.
    command(
      'call nvim_buf_set_extmark(0, g:ns, 0, 0, '
        .. "{'end_row': 1, 'hl_group': 'TestBg', 'hl_eol': v:true})"
    )
    screen:expect([[
      {100:^word1.              }|
      {100:word2verylongwordtha}|
      {100:tpushesdown         }|
      {1:~                   }|
                          |
    ]])

    -- Without it the highlight decorates characters, so it stops where they do, just as an
    -- underline already does (see tests above).
    command('call nvim_buf_clear_namespace(0, -1, 0, -1)')
    command([[call nvim_buf_add_highlight(0, -1, 'TestBg', 0, 0, -1)]])
    screen:expect([[
      {100:^word1.}              |
      {100:word2verylongwordtha}|
      {100:tpushesdown}         |
      {1:~                   }|
                          |
    ]])
  end)
end)
