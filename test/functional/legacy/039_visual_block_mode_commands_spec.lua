-- Test Visual block mode commands
-- And test "U" in Visual mode, also on German sharp S.

local t = require('test.functional.testutil')(after_each)
local nvim, eq = t.api, t.eq
local insert, feed = t.insert, t.feed
local clear, expect = t.clear, t.expect
local feed_command = t.feed_command

describe('Visual block mode', function()
  before_each(function()
    clear()

    feed_command('set ts&vi sw&vi sts&vi noet') -- Vim compatible
  end)

  it('should shift, insert, replace and change a block', function()
    insert([[
      abcdefghijklm
      abcdefghijklm
      abcdefghijklm
      abcdefghijklm
      abcdefghijklm]])

    feed('gg')
    -- Test shift-right of a block
    feed('jllll<C-v>jj>wll<C-v>jlll><CR>')
    -- Test shift-left of a block
    feed('G$hhhh<C-v>kk<lt>')
    -- Test block-insert
    feed('Gkl<C-v>kkkIxyz<ESC>')
    -- Test block-replace
    feed('Gllll<C-v>kkklllrq')
    -- Test block-change
    feed('G$khhh<C-v>hhkkcmno<ESC>')

    expect([[
      axyzbcdefghijklm
      axyzqqqq   mno	      ghijklm
      axyzqqqqef mno        ghijklm
      axyzqqqqefgmnoklm
      abcdqqqqijklm]])
  end)

  -- luacheck: ignore 611 (Line contains only whitespaces)
  it('should insert a block using cursor keys for movement', function()
    insert([[
      aaaaaa
      bbbbbb
      cccccc
      dddddd
      
      xaaa
      bbbb
      cccc
      dddd]])

    feed_command('/^aa')
    feed('l<C-v>jjjlllI<Right><Right>  <ESC>')
    feed_command('/xaaa$')
    feed('<C-v>jjjI<lt>><Left>p<ESC>')

    expect([[
      aaa  aaa
      bbb  bbb
      ccc  ccc
      ddd  ddd
      
      <p>xaaa
      <p>bbbb
      <p>cccc
      <p>dddd]])
  end)

  it('should create a block', function()
    insert([[
      A23
      4567
      
      B23
      4567
      
      C23
      4567]])

    -- Test for Visual block was created with the last <C-v>$.
    feed_command('/^A23$/')
    feed('l<C-v>j$Aab<ESC>')
    -- Test for Visual block was created with the middle <C-v>$ (1).
    feed_command('/^B23$/')
    feed('l<C-v>j$hAab<ESC>')
    -- Test for Visual block was created with the middle <C-v>$ (2).
    feed_command('/^C23$/')
    feed('l<C-v>j$hhAab<ESC>')

    expect([[
      A23ab
      4567ab
      
      B23 ab
      4567ab
      
      C23ab
      456ab7]])
  end)

  -- luacheck: ignore 621 (Indentation)
  it('should insert and append a block when virtualedit=all', function()
    insert([[
      		line1
      		line2
      		line3
      ]])

    -- Test for Visual block insert when virtualedit=all and utf-8 encoding.
    feed_command('set ve=all')
    feed_command('/\t\tline')
    feed('07l<C-v>jjIx<ESC>')

    expect([[
             x 	line1
             x 	line2
             x 	line3
      ]])

    -- Test for Visual block append when virtualedit=all.
    feed('012l<C-v>jjAx<ESC>')

    expect([[
             x     x   line1
             x     x   line2
             x     x   line3
      ]])
  end)

  it('should make a selected part uppercase', function()
    -- GUe must uppercase a whole word, also when ß changes to ẞ.
    feed('Gothe youtußeuu end<ESC>Ypk0wgUe<CR>')
    -- GUfx must uppercase until x, inclusive.
    feed('O- youßtußexu -<ESC>0fogUfx<CR>')
    -- VU must uppercase a whole line.
    feed('YpkVU<CR>')
    -- Same, when it's the last line in the buffer.
    feed('YPGi111<ESC>VUddP<CR>')
    -- Uppercase two lines.
    feed('Oblah di<CR>')
    feed('doh dut<ESC>VkUj<CR>')
    -- Uppercase part of two lines.
    feed('ddppi333<ESC>k0i222<esc>fyllvjfuUk<CR>')

    expect([[
      
      the YOUTUẞEUU end
      - yOUẞTUẞEXu -
      THE YOUTUẞEUU END
      111THE YOUTUẞEUU END
      BLAH DI
      DOH DUT
      222the yoUTUẞEUU END
      333THE YOUTUßeuu end]])
  end)

  it('should replace using Enter or NL', function()
    -- Visual replace using Enter or NL.
    feed('G3o123456789<ESC>2k05l<C-v>2jr<CR>')
    feed('G3o98765<ESC>2k02l<C-v>2jr<C-v><CR>')
    feed('G3o123456789<ESC>2k05l<C-v>2jr<CR>')
    feed('G3o98765<ESC>2k02l<C-v>2jr<C-v><Nul>')

    local expected = [[
      
      12345
      789
      12345
      789
      12345
      789
      98<CR>65
      98<CR>65
      98<CR>65
      12345
      789
      12345
      789
      12345
      789
      98<Nul>65
      98<Nul>65
      98<Nul>65]]
    expected = expected:gsub('<CR>', '\r')
    expected = expected:gsub('<Nul>', '\000')

    expect(expected)
  end)

  it('should treat cursor position correctly when virtualedit=block', function()
    insert([[
      12345
      789
      98765]])

    -- Test cursor position. When virtualedit=block and Visual block mode and $gj.
    feed_command('set ve=block')
    feed('G2l')
    feed('2k<C-v>$gj<ESC>')
    feed_command([[let cpos=getpos("'>")]])
    local cpos = nvim.nvim_get_var('cpos')
    local expected = {
      col = 4,
      off = 0,
    }
    local actual = {
      col = cpos[3],
      off = cpos[4],
    }

    eq(expected, actual)
  end)

  it('should replace spaces in front of the block with tabs', function()
    insert([[
      #define BO_ALL	    0x0001
      #define BO_BS	    0x0002
      #define BO_CRSR	    0x0004]])

    -- Block_insert when replacing spaces in front of the block with tabs.
    feed_command('set ts=8 sts=4 sw=4')
    feed('ggf0<C-v>2jI<TAB><ESC>')

    expect([[
      #define BO_ALL		0x0001
      #define BO_BS	    	0x0002
      #define BO_CRSR	    	0x0004]])
  end)
end)
