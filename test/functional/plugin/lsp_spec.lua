local helpers = require('test.functional.helpers')(after_each)

local assert_log = helpers.assert_log
local clear = helpers.clear
local buf_lines = helpers.buf_lines
local dedent = helpers.dedent
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local pesc = helpers.pesc
local insert = helpers.insert
local retry = helpers.retry
local NIL = helpers.NIL

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

local function fake_lsp_server_setup(test_name, timeout_ms)
  exec_lua([=[
    lsp = require('vim.lsp')
    local test_name, fixture_filename, logfile, timeout = ...
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
  ]=], test_name, fake_lsp_code, fake_lsp_logfile, timeout_ms or 1e3)
end

local function test_rpc_server(config)
  if config.test_name then
    clear()
    fake_lsp_server_setup(config.test_name, config.timeout_ms or 1e3)
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
        on_callback = function(err, method, params, client_id)
          eq(table.remove(expected_callbacks), {err, method, params, client_id}, "expected callback")
        end;
      }
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
    eq({'LspDiagnosticsError',
        'LspDiagnosticsErrorSign',
        'LspDiagnosticsHint',
        'LspDiagnosticsHintSign',
        'LspDiagnosticsInformation',
        'LspDiagnosticsInformationSign',
        'LspDiagnosticsUnderline',
        'LspDiagnosticsUnderlineError',
        'LspDiagnosticsUnderlineHint',
        'LspDiagnosticsUnderlineInformation',
        'LspDiagnosticsUnderlineWarning',
        'LspDiagnosticsWarning',
        'LspDiagnosticsWarningSign',
      },
      exec_lua([[require'vim.lsp'; return vim.fn.getcompletion('Lsp', 'highlight')]]))
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
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
      eq({
        '123First line of text';
        '2econd line of text';
        '3ird line of text';
        'Fourth line of text';
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
          vim.lsp.util.apply_text_document_edit(...)
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
        return vim.lsp.callbacks['workspace/applyEdit'](nil, nil, apply_edit)
      ]])
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
        { label='foobar' },
        { label='foobar', textEdit={} },
        -- resolves into insertText
        { label='foocar', insertText='foobar' },
        { label='foocar', insertText='foobar', textEdit={} },
        -- resolves into textEdit.newText
        { label='foocar', insertText='foodar', textEdit={newText='foobar'} },
        { label='foocar', textEdit={newText='foobar'} }
      }
      local completion_list_items = {items=completion_list}
      local expected = {
        { abbr = 'foobar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label = 'foobar' } } } } },
        { abbr = 'foobar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foobar', textEdit={} } } }  } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', insertText='foobar' } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', insertText='foobar', textEdit={} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', insertText='foodar', textEdit={newText='foobar'} } } } } },
        { abbr = 'foocar', dup = 1, empty = 1, icase = 1, info = ' ', kind = 'Unknown', menu = '', word = 'foobar', user_data = { nvim = { lsp = { completion_item = { label='foocar', textEdit={newText='foobar'} } } } } },
      }

      eq(expected, exec_lua([[return vim.lsp.util.text_document_completion_list_to_complete_items(...)]], completion_list, prefix))
      eq(expected, exec_lua([[return vim.lsp.util.text_document_completion_list_to_complete_items(...)]], completion_list_items, prefix))
      eq({}, exec_lua([[return vim.lsp.util.text_document_completion_list_to_complete_items(...)]], {}, prefix))
    end)
  end)
  describe('buf_diagnostics_save_positions', function()
    it('stores the diagnostics in diagnostics_by_buf', function ()
      local diagnostics = {
        { range = {}; message = "diag1" },
        { range = {}; message = "diag2" },
      }
      exec_lua([[
        vim.lsp.util.buf_diagnostics_save_positions(...)]], 0, diagnostics)
      eq(1, exec_lua [[ return #vim.lsp.util.diagnostics_by_buf ]])
      eq(diagnostics, exec_lua [[
        for _, diagnostics in pairs(vim.lsp.util.diagnostics_by_buf) do
          return diagnostics
        end
      ]])
    end)
  end)
  describe('lsp.util.show_line_diagnostics', function()
    it('creates floating window and returns popup bufnr and winnr if current line contains diagnostics', function()
      eq(3, exec_lua [[
        local buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
          "testing";
          "123";
        })
        local diagnostics = {
          {
            range = {
              start = { line = 0; character = 1; };
              ["end"] = { line = 0; character = 3; };
            };
            severity = vim.lsp.protocol.DiagnosticSeverity.Error;
            message = "Syntax error";
          },
        }
        vim.api.nvim_win_set_buf(0, buffer)
        vim.lsp.util.buf_diagnostics_save_positions(vim.fn.bufnr(buffer), diagnostics)
        local popup_bufnr, winnr = vim.lsp.util.show_line_diagnostics()
        return popup_bufnr
      ]])
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
    describe('convert SymbolInformation[] to items', function()
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
    describe('returns the name specified by protocol', function()
      eq("Text", exec_lua("return vim.lsp.util._get_completion_item_kind_name(1)"))
      eq("TypeParameter", exec_lua("return vim.lsp.util._get_completion_item_kind_name(25)"))
    end)
    describe('returns the name not specified by protocol', function()
      eq("Unknown", exec_lua("return vim.lsp.util._get_completion_item_kind_name(nil)"))
      eq("Unknown", exec_lua("return vim.lsp.util._get_completion_item_kind_name(vim.NIL)"))
      eq("Unknown", exec_lua("return vim.lsp.util._get_completion_item_kind_name(1000)"))
    end)
  end)

  describe('lsp.util._get_symbol_kind_name', function()
    describe('returns the name specified by protocol', function()
      eq("File", exec_lua("return vim.lsp.util._get_symbol_kind_name(1)"))
      eq("TypeParameter", exec_lua("return vim.lsp.util._get_symbol_kind_name(26)"))
    end)
    describe('returns the name not specified by protocol', function()
      eq("Unknown", exec_lua("return vim.lsp.util._get_symbol_kind_name(nil)"))
      eq("Unknown", exec_lua("return vim.lsp.util._get_symbol_kind_name(vim.NIL)"))
      eq("Unknown", exec_lua("return vim.lsp.util._get_symbol_kind_name(1000)"))
    end)
  end)
end)
