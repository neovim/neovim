local helpers = require('test.functional.helpers')(after_each)

local assert_log = helpers.assert_log
local clear = helpers.clear
local buf_lines = helpers.buf_lines
local dedent = helpers.dedent
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local pcall_err = helpers.pcall_err
local pesc = helpers.pesc
local insert = helpers.insert
local retry = helpers.retry
local NIL = helpers.NIL
local read_file = require('test.helpers').read_file
local write_file = require('test.helpers').write_file

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

local function fake_lsp_server_setup(test_name, timeout_ms, options)
  exec_lua([=[
    lsp = require('vim.lsp')
    local test_name, fixture_filename, logfile, timeout, options = ...
    TEST_RPC_CLIENT_ID = lsp.start_client {
      cmd_env = {
        NVIM_LOG_FILE = logfile;
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
      root_dir = vim.loop.cwd();
      on_init = function(client, result)
        TEST_RPC_CLIENT = client
        vim.rpcrequest(1, "init", result)
        client.config.flags.allow_incremental_sync = options.allow_incremental_sync or false
      end;
      on_exit = function(...)
        vim.rpcnotify(1, "exit", ...)
      end;
    }
  ]=], test_name, fake_lsp_code, fake_lsp_logfile, timeout_ms or 1e3, options or {})
end

local function test_rpc_server(config)
  if config.test_name then
    clear()
    fake_lsp_server_setup(config.test_name, config.timeout_ms or 1e3, config.options)
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
      if config.on_callback then
        config.on_callback(unpack(args))
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
    exec_lua("lsp._vim_exit_handler()")
  end
end

describe('LSP', function()
  describe('server_name specified', function()
    before_each(function()
      clear()
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
            root_dir = vim.loop.cwd();
          }
        end
        TEST_CLIENT1 = test__start_client()
      ]=], test_name, fake_lsp_code, fake_lsp_logfile)
    end)

    after_each(function()
      exec_lua("lsp._vim_exit_handler()")
     -- exec_lua("lsp.stop_all_clients(true)")
    end)

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

  describe('basic_init test', function()
    after_each(function()
      stop()
      exec_lua("lsp.stop_client(lsp.get_active_clients())")
      exec_lua("lsp._vim_exit_handler()")
    end)

    it('should run correctly', function()
      local expected_callbacks = {
        {NIL, "test", {}, 1};
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
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
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
          eq(101, code, "exit code", fake_lsp_logfile)  -- See fake-lsp-server.lua
          eq(0, signal, "exit signal", fake_lsp_logfile)
          assert_log(pesc([[assert_eq failed: left == "\"shutdown\"", right == "\"test\""]]),
            fake_lsp_logfile)
        end;
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...}, "expected callback")
        end;
      }
    end)

    it('should succeed with manual shutdown', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1, NIL};
        {NIL, "test", {}, 1};
      }
      test_rpc_server {
        test_name = "basic_init";
        on_init = function(client)
          eq(0, client.resolved_capabilities().text_document_did_change)
          client.request('shutdown')
          client.notify('exit')
          client.stop()
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...}, "expected callback")
        end;
      }
    end)

    it('client should return settings via workspace/configuration handler', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "workspace/configuration", { items = {
              { section = "testSetting1" };
              { section = "testSetting2" };
          }}, 1};
        {NIL, "start", {}, 1};
      }
      local client
      test_rpc_server {
        test_name = "check_workspace_configuration";
        on_init = function(_client)
          client = _client
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'start' then
            exec_lua([=[
              local client = vim.lsp.get_client_by_id(TEST_RPC_CLIENT_ID)
              client.config.settings = {
                testSetting1 = true;
                testSetting2 = false;
            }]=])
          end
          if method == 'workspace/configuration' then
            local result = exec_lua([=[
              local method, params = ...
              return require'vim.lsp.handlers'['workspace/configuration'](err, method, params, TEST_RPC_CLIENT_ID)]=], method, params)
            client.notify('workspace/configuration', result)
          end
          if method == 'shutdown' then
            client.stop()
          end
        end;
      }
    end)
    it('workspace/configuration returns NIL per section if client was started without config.settings', function()
      clear()
      fake_lsp_server_setup('workspace/configuration no settings')
      eq({ NIL, NIL, }, exec_lua [[
        local params = {
          items = {
            {section = 'foo'},
            {section = 'bar'},
          }
        }
        return vim.lsp.handlers['workspace/configuration'](nil, nil, params, TEST_RPC_CLIENT_ID)
      ]])
    end)

    it('should verify capabilities sent', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
      }
      test_rpc_server {
        test_name = "basic_check_capabilities";
        on_init = function(client)
          client.stop()
          local full_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(full_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_save)
          eq(false, client.resolved_capabilities().code_lens)
          eq(false, client.resolved_capabilities().code_lens_resolve)
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...}, "expected callback")
        end;
      }
    end)

    it('client.supports_methods() should validate capabilities', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
      }
      test_rpc_server {
        test_name = "capabilities_for_client_supports_method";
        on_init = function(client)
          client.stop()
          local full_kind = exec_lua("return require'vim.lsp.protocol'.TextDocumentSyncKind.Full")
          eq(full_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().completion)
          eq(true, client.resolved_capabilities().hover)
          eq(false, client.resolved_capabilities().goto_definition)
          eq(false, client.resolved_capabilities().rename)
          eq(true, client.resolved_capabilities().code_lens)
          eq(true, client.resolved_capabilities().code_lens_resolve)

          -- known methods for resolved capabilities
          eq(true, client.supports_method("textDocument/hover"))
          eq(false, client.supports_method("textDocument/definition"))

          -- unknown methods are assumed to be supported.
          eq(true, client.supports_method("unknown-method"))
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...}, "expected callback")
        end;
      }
    end)

    it('should call unsupported_method when trying to call an unsupported method', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
      }
      test_rpc_server {
        test_name = "capabilities_for_client_supports_method";
        on_setup = function()
            exec_lua([=[
              BUFFER = vim.api.nvim_get_current_buf()
              lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID)
              vim.lsp.handlers['textDocument/typeDefinition'] = function(err, method)
                vim.lsp._last_lsp_callback = { err = err; method = method }
              end
              vim.lsp._unsupported_method = function(method)
                vim.lsp._last_unsupported_method = method
                return 'fake-error'
              end
              vim.lsp.buf.type_definition()
            ]=])
        end;
        on_init = function(client)
          client.stop()
          local method = exec_lua("return vim.lsp._last_unsupported_method")
          eq("textDocument/typeDefinition", method)
          local lsp_cb_call = exec_lua("return vim.lsp._last_lsp_callback")
          eq("fake-error", lsp_cb_call.err)
          eq("textDocument/typeDefinition", lsp_cb_call.method)
          exec_lua [[
            vim.api.nvim_command(BUFFER.."bwipeout")
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...}, "expected callback")
        end;
      }
    end)

    it('shouldn\'t call unsupported_method when no client and trying to call an unsupported method', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
      }
      test_rpc_server {
        test_name = "capabilities_for_client_supports_method";
        on_setup = function()
            exec_lua([=[
              vim.lsp.handlers['textDocument/typeDefinition'] = function(err, method)
                vim.lsp._last_lsp_callback = { err = err; method = method }
              end
              vim.lsp._unsupported_method = function(method)
                vim.lsp._last_unsupported_method = method
                return 'fake-error'
              end
              vim.lsp.buf.type_definition()
            ]=])
        end;
        on_init = function(client)
          client.stop()
          eq(NIL, exec_lua("return vim.lsp._last_unsupported_method"))
          eq(NIL, exec_lua("return vim.lsp._last_lsp_callback"))
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(...)
          eq(table.remove(expected_callbacks), {...}, "expected callback")
        end;
      }
    end)

    it('should not send didOpen if the buffer closes before init', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
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
          eq(full_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          client.notify('finish')
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body sent attaching before init', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
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
          eq(full_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          exec_lua [[
            assert(not lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID), "Shouldn't attach twice")
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          if method == 'start' then
            client.notify('finish')
          end
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body sent attaching after init', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
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
          eq(full_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          if method == 'start' then
            client.notify('finish')
          end
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange full', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
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
          eq(full_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          if method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "boop";
              })
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange full with noeol', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
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
          eq(full_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          if method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "boop";
              })
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange incremental', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_incremental";
        options = { allow_incremental_sync = true };
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
          eq(sync_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          if method == 'start' then
            exec_lua [[
              vim.api.nvim_buf_set_lines(BUFFER, 1, 2, false, {
                "123boop";
              })
            ]]
            client.notify('finish')
          end
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    -- TODO(askhan) we don't support full for now, so we can disable these tests.
    pending('should check the body and didChange incremental normal mode editing', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
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
          eq(sync_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          if method == 'start' then
            helpers.command("normal! 1Go")
            client.notify('finish')
          end
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange full with 2 changes', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
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
          eq(sync_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          if method == 'start' then
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
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)

    it('should check the body and didChange full lifecycle', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
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
          eq(sync_kind, client.resolved_capabilities().text_document_did_change)
          eq(true, client.resolved_capabilities().text_document_open_close)
          exec_lua [[
            assert(lsp.buf_attach_client(BUFFER, TEST_RPC_CLIENT_ID))
          ]]
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_callback = function(err, method, params, client_id)
          if method == 'start' then
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
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
          if method == 'finish' then
            client.stop()
          end
        end;
      }
    end)
  end)

  describe("parsing tests", function()
    it('should handle invalid content-length correctly', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
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
          eq(0, code, "exit code", fake_lsp_logfile)
          eq(0, signal, "exit signal", fake_lsp_logfile)
        end;
        on_handler = function(err, method, params, client_id)
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected handler")
        end;
      }
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
      eq(dedent([[
          Error executing lua: .../lsp.lua:0: cmd: expected list, got nvim
          stack traceback:
              .../lsp.lua:0: in function <.../lsp.lua:0>]]),
        pcall_err(_cmd_parts, 'nvim'))
      eq(dedent([[
          Error executing lua: .../lsp.lua:0: cmd argument: expected string, got number
          stack traceback:
              .../lsp.lua:0: in function <.../lsp.lua:0>]]),
        pcall_err(_cmd_parts, {'nvim', 1}))
    end)
  end)
end)

describe('LSP', function()
  before_each(function()
    clear()
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

  it('highlight groups', function()
    eq({
      'LspDiagnosticsDefaultError',
      'LspDiagnosticsDefaultHint',
      'LspDiagnosticsDefaultInformation',
      'LspDiagnosticsDefaultWarning',
      'LspDiagnosticsFloatingError',
      'LspDiagnosticsFloatingHint',
      'LspDiagnosticsFloatingInformation',
      'LspDiagnosticsFloatingWarning',
      'LspDiagnosticsSignError',
      'LspDiagnosticsSignHint',
      'LspDiagnosticsSignInformation',
      'LspDiagnosticsSignWarning',
      'LspDiagnosticsUnderlineError',
      'LspDiagnosticsUnderlineHint',
      'LspDiagnosticsUnderlineInformation',
      'LspDiagnosticsUnderlineWarning',
      'LspDiagnosticsVirtualTextError',
      'LspDiagnosticsVirtualTextHint',
      'LspDiagnosticsVirtualTextInformation',
      'LspDiagnosticsVirtualTextWarning',
    }, exec_lua([[require'vim.lsp'; return vim.fn.getcompletion('Lsp', 'highlight')]]))
  end)

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
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
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
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
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
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
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
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
      eq({
        'First line of text';
        'Second line of text';
        'Third line of text';
        'Fourth line of text';
        'å å ɧ 汉语 ↥ 🤦 🦄';
        'foobar';
      }, buf_lines(1))
    end)

    describe('with LSP end line after what Vim considers to be the end line', function()
      it('applies edits when the last linebreak is considered a new line', function()
        local edits = {
          make_edit(0, 0, 5, 0, {"All replaced"});
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
        eq({'All replaced'}, buf_lines(1))
      end)
      it('applies edits when the end line is 2 larger than vim\'s', function()
        local edits = {
          make_edit(0, 0, 6, 0, {"All replaced"});
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
        eq({'All replaced'}, buf_lines(1))
      end)
      it('applies edits with a column offset', function()
        local edits = {
          make_edit(0, 0, 5, 2, {"All replaced"});
        }
        exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
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
          uri = "file://fake/uri";
          version = editVersion
        }
      }
    end
    before_each(function()
      target_bufnr = exec_lua [[
        local bufnr = vim.uri_to_bufnr("file://fake/uri")
        local lines = {"1st line of text", "2nd line of 语text"}
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      ]]
    end)
    it('correctly goes ahead with the edit if all is normal', function()
      exec_lua('vim.lsp.util.apply_text_document_edit(...)', text_document_edit(5))
      eq({
        'First ↥ 🤦 🦄 line of text';
        '2nd line of 语text';
      }, buf_lines(target_bufnr))
    end)
    it('correctly goes ahead with the edit if the version is vim.NIL', function()
      -- we get vim.NIL when we decode json null value.
      local json = exec_lua[[
        return vim.fn.json_decode("{ \"a\": 1, \"b\": null }")
      ]]
      eq(json.b, exec_lua("return vim.NIL"))

      exec_lua('vim.lsp.util.apply_text_document_edit(...)', text_document_edit(exec_lua("return vim.NIL")))
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
          vim.lsp.util.apply_text_document_edit(args[1])
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
      local expected = {
        applied = true;
        failureReason = nil;
      }
      eq(expected, exec_lua [[
        local apply_edit = {
          label = nil;
          edit = {};
        }
        return vim.lsp.handlers['workspace/applyEdit'](nil, nil, apply_edit)
      ]])
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
          uri = "file://fake/uri";
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
        local bufnr = vim.uri_to_bufnr("file://fake/uri")
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

        vim.lsp.util.apply_workspace_edit(workspace_edits)

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

        vim.lsp.util.apply_workspace_edit(workspace_edits)

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
      exec_lua('vim.lsp.util.apply_workspace_edit(...)', edit)
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
      exec_lua('vim.lsp.util.apply_workspace_edit(...)', edit)
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
      exec_lua('vim.lsp.util.apply_workspace_edit(...)', edit)
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
      eq(true, pcall(exec_lua, 'vim.lsp.util.apply_workspace_edit(...)', edit))
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
        { label='foocar', sortText="g", insertText='foodar', textEdit={newText='foobar(${1:place holder}, ${2:more ...holder{\\}})'} },
        { label='foocar', sortText="h", insertText='foodar(${1:var1} typ1, ${2:var2} *typ2) {$0\\}', textEdit={} },
        -- nested snippet tokens
        { label='foocar', sortText="i", insertText='foodar(${1:var1 ${2|typ2,typ3|} ${3:tail}}) {$0\\}', textEdit={} },
        -- plain text
        { label='foocar', sortText="j", insertText='foodar(${1:var1})', insertTextFormat=1, textEdit={} },
      }
      local completion_list_items = {items=completion_list}
      local expected = {
        { abbr = 'foobar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label = 'foobar', sortText="a" } } } } },
        { abbr = 'foobar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foobar', sortText="b", textEdit={} } } }  } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="c", insertText='foobar' } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="d", insertText='foobar', textEdit={} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="e", insertText='foodar', textEdit={newText='foobar'} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="f", textEdit={newText='foobar'} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar(place holder, more ...holder{})', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="g", insertText='foodar', textEdit={newText='foobar(${1:place holder}, ${2:more ...holder{\\}})'} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foodar(var1 typ1, var2 *typ2) {}', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="h", insertText='foodar(${1:var1} typ1, ${2:var2} *typ2) {$0\\}', textEdit={} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foodar(var1 typ2,typ3 tail) {}', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="i", insertText='foodar(${1:var1 ${2|typ2,typ3|} ${3:tail}}) {$0\\}', textEdit={} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foodar(${1:var1})', user_data = { nvim = { lsp = { completion_item = { label='foocar', sortText="j", insertText='foodar(${1:var1})', insertTextFormat=1, textEdit={} } } } } },
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
          filename = 'fake/uri',
          lnum = 1,
          col = 3,
          text = 'testing'
        },
      }
      local actual = exec_lua [[
        local bufnr = vim.uri_to_bufnr("file://fake/uri")
        local lines = {"testing", "123"}
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        local locations = {
          {
            uri = 'file://fake/uri',
            range = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            }
          },
        }
        return vim.lsp.util.locations_to_items(locations)
      ]]
      eq(expected, actual)
    end)
    it('Convert LocationLink[] to items', function()
      local expected = {
        {
          filename = 'fake/uri',
          lnum = 1,
          col = 3,
          text = 'testing'
        },
      }
      local actual = exec_lua [[
        local bufnr = vim.uri_to_bufnr("file://fake/uri")
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
        return vim.lsp.util.locations_to_items(locations)
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
            filename = 'test_a',
            kind = 'File',
            lnum = 2,
            text = '[File] TestA'
          },
          {
            col = 1,
            filename = 'test_b',
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
                uri = "file://test_a"
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
                uri = "file://test_b"
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
        local bufnr = vim.uri_to_bufnr("file://fake/uri")
        local lines = {"1st line of text", "å å ɧ 汉语 ↥ 🤦 🦄"}
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      ]]
    end)

    local location = function(start_line, start_char, end_line, end_char)
      return {
        uri = "file://fake/uri",
        range = {
          start = { line = start_line, character = start_char },
          ["end"] = { line = end_line, character = end_char },
        },
      }
    end

    local jump = function(msg)
      eq(true, exec_lua('return vim.lsp.util.jump_to_location(...)', msg))
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
          targetUri = "file://fake/uri",
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

  describe('lsp.util.get_effective_tabstop', function()
    local function test_tabstop(tabsize, softtabstop)
      exec_lua(string.format([[
        vim.api.nvim_buf_set_option(0, 'softtabstop', %d)
        vim.api.nvim_buf_set_option(0, 'tabstop', 2)
        vim.api.nvim_buf_set_option(0, 'shiftwidth', 3)
      ]], softtabstop))
      eq(tabsize, exec_lua('return vim.lsp.util.get_effective_tabstop()'))
    end

    it('with softtabstop = 1', function() test_tabstop(1, 1) end)
    it('with softtabstop = 0', function() test_tabstop(2, 0) end)
    it('with softtabstop = -1', function() test_tabstop(3, -1) end)
  end)

  describe('vim.lsp.buf.outgoing_calls', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua([=[
        require'vim.lsp.handlers'['callHierarchy/outgoingCalls']()
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
        handler(nil, nil, rust_analyzer_response)
        return vim.fn.getqflist()
      ]=])

      local expected = { {
        bufnr = 2,
        col = 5,
        lnum = 4,
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
        require'vim.lsp.handlers'['callHierarchy/incomingCalls']()
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
        handler(nil, nil, rust_analyzer_response)
        return vim.fn.getqflist()
      ]=])

      local expected = { {
        bufnr = 2,
        col = 5,
        lnum = 4,
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
end)
