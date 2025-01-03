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

describe('v:exiting', function()
  local cid

  before_each(function()
    n.clear()
    cid = n.api.nvim_get_chan_info(0).id
  end)

  it('defaults to v:null', function()
    eq(1, eval('v:exiting is v:null'))
  end)

  local function test_exiting(setup_fn)
    local function on_setup()
      command('autocmd VimLeavePre * call rpcrequest(' .. cid .. ', "exit", "VimLeavePre")')
      command('autocmd VimLeave    * call rpcrequest(' .. cid .. ', "exit", "VimLeave")')
      setup_fn()
    end
    local requests_args = {}
    local function on_request(name, args)
      eq('exit', name)
      table.insert(requests_args, args)
      eq(0, eval('v:exiting'))
      return ''
    end
    run(on_request, nil, on_setup)
    eq({ { 'VimLeavePre' }, { 'VimLeave' } }, requests_args)
  end

  it('is 0 on normal exit', function()
    test_exiting(function()
      command('quit')
    end)
  end)

  it('is 0 on exit from Ex mode involving try-catch vim-patch:8.0.0184', function()
    test_exiting(function()
      feed('gQ')
      feed_command('try', 'call NoFunction()', 'catch', 'echo "bye"', 'endtry', 'quit')
    end)
  end)
end)

describe(':cquit', function()
  local function test_cq(cmdline, exit_code, redir_msg)
    if redir_msg then
      eq(
        redir_msg,
        pcall_err(function()
          return exec_capture(cmdline)
        end)
      )
      poke_eventloop()
      assert_alive()
    else
      local p = n.spawn_wait('--cmd', cmdline)
      eq(exit_code, p.status)
    end
  end

  before_each(function()
    n.clear()
  end)

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
    test_cq('cquit 1 2', nil, 'nvim_exec2(): Vim(cquit):E488: Trailing characters: 2: cquit 1 2')
  end)

  it('exits with redir msg for non-number exit code after :cquit X', function()
    test_cq('cquit X', nil, 'nvim_exec2(): Vim(cquit):E488: Trailing characters: X: cquit X')
  end)

  it('exits with redir msg for negative exit code after :cquit -1', function()
    test_cq('cquit -1', nil, 'nvim_exec2(): Vim(cquit):E488: Trailing characters: -1: cquit -1')
  end)
end)
