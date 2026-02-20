local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local exec_capture = n.exec_capture
local exec_lua = n.exec_lua
local expect = n.expect
local fn = n.fn
local insert = n.insert
local nvim_prog = n.nvim_prog
local neq = t.neq
local new_session = n.new_session
local set_session = n.set_session
local tmpname = t.tmpname
local write_file = t.write_file

describe('Remote', function()
  local fname, other_fname
  local contents = 'The call is coming from outside the process'
  local other_contents = "A second file's contents"

  before_each(function()
    fname = tmpname() .. ' with spaces in the filename'
    other_fname = tmpname()
    write_file(fname, contents)
    write_file(other_fname, other_contents)
  end)

  describe('connect to server and', function()
    local server

    before_each(function()
      server = n.clear()
    end)

    after_each(function()
      server:close()
    end)

    -- Run a `nvim --remote` command asynchronously, wait for the given file to
    -- appear in the server, run action_fn on the server, then wait for the
    -- client to exit. Returns { exit_code, stdout, stderr }.
    local function run_remote(args, file, action_fn)
      set_session(server)
      local addr = fn.serverlist()[1]

      local helper = new_session(true)
      set_session(helper)

      local job_args = { nvim_prog, '--clean', '--headless', '--server', addr }
      for _, a in ipairs(args) do
        table.insert(job_args, a)
      end

      exec_lua(
        [[
          _G.Remote_jobid = vim.fn.jobstart({...}, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data) _G.Remote_stdout = table.concat(data, '\n') end,
            on_stderr = function(_, data) _G.Remote_stderr = table.concat(data, '\n') end,
          })
        ]],
        unpack(job_args)
      )

      if file then
        exec_lua(
          [[
            local addr, file = ...
            local chan = vim.fn.sockconnect('pipe', addr, { rpc = true })
            local deadline = vim.uv.now() + 5000
            repeat
              vim.uv.sleep(20)
              local bufs = vim.fn.rpcrequest(chan, 'nvim_list_bufs')
              for _, b in ipairs(bufs) do
                if vim.fn.rpcrequest(chan, 'nvim_buf_get_name', b) == file then
                  vim.fn.chanclose(chan)
                  return
                end
              end
            until vim.uv.now() >= deadline
            vim.fn.chanclose(chan)
          ]],
          addr,
          file
        )
      end

      set_session(server)
      if action_fn then
        action_fn()
      end

      set_session(helper)
      local code = exec_lua('return vim.fn.jobwait({_G.Remote_jobid}, 3000)')[1]
      local stdout = exec_lua('return _G.Remote_stdout')
      local stderr = exec_lua('return _G.Remote_stderr')
      helper:close()
      set_session(server)
      return code, stdout, stderr
    end

    it('edit a single file and wait for it to be closed', function()
      local code, stdout, stderr = run_remote({ '--remote', fname }, fname, function()
        command('bdelete')
      end)
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
    end)

    it('edit multiple files and wait for all to be closed', function()
      local buf_count
      local code, stdout, stderr = run_remote(
        { '--remote', fname, other_fname },
        other_fname,
        function()
          buf_count = #fn.getbufinfo({ buflisted = 1 })
          command('bdelete!')
          command('bdelete!')
        end
      )
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
      eq(2, buf_count)
    end)

    it('does not exit until all files are closed', function()
      local code, _, _ = run_remote({ '--remote', fname, other_fname }, other_fname, function()
        command('bdelete!')
      end)
      eq(-1, code)
    end)

    it('tab edit a single file with a non-changed buffer (-p)', function()
      local tab_count
      local code, stdout, stderr = run_remote({ '-p', '--remote', fname }, fname, function()
        tab_count = #fn.gettabinfo()
        command('bdelete')
      end)
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
      eq(1, tab_count)
    end)

    it('tab edit a single file with a changed buffer (-p)', function()
      insert('hello')
      local tab_count
      local code, stdout, stderr = run_remote({ '-p', '--remote', fname }, fname, function()
        tab_count = #fn.gettabinfo()
        command('bdelete')
      end)
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
      eq(2, tab_count)
    end)

    it('tab edit multiple files (-p)', function()
      local tab_count
      local code, stdout, stderr = run_remote(
        { '-p', '--remote', fname, other_fname },
        other_fname,
        function()
          tab_count = #fn.gettabinfo()
          command('bdelete!')
          command('bdelete!')
        end
      )
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
      eq(2, tab_count)
    end)

    it('executes +cmd on the server', function()
      local code, stdout, stderr = run_remote(
        { '--remote', fname, '+call setline(1, "modified")' },
        fname,
        function()
          expect('modified')
          command('bdelete!')
        end
      )
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
    end)

    it('executes -c on the server', function()
      local code, stdout, stderr = run_remote(
        { '--remote', fname, '-c', 'call setline(1, "modified-from-c")' },
        fname,
        function()
          expect('modified-from-c')
          command('bdelete!')
        end
      )
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
    end)

    it('executes +cmd only (no files) and exits immediately', function()
      local code, stdout, stderr =
        run_remote({ '--remote', '+call setline(1, "remote-cmd")' }, nil, nil)
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
      expect('remote-cmd')
    end)

    it('returns output from remote commands', function()
      local code, stdout, stderr = run_remote({ '--remote', '+echo 1+1' }, nil, nil)
      eq(0, code)
      neq(nil, string.find(stdout, '2'))
      eq('', stderr)
    end)

    -- Runs a `nvim --remote +async` command, waits for the client to exit
    -- (capturing exit code via on_exit so jobwait is not needed), optionally
    -- waits for a file to appear in the server, then runs action_fn.
    local function run_async(args, file, action_fn)
      set_session(server)
      local addr = fn.serverlist()[1]

      local helper = new_session(true)
      set_session(helper)

      local job_args = { nvim_prog, '--clean', '--headless', '--server', addr }
      for _, a in ipairs(args) do
        table.insert(job_args, a)
      end

      exec_lua(
        [[
          _G.Async_exit_code = nil
          _G.Async_stdout = ''
          _G.Async_stderr = ''
          _G.Async_jobid = vim.fn.jobstart({...}, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data) _G.Async_stdout = table.concat(data, '\n') end,
            on_stderr = function(_, data) _G.Async_stderr = table.concat(data, '\n') end,
            on_exit = function(_, code) _G.Async_exit_code = code end,
          })
        ]],
        unpack(job_args)
      )

      if file then
        exec_lua(
          [[
            local addr, file = ...
            local chan = vim.fn.sockconnect('pipe', addr, { rpc = true })
            local deadline = vim.uv.now() + 5000
            repeat
              vim.uv.sleep(20)
              local bufs = vim.fn.rpcrequest(chan, 'nvim_list_bufs')
              for _, b in ipairs(bufs) do
                if vim.fn.rpcrequest(chan, 'nvim_buf_get_name', b) == file then
                  vim.fn.chanclose(chan)
                  return
                end
              end
            until vim.uv.now() >= deadline
            vim.fn.chanclose(chan)
          ]],
          addr,
          file
        )
      end

      -- Wait for on_exit to fire (the job may have already exited).
      -- vim.wait() pumps the event loop so callbacks can run.
      exec_lua([[
        vim.wait(3000, function() return _G.Async_exit_code ~= nil end, 10)
      ]])

      set_session(server)
      if action_fn then
        action_fn()
      end

      set_session(helper)
      local code = exec_lua('return _G.Async_exit_code')
      local stdout = exec_lua('return _G.Async_stdout')
      local stderr = exec_lua('return _G.Async_stderr')
      helper:close()
      set_session(server)
      return code, stdout, stderr
    end

    it('+async opens file and exits immediately without waiting', function()
      local code, stdout, stderr = run_async({ '--remote', '+async', fname }, fname, nil)
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
    end)

    it('+async opens multiple files and exits immediately', function()
      local code, stdout, stderr =
        run_async({ '--remote', '+async', fname, other_fname }, other_fname, nil)
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
    end)

    it('+async with -p opens files in tabs and exits immediately', function()
      local code, stdout, stderr = run_async({ '-p', '--remote', '+async', fname }, fname, nil)
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
    end)

    it('+async combined with other +cmd args', function()
      local code, stdout, stderr = run_async(
        { '--remote', '+async', fname, '+call setline(1, "async-modified")' },
        fname,
        function()
          expect('async-modified')
        end
      )
      eq(0, code)
      eq('', stdout)
      eq('', stderr)
    end)

    it('exits with 0 when server quits before buffer is closed (VimLeave)', function()
      local code, _, stderr = run_remote({ '--remote', fname }, fname, function()
        local chan = fn.sockconnect('pipe', fn.serverlist()[1], { rpc = 1 })
        fn.rpcnotify(chan, 'nvim_command', 'qa!')
      end)
      eq(0, code)
      eq('', stderr)
    end)
  end)

  it('falls back to editing locally when no server is found', function()
    clear('--remote', fname)
    expect(contents)
    eq(1, #fn.getbufinfo())
    neq(nil, string.find(exec_capture('messages'), 'E247:'))
  end)

  it('prints E247 warning when no server is found', function()
    clear('--server', '/no-such.sock', '--remote', fname)
    neq(nil, string.find(exec_capture('messages'), 'E247:'))
  end)

  it('suppresses warning with -Es when no server is found', function()
    local p = n.spawn_wait { args = { '-Es', '--server', '/no-such.sock', '--remote', fname } }
    eq(0, p.status)
    eq('', p.stderr)
  end)

  it('unknown --remote subcommand exits with error', function()
    local p = n.spawn_wait { args = { '--remote-bogus' } }
    eq(2, p.status)
  end)
end)
