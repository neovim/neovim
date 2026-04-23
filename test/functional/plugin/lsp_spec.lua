local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local t_lsp = require('test.functional.plugin.lsp.testutil')

local buf_lines = n.buf_lines
local command = n.command
local dedent = t.dedent
local exec_lua = n.exec_lua
local eq = t.eq
local eval = n.eval
local matches = t.matches
local pcall_err = t.pcall_err
local pesc = vim.pesc
local insert = n.insert
local fn = n.fn
local retry = t.retry
local stop = n.stop
local NIL = vim.NIL
local read_file = t.read_file
local write_file = t.write_file
local is_ci = t.is_ci
local api = n.api
local is_os = t.is_os
local skip = t.skip
local mkdir = t.mkdir
local tmpname = t.tmpname

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition
local fake_lsp_code = t_lsp.fake_lsp_code
local fake_lsp_logfile = t_lsp.fake_lsp_logfile
local test_rpc_server = t_lsp.test_rpc_server
local create_tcp_echo_server = t_lsp.create_tcp_echo_server

local function get_buf_option(name, bufnr)
  return exec_lua(function()
    bufnr = bufnr or _G.BUFFER
    return vim.api.nvim_get_option_value(name, { buf = bufnr })
  end)
end

local function make_edit(y_0, x_0, y_1, x_1, text)
  return {
    range = {
      start = { line = y_0, character = x_0 },
      ['end'] = { line = y_1, character = x_1 },
    },
    newText = type(text) == 'table' and table.concat(text, '\n') or (text or ''),
  }
end

--- @param edits [integer, integer, integer, integer, string|string[]][]
--- @param encoding? string
local function apply_text_edits(edits, encoding)
  local edits1 = vim.tbl_map(
    --- @param edit [integer, integer, integer, integer, string|string[]]
    function(edit)
      return make_edit(unpack(edit))
    end,
    edits
  )
  exec_lua(function()
    vim.lsp.util.apply_text_edits(edits1, 1, encoding or 'utf-16')
  end)
end

--- @param notification_cb fun(method: 'body' | 'error', args: any)
local function verify_single_notification(notification_cb)
  local called = false
  n.run(nil, function(method, args)
    notification_cb(method, args)
    stop()
    called = true
  end, nil, 1000)
  eq(true, called)
end

-- TODO(justinmk): hangs on Windows https://github.com/neovim/neovim/pull/11837
if skip(is_os('win')) then
  return
end

