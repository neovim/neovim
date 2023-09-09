local luv = require('luv')
local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')

local clear, command, nvim, testprg =
  helpers.clear, helpers.command, helpers.nvim, helpers.testprg
local eval, eq, neq, retry =
  helpers.eval, helpers.eq, helpers.neq, helpers.retry
local matches = helpers.matches
local ok = helpers.ok
local feed = helpers.feed
local meths = helpers.meths
local pcall_err = helpers.pcall_err
local assert_alive = helpers.assert_alive
local skip = helpers.skip
local is_os = helpers.is_os

describe('autocmd TermClose', function()
  before_each(function()
    clear()
    nvim('set_option_value', 'shell', testprg('shell-test'), {})
    command('set shellcmdflag=EXE shellredir= shellpipe= shellquote= shellxquote=')
  end)


  local function test_termclose_delete_own_buf()
    -- The terminal process needs to keep running so that TermClose isn't triggered immediately.
    nvim('set_option_value', 'shell', string.format('"%s" INTERACT', testprg('shell-test')), {})
    command('autocmd TermClose * bdelete!')
    command('terminal')
    matches('^TermClose Autocommands for "%*": Vim%(bdelete%):E937: Attempt to delete a buffer that is in use: term://',
            pcall_err(command, 'bdelete!'))
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
    retry(nil, nil, function() neq(-1, eval('jobwait([&channel], 0)[0]')) end)
    retry(nil, nil, function() eq(23, eval('g:test_termclose')) end)
  end)

  it('triggers when long-running terminal job gets stopped', function()
    skip(is_os('win'))
    nvim('set_option_value', 'shell', is_os('win') and 'cmd.exe' or 'sh', {})
    command('autocmd TermClose * let g:test_termclose = 23')
    command('terminal')
    command('call jobstop(b:terminal_job_id)')
    retry(nil, nil, function() eq(23, eval('g:test_termclose')) end)
  end)

  it('kills job trapping SIGTERM', function()
    skip(is_os('win'))
    nvim('set_option_value', 'shell', 'sh', {})
    nvim('set_option_value', 'shellcmdflag', '-c', {})
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
    skip(is_os('win'))
    nvim('set_option_value', 'shell', 'sh', {})
    nvim('set_option_value', 'shellcmdflag', '-c', {})
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
    command('set shellcmdflag=EXE')
    command('autocmd TermClose * let g:abuf = expand("<abuf>")')
    command('edit foo')
    command('edit bar')
    eq(2, eval('bufnr("%")'))

    command('terminal ls')
    retry(nil, nil, function() eq(3, eval('bufnr("%")')) end)

    command('buffer 1')
    retry(nil, nil, function() eq(1, eval('bufnr("%")')) end)

    command('3bdelete!')
    retry(nil, nil, function() eq('3', eval('g:abuf')) end)
    feed('<c-c>:qa!<cr>')
  end)

  it('exposes v:event.status', function()
    command('set shellcmdflag=EXIT')
    command('autocmd TermClose * let g:status = v:event.status')

    command('terminal 0')
    retry(nil, nil, function() eq(0, eval('g:status')) end)

    command('terminal 42')
    retry(nil, nil, function() eq(42, eval('g:status')) end)
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
  eq({ {'TermOpen', 'n'}, {'TermEnter', 't'}, }, eval('g:evs'))
  feed([[<C-\><C-n>]])
  feed('A')
  eq({ {'TermOpen', 'n'}, {'TermEnter', 't'}, {'TermLeave', 'n'}, {'TermEnter', 't'}, }, eval('g:evs'))

  -- TermLeave is also triggered by :quit.
  command('split foo')
  command('wincmd w')
  feed('i')
  command('q!')
  eq(
    {
     {'TermOpen',  'n'},
     {'TermEnter', 't'},
     {'TermLeave', 'n'},
     {'TermEnter', 't'},
     {'TermLeave', 'n'},
     {'TermEnter', 't'},
     {'TermClose', 't'},
     {'TermLeave', 'n'},
    },
    eval('g:evs'))
end)

describe('autocmd TextChangedT', function()
  clear()
  local screen = thelpers.screen_setup()

  it('works', function()
    command('autocmd TextChangedT * ++once let g:called = 1')
    thelpers.feed_data('a')
    retry(nil, nil, function() eq(1, meths.get_var('called')) end)
  end)

  it('cannot delete terminal buffer', function()
    command([[autocmd TextChangedT * call nvim_input('<CR>') | bwipe!]])
    thelpers.feed_data('a')
    screen:expect({any = 'E937: '})
    matches('^E937: Attempt to delete a buffer that is in use: term://', meths.get_vvar('errmsg'))
  end)
end)
