-- luacheck: push ignore 113
local helpers = require('test.functional.helpers')(after_each)
-- luacheck: pop
local clear = helpers.clear

local function clear_notrace()
  -- problem: here be dragons
  -- solution: don't look for dragons to closely
  clear {env={
    NVIM_LUA_NOTRACK="1";
    VIMRUNTIME=os.getenv"VIMRUNTIME";
  }}
end

local exec_lua = helpers.exec_lua
local NIL = helpers.NIL

-- Use these to get access to a coroutine so that I can run async tests and use
-- yield.
local run, stop = helpers.run, helpers.stop
local M = {}

M.code = 'test/functional/fixtures/fake-lsp-server.lua'
M.logfile = 'Xtest-fake-lsp.log'

function M.setup(test_name, timeout_ms, options, settings)
  exec_lua([=[
    lsp = require('vim.lsp')
    local test_name, fixture_filename, logfile, timeout, options, settings = ...
    TEST_RPC_CLIENT_ID = lsp.start_client {
      cmd_env = {
        NVIM_LOG_FILE = logfile;
        NVIM_LUA_NOTRACK = "1";
      };
      cmd = {
        vim.v.progpath, '-Es', '-u', 'NONE', '--headless',
        "-c", string.format("lua TEST_NAME = %q", test_name),
        "-c", string.format("lua TIMEOUT = %d", timeout),
        "-c", "luafile "..fixture_filename,
      };
      handlers = setmetatable({}, {
        __index = function(t, method)
          return function(...)
            return vim.rpcrequest(1, 'handler', ...)
          end
        end;
      });
      workspace_folders = {{
          uri = 'file://' .. vim.loop.cwd(),
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
  ]=], test_name, M.code, M.logfile, timeout_ms or 1e3, options or {}, settings or {})
end

function M.test(config)
  if config.test_name then
    clear_notrace()
    M.setup(config.test_name, config.timeout_ms or 1e3, config.options, config.settings)
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
