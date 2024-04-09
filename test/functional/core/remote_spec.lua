local t = require('test.functional.testutil')()

local clear = t.clear
local command = t.command
local eq = t.eq
local exec_capture = t.exec_capture
local exec_lua = t.exec_lua
local expect = t.expect
local fn = t.fn
local insert = t.insert
local nvim_prog = t.nvim_prog
local new_argv = t.new_argv
local neq = t.neq
local set_session = t.set_session
local spawn = t.spawn
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
      server = spawn(new_argv(), true)
      set_session(server)
    end)

    after_each(function()
      server:close()
    end)

    -- Run a `nvim --remote*` command and return { stdout, stderr } of the process
    local function run_remote(...)
      set_session(server)
      local addr = fn.serverlist()[1]

      -- Create an nvim instance just to run the remote-invoking nvim. We want
      -- to wait for the remote instance to exit and calling jobwait blocks
      -- the event loop. If the server event loop is blocked, it can't process
      -- our incoming --remote calls.
      local client_starter = spawn(new_argv(), false, nil, true)
      set_session(client_starter)
      -- Call jobstart() and jobwait() in the same RPC request to reduce flakiness.
      eq(
        { 0 },
        exec_lua(
          [[return vim.fn.jobwait({ vim.fn.jobstart({...}, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data, _)
          _G.Remote_stdout = table.concat(data, '\n')
        end,
        on_stderr = function(_, data, _)
          _G.Remote_stderr = table.concat(data, '\n')
        end,
      }) })]],
          nvim_prog,
          '--clean',
          '--headless',
          '--server',
          addr,
          ...
        )
      )
      local res = exec_lua([[return { _G.Remote_stdout, _G.Remote_stderr }]])
      client_starter:close()
      set_session(server)
      return res
    end

    it('edit a single file', function()
      eq({ '', '' }, run_remote('--remote', fname))
      expect(contents)
      eq(1, #fn.getbufinfo())
    end)

    it('tab edit a single file with a non-changed buffer', function()
      eq({ '', '' }, run_remote('--remote-tab', fname))
      expect(contents)
      eq(1, #fn.gettabinfo())
    end)

    it('tab edit a single file with a changed buffer', function()
      insert('hello')
      eq({ '', '' }, run_remote('--remote-tab', fname))
      expect(contents)
      eq(2, #fn.gettabinfo())
    end)

    it('edit multiple files', function()
      eq({ '', '' }, run_remote('--remote', fname, other_fname))
      expect(contents)
      command('next')
      expect(other_contents)
      eq(2, #fn.getbufinfo())
    end)

    it('send keys', function()
      eq({ '', '' }, run_remote('--remote-send', ':edit ' .. fname .. '<CR><C-W>v'))
      expect(contents)
      eq(2, #fn.getwininfo())
      -- Only a single buffer as we're using edit and not drop like --remote does
      eq(1, #fn.getbufinfo())
    end)

    it('evaluate expressions', function()
      eq({ '0', '' }, run_remote('--remote-expr', 'setline(1, "Yo")'))
      eq({ 'Yo', '' }, run_remote('--remote-expr', 'getline(1)'))
      expect('Yo')
      eq({ ('k'):rep(1234), '' }, run_remote('--remote-expr', 'repeat("k", 1234)'))
      eq({ '1.25', '' }, run_remote('--remote-expr', '1.25'))
      eq({ 'no', '' }, run_remote('--remote-expr', '0z6E6F'))
      eq({ '\t', '' }, run_remote('--remote-expr', '"\t"'))
    end)
  end)

  it('creates server if not found', function()
    clear('--remote', fname)
    expect(contents)
    eq(1, #fn.getbufinfo())
    -- Since we didn't pass silent, we should get a complaint
    neq(nil, string.find(exec_capture('messages'), 'E247:'))
  end)

  it('creates server if not found with tabs', function()
    clear('--remote-tab-silent', fname, other_fname)
    expect(contents)
    eq(2, #fn.gettabinfo())
    eq(2, #fn.getbufinfo())
    -- We passed silent, so no message should be issued about the server not being found
    eq(nil, string.find(exec_capture('messages'), 'E247:'))
  end)

  describe('exits with error on', function()
    local function run_and_check_exit_code(...)
      local bogus_argv = new_argv(...)

      -- Create an nvim instance just to run the remote-invoking nvim. We want
      -- to wait for the remote instance to exit and calling jobwait blocks
      -- the event loop. If the server event loop is blocked, it can't process
      -- our incoming --remote calls.
      clear()
      -- Call jobstart() and jobwait() in the same RPC request to reduce flakiness.
      eq({ 2 }, exec_lua([[return vim.fn.jobwait({ vim.fn.jobstart(...) })]], bogus_argv))
    end
    it('bogus subcommand', function()
      run_and_check_exit_code('--remote-bogus')
    end)

    it('send without server', function()
      run_and_check_exit_code('--remote-send', 'i')
    end)

    it('expr without server', function()
      run_and_check_exit_code('--remote-expr', 'setline(1, "Yo")')
    end)
    it('wait subcommand', function()
      run_and_check_exit_code('--remote-wait', fname)
    end)
  end)
end)