describe('LSP', function()
  before_each(function()
    clear_notrace()
  end)

  after_each(function()
    stop()
    exec_lua(function()
      vim.iter(vim.lsp.get_clients({ _uninitialized = true })):each(function(client)
        client:stop(true)
      end)
    end)
    api.nvim_exec_autocmds('VimLeavePre', { modeline = false })
  end)

  teardown(function()
    os.remove(fake_lsp_logfile)
  end)

  describe('server_name specified', function()
    before_each(function()
      -- Run an instance of nvim on the file which contains our "scripts".
      -- Pass TEST_NAME to pick the script.
      local test_name = 'basic_init'
      exec_lua(function()
        _G.lsp = require('vim.lsp')
        function _G.test__start_client()
          return vim.lsp.start({
            cmd_env = {
              NVIM_LOG_FILE = fake_lsp_logfile,
              NVIM_APPNAME = 'nvim_lsp_test',
            },
            cmd = {
              vim.v.progpath,
              '-l',
              fake_lsp_code,
              test_name,
            },
            workspace_folders = {
              {
                uri = 'file://' .. vim.uv.cwd(),
                name = 'test_folder',
              },
            },
          }, { attach = false })
        end
        _G.TEST_CLIENT1 = _G.test__start_client()
      end)
    end)

    it('start_client(), Client:stop()', function()
      retry(nil, 4000, function()
        eq(
          1,
          exec_lua(function()
            return #vim.lsp.get_clients()
          end)
        )
      end)
      eq(
        2,
        exec_lua(function()
          _G.TEST_CLIENT2 = _G.test__start_client()
          return _G.TEST_CLIENT2
        end)
      )
      eq(
        3,
        exec_lua(function()
          _G.TEST_CLIENT3 = _G.test__start_client()
          return _G.TEST_CLIENT3
        end)
      )
      retry(nil, 4000, function()
        eq(
          3,
          exec_lua(function()
            return #vim.lsp.get_clients()
          end)
        )
      end)

      eq(
        false,
        exec_lua(function()
          return vim.lsp.get_client_by_id(_G.TEST_CLIENT1) == nil
        end)
      )
      eq(
        false,
        exec_lua(function()
          return vim.lsp.get_client_by_id(_G.TEST_CLIENT1).is_stopped()
        end)
      )
      exec_lua(function()
        return vim.lsp.get_client_by_id(_G.TEST_CLIENT1).stop()
      end)
      retry(nil, 4000, function()
        eq(
          2,
          exec_lua(function()
            return #vim.lsp.get_clients()
          end)
        )
      end)
      eq(
        true,
        exec_lua(function()
          return vim.lsp.get_client_by_id(_G.TEST_CLIENT1) == nil
        end)
      )

      exec_lua(function()
        vim.lsp.get_client_by_id(_G.TEST_CLIENT2):stop()
        vim.lsp.get_client_by_id(_G.TEST_CLIENT3):stop()
      end)
      retry(nil, 4000, function()
        eq(
          0,
          exec_lua(function()
            return #vim.lsp.get_clients()
          end)
        )
      end)
    end)

    it('does not reuse an already-stopping client #33616', function()
      -- we immediately try to start a second client with the same name/root
      -- before the first one has finished shutting down; we must get a new id.
      local clients = exec_lua(function()
        local client1 = assert(vim.lsp.start({
          name = 'dup-test',
          cmd = { vim.v.progpath, '-l', fake_lsp_code, 'basic_init' },
        }, { attach = false }))
        vim.lsp.get_client_by_id(client1):stop()
        local client2 = assert(vim.lsp.start({
          name = 'dup-test',
          cmd = { vim.v.progpath, '-l', fake_lsp_code, 'basic_init' },
        }, { attach = false }))
        return { client1, client2 }
      end)
      local c1, c2 = clients[1], clients[2]
      eq(false, c1 == c2, 'Expected a fresh client while the old one is stopping')
    end)
  end)

  describe('basic_init test', function()
    it('should run correctly', function()
      local expected_handlers = {
        { NIL, {}, { method = 'test', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'basic_init',
        on_init = function(client, _)
          -- client is a dummy object which will queue up commands to be run
          -- once the server initializes. It can't accept lua callbacks or
          -- other types that may be unserializable for now.
          client:stop()
        end,
        -- If the program timed out, then code will be nil.
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        -- Note that NIL must be used here.
        -- on_handler(err, method, result, client_id)
        on_handler = function(...)
          eq(table.remove(expected_handlers), { ... })
        end,
      }
    end)

    it('should fail', function()
      local expected_handlers = {
        { NIL, {}, { method = 'test', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'basic_init',
        on_init = function(client)
          client:notify('test')
          client:stop()
        end,
        on_exit = function(code, signal)
          eq(101, code, 'exit code') -- See fake-lsp-server.lua
          eq(0, signal, 'exit signal')
          t.assert_log(
            pesc([[assert_eq failed: left == "\"shutdown\"", right == "\"test\""]]),
            fake_lsp_logfile
          )
        end,
        on_handler = function(...)
          eq(table.remove(expected_handlers), { ... }, 'expected handler')
        end,
      }
    end)

    it('should send didChangeConfiguration after initialize if there are settings', function()
      test_rpc_server({
        test_name = 'basic_init_did_change_configuration',
        on_init = function(client, _)
          client:stop()
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        settings = {
          dummy = 1,
        },
      })
    end)

    it(
      "should set the client's offset_encoding when positionEncoding capability is supported",
      function()
        exec_lua(create_server_definition)
        local result = exec_lua(function()
          local server = _G._create_server({
            capabilities = {
              positionEncoding = 'utf-8',
            },
          })

          local client_id = vim.lsp.start({
            name = 'dummy',
            cmd = server.cmd,
          })

          if not client_id then
            return 'vim.lsp.start did not return client_id'
          end

          local client = vim.lsp.get_client_by_id(client_id)
          if not client then
            return 'No client found with id ' .. client_id
          end
          return client.offset_encoding
        end)
        eq('utf-8', result)
      end
    )

    it('should succeed with manual shutdown', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', bufnr = 1, client_id = 1, request_id = 2, version = 0 } },
        { NIL, {}, { method = 'test', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'basic_init',
        on_init = function(client)
          eq(0, client.server_capabilities().textDocumentSync.change)
          client:request('shutdown')
          client:notify('exit')
          client:stop()
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(...)
          eq(table.remove(expected_handlers), { ... }, 'expected handler')
        end,
      }
    end)

    it('should detach buffer in response to nvim_buf_detach', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_finish',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
          end)
          eq(
            true,
            exec_lua(function()
              return vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
            end)
          )
          eq(
            true,
            exec_lua(function()
              return vim.lsp.buf_is_attached(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
            end)
          )
          exec_lua(function()
            vim.cmd(_G.BUFFER .. 'bwipeout')
          end)
        end,
        on_init = function(_client)
          client = _client
          client:notify('finish')
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            exec_lua(function()
              return vim.lsp.buf_detach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
            end)
            eq(
              false,
              exec_lua(function()
                return vim.lsp.buf_is_attached(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
              end)
            )
            client:stop()
          end
        end,
      }
    end)

    it('should fire autocommands on attach and detach', function()
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_init',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_create_autocmd('LspAttach', {
              callback = function(ev)
                local client0 = assert(vim.lsp.get_client_by_id(ev.data.client_id))
                vim.g.lsp_attached = client0.name
              end,
            })
            vim.api.nvim_create_autocmd('LspDetach', {
              callback = function(ev)
                local client0 = assert(vim.lsp.get_client_by_id(ev.data.client_id))
                vim.g.lsp_detached = client0.name
              end,
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          eq(
            true,
            exec_lua(function()
              return vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
            end)
          )
          client:notify('finish')
        end,
        on_handler = function(_, _, ctx)
          if ctx.method == 'finish' then
            eq('basic_init', api.nvim_get_var('lsp_attached'))
            exec_lua(function()
              return vim.lsp.buf_detach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
            end)
            eq('basic_init', api.nvim_get_var('lsp_detached'))
            client:stop()
          end
        end,
      }
    end)

    it('should set default options on attach', function()
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'set_defaults_all_capabilities',
        on_init = function(_client)
          client = _client
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
          end)
        end,
        on_handler = function(_, _, ctx)
          if ctx.method == 'test' then
            eq('v:lua.vim.lsp.tagfunc', get_buf_option('tagfunc'))
            eq('v:lua.vim.lsp.omnifunc', get_buf_option('omnifunc'))
            eq('v:lua.vim.lsp.formatexpr()', get_buf_option('formatexpr'))
            eq('', get_buf_option('keywordprg'))
            eq(
              true,
              exec_lua(function()
                local keymap --- @type table<string,any>
                local called = false
                local origin = vim.lsp.buf.hover
                vim.lsp.buf.hover = function()
                  called = true
                end
                vim._with({ buf = _G.BUFFER }, function()
                  keymap = vim.fn.maparg('K', 'n', false, true)
                end)
                keymap.callback()
                vim.lsp.buf.hover = origin
                return called
              end)
            )
            client:stop()
          end
        end,
        on_exit = function(_, _)
          eq('', get_buf_option('tagfunc'))
          eq('', get_buf_option('omnifunc'))
          eq('', get_buf_option('formatexpr'))
          eq(
            true,
            exec_lua(function()
              local keymap --- @type string
              vim._with({ buf = _G.BUFFER }, function()
                keymap = vim.fn.maparg('K', 'n', false, false)
              end)
              return keymap:match('<Lua %d+: .*runtime/lua/vim/lsp%.lua:%d+>') ~= nil
            end)
          )
        end,
      }
    end)

    it('should overwrite options set by ftplugins', function()
      if t.is_zig_build() then
        return pending('TODO: broken with zig build')
      end
      local client --- @type vim.lsp.Client
      local BUFFER_1 --- @type integer
      local BUFFER_2 --- @type integer
      test_rpc_server {
        test_name = 'set_defaults_all_capabilities',
        on_init = function(_client)
          client = _client
          exec_lua(function()
            vim.api.nvim_command('filetype plugin on')
            BUFFER_1 = vim.api.nvim_create_buf(false, true)
            BUFFER_2 = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_option_value('filetype', 'man', { buf = BUFFER_1 })
            vim.api.nvim_set_option_value('filetype', 'xml', { buf = BUFFER_2 })
          end)

          -- Sanity check to ensure that some values are set after setting filetype.
          eq("v:lua.require'man'.goto_tag", get_buf_option('tagfunc', BUFFER_1))
          eq('xmlcomplete#CompleteTags', get_buf_option('omnifunc', BUFFER_2))
          eq('xmlformat#Format()', get_buf_option('formatexpr', BUFFER_2))

          exec_lua(function()
            vim.lsp.buf_attach_client(BUFFER_1, _G.TEST_RPC_CLIENT_ID)
            vim.lsp.buf_attach_client(BUFFER_2, _G.TEST_RPC_CLIENT_ID)
          end)
        end,
        on_handler = function(_, _, ctx)
          if ctx.method == 'test' then
            eq('v:lua.vim.lsp.tagfunc', get_buf_option('tagfunc', BUFFER_1))
            eq('v:lua.vim.lsp.omnifunc', get_buf_option('omnifunc', BUFFER_2))
            eq('v:lua.vim.lsp.formatexpr()', get_buf_option('formatexpr', BUFFER_2))
            client:stop()
          end
        end,
        on_exit = function(_, _)
          eq('', get_buf_option('tagfunc', BUFFER_1))
          eq('', get_buf_option('omnifunc', BUFFER_2))
          eq('', get_buf_option('formatexpr', BUFFER_2))
        end,
      }
    end)

    it('should not overwrite user-defined options', function()
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'set_defaults_all_capabilities',
        on_init = function(_client)
          client = _client
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_option_value('tagfunc', 'tfu', { buf = _G.BUFFER })
            vim.api.nvim_set_option_value('omnifunc', 'ofu', { buf = _G.BUFFER })
            vim.api.nvim_set_option_value('formatexpr', 'fex', { buf = _G.BUFFER })
            vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
          end)
        end,
        on_handler = function(_, _, ctx)
          if ctx.method == 'test' then
            eq('tfu', get_buf_option('tagfunc'))
            eq('ofu', get_buf_option('omnifunc'))
            eq('fex', get_buf_option('formatexpr'))
            client:stop()
          end
        end,
        on_exit = function(_, _)
          eq('tfu', get_buf_option('tagfunc'))
          eq('ofu', get_buf_option('omnifunc'))
          eq('fex', get_buf_option('formatexpr'))
        end,
      }
    end)

    it('should detach buffer on bufwipe', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local bufnr1 = vim.api.nvim_create_buf(false, true)
        local bufnr2 = vim.api.nvim_create_buf(false, true)
        local detach_called1 = false
        local detach_called2 = false
        vim.api.nvim_create_autocmd('LspDetach', {
          buf = bufnr1,
          callback = function()
            detach_called1 = true
          end,
        })
        vim.api.nvim_create_autocmd('LspDetach', {
          buf = bufnr2,
          callback = function()
            detach_called2 = true
          end,
        })
        vim.api.nvim_set_current_buf(bufnr1)
        local client_id = assert(vim.lsp.start({ name = 'detach-dummy', cmd = server.cmd }))
        local client = assert(vim.lsp.get_client_by_id(client_id))
        vim.api.nvim_set_current_buf(bufnr2)
        vim.lsp.start({ name = 'detach-dummy', cmd = server.cmd })
        assert(vim.tbl_count(client.attached_buffers) == 2)
        vim.api.nvim_buf_delete(bufnr1, { force = true })
        assert(vim.tbl_count(client.attached_buffers) == 1)
        vim.api.nvim_buf_delete(bufnr2, { force = true })
        assert(vim.tbl_count(client.attached_buffers) == 0)
        return detach_called1 and detach_called2
      end)
      eq(true, result)
    end)

    it('should not re-attach buffer if it was deleted in on_init #28575', function()
      exec_lua(create_server_definition)
      exec_lua(function()
        local server = _G._create_server({
          handlers = {
            initialize = function(_, _, callback)
              vim.schedule(function()
                callback(nil, { capabilities = {} })
              end)
            end,
          },
        })
        local bufnr = vim.api.nvim_create_buf(false, true)
        local on_init_called = false
        local client_id = assert(vim.lsp.start({
          name = 'detach-dummy',
          cmd = server.cmd,
          on_init = function()
            vim.api.nvim_buf_delete(bufnr, {})
            on_init_called = true
          end,
        }))
        vim.lsp.buf_attach_client(bufnr, client_id)
        local ok = vim.wait(1000, function()
          return on_init_called
        end)
        assert(ok, 'on_init was not called')
      end)
    end)

    it('should allow on_lines + nvim_buf_delete during LSP initialization #28575', function()
      exec_lua(create_server_definition)
      exec_lua(function()
        local initialized = false
        local server = _G._create_server({
          handlers = {
            initialize = function(_, _, callback)
              vim.schedule(function()
                callback(nil, { capabilities = {} })
                initialized = true
              end)
            end,
          },
        })
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
        vim.lsp.start({
          name = 'detach-dummy',
          cmd = server.cmd,
        })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'hello' })
        vim.api.nvim_buf_delete(bufnr, {})
        local ok = vim.wait(1000, function()
          return initialized
        end)
        assert(ok, 'lsp did not initialize')
      end)
    end)

    it('client should return settings via workspace/configuration handler', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        {
          NIL,
          {
            items = {
              { section = 'testSetting1' },
              { section = 'testSetting2' },
              { section = 'test.Setting3' },
              { section = 'test.Setting4' },
              {},
              { section = '' },
            },
          },
          { method = 'workspace/configuration', client_id = 1 },
        },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'check_workspace_configuration',
        on_init = function(_client)
          client = _client
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'start' then
            exec_lua(function()
              local client0 = vim.lsp.get_client_by_id(_G.TEST_RPC_CLIENT_ID)
              client0.settings = {
                testSetting1 = true,
                testSetting2 = false,
                test = { Setting3 = 'nested' },
              }
            end)
          end
          if ctx.method == 'workspace/configuration' then
            local server_result = exec_lua(
              [[
              local method, params = ...
              return require 'vim.lsp.handlers'['workspace/configuration'](
                err,
                params,
                { method = method, client_id = _G.TEST_RPC_CLIENT_ID }
              )
              ]],
              ctx.method,
              result
            )
            client:notify('workspace/configuration', server_result)
          end
          if ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it(
      'workspace/configuration returns NIL per section if client was started without config.settings',
      function()
        local result = nil
        test_rpc_server {
          test_name = 'basic_init',
          on_init = function(c)
            c.stop()
          end,
          on_setup = function()
            result = exec_lua(function()
              local result0 = {
                items = {
                  { section = 'foo' },
                  { section = 'bar' },
                },
              }
              return vim.lsp.handlers['workspace/configuration'](
                nil,
                result0,
                { client_id = _G.TEST_RPC_CLIENT_ID }
              )
            end)
          end,
        }
        eq({ NIL, NIL }, result)
      end
    )

    it('should verify capabilities sent', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'basic_check_capabilities',
        on_init = function(client)
          client:stop()
          local full_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Full
          end)
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq({ includeText = false }, client.server_capabilities().textDocumentSync.save)
          eq(false, client.server_capabilities().codeLensProvider)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(...)
          eq(table.remove(expected_handlers), { ... }, 'expected handler')
        end,
      }
    end)

    it('BufWritePost sends didSave with bool textDocumentSync.save', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'text_document_sync_save_bool',
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
            exec_lua(function()
              _G.BUFFER = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
              vim.api.nvim_exec_autocmds('BufWritePost', { buf = _G.BUFFER, modeline = false })
            end)
          else
            client:stop()
          end
        end,
      }
    end)

    it('saveas sends didOpen to multiple attached servers if filename changed', function()
      local tmpfile_new = tmpname(false)
      exec_lua(create_server_definition)
      local messages = exec_lua(function()
        local server1 = _G._create_server()
        local server2 = _G._create_server()
        local client1_id = assert(vim.lsp.start({ name = 'dummy1', cmd = server1.cmd }))
        local client2_id = assert(vim.lsp.start({ name = 'dummy2', cmd = server2.cmd }))

        vim.cmd('saveas ' .. tmpfile_new)

        vim.lsp.get_client_by_id(client1_id):stop()
        vim.lsp.get_client_by_id(client2_id):stop()

        return {
          server1 = server1.messages,
          server2 = server2.messages,
        }
      end)
      eq('textDocument/didClose', messages.server1[3].method)
      eq('textDocument/didOpen', messages.server1[4].method)
      eq('textDocument/didSave', messages.server1[5].method)

      eq('textDocument/didClose', messages.server2[3].method)
      eq('textDocument/didOpen', messages.server2[4].method)
      eq('textDocument/didSave', messages.server2[5].method)
    end)

    it('BufWritePre does not send notifications if server lacks willSave capabilities', function()
      exec_lua(create_server_definition)
      local messages = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            textDocumentSync = {
              willSave = false,
              willSaveWaitUntil = false,
            },
          },
        })
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_exec_autocmds('BufWritePre', { buf = buf, modeline = false })
        vim.lsp.get_client_by_id(client_id):stop()
        return server.messages
      end)
      eq(4, #messages)
      eq('initialize', messages[1].method)
      eq('initialized', messages[2].method)
      eq('shutdown', messages[3].method)
      eq('exit', messages[4].method)
    end)

    it('BufWritePre sends willSave / willSaveWaitUntil, applies textEdits', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            textDocumentSync = {
              willSave = true,
              willSaveWaitUntil = true,
            },
          },
          handlers = {
            ['textDocument/willSaveWaitUntil'] = function(_, _, callback)
              local text_edit = {
                range = {
                  start = { line = 0, character = 0 },
                  ['end'] = { line = 0, character = 0 },
                },
                newText = 'Hello',
              }
              callback(nil, { text_edit })
            end,
          },
        })
        local buf = vim.api.nvim_get_current_buf()
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        vim.api.nvim_exec_autocmds('BufWritePre', { buf = buf, modeline = false })
        vim.lsp.get_client_by_id(client_id):stop()
        return {
          messages = server.messages,
          lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true),
        }
      end)
      local messages = result.messages
      eq('textDocument/willSave', messages[3].method)
      eq('textDocument/willSaveWaitUntil', messages[4].method)
      eq({ 'Hello' }, result.lines)
    end)

    it('saveas sends didOpen if filename changed', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
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
            local tmpfile_old = tmpname()
            local tmpfile_new = tmpname(false)
            exec_lua(function()
              _G.BUFFER = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_name(_G.BUFFER, tmpfile_old)
              vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, true, { 'help me' })
              vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
              vim._with({ buf = _G.BUFFER }, function()
                vim.cmd('saveas ' .. tmpfile_new)
              end)
            end)
          else
            client:stop()
          end
        end,
      })
    end)

    it('BufWritePost sends didSave including text if server capability is set', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'text_document_sync_save_includeText',
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
            exec_lua(function()
              _G.BUFFER = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, true, { 'help me' })
              vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
              vim.api.nvim_exec_autocmds('BufWritePost', { buf = _G.BUFFER, modeline = false })
            end)
          else
            client:stop()
          end
        end,
      }
    end)

    it('client:supports_methods() should validate capabilities', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'capabilities_for_client_supports_method',
        on_init = function(client)
          client:stop()
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
          eq(true, client:supports_method('textDocument/hover'))
          eq(false, client:supports_method('textDocument/definition'))

          -- unknown methods are assumed to be supported.
          eq(true, client:supports_method('unknown-method'))
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(...)
          eq(table.remove(expected_handlers), { ... }, 'expected handler')
        end,
      }
    end)

    it('should not call unsupported_method when trying to call an unsupported method', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'capabilities_for_client_supports_method',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_get_current_buf()
            vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID)
            vim.lsp.handlers['textDocument/typeDefinition'] = function() end
            vim.cmd(_G.BUFFER .. 'bwipeout')
          end)
        end,
        on_init = function(client)
          client:stop()
          exec_lua(function()
            vim.lsp.buf.type_definition()
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(...)
          eq(table.remove(expected_handlers), { ... }, 'expected handler')
        end,
      }
    end)

    it(
      'should not call unsupported_method when no client and trying to call an unsupported method',
      function()
        local expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
        }
        test_rpc_server {
          test_name = 'capabilities_for_client_supports_method',
          on_setup = function()
            exec_lua(function()
              vim.lsp.handlers['textDocument/typeDefinition'] = function() end
            end)
          end,
          on_init = function(client)
            client:stop()
            exec_lua(function()
              vim.lsp.buf.type_definition()
            end)
          end,
          on_exit = function(code, signal)
            eq(0, code, 'exit code')
            eq(0, signal, 'exit signal')
          end,
          on_handler = function(...)
            eq(table.remove(expected_handlers), { ... }, 'expected handler')
          end,
        }
      end
    )

    it('should not forward RequestCancelled to callback', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'check_forward_request_cancelled',
        on_init = function(_client)
          _client:request('error_code_test')
          client = _client
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
          eq(0, #expected_handlers, 'did not call expected handler')
        end,
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), { err, {}, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should forward ServerCancelled to callback', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          { code = -32802 },
          NIL,
          { method = 'error_code_test', bufnr = 1, client_id = 1, request_id = 2, version = 0 },
        },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'check_forward_server_cancelled',
        on_init = function(_client)
          _client:request('error_code_test')
          client = _client
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
          eq(0, #expected_handlers, 'did not call expected handler')
        end,
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), { err, _, ctx }, 'expected handler')
          if ctx.method ~= 'finish' then
            client:notify('finish')
          end
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should forward ContentModified to callback', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          { code = -32801 },
          NIL,
          { method = 'error_code_test', bufnr = 1, client_id = 1, request_id = 2, version = 0 },
        },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'check_forward_content_modified',
        on_init = function(_client)
          _client:request('error_code_test')
          client = _client
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
          eq(0, #expected_handlers, 'did not call expected handler')
        end,
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), { err, _, ctx }, 'expected handler')
          if ctx.method ~= 'finish' then
            client:notify('finish')
          end
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should track pending requests to the language server', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          NIL,
          {},
          { method = 'slow_request', bufnr = 1, client_id = 1, request_id = 2, version = 0 },
        },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'check_pending_request_tracked',
        on_init = function(_client)
          client = _client
          client:request('slow_request')
          local request = exec_lua(function()
            return _G.TEST_RPC_CLIENT.requests[2]
          end)
          eq('slow_request', request.method)
          eq('pending', request.type)
          client:notify('release')
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
          eq(0, #expected_handlers, 'did not call expected handler')
        end,
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), { err, {}, ctx }, 'expected handler')
          if ctx.method == 'slow_request' then
            local request = exec_lua(function()
              return _G.TEST_RPC_CLIENT.requests[2]
            end)
            eq(nil, request)
            client:notify('finish')
          end
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should track cancel requests to the language server', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'check_cancel_request_tracked',
        on_init = function(_client)
          client = _client
          client:request('slow_request')
          client:cancel_request(2)
          local request = exec_lua(function()
            return _G.TEST_RPC_CLIENT.requests[2]
          end)
          eq('slow_request', request.method)
          eq('cancel', request.type)
          client:notify('release')
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
          eq(0, #expected_handlers, 'did not call expected handler')
        end,
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), { err, {}, ctx }, 'expected handler')
          local request = exec_lua(function()
            return _G.TEST_RPC_CLIENT.requests[2]
          end)
          eq(nil, request)
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should clear pending and cancel requests on reply', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          NIL,
          {},
          { method = 'slow_request', bufnr = 1, client_id = 1, request_id = 2, version = 0 },
        },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'check_tracked_requests_cleared',
        on_init = function(_client)
          client = _client
          client:request('slow_request')
          local request = exec_lua(function()
            return _G.TEST_RPC_CLIENT.requests[2]
          end)
          eq('slow_request', request.method)
          eq('pending', request.type)
          client:cancel_request(2)
          request = exec_lua(function()
            return _G.TEST_RPC_CLIENT.requests[2]
          end)
          eq('slow_request', request.method)
          eq('cancel', request.type)
          client:notify('release')
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
          eq(0, #expected_handlers, 'did not call expected handler')
        end,
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), { err, {}, ctx }, 'expected handler')
          if ctx.method == 'slow_request' then
            local request = exec_lua(function()
              return _G.TEST_RPC_CLIENT.requests[2]
            end)
            eq(nil, request)
            client:notify('finish')
          end
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('request should not be pending for sync responses (in-process LS)', function()
      --- @type boolean
      local pending_request = exec_lua(function()
        local function server(dispatchers)
          local closing = false
          local srv = {}
          local request_id = 0

          function srv.request(method, _params, callback, notify_reply_callback)
            if method == 'textDocument/formatting' then
              callback(nil, {})
            elseif method == 'initialize' then
              callback(nil, {
                capabilities = {
                  textDocument = {
                    formatting = true,
                  },
                },
              })
            elseif method == 'shutdown' then
              callback(nil, nil)
            end
            request_id = request_id + 1
            if notify_reply_callback then
              notify_reply_callback(request_id)
            end
            return true, request_id
          end

          function srv.notify(method)
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

        local client_id = assert(vim.lsp.start({ cmd = server }))
        local client = assert(vim.lsp.get_client_by_id(client_id))

        local ok, request_id = client:request('textDocument/formatting', {})
        assert(ok)

        local has_pending = client.requests[request_id] ~= nil
        vim.lsp.get_client_by_id(client_id):stop()

        return has_pending
      end)

      eq(false, pending_request, 'expected no pending requests')
    end)

    it('should trigger LspRequest autocmd when requests table changes', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          NIL,
          {},
          { method = 'slow_request', bufnr = 1, client_id = 1, request_id = 2, version = 0 },
        },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'check_tracked_requests_cleared',
        on_init = function(_client)
          command('let g:requests = 0')
          command('autocmd LspRequest * let g:requests+=1')
          client = _client
          client:request('slow_request')
          eq(1, eval('g:requests'))
          client:cancel_request(2)
          eq(2, eval('g:requests'))
          client:notify('release')
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
          eq(0, #expected_handlers, 'did not call expected handler')
          eq(3, eval('g:requests'))
        end,
        on_handler = function(err, _, ctx)
          eq(table.remove(expected_handlers), { err, {}, ctx }, 'expected handler')
          if ctx.method == 'slow_request' then
            client:notify('finish')
          end
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should not send didOpen if the buffer closes before init', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_finish',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
            assert(_G.TEST_RPC_CLIENT_ID == 1)
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
            assert(vim.lsp.buf_is_attached(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
            vim.cmd(_G.BUFFER .. 'bwipeout')
          end)
        end,
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Full
          end)
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          client:notify('finish')
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should check the body sent attaching before init', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Full
          end)
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(
              vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID),
              'Already attached, returns true'
            )
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should check the body sent attaching after init', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Full
          end)
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should check the body and didChange full', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open_and_change',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Full
          end)
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua(function()
              vim.api.nvim_buf_set_lines(_G.BUFFER, 1, 2, false, {
                'boop',
              })
            end)
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should check the body and didChange full with noeol', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open_and_change_noeol',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
            vim.bo[_G.BUFFER].eol = false
          end)
        end,
        on_init = function(_client)
          client = _client
          local full_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Full
          end)
          eq(full_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua(function()
              vim.api.nvim_buf_set_lines(_G.BUFFER, 1, 2, false, {
                'boop',
              })
            end)
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should send correct range for inlay hints with noeol', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          NIL,
          {},
          {
            method = 'textDocument/inlayHint',
            params = {
              textDocument = {
                uri = 'file://',
              },
              range = {
                start = { line = 0, character = 0 },
                ['end'] = { line = 1, character = 3 },
              },
            },
            bufnr = 2,
            client_id = 1,
            request_id = 2,
            version = 0,
          },
        },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'inlay_hint',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
            vim.bo[_G.BUFFER].eol = false
          end)
        end,
        on_init = function(_client)
          client = _client
          eq(true, client:supports_method('textDocument/inlayHint'))
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua(function()
              vim.lsp.inlay_hint.enable(true, { bufnr = _G.BUFFER })
            end)
          end
          if ctx.method == 'textDocument/inlayHint' then
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should check the body and didChange incremental', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open_and_change_incremental',
        options = {
          allow_incremental_sync = true,
        },
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Incremental
          end)
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua(function()
              vim.api.nvim_buf_set_lines(_G.BUFFER, 1, 2, false, {
                '123boop',
              })
            end)
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should check the body and didChange incremental with debounce', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open_and_change_incremental',
        options = {
          allow_incremental_sync = true,
          debounce_text_changes = 5,
        },
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Incremental
          end)
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua(function()
              vim.api.nvim_buf_set_lines(_G.BUFFER, 1, 2, false, {
                '123boop',
              })
            end)
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    -- TODO(askhan) we don't support full for now, so we can disable these tests.
    pending('should check the body and didChange incremental normal mode editing', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', bufnr = 1, client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open_and_change_incremental_editing',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Incremental
          end)
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            n.command('normal! 1Go')
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should check the body and didChange full with 2 changes', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open_and_change_multi',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Full
          end)
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua(function()
              vim.api.nvim_buf_set_lines(_G.BUFFER, 1, 2, false, {
                '321',
              })
              vim.api.nvim_buf_set_lines(_G.BUFFER, 1, 2, false, {
                'boop',
              })
            end)
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('should check the body and didChange full lifecycle', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_check_buffer_open_and_change_multi_and_close',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          local sync_kind = exec_lua(function()
            return require 'vim.lsp.protocol'.TextDocumentSyncKind.Full
          end)
          eq(sync_kind, client.server_capabilities().textDocumentSync.change)
          eq(true, client.server_capabilities().textDocumentSync.openClose)
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          if ctx.method == 'start' then
            exec_lua(function()
              vim.api.nvim_buf_set_lines(_G.BUFFER, 1, 2, false, {
                '321',
              })
              vim.api.nvim_buf_set_lines(_G.BUFFER, 1, 2, false, {
                'boop',
              })
              vim.api.nvim_command(_G.BUFFER .. 'bwipeout')
            end)
            client:notify('finish')
          end
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)

    it('vim.lsp.start when existing client has no workspace_folders', function()
      exec_lua(create_server_definition)
      eq(
        { 2, 'foo', 'foo' },
        exec_lua(function()
          local server = _G._create_server()
          vim.lsp.start { cmd = server.cmd, name = 'foo' }
          vim.lsp.start { cmd = server.cmd, name = 'foo', root_dir = 'bar' }
          local foos = vim.lsp.get_clients()
          return { #foos, foos[1].name, foos[2].name }
        end)
      )
    end)
  end)

  describe('parsing tests', function()
    local body = '{"jsonrpc":"2.0","id": 1,"method":"demo"}'

    before_each(function()
      exec_lua(create_tcp_echo_server)
    end)

    it('should catch error while parsing invalid header', function()
      -- No whitespace is allowed between the header field-name and colon.
      -- See https://datatracker.ietf.org/doc/html/rfc7230#section-3.2.4
      local field = 'Content-Length : 10 \r\n'
      exec_lua(function()
        _G._send_msg_to_server(field .. '\r\n')
      end)
      verify_single_notification(function(method, args) ---@param args [string, number]
        eq('error', method)
        eq(1, args[2])
        matches(vim.pesc('Content-Length not found in header: ' .. field) .. '$', args[1])
      end)
    end)

    it('value of Content-Length shoud be number', function()
      local value = '123 foo'
      exec_lua(function()
        _G._send_msg_to_server('Content-Length: ' .. value .. '\r\n\r\n')
      end)
      verify_single_notification(function(method, args) ---@param args [string, number]
        eq('error', method)
        eq(1, args[2])
        matches('value of Content%-Length is not number: ' .. value .. '$', args[1])
      end)
    end)

    it('field name is case-insensitive', function()
      exec_lua(function()
        _G._send_msg_to_server('CONTENT-Length: ' .. #body .. ' \r\n\r\n' .. body)
      end)
      verify_single_notification(function(method, args) ---@param args [string]
        eq('body', method)
        eq(body, args[1])
      end)
    end)

    it("ignore some lines ending with LF that don't contain content-length", function()
      exec_lua(function()
        _G._send_msg_to_server(
          'foo \n bar\nWARN: no common words.\nContent-Length: ' .. #body .. ' \r\n\r\n' .. body
        )
      end)
      verify_single_notification(function(method, args) ---@param args [string]
        eq('body', method)
        eq(body, args[1])
      end)
    end)

    it('should not trim vim.NIL from the end of a list', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          NIL,
          {
            arguments = { 'EXTRACT_METHOD', { metadata = { field = vim.NIL } }, 3, 0, 6123, NIL },
            command = 'refactor.perform',
            title = 'EXTRACT_METHOD',
          },
          { method = 'workspace/executeCommand', client_id = 1 },
        },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'decode_nil',
        on_setup = function()
          exec_lua(function()
            _G.BUFFER = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(_G.BUFFER, 0, -1, false, {
              'testing',
              '123',
            })
          end)
        end,
        on_init = function(_client)
          client = _client
          exec_lua(function()
            assert(vim.lsp.buf_attach_client(_G.BUFFER, _G.TEST_RPC_CLIENT_ID))
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
          if ctx.method == 'finish' then
            client:stop()
          end
        end,
      }
    end)
  end)

  describe('apply vscode text_edits', function()
    it('single replace', function()
      insert('012345678901234567890123456789')
      apply_text_edits({
        { 0, 3, 0, 6, { 'Hello' } },
      })
      eq({ '012Hello678901234567890123456789' }, buf_lines(1))
    end)

    it('two replaces', function()
      insert('012345678901234567890123456789')
      apply_text_edits({
        { 0, 3, 0, 6, { 'Hello' } },
        { 0, 6, 0, 9, { 'World' } },
      })
      eq({ '012HelloWorld901234567890123456789' }, buf_lines(1))
    end)

    it('same start pos insert are kept in order', function()
      insert('012345678901234567890123456789')
      apply_text_edits({
        { 0, 3, 0, 3, { 'World' } },
        { 0, 3, 0, 3, { 'Hello' } },
      })
      eq({ '012WorldHello345678901234567890123456789' }, buf_lines(1))
    end)

    it('same start pos insert and replace are kept in order', function()
      insert('012345678901234567890123456789')
      apply_text_edits({
        { 0, 3, 0, 3, { 'World' } },
        { 0, 3, 0, 3, { 'Hello' } },
        { 0, 3, 0, 8, { 'No' } },
      })
      eq({ '012WorldHelloNo8901234567890123456789' }, buf_lines(1))
    end)

    it('multiline', function()
      exec_lua(function()
        vim.api.nvim_buf_set_lines(1, 0, 0, true, { '  {', '    "foo": "bar"', '  }' })
      end)
      eq({ '  {', '    "foo": "bar"', '  }', '' }, buf_lines(1))
      apply_text_edits({
        { 0, 0, 3, 0, { '' } },
        { 3, 0, 3, 0, { '{\n' } },
        { 3, 0, 3, 0, { '  "foo": "bar"\n' } },
        { 3, 0, 3, 0, { '}\n' } },
      })
      eq({ '{', '  "foo": "bar"', '}', '' }, buf_lines(1))
    end)
  end)

  describe('apply_text_edits', function()
    local buffer_text = {
      'First line of text',
      'Second line of text',
      'Third line of text',
      'Fourth line of text',
      'å å ɧ 汉语 ↥ 🤦 🦄',
    }

    before_each(function()
      insert(dedent(table.concat(buffer_text, '\n')))
    end)

    it('applies simple edits', function()
      apply_text_edits({
        { 0, 0, 0, 0, { '123' } },
        { 1, 0, 1, 1, { '2' } },
        { 2, 0, 2, 2, { '3' } },
        { 3, 2, 3, 4, { '' } },
      })
      eq({
        '123First line of text',
        '2econd line of text',
        '3ird line of text',
        'Foth line of text',
        'å å ɧ 汉语 ↥ 🤦 🦄',
      }, buf_lines(1))
    end)

    it('applies complex edits', function()
      apply_text_edits({
        { 0, 0, 0, 0, { '', '12' } },
        { 0, 0, 0, 0, { '3', 'foo' } },
        { 0, 1, 0, 1, { 'bar', '123' } },
        { 0, #'First ', 0, #'First line of text', { 'guy' } },
        { 1, 0, 1, #'Second', { 'baz' } },
        { 2, #'Th', 2, #'Third', { 'e next' } },
        { 3, #'', 3, #'Fourth', { 'another line of text', 'before this' } },
        { 3, #'Fourth', 3, #'Fourth line of text', { '!' } },
      })
      eq({
        '',
        '123',
        'fooFbar',
        '123irst guy',
        'baz line of text',
        'The next line of text',
        'another line of text',
        'before this!',
        'å å ɧ 汉语 ↥ 🤦 🦄',
      }, buf_lines(1))
    end)

    it('applies complex edits (reversed range)', function()
      apply_text_edits({
        { 0, 0, 0, 0, { '', '12' } },
        { 0, 0, 0, 0, { '3', 'foo' } },
        { 0, 1, 0, 1, { 'bar', '123' } },
        { 0, #'First line of text', 0, #'First ', { 'guy' } },
        { 1, #'Second', 1, 0, { 'baz' } },
        { 2, #'Third', 2, #'Th', { 'e next' } },
        { 3, #'Fourth', 3, #'', { 'another line of text', 'before this' } },
        { 3, #'Fourth line of text', 3, #'Fourth', { '!' } },
      })
      eq({
        '',
        '123',
        'fooFbar',
        '123irst guy',
        'baz line of text',
        'The next line of text',
        'another line of text',
        'before this!',
        'å å ɧ 汉语 ↥ 🤦 🦄',
      }, buf_lines(1))
    end)

    it('applies non-ASCII characters edits', function()
      apply_text_edits({
        { 4, 3, 4, 4, { 'ä' } },
      })
      eq({
        'First line of text',
        'Second line of text',
        'Third line of text',
        'Fourth line of text',
        'å ä ɧ 汉语 ↥ 🤦 🦄',
      }, buf_lines(1))
    end)

    it('applies text edits at the end of the document', function()
      apply_text_edits({
        { 5, 0, 5, 0, 'foobar' },
      })
      eq({
        'First line of text',
        'Second line of text',
        'Third line of text',
        'Fourth line of text',
        'å å ɧ 汉语 ↥ 🤦 🦄',
        'foobar',
      }, buf_lines(1))
    end)

    it('applies multiple text edits at the end of the document', function()
      apply_text_edits({
        { 4, 0, 5, 0, '' },
        { 5, 0, 5, 0, 'foobar' },
      })
      eq({
        'First line of text',
        'Second line of text',
        'Third line of text',
        'Fourth line of text',
        'foobar',
      }, buf_lines(1))
    end)

    it('it restores marks', function()
      eq(true, api.nvim_buf_set_mark(1, 'a', 2, 1, {}))
      apply_text_edits({
        { 1, 0, 2, 5, 'foobar' },
        { 4, 0, 5, 0, 'barfoo' },
      })
      eq({
        'First line of text',
        'foobar line of text',
        'Fourth line of text',
        'barfoo',
      }, buf_lines(1))
      eq({ 2, 1 }, api.nvim_buf_get_mark(1, 'a'))
    end)

    it('it restores marks to last valid col', function()
      eq(true, api.nvim_buf_set_mark(1, 'a', 2, 10, {}))
      apply_text_edits({
        { 1, 0, 2, 15, 'foobar' },
        { 4, 0, 5, 0, 'barfoo' },
      })
      eq({
        'First line of text',
        'foobarext',
        'Fourth line of text',
        'barfoo',
      }, buf_lines(1))
      eq({ 2, 9 }, api.nvim_buf_get_mark(1, 'a'))
    end)

    it('it restores marks to last valid line', function()
      eq(true, api.nvim_buf_set_mark(1, 'a', 4, 1, {}))
      apply_text_edits({
        { 1, 0, 4, 5, 'foobar' },
        { 4, 0, 5, 0, 'barfoo' },
      })
      eq({
        'First line of text',
        'foobaro',
      }, buf_lines(1))
      eq({ 2, 1 }, api.nvim_buf_get_mark(1, 'a'))
    end)

    it('applies edit based on confirmation response', function()
      --- @type lsp.AnnotatedTextEdit
      local edit = make_edit(0, 0, 5, 0, 'foo')
      edit.annotationId = 'annotation-id'

      local function test(response)
        exec_lua(function()
          ---@diagnostic disable-next-line: duplicate-set-field
          vim.fn.confirm = function()
            return response
          end

          vim.lsp.util.apply_text_edits(
            { edit },
            1,
            'utf-16',
            { ['annotation-id'] = { label = 'Insert "foo"', needsConfirmation = true } }
          )
        end, { response })
      end

      test(2) -- 2 = No
      eq(buffer_text, buf_lines(1))

      test(1) -- 1 = Yes
      eq({ 'foo' }, buf_lines(1))
    end)

    describe('cursor position', function()
      it("don't fix the cursor if the range contains the cursor", function()
        api.nvim_win_set_cursor(0, { 2, 6 })
        apply_text_edits({
          { 1, 0, 1, 19, 'Second line of text' },
        })
        eq({
          'First line of text',
          'Second line of text',
          'Third line of text',
          'Fourth line of text',
          'å å ɧ 汉语 ↥ 🤦 🦄',
        }, buf_lines(1))
        eq({ 2, 6 }, api.nvim_win_get_cursor(0))
      end)

      it('fix the cursor to the valid col if the content was removed', function()
        api.nvim_win_set_cursor(0, { 2, 6 })
        apply_text_edits({
          { 1, 0, 1, 6, '' },
          { 1, 6, 1, 19, '' },
        })
        eq({
          'First line of text',
          '',
          'Third line of text',
          'Fourth line of text',
          'å å ɧ 汉语 ↥ 🤦 🦄',
        }, buf_lines(1))
        eq({ 2, 0 }, api.nvim_win_get_cursor(0))
      end)

      it('fix the cursor to the valid row if the content was removed', function()
        api.nvim_win_set_cursor(0, { 2, 6 })
        apply_text_edits({
          { 1, 0, 1, 6, '' },
          { 0, 18, 5, 0, '' },
        })
        eq({
          'First line of text',
        }, buf_lines(1))
        eq({ 1, 17 }, api.nvim_win_get_cursor(0))
      end)

      it('fix the cursor row', function()
        api.nvim_win_set_cursor(0, { 3, 0 })
        apply_text_edits({
          { 1, 0, 2, 0, '' },
        })
        eq({
          'First line of text',
          'Third line of text',
          'Fourth line of text',
          'å å ɧ 汉语 ↥ 🤦 🦄',
        }, buf_lines(1))
        eq({ 2, 0 }, api.nvim_win_get_cursor(0))
      end)

      it('fix the cursor col', function()
        -- append empty last line. See #22636
        api.nvim_buf_set_lines(1, -1, -1, true, { '' })

        api.nvim_win_set_cursor(0, { 2, 11 })
        apply_text_edits({
          { 1, 7, 1, 11, '' },
        })
        eq({
          'First line of text',
          'Second  of text',
          'Third line of text',
          'Fourth line of text',
          'å å ɧ 汉语 ↥ 🤦 🦄',
          '',
        }, buf_lines(1))
        eq({ 2, 7 }, api.nvim_win_get_cursor(0))
      end)

      it('fix the cursor row and col', function()
        api.nvim_win_set_cursor(0, { 2, 12 })
        apply_text_edits({
          { 0, 11, 1, 12, '' },
        })
        eq({
          'First line of text',
          'Third line of text',
          'Fourth line of text',
          'å å ɧ 汉语 ↥ 🤦 🦄',
        }, buf_lines(1))
        eq({ 1, 11 }, api.nvim_win_get_cursor(0))
      end)
    end)

    describe('with LSP end line after what Vim considers to be the end line', function()
      it('applies edits when the last linebreak is considered a new line', function()
        apply_text_edits({
          { 0, 0, 5, 0, { 'All replaced' } },
        })
        eq({ 'All replaced' }, buf_lines(1))
      end)

      it("applies edits when the end line is 2 larger than vim's", function()
        apply_text_edits({
          { 0, 0, 6, 0, { 'All replaced' } },
        })
        eq({ 'All replaced' }, buf_lines(1))
      end)

      it('applies edits with a column offset', function()
        apply_text_edits({
          { 0, 0, 5, 2, { 'All replaced' } },
        })
        eq({ 'All replaced' }, buf_lines(1))
      end)
    end)
  end)

  describe('apply_text_edits regression tests for #20116', function()
    before_each(function()
      insert(dedent([[
      Test line one
      Test line two 21 char]]))
    end)

    describe('with LSP end column out of bounds and start column at 0', function()
      it('applies edits at the end of the buffer', function()
        apply_text_edits({
          { 0, 0, 1, 22, { '#include "whatever.h"\r\n#include <algorithm>\r' } },
        }, 'utf-8')
        eq({ '#include "whatever.h"', '#include <algorithm>' }, buf_lines(1))
      end)

      it('applies edits in the middle of the buffer', function()
        apply_text_edits({
          { 0, 0, 0, 22, { '#include "whatever.h"\r\n#include <algorithm>\r' } },
        }, 'utf-8')
        eq(
          { '#include "whatever.h"', '#include <algorithm>', 'Test line two 21 char' },
          buf_lines(1)
        )
      end)
    end)

    describe('with LSP end column out of bounds and start column NOT at 0', function()
      it('applies edits at the end of the buffer', function()
        apply_text_edits({
          { 0, 2, 1, 22, { '#include "whatever.h"\r\n#include <algorithm>\r' } },
        }, 'utf-8')
        eq({ 'Te#include "whatever.h"', '#include <algorithm>' }, buf_lines(1))
      end)

      it('applies edits in the middle of the buffer', function()
        apply_text_edits({
          { 0, 2, 0, 22, { '#include "whatever.h"\r\n#include <algorithm>\r' } },
        }, 'utf-8')
        eq(
          { 'Te#include "whatever.h"', '#include <algorithm>', 'Test line two 21 char' },
          buf_lines(1)
        )
      end)
    end)
  end)

  describe('apply_text_document_edit', function()
    local target_bufnr --- @type integer

    local text_document_edit = function(editVersion)
      return {
        edits = {
          make_edit(0, 0, 0, 3, 'First ↥ 🤦 🦄'),
        },
        textDocument = {
          uri = 'file:///fake/uri',
          version = editVersion,
        },
      }
    end

    before_each(function()
      target_bufnr = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri')
        local lines = { '1st line of text', '2nd line of 语text' }
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      end)
    end)

    it('correctly goes ahead with the edit if all is normal', function()
      exec_lua(function(text_edit)
        vim.lsp.util.apply_text_document_edit(text_edit, nil, 'utf-16')
      end, text_document_edit(5))
      eq({
        'First ↥ 🤦 🦄 line of text',
        '2nd line of 语text',
      }, buf_lines(target_bufnr))
    end)

    it('always accepts edit with version = 0', function()
      exec_lua(function(text_edit)
        vim.lsp.util.buf_versions[target_bufnr] = 10
        vim.lsp.util.apply_text_document_edit(text_edit, nil, 'utf-16')
      end, text_document_edit(0))
      eq({
        'First ↥ 🤦 🦄 line of text',
        '2nd line of 语text',
      }, buf_lines(target_bufnr))
    end)

    it('skips the edit if the version of the edit is behind the local buffer ', function()
      local apply_edit_mocking_current_version = function(edit, versionedBuf)
        exec_lua(function()
          vim.lsp.util.buf_versions[versionedBuf.bufnr] = versionedBuf.currentVersion
          vim.lsp.util.apply_text_document_edit(edit, nil, 'utf-16')
        end)
      end

      local baseText = {
        '1st line of text',
        '2nd line of 语text',
      }

      eq(baseText, buf_lines(target_bufnr))

      -- Apply an edit for an old version, should skip
      apply_edit_mocking_current_version(
        text_document_edit(2),
        { currentVersion = 7, bufnr = target_bufnr }
      )
      eq(baseText, buf_lines(target_bufnr)) -- no change

      -- Sanity check that next version to current does apply change
      apply_edit_mocking_current_version(
        text_document_edit(8),
        { currentVersion = 7, bufnr = target_bufnr }
      )
      eq({
        'First ↥ 🤦 🦄 line of text',
        '2nd line of 语text',
      }, buf_lines(target_bufnr))
    end)
  end)

  describe('workspace_apply_edit', function()
    it('workspace/applyEdit returns ApplyWorkspaceEditResponse', function()
      local expected_handlers = {
        { NIL, {}, { method = 'test', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'basic_init',
        on_init = function(client, _)
          client:stop()
        end,
        -- If the program timed out, then code will be nil.
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        -- Note that NIL must be used here.
        -- on_handler(err, method, result, client_id)
        on_handler = function(...)
          local expected = {
            applied = true,
            failureReason = nil,
          }
          eq(
            expected,
            exec_lua(function()
              local apply_edit = {
                label = nil,
                edit = {},
              }
              return vim.lsp.handlers['workspace/applyEdit'](
                nil,
                apply_edit,
                { client_id = _G.TEST_RPC_CLIENT_ID }
              )
            end)
          )
          eq(table.remove(expected_handlers), { ... })
        end,
      }
    end)
  end)

  describe('apply_workspace_edit', function()
    local replace_line_edit = function(row, new_line, editVersion)
      return {
        edits = {
          -- NOTE: This is a hack if you have a line longer than 1000 it won't replace it
          make_edit(row, 0, row, 1000, new_line),
        },
        textDocument = {
          uri = 'file:///fake/uri',
          version = editVersion,
        },
      }
    end

    -- Some servers send all the edits separately, but with the same version.
    -- We should not stop applying the edits
    local make_workspace_edit = function(changes)
      return {
        documentChanges = changes,
      }
    end

    local target_bufnr --- @type integer
    local changedtick --- @type integer

    before_each(function()
      exec_lua(function()
        target_bufnr = vim.uri_to_bufnr('file:///fake/uri')
        local lines = {
          'Original Line #1',
          'Original Line #2',
        }

        vim.api.nvim_buf_set_lines(target_bufnr, 0, -1, false, lines)

        local function update_changed_tick()
          vim.lsp.util.buf_versions[target_bufnr] = vim.b[target_bufnr].changedtick
        end

        update_changed_tick()
        vim.api.nvim_buf_attach(target_bufnr, false, {
          on_changedtick = update_changed_tick,
        })

        changedtick = vim.b[target_bufnr].changedtick
      end)
    end)

    it('apply_workspace_edit applies a single edit', function()
      local new_lines = {
        'First Line',
      }

      local edits = {}
      for row, line in ipairs(new_lines) do
        table.insert(edits, replace_line_edit(row - 1, line, changedtick))
      end

      eq(
        {
          'First Line',
          'Original Line #2',
        },
        exec_lua(function(workspace_edits)
          vim.lsp.util.apply_workspace_edit(workspace_edits, 'utf-16')

          return vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false)
        end, make_workspace_edit(edits))
      )
      eq(true, api.nvim_get_option_value('buflisted', { buf = target_bufnr }))
    end)

    it('apply_workspace_edit applies multiple edits', function()
      local new_lines = {
        'First Line',
        'Second Line',
      }

      local edits = {}
      for row, line in ipairs(new_lines) do
        table.insert(edits, replace_line_edit(row - 1, line, changedtick))
      end

      eq(
        new_lines,
        exec_lua(function(workspace_edits)
          vim.lsp.util.apply_workspace_edit(workspace_edits, 'utf-16')
          return vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false)
        end, make_workspace_edit(edits))
      )
    end)

    it('supports file creation with CreateFile payload', function()
      local tmpfile = tmpname(false)
      local uri = exec_lua('return vim.uri_from_fname(...)', tmpfile)
      local edit = {
        documentChanges = {
          {
            kind = 'create',
            uri = uri,
          },
        },
      }
      exec_lua(function()
        vim.lsp.util.apply_workspace_edit(edit, 'utf-16')
      end)
      eq(true, vim.uv.fs_stat(tmpfile) ~= nil)
    end)

    it(
      'supports file creation in folder that needs to be created with CreateFile payload',
      function()
        local tmpfile = tmpname(false) .. '/dummy/x/'
        local uri = exec_lua('return vim.uri_from_fname(...)', tmpfile)
        local edit = {
          documentChanges = {
            {
              kind = 'create',
              uri = uri,
            },
          },
        }
        exec_lua(function()
          vim.lsp.util.apply_workspace_edit(edit, 'utf-16')
        end)
        eq(true, vim.uv.fs_stat(tmpfile) ~= nil)
      end
    )

    it('createFile does not touch file if it exists and ignoreIfExists is set', function()
      local tmpfile = tmpname()
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
        },
      }
      exec_lua('vim.lsp.util.apply_workspace_edit(...)', edit, 'utf-16')
      eq(true, vim.uv.fs_stat(tmpfile) ~= nil)
      eq('Dummy content', read_file(tmpfile))
    end)

    it('createFile overrides file if overwrite is set', function()
      local tmpfile = tmpname()
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
        },
      }
      exec_lua('vim.lsp.util.apply_workspace_edit(...)', edit, 'utf-16')
      eq(true, vim.uv.fs_stat(tmpfile) ~= nil)
      eq('', read_file(tmpfile))
    end)

    it('DeleteFile delete file and buffer', function()
      local tmpfile = tmpname()
      write_file(tmpfile, 'Be gone')
      local uri = exec_lua(function()
        local bufnr = vim.fn.bufadd(tmpfile)
        vim.fn.bufload(bufnr)
        return vim.uri_from_fname(tmpfile)
      end)
      local edit = {
        documentChanges = {
          {
            kind = 'delete',
            uri = uri,
          },
        },
      }
      eq(true, pcall(exec_lua, 'vim.lsp.util.apply_workspace_edit(...)', edit, 'utf-16'))
      eq(false, vim.uv.fs_stat(tmpfile) ~= nil)
      eq(false, api.nvim_buf_is_loaded(fn.bufadd(tmpfile)))
    end)

    it('DeleteFile fails if file does not exist and ignoreIfNotExists is false', function()
      local tmpfile = tmpname(false)
      local uri = exec_lua('return vim.uri_from_fname(...)', tmpfile)
      local edit = {
        documentChanges = {
          {
            kind = 'delete',
            uri = uri,
            options = {
              ignoreIfNotExists = false,
            },
          },
        },
      }
      eq(false, pcall(exec_lua, 'vim.lsp.util.apply_workspace_edit(...)', edit, 'utf-16'))
      eq(false, vim.uv.fs_stat(tmpfile) ~= nil)
    end)
  end)

  describe('vim.lsp.tagfunc', function()
    before_each(function()
      ---@type lsp.Location[]
      local mock_locations = {
        {
          range = {
            ['start'] = { line = 5, character = 23 },
            ['end'] = { line = 10, character = 0 },
          },
          uri = 'test://buf',
        },
        {
          range = {
            ['start'] = { line = 42, character = 10 },
            ['end'] = { line = 44, character = 0 },
          },
          uri = 'test://another-file',
        },
      }
      exec_lua(create_server_definition)
      exec_lua(function()
        _G.mock_locations = mock_locations
        _G.server = _G._create_server({
          ---@type lsp.ServerCapabilities
          capabilities = {
            definitionProvider = true,
            workspaceSymbolProvider = true,
          },
          handlers = {
            ---@return lsp.Location[]
            ['textDocument/definition'] = function(_, _, callback)
              callback(nil, { _G.mock_locations[1] })
            end,
            ---@return lsp.WorkspaceSymbol[]
            ['workspace/symbol'] = function(_, request, callback)
              assert(request.query == 'foobar')
              callback(nil, {
                {
                  name = 'foobar',
                  kind = 13, ---@type lsp.SymbolKind
                  location = _G.mock_locations[1],
                },
                {
                  name = 'vim.foobar',
                  kind = 12, ---@type lsp.SymbolKind
                  location = _G.mock_locations[2],
                },
              })
            end,
          },
        })
        _G.client_id = vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd })
      end)
    end)

    after_each(function()
      exec_lua(function()
        vim.lsp.get_client_by_id(_G.client_id):stop()
      end)
    end)

    it('with flags=c, returns matching tags using textDocument/definition', function()
      local result = exec_lua(function()
        return vim.lsp.tagfunc('foobar', 'c')
      end)
      eq({
        {
          cmd = '/\\%6l\\%1c/', -- for location (5, 23)
          filename = 'test://buf',
          name = 'foobar',
        },
      }, result)
    end)

    it('without flags=c, returns all matching tags using workspace/symbol', function()
      local result = exec_lua(function()
        return vim.lsp.tagfunc('foobar', '')
      end)
      eq({
        {
          cmd = '/\\%6l\\%1c/', -- for location (5, 23)
          filename = 'test://buf',
          kind = 'Variable',
          name = 'foobar',
        },
        {
          cmd = '/\\%43l\\%1c/', -- for location (42, 10)
          filename = 'test://another-file',
          kind = 'Function',
          name = 'vim.foobar',
        },
      }, result)
    end)

    it('with flags including i, returns NIL', function()
      exec_lua(function()
        local result = vim.lsp.tagfunc('foobar', 'cir')
        assert(result == vim.NIL, 'should not issue LSP requests')
        return {}
      end)
    end)
  end)

  describe('cmd', function()
    it('connects to lsp server via rpc.connect using ip address', function()
      exec_lua(create_tcp_echo_server)
      exec_lua(function()
        local port = _G._create_tcp_server('127.0.0.1')
        vim.lsp.start({ name = 'dummy', cmd = vim.lsp.rpc.connect('127.0.0.1', port) })
      end)
      verify_single_notification(function(method, args) ---@param args [string]
        eq('body', method)
        eq('initialize', vim.json.decode(args[1]).method)
      end)
    end)

    it('connects to lsp server via rpc.connect using hostname', function()
      skip(is_os('bsd'), 'issue with host resolution in ci')
      skip(t.is_arch('s390x'), 'issue with host resolution in ci')
      exec_lua(create_tcp_echo_server)
      exec_lua(function()
        local port = _G._create_tcp_server('::1')
        vim.lsp.start({ name = 'dummy', cmd = vim.lsp.rpc.connect('localhost', port) })
      end)
      verify_single_notification(function(method, args) ---@param args [string]
        eq('body', method)
        eq('initialize', vim.json.decode(args[1]).method)
      end)
    end)

    it('can connect to lsp server via pipe or domain_socket', function()
      local tmpfile = is_os('win') and '\\\\.\\\\pipe\\pipe.test' or tmpname(false)
      local result = exec_lua(function()
        local uv = vim.uv
        local server = assert(uv.new_pipe(false))
        server:bind(tmpfile)
        local init = nil

        server:listen(127, function(err)
          assert(not err, err)
          local client = assert(vim.uv.new_pipe())
          server:accept(client)
          client:read_start(require('vim.lsp.rpc').create_read_loop(function(body)
            init = body
            client:close()
          end))
        end)
        vim.lsp.start({ name = 'dummy', cmd = vim.lsp.rpc.connect(tmpfile) })
        vim.wait(1000, function()
          return init ~= nil
        end)
        assert(init, 'server must receive `initialize` request')
        server:close()
        server:shutdown()
        return vim.json.decode(init)
      end)
      eq('initialize', result.method)
    end)
  end)

  describe('handlers', function()
    it('handler can return false as response', function()
      local result = exec_lua(function()
        local server = assert(vim.uv.new_tcp())
        local messages = {}
        local responses = {}
        server:bind('127.0.0.1', 0)
        server:listen(127, function(err)
          assert(not err, err)
          local socket = assert(vim.uv.new_tcp())
          server:accept(socket)
          socket:read_start(require('vim.lsp.rpc').create_read_loop(function(body)
            local payload = vim.json.decode(body)
            if payload.method then
              table.insert(messages, payload.method)
              if payload.method == 'initialize' then
                local msg = vim.json.encode({
                  id = payload.id,
                  jsonrpc = '2.0',
                  result = {
                    capabilities = {},
                  },
                })
                socket:write(table.concat({ 'Content-Length: ', tostring(#msg), '\r\n\r\n', msg }))
              elseif payload.method == 'initialized' then
                local msg = vim.json.encode({
                  id = 10,
                  jsonrpc = '2.0',
                  method = 'dummy',
                  params = {},
                })
                socket:write(table.concat({ 'Content-Length: ', tostring(#msg), '\r\n\r\n', msg }))
              end
            else
              table.insert(responses, payload)
              socket:close()
            end
          end))
        end)
        local port = server:getsockname().port
        local handler_called = false
        vim.lsp.handlers['dummy'] = function(_, _)
          handler_called = true
          return false
        end
        local client_id =
          assert(vim.lsp.start({ name = 'dummy', cmd = vim.lsp.rpc.connect('127.0.0.1', port) }))
        vim.lsp.get_client_by_id(client_id)
        vim.wait(1000, function()
          return #messages == 2 and handler_called and #responses == 1
        end)
        server:close()
        server:shutdown()
        return {
          messages = messages,
          handler_called = handler_called,
          responses = responses,
        }
      end)
      local expected = {
        messages = { 'initialize', 'initialized' },
        handler_called = true,
        responses = {
          {
            id = 10,
            jsonrpc = '2.0',
            result = false,
          },
        },
      }
      eq(expected, result)
    end)

    --- Starts a TCP server that completes initialization, then sends `null_id_payload` after the
    --- "initialized" notification. If `notification_method` is given, registers a handler
    --- that tracks whether it was dispatched as a notification.
    ---
    --- @param null_id_payload string JSON
    --- @param notification_method? string
    --- @return { on_error_called: table, notification_received: boolean, messages: boolean }.
    local function test_null_id_response(null_id_payload, notification_method)
      return exec_lua(function()
        local server = assert(vim.uv.new_tcp())
        local accepted
        local messages = {}
        server:bind('127.0.0.1', 0)
        server:listen(127, function(err)
          assert(not err, err)
          accepted = assert(vim.uv.new_tcp())
          server:accept(accepted)
          accepted:read_start(require('vim.lsp.rpc').create_read_loop(function(body)
            local payload = vim.json.decode(body)
            if payload.method then
              table.insert(messages, payload.method)
              if payload.method == 'initialize' then
                -- Send a valid initialize response first
                local msg = vim.json.encode({
                  id = payload.id,
                  jsonrpc = '2.0',
                  result = {
                    capabilities = {},
                  },
                })
                accepted:write(
                  table.concat({ 'Content-Length: ', tostring(#msg), '\r\n\r\n', msg })
                )
              elseif payload.method == 'initialized' then
                accepted:write(table.concat({
                  'Content-Length: ',
                  tostring(#null_id_payload),
                  '\r\n\r\n',
                  null_id_payload,
                }))
              end
            end
          end, function()
            if accepted and not accepted:is_closing() then
              accepted:close()
            end
          end, function()
            if accepted and not accepted:is_closing() then
              accepted:close()
            end
          end))
        end)
        local port = server:getsockname().port
        local on_error_called = false
        local notification_received = false
        local handlers = nil
        if notification_method then
          handlers = {
            [notification_method] = function()
              notification_received = true
              return {}
            end,
          }
        end
        local client_id = assert(vim.lsp.start({
          name = 'null-id-test',
          cmd = vim.lsp.rpc.connect('127.0.0.1', port),
          on_error = function(_code, _err)
            on_error_called = true
          end,
          handlers = handlers,
        }))
        vim.lsp.get_client_by_id(client_id)
        vim.wait(1000, function()
          return #messages >= 2 and (on_error_called or notification_received)
        end)
        if accepted and not accepted:is_closing() then
          accepted:close()
        end
        server:shutdown()
        server:close()
        return {
          messages = messages,
          on_error_called = on_error_called,
          notification_received = notification_received,
        }
      end)
    end

    it('null-id in response (JSON-RPC 2.0 parse error) is handled, emits error', function()
      local result = test_null_id_response(
        '{"jsonrpc":"2.0","error":{"code":-32700,"message":"Parse error"},"id":null}'
      )
      eq(true, result.on_error_called)
      eq(true, #result.messages >= 2)
    end)

    it('null-id in response does not misclassify as a notification', function()
      -- Sanity check: a real notification (no id) dispatches the handler.
      local valid = test_null_id_response(
        '{"jsonrpc":"2.0","method":"workspace/configuration","params":{"items":[]}}',
        'workspace/configuration'
      )
      eq(true, valid.notification_received)

      local result = test_null_id_response(
        -- Error response with null id (parse error per JSON-RPC 2.0 §5)
        '{"jsonrpc":"2.0","method":"workspace/configuration","params":{"items":[]},"id":null}',
        'workspace/configuration'
      )
      -- Should be dispatched as an error, NOT silently handled as a notification.
      eq(true, result.on_error_called)
      -- Null id must NOT be dispatched as a notification.
      eq(false, result.notification_received)
    end)
  end)

  describe('#dynamic vim.lsp._dynamic', function()
    it('supports dynamic registration', function()
      local root_dir = tmpname(false)
      mkdir(root_dir)
      local tmpfile = root_dir .. '/dynamic.foo'
      local file = io.open(tmpfile, 'w')
      if file then
        file:close()
      end

      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local client_id = assert(vim.lsp.start({
          name = 'dynamic-test',
          cmd = server.cmd,
          root_dir = root_dir,
          get_language_id = function()
            return 'dummy-lang'
          end,
          capabilities = {
            textDocument = {
              formatting = {
                dynamicRegistration = true,
              },
              rangeFormatting = {
                dynamicRegistration = true,
              },
            },
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
              didChangeConfiguration = {
                dynamicRegistration = true,
              },
            },
          },
        }))

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'formatting',
              method = 'textDocument/formatting',
              registerOptions = {
                documentSelector = {
                  {
                    pattern = root_dir .. '/*.foo',
                  },
                },
              },
            },
          },
        }, { client_id = client_id })

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'range-formatting',
              method = 'textDocument/rangeFormatting',
              registerOptions = {
                documentSelector = {
                  {
                    language = 'dummy-lang',
                  },
                },
              },
            },
          },
        }, { client_id = client_id })

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'completion',
              method = 'textDocument/completion',
            },
          },
        }, { client_id = client_id })

        local result = {}
        local function check(method, fname, ...)
          local bufnr = fname and vim.fn.bufadd(fname) or nil
          local client = assert(vim.lsp.get_client_by_id(client_id))
          local keys = { ... }
          local caps = {}
          if #keys > 0 then
            client:_provider_foreach(method, function(cap)
              table.insert(caps, vim.tbl_get(cap, unpack(keys)) or vim.NIL)
            end)
          end
          result[#result + 1] = {
            method = method,
            fname = fname,
            supported = client:supports_method(method, bufnr),
            cap = #keys > 0 and caps or nil,
          }
        end

        check('textDocument/formatting')
        check('textDocument/formatting', tmpfile)
        check('textDocument/rangeFormatting')
        check('textDocument/rangeFormatting', tmpfile)
        check('textDocument/completion')

        check('workspace/didChangeWatchedFiles')
        check('workspace/didChangeWatchedFiles', tmpfile)

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'didChangeWatched',
              method = 'workspace/didChangeWatchedFiles',
              registerOptions = {
                watchers = {
                  {
                    globPattern = 'something',
                    kind = 4,
                  },
                },
              },
            },
          },
        }, { client_id = client_id })

        check('workspace/didChangeWatchedFiles')
        check('workspace/didChangeWatchedFiles', tmpfile)

        -- Initial support false
        check('workspace/diagnostic')

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'diag1',
              method = 'textDocument/diagnostic',
              registerOptions = {
                identifier = 'diag-ident-1',
                -- workspaceDiagnostics field omitted
              },
            },
          },
        }, { client_id = client_id })

        -- Checks after registering without workspaceDiagnostics support
        -- Returns false
        check('workspace/diagnostic', nil, 'identifier')

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'diag2',
              method = 'textDocument/diagnostic',
              registerOptions = {
                identifier = 'diag-ident-2',
                workspaceDiagnostics = true,
              },
            },
          },
        }, { client_id = client_id })

        -- Check after second registration with support
        -- Returns true
        check('workspace/diagnostic', nil, 'identifier')

        vim.lsp.handlers['client/unregisterCapability'](nil, {
          unregisterations = {
            { id = 'diag2', method = 'textDocument/diagnostic' },
          },
        }, { client_id = client_id })

        -- Check after unregistering
        -- Returns false
        check('workspace/diagnostic', nil, 'identifier')

        check('textDocument/codeAction')
        check('codeAction/resolve')

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'codeAction',
              method = 'textDocument/codeAction',
              registerOptions = {
                resolveProvider = true,
              },
            },
          },
        }, { client_id = client_id })

        check('textDocument/codeAction')
        check('codeAction/resolve')

        check('workspace/didChangeWorkspaceFolders')
        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'didChangeWorkspaceFolders-id',
              method = 'workspace/didChangeWorkspaceFolders',
            },
          },
        }, { client_id = client_id })
        check('workspace/didChangeWorkspaceFolders')

        check('workspace/didChangeConfiguration')
        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'didChangeConfiguration-id',
              method = 'workspace/didChangeConfiguration',
              registerOptions = {
                section = 'dummy-section',
              },
            },
          },
        }, { client_id = client_id })
        check('workspace/didChangeConfiguration', nil, 'section')

        return result
      end)

      eq(21, #result)
      eq({ method = 'textDocument/formatting', supported = false }, result[1])
      eq({ method = 'textDocument/formatting', supported = true, fname = tmpfile }, result[2])
      eq({ method = 'textDocument/rangeFormatting', supported = true }, result[3])
      eq({ method = 'textDocument/rangeFormatting', supported = true, fname = tmpfile }, result[4])
      eq({ method = 'textDocument/completion', supported = false }, result[5])
      eq({ method = 'workspace/didChangeWatchedFiles', supported = false }, result[6])
      eq(
        { method = 'workspace/didChangeWatchedFiles', supported = false, fname = tmpfile },
        result[7]
      )
      eq({ method = 'workspace/didChangeWatchedFiles', supported = true }, result[8])
      eq(
        { method = 'workspace/didChangeWatchedFiles', supported = true, fname = tmpfile },
        result[9]
      )
      eq({ method = 'workspace/diagnostic', supported = false }, result[10])
      eq({ method = 'workspace/diagnostic', supported = false, cap = {} }, result[11])
      eq({
        method = 'workspace/diagnostic',
        supported = true,
        cap = { 'diag-ident-2' },
      }, result[12])
      eq({ method = 'workspace/diagnostic', supported = false, cap = {} }, result[13])
      eq({ method = 'textDocument/codeAction', supported = false }, result[14])
      eq({ method = 'codeAction/resolve', supported = false }, result[15])
      eq({ method = 'textDocument/codeAction', supported = true }, result[16])
      eq({ method = 'codeAction/resolve', supported = true }, result[17])
      eq({ method = 'workspace/didChangeWorkspaceFolders', supported = false }, result[18])
      eq({ method = 'workspace/didChangeWorkspaceFolders', supported = true }, result[19])
      eq({ method = 'workspace/didChangeConfiguration', supported = false }, result[20])
      eq(
        { method = 'workspace/didChangeConfiguration', supported = true, cap = { 'dummy-section' } },
        result[21]
      )
    end)

    it('identifies client dynamic registration capability', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local client_id = assert(vim.lsp.start({
          name = 'dynamic-test',
          cmd = server.cmd,
          capabilities = {
            textDocument = {
              formatting = {
                dynamicRegistration = true,
              },
              synchronization = {
                dynamicRegistration = true,
              },
              diagnostic = {
                dynamicRegistration = true,
              },
            },
          },
        }))

        local result = {}
        local function check(method)
          local client = assert(vim.lsp.get_client_by_id(client_id))
          result[#result + 1] = {
            method = method,
            supports_reg = client:_supports_registration(method),
          }
        end

        check('textDocument/formatting')
        check('textDocument/didSave')
        check('textDocument/didOpen')
        check('textDocument/codeLens')
        check('textDocument/diagnostic')
        check('workspace/diagnostic')

        return result
      end)

      eq(6, #result)
      eq({ method = 'textDocument/formatting', supports_reg = true }, result[1])
      eq({ method = 'textDocument/didSave', supports_reg = true }, result[2])
      eq({ method = 'textDocument/didOpen', supports_reg = true }, result[3])
      eq({ method = 'textDocument/codeLens', supports_reg = false }, result[4])
      eq({ method = 'textDocument/diagnostic', supports_reg = true }, result[5])
      eq({ method = 'workspace/diagnostic', supports_reg = true }, result[6])
    end)

    it('supports static registration', function()
      exec_lua(create_server_definition)

      local client_id = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            colorProvider = { id = 'color-registration' },
            diagnosticProvider = {
              id = 'diag-registration',
              identifier = 'diag-ident-static',
              workspaceDiagnostics = true,
            },
          },
        })

        return assert(vim.lsp.start({ name = 'dynamic-test', cmd = server.cmd }))
      end)

      local function sort_method(tbl)
        local result_t = vim.deepcopy(tbl)
        table.sort(result_t, function(a, b)
          return (a.method or '') < (b.method or '')
        end)
        return result_t
      end

      eq(
        {
          {
            id = 'color-registration',
            method = 'textDocument/colorPresentation',
            registerOptions = { id = 'color-registration' },
          },
          {
            id = 'color-registration',
            method = 'textDocument/documentColor',
            registerOptions = { id = 'color-registration' },
          },
        },
        sort_method(exec_lua(function()
          local client = assert(vim.lsp.get_client_by_id(client_id))
          return client.dynamic_capabilities:get('colorProvider')
        end))
      )

      eq(
        {
          {
            id = 'diag-registration',
            method = 'textDocument/diagnostic',
            registerOptions = {
              id = 'diag-registration',
              identifier = 'diag-ident-static',
              workspaceDiagnostics = true,
            },
          },
        },
        sort_method(exec_lua(function()
          local client = assert(vim.lsp.get_client_by_id(client_id))
          return client.dynamic_capabilities:get('diagnosticProvider')
        end))
      )

      eq(
        { 'diag-ident-static' },
        exec_lua(function()
          local client = assert(vim.lsp.get_client_by_id(client_id))
          local result = {}
          client:_provider_foreach('textDocument/diagnostic', function(cap)
            table.insert(result, cap.identifier)
          end)
          return result
        end)
      )
    end)
  end)

  describe('vim.lsp._watchfiles', function()
    --- @type integer, integer, integer
    local created, changed, deleted

    setup(function()
      n.clear()
      created = exec_lua([[return vim.lsp.protocol.FileChangeType.Created]])
      changed = exec_lua([[return vim.lsp.protocol.FileChangeType.Changed]])
      deleted = exec_lua([[return vim.lsp.protocol.FileChangeType.Deleted]])
    end)

    local function test_filechanges(watchfunc)
      it(
        string.format('sends notifications when files change (watchfunc=%s)', watchfunc),
        function()
          if watchfunc == 'inotify' then
            skip(is_os('win'), 'not supported on windows')
            skip(is_os('mac'), 'flaky test on mac')
            skip(
              not is_ci() and fn.executable('inotifywait') == 0,
              'inotify-tools not installed and not on CI'
            )
            skip(t.is_arch('s390x'), 'inotifywait not available on s390x CI')
          end

          if watchfunc == 'watch' then
            skip(is_os('mac'), 'flaky test on mac')
            skip(
              is_os('bsd'),
              'Stopped working on bsd after 3ca967387c49c754561c3b11a574797504d40f38'
            )
          else
            skip(
              is_os('bsd'),
              'kqueue only reports events on watched folder itself, not contained files #26110'
            )
          end

          local root_dir = tmpname(false)
          mkdir(root_dir)

          exec_lua(create_server_definition)
          local result = exec_lua(function()
            local server = _G._create_server()
            local client_id = assert(vim.lsp.start({
              name = 'watchfiles-test',
              cmd = server.cmd,
              root_dir = root_dir,
              capabilities = {
                workspace = {
                  didChangeWatchedFiles = {
                    dynamicRegistration = true,
                  },
                },
              },
            }))

            require('vim.lsp._watchfiles')._watchfunc = require('vim._watch')[watchfunc]

            local expected_messages = 0

            local msg_wait_timeout = watchfunc == 'watch' and 200 or 2500

            local function wait_for_message(incr)
              expected_messages = expected_messages + (incr or 1)
              assert(
                vim.wait(msg_wait_timeout, function()
                  return #server.messages == expected_messages
                end),
                'Timed out waiting for expected number of messages. Current messages seen so far: '
                  .. vim.inspect(server.messages)
              )
            end

            wait_for_message(2) -- initialize, initialized

            vim.lsp.handlers['client/registerCapability'](nil, {
              registrations = {
                {
                  id = 'watchfiles-test-0',
                  method = 'workspace/didChangeWatchedFiles',
                  registerOptions = {
                    watchers = {
                      {
                        globPattern = '**/watch',
                        kind = 7,
                      },
                    },
                  },
                },
              },
            }, { client_id = client_id })

            if watchfunc ~= 'watch' then
              vim.wait(100)
            end

            local path = root_dir .. '/watch'
            local tmp = vim.fn.tempname()
            io.open(tmp, 'w'):close()
            vim.uv.fs_rename(tmp, path)

            wait_for_message()

            os.remove(path)

            wait_for_message()

            vim.lsp.get_client_by_id(client_id):stop()

            return server.messages
          end)

          local uri = vim.uri_from_fname(root_dir .. '/watch')

          eq(6, #result)

          eq({
            method = 'workspace/didChangeWatchedFiles',
            params = {
              changes = {
                {
                  type = created,
                  uri = uri,
                },
              },
            },
          }, result[3])

          eq({
            method = 'workspace/didChangeWatchedFiles',
            params = {
              changes = {
                {
                  type = deleted,
                  uri = uri,
                },
              },
            },
          }, result[4])
        end
      )
    end

    test_filechanges('watch')
    test_filechanges('watchdirs')
    test_filechanges('inotify')

    it('correctly registers and unregisters', function()
      local root_dir = '/some_dir'
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local client_id = assert(vim.lsp.start({
          name = 'watchfiles-test',
          cmd = server.cmd,
          root_dir = root_dir,
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
            },
          },
        }))

        local expected_messages = 2 -- initialize, initialized
        local function wait_for_messages()
          assert(
            vim.wait(200, function()
              return #server.messages == expected_messages
            end),
            'Timed out waiting for expected number of messages. Current messages seen so far: '
              .. vim.inspect(server.messages)
          )
        end

        wait_for_messages()

        local send_event --- @type function
        require('vim.lsp._watchfiles')._watchfunc = function(_, _, callback)
          local stopped = false
          send_event = function(...)
            if not stopped then
              callback(...)
            end
          end
          return function()
            stopped = true
          end
        end

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'watchfiles-test-0',
              method = 'workspace/didChangeWatchedFiles',
              registerOptions = {
                watchers = {
                  {
                    globPattern = '**/*.watch0',
                  },
                },
              },
            },
          },
        }, { client_id = client_id })

        send_event(root_dir .. '/file.watch0', vim._watch.FileChangeType.Created)
        send_event(root_dir .. '/file.watch1', vim._watch.FileChangeType.Created)

        expected_messages = expected_messages + 1
        wait_for_messages()

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'watchfiles-test-1',
              method = 'workspace/didChangeWatchedFiles',
              registerOptions = {
                watchers = {
                  {
                    globPattern = '**/*.watch1',
                  },
                },
              },
            },
          },
        }, { client_id = client_id })

        vim.lsp.handlers['client/unregisterCapability'](nil, {
          unregisterations = {
            {
              id = 'watchfiles-test-0',
              method = 'workspace/didChangeWatchedFiles',
            },
          },
        }, { client_id = client_id })

        send_event(root_dir .. '/file.watch0', vim._watch.FileChangeType.Created)
        send_event(root_dir .. '/file.watch1', vim._watch.FileChangeType.Created)

        expected_messages = expected_messages + 1
        wait_for_messages()

        return server.messages
      end)

      local function watched_uri(fname)
        return vim.uri_from_fname(root_dir .. '/' .. fname)
      end

      eq(4, #result)
      eq('workspace/didChangeWatchedFiles', result[3].method)
      eq({
        changes = {
          {
            type = created,
            uri = watched_uri('file.watch0'),
          },
        },
      }, result[3].params)
      eq('workspace/didChangeWatchedFiles', result[4].method)
      eq({
        changes = {
          {
            type = created,
            uri = watched_uri('file.watch1'),
          },
        },
      }, result[4].params)
    end)

    it('correctly handles the registered watch kind', function()
      local root_dir = 'some_dir'
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local client_id = assert(vim.lsp.start({
          name = 'watchfiles-test',
          cmd = server.cmd,
          root_dir = root_dir,
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
            },
          },
        }))

        local expected_messages = 2 -- initialize, initialized
        local function wait_for_messages()
          assert(
            vim.wait(200, function()
              return #server.messages == expected_messages
            end),
            'Timed out waiting for expected number of messages. Current messages seen so far: '
              .. vim.inspect(server.messages)
          )
        end

        wait_for_messages()

        local watch_callbacks = {} --- @type function[]
        local function send_event(...)
          for _, cb in ipairs(watch_callbacks) do
            cb(...)
          end
        end
        require('vim.lsp._watchfiles')._watchfunc = function(_, _, callback)
          table.insert(watch_callbacks, callback)
          return function()
            -- noop because this test never stops the watch
          end
        end

        local protocol = require('vim.lsp.protocol')

        local watchers = {}
        local max_kind = protocol.WatchKind.Create
          + protocol.WatchKind.Change
          + protocol.WatchKind.Delete
        for i = 0, max_kind do
          table.insert(watchers, {
            globPattern = {
              baseUri = vim.uri_from_fname('/dir'),
              pattern = 'watch' .. tostring(i),
            },
            kind = i,
          })
        end
        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'watchfiles-test-kind',
              method = 'workspace/didChangeWatchedFiles',
              registerOptions = {
                watchers = watchers,
              },
            },
          },
        }, { client_id = client_id })

        for i = 0, max_kind do
          local filename = '/dir/watch' .. tostring(i)
          send_event(filename, vim._watch.FileChangeType.Created)
          send_event(filename, vim._watch.FileChangeType.Changed)
          send_event(filename, vim._watch.FileChangeType.Deleted)
        end

        expected_messages = expected_messages + 1
        wait_for_messages()

        return server.messages
      end)

      local function watched_uri(fname)
        return vim.uri_from_fname('/dir/' .. fname)
      end

      eq(3, #result)
      eq('workspace/didChangeWatchedFiles', result[3].method)
      eq({
        changes = {
          {
            type = created,
            uri = watched_uri('watch1'),
          },
          {
            type = changed,
            uri = watched_uri('watch2'),
          },
          {
            type = created,
            uri = watched_uri('watch3'),
          },
          {
            type = changed,
            uri = watched_uri('watch3'),
          },
          {
            type = deleted,
            uri = watched_uri('watch4'),
          },
          {
            type = created,
            uri = watched_uri('watch5'),
          },
          {
            type = deleted,
            uri = watched_uri('watch5'),
          },
          {
            type = changed,
            uri = watched_uri('watch6'),
          },
          {
            type = deleted,
            uri = watched_uri('watch6'),
          },
          {
            type = created,
            uri = watched_uri('watch7'),
          },
          {
            type = changed,
            uri = watched_uri('watch7'),
          },
          {
            type = deleted,
            uri = watched_uri('watch7'),
          },
        },
      }, result[3].params)
    end)

    it('prunes duplicate events', function()
      local root_dir = 'some_dir'
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local client_id = assert(vim.lsp.start({
          name = 'watchfiles-test',
          cmd = server.cmd,
          root_dir = root_dir,
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
            },
          },
        }))

        local expected_messages = 2 -- initialize, initialized
        local function wait_for_messages()
          assert(
            vim.wait(200, function()
              return #server.messages == expected_messages
            end),
            'Timed out waiting for expected number of messages. Current messages seen so far: '
              .. vim.inspect(server.messages)
          )
        end

        wait_for_messages()

        local send_event --- @type function
        require('vim.lsp._watchfiles')._watchfunc = function(_, _, callback)
          send_event = callback
          return function()
            -- noop because this test never stops the watch
          end
        end

        vim.lsp.handlers['client/registerCapability'](nil, {
          registrations = {
            {
              id = 'watchfiles-test-kind',
              method = 'workspace/didChangeWatchedFiles',
              registerOptions = {
                watchers = {
                  {
                    globPattern = '**/*',
                  },
                },
              },
            },
          },
        }, { client_id = client_id })

        send_event('file1', vim._watch.FileChangeType.Created)
        send_event('file1', vim._watch.FileChangeType.Created) -- pruned
        send_event('file1', vim._watch.FileChangeType.Changed)
        send_event('file2', vim._watch.FileChangeType.Created)
        send_event('file1', vim._watch.FileChangeType.Changed) -- pruned

        expected_messages = expected_messages + 1
        wait_for_messages()

        return server.messages
      end)

      eq(3, #result)
      eq('workspace/didChangeWatchedFiles', result[3].method)
      eq({
        changes = {
          {
            type = created,
            uri = vim.uri_from_fname('file1'),
          },
          {
            type = changed,
            uri = vim.uri_from_fname('file1'),
          },
          {
            type = created,
            uri = vim.uri_from_fname('file2'),
          },
        },
      }, result[3].params)
    end)

    it("ignores registrations by servers when the client doesn't advertise support", function()
      exec_lua(create_server_definition)
      exec_lua(function()
        _G.server = _G._create_server()
        require('vim.lsp._watchfiles')._watchfunc = function(_, _, _)
          -- Since the registration is ignored, this should not execute and `watching` should stay false
          _G.watching = true
          return function() end
        end
      end)

      local function check_registered(capabilities)
        return exec_lua(function()
          _G.watching = false
          local client_id = assert(vim.lsp.start({
            name = 'watchfiles-test',
            cmd = _G.server.cmd,
            root_dir = 'some_dir',
            capabilities = capabilities,
          }, {
            reuse_client = function()
              return false
            end,
          }))

          vim.lsp.handlers['client/registerCapability'](nil, {
            registrations = {
              {
                id = 'watchfiles-test-kind',
                method = 'workspace/didChangeWatchedFiles',
                registerOptions = {
                  watchers = {
                    {
                      globPattern = '**/*',
                    },
                  },
                },
              },
            },
          }, { client_id = client_id })

          -- Ensure no errors occur when unregistering something that was never really registered.
          vim.lsp.handlers['client/unregisterCapability'](nil, {
            unregisterations = {
              {
                id = 'watchfiles-test-kind',
                method = 'workspace/didChangeWatchedFiles',
              },
            },
          }, { client_id = client_id })

          vim.lsp.get_client_by_id(client_id):stop(true)
          return _G.watching
        end)
      end

      eq(is_os('mac') or is_os('win'), check_registered(nil)) -- start{_client}() defaults to make_client_capabilities().
      eq(
        false,
        check_registered({
          workspace = {
            didChangeWatchedFiles = {
              dynamicRegistration = false,
            },
          },
        })
      )
      eq(
        true,
        check_registered({
          workspace = {
            didChangeWatchedFiles = {
              dynamicRegistration = true,
            },
          },
        })
      )
    end)
  end)

  describe('vim.lsp.config() and vim.lsp.enable()', function()
    ---@param names string[]
    local function get_resolved(names)
      return exec_lua(function(names_)
        local rv = {}
        local cs = vim.lsp._enabled_configs
        for _, k in ipairs(names_) do
          rv[k] = not not (cs[k] and cs[k].resolved_config)
        end
        return rv
      end, names)
    end

    it('merges settings from "*"', function()
      eq(
        {
          name = 'foo',
          cmd = { 'foo' },
          root_markers = { '.git' },
        },
        exec_lua(function()
          vim.lsp.config('*', { root_markers = { '.git' } })
          vim.lsp.config('foo', { cmd = { 'foo' } })

          return vim.lsp.config['foo']
        end)
      )
    end)

    it('config("bogus") shows a hint', function()
      matches(
        'hint%: to resolve a config',
        pcall_err(exec_lua, function()
          vim.print(vim.lsp.config('non-existent-config'))
        end)
      )
    end)

    it('sets up an autocmd', function()
      eq(
        1,
        exec_lua(function()
          vim.lsp.config('foo', {
            cmd = { 'foo' },
            root_markers = { '.foorc' },
          })
          vim.lsp.enable('foo')
          return #vim.api.nvim_get_autocmds({
            group = 'nvim.lsp.enable',
            event = 'FileType',
          })
        end)
      )
    end)

    it('handle nil config (some clients may not have a config!)', function()
      exec_lua(create_server_definition)
      exec_lua(function()
        local server = _G._create_server()
        vim.bo.filetype = 'lua'
        -- Attach a client without defining a config.
        local client_id = vim.lsp.start({
          name = 'test_ls',
          cmd = function(dispatchers, config)
            _G.test_resolved_root = config.root_dir --[[@type string]]
            return server.cmd(dispatchers, config)
          end,
        }, { bufnr = 0 })

        local bufnr = vim.api.nvim_get_current_buf()
        local client = vim.lsp.get_client_by_id(client_id)
        assert(client.attached_buffers[bufnr])

        -- Exercise the codepath which had a regression:
        vim.lsp.enable('test_ls')
        vim.api.nvim_exec_autocmds('FileType', { buf = bufnr })

        -- enable() does _not_ detach the client since it doesn't actually have a config.
        -- XXX: otoh, is it confusing to allow `enable("foo")` if there a "foo" _client_ without a "foo" _config_?
        assert(client.attached_buffers[bufnr])
        assert(client_id == vim.lsp.get_client_by_id(bufnr).id)
      end)
    end)

    it('attaches to buffers when they are opened', function()
      exec_lua(create_server_definition)

      local tmp1 = t.tmpname(true)
      local tmp2 = t.tmpname(true)

      exec_lua(function()
        local server = _G._create_server({
          handlers = {
            initialize = function(_, _, callback)
              callback(nil, { capabilities = {} })
            end,
          },
        })

        vim.lsp.config('foo', {
          cmd = server.cmd,
          filetypes = { 'foo' },
          root_markers = { '.foorc' },
        })

        vim.lsp.config('bar', {
          cmd = server.cmd,
          filetypes = { 'bar' },
          root_markers = { '.foorc' },
        })

        vim.lsp.enable('foo')
        vim.lsp.enable('bar')

        vim.cmd.edit(tmp1)
        vim.bo.filetype = 'foo'
        _G.foo_buf = vim.api.nvim_get_current_buf()

        vim.cmd.edit(tmp2)
        vim.bo.filetype = 'bar'
        _G.bar_buf = vim.api.nvim_get_current_buf()
      end)

      eq(
        { 1, 'foo', 1, 'bar' },
        exec_lua(function()
          local foos = vim.lsp.get_clients({ bufnr = assert(_G.foo_buf) })
          local bars = vim.lsp.get_clients({ bufnr = assert(_G.bar_buf) })
          return { #foos, foos[1].name, #bars, bars[1].name }
        end)
      )
    end)

    it('attaches/detaches preexisting buffers', function()
      exec_lua(create_server_definition)

      local tmp1 = t.tmpname(true)
      local tmp2 = t.tmpname(true)

      exec_lua(function()
        vim.cmd.edit(tmp1)
        vim.bo.filetype = 'foo'
        _G.foo_buf = vim.api.nvim_get_current_buf()

        vim.cmd.edit(tmp2)
        vim.bo.filetype = 'bar'
        _G.bar_buf = vim.api.nvim_get_current_buf()

        local server = _G._create_server({
          handlers = {
            initialize = function(_, _, callback)
              callback(nil, { capabilities = {} })
            end,
          },
        })

        vim.lsp.config('foo', {
          cmd = server.cmd,
          filetypes = { 'foo' },
          root_markers = { '.foorc' },
        })

        vim.lsp.config('bar', {
          cmd = server.cmd,
          filetypes = { 'bar' },
          root_markers = { '.foorc' },
        })

        vim.lsp.enable('foo')
        vim.lsp.enable('bar')
      end)

      eq(
        { 1, 'foo', 1, 'bar' },
        exec_lua(function()
          local foos = vim.lsp.get_clients({ bufnr = assert(_G.foo_buf) })
          local bars = vim.lsp.get_clients({ bufnr = assert(_G.bar_buf) })
          return { #foos, foos[1].name, #bars, bars[1].name }
        end)
      )

      -- Now disable the 'foo' lsp and confirm that it's detached from the buffer it was previous
      -- attached to.
      exec_lua([[vim.lsp.enable('foo', false)]])
      eq(
        { 0, 'foo', 1, 'bar' },
        exec_lua(function()
          local foos = vim.lsp.get_clients({ bufnr = assert(_G.foo_buf) })
          local bars = vim.lsp.get_clients({ bufnr = assert(_G.bar_buf) })
          return { #foos, 'foo', #bars, bars[1].name }
        end)
      )
    end)

    it('in first FileType event (on startup)', function()
      local tmp = tmpname()
      write_file(tmp, string.dump(create_server_definition))
      n.clear({
        args = {
          '--cmd',
          string.format([[lua assert(loadfile(%q))()]], tmp),
          '--cmd',
          [[lua _G.server = _G._create_server({ handlers = {initialize = function(_, _, callback) callback(nil, {capabilities = {}}) end} })]],
          '--cmd',
          [[lua vim.lsp.config('foo', { cmd = _G.server.cmd, filetypes = { 'foo' }, root_markers = { '.foorc' } })]],
          '--cmd',
          [[au FileType * ++once lua vim.lsp.enable('foo')]],
          '-c',
          'set ft=foo',
        },
      })

      eq(
        { 1, 'foo' },
        exec_lua(function()
          local foos = vim.lsp.get_clients({ bufnr = 0 })
          return { #foos, (foos[1] or {}).name }
        end)
      )
      exec_lua([[vim.lsp.enable('foo', false)]])
      eq(
        0,
        exec_lua(function()
          return #vim.lsp.get_clients({ bufnr = 0 })
        end)
      )
    end)

    it('does not attach to buffers more than once if no root_dir', function()
      exec_lua(create_server_definition)

      local tmp1 = t.tmpname(true)

      eq(
        1,
        exec_lua(function()
          local server = _G._create_server({
            handlers = {
              initialize = function(_, _, callback)
                callback(nil, { capabilities = {} })
              end,
            },
          })

          vim.lsp.config('foo', { cmd = server.cmd, filetypes = { 'foo' } })
          vim.lsp.enable('foo')

          vim.cmd.edit(assert(tmp1))
          vim.bo.filetype = 'foo'
          vim.bo.filetype = 'foo'

          return #vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
        end)
      )
    end)

    it('async root_dir, cmd(…,config) gets resolved config', function()
      exec_lua(create_server_definition)

      local tmp1 = t.tmpname(true)
      exec_lua(function()
        local server = _G._create_server({
          handlers = {
            initialize = function(_, _, callback)
              callback(nil, { capabilities = {} })
            end,
          },
        })

        vim.lsp.config('foo', {
          cmd = function(dispatchers, config)
            _G.test_resolved_root = config.root_dir --[[@type string]]
            return server.cmd(dispatchers, config)
          end,
          filetypes = { 'foo' },
          root_dir = function(bufnr, cb)
            assert(tmp1 == vim.api.nvim_buf_get_name(bufnr))
            vim.system({ 'sleep', '0' }, {}, function()
              cb('some_dir')
            end)
          end,
        })
        vim.lsp.enable('foo')

        vim.cmd.edit(assert(tmp1))
        vim.bo.filetype = 'foo'
      end)

      retry(nil, 1000, function()
        eq(
          'some_dir',
          exec_lua(function()
            return vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })[1].root_dir
          end)
        )
      end)
      eq(
        'some_dir',
        exec_lua(function()
          return _G.test_resolved_root
        end)
      )
    end)

    it('starts correct LSP and stops incorrect LSP when filetype changes', function()
      exec_lua(create_server_definition)

      local tmp1 = t.tmpname(true)

      exec_lua(function()
        local server = _G._create_server({
          handlers = {
            initialize = function(_, _, callback)
              callback(nil, { capabilities = {} })
            end,
          },
        })

        vim.lsp.config('foo', {
          cmd = server.cmd,
          filetypes = { 'foo' },
          root_markers = { '.foorc' },
        })

        vim.lsp.config('bar', {
          cmd = server.cmd,
          filetypes = { 'bar' },
          root_markers = { '.foorc' },
        })

        vim.lsp.enable('foo')
        vim.lsp.enable('bar')

        vim.cmd.edit(tmp1)
      end)

      local count_clients = function()
        return exec_lua(function()
          local foos = vim.lsp.get_clients({ name = 'foo', bufnr = 0 })
          local bars = vim.lsp.get_clients({ name = 'bar', bufnr = 0 })
          return { #foos, 'foo', #bars, 'bar' }
        end)
      end

      -- No filetype on the buffer yet, so no LSPs.
      eq({ 0, 'foo', 0, 'bar' }, count_clients())

      -- Set the filetype to 'foo', confirm a LSP starts.
      exec_lua([[vim.bo.filetype = 'foo']])
      eq({ 1, 'foo', 0, 'bar' }, count_clients())

      -- Set the filetype to 'bar', confirm a new LSP starts, and the old one goes away.
      exec_lua([[vim.bo.filetype = 'bar']])
      eq({ 0, 'foo', 1, 'bar' }, count_clients())
    end)

    it('validates config on attach', function()
      local tmp1 = t.tmpname(true)
      exec_lua(function()
        vim.fn.writefile({ '' }, fake_lsp_logfile)
        vim.lsp.log._set_filename(fake_lsp_logfile)
      end)

      local function test_cfg(cfg, err)
        exec_lua(function()
          vim.lsp.config['foo'] = {}
          vim.lsp.config('foo', cfg)
          vim.lsp.enable('foo')
          vim.cmd.edit(assert(tmp1))
          vim.bo.filetype = 'non.applicable.filetype'
        end)

        -- Assert NO log for non-applicable 'filetype'. #35737
        if type(cfg.filetypes) == 'table' then
          t.assert_nolog(err, fake_lsp_logfile)
        end

        exec_lua(function()
          vim.bo.filetype = 'foo'
        end)

        retry(nil, 1000, function()
          t.assert_log(err, fake_lsp_logfile)
        end)
      end

      test_cfg({
        filetypes = { 'foo' },
        cmd = { 'lolling' },
      }, 'invalid "foo" config: .* lolling is not executable')

      test_cfg({
        cmd = { 'cat' },
        filetypes = true,
      }, 'invalid "foo" config: .* filetypes: expected table, got boolean')
    end)

    it('does not start without workspace if workspace_required=true', function()
      exec_lua(create_server_definition)

      local tmp1 = t.tmpname(true)

      eq(
        { workspace_required = false },
        exec_lua(function()
          local server = _G._create_server({
            handlers = {
              initialize = function(_, _, callback)
                callback(nil, { capabilities = {} })
              end,
            },
          })

          local ws_required = { cmd = server.cmd, workspace_required = true, filetypes = { 'foo' } }
          local ws_not_required = vim.deepcopy(ws_required)
          ws_not_required.workspace_required = false

          vim.lsp.config('ws_required', ws_required)
          vim.lsp.config('ws_not_required', ws_not_required)
          vim.lsp.enable('ws_required')
          vim.lsp.enable('ws_not_required')

          vim.cmd.edit(assert(tmp1))
          vim.bo.filetype = 'foo'

          local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
          assert(1 == #clients)
          return { workspace_required = clients[1].config.workspace_required }
        end)
      )
    end)

    it('does not allow wildcards in config name', function()
      local err =
        '.../lsp.lua:0: name: expected non%-wildcard string, got foo%*%. Info: LSP config name cannot contain wildcard %("%*"%)'

      matches(
        err,
        pcall_err(exec_lua, function()
          local _ = vim.lsp.config['foo*']
        end)
      )
      matches(
        err,
        pcall_err(exec_lua, function()
          vim.lsp.config['foo*'] = {}
        end)
      )
      matches(
        err,
        pcall_err(exec_lua, function()
          vim.lsp.config('foo*', {})
        end)
      )
      -- Exception for '*'
      pcall(exec_lua, function()
        vim.lsp.config('*', {})
      end)
    end)

    it('root_markers priority', function()
      --- Setup directories for testing
      -- root/
      -- ├── dir_a/
      -- │   ├── dir_b/
      -- │   │   ├── target
      -- │   │   └── marker_d
      -- │   ├── marker_b
      -- │   └── marker_c
      -- └── marker_a

      ---@param filepath string
      local function touch(filepath)
        local file = io.open(filepath, 'w')
        if file then
          file:close()
        end
      end

      local tmp_root = tmpname(false)
      local marker_a = tmp_root .. '/marker_a'
      local dir_a = tmp_root .. '/dir_a'
      local marker_b = dir_a .. '/marker_b'
      local marker_c = dir_a .. '/marker_c'
      local dir_b = dir_a .. '/dir_b'
      local marker_d = dir_b .. '/marker_d'
      local target = dir_b .. '/target'

      mkdir(tmp_root)
      touch(marker_a)
      mkdir(dir_a)
      touch(marker_b)
      touch(marker_c)
      mkdir(dir_b)
      touch(marker_d)
      touch(target)

      exec_lua(create_server_definition)
      exec_lua(function()
        _G._custom_server = _G._create_server()
      end)

      ---@param root_markers (string|string[])[]
      ---@param expected_root_dir string?
      local function markers_resolve_to(root_markers, expected_root_dir)
        exec_lua(function()
          vim.lsp.config['foo'] = {}
          vim.lsp.config('foo', {
            cmd = _G._custom_server.cmd,
            reuse_client = function()
              return false
            end,
            filetypes = { 'foo' },
            root_markers = root_markers,
          })
          vim.lsp.enable('foo')
          vim.cmd.edit(target)
          vim.bo.filetype = 'foo'
        end)
        retry(nil, 1000, function()
          eq(
            expected_root_dir,
            exec_lua(function()
              local clients = vim.lsp.get_clients()
              return clients[#clients].root_dir
            end)
          )
        end)
      end

      markers_resolve_to({ 'marker_d' }, dir_b)
      markers_resolve_to({ 'marker_b' }, dir_a)
      markers_resolve_to({ 'marker_c' }, dir_a)
      markers_resolve_to({ 'marker_a' }, tmp_root)
      markers_resolve_to({ 'foo' }, nil)
      markers_resolve_to({ { 'marker_b', 'marker_a' }, 'marker_d' }, dir_a)
      markers_resolve_to({ 'marker_a', { 'marker_b', 'marker_d' } }, tmp_root)
      markers_resolve_to({ 'foo', { 'bar', 'baz' }, 'marker_d' }, dir_b)
    end)

    it('vim.lsp.is_enabled()', function()
      exec_lua(function()
        vim.lsp.config('foo', {
          cmd = { 'foo' },
          root_markers = { '.foorc' },
        })
      end)

      -- LSP config defaults to disabled.
      eq(false, exec_lua([[return vim.lsp.is_enabled('foo')]]))

      -- Confirm we can enable it.
      exec_lua([[vim.lsp.enable('foo')]])
      eq(true, exec_lua([[return vim.lsp.is_enabled('foo')]]))

      -- And finally, disable it again.
      exec_lua([[vim.lsp.enable('foo', false)]])
      eq(false, exec_lua([[return vim.lsp.is_enabled('foo')]]))
    end)

    it('vim.lsp.get_configs()', function()
      exec_lua(function()
        vim.lsp.config('foo', {
          cmd = { 'foo' },
          filetypes = { 'foofile' },
          root_markers = { '.foorc' },
        })
        vim.lsp.config('bar', {
          cmd = { 'bar' },
          root_markers = { '.barrc' },
        })
        vim.lsp.enable('foo')
      end)

      local function names(configs)
        local config_names = vim
          .iter(configs)
          :map(function(config)
            return config.name
          end)
          :totable()
        table.sort(config_names)
        return config_names
      end

      eq({ 'foo' }, names(exec_lua([[return vim.lsp.get_configs { enabled = true }]])))
      -- Does NOT resolve non-enabled configs.
      eq({ foo = true, bar = false }, get_resolved({ 'bar', 'foo' }))

      eq({ 'bar' }, names(exec_lua([[return vim.lsp.get_configs { enabled = false }]])))

      -- With no filter, return all configs
      eq({ 'bar', 'foo' }, names(exec_lua([[return vim.lsp.get_configs()]])))

      -- Confirm `filetype` works
      eq({ 'foo' }, names(exec_lua([[return vim.lsp.get_configs { filetype = 'foofile' }]])))

      -- Confirm filters combine
      eq(
        { 'foo' },
        names(exec_lua([[return vim.lsp.get_configs { filetype = 'foofile', enabled = true }]]))
      )
      eq(
        {},
        names(exec_lua([[return vim.lsp.get_configs { filetype = 'foofile', enabled = false }]]))
      )
      -- Does NOT resolve non-enabled configs.
      eq({ foo = true, bar = false }, get_resolved({ 'bar', 'foo' }))
    end)
  end)
end)
