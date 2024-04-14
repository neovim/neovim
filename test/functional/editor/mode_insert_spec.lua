-- Insert-mode tests.

local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = t.clear, t.feed, t.insert
local expect = t.expect
local command = t.command
local eq = t.eq
local eval = t.eval
local curbuf_contents = t.curbuf_contents
local api = t.api

describe('insert-mode', function()
  before_each(function()
    clear()
  end)

  it('indents only once after "!" keys #12894', function()
    command('let counter = []')
    command('set indentexpr=len(add(counter,0))')
    feed('i<C-F>x')
    eq(' x', curbuf_contents())
  end)

  it('CTRL-@', function()
    -- Inserts last-inserted text, leaves insert-mode.
    insert('hello')
    feed('i<C-@>x')
    expect('hellhello')

    -- C-Space is the same as C-@.
    -- CTRL-SPC inserts last-inserted text, leaves insert-mode.
    feed('i<C-Space>x')
    expect('hellhellhello')

    -- CTRL-A inserts last inserted text
    feed('i<C-A>x')
    expect('hellhellhellhelloxo')
  end)

  describe('Ctrl-R', function()
    it('works', function()
      command("let @@ = 'test'")
      feed('i<C-r>"')
      expect('test')
    end)

    it('works with multi-byte text', function()
      command("let @@ = 'påskägg'")
      feed('i<C-r>"')
      expect('påskägg')
    end)

    it('double quote is removed after hit-enter prompt #22609', function()
      local screen = Screen.new(50, 6)
      screen:attach()
      feed('i<C-R>')
      screen:expect([[
        {18:^"}                                                 |
        {1:~                                                 }|*4
        {5:-- INSERT --}                                      |
      ]])
      feed("=function('add')")
      screen:expect([[
        {18:"}                                                 |
        {1:~                                                 }|*4
        ={25:function}{16:(}{26:'add'}{16:)}^                                  |
      ]])
      feed('<CR>')
      screen:expect([[
        {18:"}                                                 |
        {1:~                                                 }|
        {3:                                                  }|
        ={25:function}{16:(}{26:'add'}{16:)}                                  |
        {9:E729: Using a Funcref as a String}                 |
        {6:Press ENTER or type command to continue}^           |
      ]])
      feed('<CR>')
      screen:expect([[
        ^                                                  |
        {1:~                                                 }|*4
        {5:-- INSERT --}                                      |
      ]])
    end)
  end)

  describe('Ctrl-O', function()
    it('enters command mode for one command', function()
      feed('ihello world<C-o>')
      feed(':let ctrlo = "test"<CR>')
      feed('iii')
      expect('hello worldiii')
      eq(1, eval('ctrlo ==# "test"'))
    end)

    it('re-enters insert mode at the end of the line when running startinsert', function()
      -- #6962
      feed('ihello world<C-o>')
      feed(':startinsert<CR>')
      feed('iii')
      expect('hello worldiii')
    end)

    it('re-enters insert mode at the beginning of the line when running startinsert', function()
      insert('hello world')
      feed('0<C-o>')
      feed(':startinsert<CR>')
      feed('aaa')
      expect('aaahello world')
    end)

    it('re-enters insert mode in the middle of the line when running startinsert', function()
      insert('hello world')
      feed('bi<C-o>')
      feed(':startinsert<CR>')
      feed('ooo')
      expect('hello oooworld')
    end)
  end)

  describe('Ctrl-V', function()
    it('supports entering the decimal value of a character', function()
      feed('i<C-V>076<C-V>167')
      expect('L§')
    end)

    it('supports entering the octal value of a character with "o"', function()
      feed('i<C-V>o114<C-V>o247<Esc>')
      expect('L§')
    end)

    it('supports entering the octal value of a character with "O"', function()
      feed('i<C-V>O114<C-V>O247<Esc>')
      expect('L§')
    end)

    it('supports entering the hexadecimal value of a character with "x"', function()
      feed('i<C-V>x4c<C-V>xA7<Esc>')
      expect('L§')
    end)

    it('supports entering the hexadecimal value of a character with "X"', function()
      feed('i<C-V>X4c<C-V>XA7<Esc>')
      expect('L§')
    end)

    it('supports entering the hexadecimal value of a character with "u"', function()
      feed('i<C-V>u25ba<C-V>u25C7<Esc>')
      expect('►◇')
    end)

    it('supports entering the hexadecimal value of a character with "U"', function()
      feed('i<C-V>U0001f600<C-V>U0001F601<Esc>')
      expect('😀😁')
    end)

    it('entering character by value is interrupted by invalid character', function()
      feed('i<C-V>76c<C-V>76<C-F2><C-V>u3c0j<C-V>u3c0<M-F3><C-V>U1f600j<C-V>U1f600<D-F4><Esc>')
      expect('LcL<C-F2>πjπ<M-F3>😀j😀<D-F4>')
    end)

    it('shows o, O, u, U, x, X, and digits with modifiers', function()
      feed('i<C-V><M-o><C-V><D-o><C-V><M-O><C-V><D-O><Esc>')
      expect('<M-o><D-o><M-O><D-O>')
      feed('cc<C-V><M-u><C-V><D-u><C-V><M-U><C-V><D-U><Esc>')
      expect('<M-u><D-u><M-U><D-U>')
      feed('cc<C-V><M-x><C-V><D-x><C-V><M-X><C-V><D-X><Esc>')
      expect('<M-x><D-x><M-X><D-X>')
      feed('cc<C-V><M-1><C-V><D-2><C-V><M-7><C-V><D-8><Esc>')
      expect('<M-1><D-2><M-7><D-8>')
    end)
  end)

  it('Ctrl-Shift-V supports entering unsimplified key notations', function()
    feed('i<C-S-V><C-J><C-S-V><C-@><C-S-V><C-[><C-S-V><C-S-M><C-S-V><M-C-I><C-S-V><C-D-J><Esc>')
    expect('<C-J><C-@><C-[><C-S-M><M-C-I><C-D-J>')
  end)

  it('multi-char mapping updates screen properly #25626', function()
    local screen = Screen.new(60, 6)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { bold = true, reverse = true }, -- StatusLine
      [2] = { reverse = true }, -- StatusLineNC
      [3] = { bold = true }, -- ModeMsg
    })
    screen:attach()
    command('vnew')
    insert('foo\nfoo\nfoo')
    command('wincmd w')
    command('set timeoutlen=10000')
    command('inoremap jk <Esc>')
    feed('i<CR>βββ<Left><Left>j')
    screen:expect {
      grid = [[
      foo                           │                             |
      foo                           │β^jβ                          |
      foo                           │{0:~                            }|
      {0:~                             }│{0:~                            }|
      {2:[No Name] [+]                  }{1:[No Name] [+]                }|
      {3:-- INSERT --}                                                |
    ]],
    }
    feed('k')
    screen:expect {
      grid = [[
      foo                           │                             |
      foo                           │^βββ                          |
      foo                           │{0:~                            }|
      {0:~                             }│{0:~                            }|
      {2:[No Name] [+]                  }{1:[No Name] [+]                }|
                                                                  |
    ]],
    }
  end)

  describe('backspace', function()
    local function set_lines(line_b, line_e, ...)
      api.nvim_buf_set_lines(0, line_b, line_e, true, { ... })
    end
    local function s(count)
      return (' '):rep(count)
    end

    local function test_cols(expected_cols)
      local cols = { { t.fn.col('.'), t.fn.virtcol('.') } }
      for _ = 2, #expected_cols do
        feed('<BS>')
        table.insert(cols, { t.fn.col('.'), t.fn.virtcol('.') })
      end
      eq(expected_cols, cols)
    end

    it('works with tabs and spaces', function()
      local screen = Screen.new(30, 2)
      screen:attach()
      command('setl ts=4 sw=4')
      set_lines(0, 1, '\t' .. s(4) .. '\t' .. s(9) .. '\t a')
      feed('$i')
      test_cols({
        { 18, 26 },
        { 17, 25 },
        { 15, 21 },
        { 11, 17 },
        { 7, 13 },
        { 6, 9 },
        { 2, 5 },
        { 1, 1 },
      })
    end)

    it('works with varsofttabstop', function()
      local screen = Screen.new(30, 2)
      screen:attach()
      command('setl vsts=6,2,5,3')
      set_lines(0, 1, 'a\t' .. s(4) .. '\t a')
      feed('$i')
      test_cols({
        { 9, 18 },
        { 8, 17 },
        { 8, 14 },
        { 3, 9 },
        { 7, 7 },
        { 2, 2 },
        { 1, 1 },
      })
    end)

    it('works with tab as ^I', function()
      local screen = Screen.new(30, 2)
      screen:attach()
      command('set list listchars=space:.')
      command('setl ts=4 sw=4')
      set_lines(0, 1, '\t' .. s(4) .. '\t' .. s(9) .. '\t a')
      feed('$i')
      test_cols({
        { 18, 21 },
        { 15, 17 },
        { 11, 13 },
        { 7, 9 },
        { 4, 5 },
        { 1, 1 },
      })
    end)

    it('works in replace mode', function()
      local screen = Screen.new(50, 2)
      screen:attach()
      command('setl ts=8 sw=8 sts=8')
      set_lines(0, 1, '\t' .. s(4) .. '\t' .. s(9) .. '\t a')
      feed('$R')
      test_cols({
        { 18, 34 },
        { 17, 33 },
        { 15, 25 },
        { 7, 17 },
        { 2, 9 },
        { 1, 8 }, -- last screen cell of first tab is at vcol 8
      })
    end)

    it('works with breakindent', function()
      local screen = Screen.new(17, 4)
      screen:attach()
      command('setl ts=4 sw=4 bri briopt=min:5')
      set_lines(0, 1, '\t' .. s(4) .. '\t' .. s(9) .. '\t a')
      feed('$i')
      test_cols({
        { 18, 50 },
        { 17, 49 },
        { 15, 33 },
        { 11, 17 },
        { 7, 13 },
        { 6, 9 },
        { 2, 5 },
        { 1, 1 },
      })
    end)

    it('works with inline virtual text', function()
      local screen = Screen.new(50, 2)
      screen:attach()
      command('setl ts=4 sw=4')
      set_lines(0, 1, '\t' .. s(4) .. '\t' .. s(9) .. '\t a')
      local ns = api.nvim_create_namespace('')
      local vt_opts = { virt_text = { { 'text' } }, virt_text_pos = 'inline' }
      api.nvim_buf_set_extmark(0, ns, 0, 2, vt_opts)
      feed('$i')
      test_cols({
        { 18, 30 },
        { 17, 29 },
        { 15, 25 },
        { 11, 21 },
        { 7, 17 },
        { 6, 13 },
        { 2, 9 },
        { 1, 5 },
      })
    end)

    it("works with 'revins'", function()
      local screen = Screen.new(30, 3)
      screen:attach()
      command('setl ts=4 sw=4 revins')
      set_lines(0, 1, ('a'):rep(16), s(3) .. '\t' .. s(4) .. '\t a')
      feed('j$i')
      test_cols({
        { 11, 14 },
        { 10, 13 },
        { 9, 9 },
        { 5, 5 },
        { 1, 1 },
        { 1, 1 }, -- backspace on empty line does nothing
      })
      eq(2, api.nvim_win_get_cursor(0)[1])
    end)
  end)
end)
