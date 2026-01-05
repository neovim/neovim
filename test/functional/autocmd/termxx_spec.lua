local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local uv = vim.uv

local clear, command, testprg = n.clear, n.command, n.testprg
local eval, eq, neq, retry = n.eval, t.eq, t.neq, t.retry
local exec_lua = n.exec_lua
local matches = t.matches
local ok = t.ok
local feed = n.feed
local api = n.api
local pcall_err = t.pcall_err
local assert_alive = n.assert_alive
local skip = t.skip
local is_os = t.is_os

describe('autocmd TermClose', function()
  before_each(function()
    clear()
    api.nvim_set_option_value('shell', testprg('shell-test'), {})
    command('set shellcmdflag=EXE shellredir= shellpipe= shellquote= shellxquote=')
    command('autocmd! nvim.terminal TermClose')
  end)

  local function test_termclose_delete_own_buf()
    -- The terminal process needs to keep running so that TermClose isn't triggered immediately.
    api.nvim_set_option_value('shell', string.format('"%s" INTERACT', testprg('shell-test')), {})
    command('terminal')
    local termbuf = api.nvim_get_current_buf()
    command(('autocmd TermClose * bdelete! %d'):format(termbuf))
    matches(
      '^TermClose Autocommands for "%*": Vim%(bdelete%):E937: Attempt to delete a buffer that is in use: term://',
      pcall_err(command, 'bdelete!')
    )
    assert_alive()
  end

  it('TermClose deleting its own buffer, altbuf = buffer 1 #10386', function()
    test_termclose_delete_own_buf()
  end)

  it('TermClose deleting its own buffer, altbuf NOT buffer 1 #10386', function()
    command('edit foo1')
    test_termclose_delete_own_buf()
  end)

  it('TermClose deleting all other buffers', function()
    local oldbuf = api.nvim_get_current_buf()
    -- The terminal process needs to keep running so that TermClose isn't triggered immediately.
    api.nvim_set_option_value('shell', string.format('"%s" INTERACT', testprg('shell-test')), {})
    command(('autocmd TermClose * bdelete! %d'):format(oldbuf))
    command('horizontal terminal')
    neq(oldbuf, api.nvim_get_current_buf())
    command('bdelete!')
    feed('<C-G>') -- This shouldn't crash due to having a 0-line buffer.
    assert_alive()
  end)

  it('TermClose switching back to terminal buffer', function()
    local buf = api.nvim_get_current_buf()
    api.nvim_open_term(buf, {})
    command(('autocmd TermClose * buffer %d | new'):format(buf))
    eq(
      'TermClose Autocommands for "*": Vim(buffer):E1546: Cannot switch to a closing buffer',
      pcall_err(command, 'bwipe!')
    )
    assert_alive()
  end)

  it('triggers when fast-exiting terminal job stops', function()
    command('autocmd TermClose * let g:test_termclose = 23')
    command('terminal')
    -- shell-test exits immediately.
    retry(nil, nil, function()
      neq(-1, eval('jobwait([&channel], 0)[0]'))
    end)
    retry(nil, nil, function()
      eq(23, eval('g:test_termclose'))
    end)
  end)

  it('triggers when long-running terminal job gets stopped', function()
    skip(is_os('win'))
    api.nvim_set_option_value('shell', is_os('win') and 'cmd.exe' or 'sh', {})
    command('autocmd TermClose * let g:test_termclose = 23')
    command('terminal')
    command('call jobstop(b:terminal_job_id)')
    retry(nil, nil, function()
      eq(23, eval('g:test_termclose'))
    end)
  end)

  it('kills job trapping SIGTERM', function()
    skip(is_os('win'))
    api.nvim_set_option_value('shell', 'sh', {})
    api.nvim_set_option_value('shellcmdflag', '-c', {})
    command(
      [[ let g:test_job = jobstart('trap "" TERM && echo 1 && sleep 60', { ]]
        .. [[ 'on_stdout': {-> execute('let g:test_job_started = 1')}, ]]
        .. [[ 'on_exit': {-> execute('let g:test_job_exited = 1')}}) ]]
    )
    retry(nil, nil, function()
      eq(1, eval('get(g:, "test_job_started", 0)'))
    end)

    uv.update_time()
    local start = uv.now()
    command('call jobstop(g:test_job)')
    retry(nil, nil, function()
      eq(1, eval('get(g:, "test_job_exited", 0)'))
    end)
    uv.update_time()
    local duration = uv.now() - start
    -- Nvim begins SIGTERM after KILL_TIMEOUT_MS.
    ok(duration >= 2000)
    ok(duration <= 4000) -- Epsilon for slow CI
  end)

  it('kills PTY job trapping SIGHUP and SIGTERM', function()
    skip(is_os('win'))
    api.nvim_set_option_value('shell', 'sh', {})
    api.nvim_set_option_value('shellcmdflag', '-c', {})
    command(
      [[ let g:test_job = jobstart('trap "" HUP TERM && echo 1 && sleep 60', { ]]
        .. [[ 'pty': 1,]]
        .. [[ 'on_stdout': {-> execute('let g:test_job_started = 1')}, ]]
        .. [[ 'on_exit': {-> execute('let g:test_job_exited = 1')}}) ]]
    )
    retry(nil, nil, function()
      eq(1, eval('get(g:, "test_job_started", 0)'))
    end)

    uv.update_time()
    local start = uv.now()
    command('call jobstop(g:test_job)')
    retry(nil, nil, function()
      eq(1, eval('get(g:, "test_job_exited", 0)'))
    end)
    uv.update_time()
    local duration = uv.now() - start
    -- Nvim begins SIGKILL after (2 * KILL_TIMEOUT_MS).
    ok(duration >= 4000)
    ok(duration <= 7000) -- Epsilon for slow CI
  end)

  it('reports the correct <abuf>', function()
    command('set hidden')
    command('set shellcmdflag=EXE')
    command('autocmd TermClose * let g:abuf = expand("<abuf>")')
    command('edit foo')
    command('edit bar')
    eq(2, eval('bufnr("%")'))

    command('terminal ls')
    retry(nil, nil, function()
      eq(3, eval('bufnr("%")'))
    end)

    command('buffer 1')
    retry(nil, nil, function()
      eq(1, eval('bufnr("%")'))
    end)

    command('3bdelete!')
    retry(nil, nil, function()
      eq('3', eval('g:abuf'))
    end)
    feed('<c-c>:qa!<cr>')
  end)

  it('exposes v:event.status', function()
    command('set shellcmdflag=EXIT')
    command('autocmd TermClose * let g:status = v:event.status')

    command('terminal 0')
    retry(nil, nil, function()
      eq(0, eval('g:status'))
    end)

    command('terminal 42')
    retry(nil, nil, function()
      eq(42, eval('g:status'))
    end)
  end)
end)

