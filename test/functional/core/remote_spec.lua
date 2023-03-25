local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local expect = helpers.expect
local funcs = helpers.funcs
local insert = helpers.insert
local meths = helpers.meths
local new_argv = helpers.new_argv
local neq = helpers.neq
local set_session = helpers.set_session
local spawn = helpers.spawn
local tmpname = helpers.tmpname
local write_file = helpers.write_file

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

    local function run_remote(...)
      set_session(server)
      local addr = funcs.serverlist()[1]
      local client_argv = new_argv({args={'--server', addr, ...}})

      -- Create an nvim instance just to run the remote-invoking nvim. We want
      -- to wait for the remote instance to exit and calling jobwait blocks
      -- the event loop. If the server event loop is blocked, it can't process
      -- our incoming --remote calls.
      local client_starter = spawn(new_argv(), false, nil, true)
      set_session(client_starter)
      -- Call jobstart() and jobwait() in the same RPC request to reduce flakiness.
      eq({ 0 }, exec_lua([[return vim.fn.jobwait({ vim.fn.jobstart(...) })]], client_argv))
      client_starter:close()
      set_session(server)
    end

    it('edit a single file', function()
      run_remote('--remote', fname)
      expect(contents)
      eq(2, #funcs.getbufinfo())
    end)

    it('tab edit a single file with a non-changed buffer', function()
      run_remote('--remote-tab', fname)
      expect(contents)
      eq(1, #funcs.gettabinfo())
    end)

    it('tab edit a single file with a changed buffer', function()
      insert('hello')
      run_remote('--remote-tab', fname)
      expect(contents)
      eq(2, #funcs.gettabinfo())
    end)

    it('edit multiple files', function()
      run_remote('--remote', fname, other_fname)
      expect(contents)
      command('next')
      expect(other_contents)
      eq(3, #funcs.getbufinfo())
    end)

    it('send keys', function()
      run_remote('--remote-send', ':edit '..fname..'<CR><C-W>v')
      expect(contents)
      eq(2, #funcs.getwininfo())
      -- Only a single buffer as we're using edit and not drop like --remote does
      eq(1, #funcs.getbufinfo())
    end)

    it('evaluate expressions', function()
      run_remote('--remote-expr', 'setline(1, "Yo")')
      expect('Yo')
    end)
  end)

  it('creates server if not found', function()
    clear('--remote', fname)
    expect(contents)
    eq(1, #funcs.getbufinfo())
    -- Since we didn't pass silent, we should get a complaint
    neq(nil, string.find(meths.exec2('messages', { output = true }).output, 'E247'))
  end)

  it('creates server if not found with tabs', function()
    clear('--remote-tab-silent', fname, other_fname)
    expect(contents)
    eq(2, #funcs.gettabinfo())
    eq(2, #funcs.getbufinfo())
    -- We passed silent, so no message should be issued about the server not being found
    eq(nil, string.find(meths.exec2('messages', { output = true }).output, 'E247'))
  end)

  pending('exits with error on', function()
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
