local helpers = require('test.functional.helpers')(after_each)

local assert_log = helpers.assert_log
local clear = helpers.clear
local buf_lines = helpers.buf_lines
local command = helpers.command
local dedent = helpers.dedent
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local eval = helpers.eval
local matches = helpers.matches
local pcall_err = helpers.pcall_err
local pesc = helpers.pesc
local insert = helpers.insert
local funcs = helpers.funcs
local retry = helpers.retry
local NIL = helpers.NIL
local read_file = require('test.helpers').read_file
local write_file = require('test.helpers').write_file
local isCI = helpers.isCI
local meths = helpers.meths

-- Use these to get access to a coroutine so that I can run async tests and use
-- yield.
local run, stop = helpers.run, helpers.stop

-- TODO(justinmk): hangs on Windows https://github.com/neovim/neovim/pull/11837
if helpers.pending_win32(pending) then return end

-- Fake LSP server.
local fake_lsp_code = 'test/functional/fixtures/fake-lsp-server.lua'
local fake_lsp_logfile = 'Xtest-fake-lsp.log'

teardown(function()
  os.remove(fake_lsp_logfile)
end)

local function clear_notrace()
  -- problem: here be dragons
  -- solution: don't look for dragons to closely
  clear {env={
    NVIM_LUA_NOTRACK="1";
    VIMRUNTIME=os.getenv"VIMRUNTIME";
  }}
end


local function fake_lsp_server_setup(test_name, timeout_ms, options, settings)
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
  ]=], test_name, fake_lsp_code, fake_lsp_logfile, timeout_ms or 1e3, options or {}, settings or {})
end

local function test_rpc_server(config)
  if config.test_name then
    clear_notrace()
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

describe('LSP', function()
  before_each(function()
    clear_notrace()

    -- Run an instance of nvim on the file which contains our "scripts".
    -- Pass TEST_NAME to pick the script.
    local test_name = "basic_init"
    exec_lua([=[
      lsp = require('vim.lsp')
      local test_name, fixture_filename, logfile = ...
      function test__start_client()
        return lsp.start_client {
          cmd_env = {
            NVIM_LOG_FILE = logfile;
          };
          cmd = {
            vim.v.progpath, '-Es', '-u', 'NONE', '--headless',
            "-c", string.format("lua TEST_NAME = %q", test_name),
            "-c", "luafile "..fixture_filename;
          };
          workspace_folders = {{
              uri = 'file://' .. vim.loop.cwd(),
              name = 'test_folder',
          }};
        }
      end
      TEST_CLIENT1 = test__start_client()
    ]=], test_name, fake_lsp_code, fake_lsp_logfile)
  end)

  after_each(function()
    exec_lua("vim.api.nvim_exec_autocmds('VimLeavePre', { modeline = false })")
   -- exec_lua("lsp.stop_all_clients(true)")
  end)

  describe('server_name specified', function()
    it('start_client(), stop_client()', function()
      retry(nil, 4000, function()
        eq(1, exec_lua('return #lsp.get_active_clients()'))
      end)
      eq(2, exec_lua([[
        TEST_CLIENT2 = test__start_client()
        return TEST_CLIENT2
      ]]))
      eq(3, exec_lua([[
        TEST_CLIENT3 = test__start_client()
        return TEST_CLIENT3
      ]]))
      retry(nil, 4000, function()
        eq(3, exec_lua('return #lsp.get_active_clients()'))
      end)

      eq(false, exec_lua('return lsp.get_client_by_id(TEST_CLIENT1) == nil'))
      eq(false, exec_lua('return lsp.get_client_by_id(TEST_CLIENT1).is_stopped()'))
      exec_lua('return lsp.get_client_by_id(TEST_CLIENT1).stop()')
      retry(nil, 4000, function()
        eq(2, exec_lua('return #lsp.get_active_clients()'))
      end)
      eq(true, exec_lua('return lsp.get_client_by_id(TEST_CLIENT1) == nil'))

      exec_lua('lsp.stop_client({TEST_CLIENT2, TEST_CLIENT3})')
      retry(nil, 4000, function()
        eq(0, exec_lua('return #lsp.get_active_clients()'))
      end)
    end)

    it('stop_client() also works on client objects', function()
      exec_lua([[
        TEST_CLIENT2 = test__start_client()
        TEST_CLIENT3 = test__start_client()
      ]])
      retry(nil, 4000, function()
        eq(3, exec_lua('return #lsp.get_active_clients()'))
      end)
      -- Stop all clients.
      exec_lua('lsp.stop_client(lsp.get_active_clients())')
      retry(nil, 4000, function()
        eq(0, exec_lua('return #lsp.get_active_clients()'))
      end)
    end)
  end)

  describe('lsp._cmd_parts test', function()
    local function _cmd_parts(input)
      return exec_lua([[
        lsp = require('vim.lsp')
        return lsp._cmd_parts(...)
      ]], input)
    end
    it('should valid cmd argument', function()
      eq(true, pcall(_cmd_parts, {"nvim"}))
      eq(true, pcall(_cmd_parts, {"nvim", "--head"}))
    end)

    it('should invalid cmd argument', function()
      eq('Error executing lua: .../lsp.lua:0: cmd: expected list, got nvim',
        pcall_err(_cmd_parts, 'nvim'))
      eq('Error executing lua: .../lsp.lua:0: cmd argument: expected string, got number',
        pcall_err(_cmd_parts, {'nvim', 1}))
    end)
  end)
end)

