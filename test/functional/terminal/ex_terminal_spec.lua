local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local assert_alive = n.assert_alive
local clear, poke_eventloop = n.clear, n.poke_eventloop
local testprg, source, eq = n.testprg, n.source, t.eq
local feed = n.feed
local feed_command, eval = n.feed_command, n.eval
local fn = n.fn
local api = n.api
local retry = t.retry
local ok = t.ok
local command = n.command
local skip = t.skip
local is_os = t.is_os
local is_ci = t.is_ci

describe(':terminal', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 4, { rgb = false })
    screen._default_attr_ids = nil
  end)

  it('does not interrupt Press-ENTER prompt #2748', function()
    -- Ensure that :messages shows Press-ENTER.
    source([[
      echomsg "msg1"
      echomsg "msg2"
      echomsg "msg3"
    ]])
    -- Invoke a command that emits frequent terminal activity.
    feed([[:terminal "]] .. testprg('shell-test') .. [[" REP 9999 !terminal_output!<cr>]])
    feed([[<C-\><C-N>]])
    poke_eventloop()
    -- Wait for some terminal activity.
    retry(nil, 4000, function()
      ok(fn.line('$') > 6)
    end)
    feed_command('messages')
    screen:expect([[
      msg1                                              |
      msg2                                              |
      msg3                                              |
      Press ENTER or type command to continue^           |
    ]])
  end)

  it('reads output buffer on terminal reporting #4151', function()
    skip(is_ci('cirrus') or is_os('win'))
    if is_os('win') then
      feed_command(
        [[terminal powershell -NoProfile -NoLogo -Command Write-Host -NoNewline "\"$([char]27)[6n\""; Start-Sleep -Milliseconds 500 ]]
      )
    else
      feed_command([[terminal printf '\e[6n'; sleep 0.5 ]])
    end
    screen:expect { any = '%^%[%[1;1R' }
  end)

  it('in normal-mode :split does not move cursor', function()
    if is_os('win') then
      feed_command(
        [[terminal for /L \\%I in (1,0,2) do ( echo foo & ping -w 100 -n 1 127.0.0.1 > nul )]]
      )
    else
      feed_command([[terminal while true; do echo foo; sleep .1; done]])
    end
    feed([[<C-\><C-N>M]]) -- move cursor away from last line
    poke_eventloop()
    eq(3, eval("line('$')")) -- window height
    eq(2, eval("line('.')")) -- cursor is in the middle
    feed_command('vsplit')
    eq(2, eval("line('.')")) -- cursor stays where we put it
    feed_command('split')
    eq(2, eval("line('.')")) -- cursor stays where we put it
  end)

  it('Enter/Leave does not increment jumplist #3723', function()
    feed_command('terminal')
    local function enter_and_leave()
      local lines_before = fn.line('$')
      -- Create a new line (in the shell). For a normal buffer this
      -- increments the jumplist; for a terminal-buffer it should not. #3723
      feed('i')
      poke_eventloop()
      feed('<CR><CR><CR><CR>')
      poke_eventloop()
      feed([[<C-\><C-N>]])
      poke_eventloop()
      -- Wait for >=1 lines to be created.
      retry(nil, 4000, function()
        ok(fn.line('$') > lines_before)
      end)
    end
    enter_and_leave()
    enter_and_leave()
    enter_and_leave()
    ok(fn.line('$') > 6) -- Verify assumption.
    local jumps = fn.split(fn.execute('jumps'), '\n')
    eq(' jump line  col file/text', jumps[1])
    eq(3, #jumps)
  end)

  it('nvim_get_mode() in :terminal', function()
    command('terminal')
    eq({ blocking = false, mode = 'nt' }, api.nvim_get_mode())
    feed('i')
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
    feed([[<C-\><C-N>]])
    eq({ blocking = false, mode = 'nt' }, api.nvim_get_mode())
  end)

  it(':stopinsert RPC request exits terminal-mode #7807', function()
    command('terminal')
    feed('i[tui] insert-mode')
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
    command('stopinsert')
    feed('<Ignore>') -- Add input to separate two RPC requests
    eq({ blocking = false, mode = 'nt' }, api.nvim_get_mode())
  end)

  it(":stopinsert in normal mode doesn't break insert mode #9889", function()
    command('terminal')
    eq({ blocking = false, mode = 'nt' }, api.nvim_get_mode())
    command('stopinsert')
    feed('<Ignore>') -- Add input to separate two RPC requests
    eq({ blocking = false, mode = 'nt' }, api.nvim_get_mode())
    feed('a')
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
  end)

  it('switching to terminal buffer in Insert mode goes to Terminal mode #7164', function()
    command('terminal')
    command('vnew')
    feed('i')
    command('let g:events = []')
    command('autocmd InsertLeave * let g:events += ["InsertLeave"]')
    command('autocmd TermEnter * let g:events += ["TermEnter"]')
    command('inoremap <F2> <Cmd>wincmd p<CR>')
    eq({ blocking = false, mode = 'i' }, api.nvim_get_mode())
    feed('<F2>')
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
    eq({ 'InsertLeave', 'TermEnter' }, eval('g:events'))
  end)

  it('switching to terminal buffer immediately after :stopinsert #27031', function()
    command('terminal')
    command('vnew')
    feed('i')
    eq({ blocking = false, mode = 'i' }, api.nvim_get_mode())
    command('stopinsert | wincmd p')
    eq({ blocking = false, mode = 'nt' }, api.nvim_get_mode())
  end)
end)

