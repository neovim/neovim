local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local source = helpers.source
local dedent = helpers.dedent
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local neq = helpers.neq
local NIL = helpers.NIL

-- Use these to get access to a coroutine so that I can run async tests and use
-- yield.
local run, stop = helpers.run, helpers.stop

local function test_rpc_server_setup(test_name)
  exec_lua([=[
    lsp = require('vim.lsp')
    TEST_RPC_CLIENT_ID = lsp.start_client {
      cmd = {
        vim.api.nvim_get_vvar("progpath"), '-Es', '-u', 'NONE', '--headless',
        "-c", string.format("lua TEST_NAME = %q", ...),
        "-c", "luafile test/functional/fixtures/lsp-test-rpc-server.lua"
      };
      callbacks = setmetatable({}, {
        __index = function(t, method)
          return function(...)
            return vim.fn.rpcrequest(1, 'callback', ...)
          end
        end;
      });
      root_dir = vim.loop.cwd();
      on_init = function(client, result)
        TEST_RPC_CLIENT = client
        local commands = vim.fn.rpcrequest(1, "init", result)
        for _, v in ipairs(commands) do
          client[v[1]](unpack(v[2]))
        end
      end;
      on_exit = function(...)
        vim.fn.rpcnotify(1, "exit", ...)
      end;
    }
  ]=], test_name)
end

local function test_rpc_server(config)
  if config.test_name then
    clear()
    test_rpc_server_setup(config.test_name)
  end
  local init_commands = {}
  local client = setmetatable({}, {
    __index = function(_, name)
      local argtype = exec_lua("return type(TEST_RPC_CLIENT[...])", name)
      if argtype == 'function' then
        return function(...)
          return exec_lua([=[
          local args = {...}
          return TEST_RPC_CLIENT[table.remove(args, 1)](unpack(args))
          ]=], name, ...)
        end
      else
        return exec_lua("return TEST_RPC_CLIENT[...]", name)
      end
      -- if name == 'id' then
      --   return exec_lua("return TEST_RPC_CLIENT_ID")
      -- end
      -- return function(...)
      --   table.insert(init_commands, {name, {...}})
      -- end
    end;
  })
  local code, signal
  local function on_request(method, args)
    if method == "init" then
      if config.on_init then
        config.on_init(client, unpack(args))
      end
      return init_commands
    end
    if method == 'callback' then
      if config.on_callback then
        config.on_callback(unpack(args))
      end
    end
    return {}
  end
  local function on_notify(method, args)
    if method == 'exit' then
      code, signal = unpack(args)
      stop()
      return
    end
  end
  local function on_setup()
  end
  run(on_request, on_notify, on_setup, 1000)
  if config.on_exit then
    config.on_exit(code, signal)
  end
  stop()
  if config.test_name then
    exec_lua("lsp._vim_exit_handler()")
  end
end

describe('Language Client API', function()
  describe('server_name is specified', function()
    before_each(function()
      clear()
      -- Run an instance of nvim on the file which contains our "scripts".
      -- Pass TEST_NAME to pick the script.
      local test_name = "basic_init"
      exec_lua([=[
        lsp = require('vim.lsp')
        TEST_RPC_CLIENT_ID = lsp.start_client {
          cmd = {
            vim.api.nvim_get_vvar("progpath"), '-Es', '-u', 'NONE', '--headless',
            "-c", string.format("lua TEST_NAME = %q", ...),
            "-c", "luafile test/functional/fixtures/lsp-test-rpc-server.lua"
          };
          root_dir = vim.loop.cwd();
        }
      ]=], test_name)
    end)

    after_each(function()
      exec_lua("lsp._vim_exit_handler()")
     -- exec_lua("lsp.stop_all_clients(true)")
    end)

    describe('start_client and stop_client', function()
      it('should return true', function()
        helpers.sleep(10)
        eq(1, exec_lua("return #lsp.get_active_clients()"))
        eq(false, exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID) == nil"))
        eq(false, exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID).is_stopped()"))
        exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID).stop()")
        eq(false, exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID).is_stopped()"))
        helpers.sleep(10)
        eq(true, exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID) == nil"))
      end)
    end)
  end)

  describe('basic_init test', function()
    it('should run correctly', function()
      local expected_callbacks = {
        {NIL, "test", {}, 1};
      }
      test_rpc_server {
        test_name = "basic_init";
        on_init = function(client, _init_result)
          -- client is a dummy object which will queue up commands to be run
          -- once the server initializes. It can't accept lua callbacks or
          -- other types that may be unserializable for now.
          client.stop()
        end;
        -- If the program timed out, then code will be nil.
        on_exit = function(code, signal)
          eq(0, code, "exit code") eq(0, signal, "exit signal")
        end;
        -- Note that NIL must be used here.
        -- on_callback(err, method, result, client_id)
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...})
        end;
      }
    end)

    it('should fail', function()
      local expected_callbacks = {
        {NIL, "test", {}, 1};
      }
      test_rpc_server {
        test_name = "basic_init";
        on_init = function(client)
          client.notify('test')
          client.stop()
        end;
        on_exit = function(code, signal)
          eq(1, code, "exit code") eq(0, signal, "exit signal")
        end;
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...}, "expected callback")
        end;
      }
    end)

    it('should succeed with manual shutdown', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "test", {}, 1};
      }
      test_rpc_server {
        test_name = "basic_init";
        on_init = function(client)
          client.request('shutdown')
          client.notify('exit')
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code") eq(0, signal, "exit signal")
        end;
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...}, "expected callback")
        end;
      }
    end)
  end)
end)
