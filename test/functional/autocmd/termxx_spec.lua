local uv = vim.uv
local t = require('test.functional.testutil')()
local tt = require('test.functional.terminal.testutil')

local clear, command, testprg = t.clear, t.command, t.testprg
local eval, eq, neq, retry = t.eval, t.eq, t.neq, t.retry
local matches = t.matches
local ok = t.ok
local feed = t.feed
local api = t.api
local pcall_err = t.pcall_err
local assert_alive = t.assert_alive
local skip = t.skip
local is_os = t.is_os

describe('autocmd TermClose', function()
  before_each(function()
    clear()
    api.nvim_set_option_value('shell', testprg('shell-test'), {})
    command('set shellcmdflag=EXE shellredir= shellpipe= shellquote= shellxquote=')
  end)

  local function test_termclose_delete_own_buf()
    -- The terminal process needs to keep running so that TermClose isn't triggered immediately.
    api.nvim_set_option_value('shell', string.format('"%s" INTERACT', testprg('shell-test')), {})
    command('autocmd TermClose * bdelete!')
    command('terminal')
    matches(
      '^TermClose Autocommands for "%*": Vim%(bdelete%):E937: Attempt to delete a buffer that is in use: term://',
      pcall_err(command, 'bdelete!')
    )
    assert_alive()
  end

  -- TODO: fixed after merging patches for `can_unload_buffer`?
  pending('TermClose deleting its own buffer, altbuf = buffer 1 #10386', function()
    test_termclose_delete_own_buf()
  end)

  it('TermClose deleting its own buffer, altbuf NOT buffer 1 #10386', function()
    command('edit foo1')
    test_termclose_delete_own_buf()
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

describe('autocmd TextChangedT', function()
  clear()
  local screen = tt.screen_setup()

  it('works', function()
    command('autocmd TextChangedT * ++once let g:called = 1')
    tt.feed_data('a')
    retry(nil, nil, function()
      eq(1, api.nvim_get_var('called'))
    end)
  end)

  it('cannot delete terminal buffer', function()
    command([[autocmd TextChangedT * call nvim_input('<CR>') | bwipe!]])
    tt.feed_data('a')
    screen:expect({ any = 'E937: ' })
    matches(
      '^E937: Attempt to delete a buffer that is in use: term://',
      api.nvim_get_vvar('errmsg')
    )
  end)
end)