local function test_terminal_with_fake_shell(backslash)
  -- shell-test.c is a fake shell that prints its arguments and exits.
  local shell_path = testprg('shell-test')
  if backslash then
    shell_path = shell_path:gsub('/', [[\]])
  end

  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 4, { rgb = false })
    screen._default_attr_ids = nil
    api.nvim_set_option_value('shell', shell_path, {})
    api.nvim_set_option_value('shellcmdflag', 'EXE', {})
    api.nvim_set_option_value('shellxquote', '', {}) -- win: avoid extra quotes
  end)

  it('with no argument, acts like termopen()', function()
    command('autocmd! nvim_terminal TermClose')
    feed_command('terminal')
    screen:expect([[
      ^ready $                                           |
      [Process exited 0]                                |
                                                        |
      :terminal                                         |
    ]])
  end)

  it("with no argument, and 'shell' is set to empty string", function()
    api.nvim_set_option_value('shell', '', {})
    feed_command('terminal')
    screen:expect([[
      ^                                                  |
      ~                                                 |*2
      E91: 'shell' option is empty                      |
    ]])
  end)

  it("with no argument, but 'shell' has arguments, acts like termopen()", function()
    api.nvim_set_option_value('shell', shell_path .. ' INTERACT', {})
    feed_command('terminal')
    screen:expect([[
      ^interact $                                        |
                                                        |*2
      :terminal                                         |
    ]])
  end)

  it('executes a given command through the shell', function()
    feed_command('terminal echo hi')
    screen:expect([[
      ^ready $ echo hi                                   |
                                                        |
      [Process exited 0]                                |
      :terminal echo hi                                 |
    ]])
  end)

  it("executes a given command through the shell, when 'shell' has arguments", function()
    api.nvim_set_option_value('shell', shell_path .. ' -t jeff', {})
    feed_command('terminal echo hi')
    screen:expect([[
      ^jeff $ echo hi                                    |
                                                        |
      [Process exited 0]                                |
      :terminal echo hi                                 |
    ]])
  end)

  it('allows quotes and slashes', function()
    feed_command([[terminal echo 'hello' \ "world"]])
    screen:expect([[
      ^ready $ echo 'hello' \ "world"                    |
                                                        |
      [Process exited 0]                                |
      :terminal echo 'hello' \ "world"                  |
    ]])
  end)

  it('ex_terminal() double-free #4554', function()
    source([[
      autocmd BufNew * set shell=foo
      terminal]])
    -- Verify that BufNew actually fired (else the test is invalid).
    eq('foo', eval('&shell'))
  end)

  it('ignores writes if the backing stream closes', function()
    command('autocmd! nvim_terminal TermClose')
    feed_command('terminal')
    feed('iiXXXXXXX')
    poke_eventloop()
    -- Race: Though the shell exited (and streams were closed by SIGCHLD
    -- handler), :terminal cleanup is pending on the main-loop.
    -- This write should be ignored (not crash, #5445).
    feed('iiYYYYYYY')
    assert_alive()
  end)

  it('works with findfile()', function()
    command('autocmd! nvim_terminal TermClose')
    feed_command('terminal')
    eq('term://', string.match(eval('bufname("%")'), '^term://'))
    eq('scripts/shadacat.py', eval('findfile("scripts/shadacat.py", ".")'))
  end)

  it('works with :find', function()
    command('autocmd! nvim_terminal TermClose')
    feed_command('terminal')
    screen:expect([[
      ^ready $                                           |
      [Process exited 0]                                |
                                                        |
      :terminal                                         |
    ]])
    eq('term://', string.match(eval('bufname("%")'), '^term://'))
    feed([[<C-\><C-N>]])
    feed_command([[find */shadacat.py]])
    if is_os('win') then
      eq('scripts\\shadacat.py', eval('bufname("%")'))
    else
      eq('scripts/shadacat.py', eval('bufname("%")'))
    end
  end)

  it('works with gf', function()
    feed_command([[terminal echo "scripts/shadacat.py"]])
    screen:expect([[
      ^ready $ echo "scripts/shadacat.py"                |
                                                        |
      [Process exited 0]                                |
      :terminal echo "scripts/shadacat.py"              |
    ]])
    feed([[<C-\><C-N>]])
    eq('term://', string.match(eval('bufname("%")'), '^term://'))
    feed([[ggf"lgf]])
    eq('scripts/shadacat.py', eval('bufname("%")'))
  end)

  it('with bufhidden=delete #3958', function()
    command('set hidden')
    eq(1, eval('&hidden'))
    command('autocmd BufNew * setlocal bufhidden=delete')
    for _ = 1, 5 do
      source([[
      execute 'edit '.reltimestr(reltime())
      terminal]])
    end
  end)

  describe('exit does not have long delay #27615', function()
    for _, ut in ipairs({ 5, 50, 500, 5000, 50000, 500000 }) do
      it(('with updatetime=%d'):format(ut), function()
        api.nvim_set_option_value('updatetime', ut, {})
        api.nvim_set_option_value('shellcmdflag', 'EXIT', {})
        feed_command('terminal 42')
        screen:expect([[
          ^                                                  |
          [Process exited 42]                               |
                                                            |
          :terminal 42                                      |
        ]])
      end)
    end
  end)
end

describe(':terminal (with fake shell)', function()
  test_terminal_with_fake_shell(false)
  if is_os('win') then
    describe("when 'shell' uses backslashes", function()
      test_terminal_with_fake_shell(true)
    end)
  end
end)
