local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local neovim = require('test.client2.neovim')

describe('nvim client', function()
  local nvim
  setup(function()
    nvim = neovim.new_child(n.nvim_prog, { '--embed', '-u', 'NONE', '-i', 'NONE' })
  end)

  teardown(function()
    if nvim then
      nvim:close()
    end
  end)

  it('can call to nvim', function()
    t.eq(3, nvim:eval('1 + 2'))
  end)

  it('can handle requests from nvim', function()
    local channel = nvim:get_api_info()[1]
    local arg
    nvim.handlers = {
      request_test = function(a)
        arg = a
        return 'world'
      end,
    }
    t.eq('world', nvim:call('rpcrequest', channel, 'request_test', 'hello'))
    t.eq('hello', arg)
  end)

  it('can handle notifications from nvim', function()
    local channel = nvim:get_api_info()[1]
    local arg
    nvim.handlers = {
      request_test = function(a)
        arg = a
      end,
    }
    nvim:call('rpcnotify', channel, 'request_test', 'hello')
    nvim:get_api_info() -- ensure that notify was received
    t.eq('hello', arg)
  end)

  it('can handle errors returned from nvim', function()
    assert.has_error(function()
      nvim:call('bogus function')
    end, 'exception: Vim:E117: Unknown function: bogus function')

    -- Caught: (no error)  Expected: (string) ''
    -- assert.has_error(function() nvim:call('eval', 'bogus expr') end, '')
  end)

  it('can return errors to nvim', function()
    local channel = nvim:get_api_info()[1]
    nvim.handlers['error_test'] = function()
      nvim:error('ouch')
    end

    -- Caught: (no error) Expected: (string) 'ouch'
    -- assert.has_error(function() nvim:call('rpcrequest', channel, 'error_test') end, 'ouch')

    -- Yuck. Is there a better way to check the error?
    t.eq(
      "\nError invoking 'error_test' on channel 1:\nouch",
      nvim:call('execute', 'silent! call rpcrequest(' .. channel .. ', "error_test")')
    )
  end)

  it('can construct extension types', function()
    local x, y

    x = nvim:get_current_buf()
    assert.is_not_nil(x)
    y = nvim:buf(x.id)
    t.eq(x, y)

    x = nvim:get_current_win()
    assert.is_not_nil(x)
    y = nvim:win(x.id)
    t.eq(x, y)

    x = nvim:get_current_tabpage()
    assert.is_not_nil(x)
    y = nvim:tabpage(x.id)
    t.eq(x, y)
  end)

  describe('buf', function()
    it('can compare eq', function()
      local bufs1 = nvim:list_bufs()
      local bufs2 = nvim:list_bufs()
      t.eq(bufs1[1], bufs2[1])
    end)

    it('not eq win', function()
      local b = nvim:buf(1)
      local w = nvim:win(1)
      assert.are_not.equal(b, w)
    end)

    it('line functions', function()
      local buf = nvim:get_current_buf()
      -- nvim:put({'line1', 'line2'}, 'l', false, false)
      t.eq(1, buf:line_count())
      buf:set_lines(1, 2, false, { 'line' })
      t.eq(2, buf:line_count())
      local lines = buf:get_lines(0, -1, true)
      t.eq(2, #lines)
      t.eq('', lines[1])
      t.eq('line', lines[2])
      buf:set_lines(1, 2, true, {})
      t.eq(1, buf:line_count())
    end)
  end)
end)
