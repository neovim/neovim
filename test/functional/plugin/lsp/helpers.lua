local helpers = require('test.functional.helpers')(nil)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local run = helpers.run
local stop = helpers.stop
local NIL = helpers.NIL

local M = {}

function M.clear_notrace()
  -- problem: here be dragons
  -- solution: don't look too closely for dragons
  clear {env={
    NVIM_LUA_NOTRACK="1";
    NVIM_APPNAME="nvim_lsp_test";
    VIMRUNTIME=os.getenv"VIMRUNTIME";
  }}
end

M.create_server_definition = [[
  function _create_server(opts)
    opts = opts or {}
    local server = {}
    server.messages = {}

    function server.cmd(dispatchers)
      local closing = false
      local handlers = opts.handlers or {}
      local srv = {}

      function srv.request(method, params, callback)
        table.insert(server.messages, {
          method = method,
          params = params,
        })
        local handler = handlers[method]
        if handler then
          local response, err = handler(method, params)
          callback(err, response)
        elseif method == 'initialize' then
          callback(nil, {
            capabilities = opts.capabilities or {}
          })
        elseif method == 'shutdown' then
          callback(nil, nil)
        end
        local request_id = #server.messages
        return true, request_id
      end

      function srv.notify(method, params)
        table.insert(server.messages, {
          method = method,
          params = params
        })
        if method == 'exit' then
          dispatchers.on_exit(0, 15)
        end
      end

      function srv.is_closing()
        return closing
      end

      function srv.terminate()
        closing = true
      end

      return srv
    end

    return server
  end
]]

-- Fake LSP server.
M.fake_lsp_code = 'test/functional/fixtures/fake-lsp-server.lua'
M.fake_lsp_logfile = 'Xtest-fake-lsp.log'

local function fake_lsp_server_setup(test_name, timeout_ms, options, settings)
  exec_lua([=[
    lsp = require('vim.lsp')
    local test_name, fake_lsp_code, fake_lsp_logfile, timeout, options, settings = ...
    TEST_RPC_CLIENT_ID = lsp.start_client {
      cmd_env = {
        NVIM_LOG_FILE = fake_lsp_logfile;
        NVIM_LUA_NOTRACK = "1";
        NVIM_APPNAME = "nvim_lsp_test";
      };
      cmd = {
        vim.v.progpath, '-l', fake_lsp_code, test_name, tostring(timeout),
      };
      handlers = setmetatable({}, {
        __index = function(t, method)
          return function(...)
            return vim.rpcrequest(1, 'handler', ...)
          end
        end;
      });
      workspace_folders = {{
          uri = 'file://' .. vim.uv.cwd(),
          name = 'test_folder',
      }};
      on_init = function(client, result)
        TEST_RPC_CLIENT = client
        vim.rpcrequest(1, "init", result)
      end;
      flags = {
        allow_incremental_sync = options.allow_incremental_sync or false;
        debounce_text_changes = options.debounce_text_changes or 0;
      };
      settings = settings;
      on_exit = function(...)
        vim.rpcnotify(1, "exit", ...)
      end;
    }
  ]=], test_name, M.fake_lsp_code, M.fake_lsp_logfile, timeout_ms or 1e3, options or {}, settings or {})
end

function M.test_rpc_server(config)
  if config.test_name then
    M.clear_notrace()
    fake_lsp_server_setup(config.test_name, config.timeout_ms or 1e3, config.options, config.settings)
  end
  local client = setmetatable({}, {
    __index = function(_, name)
      -- Workaround for not being able to yield() inside __index for Lua 5.1 :(
      -- Otherwise I would just return the value here.
      return function(...)
        return exec_lua([=[
        local name = ...
        if type(TEST_RPC_CLIENT[name]) == 'function' then
          return TEST_RPC_CLIENT[name](select(2, ...))
        else
          return TEST_RPC_CLIENT[name]
        end
        ]=], name, ...)
      end
    end;
  })
  local code, signal
  local function on_request(method, args)
    if method == "init" then
      if config.on_init then
        config.on_init(client, unpack(args))
      end
      return NIL
    end
    if method == 'handler' then
      if config.on_handler then
        config.on_handler(unpack(args))
      end
    end
    return NIL
  end
  local function on_notify(method, args)
    if method == 'exit' then
      code, signal = unpack(args)
      return stop()
    end
  end
  --  TODO specify timeout?
  --  run(on_request, on_notify, config.on_setup, 1000)
  run(on_request, on_notify, config.on_setup)
  if config.on_exit then
    config.on_exit(code, signal)
  end
  stop()
  if config.test_name then
    exec_lua("vim.api.nvim_exec_autocmds('VimLeavePre', { modeline = false })")
  end
end

return M
