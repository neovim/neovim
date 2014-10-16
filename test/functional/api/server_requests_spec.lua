-- Tests for some server->client RPC scenarios. Note that unlike with
-- `rpcnotify`, to evaluate `rpcrequest` calls we need the client event loop to
-- be running.
local helpers = require('test.functional.helpers')
local clear, nvim, eval, eq, run, stop = helpers.clear, helpers.nvim,
      helpers.eval, helpers.eq, helpers.run, helpers.stop


describe('server -> client', function()
  local cid

  before_each(function()
    clear()
    cid = nvim('get_api_info')[1]
  end)

  describe('simple call', function()
    it('works', function()
      local function on_setup()
        eq({4, 5, 6}, eval('rpcrequest('..cid..', "scall", 1, 2, 3)'))
        stop()
      end

      local function on_request(method, args)
        eq('scall', method)
        eq({1, 2, 3}, args)
        nvim('command', 'let g:result = [4, 5, 6]')
        return eval('g:result')
      end
      run(on_request, nil, on_setup)
    end)
  end)

  describe('recursive call', function()
    it('works', function()
      local function on_setup()
        nvim('set_var', 'result1', 0)
        nvim('set_var', 'result2', 0)
        nvim('set_var', 'result3', 0)
        nvim('set_var', 'result4', 0)
        nvim('command', 'let g:result1 = rpcrequest('..cid..', "rcall", 2)')
        eq(4, nvim('get_var', 'result1'))
        eq(8, nvim('get_var', 'result2'))
        eq(16, nvim('get_var', 'result3'))
        eq(32, nvim('get_var', 'result4'))
        stop()
      end

      local function on_request(method, args)
        eq('rcall', method)
        local n = unpack(args) * 2
        if n <= 16 then
          local cmd
          if n == 4 then
            cmd = 'let g:result2 = rpcrequest('..cid..', "rcall", '..n..')'
          elseif n == 8 then
            cmd = 'let g:result3 = rpcrequest('..cid..', "rcall", '..n..')'
          elseif n == 16 then
            cmd = 'let g:result4 = rpcrequest('..cid..', "rcall", '..n..')'
          end
          nvim('command', cmd)
        end
        return n
      end
      run(on_request, nil, on_setup)
    end)
  end)
end)
