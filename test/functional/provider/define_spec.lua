local t = require('test.functional.testutil')()
local eval, command = t.eval, t.command
local eq, run, stop = t.eq, t.run, t.stop
local clear = t.clear
local api = t.api

local function get_prefix(sync)
  if sync then
    return 'sync'
  end
  return 'async'
end

local function call(fn, arguments)
  command('call ' .. fn .. '(' .. arguments .. ')')
end

local function clear_and_init(init)
  return function()
    clear()
    if init then
      init()
    end
  end
end

local function runx(sync, handler, on_setup)
  local function setup_cb(...)
    on_setup(...)
    -- need to stop on setup callback because there's two session:request
    -- calls in `request/t.lua`. The second call will always return
    -- after pending notification/request callbacks are processed
    stop()
  end
  local function handler_cb(...)
    return handler(...)
  end
  if sync then
    run(handler_cb, nil, setup_cb)
  else
    run(nil, handler_cb, setup_cb)
  end
end

local function command_specs_for(fn, sync, first_arg_factory, init)
  local prefix = get_prefix(sync)

  describe(prefix .. ' command created by', function()
    before_each(clear_and_init(init))

    describe(fn, function()
      local args

      before_each(function()
        args = first_arg_factory() .. ', "test-handler", '
        if sync then
          args = args .. '1'
        else
          args = args .. '0'
        end
        args = args .. ', "RpcCommand"'
      end)

      it('without options', function()
        call(fn, args .. ', {}')
        local function on_setup()
          command('RpcCommand')
        end

        local function handler(method)
          eq('test-handler', method)
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with nargs', function()
        call(fn, args .. ', {"nargs": "*"}')
        local function on_setup()
          command('RpcCommand arg1 arg2 arg3')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ 'arg1', 'arg2', 'arg3' }, arguments[1])
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with nargs/double-quote', function()
        call(fn, args .. ', {"nargs": "*"}')
        local function on_setup()
          command('RpcCommand "arg1" "arg2" "arg3"')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ '"arg1"', '"arg2"', '"arg3"' }, arguments[1])
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with range', function()
        call(fn, args .. ', {"range": ""}')
        local function on_setup()
          command('1,1RpcCommand')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ 1, 1 }, arguments[1])
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with nargs/range', function()
        call(fn, args .. ', {"nargs": "1", "range": ""}')
        local function on_setup()
          command('1,1RpcCommand arg')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ 'arg' }, arguments[1])
          eq({ 1, 1 }, arguments[2])
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with nargs/count', function()
        call(fn, args .. ', {"nargs": "1", "count": "5"}')
        local function on_setup()
          command('5RpcCommand arg')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ 'arg' }, arguments[1])
          eq(5, arguments[2])
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with nargs/count/bang', function()
        call(fn, args .. ', {"nargs": "1", "count": "5", "bang": ""}')
        local function on_setup()
          command('5RpcCommand! arg')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ 'arg' }, arguments[1])
          eq(5, arguments[2])
          eq(1, arguments[3])
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with nargs/count/bang/register', function()
        call(fn, args .. ', {"nargs": "1", "count": "5", "bang": "",' .. ' "register": ""}')
        local function on_setup()
          command('5RpcCommand! b arg')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ 'arg' }, arguments[1])
          eq(5, arguments[2])
          eq(1, arguments[3])
          eq('b', arguments[4])
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with nargs/count/bang/register/eval', function()
        call(
          fn,
          args
            .. ', {"nargs": "1", "count": "5", "bang": "",'
            .. ' "register": "", "eval": "@<reg>"}'
        )
        local function on_setup()
          command('let @b = "regb"')
          command('5RpcCommand! b arg')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ 'arg' }, arguments[1])
          eq(5, arguments[2])
          eq(1, arguments[3])
          eq('b', arguments[4])
          eq('regb', arguments[5])
          return ''
        end

        runx(sync, handler, on_setup)
      end)
    end)
  end)
end

