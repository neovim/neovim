local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local NIL = helpers.NIL

-- Use these to get access to a coroutine so that I can run async tests and use
-- yield.
local run, stop = helpers.run, helpers.stop

if helpers.pending_win32(pending) then return end

local is_windows = require'luv'.os_uname().sysname == "Windows"
local lsp_test_rpc_server_file = "test/functional/fixtures/lsp-test-rpc-server.lua"
if is_windows then
  lsp_test_rpc_server_file = lsp_test_rpc_server_file:gsub("/", "\\")
end

local function test_rpc_server_setup(test_name, timeout_ms)
  exec_lua([=[
    lsp = require('vim.lsp')
    local test_name, fixture_filename, timeout = ...
    TEST_RPC_CLIENT_ID = lsp.start_client {
      cmd = {
        vim.api.nvim_get_vvar("progpath"), '-Es', '-u', 'NONE', '--headless',
        "-c", string.format("lua TEST_NAME = %q", test_name),
        "-c", string.format("lua TIMEOUT = %d", timeout),
        "-c", "luafile "..fixture_filename,
      };
      callbacks = setmetatable({}, {
        __index = function(t, method)
          return function(...)
            return vim.rpcrequest(1, 'callback', ...)
          end
        end;
      });
      root_dir = vim.loop.cwd();
      on_init = function(client, result)
        TEST_RPC_CLIENT = client
        vim.rpcrequest(1, "init", result)
      end;
      on_exit = function(...)
        vim.rpcnotify(1, "exit", ...)
      end;
    }
  ]=], test_name, lsp_test_rpc_server_file, timeout_ms or 1e3)
end

local function test_rpc_server(config)
  if config.test_name then
    clear()
    test_rpc_server_setup(config.test_name, config.timeout_ms or 1e3)
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
    if method == 'callback' then
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

describe('Language Client API', function()
  describe('server_name is specified', function()
    before_each(function()
      clear()
      -- Run an instance of nvim on the file which contains our "scripts".
      -- Pass TEST_NAME to pick the script.
      local test_name = "basic_init"
      exec_lua([=[
        lsp = require('vim.lsp')
        local test_name, fixture_filename = ...
        TEST_RPC_CLIENT_ID = lsp.start_client {
          cmd = {
            vim.api.nvim_get_vvar("progpath"), '-Es', '-u', 'NONE', '--headless',
            "-c", string.format("lua TEST_NAME = %q", test_name),
            "-c", "luafile "..fixture_filename;
          };
          root_dir = vim.loop.cwd();
        }
      ]=], test_name, lsp_test_rpc_server_file)
    end)

    after_each(function()
      exec_lua("lsp._vim_exit_handler()")
     -- exec_lua("lsp.stop_all_clients(true)")
    end)

    describe('start_client and stop_client', function()
      it('should return true', function()
        for _ = 1, 20 do
          helpers.sleep(10)
          if exec_lua("return #lsp.get_active_clients()") > 0 then
            break
          end
        end
        eq(1, exec_lua("return #lsp.get_active_clients()"))
        eq(false, exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID) == nil"))
        eq(false, exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID).is_stopped()"))
        exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID).stop()")
        eq(false, exec_lua("return lsp.get_client_by_id(TEST_RPC_CLIENT_ID).is_stopped()"))
        for _ = 1, 20 do
          helpers.sleep(10)
          if exec_lua("return #lsp.get_active_clients()") == 0 then
            break
          end
        end
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
          eq(0, client.resolved_capabilities().text_document_did_change)
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

    it('should verify capabilities sent', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
      }
      test_rpc_server {
        test_name = "basic_check_capabilities";
        on_init = function(client)
          client.stop()
        end;
        on_exit = function(code, signal)
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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

    -- TODO(askhan) we don't support full for now, so we can disable these tests.
    pending('should check the body and didChange incremental', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_incremental";
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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

    -- TODO(askhan) we don't support full for now, so we can disable these tests.
    pending('should check the body and didChange incremental normal mode editting', function()
      local expected_callbacks = {
        {NIL, "shutdown", {}, 1};
        {NIL, "finish", {}, 1};
        {NIL, "start", {}, 1};
      }
      local client
      test_rpc_server {
        test_name = "basic_check_buffer_open_and_change_incremental_editting";
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
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
          eq(0, code, "exit code") eq(0, signal, "exit signal")
        end;
        on_callback = function(err, method, params, client_id)
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
        end;
      }
    end)

  end)
end)
