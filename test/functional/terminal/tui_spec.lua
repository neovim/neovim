-- Some sanity checks for the TUI using the builtin terminal emulator
-- as a simple way to send keys and assert screen state.
local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local feed = thelpers.feed_data
local execute = helpers.execute
local nvim_dir = helpers.nvim_dir

if helpers.pending_win32(pending) then return end

describe('tui', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    -- right now pasting can be really slow in the TUI, especially in ASAN.
    -- this will be fixed later but for now we require a high timeout.
    screen.timeout = 60000
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  after_each(function()
    screen:detach()
  end)

  it('accepts basic utf-8 input', function()
    feed('iabc\ntest1\ntest2')
    screen:expect([[
      abc                                               |
      test1                                             |
      test2{1: }                                            |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed('\027')
    screen:expect([[
      abc                                               |
      test1                                             |
      test{1:2}                                             |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('interprets leading <Esc> byte as ALT modifier in normal-mode', function()
    local keys = 'dfghjkl'
    for c in keys:gmatch('.') do
      execute('nnoremap <a-'..c..'> ialt-'..c..'<cr><esc>')
      feed('\027'..c)
    end
    screen:expect([[
      alt-j                                             |
      alt-k                                             |
      alt-l                                             |
      {1: }                                                 |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed('gg')
    screen:expect([[
      {1:a}lt-d                                             |
      alt-f                                             |
      alt-g                                             |
      alt-h                                             |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('does not mangle unmapped ALT-key chord', function()
    -- Vim represents ALT/META by setting the "high bit" of the modified key;
    -- we do _not_. #3982
    --
    -- Example: for input ALT+j:
    --    * Vim (Nvim prior to #3982) sets high-bit, inserts "ê".
    --    * Nvim (after #3982) inserts "j".
    feed('i\027j')
    screen:expect([[
      j{1: }                                                |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('accepts ascii control sequences', function()
    feed('i')
    feed('\022\007') -- ctrl+g
    feed('\022\022') -- ctrl+v
    feed('\022\013') -- ctrl+m
    screen:expect([[
    {9:^G^V^M}{1: }                                           |
    {4:~                                                 }|
    {4:~                                                 }|
    {4:~                                                 }|
    {5:[No Name] [+]                                     }|
    {3:-- INSERT --}                                      |
    {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('automatically sends <Paste> for bracketed paste sequences', function()
    feed('i\027[200~')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      {3:-- INSERT (paste) --}                              |
      {3:-- TERMINAL --}                                    |
    ]])
    feed('pasted from terminal')
    screen:expect([[
      pasted from terminal{1: }                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT (paste) --}                              |
      {3:-- TERMINAL --}                                    |
    ]])
    feed('\027[201~')
    screen:expect([[
      pasted from terminal{1: }                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('can handle arbitrarily long bursts of input', function()
    execute('set ruler')
    local t = {}
    for i = 1, 3000 do
      t[i] = 'item ' .. tostring(i)
    end
    feed('i\027[200~'..table.concat(t, '\n')..'\027[201~')
    screen:expect([[
      item 2997                                         |
      item 2998                                         |
      item 2999                                         |
      item 3000{1: }                                        |
      {5:[No Name] [+]                   3000,10        Bot}|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)
end)

describe('tui with non-tty file descriptors', function()
  before_each(helpers.clear)

  after_each(function()
    os.remove('testF') -- ensure test file is removed
  end)

  it('can handle pipes as stdout and stderr', function()
    local screen = thelpers.screen_setup(0, '"'..helpers.nvim_prog..' -u NONE -i NONE --cmd \'set noswapfile\' --cmd \'normal iabc\' > /dev/null 2>&1 && cat testF && rm testF"')
    feed(':w testF\n:q\n')
    screen:expect([[
      :w testF                                          |
      :q                                                |
      abc                                               |
                                                        |
      [Process exited 0]{1: }                               |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)
end)

describe('tui focus event handling', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    execute('autocmd FocusGained * echo "gained"')
    execute('autocmd FocusLost * echo "lost"')
  end)

  it('can handle focus events in normal mode', function()
    feed('\027[I')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      gained                                            |
      {3:-- TERMINAL --}                                    |
    ]])

    feed('\027[O')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      lost                                              |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('can handle focus events in insert mode', function()
    execute('set noshowmode')
    feed('i')
    feed('\027[I')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      gained                                            |
      {3:-- TERMINAL --}                                    |
    ]])
    feed('\027[O')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      lost                                              |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('can handle focus events in cmdline mode', function()
    feed(':')
    feed('\027[I')
    screen:expect([[
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      g{1:a}ined                                            |
      {3:-- TERMINAL --}                                    |
    ]])
    feed('\027[O')
    screen:expect([[
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      l{1:o}st                                              |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('can handle focus events in terminal mode', function()
    execute('set shell='..nvim_dir..'/shell-test')
    execute('set laststatus=0')
    execute('set noshowmode')
    execute('terminal')
    feed('\027[I')
    screen:expect([[
      ready $                                           |
      [Process exited 0]{1: }                               |
                                                        |
                                                        |
                                                        |
      gained                                            |
      {3:-- TERMINAL --}                                    |
    ]])
   feed('\027[O')
    screen:expect([[
      ready $                                           |
      [Process exited 0]{1: }                               |
                                                        |
                                                        |
                                                        |
      lost                                              |
      {3:-- TERMINAL --}                                    |
    ]])
  end)
end)

-- These tests require `thelpers` because --headless/--embed
-- does not initialize the TUI.
describe("tui 't_Co' (terminal colors)", function()
  local screen
  local is_linux = (helpers.eval("system('uname') =~? 'linux'") == 1)

  local function assert_term_colors(term, colorterm, maxcolors)
    helpers.clear({env={TERM=term}, args={}})
    -- This is ugly because :term/termopen() forces TERM=xterm-256color.
    -- TODO: Revisit this after jobstart/termopen accept `env` dict.
    screen = thelpers.screen_setup(0, string.format(
      [=[['sh', '-c', 'TERM=%s %s %s -u NONE -i NONE --cmd "silent set noswapfile"']]=],
      term,
      (colorterm ~= nil and "COLORTERM="..colorterm or ""),
      helpers.nvim_prog))

    thelpers.feed_data(":echo &t_Co\n")
    local tline
    if maxcolors == 8 then
      tline = "~                                                 "
    else
      tline = "{4:~                                                 }"
    end
    screen:expect(string.format([[
      {1: }                                                 |
      %s|
      %s|
      %s|
      {5:[No Name]                                         }|
      %-3s                                               |
      {3:-- TERMINAL --}                                    |
    ]], tline, tline, tline, tostring(maxcolors and maxcolors or "")))
  end

  it("unknown TERM sets empty 't_Co'", function()
    assert_term_colors("yet-another-term", nil, nil)
  end)

  it("unknown TERM with COLORTERM=screen-256color uses 256 colors", function()
    assert_term_colors("yet-another-term", "screen-256color", 256)
  end)

  it("TERM=linux uses 8 colors", function()
    if is_linux then
      assert_term_colors("linux", nil, 8)
    else
      pending()
    end
  end)

  it("TERM=screen uses 8 colors", function()
    if is_linux then
      assert_term_colors("screen", nil, 8)
    else
      pending()
    end
  end)

  it("TERM=screen COLORTERM=screen-256color uses 256 colors", function()
    assert_term_colors("screen", "screen-256color", 256)
  end)

  it("TERM=yet-another-term COLORTERM=screen-256color uses 256 colors", function()
    assert_term_colors("screen", "screen-256color", 256)
  end)

  it("TERM=xterm uses 256 colors", function()
    assert_term_colors("xterm", nil, 256)
  end)

  it("TERM=xterm-256color uses 256 colors", function()
    assert_term_colors("xterm-256color", nil, 256)
  end)
end)