describe('LSP', function()
  describe('basic_init test', function()
    after_each(function()
      stop()
      exec_lua("lsp.stop_client(lsp.get_active_clients(), true)")
      exec_lua("vim.api.nvim_exec_autocmds('VimLeavePre', { modeline = false })")
    end)

    it('should run correctly', function()
      local expected_handlers = {
        {NIL, {}, {method="test", client_id=1}};
      }
      test_rpc_server {
        test_name = "basic_init";
        on_init = function(client, _)
          -- client is a dummy object which will queue up commands to be run
          -- once the server initializes. It can't accept lua callbacks or
          -- other types that may be unserializable for now.
          client.stop()
        end;
        -- If the program timed out, then code will be nil.
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        -- Note that NIL must be used here.
        -- on_handler(err, method, result, client_id)
        on_handler = function(...)
          eq(table.remove(expected_handlers), {...})
        end;
      }
    end)

    it('should fail', function()
      local expected_handlers = {
        {NIL, {}, {method="test", client_id=1}};
      }
      test_rpc_server {
        test_name = "basic_init";
        on_init = function(client)
          client.notify('test')
          client.stop()
        end;
        on_exit = function(code, signal)
          eq(101, code, "exit code")  -- See fake-lsp-server.lua
          eq(0, signal, "exit signal")
          assert_log(pesc([[assert_eq failed: left == "\"shutdown\"", right == "\"test\""]]),
            fake_lsp_logfile)
        end;
        on_handler = function(...)
          eq(table.remove(expected_handlers), {...}, "expected handler")
        end;
      }
    end)

    it('should send didChangeConfiguration after initialize if there are settings', function()
      test_rpc_server({
        test_name = 'basic_init_did_change_configuration',
        on_init = function(client, _)
          client.stop()
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code', fake_lsp_logfile)
          eq(0, signal, 'exit signal', fake_lsp_logfile)
        end,
        settings = {
          dummy = 1,
        },
      })
    end)

    it('should succeed with manual shutdown', function()
      if isCI() then
        pending('hangs the build on CI #14028, re-enable with freeze timeout #14204')
        return
      elseif helpers.skip_fragile(pending) then
        return
      end
      local expected_handlers = {
        {NIL, {}, {method="shutdown", bufnr=1, client_id=1}};
        {NIL, {}, {method="test", client_id=1}};
      }
      test_rpc_server {
        test_name = "basic_init";
        on_init = function(client)
          eq(0, client.server_capabilities().textDocumentSync.change)
          client.request('shutdown')
          client.notify('exit')
          client.stop()
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(...)
          eq(table.remove(expected_handlers), {...}, "expected handler")
        end;
      }
    end)

    it('should detach buffer in response to nvim_buf_detach', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_finish";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
          ]]
          eq(true, exec_lua("return lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID)"))
          eq(true, exec_lua("return lsp.buf_is_attached(BUFFER, TEST_RPC_CLIENT_ID)"))
          exec_lua [[
            vim.api.nvim_command(BUFFER.."bwipeout")
          ]]
        end;
        on_init = function(_client)
          client = _client
          client.notify('finish')
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            exec_lua("return lsp.buf_detach_client(BUFFER, TEST_RPC_CLIENT_ID)")
            eq(false, exec_lua("return lsp.buf_is_attached(BUFFER, TEST_RPC_CLIENT_ID)"))
            client.stop()
          end
        end;
      }
    end)

    it('should fire autocommands on attach and detach', function()
      local client
      test_rpc_server {
        test_name = "basic_init";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_create_autocmd('LspAttach', {
              callback = function(args)
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                vim.g.lsp_attached = client.name
              end,
            })
            vim.api.nvim_create_autocmd('LspDetach', {
              callback = function(args)
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                vim.g.lsp_detached = client.name
              end,
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          eq(true, exec_lua("return lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID)"))
          client.notify('finish')
        end;
        on_handler = function(_, _, ctx)
          if ctx.method == 'finish' then
            eq('basic_init', meths.get_var('lsp_attached'))
            exec_lua("return lsp.buf_detach_client(BUFFER, TEST_RPC_CLIENT_ID)")
            eq('basic_init', meths.get_var('lsp_detached'))
            client.stop()
          end
        end;
      }
    end)

    it('client should return settings via workspace/configuration handler', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, { items = {
              { section = "testSetting1" };
              { section = "testSetting2" };
              { section = "test.Setting3" };
              { section = "test.Setting4" };
          }}, { method="workspace/configuration", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "check_workspace_configuration";
        on_init = function(_client)
          client = _client
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'start' then
            exec_lua([=[
              local client = vim.lsp.get_client_by_id(TEST_RPC_CLIENT_ID)
              client.config.settings = {
                testSetting1 = true;
                testSetting2 = false;
                test = {Setting3 = 'nested' };
            }]=])
          end
          if ctx.method == 'workspace/configuration' then
            local server_result = exec_lua([=[
              local method, params = ...
              return require'vim.lsp.handlers'['workspace/configuration'](err, params, {method=method, client_id=TEST_RPC_CLIENT_ID})]=], ctx.method, result)
            client.notify('workspace/configuration', server_result)
          end
          if ctx.method == 'shutdown' then
            client.stop()
          end
        end;
      }
    end)
    it('workspace/configuration returns NIL per section if client was started without config.settings', function()
      local result = nil
      test_rpc_server {
        test_name = 'basic_init';
        on_init = function(c) c.stop() end,
        on_setup = function()
          result = exec_lua [[
            local result = {
              items = {
                {section = 'foo'},
                {section = 'bar'},
              }
            }
            return vim.lsp.handlers['workspace/configuration'](nil, result, {client_id=TEST_RPC_CLIENT_ID})
          ]]
        end
      }
      eq({ NIL, NIL }, result)
    end)

    it('should verify capabilities sent', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
      }
      test_rpc_server {
        test_name = "basic_check_capabilities";
        on_init = function(client)
          client.stop()
          local full_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq({includeText = false}, client.server_capabilities().textDocumentSync.save)
          eq(false, client.server_capabilities().codeLensProvider)
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(...)
          eq(table.remove(expected_handlers), {...}, "expected handler")
        end;
      }
    end)

    it('BufWritePost sends didSave with bool textDocumentSync.save', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "text_document_sync_save_bool";
        on_init = function(c)
          client = c
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == "start" then
            exec_lua([=[
              BUFFER = vim.api.nvim_get_current_buf()
              lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID)
              vim.api.nvim_exec_autocmds('BufWritePost', { buffer = BUFFER, modeline = false })
            ]=])
          else
            client.stop()
          end
        end;
      }
    end)

    it('saveas sends didOpen if filename changed', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client
      test_rpc_server({
        test_name = 'text_document_save_did_open',
        on_init = function(c)
          client = c
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'start' then
            local tmpfile_old = helpers.tmpname()
            local tmpfile_new = helpers.tmpname()
            os.remove(tmpfile_new)
            exec_lua(
              [=[
              local oldname, newname = ...
              BUFFER = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_name(BUFFER, oldname)
              vim.api.nvim_buf_set_lines(BUFFER, 0, -1, true, {"help me"})
              lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID)
              vim.api.nvim_buf_call(BUFFER, function() vim.cmd('saveas ' .. newname) end)
            ]=],
              tmpfile_old,
              tmpfile_new
            )
          else
            client.stop()
          end
        end,
      })
    end)

    it('BufWritePost sends didSave including text if server capability is set', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "text_document_sync_save_includeText";
        on_init = function(c)
          client = c
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == "start" then
            exec_lua([=[
              BUFFER = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_lines(BUFFER, 0, -1, true, {"help me"})
              lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID)
              vim.api.nvim_exec_autocmds('BufWritePost', { buffer = BUFFER, modeline = false })
            ]=])
          else
            client.stop()
          end
        end;
      }
    end)

    it('client.supports_methods() should validate capabilities', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
      }
      test_rpc_server {
        test_name = "capabilities_for_client_supports_method";
        on_init = function(client)
          client.stop()
          local expected_sync_capabilities = {
            change = 1,
            openClose = true,
            save = { includeText = false },
            willSave = false,
            willSaveWaitUntil = false,
          }
          eq(expected_sync_capabilities, client.server_capabilities().textDocumentSync)
          eq(true, client.server_capabilities().completionProvider)
          eq(true, client.server_capabilities().hoverProvider)
          eq(false, client.server_capabilities().definitionProvider)
          eq(false, client.server_capabilities().renameProvider)
          eq(true, client.server_capabilities().codeLensProvider.resolveProvider)

          -- known methods for resolved capabilities
          eq(true, client.supports_method("textDocument/hover"))
          eq(false, client.supports_method("textDocument/definition"))

          -- unknown methods are assumed to be supported.
          eq(true, client.supports_method("unknown-method"))
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(...)
          eq(table.remove(expected_handlers), {...}, "expected handler")
        end;
      }
    end)

    it('should not call unsupported_method when trying to call an unsupported method', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
      }
      test_rpc_server {
        test_name = "capabilities_for_client_supports_method";
        on_setup = function()
            exec_lua([=[
              BUFFER = vim.api.nvim_get_current_buf()
              lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID)
              vim.lsp.handlers['textDocument/typeDefinition'] = function() end
            ]=])
        end;
        on_init = function(client)
          client.stop()
          exec_lua("vim.lsp.buf.type_definition()")
          exec_lua [[
            vim.api.nvim_command(BUFFER.."bwipeout")
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(...)
          eq(table.remove(expected_handlers), {...}, "expected handler")
        end;
      }
    end)

    it('should not call unsupported_method when no client and trying to call an unsupported method', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
      }
      test_rpc_server {
        test_name = "capabilities_for_client_supports_method";
        on_setup = function()
            exec_lua([=[
              vim.lsp.handlers['textDocument/typeDefinition'] = function() end
            ]=])
        end;
        on_init = function(client)
          client.stop()
          exec_lua("vim.lsp.buf.type_definition()")
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(...)
          eq(table.remove(expected_handlers), {...}, "expected handler")
        end;
      }
    end)

    it('should not forward RequestCancelled to callback', function()
      local expected_handlers = {
        {NIL, {}, {method="finish", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "check_forward_request_cancelled";
        on_init = function(_client)
          _client.request("error_code_test")
          client = _client
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
          eq(0, #expected_handlers, "did not call expected handler")
        end;
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), {err, {}, ctx}, "expected handler")
          if ctx.method == 'finish' then client.stop() end
        end;
      }
    end)

    it('should forward ContentModified to callback', function()
      local expected_handlers = {
        {NIL, {}, {method="finish", client_id=1}};
        {{code = -32801}, NIL, {method = "error_code_test", bufnr=1, client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "check_forward_content_modified";
        on_init = function(_client)
          _client.request("error_code_test")
          client = _client
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
          eq(0, #expected_handlers, "did not call expected handler")
        end;
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), {err, _, ctx}, "expected handler")
          -- if ctx.method == 'error_code_test' then client.notify("finish") end
          if ctx.method ~= 'finish' then client.notify('finish') end
          if ctx.method == 'finish' then client.stop() end
        end;
      }
    end)

    it('should track pending requests to the language server', function()
      local expected_handlers = {
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="slow_request", bufnr=1, client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "check_pending_request_tracked";
        on_init = function(_client)
          client = _client
          client.request("slow_request")
          local request = exec_lua([=[ return TEST_RPC_CLIENT.requests[2] ]=])
          eq("slow_request", request.method)
          eq("pending", request.type)
          client.notify("release")
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
          eq(0, #expected_handlers, "did not call expected handler")
        end;
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), {err, {}, ctx}, "expected handler")
          if ctx.method == 'slow_request' then
            local request = exec_lua([=[ return TEST_RPC_CLIENT.requests[2] ]=])
            eq(NIL, request)
            client.notify("finish")
          end
          if ctx.method == 'finish' then client.stop() end
        end;
      }
    end)

    it('should track cancel requests to the language server', function()
      local expected_handlers = {
        {NIL, {}, {method="finish", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "check_cancel_request_tracked";
        on_init = function(_client)
          client = _client
          client.request("slow_request")
          client.cancel_request(2)
          local request = exec_lua([=[ return TEST_RPC_CLIENT.requests[2] ]=])
          eq("slow_request", request.method)
          eq("cancel", request.type)
          client.notify("release")
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
          eq(0, #expected_handlers, "did not call expected handler")
        end;
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), {err, {}, ctx}, "expected handler")
          local request = exec_lua([=[ return TEST_RPC_CLIENT.requests[2] ]=])
          eq(NIL, request)
          if ctx.method == 'finish' then client.stop() end
        end;
      }
    end)

    it('should clear pending and cancel requests on reply', function()
      local expected_handlers = {
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="slow_request", bufnr=1, client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "check_tracked_requests_cleared";
        on_init = function(_client)
          client = _client
          client.request("slow_request")
          local request = exec_lua([=[ return TEST_RPC_CLIENT.requests[2] ]=])
          eq("slow_request", request.method)
          eq("pending", request.type)
          client.cancel_request(2)
          request = exec_lua([=[ return TEST_RPC_CLIENT.requests[2] ]=])
          eq("slow_request", request.method)
          eq("cancel", request.type)
          client.notify("release")
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
          eq(0, #expected_handlers, "did not call expected handler")
        end;
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), {err, {}, ctx}, "expected handler")
          if ctx.method == 'slow_request' then
            local request = exec_lua([=[ return TEST_RPC_CLIENT.requests[2] ]=])
            eq(NIL, request)
            client.notify("finish")
          end
          if ctx.method == 'finish' then client.stop() end
        end;
      }
    end)

    it('should trigger LspRequest autocmd when requests table changes', function()
      local expected_handlers = {
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="slow_request", bufnr=1, client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "check_tracked_requests_cleared";
        on_init = function(_client)
          command('let g:requests = 0')
          command('autocmd User LspRequest let g:requests+=1')
          client = _client
          client.request("slow_request")
          eq(1, eval('g:requests'))
          client.cancel_request(2)
          eq(2, eval('g:requests'))
          client.notify("release")
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
          eq(0, #expected_handlers, "did not call expected handler")
          eq(3, eval('g:requests'))
        end;
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), {err, {}, ctx}, "expected handler")
          if ctx.method == 'slow_request' then
            client.notify("finish")
          end
          if ctx.method == 'finish' then client.stop() end
        end;
      }
    end)

    it('should not send didOpen if the buffer closes before init', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_finish";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
          eq(1, exec_lua("return TEST_RPC_CLIENT_ID"))
          eq(true, exec_lua("return lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID)"))
          eq(true, exec_lua("return lsp.buf_is_attached(BUFFER, TEST_RPC_CLIENT_ID)"))
          exec_lua [[
            vim.api.nvim_command(BUFFER.."bwipeout")
          ]]
        end;
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          client.notify('finish')
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body sent attaching before init', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(not lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID), "Shouldn't attach twice")
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body sent attaching after init', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange full', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "boop";
              })
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange full with noeol', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_noeol";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
            vim.api.nvim_buf_set_option(BUFFER, 'eol', false)
          ]]
        end;
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "boop";
              })
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange incremental', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_incremental";
        options = {
          allow_incremental_sync = true,
        };
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Incremental")
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "123boop";
              })
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)
    it('should check the body and didChange incremental with debounce', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_incremental";
        options = {
          allow_incremental_sync = true,
          debounce_text_changes = 5
        };
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Incremental")
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "123boop";
              })
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    -- TODO(askhan) we don't support full for now, so we can disable these tests.
    pending('should check the body and didChange incremental normal mode editing', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", bufnr=1, client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_incremental_editing";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Incremental")
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            helpers.command("normal! 1Go")
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange full with 2 changes', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_multi";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "321";
              })
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "boop";
              })
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange full lifecycle', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_multi_and_close";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result,ctx)
          if ctx.method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "321";
              })
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "boop";
              })
              vim.api.nvim_command(BUFFER.."bwipeout")
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)
  end)

  describe("parsing tests", function()
    it('should handle invalid content-length correctly', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "invalid_header";
        on_setup = function()
        end;
        on_init = function(_client)
          client = _client
          client.stop(true)
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
        end;
      }
    end)

    it('should not trim vim.NIL from the end of a list', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="finish", client_id=1}};
        {NIL,{
          arguments = { "EXTRACT_METHOD", {metadata = {}}, 3, 0, 6123, NIL },
          command = "refactor.perform",
          title = "EXTRACT_METHOD"
        },  {method="workspace/executeCommand", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "decode_nil";
        on_setup = function()
          exec_lua [[
            BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(BUFFER, 0, -1, false, {
              "testing";
              "123";
            })
          ]]
        end;
        on_init = function(_client)
          client = _client
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'finish' then
            client.stop()
          end
        end;
      }
    end)
  end)
