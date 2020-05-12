local helpers = require('test.functional.helpers')(after_each)

local command = helpers.command
local feed_command = helpers.feed_command
local eval = helpers.eval
local eq = helpers.eq
local run = helpers.run
local funcs = helpers.funcs
local nvim_prog = helpers.nvim_prog
local redir_exec = helpers.redir_exec
local wait = helpers.wait

describe('v:exiting', function()
  local cid

  before_each(function()
    helpers.clear()
    cid = helpers.nvim('get_api_info')[1]
  end)

  it('defaults to v:null', function()
    eq(1, eval('v:exiting is v:null'))
  end)

  it('is 0 on normal exit', function()
    local function on_setup()
      command('autocmd VimLeavePre * call rpcrequest('..cid..', "")')
      command('autocmd VimLeave    * call rpcrequest('..cid..', "")')
      command('quit')
    end
    local function on_request()
      eq(0, eval('v:exiting'))
      return ''
    end
    run(on_request, nil, on_setup)
  end)
  it('is 0 on exit from ex-mode involving try-catch', function()
    local function on_setup()
      command('autocmd VimLeavePre * call rpcrequest('..cid..', "")')
      command('autocmd VimLeave    * call rpcrequest('..cid..', "")')
      feed_command('call feedkey("Q")','try', 'call NoFunction()', 'catch', 'echo "bye"', 'endtry', 'quit')
    end
    local function on_request()
      eq(0, eval('v:exiting'))
      return ''
    end
    run(on_request, nil, on_setup)
  end)
end)

describe(':cquit', function()
  local function test_cq(cmdline, exit_code, redir_msg)
    if redir_msg then
      eq('\n' .. redir_msg, redir_exec(cmdline))
      wait()
      eq(2, eval("1+1"))  -- Still alive?
    else
      funcs.system({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless', '--cmd', cmdline})
      eq(exit_code, eval('v:shell_error'))
    end
  end

  before_each(function()
    helpers.clear()
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
    test_cq('cquit 1 2', nil, 'E488: Trailing characters: cquit 1 2')
  end)

  it('exits with redir msg for non-number exit code after :cquit X', function()
    test_cq('cquit X', nil, 'E488: Trailing characters: cquit X')
  end)

  it('exits with redir msg for negative exit code after :cquit -1', function()
    test_cq('cquit -1', nil, 'E488: Trailing characters: cquit -1')
  end)
end)