it('autocmd TermEnter, TermLeave', function()
  clear()
  command('let g:evs = []')
  command('autocmd TermOpen  * call add(g:evs, ["TermOpen", mode()])')
  command('autocmd TermClose * call add(g:evs, ["TermClose", mode()])')
  command('autocmd TermEnter * call add(g:evs, ["TermEnter", mode()])')
  command('autocmd TermLeave * call add(g:evs, ["TermLeave", mode()])')
  command('terminal')

  feed('i')
  eq({ { 'TermOpen', 'n' }, { 'TermEnter', 't' } }, eval('g:evs'))
  feed([[<C-\><C-n>]])
  feed('A')
  eq(
    { { 'TermOpen', 'n' }, { 'TermEnter', 't' }, { 'TermLeave', 'n' }, { 'TermEnter', 't' } },
    eval('g:evs')
  )

  -- TermLeave is also triggered by :quit.
  command('split foo')
  feed('<Ignore>') -- Add input to separate two RPC requests
  command('wincmd w')
  feed('i')
  command('q!')
  feed('<Ignore>') -- Add input to separate two RPC requests
  eq({
    { 'TermOpen', 'n' },
    { 'TermEnter', 't' },
    { 'TermLeave', 'n' },
    { 'TermEnter', 't' },
    { 'TermLeave', 'n' },
    { 'TermEnter', 't' },
    { 'TermClose', 't' },
    { 'TermLeave', 'n' },
  }, eval('g:evs'))
end)

