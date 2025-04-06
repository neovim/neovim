local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local tt = require('test.functional.testterm')

local clear = n.clear
local eq = t.eq
local eval = n.eval
local exc_exec = n.exc_exec
local feed_command = n.feed_command
local feed = n.feed
local insert = n.insert
local neq = t.neq
local next_msg = n.next_msg
local testprg = n.testprg
local ok = t.ok
local source = n.source
local write_file = t.write_file
local mkdir = t.mkdir
local rmdir = n.rmdir
local assert_alive = n.assert_alive
local command = n.command
local fn = n.fn
local retry = t.retry
local api = n.api
local NIL = vim.NIL
local poke_eventloop = n.poke_eventloop
local get_pathsep = n.get_pathsep
local pathroot = n.pathroot
local exec_lua = n.exec_lua
local nvim_set = n.nvim_set
local expect_twostreams = n.expect_twostreams
local expect_msg_seq = n.expect_msg_seq
local pcall_err = t.pcall_err
local matches = t.matches
local skip = t.skip
local is_os = t.is_os

describe('jobs', function()
  local channel

  before_each(function()
    clear()

    channel = api.nvim_get_chan_info(0).id
    api.nvim_set_var('channel', channel)
    source([[
    function! Normalize(data) abort
      " Windows: remove ^M and term escape sequences
      return type([]) == type(a:data)
        \ ? map(a:data, 'substitute(substitute(v:val, "\r", "", "g"), "\x1b\\%(\\]\\d\\+;.\\{-}\x07\\|\\[.\\{-}[\x40-\x7E]\\)", "", "g")')
        \ : a:data
    endfunction
    function! OnEvent(id, data, event) dict
      let userdata = get(self, 'user')
      let data     = Normalize(a:data)
      call rpcnotify(g:channel, a:event, userdata, data)
    endfunction
    let g:job_opts = {
    \ 'on_stdout': function('OnEvent'),
    \ 'on_exit': function('OnEvent'),
    \ 'user': 0
    \ }
    ]])
  end)

  it('validation', function()
    matches(
      "E475: Invalid argument: job cannot have both 'pty' and 'rpc' options set",
      pcall_err(command, "call jobstart(['cat', '-'], { 'pty': v:true, 'rpc': v:true })")
    )
    matches(
      'E475: Invalid argument: expected valid directory',
      pcall_err(command, "call jobstart(['cat', '-'], { 'cwd': 9313843 })")
    )
    matches(
      'E475: Invalid argument: expected valid directory',
      pcall_err(command, "call jobstart(['cat', '-'], { 'cwd': 'bogusssssss/bogus' })")
    )
    matches(
      "E475: Invalid argument: 'term' must be Boolean",
      pcall_err(command, "call jobstart(['cat', '-'], { 'term': 'bogus' })")
    )
    matches(
      "E475: Invalid argument: 'term' must be Boolean",
      pcall_err(command, "call jobstart(['cat', '-'], { 'term': 1 })")
    )
    command('set modified')
    matches(
      vim.pesc('jobstart(...,{term=true}) requires unmodified buffer'),
      pcall_err(command, "call jobstart(['cat', '-'], { 'term': v:true })")
    )

    -- Non-failure cases:
    command('set nomodified')
    command("call jobstart(['cat', '-'], { 'term': v:true })")
    command("call jobstart(['cat', '-'], { 'term': v:false })")
  end)

  it('must specify env option as a dict', function()
    command('let g:job_opts.env = v:true')
    local _, err = pcall(function()
      if is_os('win') then
        command("let j = jobstart('set', g:job_opts)")
      else
        command("let j = jobstart('env', g:job_opts)")
      end
    end)
    matches('E475: Invalid argument: env', err)
  end)

  it('append environment #env', function()
    command("let $VAR = 'abc'")
    command("let $TOTO = 'goodbye world'")
    command("let g:job_opts.env = {'TOTO': 'hello world'}")
    if is_os('win') then
      command([[call jobstart('echo %TOTO% %VAR%', g:job_opts)]])
    else
      command([[call jobstart('echo $TOTO $VAR', g:job_opts)]])
    end

    expect_msg_seq({
      { 'notification', 'stdout', { 0, { 'hello world abc' } } },
      { 'notification', 'stdout', { 0, { '', '' } } },
    }, {
      { 'notification', 'stdout', { 0, { 'hello world abc', '' } } },
      { 'notification', 'stdout', { 0, { '' } } },
    })
  end)

  it('append environment with pty #env', function()
    command("let $VAR = 'abc'")
    command("let $TOTO = 'goodbye world'")
    command('let g:job_opts.pty = v:true')
    command("let g:job_opts.env = {'TOTO': 'hello world'}")
    if is_os('win') then
      command([[call jobstart('echo %TOTO% %VAR%', g:job_opts)]])
    else
      command([[call jobstart('echo $TOTO $VAR', g:job_opts)]])
    end
    expect_msg_seq({
      { 'notification', 'stdout', { 0, { 'hello world abc' } } },
      { 'notification', 'stdout', { 0, { '', '' } } },
    }, {
      { 'notification', 'stdout', { 0, { 'hello world abc', '' } } },
      { 'notification', 'stdout', { 0, { '' } } },
    })
  end)

  it('replace environment #env', function()
    command("let $VAR = 'abc'")
    command("let $TOTO = 'goodbye world'")
    command("let g:job_opts.env = {'TOTO': 'hello world'}")
    command('let g:job_opts.clear_env = 1')

    -- libuv ensures that certain "required" environment variables are
    -- preserved if the user doesn't provide them in a custom environment
    -- https://github.com/libuv/libuv/blob/635e0ce6073c5fbc96040e336b364c061441b54b/src/win/process.c#L672
    -- https://github.com/libuv/libuv/blob/635e0ce6073c5fbc96040e336b364c061441b54b/src/win/process.c#L48-L60
    --
    -- Rather than expecting a completely empty environment, ensure that $VAR
    -- is *not* in the environment but $TOTO is.
    if is_os('win') then
      command([[call jobstart('echo %TOTO% %VAR%', g:job_opts)]])
      expect_msg_seq({
        { 'notification', 'stdout', { 0, { 'hello world %VAR%', '' } } },
      })
    else
      command('set shell=/bin/sh')
      command([[call jobstart('echo $TOTO $VAR', g:job_opts)]])
      expect_msg_seq({
        { 'notification', 'stdout', { 0, { 'hello world', '' } } },
      })
    end
  end)

  it('handles case-insensitively matching #env vars', function()
    command("let $TOTO = 'abc'")
    -- Since $Toto is being set in the job, it should take precedence over the
    -- global $TOTO on Windows
    command("let g:job_opts = {'env': {'Toto': 'def'}, 'stdout_buffered': v:true}")
    if is_os('win') then
      command([[let j = jobstart('set | find /I "toto="', g:job_opts)]])
    else
      command([[let j = jobstart('env | grep -i toto=', g:job_opts)]])
    end
    command('call jobwait([j])')
    command('let g:output = Normalize(g:job_opts.stdout)')
    local actual = eval('g:output')
    local expected
    if is_os('win') then
      -- Toto is normalized to TOTO so we can detect duplicates, and because
      -- Windows doesn't care about case
      expected = { 'TOTO=def', '' }
    else
      expected = { 'TOTO=abc', 'Toto=def', '' }
    end
    table.sort(actual)
    table.sort(expected)
    eq(expected, actual)
  end)

  it('uses &shell and &shellcmdflag if passed a string', function()
    command("let $VAR = 'abc'")
    if is_os('win') then
      command("let j = jobstart('echo %VAR%', g:job_opts)")
    else
      command("let j = jobstart('echo $VAR', g:job_opts)")
    end
    eq({ 'notification', 'stdout', { 0, { 'abc', '' } } }, next_msg())
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 0 } }, next_msg())
  end)

  it('changes to given / directory', function()
    command("let g:job_opts.cwd = '/'")
    if is_os('win') then
      command("let j = jobstart('cd', g:job_opts)")
    else
      command("let j = jobstart('pwd', g:job_opts)")
    end
    eq({ 'notification', 'stdout', { 0, { pathroot(), '' } } }, next_msg())
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 0 } }, next_msg())
  end)

  it('changes to given `cwd` directory', function()
    local dir = eval('resolve(tempname())'):gsub('/', get_pathsep())
    mkdir(dir)
    command("let g:job_opts.cwd = '" .. dir .. "'")
    if is_os('win') then
      command("let j = jobstart('cd', g:job_opts)")
    else
      command("let j = jobstart('pwd', g:job_opts)")
    end
    expect_msg_seq(
      {
        { 'notification', 'stdout', { 0, { dir, '' } } },
        { 'notification', 'stdout', { 0, { '' } } },
        { 'notification', 'exit', { 0, 0 } },
      },
      -- Alternative sequence:
      {
        { 'notification', 'stdout', { 0, { dir } } },
        { 'notification', 'stdout', { 0, { '', '' } } },
        { 'notification', 'stdout', { 0, { '' } } },
        { 'notification', 'exit', { 0, 0 } },
      }
    )
    rmdir(dir)
  end)

  it('fails to change to invalid `cwd`', function()
    local dir = eval('resolve(tempname())."-bogus"')
    local _, err = pcall(function()
      command("let g:job_opts.cwd = '" .. dir .. "'")
      if is_os('win') then
        command("let j = jobstart('cd', g:job_opts)")
      else
        command("let j = jobstart('pwd', g:job_opts)")
      end
    end)
    matches('E475: Invalid argument: expected valid directory$', err)
  end)

  it('error on non-executable `cwd`', function()
    skip(is_os('win'), 'Not applicable for Windows')

    local dir = 'Xtest_not_executable_dir'
    mkdir(dir)
    fn.setfperm(dir, 'rw-------')
    matches(
      '^Vim%(call%):E903: Process failed to start: permission denied: .*',
      pcall_err(command, "call jobstart(['pwd'], {'cwd': '" .. dir .. "'})")
    )
    rmdir(dir)
  end)

  it('returns 0 when it fails to start', function()
    eq('', eval('v:errmsg'))
    feed_command('let g:test_jobid = jobstart([])')
    eq(0, eval('g:test_jobid'))
    eq('E474:', string.match(eval('v:errmsg'), 'E%d*:'))
  end)

  it('returns -1 when target is not executable #5465', function()
    local function new_job()
      return eval([[jobstart('')]])
    end
    local executable_jobid = new_job()

    local exe = is_os('win') and './test/functional/fixtures'
      or './test/functional/fixtures/non_executable.txt'
    eq(
      "Vim:E475: Invalid value for argument cmd: '" .. exe .. "' is not executable",
      pcall_err(eval, "jobstart(['" .. exe .. "'])")
    )
    eq('', eval('v:errmsg'))
    -- Non-executable job should not increment the job ids. #5465
    eq(executable_jobid + 1, new_job())
  end)

  it('invokes callbacks when the job writes and exits', function()
    command("let g:job_opts.on_stderr  = function('OnEvent')")
    command([[call jobstart(has('win32') ? 'echo:' : 'echo', g:job_opts)]])
    expect_twostreams({
      { 'notification', 'stdout', { 0, { '', '' } } },
      { 'notification', 'stdout', { 0, { '' } } },
    }, { { 'notification', 'stderr', { 0, { '' } } } })
    eq({ 'notification', 'exit', { 0, 0 } }, next_msg())
  end)

  it('interactive commands', function()
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    neq(0, eval('j'))
    command('call jobsend(j, "abc\\n")')
    eq({ 'notification', 'stdout', { 0, { 'abc', '' } } }, next_msg())
    command('call jobsend(j, "123\\nxyz\\n")')
    expect_msg_seq(
      { { 'notification', 'stdout', { 0, { '123', 'xyz', '' } } } },
      -- Alternative sequence:
      {
        { 'notification', 'stdout', { 0, { '123', '' } } },
        { 'notification', 'stdout', { 0, { 'xyz', '' } } },
      }
    )
    command('call jobsend(j, [123, "xyz", ""])')
    expect_msg_seq(
      { { 'notification', 'stdout', { 0, { '123', 'xyz', '' } } } },
      -- Alternative sequence:
      {
        { 'notification', 'stdout', { 0, { '123', '' } } },
        { 'notification', 'stdout', { 0, { 'xyz', '' } } },
      }
    )
    command('call jobstop(j)')
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 143 } }, next_msg())
  end)

  it('preserves NULs', function()
    -- Make a file with NULs in it.
    local filename = t.tmpname()
    write_file(filename, 'abc\0def\n')

    command("let j = jobstart(['cat', '" .. filename .. "'], g:job_opts)")
    eq({ 'notification', 'stdout', { 0, { 'abc\ndef', '' } } }, next_msg())
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 0 } }, next_msg())
    os.remove(filename)

    -- jobsend() preserves NULs.
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    command([[call jobsend(j, ["123\n456",""])]])
    eq({ 'notification', 'stdout', { 0, { '123\n456', '' } } }, next_msg())
    command('call jobstop(j)')
  end)

  it('emits partial lines (does NOT buffer data lacking newlines)', function()
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    command('call jobsend(j, "abc\\nxyz")')
    eq({ 'notification', 'stdout', { 0, { 'abc', 'xyz' } } }, next_msg())
    command('call jobstop(j)')
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 143 } }, next_msg())
  end)

  it('preserves newlines', function()
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    command('call jobsend(j, "a\\n\\nc\\n\\n\\n\\nb\\n\\n")')
    eq({ 'notification', 'stdout', { 0, { 'a', '', 'c', '', '', '', 'b', '', '' } } }, next_msg())
  end)

  it('preserves NULs', function()
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    command('call jobsend(j, ["\n123\n", "abc\\nxyz\n", ""])')
    eq({ 'notification', 'stdout', { 0, { '\n123\n', 'abc\nxyz\n', '' } } }, next_msg())
    command('call jobstop(j)')
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 143 } }, next_msg())
  end)

  it('avoids sending final newline', function()
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    command('call jobsend(j, ["some data", "without\nfinal nl"])')
    eq({ 'notification', 'stdout', { 0, { 'some data', 'without\nfinal nl' } } }, next_msg())
    command('call jobstop(j)')
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 143 } }, next_msg())
  end)

  it('closes the job streams with jobclose', function()
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    command('call jobclose(j, "stdin")')
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 0 } }, next_msg())
  end)

  it('disallows jobsend on a job that closed stdin', function()
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    command('call jobclose(j, "stdin")')
    eq(
      false,
      pcall(function()
        command('call jobsend(j, ["some data"])')
      end)
    )

    command("let g:job_opts.stdin = 'null'")
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    eq(
      false,
      pcall(function()
        command('call jobsend(j, ["some data"])')
      end)
    )
  end)

  it('disallows jobsend on a non-existent job', function()
    eq(false, pcall(eval, "jobsend(-1, 'lol')"))
    eq(0, eval('jobstop(-1)'))
  end)

  it('jobstop twice on the stopped or exited job return 0', function()
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    neq(0, eval('j'))
    eq(1, eval('jobstop(j)'))
    eq(0, eval('jobstop(j)'))
  end)

  it('will not leak memory if we leave a job running', function()
    command("call jobstart(['cat', '-'], g:job_opts)")
  end)

  it('can get the pid value using getpid', function()
    command("let j =  jobstart(['cat', '-'], g:job_opts)")
    local pid = eval('jobpid(j)')
    neq(NIL, api.nvim_get_proc(pid))
    command('call jobstop(j)')
    eq({ 'notification', 'stdout', { 0, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 0, 143 } }, next_msg())
    eq(NIL, api.nvim_get_proc(pid))
  end)

  it('disposed on Nvim exit', function()
    -- Start a child process which doesn't die on stdin close.
    local j = n.fn.jobstart({ n.nvim_prog, '--clean', '--headless' })
    local pid = n.fn.jobpid(j)
    eq('number', type(api.nvim_get_proc(pid).pid))
    clear()
    eq(NIL, api.nvim_get_proc(pid))
  end)

  it('can survive Nvim exit with "detach"', function()
    local j = n.fn.jobstart({ n.nvim_prog, '--clean', '--headless' }, { detach = true })
    local pid = n.fn.jobpid(j)
    eq('number', type(api.nvim_get_proc(pid).pid))
    clear()
    -- Still alive.
    eq('number', type(api.nvim_get_proc(pid).pid))
    -- Clean up after ourselves.
    eq(0, vim.uv.kill(pid, 'sigkill'))
  end)

  it('can pass user data to the callback', function()
    command('let g:job_opts.user = {"n": 5, "s": "str", "l": [1]}')
    command([[call jobstart('echo foo', g:job_opts)]])
    local data = { n = 5, s = 'str', l = { 1 } }
    expect_msg_seq(
      {
        { 'notification', 'stdout', { data, { 'foo', '' } } },
        { 'notification', 'stdout', { data, { '' } } },
      },
      -- Alternative sequence:
      {
        { 'notification', 'stdout', { data, { 'foo' } } },
        { 'notification', 'stdout', { data, { '', '' } } },
        { 'notification', 'stdout', { data, { '' } } },
      }
    )
    eq({ 'notification', 'exit', { data, 0 } }, next_msg())
  end)

  it('can omit data callbacks', function()
    command('unlet g:job_opts.on_stdout')
    command('let g:job_opts.user = 5')
    command([[call jobstart('echo foo', g:job_opts)]])
    eq({ 'notification', 'exit', { 5, 0 } }, next_msg())
  end)

  it('can omit exit callback', function()
    command('unlet g:job_opts.on_exit')
    command('let g:job_opts.user = 5')
    command([[call jobstart('echo foo', g:job_opts)]])
    expect_msg_seq(
      {
        { 'notification', 'stdout', { 5, { 'foo', '' } } },
        { 'notification', 'stdout', { 5, { '' } } },
      },
      -- Alternative sequence:
      {
        { 'notification', 'stdout', { 5, { 'foo' } } },
        { 'notification', 'stdout', { 5, { '', '' } } },
        { 'notification', 'stdout', { 5, { '' } } },
      }
    )
  end)

  it('will pass return code with the exit event', function()
    command('let g:job_opts.user = 5')
    command("call jobstart('exit 55', g:job_opts)")
    eq({ 'notification', 'stdout', { 5, { '' } } }, next_msg())
    eq({ 'notification', 'exit', { 5, 55 } }, next_msg())
  end)

  it('can receive dictionary functions', function()
    source([[
    let g:dict = {'id': 10}
    function g:dict.on_exit(id, code, event)
      call rpcnotify(g:channel, a:event, a:code, self.id)
    endfunction
    call jobstart('exit 45', g:dict)
    ]])
    eq({ 'notification', 'exit', { 45, 10 } }, next_msg())
  end)

  it('can redefine callbacks being used by a job', function()
    local screen = Screen.new()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue },
    })
    source([[
      function! g:JobHandler(job_id, data, event)
      endfunction

      let g:callbacks = {
      \ 'on_stdout': function('g:JobHandler'),
      \ 'on_stderr': function('g:JobHandler'),
      \ 'on_exit': function('g:JobHandler')
      \ }
      let job = jobstart(['cat', '-'], g:callbacks)
    ]])
    poke_eventloop()
    source([[
      function! g:JobHandler(job_id, data, event)
      endfunction
    ]])

    eq('', eval('v:errmsg'))
  end)

  it('requires funcrefs for script-local (s:) functions', function()
    local screen = Screen.new(60, 5)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = { bold = true, foreground = Screen.colors.SeaGreen4 },
    })

    -- Pass job callback names _without_ `function(...)`.
    source([[
      function! s:OnEvent(id, data, event) dict
        let g:job_result = get(self, 'user')
      endfunction
      let s:job = jobstart('echo "foo"', {
        \ 'on_stdout': 's:OnEvent',
        \ 'on_stderr': 's:OnEvent',
        \ 'on_exit':   's:OnEvent',
        \ })
    ]])

    screen:expect { any = '{2:E120: Using <SID> not in a script context: s:OnEvent}' }
  end)

  it('does not repeat output with slow output handlers', function()
    source([[
      let d = {'data': []}
      function! d.on_stdout(job, data, event) dict
        call add(self.data, Normalize(a:data))
        sleep 200m
      endfunction
      function! d.on_exit(job, data, event) dict
        let g:exit_data = copy(self.data)
      endfunction
      if has('win32')
        let cmd = 'for /L %I in (1,1,5) do @(echo %I& ping -n 2 127.0.0.1 > nul)'
      else
        let cmd = ['sh', '-c', 'for i in 1 2 3 4 5; do echo $i; sleep 0.1; done']
      endif
      let g:id = jobstart(cmd, d)
      sleep 1500m
      call jobwait([g:id])
    ]])

    local expected = { '1', '2', '3', '4', '5', '' }
    local chunks = eval('d.data')
    -- check nothing was received after exit, including EOF
    eq(eval('g:exit_data'), chunks)
    local received = { '' }
    for i, chunk in ipairs(chunks) do
      if i < #chunks then
        -- if chunks got joined, a spurious [''] callback was not sent
        neq({ '' }, chunk)
      else
        -- but EOF callback is still sent
        eq({ '' }, chunk)
      end
      received[#received] = received[#received] .. chunk[1]
      for j = 2, #chunk do
        received[#received + 1] = chunk[j]
      end
    end
    eq(expected, received)
  end)

  it('does not invoke callbacks recursively', function()
    source([[
      let d = {'data': []}
      function! d.on_stdout(job, data, event) dict
        " if callbacks were invoked recursively, this would cause on_stdout
        " to be invoked recursively and the data reversed on the call stack
        sleep 200m
        call add(self.data, Normalize(a:data))
      endfunction
      function! d.on_exit(job, data, event) dict
        let g:exit_data = copy(self.data)
      endfunction
      if has('win32')
        let cmd = 'for /L %I in (1,1,5) do @(echo %I& ping -n 2 127.0.0.1 > nul)'
      else
        let cmd = ['sh', '-c', 'for i in 1 2 3 4 5; do echo $i; sleep 0.1; done']
      endif
      let g:id = jobstart(cmd, d)
      sleep 1500m
      call jobwait([g:id])
    ]])

    local expected = { '1', '2', '3', '4', '5', '' }
    local chunks = eval('d.data')
    -- check nothing was received after exit, including EOF
    eq(eval('g:exit_data'), chunks)
    local received = { '' }
    for i, chunk in ipairs(chunks) do
      if i < #chunks then
        -- if chunks got joined, a spurious [''] callback was not sent
        neq({ '' }, chunk)
      else
        -- but EOF callback is still sent
        eq({ '' }, chunk)
      end
      received[#received] = received[#received] .. chunk[1]
      for j = 2, #chunk do
        received[#received + 1] = chunk[j]
      end
    end
    eq(expected, received)
  end)

  it('jobstart() works with partial functions', function()
    source([[
    function PrintArgs(a1, a2, id, data, event)
      " Windows: remove ^M
      let normalized = map(a:data, 'substitute(v:val, "\r", "", "g")')
      call rpcnotify(g:channel, '1', a:a1,  a:a2, normalized, a:event)
    endfunction
    let Callback = function('PrintArgs', ["foo", "bar"])
    let g:job_opts = {'on_stdout': Callback}
    call jobstart('echo some text', g:job_opts)
    ]])
    expect_msg_seq(
      { { 'notification', '1', { 'foo', 'bar', { 'some text', '' }, 'stdout' } } },
      -- Alternative sequence:
      {
        { 'notification', '1', { 'foo', 'bar', { 'some text' }, 'stdout' } },
        { 'notification', '1', { 'foo', 'bar', { '', '' }, 'stdout' } },
      }
    )
  end)

  it('jobstart() works with closures', function()
    source([[
      fun! MkFun()
          let a1 = 'foo'
          let a2 = 'bar'
          return {id, data, event -> rpcnotify(g:channel, '1', a1, a2, Normalize(data), event)}
      endfun
      let g:job_opts = {'on_stdout': MkFun()}
      call jobstart('echo some text', g:job_opts)
    ]])
    expect_msg_seq(
      { { 'notification', '1', { 'foo', 'bar', { 'some text', '' }, 'stdout' } } },
      -- Alternative sequence:
      {
        { 'notification', '1', { 'foo', 'bar', { 'some text' }, 'stdout' } },
        { 'notification', '1', { 'foo', 'bar', { '', '' }, 'stdout' } },
      }
    )
  end)

  it('jobstart() works when closure passed directly to `jobstart`', function()
    source([[
      let g:job_opts = {'on_stdout': {id, data, event -> rpcnotify(g:channel, '1', 'foo', 'bar', Normalize(data), event)}}
      call jobstart('echo some text', g:job_opts)
    ]])
    expect_msg_seq(
      { { 'notification', '1', { 'foo', 'bar', { 'some text', '' }, 'stdout' } } },
      -- Alternative sequence:
      {
        { 'notification', '1', { 'foo', 'bar', { 'some text' }, 'stdout' } },
        { 'notification', '1', { 'foo', 'bar', { '', '' }, 'stdout' } },
      }
    )
  end)

  it('jobstart() environment: $NVIM, $NVIM_LISTEN_ADDRESS #11009', function()
    local function get_child_env(envname, env)
      return exec_lua(
        [[
        local envname, env = ...
        local join = function(s) return vim.fn.join(s, '') end
        local stdout = {}
        local stderr = {}
        local opt = {
          env = env,
          stdout_buffered = true,
          stderr_buffered = true,
          on_stderr = function(chan, data, name) stderr = data end,
          on_stdout = function(chan, data, name) stdout = data end,
        }
        local j1 = vim.fn.jobstart({ vim.v.progpath, '-es', '-V1',('+echo "%s="..getenv("%s")'):format(envname, envname), '+qa!' }, opt)
        vim.fn.jobwait({ j1 }, 10000)
        return join({ join(stdout), join(stderr) })
      ]],
        envname,
        env
      )
    end

    local addr = eval('v:servername')
    ok((addr):len() > 0)
    -- $NVIM is _not_ defined in the top-level Nvim process.
    eq('', eval('$NVIM'))
    -- jobstart() shares its v:servername with the child via $NVIM.
    eq('NVIM=' .. addr, get_child_env('NVIM'))
    -- $NVIM_LISTEN_ADDRESS is unset by server_init in the child.
    eq('NVIM_LISTEN_ADDRESS=v:null', get_child_env('NVIM_LISTEN_ADDRESS'))
    eq(
      'NVIM_LISTEN_ADDRESS=v:null',
      get_child_env('NVIM_LISTEN_ADDRESS', { NVIM_LISTEN_ADDRESS = 'Xtest_jobstart_env' })
    )
    -- User can explicitly set $NVIM_LOG_FILE, $VIM, $VIMRUNTIME.
    eq(
      'NVIM_LOG_FILE=Xtest_jobstart_env',
      get_child_env('NVIM_LOG_FILE', { NVIM_LOG_FILE = 'Xtest_jobstart_env' })
    )
    os.remove('Xtest_jobstart_env')
  end)

  describe('jobwait()', function()
    before_each(function()
      if is_os('win') then
        n.set_shell_powershell()
      end
    end)

    it('returns a list of status codes', function()
      source([[
      call rpcnotify(g:channel, 'wait', jobwait(has('win32') ? [
      \  jobstart('Start-Sleep -Milliseconds 100; exit 4'),
      \  jobstart('Start-Sleep -Milliseconds 300; exit 5'),
      \  jobstart('Start-Sleep -Milliseconds 500; exit 6'),
      \  jobstart('Start-Sleep -Milliseconds 700; exit 7')
      \  ] : [
      \  jobstart('sleep 0.10; exit 4'),
      \  jobstart('sleep 0.110; exit 5'),
      \  jobstart('sleep 0.210; exit 6'),
      \  jobstart('sleep 0.310; exit 7')
      \  ]))
      ]])
      eq({ 'notification', 'wait', { { 4, 5, 6, 7 } } }, next_msg())
    end)

    it('will run callbacks while waiting', function()
      source([[
      let g:dict = {}
      let g:jobs = []
      let g:exits = []
      function g:dict.on_stdout(id, code, event) abort
        call add(g:jobs, a:id)
      endfunction
      function g:dict.on_exit(id, code, event) abort
        if a:code != 5
          throw 'Error!'
        endif
        call add(g:exits, a:id)
      endfunction
      call jobwait(has('win32') ? [
      \  jobstart('Start-Sleep -Milliseconds 100; exit 5', g:dict),
      \  jobstart('Start-Sleep -Milliseconds 300; exit 5', g:dict),
      \  jobstart('Start-Sleep -Milliseconds 500; exit 5', g:dict),
      \  jobstart('Start-Sleep -Milliseconds 700; exit 5', g:dict)
      \  ] : [
      \  jobstart('sleep 0.010; exit 5', g:dict),
      \  jobstart('sleep 0.030; exit 5', g:dict),
      \  jobstart('sleep 0.050; exit 5', g:dict),
      \  jobstart('sleep 0.070; exit 5', g:dict)
      \  ])
      call rpcnotify(g:channel, 'wait', sort(g:jobs), sort(g:exits))
      ]])
      eq({ 'notification', 'wait', { { 3, 4, 5, 6 }, { 3, 4, 5, 6 } } }, next_msg())
    end)

    it('will return status codes in the order of passed ids', function()
      source([[
      call rpcnotify(g:channel, 'wait', jobwait(has('win32') ? [
      \  jobstart('Start-Sleep -Milliseconds 700; exit 4'),
      \  jobstart('Start-Sleep -Milliseconds 500; exit 5'),
      \  jobstart('Start-Sleep -Milliseconds 300; exit 6'),
      \  jobstart('Start-Sleep -Milliseconds 100; exit 7')
      \  ] : [
      \  jobstart('sleep 0.070; exit 4'),
      \  jobstart('sleep 0.050; exit 5'),
      \  jobstart('sleep 0.030; exit 6'),
      \  jobstart('sleep 0.010; exit 7')
      \  ]))
      ]])
      eq({ 'notification', 'wait', { { 4, 5, 6, 7 } } }, next_msg())
    end)

    it('will return -3 for invalid job ids', function()
      source([[
      call rpcnotify(g:channel, 'wait', jobwait([
      \  -10,
      \  jobstart((has('win32') ? 'Start-Sleep -Milliseconds 100' : 'sleep 0.01').'; exit 5'),
      \  ]))
      ]])
      eq({ 'notification', 'wait', { { -3, 5 } } }, next_msg())
    end)

    it('will return -2 when interrupted without timeout', function()
      feed_command(
        'call rpcnotify(g:channel, "ready") | '
          .. 'call rpcnotify(g:channel, "wait", '
          .. 'jobwait([jobstart("'
          .. (is_os('win') and 'Start-Sleep 10' or 'sleep 10')
          .. '; exit 55")]))'
      )
      eq({ 'notification', 'ready', {} }, next_msg())
      feed('<c-c>')
      eq({ 'notification', 'wait', { { -2 } } }, next_msg())
    end)

    it('will return -2 when interrupted with timeout', function()
      feed_command(
        'call rpcnotify(g:channel, "ready") | '
          .. 'call rpcnotify(g:channel, "wait", '
          .. 'jobwait([jobstart("'
          .. (is_os('win') and 'Start-Sleep 10' or 'sleep 10')
          .. '; exit 55")], 10000))'
      )
      eq({ 'notification', 'ready', {} }, next_msg())
      feed('<c-c>')
      eq({ 'notification', 'wait', { { -2 } } }, next_msg())
    end)

    it('can be called recursively', function()
      source([[
      let g:opts = {}
      let g:counter = 0
      function g:opts.on_stdout(id, msg, _event)
        if self.state == 0
          if self.counter < 10
            call Run()
          endif
          let self.state = 1
          call jobsend(a:id, "line1\n")
        elseif self.state == 1
          let self.state = 2
          call jobsend(a:id, "line2\n")
        elseif self.state == 2
          let self.state = 3
          call jobsend(a:id, "line3\n")
        elseif self.state == 3
          let self.state = 4
          call rpcnotify(g:channel, 'w', printf('job %d closed', self.counter))
          call jobclose(a:id, 'stdin')
        endif
      endfunction
      function g:opts.on_exit(...)
        call rpcnotify(g:channel, 'w', printf('job %d exited', self.counter))
      endfunction
      function Run()
        let g:counter += 1
        let j = copy(g:opts)
        let j.state = 0
        let j.counter = g:counter
        call jobwait([
        \   jobstart('echo ready; cat -', j),
        \ ])
      endfunction
      ]])
      feed_command('call Run()')
      local r
      for i = 10, 1, -1 do
        r = next_msg()
        eq('job ' .. i .. ' closed', r[3][1])
        r = next_msg()
        eq('job ' .. i .. ' exited', r[3][1])
      end
      eq(10, api.nvim_eval('g:counter'))
    end)

    describe('with timeout argument', function()
      it('will return -1 if the wait timed out', function()
        source([[
        call rpcnotify(g:channel, 'wait', jobwait([
        \  jobstart((has('win32') ? 'Start-Sleep 10' : 'sleep 10').'; exit 5'),
        \  ], 100))
        ]])
        eq({ 'notification', 'wait', { { -1 } } }, next_msg())
      end)

      it('can pass 0 to check if a job exists', function()
        source([[
        call rpcnotify(g:channel, 'wait', jobwait(has('win32') ? [
        \  jobstart('Start-Sleep -Milliseconds 50; exit 4'),
        \  jobstart('Start-Sleep -Milliseconds 300; exit 5'),
        \  ] : [
        \  jobstart('sleep 0.05; exit 4'),
        \  jobstart('sleep 0.3; exit 5'),
        \  ], 0))
        ]])
        eq({ 'notification', 'wait', { { -1, -1 } } }, next_msg())
      end)
    end)

    it('hides cursor and flushes messages before blocking', function()
      local screen = Screen.new(50, 6)
      command([[let g:id = jobstart([v:progpath, '--clean', '--headless'])]])
      source([[
        func PrintAndWait()
          echon "aaa\nbbb"
          call jobwait([g:id], 300)
          echon "\nccc"
        endfunc
      ]])
      feed(':call PrintAndWait()')
      screen:expect([[
                                                          |
        {1:~                                                 }|*4
        :call PrintAndWait()^                              |
      ]])
      feed('<CR>')
      screen:expect {
        grid = [[
                                                          |
        {1:~                                                 }|*2
        {3:                                                  }|
        aaa                                               |
        bbb                                               |
      ]],
        timeout = 100,
      }
      screen:expect {
        grid = [[
                                                          |
        {3:                                                  }|
        aaa                                               |
        bbb                                               |
        ccc                                               |
        {6:Press ENTER or type command to continue}^           |
      ]],
      }
      feed('<CR>')
      fn.jobstop(api.nvim_get_var('id'))
    end)

    it('does not set UI busy with zero timeout #31712', function()
      local screen = Screen.new(50, 6)
      command([[let g:id = jobstart(['sleep', '0.3'])]])
      local busy = 0
      screen._handle_busy_start = (function(orig)
        return function()
          orig(screen)
          busy = busy + 1
        end
      end)(screen._handle_busy_start)
      source([[
        func PrintAndPoll()
          echon "aaa\nbbb"
          call jobwait([g:id], 0)
          echon "\nccc"
        endfunc
      ]])
      feed_command('call PrintAndPoll()')
      screen:expect {
        grid = [[
                                                          |
        {3:                                                  }|
        aaa                                               |
        bbb                                               |
        ccc                                               |
        {6:Press ENTER or type command to continue}^           |
      ]],
      }
      feed('<CR>')
      fn.jobstop(api.nvim_get_var('id'))
      eq(0, busy)
    end)
  end)

  pending('exit event follows stdout, stderr', function()
    command("let g:job_opts.on_stderr  = function('OnEvent')")
    command("let j = jobstart(['cat', '-'], g:job_opts)")
    api.nvim_eval('jobsend(j, "abcdef")')
    api.nvim_eval('jobstop(j)')
    expect_msg_seq(
      {
        { 'notification', 'stdout', { 0, { 'abcdef' } } },
        { 'notification', 'stdout', { 0, { '' } } },
        { 'notification', 'stderr', { 0, { '' } } },
      },
      -- Alternative sequence:
      {
        { 'notification', 'stderr', { 0, { '' } } },
        { 'notification', 'stdout', { 0, { 'abcdef' } } },
        { 'notification', 'stdout', { 0, { '' } } },
      },
      -- Alternative sequence:
      {
        { 'notification', 'stdout', { 0, { 'abcdef' } } },
        { 'notification', 'stderr', { 0, { '' } } },
        { 'notification', 'stdout', { 0, { '' } } },
      }
    )
    eq({ 'notification', 'exit', { 0, 143 } }, next_msg())
  end)

  it('does not crash when repeatedly failing to start shell', function()
    source([[
      set shell=nosuchshell
      func! DoIt()
        call jobstart('true')
        call jobstart('true')
      endfunc
    ]])
    -- The crash only triggered if both jobs are cleaned up on the same event
    -- loop tick. This is also prevented by try-block, so feed must be used.
    feed_command('call DoIt()')
    feed('<cr>') -- press RETURN
    assert_alive()
  end)

  it('jobstop() kills entire process tree #6530', function()
    -- XXX: Using `nvim` isn't a good test, it reaps its children on exit.
    -- local c = 'call jobstart([v:progpath, "-u", "NONE", "-i", "NONE", "--headless"])'
    -- local j = eval("jobstart([v:progpath, '-u', 'NONE', '-i', 'NONE', '--headless', '-c', '"
    --                ..c.."', '-c', '"..c.."'])")

    -- Create child with several descendants.
    if is_os('win') then
      source([[
      function! s:formatprocs(pid, prefix)
        let result = ''
        let result .= a:prefix . printf("%-24.24s%6s %12.12s %s\n",
              \                         s:procs[a:pid]['name'],
              \                         a:pid,
              \                         s:procs[a:pid]['Session Name'],
              \                         s:procs[a:pid]['Session'])
        if has_key(s:procs[a:pid], 'children')
          for pid in s:procs[a:pid]['children']
            let result .= s:formatprocs(pid, a:prefix . '  ')
          endfor
        endif
        return result
      endfunction

      function! PsTree() abort
        let s:procs = {}
        for proc in map(
              \       map(
              \         systemlist('tasklist /NH'),
              \         'substitute(v:val, "\r", "", "")'),
              \       'split(v:val, "\\s\\+")')
          if len(proc) == 6
            let s:procs[proc[1]] .. ']]' .. [[= {'name': proc[0],
                  \               'Session Name': proc[2],
                  \               'Session': proc[3]}
          endif
        endfor
        for pid in keys(s:procs)
          let children = nvim_get_proc_children(str2nr(pid))
          if !empty(children)
            let s:procs[pid]['children'] = children
            for cpid in children
              let s:procs[printf('%d', cpid)]['parent'] = str2nr(pid)
            endfor
          endif
        endfor
        let result = ''
        for pid in sort(keys(s:procs), {i1, i2 -> i1 - i2})
          if !has_key(s:procs[pid], 'parent')
            let result .= s:formatprocs(pid, '')
          endif
        endfor
        return result
      endfunction
      ]])
    end
    local sleep_cmd = (is_os('win') and 'ping -n 31 127.0.0.1' or 'sleep 30')
    local j = eval("jobstart('" .. sleep_cmd .. ' | ' .. sleep_cmd .. ' | ' .. sleep_cmd .. "')")
    local ppid = fn.jobpid(j)
    local children
    if is_os('win') then
      local status, result = pcall(retry, nil, nil, function()
        children = api.nvim_get_proc_children(ppid)
        -- On Windows conhost.exe may exist, and
        -- e.g. vctip.exe might appear.  #10783
        ok(#children >= 3 and #children <= 5)
      end)
      if not status then
        print('')
        print(eval('PsTree()'))
        error(result)
      end
    else
      retry(nil, nil, function()
        children = api.nvim_get_proc_children(ppid)
        eq(3, #children)
      end)
    end
    -- Assert that nvim_get_proc() sees the children.
    for _, child_pid in ipairs(children) do
      local info = api.nvim_get_proc(child_pid)
      -- eq((is_os('win') and 'nvim.exe' or 'nvim'), info.name)
      eq(ppid, info.ppid)
    end
    -- Kill the root of the tree.
    eq(1, fn.jobstop(j))
    -- Assert that the children were killed.
    retry(nil, nil, function()
      for _, child_pid in ipairs(children) do
        eq(NIL, api.nvim_get_proc(child_pid))
      end
    end)
  end)

  it('jobstop on same id before stopped', function()
    command('let j = jobstart(["cat", "-"], g:job_opts)')
    neq(0, eval('j'))

    eq({ 1, 0 }, eval('[jobstop(j), jobstop(j)]'))
  end)

  describe('running tty-test program', function()
    if skip(is_os('win')) then
      return
    end
    local function next_chunk()
      local rv
      while true do
        local msg = next_msg()
        local data = msg[3][2]
        for i = 1, #data do
          data[i] = data[i]:gsub('\n', '\000')
        end
        rv = table.concat(data, '\n')
        rv = rv:gsub('\r\n$', ''):gsub('^\r\n', '')
        if rv ~= '' then
          break
        end
      end
      return rv
    end

    local j
    local function send(str)
      -- check no nvim_chan_free double free with pty job (#14198)
      api.nvim_chan_send(j, str)
    end

    before_each(function()
      -- Redefine Normalize() so that TTY data is not munged.
      source([[
      function! Normalize(data) abort
        return a:data
      endfunction
      ]])
      insert(testprg('tty-test'))
      command('let g:job_opts.pty = 1')
      command('let exec = [expand("<cfile>:p")]')
      command('let j = jobstart(exec, g:job_opts)')
      j = eval 'j'
      eq('tty ready', next_chunk())
    end)

    it('echoing input', function()
      send('test')
      eq('test', next_chunk())
    end)

    it('resizing window', function()
      command('call jobresize(j, 40, 10)')
      eq('rows: 10, cols: 40', next_chunk())
      command('call jobresize(j, 10, 40)')
      eq('rows: 40, cols: 10', next_chunk())
    end)

    it('jobclose() sends SIGHUP', function()
      command('call jobclose(j)')
      local msg = next_msg()
      msg = (msg[2] == 'stdout') and next_msg() or msg -- Skip stdout, if any.
      eq({ 'notification', 'exit', { 0, 42 } }, msg)
    end)

    it('jobstart() does not keep ptmx file descriptor open', function()
      -- Start another job (using libuv)
      command('let g:job_opts.pty = 0')
      local other_jobid = eval("jobstart(['cat', '-'], g:job_opts)")
      local other_pid = eval('jobpid(' .. other_jobid .. ')')

      -- Other job doesn't block first job from receiving SIGHUP on jobclose()
      command('call jobclose(j)')
      -- Have to wait so that the SIGHUP can be processed by tty-test on time.
      -- Can't wait for the next message in case this test fails, if it fails
      -- there won't be any more messages, and the test would hang.
      vim.uv.sleep(100)
      local err = exc_exec('call jobpid(j)')
      eq('Vim(call):E900: Invalid channel id', err)

      -- cleanup
      eq(other_pid, eval('jobpid(' .. other_jobid .. ')'))
      command('call jobstop(' .. other_jobid .. ')')
    end)
  end)

  it('does not close the same handle twice on exit #25086', function()
    local filename = string.format('%s.lua', t.tmpname())
    write_file(
      filename,
      [[
      vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
          local id = vim.fn.jobstart('sleep 0')
          vim.fn.jobwait({id})
        end,
      })
    ]]
    )

    local screen = tt.setup_child_nvim({
      '--cmd',
      'set notermguicolors',
      '-i',
      'NONE',
      '-u',
      filename,
    })
    -- Wait for startup to complete, so that all terminal responses are received.
    screen:expect([[
      ^                                                  |
      ~                                                 |*3
      {1:[No Name]                       0,0-1          All}|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])

    feed(':q<CR>')
    if is_os('freebsd') then
      screen:expect { any = vim.pesc('[Process exited 0]') }
    else
      screen:expect([[
                                                          |
        [Process exited 0]^                                |
                                                          |*4
        {3:-- TERMINAL --}                                    |
      ]])
    end
  end)
end)

describe('pty process teardown', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(30, 6)
    screen:expect([[
      ^                              |
      {1:~                             }|*4
                                    |
    ]])
  end)

  it('does not prevent/delay exit. #4798 #4900', function()
    skip(fn.executable('sleep') == 0, 'missing "sleep" command')
    -- Use a nested nvim (in :term) to test without --headless.
    fn.jobstart({
      n.nvim_prog,
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--cmd',
      nvim_set,
      -- Use :term again in the _nested_ nvim to get a PTY process.
      -- Use `sleep` to simulate a long-running child of the PTY.
      '+terminal',
      '+!(sleep 300 &)',
      '+qa',
    }, {
      term = true,
      env = { VIMRUNTIME = os.getenv('VIMRUNTIME') },
    })

    -- Exiting should terminate all descendants (PTY, its children, ...).
    screen:expect([[
      ^                              |
      [Process exited 0]            |
                                    |*4
    ]])
  end)
end)
