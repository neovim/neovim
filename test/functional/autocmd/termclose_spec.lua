local luv = require('luv')
local helpers = require('test.functional.helpers')(after_each)

local clear, command, nvim, nvim_dir =
  helpers.clear, helpers.command, helpers.nvim, helpers.nvim_dir
local eval, eq, retry =
  helpers.eval, helpers.eq, helpers.retry
local ok = helpers.ok
local iswin = helpers.iswin


describe('TermClose event', function()
  before_each(function()
    clear()
    nvim('set_option', 'shell', nvim_dir .. '/shell-test')
    nvim('set_option', 'shellcmdflag', 'EXE')
  end)

  it('triggers when fast-exiting terminal job stops', function()
    command('autocmd TermClose * let g:test_termclose = 23')
    command('terminal')
    command('call jobstop(b:terminal_job_id)')
    retry(nil, nil, function() eq(23, eval('g:test_termclose')) end)
  end)

  it('triggers when long-running terminal job gets stopped', function()
    nvim('set_option', 'shell', iswin() and 'cmd.exe' or 'sh')
    command('autocmd TermClose * let g:test_termclose = 23')
    command('terminal')
    command('call jobstop(b:terminal_job_id)')
    retry(nil, nil, function() eq(23, eval('g:test_termclose')) end)
  end)

  it('kills job trapping SIGTERM', function()
    if iswin() then return end
    nvim('set_option', 'shell', 'sh')
    nvim('set_option', 'shellcmdflag', '-c')
    command([[ let g:test_job = jobstart('trap "" TERM && echo 1 && sleep 60', { ]]
      .. [[ 'on_stdout': {-> execute('let g:test_job_started = 1')}, ]]
      .. [[ 'on_exit': {-> execute('let g:test_job_exited = 1')}}) ]])
    retry(nil, nil, function() eq(1, eval('get(g:, "test_job_started", 0)')) end)

    luv.update_time()
    local start = luv.now()
    command('call jobstop(g:test_job)')
    retry(nil, nil, function() eq(1, eval('get(g:, "test_job_exited", 0)')) end)
    luv.update_time()
    local duration = luv.now() - start
    -- Nvim begins SIGTERM after KILL_TIMEOUT_MS.
    ok(duration >= 2000)
    ok(duration <= 4000)  -- Epsilon for slow CI
  end)

  it('kills PTY job trapping SIGHUP and SIGTERM', function()
    if iswin() then return end
    nvim('set_option', 'shell', 'sh')
    nvim('set_option', 'shellcmdflag', '-c')
    command([[ let g:test_job = jobstart('trap "" HUP TERM && echo 1 && sleep 60', { ]]
      .. [[ 'pty': 1,]]
      .. [[ 'on_stdout': {-> execute('let g:test_job_started = 1')}, ]]
      .. [[ 'on_exit': {-> execute('let g:test_job_exited = 1')}}) ]])
    retry(nil, nil, function() eq(1, eval('get(g:, "test_job_started", 0)')) end)

    luv.update_time()
    local start = luv.now()
    command('call jobstop(g:test_job)')
    retry(nil, nil, function() eq(1, eval('get(g:, "test_job_exited", 0)')) end)
    luv.update_time()
    local duration = luv.now() - start
    -- Nvim begins SIGKILL after (2 * KILL_TIMEOUT_MS).
    ok(duration >= 4000)
    ok(duration <= 7000)  -- Epsilon for slow CI
  end)

  it('reports the correct <abuf>', function()
    command('set hidden')
    command('autocmd TermClose * let g:abuf = expand("<abuf>")')
    command('edit foo')
    command('edit bar')
    eq(2, eval('bufnr("%")'))

    command('terminal')
    retry(nil, nil, function() eq(3, eval('bufnr("%")')) end)

    command('buffer 1')
    retry(nil, nil, function() eq(1, eval('bufnr("%")')) end)

    command('3bdelete!')
    retry(nil, nil, function() eq('3', eval('g:abuf')) end)
  end)
end)