describe('autocmd TextChangedT,WinResized', function()
  before_each(clear)

  it('TextChangedT works', function()
    local screen = Screen.new(50, 7)
    screen:set_default_attr_ids({
      [1] = { bold = true },
      [31] = { foreground = Screen.colors.Gray100, background = Screen.colors.DarkGreen },
      [32] = {
        foreground = Screen.colors.Gray100,
        bold = true,
        background = Screen.colors.DarkGreen,
      },
    })

    local term, term_unfocused = exec_lua(function()
      -- Split windows before opening terminals so TextChangedT doesn't fire an additional time due
      -- to the inner terminal being resized (which is usually deferred too).
      vim.cmd.vnew()
      local term_unfocused = vim.api.nvim_open_term(0, {})
      vim.cmd.wincmd 'p'
      local term = vim.api.nvim_open_term(0, {})
      vim.cmd.startinsert()
      return term, term_unfocused
    end)
    eq('t', eval('mode()'))

    exec_lua(function()
      _G.n_triggered = 0
      vim.api.nvim_create_autocmd('TextChanged', {
        callback = function()
          _G.n_triggered = _G.n_triggered + 1
        end,
      })
      _G.t_triggered = 0
      vim.api.nvim_create_autocmd('TextChangedT', {
        callback = function()
          _G.t_triggered = _G.t_triggered + 1
        end,
      })
    end)

    api.nvim_chan_send(term, 'a')
    retry(nil, nil, function()
      eq(1, exec_lua('return _G.t_triggered'))
    end)
    api.nvim_chan_send(term, 'b')
    retry(nil, nil, function()
      eq(2, exec_lua('return _G.t_triggered'))
    end)

    -- Not triggered by changes in a non-current terminal.
    api.nvim_chan_send(term_unfocused, 'hello')
    screen:expect([[
      hello                    │ab^                      |
                               │                        |*4
      {31:[Scratch]                 }{32:[Scratch]               }|
      {1:-- TERMINAL --}                                    |
    ]])
    eq(2, exec_lua('return _G.t_triggered'))

    -- Not triggered by unflushed redraws.
    api.nvim__redraw({ valid = false, flush = false })
    eq(2, exec_lua('return _G.t_triggered'))

    -- Not triggered when not in terminal mode.
    command('stopinsert')
    eq('n', eval('mode()'))
    eq(2, exec_lua('return _G.t_triggered'))
    eq(0, exec_lua('return _G.n_triggered')) -- Nothing we did was in Normal mode yet.

    api.nvim_chan_send(term, 'c')
    screen:expect([[
      hello                    │a^bc                     |
                               │                        |*4
      {31:[Scratch]                 }{32:[Scratch]               }|
                                                        |
    ]])
    eq(1, exec_lua('return _G.n_triggered')) -- Happened in Normal mode.
  end)

  it('no crash when deleting terminal buffer', function()
    -- Using nvim_open_term over :terminal as the former can free the terminal immediately on
    -- close, causing the crash.

    -- WinResized
    local buf1, term1 = exec_lua(function()
      vim.cmd.new()
      local buf = vim.api.nvim_get_current_buf()
      local term = vim.api.nvim_open_term(0, {
        on_input = function()
          vim.cmd.wincmd '_'
        end,
      })
      vim.api.nvim_create_autocmd('WinResized', {
        once = true,
        command = 'bwipeout!',
      })
      return buf, term
    end)
    feed('ii')
    eq(false, api.nvim_buf_is_valid(buf1))
    eq('n', eval('mode()'))
    eq({}, api.nvim_get_chan_info(term1)) -- Channel should've been cleaned up.

    -- TextChangedT
    local buf2, term2 = exec_lua(function()
      vim.cmd.new()
      local buf = vim.api.nvim_get_current_buf()
      local term = vim.api.nvim_open_term(0, {
        on_input = function(_, chan)
          vim.api.nvim_chan_send(chan, 'sup')
        end,
      })
      vim.api.nvim_create_autocmd('TextChangedT', {
        once = true,
        command = 'bwipeout!',
      })
      return buf, term
    end)
    feed('ii')
    -- refresh_terminal is deferred, so TextChangedT may not trigger immediately.
    retry(nil, nil, function()
      eq(false, api.nvim_buf_is_valid(buf2))
    end)
    eq('n', eval('mode()'))
    eq({}, api.nvim_get_chan_info(term2)) -- Channel should've been cleaned up.
  end)
end)
