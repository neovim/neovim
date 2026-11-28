local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
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
local set_session = n.set_session
local tmpname = t.tmpname
local write_file = t.write_file

describe('--remote', function()
  local fname, other_fname
  local contents = 'The call is coming from outside the process'
  local other_contents = "A second file's contents"

  before_each(function()
    fname = tmpname() .. ' with spaces in the filename'
    other_fname = tmpname()
    write_file(fname, contents)
    write_file(other_fname, other_contents)
  end)

  describe('connect', function()
    local server
    before_each(function()
      server = n.clear()
    end)

    after_each(function()
      server:close()
    end)

    -- Start `nvim --remote*` from another Nvim, so the server event loop is not blocked.
    local client_starter
    local function start_remote(...)
      set_session(server)
      local addr = fn.serverlist()[1]
      client_starter = n.new_session(true)
      set_session(client_starter)
      exec_lua(
        [[_G.Remote_job = vim.fn.jobstart({...}, {
          stdout_buffered = true,
          stderr_buffered = true,
          on_stdout = function(_, data, _)
            _G.Remote_stdout = table.concat(data, '\n')
          end,
          on_stderr = function(_, data, _)
            _G.Remote_stderr = table.concat(data, '\n')
          end,
        })]],
        nvim_prog,
        '--clean',
        '--headless',
        '--server',
        addr,
        ...
      )
      set_session(server)
    end

    --- @return [integer, string, string] # exit code (-1 if still running), stdout, stderr
    local function finish_remote(timeout)
      set_session(client_starter)
      local res = exec_lua(function(ms)
        local code = vim.fn.jobwait({ _G.Remote_job }, ms)[1]
        return { code, _G.Remote_stdout, _G.Remote_stderr }
      end, timeout or 10000)
      if res[1] ~= -1 then
        client_starter:close()
      end
      set_session(server)
      return res
    end

    after_each(function()
      if client_starter then
        client_starter:close()
        client_starter = nil
      end
    end)

    -- Run a `nvim --remote*` command that does not wait and return { stdout, stderr }
    local function run_remote(...)
      start_remote(...)
      local res = finish_remote()
      eq(0, res[1])
      return { res[2], res[3] }
    end

    local function wait_for_text(text)
      t.retry(nil, 10000, function()
        eq(text, n.api.nvim_get_current_line())
      end)
    end

    local function assert_waiting()
      eq(-1, finish_remote(200)[1])
    end

    it('edit a single file', function()
      start_remote('--remote', fname)
      wait_for_text(contents)
      expect(contents)
      eq(1, #fn.getbufinfo())
      assert_waiting()
      command('enew')
      eq({ 0, '', '' }, finish_remote())
    end)

    it('tab edit a single file with a non-changed buffer', function()
      start_remote('--remote-tab', fname)
      wait_for_text(contents)
      expect(contents)
      eq(1, #fn.gettabinfo())
      command('enew')
      eq({ 0, '', '' }, finish_remote())
    end)

    it('tab edit a single file with a changed buffer', function()
      insert('hello')
      start_remote('--remote-tab', fname)
      wait_for_text(contents)
      expect(contents)
      eq(2, #fn.gettabinfo())
      assert_waiting()
      command('tabclose')
      eq({ 0, '', '' }, finish_remote())
    end)

    it('edit multiple files', function()
      start_remote('--remote', fname, other_fname)
      wait_for_text(contents)
      expect(contents)
      command('next')
      expect(other_contents)
      eq(2, #fn.getbufinfo())
      assert_waiting()
      command('enew')
      eq({ 0, '', '' }, finish_remote())
    end)

    it('waits for files that were not displayed yet', function()
      start_remote('--remote', fname, other_fname)
      wait_for_text(contents)
      command('enew')
      assert_waiting()
      command('bwipeout ' .. fn.fnameescape(other_fname))
      eq({ 0, '', '' }, finish_remote())
    end)

    it('done when the buffer is deleted', function()
      start_remote('--remote', fname)
      wait_for_text(contents)
      assert_waiting()
      command('bdelete')
      eq({ 0, '', '' }, finish_remote())
    end)

    it('done when the server exits', function()
      start_remote('--remote', fname)
      wait_for_text(contents)
      assert_waiting()
      server:close()
      eq(0, finish_remote()[1])
      server = n.clear()
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

    it('security: server-to-client API calls are rejected', function()
      exec_lua(function()
        _G.call_client = function()
          local client = 0
          for _, chan in ipairs(vim.api.nvim_list_chans()) do
            client = math.max(client, chan.id)
          end
          return select(2, pcall(vim.rpcrequest, client, 'nvim_eval', '1'))
        end
      end)
      t.matches(
        'Rejected API call from untrusted peer: nvim_eval',
        run_remote('--remote-expr', 'luaeval("_G.call_client()")')[1]
      )
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
      local p = n.spawn_wait { args = { ... } }
      eq(2, p.status)
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