local function autocmd_specs_for(fn, sync, first_arg_factory, init)
  local prefix = get_prefix(sync)

  describe(prefix .. ' autocmd created by', function()
    before_each(clear_and_init(init))

    describe(fn, function()
      local args

      before_each(function()
        args = first_arg_factory() .. ', "test-handler", '
        if sync then
          args = args .. '1'
        else
          args = args .. '0'
        end
        args = args .. ', "BufEnter"'
      end)

      it('without options', function()
        call(fn, args .. ', {}')
        local function on_setup()
          command('doautocmd BufEnter x.c')
        end

        local function handler(method)
          eq('test-handler', method)
          return ''
        end

        runx(sync, handler, on_setup)
      end)

      it('with eval', function()
        call(fn, args .. [[, {'eval': 'expand("<afile>")'}]])
        local function on_setup()
          command('doautocmd BufEnter x.c')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq('x.c', arguments[1])
          return ''
        end

        runx(sync, handler, on_setup)
      end)
    end)
  end)
end

local function function_specs_for(fn, sync, first_arg_factory, init)
  local prefix = get_prefix(sync)

  describe(prefix .. ' function created by', function()
    before_each(clear_and_init(init))

    describe(fn, function()
      local args

      before_each(function()
        args = first_arg_factory() .. ', "test-handler", '
        if sync then
          args = args .. '1'
        else
          args = args .. '0'
        end
        args = args .. ', "TestFunction"'
      end)

      it('without options', function()
        call(fn, args .. ', {}')
        local function on_setup()
          if sync then
            eq('rv', eval('TestFunction(1, "a", ["b", "c"])'))
          else
            eq(1, eval('TestFunction(1, "a", ["b", "c"])'))
          end
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ { 1, 'a', { 'b', 'c' } } }, arguments)
          return 'rv'
        end

        runx(sync, handler, on_setup)
      end)

      it('with eval', function()
        call(fn, args .. [[, {'eval': '2 + 2'}]])
        local function on_setup()
          if sync then
            eq('rv', eval('TestFunction(1, "a", ["b", "c"])'))
          else
            eq(1, eval('TestFunction(1, "a", ["b", "c"])'))
          end
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ { 1, 'a', { 'b', 'c' } }, 4 }, arguments)
          return 'rv'
        end

        runx(sync, handler, on_setup)
      end)

      it('with range', function()
        t.insert([[
          foo
          bar
          baz
          zub]])
        call(fn, args .. [[, {'range': ''}]])
        local function on_setup()
          command('2,3call TestFunction(1, "a", ["b", "c"])')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ { 1, 'a', { 'b', 'c' } }, { 2, 3 } }, arguments)
          return 'rv'
        end

        runx(sync, handler, on_setup)
      end)

      it('with eval/range', function()
        call(fn, args .. [[, {'eval': '4', 'range': ''}]])
        local function on_setup()
          command('%call TestFunction(1, "a", ["b", "c"])')
        end

        local function handler(method, arguments)
          eq('test-handler', method)
          eq({ { 1, 'a', { 'b', 'c' } }, { 1, 1 }, 4 }, arguments)
          return 'rv'
        end

        runx(sync, handler, on_setup)
      end)
    end)
  end)
end

local function channel()
  return api.nvim_get_chan_info(0).id
end

local function host()
  return '"busted"'
end

local function register()
  eval('remote#host#Register("busted", "busted", ' .. channel() .. ')')
end

command_specs_for('remote#define#CommandOnChannel', true, channel)
command_specs_for('remote#define#CommandOnChannel', false, channel)
command_specs_for('remote#define#CommandOnHost', true, host, register)
command_specs_for('remote#define#CommandOnHost', false, host, register)

autocmd_specs_for('remote#define#AutocmdOnChannel', true, channel)
autocmd_specs_for('remote#define#AutocmdOnChannel', false, channel)
autocmd_specs_for('remote#define#AutocmdOnHost', true, host, register)
autocmd_specs_for('remote#define#AutocmdOnHost', false, host, register)

function_specs_for('remote#define#FunctionOnChannel', true, channel)
function_specs_for('remote#define#FunctionOnChannel', false, channel)
function_specs_for('remote#define#FunctionOnHost', true, host, register)
function_specs_for('remote#define#FunctionOnHost', false, host, register)
