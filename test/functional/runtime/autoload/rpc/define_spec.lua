local helpers = require('test.functional.helpers')
local eval, command, nvim = helpers.eval, helpers.command, helpers.nvim
local eq, run, stop = helpers.eq, helpers.run, helpers.stop
local clear, feed = helpers.clear, helpers.feed


local function runx(sync, handler, on_setup)
  local function setup_cb(...)
    on_setup(...)
    -- need to stop on setup callback because there's two session:request
    -- calls in `request/helpers.lua`. The second call will always return
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

local function command_specs_for(fn, sync,first_arg_factory, init)
  local function call(args)
    command('call '..fn..'('..args..')')
  end

  local prefix = 'async'
  if sync then
    prefix = 'sync'
  end

  describe(prefix..' command created by', function()
    before_each(function()
      clear()
      if init then
        init()
      end
    end)

    describe(fn, function()
      local args

      before_each(function()
        args = first_arg_factory()..', "test-handler", '
        if sync then
          args = args .. '1'
        else
          args = args .. '0'
        end
        args = args..', "RpcCommand"'
      end)

      describe('without options', function()
        it('ok', function()
          call(args..', {}')
          local function on_setup()
            command('RpcCommand')
          end

          local function handler(method)
            eq('test-handler', method)
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)

      describe('with nargs', function()
        it('ok', function()
          call(args..', {"nargs": "*"}')
          local function on_setup()
            command('RpcCommand arg1 arg2 arg3')
          end

          local function handler(method, args)
            eq('test-handler', method)
            eq({'arg1', 'arg2', 'arg3'}, args[1])
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)

      describe('with range', function()
        it('ok', function()
          call(args..', {"range": ""}')
          local function on_setup()
            command('1,1RpcCommand')
          end

          local function handler(method, args)
            eq('test-handler', method)
            eq({1, 1}, args[1])
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)

      describe('with nargs/range', function()
        it('ok', function()
          call(args..', {"nargs": "1", "range": ""}')
          local function on_setup()
            command('1,1RpcCommand arg')
          end

          local function handler(method, args)
            eq('test-handler', method)
            eq({'arg'}, args[1])
            eq({1, 1}, args[2])
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)

      describe('with nargs/count', function()
        it('ok', function()
          call(args..', {"nargs": "1", "range": "5"}')
          local function on_setup()
            command('5RpcCommand arg')
          end

          local function handler(method, args)
            eq('test-handler', method)
            eq({'arg'}, args[1])
            eq(5, args[2])
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)

      describe('with nargs/count/bang', function()
        it('ok', function()
          call(args..', {"nargs": "1", "range": "5", "bang": ""}')
          local function on_setup()
            command('5RpcCommand! arg')
          end

          local function handler(method, args)
            eq('test-handler', method)
            eq({'arg'}, args[1])
            eq(5, args[2])
            eq(1, args[3])
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)

      describe('with nargs/count/bang/register', function()
        it('ok', function()
          call(args..', {"nargs": "1", "range": "5", "bang": "",'..
                     ' "register": ""}')
          local function on_setup()
            command('5RpcCommand! b arg')
          end

          local function handler(method, args)
            eq('test-handler', method)
            eq({'arg'}, args[1])
            eq(5, args[2])
            eq(1, args[3])
            eq('b', args[4])
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)

      describe('with nargs/count/bang/register/eval', function()
        it('ok', function()
          call(args..', {"nargs": "1", "range": "5", "bang": "",'..
                     ' "register": "", "eval": "@<reg>"}')
          local function on_setup()
            command('let @b = "regb"')
            command('5RpcCommand! b arg')
          end

          local function handler(method, args)
            eq('test-handler', method)
            eq({'arg'}, args[1])
            eq(5, args[2])
            eq(1, args[3])
            eq('b', args[4])
            eq('regb', args[5])
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)
    end)
  end)
end

local function autocmd_specs_for(fn, sync, first_arg_factory, init)
  local function call(args)
    command('call '..fn..'('..args..')')
  end

  local prefix = 'async'
  if sync then
    prefix = 'sync'
  end

  describe(prefix..' autocmd created by', function()
    before_each(function()
      clear()
      if init then
        init()
      end
    end)

    describe(fn, function()
      local args

      before_each(function()
        args = first_arg_factory()..', "test-handler", '
        if sync then
          args = args .. '1'
        else
          args = args .. '0'
        end
        args = args..', "BufEnter"'
      end)

      describe('without options', function()
        it('ok', function()
          call(args..', {}')
          local function on_setup()
            command('doautocmd BufEnter x.c')
          end

          local function handler(method, args)
            eq('test-handler', method)
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)

      describe('with eval', function()
        it('ok', function()
          call(args..[[, {'eval': 'expand("<afile>")'}]])
          local function on_setup()
            command('doautocmd BufEnter x.c')
          end

          local function handler(method, args)
            eq('test-handler', method)
            eq('x.c', args[1])
            return ''
          end

          runx(sync, handler, on_setup)
        end)
      end)
    end)
  end)
end


local function channel()
  return nvim('get_api_info')[1]
end

local function host()
  return '"busted"'
end

local function register()
  eval('rpc#host#Register("busted", '..channel()..')')
end

command_specs_for('rpc#define#CommandOnChannel', true, channel)
command_specs_for('rpc#define#CommandOnChannel', false, channel)
command_specs_for('rpc#define#CommandOnHost', true, host, register)
command_specs_for('rpc#define#CommandOnHost', false, host, register)

autocmd_specs_for('rpc#define#AutocmdOnChannel', true, channel)
autocmd_specs_for('rpc#define#AutocmdOnChannel', false, channel)
autocmd_specs_for('rpc#define#AutocmdOnHost', true, host, register)
autocmd_specs_for('rpc#define#AutocmdOnHost', false, host, register)
