local helpers = require('test.functional.helpers')(after_each)

local command = helpers.command
local eval = helpers.eval
local eq, neq = helpers.eq, helpers.neq
local run = helpers.run

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

  it('is non-zero after :cquit', function()
    local function on_setup()
      command('autocmd VimLeavePre * call rpcrequest('..cid..', "")')
      command('autocmd VimLeave    * call rpcrequest('..cid..', "")')
      command('cquit')
    end
    local function on_request()
      neq(0, eval('v:exiting'))
      return ''
    end
    run(on_request, nil, on_setup)
  end)

  it('is specified a non-zero exit code after :cquit', function()
    local function on_setup()
      command('autocmd VimLeavePre * call rpcrequest('..cid..', "")')
      command('autocmd VimLeave    * call rpcrequest('..cid..', "")')
      command('cquit 123')
    end
    local function on_request()
      eq(123, eval('v:exiting'))
      return ''
    end
    run(on_request, nil, on_setup)
  end)

  it('is specified a zero exit code after :cquit', function()
    local function on_setup()
      command('autocmd VimLeavePre * call rpcrequest('..cid..', "")')
      command('autocmd VimLeave    * call rpcrequest('..cid..', "")')
      command('cquit 0')
    end
    local function on_request()
      eq(0, eval('v:exiting'))
      return ''
    end
    run(on_request, nil, on_setup)
  end)
end)
