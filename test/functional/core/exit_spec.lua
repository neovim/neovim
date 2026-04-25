local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local assert_alive = n.assert_alive
local command = n.command
local feed_command = n.feed_command
local feed = n.feed
local eval = n.eval
local eq = t.eq
local run = n.run
local pcall_err = t.pcall_err
local exec_capture = n.exec_capture
local poke_eventloop = n.poke_eventloop

describe('exit:', function()
  local cid

  before_each(function()
    n.clear()
    cid = n.api.nvim_get_chan_info(0).id
  end)

  it('v:exiting defaults to v:null', function()
    eq(1, eval('v:exiting is v:null'))
    eq('', eval('v:exitreason'))
  end)

  local function test_exiting(setup_fn)
    local function on_setup()
      command(('autocmd QuitPre     * call rpcrequest(%d, "exit", "QuitPre")'):format(cid))
      command(('autocmd ExitPre     * call rpcrequest(%d, "exit", "ExitPre")'):format(cid))
      command(('autocmd VimLeavePre * call rpcrequest(%d, "exit", "VimLeavePre")'):format(cid))
      command(('autocmd VimLeave    * call rpcrequest(%d, "exit", "VimLeave")'):format(cid))
      setup_fn()
    end
    local received = {}
    local function on_request(name, args)
      eq('exit', name)
      table.insert(received, args)
      eq('quit', eval('v:exitreason'))
      if args[1] == 'VimLeavePre' or args[1] == 'VimLeave' then
        eq(0, eval('v:exiting'))
      end
      return ''
    end
    run(on_request, nil, on_setup)
    eq({ { 'QuitPre' }, { 'ExitPre' }, { 'VimLeavePre' }, { 'VimLeave' } }, received)
  end

  it('v:exiting=0, v:exitreason=quit on normal exit', function()
    test_exiting(function()
      command('quit')
    end)
  end)

  it('v:exiting=0, v:exitreason=quit on exit from Ex mode try-catch vim-patch:8.0.0184', function()
    test_exiting(function()
      feed('gQ')
      feed_command('try', 'call NoFunction()', 'catch', 'echo "bye"', 'endtry', 'quit')
    end)
  end)

  it('resets v:exitreason if quit is cancelled', function()
    n.api.nvim_buf_set_lines(0, 0, -1, true, { 'modified' })
    pcall_err(command, 'quit')
    eq('', eval('v:exitreason'))
  end)
end)

describe(':cquit', function()
  local function test_cq(cmdline, exit_code, redir_msg)
    if redir_msg then
      n.clear()
      eq(
        redir_msg,
        pcall_err(function()
          return exec_capture(cmdline)
        end)
      )
      poke_eventloop()
      assert_alive()
      n.check_close()
    else
      local p = n.spawn_wait('--cmd', cmdline)
      eq(exit_code, p.status)
    end
  end

  it('exits with non-zero after :cquit', function()
    test_cq('cquit', 1, nil)
  end)

  it('exits with non-zero after :cquit 123', function()
    test_cq('cquit 123', 123, nil)
  end)

  it('exits with non-zero after :123 cquit', function()
    test_cq('123 cquit', 123, nil)
  end)

  it('exits with 0 after :cquit 0', function()
    test_cq('cquit 0', 0, nil)
  end)

  it('exits with 0 after :0 cquit', function()
    test_cq('0 cquit', 0, nil)
  end)

  it('exits with redir msg for multiple exit codes after :cquit 1 2', function()
    test_cq(
      'cquit 1 2',
      nil,
      'nvim_exec2(), line 1: Vim(cquit):E488: Trailing characters: 2: cquit 1 2'
    )
  end)

  it('exits with redir msg for non-number exit code after :cquit X', function()
    test_cq(
      'cquit X',
      nil,
      'nvim_exec2(), line 1: Vim(cquit):E488: Trailing characters: X: cquit X'
    )
  end)

  it('exits with redir msg for negative exit code after :cquit -1', function()
    test_cq(
      'cquit -1',
      nil,
      'nvim_exec2(), line 1: Vim(cquit):E488: Trailing characters: -1: cquit -1'
    )
  end)
end)

describe('when piping to stdin, no crash during exit', function()
  before_each(function()
    n.clear()
  end)

  it('after :quit non-last window in vim.schedule() callback #14379', function()
    n.fn.system({
      n.nvim_prog,
      '-es',
      '--cmd',
      "lua vim.schedule(function() vim.cmd('vsplit | quit') end)",
      '+quit',
    }, '')
    eq(0, n.api.nvim_get_vvar('shell_error'))
  end)

  it('after :quit non-last window in vim.defer_fn() callback #14379', function()
    n.fn.system({
      n.nvim_prog,
      '-es',
      '--cmd',
      "lua vim.defer_fn(function() vim.cmd('vsplit | quit') end, 0)",
      '+quit',
    }, '')
    eq(0, n.api.nvim_get_vvar('shell_error'))
  end)

  it('after closing v:stderr channel', function()
    n.fn.system({
      n.nvim_prog,
      '-es',
      '--cmd',
      'call chanclose(v:stderr)',
      '+quit',
    }, '')
    eq(0, n.api.nvim_get_vvar('shell_error'))
  end)
end)
