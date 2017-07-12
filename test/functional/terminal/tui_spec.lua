-- Some sanity checks for the TUI using the builtin terminal emulator
-- as a simple way to send keys and assert screen state.
local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local feed_data = thelpers.feed_data
local feed_command = helpers.feed_command
local nvim_dir = helpers.nvim_dir
local retry = helpers.retry
local clear, eq, eval, exc_exec, feed_command, feed, insert, neq, next_msg, nvim,
  nvim_dir, ok, source, write_file, mkdir, rmdir = helpers.clear,
  helpers.eq, helpers.eval, helpers.exc_exec, helpers.feed_command, helpers.feed,
  helpers.insert, helpers.neq, helpers.next_message, helpers.nvim,
  helpers.nvim_dir, helpers.ok, helpers.source,
  helpers.write_file, helpers.mkdir, helpers.rmdir

if helpers.pending_win32(pending) then return end

describe('tui', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]')
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
    feed_data('iabc\ntest1\ntest2')
    screen:expect([[
      abc                                               |
      test1                                             |
      test2{1: }                                            |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027')
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
      feed_command('nnoremap <a-'..c..'> ialt-'..c..'<cr><esc>')
      feed_data('\027'..c)
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
    feed_data('gg')
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
    feed_data('i\027j')
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
    feed_data('i')
    feed_data('\022\007') -- ctrl+g
    feed_data('\022\022') -- ctrl+v
    feed_data('\022\013') -- ctrl+m
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
    feed_data('i\027[200~')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      {3:-- INSERT (paste) --}                              |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('pasted from terminal')
    screen:expect([[
      pasted from terminal{1: }                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT (paste) --}                              |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[201~')
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
    feed_command('set ruler')
    local t = {}
    for i = 1, 3000 do
      t[i] = 'item ' .. tostring(i)
    end
    feed_data('i\027[200~'..table.concat(t, '\n')..'\027[201~')
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
    local screen = thelpers.screen_setup(0, '"'..helpers.nvim_prog
      ..' -u NONE -i NONE --cmd \'set noswapfile noshowcmd noruler\' --cmd \'normal iabc\' > /dev/null 2>&1 && cat testF && rm testF"')
    feed_data(':w testF\n:q\n')
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
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]')
    feed_data(":autocmd FocusGained * echo 'gained'\n")
    feed_data(":autocmd FocusLost * echo 'lost'\n")
    feed_data("\034\016")  -- CTRL-\ CTRL-N
  end)

  it('can handle focus events in normal mode', function()
    feed_data('\027[I')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      gained                                            |
      {3:-- TERMINAL --}                                    |
    ]])

    feed_data('\027[O')
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
    feed_command('set noshowmode')
    feed_data('i')
    feed_data('\027[I')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      gained                                            |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[O')
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
    feed_data(':')
    feed_data('\027[I')
    screen:expect([[
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      g{1:a}ined                                            |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[O')
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
    feed_data(':set shell='..nvim_dir..'/shell-test\n')
    feed_data(':set noshowmode laststatus=0\n')

    retry(2, 3 * screen.timeout, function()
      feed_data(':terminal\n')
      feed_data('\027[I')
      screen:expect([[
        ready $                                           |
        [Process exited 0]{1: }                               |
                                                          |
                                                          |
                                                          |
        gained                                            |
        {3:-- TERMINAL --}                                    |
      ]])
      feed_data('\027[O')
      screen:expect([[
        ready $                                           |
        [Process exited 0]{1: }                               |
                                                          |
                                                          |
                                                          |
        lost                                              |
        {3:-- TERMINAL --}                                    |
      ]])

      -- If retry is needed...
      feed_data("\034\016")  -- CTRL-\ CTRL-N
      feed_data(':bwipeout!\n')
    end)
  end)
end)

-- These tests require `thelpers` because --headless/--embed
-- does not initialize the TUI.
describe("tui 't_Co' (terminal colors)", function()
  local screen
  local is_freebsd = (helpers.eval("system('uname') =~? 'FreeBSD'") == 1)

  local function assert_term_colors(term, colorterm, maxcolors)
    helpers.clear({env={TERM=term}, args={}})
    -- This is ugly because :term/termopen() forces TERM=xterm-256color.
    -- TODO: Revisit this after jobstart/termopen accept `env` dict.
    screen = thelpers.screen_setup(0, string.format(
      [=[['sh', '-c', 'LANG=C TERM=%s %s %s -u NONE -i NONE --cmd "silent set noswapfile noshowcmd noruler"']]=],
      term,
      (colorterm ~= nil and "COLORTERM="..colorterm or ""),
      helpers.nvim_prog))

    thelpers.feed_data(":echo &t_Co\n")
    helpers.wait()
    local tline
    if maxcolors == 8 or maxcolors == 16 then
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

  -- ansi and no terminal type at all:

  it("no TERM uses 8 colors", function()
    assert_term_colors(nil, nil, 8)
  end)

  it("TERM=ansi no COLORTERM uses 8 colors", function()
    assert_term_colors("ansi", nil, 8)
  end)

  it("TERM=ansi with COLORTERM=anything-no-number uses 16 colors", function()
    assert_term_colors("ansi", "yet-another-term", 16)
  end)

  it("unknown TERM COLORTERM with 256 in name uses 256 colors", function()
    assert_term_colors("ansi", "yet-another-term-256color", 256)
  end)

  it("TERM=ansi-256color sets 256 colours", function()
    assert_term_colors("ansi-256color", nil, 256)
  end)

  -- Unknown terminal types:

  it("unknown TERM no COLORTERM sets 8 colours", function()
    assert_term_colors("yet-another-term", nil, 8)
  end)

  it("unknown TERM with COLORTERM=anything-no-number uses 16 colors", function()
    assert_term_colors("yet-another-term", "yet-another-term", 16)
  end)

  it("unknown TERM with 256 in name sets 256 colours", function()
    assert_term_colors("yet-another-term-256color", nil, 256)
  end)

  it("unknown TERM COLORTERM with 256 in name uses 256 colors", function()
    assert_term_colors("yet-another-term", "yet-another-term-256color", 256)
  end)

  -- Linux kernel terminal emulator:

  it("TERM=linux uses 256 colors", function()
    assert_term_colors("linux", nil, 256)
  end)

  it("TERM=linux-16color uses 256 colors", function()
    assert_term_colors("linux-16color", nil, 256)
  end)

  it("TERM=linux-256color uses 256 colors", function()
    assert_term_colors("linux-256color", nil, 256)
  end)

  -- screen:
  --
  -- FreeBSD falls back to the built-in screen-256colour entry.
  -- Linux and MacOS have a screen entry in external terminfo with 8 colours,
  -- which is raised to 16 by COLORTERM.

  it("TERM=screen no COLORTERM uses 8/256 colors", function()
    if is_freebsd then
      assert_term_colors("screen", nil, 256)
    else
      assert_term_colors("screen", nil, 8)
    end
  end)

  it("TERM=screen COLORTERM=screen uses 16/256 colors", function()
    if is_freebsd then
      assert_term_colors("screen", "screen", 256)
    else
      assert_term_colors("screen", "screen", 16)
    end
  end)

  it("TERM=screen COLORTERM=screen-256color uses 256 colors", function()
    assert_term_colors("screen", "screen-256color", 256)
  end)

  it("TERM=screen-256color no COLORTERM uses 256 colors", function()
    assert_term_colors("screen-256color", nil, 256)
  end)

  -- tmux:
  --
  -- FreeBSD and MacOS fall back to the built-in tmux-256colour entry.
  -- Linux has a tmux entry in external terminfo with 8 colours,
  -- which is raised to 256.

  it("TERM=tmux no COLORTERM uses 256 colors", function()
    assert_term_colors("tmux", nil, 256)
  end)

  it("TERM=tmux COLORTERM=tmux uses 256 colors", function()
    assert_term_colors("tmux", "tmux", 256)
  end)

  it("TERM=tmux COLORTERM=tmux-256color uses 256 colors", function()
    assert_term_colors("tmux", "tmux-256color", 256)
  end)

  it("TERM=tmux-256color no COLORTERM uses 256 colors", function()
    assert_term_colors("tmux-256color", nil, 256)
  end)

  -- xterm and imitators:

  it("TERM=xterm uses 256 colors", function()
    assert_term_colors("xterm", nil, 256)
  end)

  it("TERM=xterm COLORTERM=gnome-terminal uses 256 colors", function()
    assert_term_colors("xterm", "gnome-terminal", 256)
  end)

  it("TERM=xterm COLORTERM=mate-terminal uses 256 colors", function()
    assert_term_colors("xterm", "mate-terminal", 256)
  end)

  it("TERM=xterm-256color uses 256 colors", function()
    assert_term_colors("xterm-256color", nil, 256)
  end)

  -- rxvt and stterm:
  --
  -- FreeBSD and MacOS fall back to the built-in rxvt-256color and
  -- st-256colour entries.
  -- Linux has an rxvt, an st, and an st-16color entry in external terminfo
  -- with 8, 8, and 16 colours respectively, which are raised to 256.

  it("TERM=rxvt no COLORTERM uses 256 colors", function()
    assert_term_colors("rxvt", nil, 256)
  end)

  it("TERM=rxvt COLORTERM=rxvt uses 256 colors", function()
    assert_term_colors("rxvt", "rxvt", 256)
  end)

  it("TERM=rxvt-256color uses 256 colors", function()
    assert_term_colors("rxvt-256color", nil, 256)
  end)

  it("TERM=st no COLORTERM uses 256 colors", function()
    assert_term_colors("st", nil, 256)
  end)

  it("TERM=st COLORTERM=st uses 256 colors", function()
    assert_term_colors("st", "st", 256)
  end)

  it("TERM=st COLORTERM=st-256color uses 256 colors", function()
    assert_term_colors("st", "st-256color", 256)
  end)

  it("TERM=st-16color no COLORTERM uses 8/256 colors", function()
    assert_term_colors("st", nil, 256)
  end)

  it("TERM=st-16color COLORTERM=st uses 16/256 colors", function()
    assert_term_colors("st", "st", 256)
  end)

  it("TERM=st-16color COLORTERM=st-256color uses 256 colors", function()
    assert_term_colors("st", "st-256color", 256)
  end)

  it("TERM=st-256color uses 256 colors", function()
    assert_term_colors("st-256color", nil, 256)
  end)

  -- gnome and vte:
  --
  -- FreeBSD and MacOS fall back to the built-in vte-256color entry.
  -- Linux has a gnome, a vte, a gnome-256color, and a vte-256color entry in
  -- external terminfo with 8, 8, 256, and 256 colours respectively, which are
  -- raised to 256.

  it("TERM=gnome no COLORTERM uses 256 colors", function()
    assert_term_colors("gnome", nil, 256)
  end)

  it("TERM=gnome COLORTERM=gnome uses 256 colors", function()
    assert_term_colors("gnome", "gnome", 256)
  end)

  it("TERM=gnome COLORTERM=gnome-256color uses 256 colors", function()
    assert_term_colors("gnome", "gnome-256color", 256)
  end)

  it("TERM=gnome-256color uses 256 colors", function()
    assert_term_colors("gnome-256color", nil, 256)
  end)

  it("TERM=vte no COLORTERM uses 256 colors", function()
    assert_term_colors("vte", nil, 256)
  end)

  it("TERM=vte COLORTERM=vte uses 256 colors", function()
    assert_term_colors("vte", "vte", 256)
  end)

  it("TERM=vte COLORTERM=vte-256color uses 256 colors", function()
    assert_term_colors("vte", "vte-256color", 256)
  end)

  it("TERM=vte-256color uses 256 colors", function()
    assert_term_colors("vte-256color", nil, 256)
  end)

  -- others:

  it("TERM=interix uses 8 colors", function()
    assert_term_colors("interix", nil, 8)
  end)

  it("TERM=iTerm.app uses 256 colors", function()
    assert_term_colors("iTerm.app", nil, 256)
  end)

  it("TERM=iterm uses 256 colors", function()
    assert_term_colors("iterm", nil, 256)
  end)
end)

describe('tui guicursor handling', function()
  -- poor man test for guicursor (mostly VTE)
  -- setup the guicursor
  -- then check that some sequences are sent

  -- local screen
  local vte_cursor = function (shape, blink)
    local x = ""
    -- also called beam
    if shape == "ver" then
      x = 5
    elseif shape == "block" then
      x = 1
    elseif shape == "under" then
      x = 3
    else
      assert (0, "invalid shape")
    end

    if not blink then
      x = x + 1
    end
    -- escape the magic character '[' with '%' hence the '%['
    -- prepend %\27 ?
    -- "%["..
    return "%["..x.." q"
  end


  -- local osc_reset = "\x1b]112"
  -- local beam_cursor = "\x1b["..x.."q"
  -- local block = "\x1b[1 q"
  -- local = "\x1b[1 q"
  -- "\27[1 q"
  -- local shape_block = vte_cursor('block')
  -- local shape_hor = "\27[3 q"
  -- local shape_ver = "\27%[5 q"

  before_each(function()
    helpers.clear()
    local channel = nvim('get_api_info')[1]
    nvim('set_var', 'channel', channel)
    -- Use a nested nvim (in :term) to test without --headless.
    -- feed_command(":terminal '"..helpers.nvim_prog)
    -- screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog
      -- ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]')
    helpers.source([[
    function! s:OnOut(id, data, event) dict
      let userdata = get(self, 'user')
      let data     = a:data

      " userdata
      call rpcnotify(g:channel, "onout", data)
    endfunction

    function! s:OnEvent(id, data, event) dict
      let userdata = get(self, 'user')
      let data     = a:data
      call rpcnotify(g:channel, a:event, userdata, data)
    endfunction
    let g:job_opts = {
    \ 'on_stdout': function('s:OnOut'),
    \ 'on_stderr': function('s:OnEvent'),
    \ 'on_exit': function('s:OnEvent'),
    \ 'pty': 1,
    \ 'user': 0
    \ }
    ]])
    -- luaeval
    -- \ 'TERM': 1,

  end)


  local gen = function(startup_options, input, pattern)
    -- make sure your pattern has escaped characters such as [,] else
    -- lua may return some errors
    print("nvim prog: " .. helpers.nvim_prog)
    if helpers.iswin() then
      pending()
    else
      --star[tinsert][!]

      -- look for examples in gdb printer or terminal/helpers.lua
      -- cf feed_termcode etc
      -- '--cmd', 'call feedkeys(\"itoto\")'
      local cmds= ""
      for _, cmd in ipairs(startup_options)
      do
        cmds = cmds..', "--cmd", "'..cmd..'"'
      end

      print("commands=", cmds)
      nvim('command', "let j = jobstart([ '".. helpers.nvim_prog.."', '-u', 'NONE', '-i', 'NONE', '--cmd', 'set noswapfile noshowcmd noruler shortmess=I'"..cmds.."  ], g:job_opts)")
      -- to send data to the job
      -- for i in ipairs(startup_options):
      nvim('command', 'call jobsend(j, "'..input..'\\x1b:q!\n")')
    end

    -- todo set guicursor to interesting value
    -- print("matches =", nvim('get_option', 'guicursor'))
    -- print("matches =", nvim('get_var', 'nb_match'))

    local buffer = ""
    for i=10,1,-1
    do
      local msg = next_msg(50)
      local pp = require('pl.pretty')
      pp.dump(msg)
      if msg ~= nil  then
        if msg[2] ~= "exit" then
          local args = msg[3]
          local line = (args[1])[1]
          buffer = buffer..line
        end
      end
    end

    print(buffer)
    print("pattern = "..pattern)
    ok(buffer:find(pattern) ~= nil)

  end -- end of gen

  it('VTE guicursor', function()
    local shape_ver_noblink = vte_cursor('ver', false)
    local shape_block_noblink = vte_cursor('block', false)
    local pattern = shape_ver_noblink.."(.*)toto(.*)"..shape_block_noblink
    -- :append (line("."), "zaza")
    -- :append (line(\".\"), \"zaza\")
    -- \x1b\x1b:q!
    gen( {'set guicursor=n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20'}, [[itoto\x1b\x1b:q!\n]], pattern)
  end)

  -- it('VTE invisible cursor ', function()
  --
  --   -- local shape_ver_noblink = vte_cursor('ver', false)
  --   -- local shape_block_noblink = vte_cursor('block', false)
  --   local pattern = "\x1b%[?25l"
  --   -- :append (line("."), "zaza")
  --   -- :append (line(\".\"), \"zaza\")
  --   -- \x1b\x1b:q!
  --   -- TODO set tgc
  --   local cmds = {
  --     'set termguicolors',
  --     'set guicursor=n-v-c:block-Cursor/lCursor,ve:ver35-Cursor,o:hor50-Cursor,i-ci:ver25-Cursor/lCursor,r-cr:hor20-Cursor/lCursor',
  --     'hi Cursor guibg=NONE'
  --   }
  --   gen(cmds, [[itoto\x1b\x1b:q!\n]], pattern)
  --   -- eq({'notification', 'exit', {0, 0}}, next_msg())
  -- end)
end)