end)

describe('LSP', function()
  before_each(function()
    clear_notrace()
  end)

  local function make_edit(y_0, x_0, y_1, x_1, text)
    return {
      range = {
        start = { line = y_0, character = x_0 };
        ["end"] = { line = y_1, character = x_1 };
      };
      newText = type(text) == 'table' and table.concat(text, '\n') or (text or "");
    }
  end

  describe('apply_text_edits', function()
    before_each(function()
      insert(dedent([[
        First line of text
        Second line of text
        Third line of text
        Fourth line of text
        å å ɧ 汉语 ↥ 🤦 🦄]]))
    end)
    it('applies simple edits', function()
      local edits = {
        make_edit(0, 0, 0, 0, {"123"});
        make_edit(1, 0, 1, 1, {"2"});
        make_edit(2, 0, 2, 2, {"3"});
        make_edit(3, 2, 3, 4, {""});
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
      eq({
        '123First line of text';
        '2econd line of text';
        '3ird line of text';
        'Foth line of text';
        'å å ɧ 汉语 ↥ 🤦 🦄';
      }, buf_lines(1))
    end)
    it('applies complex edits', function()
      local edits = {
        make_edit(0, 0, 0, 0, {"", "12"});
        make_edit(0, 0, 0, 0, {"3", "foo"});
        make_edit(0, 1, 0, 1, {"bar", "123"});
        make_edit(0, #"First ", 0, #"First line of text", {"guy"});
        make_edit(1, 0, 1, #'Second', {"baz"});
        make_edit(2, #'Th', 2, #"Third", {"e next"});
        make_edit(3, #'', 3, #"Fourth", {"another line of text", "before this"});
        make_edit(3, #'Fourth', 3, #"Fourth line of text", {"!"});
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
      eq({
        '';
        '123';
        'fooFbar';
        '123irst guy';
        'baz line of text';
        'The next line of text';
        'another line of text';
        'before this!';
        'å å ɧ 汉语 ↥ 🤦 🦄';
      }, buf_lines(1))
    end)
    it('applies complex edits (reversed range)', function()
      local edits = {
        make_edit(0, 0, 0, 0, {"", "12"});
        make_edit(0, 0, 0, 0, {"3", "foo"});
        make_edit(0, 1, 0, 1, {"bar", "123"});
        make_edit(0, #"First line of text", 0, #"First ", {"guy"});
        make_edit(1, #'Second', 1, 0, {"baz"});
        make_edit(2, #"Third", 2, #'Th', {"e next"});
        make_edit(3, #"Fourth", 3, #'', {"another line of text", "before this"});
        make_edit(3, #"Fourth line of text", 3, #'Fourth', {"!"});
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
      eq({
        '';
        '123';
        'fooFbar';
        '123irst guy';
        'baz line of text';
        'The next line of text';
        'another line of text';
        'before this!';
        'å å ɧ 汉语 ↥ 🤦 🦄';
      }, buf_lines(1))
    end)
    it('applies non-ASCII characters edits', function()
      local edits = {
        make_edit(4, 3, 4, 4, {"ä"});
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
      eq({
        'First line of text';
        'Second line of text';
        'Third line of text';
        'Fourth line of text';
        'å ä ɧ 汉语 ↥ 🤦 🦄';
      }, buf_lines(1))
    end)
    it('applies text edits at the end of the document', function()
      local edits = {
        make_edit(5, 0, 5, 0, "foobar");
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
      eq({
        'First line of text';
        'Second line of text';
        'Third line of text';
        'Fourth line of text';
        'å å ɧ 汉语 ↥ 🤦 🦄';
        'foobar';
      }, buf_lines(1))
    end)
    it('applies multiple text edits at the end of the document', function()
      local edits = {
        make_edit(4, 0, 5, 0, "");
        make_edit(5, 0, 5, 0, "foobar");
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
      eq({
        'First line of text';
        'Second line of text';
        'Third line of text';
        'Fourth line of text';
        'foobar';
      }, buf_lines(1))
    end)

    describe('cursor position', function()
      it('don\'t fix the cursor if the range contains the cursor', function()
        funcs.nvim_win_set_cursor(0, { 2, 6 })
        local edits = {
          make_edit(1, 0, 1, 19, 'Second line of text')
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({
          'First line of text';
          'Second line of text';
          'Third line of text';
          'Fourth line of text';
          'å å ɧ 汉语 ↥ 🤦 🦄';
        }, buf_lines(1))
        eq({ 2, 6 }, funcs.nvim_win_get_cursor(0))
      end)

      it('fix the cursor to the valid col if the content was removed', function()
        funcs.nvim_win_set_cursor(0, { 2, 6 })
        local edits = {
          make_edit(1, 0, 1, 6, ''),
          make_edit(1, 6, 1, 19, '')
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({
          'First line of text';
          '';
          'Third line of text';
          'Fourth line of text';
          'å å ɧ 汉语 ↥ 🤦 🦄';
        }, buf_lines(1))
        eq({ 2, 0 }, funcs.nvim_win_get_cursor(0))
      end)

      it('fix the cursor to the valid row if the content was removed', function()
        funcs.nvim_win_set_cursor(0, { 2, 6 })
        local edits = {
          make_edit(1, 0, 1, 6, ''),
          make_edit(0, 18, 5, 0, '')
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({
          'First line of text';
        }, buf_lines(1))
        eq({ 1, 6 }, funcs.nvim_win_get_cursor(0))
      end)

      it('fix the cursor row', function()
        funcs.nvim_win_set_cursor(0, { 3, 0 })
        local edits = {
          make_edit(1, 0, 2, 0, '')
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({
          'First line of text';
          'Third line of text';
          'Fourth line of text';
          'å å ɧ 汉语 ↥ 🤦 🦄';
        }, buf_lines(1))
        eq({ 2, 0 }, funcs.nvim_win_get_cursor(0))
      end)

      it('fix the cursor col', function()
        funcs.nvim_win_set_cursor(0, { 2, 11 })
        local edits = {
          make_edit(1, 7, 1, 11, '')
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({
          'First line of text';
          'Second  of text';
          'Third line of text';
          'Fourth line of text';
          'å å ɧ 汉语 ↥ 🤦 🦄';
        }, buf_lines(1))
        eq({ 2, 7 }, funcs.nvim_win_get_cursor(0))
      end)

      it('fix the cursor row and col', function()
        funcs.nvim_win_set_cursor(0, { 2, 12 })
        local edits = {
          make_edit(0, 11, 1, 12, '')
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({
          'First line of text';
          'Third line of text';
          'Fourth line of text';
          'å å ɧ 汉语 ↥ 🤦 🦄';
        }, buf_lines(1))
        eq({ 1, 11 }, funcs.nvim_win_get_cursor(0))
      end)
    end)

    describe('with LSP end line after what Vim considers to be the end line', function()
      it('applies edits when the last linebreak is considered a new line', function()
        local edits = {
          make_edit(0, 0, 5, 0, {"All replaced"});
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({'All replaced'}, buf_lines(1))
      end)
      it('applies edits when the end line is 2 larger than vim\'s', function()
        local edits = {
          make_edit(0, 0, 6, 0, {"All replaced"});
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({'All replaced'}, buf_lines(1))
      end)
      it('applies edits with a column offset', function()
        local edits = {
          make_edit(0, 0, 5, 2, {"All replaced"});
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1, "utf-16")
        eq({'All replaced'}, buf_lines(1))
      end)
    end)
  end)

  describe('apply_text_document_edit', function()
    local target_bufnr
    local text_document_edit = function(editVersion)
      return {
        edits = {
          make_edit(0, 0, 0, 3, "First ↥ 🤦 🦄")
        },
        textDocument = {
          uri = "file:///fake/uri";
          version = editVersion
        }
      }
    end
    before_each(function()
      target_bufnr = exec_lua [[
        local bufnr = vim.uri_to_bufnr("file:///fake/uri")
        local lines = {"1st line of text", "2nd line of 语text"}
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      ]]
    end)
    it('correctly goes ahead with the edit if all is normal', function()
      exec_lua("vim.lsp.util.apply_text_document_edit(..., nil, 'utf-16')", text_document_edit(5))
      eq({
        'First ↥ 🤦 🦄 line of text';
        '2nd line of 语text';
      }, buf_lines(target_bufnr))
    end)
    it('always accepts edit with version = 0', function()
      exec_lua([[
        local args = {...}
        local bufnr = select(1, ...)
        local text_edit = select(2, ...)
        vim.lsp.util.buf_versions[bufnr] = 10
        vim.lsp.util.apply_text_document_edit(text_edit, nil, 'utf-16')
      ]], target_bufnr, text_document_edit(0))
      eq({
        'First ↥ 🤦 🦄 line of text';
        '2nd line of 语text';
      }, buf_lines(target_bufnr))
    end)
    it('skips the edit if the version of the edit is behind the local buffer ', function()
      local apply_edit_mocking_current_version = function(edit, versionedBuf)
        exec_lua([[
          local args = {...}
          local versionedBuf = args[2]
          vim.lsp.util.buf_versions[versionedBuf.bufnr] = versionedBuf.currentVersion
          vim.lsp.util.apply_text_document_edit(args[1], nil, 'utf-16')
        ]], edit, versionedBuf)
      end

      local baseText = {
        '1st line of text';
        '2nd line of 语text';
      }

      eq(baseText, buf_lines(target_bufnr))

      -- Apply an edit for an old version, should skip
      apply_edit_mocking_current_version(text_document_edit(2), {currentVersion=7; bufnr=target_bufnr})
      eq(baseText, buf_lines(target_bufnr)) -- no change

      -- Sanity check that next version to current does apply change
      apply_edit_mocking_current_version(text_document_edit(8), {currentVersion=7; bufnr=target_bufnr})
      eq({
        'First ↥ 🤦 🦄 line of text';
        '2nd line of 语text';
      }, buf_lines(target_bufnr))
    end)
  end)

  describe('workspace_apply_edit', function()
    it('workspace/applyEdit returns ApplyWorkspaceEditResponse', function()
      local expected_handlers = {
        {NIL, {}, {method="test", client_id=1}};
      }
      test_rpc_server {
        test_name = "basic_init";
        on_init = function(client, _)
          client.stop()
        end;
        -- If the program timed out, then code will be nil.
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        -- Note that NIL must be used here.
        -- on_handler(err, method, result, client_id)
        on_handler = function(...)
          local expected = {
            applied = true;
            failureReason = nil;
          }
          eq(expected, exec_lua [[
            local apply_edit = {
              label = nil;
              edit = {};
            }
            return vim.lsp.handlers['workspace/applyEdit'](nil, apply_edit, {client_id = TEST_RPC_CLIENT_ID})
          ]])
          eq(table.remove(expected_handlers), {...})
        end;
      }
    end)
  end)

  describe('apply_workspace_edit', function()
    local replace_line_edit = function(row, new_line, editVersion)
      return {
        edits = {
          -- NOTE: This is a hack if you have a line longer than 1000 it won't replace it
          make_edit(row, 0, row, 1000, new_line)
        },
        textDocument = {
          uri = "file:///fake/uri";
          version = editVersion
        }
      }
    end

    -- Some servers send all the edits separately, but with the same version.
    -- We should not stop applying the edits
    local make_workspace_edit = function(changes)
      return {
        documentChanges = changes
      }
    end

    local target_bufnr, changedtick = nil, nil

    before_each(function()
      local ret = exec_lua [[
        local bufnr = vim.uri_to_bufnr("file:///fake/uri")
        local lines = {
          "Original Line #1",
          "Original Line #2"
        }

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

        local update_changed_tick = function()
          vim.lsp.util.buf_versions[bufnr] = vim.api.nvim_buf_get_var(bufnr, 'changedtick')
        end

        update_changed_tick()
        vim.api.nvim_buf_attach(bufnr, false, {
          on_changedtick = function()
            update_changed_tick()
          end
        })

        return {bufnr, vim.api.nvim_buf_get_var(bufnr, 'changedtick')}
      ]]

      target_bufnr = ret[1]
      changedtick = ret[2]
    end)

    it('apply_workspace_edit applies a single edit', function()
      local new_lines = {
        "First Line",
      }

      local edits = {}
      for row, line in ipairs(new_lines) do
        table.insert(edits, replace_line_edit(row - 1, line, changedtick))
      end

      eq({
        "First Line",
        "Original Line #2",
      }, exec_lua([[
        local args = {...}
        local workspace_edits = args[1]
        local target_bufnr = args[2]

        vim.lsp.util.apply_workspace_edit(workspace_edits, 'utf-16')

        return vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false)
      ]], make_workspace_edit(edits), target_bufnr))
    end)

    it('apply_workspace_edit applies multiple edits', function()
      local new_lines = {
        "First Line",
        "Second Line",
      }

      local edits = {}
      for row, line in ipairs(new_lines) do
        table.insert(edits, replace_line_edit(row - 1, line, changedtick))
      end

      eq(new_lines, exec_lua([[
        local args = {...}
        local workspace_edits = args[1]
        local target_bufnr = args[2]

        vim.lsp.util.apply_workspace_edit(workspace_edits, 'utf-16')

        return vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false)
      ]], make_workspace_edit(edits), target_bufnr))
    end)
    it('Supports file creation with CreateFile payload', function()
      local tmpfile = helpers.tmpname()
      os.remove(tmpfile) -- Should not exist, only interested in a tmpname
      local uri = exec_lua('return vim.uri_from_fname(...)', tmpfile)
      local edit = {
        documentChanges = {
          {
            kind = 'create',
            uri = uri,
          },
        }
      }
      exec_lua('vim.lsp.util.apply_workspace_edit(...)', edit, 'utf-16')
      eq(true, exec_lua('return vim.loop.fs_stat(...) ~= nil', tmpfile))
    end)
    it('createFile does not touch file if it exists and ignoreIfExists is set', function()
      local tmpfile = helpers.tmpname()
      write_file(tmpfile, 'Dummy content')
      local uri = exec_lua('return vim.uri_from_fname(...)', tmpfile)
      local edit = {
        documentChanges = {
          {
            kind = 'create',
            uri = uri,
            options = {
              ignoreIfExists = true,
            },
          },
        }
      }
      exec_lua('vim.lsp.util.apply_workspace_edit(...)', edit, 'utf-16')
      eq(true, exec_lua('return vim.loop.fs_stat(...) ~= nil', tmpfile))
      eq('Dummy content', read_file(tmpfile))
    end)
    it('createFile overrides file if overwrite is set', function()
      local tmpfile = helpers.tmpname()
      write_file(tmpfile, 'Dummy content')
      local uri = exec_lua('return vim.uri_from_fname(...)', tmpfile)
      local edit = {
        documentChanges = {
          {
            kind = 'create',
            uri = uri,
            options = {
              overwrite = true,
              ignoreIfExists = true, -- overwrite must win over ignoreIfExists
            },
          },
        }
      }
      exec_lua('vim.lsp.util.apply_workspace_edit(...)', edit, 'utf-16')
      eq(true, exec_lua('return vim.loop.fs_stat(...) ~= nil', tmpfile))
      eq('', read_file(tmpfile))
    end)
    it('DeleteFile delete file and buffer', function()
      local tmpfile = helpers.tmpname()
      write_file(tmpfile, 'Be gone')
      local uri = exec_lua([[
        local fname = select(1, ...)
        local bufnr = vim.fn.bufadd(fname)
        vim.fn.bufload(bufnr)
        return vim.uri_from_fname(fname)
      ]], tmpfile)
      local edit = {
        documentChanges = {
          {
            kind = 'delete',
            uri = uri,
          }
        }
      }
      eq(true, pcall(exec_lua, 'vim.lsp.util.apply_workspace_edit(...)', edit, 'utf-16'))
      eq(false, exec_lua('return vim.loop.fs_stat(...) ~= nil', tmpfile))
      eq(false, exec_lua('return vim.api.nvim_buf_is_loaded(vim.fn.bufadd(...))', tmpfile))
    end)
    it('DeleteFile fails if file does not exist and ignoreIfNotExists is false', function()
      local tmpfile = helpers.tmpname()
      os.remove(tmpfile)
      local uri = exec_lua('return vim.uri_from_fname(...)', tmpfile)
      local edit = {
        documentChanges = {
          {
            kind = 'delete',
            uri = uri,
            options = {
              ignoreIfNotExists = false,
            }
          }
        }
      }
      eq(false, pcall(exec_lua, 'vim.lsp.util.apply_workspace_edit(...)', edit))
      eq(false, exec_lua('return vim.loop.fs_stat(...) ~= nil', tmpfile))
    end)
  end)

  describe('completion_list_to_complete_items', function()
    -- Completion option precedence:
    -- textEdit.newText > insertText > label
    -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
    it('should choose right completion option', function ()
      local prefix = 'foo'
      local completion_list = {
        -- resolves into label
        { label='foobar', sortText="a" },
        { label='foobar', sortText="b", textEdit={} },
        -- resolves into insertText
        { label='foocar', sortText="c", insertText='foobar' },
        { label='foocar', sortText="d", insertText='foobar', textEdit={} },
        -- resolves into textEdit.newText
        { label='foocar', sortText="e", insertText='foodar', textEdit={newText='foobar'} },
        { label='foocar', sortText="f", textEdit={newText='foobar'} },
        -- real-world snippet text
        { label='foocar', sortText="g", insertText='foodar', insertTextFormat=2, textEdit={newText='foobar(${1:place holder}, ${2:more ...holder{\\}})'} },
        { label='foocar', sortText="h", insertText='foodar(${1:var1} typ1, ${2:var2} *typ2) {$0\\}', insertTextFormat=2, textEdit={} },
        -- nested snippet tokens
        { label='foocar', sortText="i", insertText='foodar(${1:var1 ${2|typ2,typ3|} ${3:tail}}) {$0\\}', insertTextFormat=2, textEdit={} },
        -- braced tabstop
        { label='foocar', sortText="j", insertText='foodar()${0}', insertTextFormat=2, textEdit={} },
        -- plain text
        { label='foocar', sortText="k", insertText='foodar(${1:var1})', insertTextFormat=1, textEdit={} },
      }
      local completion_list_items = {items=completion_list}
      local expected = {
        { abbr = 'foobar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label = 'foobar', sortText="a" } } } } },
        { abbr = 'foobar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foobar', sortText="b", textEdit={} } } }  } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="c", insertText='foobar' } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="d", insertText='foobar', textEdit={} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="e", insertText='foodar', textEdit={newText='foobar'} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="f", textEdit={newText='foobar'} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar(place holder, more ...holder{})', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="g", insertText='foodar', insertTextFormat=2, textEdit={newText='foobar(${1:place holder}, ${2:more ...holder{\\}})'} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foodar(var1 typ1, var2 *typ2) {}', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="h", insertText='foodar(${1:var1} typ1, ${2:var2} *typ2) {$0\\}', insertTextFormat=2, textEdit={} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foodar(var1 typ2 tail) {}', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="i", insertText='foodar(${1:var1 ${2|typ2,typ3|} ${3:tail}}) {$0\\}', insertTextFormat=2, textEdit={} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foodar()', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="j", insertText='foodar()${0}', insertTextFormat=2, textEdit={} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foodar(${1:var1})', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="k", insertText='foodar(${1:var1})', insertTextFormat=1, textEdit={} } } } } },
      }

      eq(expected, exec_lua([[return vim.lsp.util.text_document_completion_list_to_complete_items(...)]], completion_list, prefix))
      eq(expected, exec_lua([[return vim.lsp.util.text_document_completion_list_to_complete_items(...)]], completion_list_items, prefix))
      eq({}, exec_lua([[return vim.lsp.util.text_document_completion_list_to_complete_items(...)]], {}, prefix))
    end)
  end)

  describe('lsp.util.rename', function()
    it('Can rename an existing file', function()
      local old = helpers.tmpname()
      write_file(old, 'Test content')
      local new = helpers.tmpname()
      os.remove(new)  -- only reserve the name, file must not exist for the test scenario
      local lines = exec_lua([[
        local old = select(1, ...)
        local new = select(2, ...)
        vim.lsp.util.rename(old, new)

        -- after rename the target file must have the contents of the source file
        local bufnr = vim.fn.bufadd(new)
        vim.fn.bufload(new)
        return vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
      ]], old, new)
      eq({'Test content'}, lines)
      local exists = exec_lua('return vim.loop.fs_stat(...) ~= nil', old)
      eq(false, exists)
      exists = exec_lua('return vim.loop.fs_stat(...) ~= nil', new)
      eq(true, exists)
      os.remove(new)
    end)
    it('Does not rename file if target exists and ignoreIfExists is set or overwrite is false', function()
      local old = helpers.tmpname()
      write_file(old, 'Old File')
      local new = helpers.tmpname()
      write_file(new, 'New file')

      exec_lua([[
        local old = select(1, ...)
        local new = select(2, ...)

        vim.lsp.util.rename(old, new, { ignoreIfExists = true })
      ]], old, new)

      eq(true, exec_lua('return vim.loop.fs_stat(...) ~= nil', old))
      eq('New file', read_file(new))

      exec_lua([[
        local old = select(1, ...)
        local new = select(2, ...)

        vim.lsp.util.rename(old, new, { overwrite = false })
      ]], old, new)

      eq(true, exec_lua('return vim.loop.fs_stat(...) ~= nil', old))
      eq('New file', read_file(new))
    end)
    it('Does override target if overwrite is true', function()
      local old = helpers.tmpname()
      write_file(old, 'Old file')
      local new = helpers.tmpname()
      write_file(new, 'New file')
      exec_lua([[
        local old = select(1, ...)
        local new = select(2, ...)

        vim.lsp.util.rename(old, new, { overwrite = true })
      ]], old, new)

      eq(false, exec_lua('return vim.loop.fs_stat(...) ~= nil', old))
      eq(true, exec_lua('return vim.loop.fs_stat(...) ~= nil', new))
      eq('Old file\n', read_file(new))
    end)
  end)

  describe('lsp.util.locations_to_items', function()
    it('Convert Location[] to items', function()
      local expected = {
        {
          filename = '/fake/uri',
          lnum = 1,
          col = 3,
          text = 'testing'
        },
      }
      local actual = exec_lua [[
        local bufnr = vim.uri_to_bufnr("file:///fake/uri")
        local lines = {"testing", "123"}
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        local locations = {
          {
            uri = 'file:///fake/uri',
            range = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            }
          },
        }
        return vim.lsp.util.locations_to_items(locations, 'utf-16')
      ]]
      eq(expected, actual)
    end)
    it('Convert LocationLink[] to items', function()
      local expected = {
        {
          filename = '/fake/uri',
          lnum = 1,
          col = 3,
          text = 'testing'
        },
      }
      local actual = exec_lua [[
        local bufnr = vim.uri_to_bufnr("file:///fake/uri")
        local lines = {"testing", "123"}
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        local locations = {
          {
            targetUri = vim.uri_from_bufnr(bufnr),
            targetRange = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            },
            targetSelectionRange = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            }
          },
        }
        return vim.lsp.util.locations_to_items(locations, 'utf-16')
      ]]
      eq(expected, actual)
    end)
  end)
  describe('lsp.util.symbols_to_items', function()
    describe('convert DocumentSymbol[] to items', function()
      it('DocumentSymbol has children', function()
        local expected = {
          {
            col = 1,
            filename = '',
            kind = 'File',
            lnum = 2,
            text = '[File] TestA'
          },
          {
            col = 1,
            filename = '',
            kind = 'Module',
            lnum = 4,
            text = '[Module] TestB'
          },
          {
            col = 1,
            filename = '',
            kind = 'Namespace',
            lnum = 6,
            text = '[Namespace] TestC'
          }
        }
        eq(expected, exec_lua [[
          local doc_syms = {
            {
              deprecated = false,
              detail = "A",
              kind = 1,
              name = "TestA",
              range = {
                start = {
                  character = 0,
                  line = 1
                },
                ["end"] = {
                  character = 0,
                  line = 2
                }
              },
              selectionRange = {
                start = {
                  character = 0,
                  line = 1
                },
                ["end"] = {
                  character = 4,
                  line = 1
                }
              },
              children = {
                {
                  children = {},
                  deprecated = false,
                  detail = "B",
                  kind = 2,
                  name = "TestB",
                  range = {
                    start = {
                      character = 0,
                      line = 3
                    },
                    ["end"] = {
                      character = 0,
                      line = 4
                    }
                  },
                  selectionRange = {
                    start = {
                      character = 0,
                      line = 3
                    },
                    ["end"] = {
                      character = 4,
                      line = 3
                    }
                  }
                }
              }
            },
            {
              deprecated = false,
              detail = "C",
              kind = 3,
              name = "TestC",
              range = {
                start = {
                  character = 0,
                  line = 5
                },
                ["end"] = {
                  character = 0,
                  line = 6
                }
              },
              selectionRange = {
                start = {
                  character = 0,
                  line = 5
                },
                ["end"] = {
                  character = 4,
                  line = 5
                }
              }
            }
          }
          return vim.lsp.util.symbols_to_items(doc_syms, nil)
        ]])
      end)
      it('DocumentSymbol has no children', function()
        local expected = {
          {
            col = 1,
            filename = '',
            kind = 'File',
            lnum = 2,
            text = '[File] TestA'
          },
          {
            col = 1,
            filename = '',
            kind = 'Namespace',
            lnum = 6,
            text = '[Namespace] TestC'
          }
        }
        eq(expected, exec_lua [[
          local doc_syms = {
            {
              deprecated = false,
              detail = "A",
              kind = 1,
              name = "TestA",
              range = {
                start = {
                  character = 0,
                  line = 1
                },
                ["end"] = {
                  character = 0,
                  line = 2
                }
              },
              selectionRange = {
                start = {
                  character = 0,
                  line = 1
                },
                ["end"] = {
                  character = 4,
                  line = 1
                }
              },
            },
            {
              deprecated = false,
              detail = "C",
              kind = 3,
              name = "TestC",
              range = {
                start = {
                  character = 0,
                  line = 5
                },
                ["end"] = {
                  character = 0,
                  line = 6
                }
              },
              selectionRange = {
                start = {
                  character = 0,
                  line = 5
                },
                ["end"] = {
                  character = 4,
                  line = 5
                }
              }
            }
          }
          return vim.lsp.util.symbols_to_items(doc_syms, nil)
        ]])
      end)
    end)
    it('convert SymbolInformation[] to items', function()
        local expected = {
          {
            col = 1,
            filename = '/test_a',
            kind = 'File',
            lnum = 2,
            text = '[File] TestA'
          },
          {
            col = 1,
            filename = '/test_b',
            kind = 'Module',
            lnum = 4,
            text = '[Module] TestB'
          }
        }
        eq(expected, exec_lua [[
          local sym_info = {
            {
              deprecated = false,
              kind = 1,
              name = "TestA",
              location = {
                range = {
                  start = {
                    character = 0,
                    line = 1
                  },
                  ["end"] = {
                    character = 0,
                    line = 2
                  }
                },
                uri = "file:///test_a"
              },
              contanerName = "TestAContainer"
            },
            {
              deprecated = false,
              kind = 2,
              name = "TestB",
              location = {
                range = {
                  start = {
                    character = 0,
                    line = 3
                  },
                  ["end"] = {
                    character = 0,
                    line = 4
                  }
                },
                uri = "file:///test_b"
              },
              contanerName = "TestBContainer"
            }
          }
          return vim.lsp.util.symbols_to_items(sym_info, nil)
        ]])
    end)
  end)

  describe('lsp.util._get_completion_item_kind_name', function()
    it('returns the name specified by protocol', function()
      eq("Text", exec_lua("return vim.lsp.util._get_completion_item_kind_name(1)"))
      eq("TypeParameter", exec_lua("return vim.lsp.util._get_completion_item_kind_name(25)"))
    end)
    it('returns the name not specified by protocol', function()
      eq("Unknown", exec_lua("return vim.lsp.util._get_completion_item_kind_name(nil)"))
      eq("Unknown", exec_lua("return vim.lsp.util._get_completion_item_kind_name(vim.NIL)"))
      eq("Unknown", exec_lua("return vim.lsp.util._get_completion_item_kind_name(1000)"))
    end)
  end)

  describe('lsp.util._get_symbol_kind_name', function()
    it('returns the name specified by protocol', function()
      eq("File", exec_lua("return vim.lsp.util._get_symbol_kind_name(1)"))
      eq("TypeParameter", exec_lua("return vim.lsp.util._get_symbol_kind_name(26)"))
    end)
    it('returns the name not specified by protocol', function()
      eq("Unknown", exec_lua("return vim.lsp.util._get_symbol_kind_name(nil)"))
      eq("Unknown", exec_lua("return vim.lsp.util._get_symbol_kind_name(vim.NIL)"))
      eq("Unknown", exec_lua("return vim.lsp.util._get_symbol_kind_name(1000)"))
    end)
  end)

  describe('lsp.util.jump_to_location', function()
    local target_bufnr

    before_each(function()
      target_bufnr = exec_lua [[
        local bufnr = vim.uri_to_bufnr("file:///fake/uri")
        local lines = {"1st line of text", "å å ɧ 汉语 ↥ 🤦 🦄"}
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      ]]
    end)

    local location = function(start_line, start_char, end_line, end_char)
      return {
        uri = "file:///fake/uri",
        range = {
          start = { line = start_line, character = start_char },
          ["end"] = { line = end_line, character = end_char },
        },
      }
    end

    local jump = function(msg)
      eq(true, exec_lua('return vim.lsp.util.jump_to_location(...)', msg, "utf-16"))
      eq(target_bufnr, exec_lua[[return vim.fn.bufnr('%')]])
      return {
        line = exec_lua[[return vim.fn.line('.')]],
        col = exec_lua[[return vim.fn.col('.')]],
      }
    end

    it('jumps to a Location', function()
      local pos = jump(location(0, 9, 0, 9))
      eq(1, pos.line)
      eq(10, pos.col)
    end)

    it('jumps to a LocationLink', function()
      local pos = jump({
          targetUri = "file:///fake/uri",
          targetSelectionRange = {
            start = { line = 0, character = 4 },
            ["end"] = { line = 0, character = 4 },
          },
          targetRange = {
            start = { line = 1, character = 5 },
            ["end"] = { line = 1, character = 5 },
          },
        })
      eq(1, pos.line)
      eq(5, pos.col)
    end)

    it('jumps to the correct multibyte column', function()
      local pos = jump(location(1, 2, 1, 2))
      eq(2, pos.line)
      eq(4, pos.col)
      eq('å', exec_lua[[return vim.fn.expand('<cword>')]])
    end)

    it('adds current position to jumplist before jumping', function()
      funcs.nvim_win_set_buf(0, target_bufnr)
      local mark = funcs.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 1, 0 }, mark)

      funcs.nvim_win_set_cursor(0, {2, 3})
      jump(location(0, 9, 0, 9))

      mark = funcs.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 2, 3 }, mark)
    end)
  end)

  describe('lsp.util._make_floating_popup_size', function()
    before_each(function()
      exec_lua [[ contents =
      {"text tαxt txtα tex",
      "text tααt tααt text",
      "text tαxt tαxt"}
      ]]
    end)

    it('calculates size correctly', function()
      eq({19,3}, exec_lua[[ return {vim.lsp.util._make_floating_popup_size(contents)} ]])
    end)

    it('calculates size correctly with wrapping', function()
      eq({15,5}, exec_lua[[ return {vim.lsp.util._make_floating_popup_size(contents,{width = 15, wrap_at = 14})} ]])
    end)
  end)

  describe('lsp.util.trim.trim_empty_lines', function()
    it('properly trims empty lines', function()
      eq({{"foo", "bar"}}, exec_lua[[ return vim.lsp.util.trim_empty_lines({{ "foo", "bar" },  nil}) ]])
    end)
  end)

  describe('lsp.util.convert_signature_help_to_markdown_lines', function()
    it('can handle negative activeSignature', function()
      local result = exec_lua[[
        local signature_help = {
          activeParameter = 0,
          activeSignature = -1,
          signatures = {
            {
              documentation = "",
              label = "TestEntity.TestEntity()",
              parameters = {}
            },
          }
        }
        return vim.lsp.util.convert_signature_help_to_markdown_lines(signature_help, 'cs', {','})
      ]]
      local expected = {'```cs', 'TestEntity.TestEntity()', '```', ''}
      eq(expected, result)
    end)
  end)

  describe('lsp.util.get_effective_tabstop', function()
    local function test_tabstop(tabsize, shiftwidth)
      exec_lua(string.format([[
        vim.api.nvim_buf_set_option(0, 'shiftwidth', %d)
        vim.api.nvim_buf_set_option(0, 'tabstop', 2)
      ]], shiftwidth))
      eq(tabsize, exec_lua('return vim.lsp.util.get_effective_tabstop()'))
    end

    it('with shiftwidth = 1', function() test_tabstop(1, 1) end)
    it('with shiftwidth = 0', function() test_tabstop(2, 0) end)
  end)

  describe('vim.lsp.buf.outgoing_calls', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua([=[
        require'vim.lsp.handlers'['callHierarchy/outgoingCalls'](nil, nil, {}, nil)
        return #vim.fn.getqflist()
      ]=])
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right caller', function()
      local qflist = exec_lua([=[
        local rust_analyzer_response = { {
          fromRanges = { {
            ['end'] = {
              character = 7,
              line = 3
            },
            start = {
              character = 4,
              line = 3
            }
          } },
          to = {
            detail = "fn foo()",
            kind = 12,
            name = "foo",
            range = {
              ['end'] = {
                character = 11,
                line = 0
              },
              start = {
                character = 0,
                line = 0
              }
            },
            selectionRange = {
              ['end'] = {
                character = 6,
                line = 0
              },
              start = {
              character = 3,
              line = 0
              }
            },
            uri = "file:///src/main.rs"
          }
        } }
        local handler = require'vim.lsp.handlers'['callHierarchy/outgoingCalls']
        handler(nil, rust_analyzer_response, {})
        return vim.fn.getqflist()
      ]=])

      local expected = { {
        bufnr = 2,
        col = 5,
        end_col = 0,
        lnum = 4,
        end_lnum = 0,
        module = "",
        nr = 0,
        pattern = "",
        text = "foo",
        type = "",
        valid = 1,
        vcol = 0
      } }

      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.incoming_calls', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua([=[
        require'vim.lsp.handlers'['callHierarchy/incomingCalls'](nil, nil, {})
        return #vim.fn.getqflist()
      ]=])
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right callee', function()
      local qflist = exec_lua([=[
        local rust_analyzer_response = { {
          from = {
            detail = "fn main()",
            kind = 12,
            name = "main",
            range = {
              ['end'] = {
                character = 1,
                line = 4
              },
              start = {
                character = 0,
                line = 2
              }
            },
            selectionRange = {
              ['end'] = {
                character = 7,
                line = 2
              },
              start = {
                character = 3,
                line = 2
              }
            },
            uri = "file:///src/main.rs"
          },
          fromRanges = { {
            ['end'] = {
              character = 7,
              line = 3
            },
            start = {
              character = 4,
              line = 3
            }
          } }
        } }

        local handler = require'vim.lsp.handlers'['callHierarchy/incomingCalls']
        handler(nil, rust_analyzer_response, {})
        return vim.fn.getqflist()
      ]=])

      local expected = { {
        bufnr = 2,
        col = 5,
        end_col = 0,
        lnum = 4,
        end_lnum = 0,
        module = "",
        nr = 0,
        pattern = "",
        text = "main",
        type = "",
        valid = 1,
        vcol = 0
      } }

      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.rename', function()
    for _, test in ipairs({
      {
        it = "does not attempt to rename on nil response",
        name = "prepare_rename_nil",
        expected_handlers = {
          {NIL, {}, {method="shutdown", client_id=1}};
          {NIL, {}, {method="start", client_id=1}};
        },
      },
      {
        it = "handles prepareRename placeholder response",
        name = "prepare_rename_placeholder",
        expected_handlers = {
          {NIL, {}, {method="shutdown", client_id=1}};
          {NIL, NIL, {method="textDocument/rename", client_id=1, bufnr=1}};
          {NIL, {}, {method="start", client_id=1}};
        },
        expected_text = "placeholder", -- see fake lsp response
      },
      {
        it = "handles range response",
        name = "prepare_rename_range",
        expected_handlers = {
          {NIL, {}, {method="shutdown", client_id=1}};
          {NIL, NIL, {method="textDocument/rename", client_id=1, bufnr=1}};
          {NIL, {}, {method="start", client_id=1}};
        },
        expected_text = "line", -- see test case and fake lsp response
      },
      {
        it = "handles error",
        name = "prepare_rename_error",
        expected_handlers = {
          {NIL, {}, {method="shutdown", client_id=1}};
          {NIL, {}, {method="start", client_id=1}};
        },
      },
    }) do
    it(test.it, function()
      local client
      test_rpc_server {
        test_name = test.name;
        on_init = function(_client)
          client = _client
          eq(true, client.server_capabilities().renameProvider.prepareProvider)
        end;
        on_setup = function()
          exec_lua([=[
            local bufnr = vim.api.nvim_get_current_buf()
            lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)
            vim.lsp._stubs = {}
            vim.fn.input = function(opts, on_confirm)
              vim.lsp._stubs.input_prompt = opts.prompt
              vim.lsp._stubs.input_text = opts.default
              return 'renameto' -- expect this value in fake lsp
            end
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'', 'this is line two'})
            vim.fn.cursor(2, 13) -- the space between "line" and "two"
          ]=])
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end;
        on_handler = function(err, result, ctx)
          -- Don't compare & assert params, they're not relevant for the testcase
          -- This allows us to be lazy and avoid declaring them
          ctx.params = nil

          eq(table.remove(test.expected_handlers), {err, result, ctx}, "expected handler")
          if ctx.method == 'start' then
            exec_lua("vim.lsp.buf.rename()")
          end
          if ctx.method == 'shutdown' then
            if test.expected_text then
              eq("New Name: ", exec_lua("return vim.lsp._stubs.input_prompt"))
              eq(test.expected_text, exec_lua("return vim.lsp._stubs.input_text"))
            end
            client.stop()
          end
        end;
      }
    end)
    end
  end)

  describe('vim.lsp.buf.code_action', function()
    it('Calls client side command if available', function()
      local client
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      test_rpc_server {
        test_name = 'code_action_with_resolve',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function()
        end,
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx})
          if ctx.method == 'start' then
            exec_lua([[
              vim.lsp.commands['dummy1'] = function(cmd)
                vim.lsp.commands['dummy2'] = function()
                end
              end
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)
              vim.fn.inputlist = function()
                return 1
              end
              vim.lsp.buf.code_action()
            ]])
          elseif ctx.method == 'shutdown' then
            eq('function', exec_lua[[return type(vim.lsp.commands['dummy2'])]])
            client.stop()
          end
        end
      }
    end)
    it('Calls workspace/executeCommand if no client side command', function()
      local client
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        {
          NIL,
          { command = 'dummy1', title = 'Command 1' },
          { bufnr = 1, method = 'workspace/executeCommand', client_id = 1 },
        },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      test_rpc_server({
        test_name = 'code_action_server_side_command',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function() end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code', fake_lsp_logfile)
          eq(0, signal, 'exit signal', fake_lsp_logfile)
        end,
        on_handler = function(err, result, ctx)
          ctx.params = nil -- don't compare in assert
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            exec_lua([[
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)
              vim.fn.inputlist = function()
                return 1
              end
              vim.lsp.buf.code_action()
            ]])
          elseif ctx.method == 'shutdown' then
            client.stop()
          end
        end,
      })
    end)
    it('Filters and automatically applies action if requested', function()
      local client
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      test_rpc_server {
        test_name = 'code_action_filter',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function()
        end,
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx})
          if ctx.method == 'start' then
            exec_lua([[
              vim.lsp.commands['preferred_command'] = function(cmd)
                vim.lsp.commands['executed_preferred'] = function()
                end
              end
              vim.lsp.commands['quickfix_command'] = function(cmd)
                vim.lsp.commands['executed_quickfix'] = function()
                end
              end
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)
              vim.lsp.buf.code_action({ filter = function(a) return a.isPreferred end, apply = true, })
              vim.lsp.buf.code_action({
                  -- expect to be returned actions 'quickfix' and 'quickfix.foo'
                  context = { only = {'quickfix'}, },
                  apply = true,
                  filter = function(a)
                      if a.kind == 'quickfix.foo' then
                        vim.lsp.commands['filtered_quickfix_foo'] = function() end
                        return false
                      elseif a.kind == 'quickfix' then
                        return true
                      else
                        assert(nil, 'unreachable')
                      end
                  end,
              })
            ]])
          elseif ctx.method == 'shutdown' then
            eq('function', exec_lua[[return type(vim.lsp.commands['executed_preferred'])]])
            eq('function', exec_lua[[return type(vim.lsp.commands['filtered_quickfix_foo'])]])
            eq('function', exec_lua[[return type(vim.lsp.commands['executed_quickfix'])]])
            client.stop()
          end
        end
      }
    end)
  end)
  describe('vim.lsp.commands', function()
    it('Accepts only string keys', function()
      matches(
        '.*The key for commands in `vim.lsp.commands` must be a string',
        pcall_err(exec_lua, 'vim.lsp.commands[1] = function() end')
      )
    end)
    it('Accepts only function values', function()
      matches(
        '.*Command added to `vim.lsp.commands` must be a function',
        pcall_err(exec_lua, 'vim.lsp.commands.dummy = 10')
      )
    end)
  end)
  describe('vim.lsp.codelens', function()
    it('uses client commands', function()
      local client
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      test_rpc_server {
        test_name = 'clientside_commands',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function()
        end,
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx})
          if ctx.method == 'start' then
            local fake_uri = "file:///fake/uri"
            local cmd = exec_lua([[
              fake_uri = ...
              local bufnr = vim.uri_to_bufnr(fake_uri)
              vim.fn.bufload(bufnr)
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'One line'})
              local lenses = {
                {
                  range = {
                    start = { line = 0, character = 0, },
                    ['end'] = { line = 0, character = 8 }
                  },
                  command = { title = 'Lens1', command = 'Dummy' }
                },
              }
              vim.lsp.codelens.on_codelens(nil, lenses, {method='textDocument/codeLens', client_id=1, bufnr=bufnr})
              local cmd_called = nil
              vim.lsp.commands['Dummy'] = function(command)
                cmd_called = command
              end
              vim.api.nvim_set_current_buf(bufnr)
              vim.lsp.codelens.run()
              return cmd_called
            ]], fake_uri)
         eq({ command = 'Dummy', title = 'Lens1' }, cmd)
         elseif ctx.method == 'shutdown' then
           client.stop()
          end
        end
      }
    end)

    it('releases buffer refresh lock', function()
      local client
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      test_rpc_server {
        test_name = 'codelens_refresh_lock',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function()
          exec_lua([=[
              local bufnr = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'One line'})
              vim.lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)

              CALLED = false
              RESPONSE = nil
              local on_codelens = vim.lsp.codelens.on_codelens
              vim.lsp.codelens.on_codelens = function (err, result, ...)
                CALLED = true
                RESPONSE = { err = err, result = result }
                return on_codelens(err, result, ...)
              end
            ]=])
        end,
        on_exit = function(code, signal)
          eq(0, code, "exit code")
          eq(0, signal, "exit signal")
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), {err, result, ctx})
          if ctx.method == 'start' then
            -- 1. first codelens request errors
            local response = exec_lua([=[
              CALLED = false
              vim.lsp.codelens.refresh()
              vim.wait(100, function () return CALLED end)
              return RESPONSE
            ]=])
            eq( { err = { code = -32002, message = "ServerNotInitialized" } }, response)

            -- 2. second codelens request runs
            response = exec_lua([=[
              CALLED = false
              local cmd_called = nil
              vim.lsp.commands["Dummy"] = function (command)
                cmd_called = command
              end
              vim.lsp.codelens.refresh()
              vim.wait(100, function () return CALLED end)
              vim.lsp.codelens.run()
              vim.wait(100, function () return cmd_called end)
              return cmd_called
            ]=])
            eq( { command = "Dummy", title = "Lens1" }, response)

            -- 3. third codelens request runs
            response = exec_lua([=[
              CALLED = false
              local cmd_called = nil
              vim.lsp.commands["Dummy"] = function (command)
                cmd_called = command
              end
              vim.lsp.codelens.refresh()
              vim.wait(100, function () return CALLED end)
              vim.lsp.codelens.run()
              vim.wait(100, function () return cmd_called end)
              return cmd_called
            ]=])
            eq( { command = "Dummy", title = "Lens2" }, response)
         elseif ctx.method == 'shutdown' then
           client.stop()
          end
        end
      }
    end)
  end)

  describe("vim.lsp.buf.format", function()
    it("Aborts with notify if no client matches filter", function()
      local client
      test_rpc_server {
        test_name = "basic_init",
        on_init = function(c)
          client = c
        end,
        on_handler = function()
          local notify_msg = exec_lua([[
            local bufnr = vim.api.nvim_get_current_buf()
            vim.lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)
            local notify_msg
            local notify = vim.notify
            vim.notify = function(msg, log_level)
              notify_msg = msg
            end
            vim.lsp.buf.format({ name = 'does-not-exist' })
            vim.notify = notify
            return notify_msg
          ]])
          eq("[LSP] Format request failed, no matching language servers.", notify_msg)
          client.stop()
        end,
      }
    end)
    it("Sends textDocument/formatting request to format buffer", function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_formatting",
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == "start" then
            local notify_msg = exec_lua([[
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)
              local notify_msg
              local notify = vim.notify
              vim.notify = function(msg, log_level)
                notify_msg = msg
              end
              vim.lsp.buf.format({ bufnr = bufnr })
              vim.notify = notify
              return notify_msg
            ]])
            eq(NIL, notify_msg)
          elseif ctx.method == "shutdown" then
            client.stop()
          end
        end,
      }
    end)
    it('Can format async', function()
      local expected_handlers = {
        {NIL, {}, {method="shutdown", client_id=1}};
        {NIL, {}, {method="start", client_id=1}};
      }
      local client
      test_rpc_server {
        test_name = "basic_formatting",
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == "start" then
            local result = exec_lua([[
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, TEST_RPC_CLIENT_ID)

              local notify_msg
              local notify = vim.notify
              vim.notify = function(msg, log_level)
                notify_msg = msg
              end

              local handler = vim.lsp.handlers['textDocument/formatting']
              local handler_called = false
              vim.lsp.handlers['textDocument/formatting'] = function(...)
                handler_called = true
              end

              vim.lsp.buf.format({ bufnr = bufnr, async = true })
              vim.wait(1000, function() return handler_called end)

              vim.notify = notify
              vim.lsp.handlers['textDocument/formatting'] = handler
              return {notify = notify_msg, handler_called = handler_called}
            ]])
            eq({handler_called=true}, result)
          elseif ctx.method == "shutdown" then
            client.stop()
          end
        end,
      }
    end)
  end)
end)
