local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local assert_alive = n.assert_alive
local clear, poke_eventloop = n.clear, n.poke_eventloop
local testprg, source, eq, neq = n.testprg, n.source, t.eq, t.neq
local feed = n.feed
local eval = n.eval
local fn = n.fn
local api = n.api
local exec_lua = n.exec_lua
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
    feed(':messages<CR>')
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
      command(
        [[terminal powershell -NoProfile -NoLogo -Command Write-Host -NoNewline "\"$([char]27)[6n\""; Start-Sleep -Milliseconds 500 ]]
      )
    else
      command([[terminal printf '\e[6n'; sleep 0.5 ]])
    end
    screen:expect { any = '%^%[%[1;1R' }
  end)

  it('in normal-mode :split does not move cursor', function()
    if is_os('win') then
      command(
        [[terminal for /L \\%I in (1,0,2) do ( echo foo & ping -w 100 -n 1 127.0.0.1 > nul )]]
      )
    else
      command([[terminal while true; do echo foo; sleep .1; done]])
    end
    feed([[<C-\><C-N>M]]) -- move cursor away from last line
    poke_eventloop()
    eq(3, eval("line('$')")) -- window height
    eq(2, eval("line('.')")) -- cursor is in the middle
    feed(':vsplit<CR>')
    eq(2, eval("line('.')")) -- cursor stays where we put it
    feed(':split<CR>')
    eq(2, eval("line('.')")) -- cursor stays where we put it
  end)

  it('Enter/Leave does not increment jumplist #3723', function()
    feed(':terminal<CR>')
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
    feed('<Ignore>') -- Add input to separate two RPC requests
    eq({ blocking = false, mode = 'nt' }, api.nvim_get_mode())
  end)

  it('switching to another terminal buffer in Terminal mode', function()
    command('terminal')
    local buf0 = api.nvim_get_current_buf()
    command('terminal')
    local buf1 = api.nvim_get_current_buf()
    command('terminal')
    local buf2 = api.nvim_get_current_buf()
    neq(buf0, buf1)
    neq(buf0, buf2)
    neq(buf1, buf2)
    feed('i')
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
    api.nvim_set_current_buf(buf1)
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
    api.nvim_set_current_buf(buf0)
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
    exec_lua(function()
      vim.api.nvim_set_current_buf(buf1)
      vim.api.nvim_buf_delete(buf0, { force = true })
    end)
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
    api.nvim_set_current_buf(buf2)
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
    api.nvim_set_current_buf(buf1)
    eq({ blocking = false, mode = 't' }, api.nvim_get_mode())
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
    t.mkdir('Xsomedir')
    t.write_file('Xsomedir/Xuniquefile', '')
  end)

  after_each(function()
    n.rmdir('Xsomedir')
  end)

  it('with no argument, acts like jobstart(…,{term=true})', function()
    command('autocmd! nvim.terminal TermClose')
    command('terminal')
    screen:expect([[
      ^ready $                                           |
      [Process exited 0]                                |
                                                        |*2
    ]])
  end)

  it("with no argument, and 'shell' is set to empty string", function()
    api.nvim_set_option_value('shell', '', {})
    eq("Vim(terminal):E91: 'shell' option is empty", t.pcall_err(command, 'terminal'))
  end)

  it("with no argument, but 'shell' has arguments, acts like jobstart(…,{term=true})", function()
    api.nvim_set_option_value('shell', shell_path .. ' INTERACT', {})
    command('terminal')
    screen:expect([[
      ^interact $                                        |
                                                        |*3
    ]])
  end)

  it('executes a given command through the shell', function()
    command('terminal echo hi')
    screen:expect([[
      ^ready $ echo hi                                   |
                                                        |
      [Process exited 0]                                |
                                                        |
    ]])
  end)

  it("executes a given command through the shell, when 'shell' has arguments", function()
    api.nvim_set_option_value('shell', shell_path .. ' -t jeff', {})
    command('terminal echo hi')
    screen:expect([[
      ^jeff $ echo hi                                    |
                                                        |
      [Process exited 0]                                |
                                                        |
    ]])
  end)

  it('allows quotes and slashes', function()
    command([[terminal echo 'hello' \ "world"]])
    screen:expect([[
      ^ready $ echo 'hello' \ "world"                    |
                                                        |
      [Process exited 0]                                |
                                                        |
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
    command('autocmd! nvim.terminal TermClose')
    command('terminal')
    feed('iiXXXXXXX')
    poke_eventloop()
    -- Race: Though the shell exited (and streams were closed by SIGCHLD
    -- handler), :terminal cleanup is pending on the main-loop.
    -- This write should be ignored (not crash, #5445).
    feed('iiYYYYYYY')
    assert_alive()
  end)

  it('works with findfile()', function()
    command('autocmd! nvim.terminal TermClose')
    command('terminal')
    eq('term://', string.match(eval('bufname("%")'), '^term://'))
    eq('Xsomedir/Xuniquefile', eval('findfile("Xsomedir/Xuniquefile", ".")'))
  end)

  it('works with :find', function()
    command('autocmd! nvim.terminal TermClose')
    command('terminal')
    screen:expect([[
      ^ready $                                           |
      [Process exited 0]                                |
                                                        |*2
    ]])
    eq('term://', string.match(eval('bufname("%")'), '^term://'))
    feed([[<C-\><C-N>]])
    command([[find */Xuniquefile]])
    if is_os('win') then
      eq('Xsomedir\\Xuniquefile', eval('bufname("%")'))
    else
      eq('Xsomedir/Xuniquefile', eval('bufname("%")'))
    end
  end)

  it('works with gf', function()
    command([[terminal echo "Xsomedir/Xuniquefile"]])
    screen:expect([[
      ^ready $ echo "Xsomedir/Xuniquefile"               |
                                                        |
      [Process exited 0]                                |
                                                        |
    ]])
    feed([[<C-\><C-N>]])
    eq('term://', string.match(eval('bufname("%")'), '^term://'))
    feed([[ggf"lgf]])
    eq('Xsomedir/Xuniquefile', eval('bufname("%")'))
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
        command('terminal 42')
        screen:expect([[
          ^                                                  |
          [Process exited 42]                               |
                                                            |*2
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
