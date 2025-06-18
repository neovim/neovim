local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local run = n.run
local stop = n.stop
local api = n.api
local NIL = vim.NIL

local M = {}

function M.clear_notrace()
  -- problem: here be dragons
  -- solution: don't look too closely for dragons
  clear {
    env = {
      NVIM_LUA_NOTRACK = '1',
      NVIM_APPNAME = 'nvim_lsp_test',
      VIMRUNTIME = os.getenv 'VIMRUNTIME',
    },
  }
end

M.create_tcp_echo_server = function()
  --- Create a TCP server that echos the first message it receives.
  --- @param host string
  ---@return uv.uv_tcp_t
  ---@return integer
  ---@return fun():string|nil
  function _G._create_tcp_server(host)
    local uv = vim.uv
    local server = assert(uv.new_tcp())
    local init = nil
    server:bind(host, 0)
    server:listen(127, function(err)
      assert(not err, err)
      local socket = assert(uv.new_tcp())
      server:accept(socket)
      socket:read_start(require('vim.lsp.rpc').create_read_loop(function(body)
        init = body
        socket:close()
      end))
    end)
    local port = server:getsockname().port
    return server, port, function()
      return init
    end
  end
end

M.create_server_definition = function()
  function _G._create_server(opts)
    opts = opts or {}
    local server = {}
    server.messages = {}

    function server.cmd(dispatchers, _config)
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
          handler(method, params, callback)
        elseif method == 'initialize' then
          callback(nil, {
            capabilities = opts.capabilities or {},
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
          params = params,
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
end

-- Fake LSP server.
M.fake_lsp_code = 'test/functional/fixtures/fake-lsp-server.lua'
M.fake_lsp_logfile = 'Xtest-fake-lsp.log'

local function fake_lsp_server_setup(test_name, timeout_ms, options, settings)
  exec_lua(function(fake_lsp_code, fake_lsp_logfile, timeout)
    options = options or {}
    settings = settings or {}
    _G.lsp = require('vim.lsp')
    _G.TEST_RPC_CLIENT_ID = _G.lsp.start_client {
      cmd_env = {
        NVIM_LOG_FILE = fake_lsp_logfile,
        NVIM_LUA_NOTRACK = '1',
        NVIM_APPNAME = 'nvim_lsp_test',
      },
      cmd = {
        vim.v.progpath,
        '-l',
        fake_lsp_code,
        test_name,
        tostring(timeout),
      },
      handlers = setmetatable({}, {
        __index = function(_t, _method)
          return function(...)
            return vim.rpcrequest(1, 'handler', ...)
          end
        end,
      }),
      workspace_folders = {
        {
          uri = 'file://' .. vim.uv.cwd(),
          name = 'test_folder',
        },
      },
      before_init = function(_params, _config)
        vim.schedule(function()
          vim.rpcrequest(1, 'setup')
        end)
      end,
      on_init = function(client, result)
        _G.TEST_RPC_CLIENT = client
        vim.rpcrequest(1, 'init', result)
      end,
      flags = {
        allow_incremental_sync = options.allow_incremental_sync or false,
        debounce_text_changes = options.debounce_text_changes or 0,
      },
      settings = settings,
      on_exit = function(...)
        vim.rpcnotify(1, 'exit', ...)
      end,
    }
  end, M.fake_lsp_code, M.fake_lsp_logfile, timeout_ms or 1e3)
end

--- @class test.lsp.Config
--- @field test_name string
--- @field timeout_ms? integer
--- @field options? table
--- @field settings? table
---
--- @field on_setup? fun()
--- @field on_init? fun(client: vim.lsp.Client, ...)
--- @field on_handler? fun(...)
--- @field on_exit? fun(code: integer, signal: integer)

--- @param config test.lsp.Config
function M.test_rpc_server(config)
  if config.test_name then
    M.clear_notrace()
    fake_lsp_server_setup(
      config.test_name,
      config.timeout_ms or 1e3,
      config.options,
      config.settings
    )
  end
  local client = setmetatable({}, {
    __index = function(t, name)
      -- Workaround for not being able to yield() inside __index for Lua 5.1 :(
      -- Otherwise I would just return the value here.
      return function(arg1, ...)
        local ismethod = arg1 == t
        return exec_lua(function(...)
          local client = _G.TEST_RPC_CLIENT
          if type(client[name]) == 'function' then
            return client[name](ismethod and client or arg1, ...)
          end
          return client[name]
        end, ...)
      end
    end,
  })
  --- @type integer, integer
  local code, signal
  local function on_request(method, args)
    if method == 'setup' then
      if config.on_setup then
        config.on_setup()
      end
      return NIL
    end
    if method == 'init' then
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
  --  run(on_request, on_notify, nil, 1000)
  run(on_request, on_notify, nil)
  if config.on_exit then
    config.on_exit(code, signal)
  end
  stop()
  if config.test_name then
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end
end

return M
