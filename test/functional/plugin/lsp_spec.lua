local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local t_lsp = require('test.functional.plugin.lsp.testutil')

local assert_log = t.assert_log
local buf_lines = n.buf_lines
local clear = n.clear
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
    exec_lua('lsp.stop_client(lsp.get_clients(), true)')
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
          return vim.lsp.start_client {
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
          }
        end
        _G.TEST_CLIENT1 = _G.test__start_client()
      end)
    end)

    it('start_client(), stop_client()', function()
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
        vim.lsp.stop_client({ _G.TEST_CLIENT2, _G.TEST_CLIENT3 })
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

    it('stop_client() also works on client objects', function()
      exec_lua(function()
        _G.TEST_CLIENT2 = _G.test__start_client()
        _G.TEST_CLIENT3 = _G.test__start_client()
      end)
      retry(nil, 4000, function()
        eq(
          3,
          exec_lua(function()
            return #vim.lsp.get_clients()
          end)
        )
      end)
      -- Stop all clients.
      exec_lua(function()
        vim.lsp.stop_client(vim.lsp.get_clients())
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
          assert_log(
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
        clear()
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
      if is_ci() then
        pending('hangs the build on CI #14028, re-enable with freeze timeout #14204')
        return
      elseif t.skip_fragile(pending) then
        return
      end
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', bufnr = 1, client_id = 1, version = 0 } },
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
              callback = function(args)
                local client0 = assert(vim.lsp.get_client_by_id(args.data.client_id))
                vim.g.lsp_attached = client0.name
              end,
            })
            vim.api.nvim_create_autocmd('LspDetach', {
              callback = function(args)
                local client0 = assert(vim.lsp.get_client_by_id(args.data.client_id))
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
              return keymap:match('<Lua %d+: .+/runtime/lua/vim/lsp%.lua:%d+>') ~= nil
            end)
          )
        end,
      }
    end)

    it('should overwrite options set by ftplugins', function()
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
      clear()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
        local detach_called = false
        vim.api.nvim_create_autocmd('LspDetach', {
          callback = function()
            detach_called = true
          end,
        })
        local client_id = vim.lsp.start({ name = 'detach-dummy', cmd = server.cmd })
        assert(client_id, 'lsp.start must return client_id')
        local client = assert(vim.lsp.get_client_by_id(client_id))
        local num_attached_before = vim.tbl_count(client.attached_buffers)
        vim.api.nvim_buf_delete(bufnr, { force = true })
        local num_attached_after = vim.tbl_count(client.attached_buffers)
        return {
          bufnr = bufnr,
          client_id = client_id,
          num_attached_before = num_attached_before,
          num_attached_after = num_attached_after,
          detach_called = detach_called,
        }
      end)
      eq(true, result ~= nil, 'exec_lua must return result')
      eq(1, result.num_attached_before)
      eq(0, result.num_attached_after)
      eq(true, result.detach_called)
    end)

    it('should not re-attach buffer if it was deleted in on_init #28575', function()
      clear()
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
      clear()
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
              vim.api.nvim_exec_autocmds('BufWritePost', { buffer = _G.BUFFER, modeline = false })
            end)
          else
            client:stop()
          end
        end,
      }
    end)

    it('BufWritePre does not send notifications if server lacks willSave capabilities', function()
      clear()
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
        vim.api.nvim_exec_autocmds('BufWritePre', { buffer = buf, modeline = false })
        vim.lsp.stop_client(client_id)
        return server.messages
      end)
      eq(4, #messages)
      eq('initialize', messages[1].method)
      eq('initialized', messages[2].method)
      eq('shutdown', messages[3].method)
      eq('exit', messages[4].method)
    end)

    it('BufWritePre sends willSave / willSaveWaitUntil, applies textEdits', function()
      clear()
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
        vim.api.nvim_exec_autocmds('BufWritePre', { buffer = buf, modeline = false })
        vim.lsp.stop_client(client_id)
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
              vim.api.nvim_exec_autocmds('BufWritePost', { buffer = _G.BUFFER, modeline = false })
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

    it('should forward ContentModified to callback', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          { code = -32801 },
          NIL,
          { method = 'error_code_test', bufnr = 1, client_id = 1, version = 0 },
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
          -- if ctx.method == 'error_code_test' then client.notify("finish") end
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
        { NIL, {}, { method = 'slow_request', bufnr = 1, client_id = 1, version = 0 } },
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
        { NIL, {}, { method = 'slow_request', bufnr = 1, client_id = 1, version = 0 } },
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

    it('should trigger LspRequest autocmd when requests table changes', function()
      local expected_handlers = {
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'slow_request', bufnr = 1, client_id = 1, version = 0 } },
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
  end)

  describe('parsing tests', function()
    it('should handle invalid content-length correctly', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'invalid_header',
        on_setup = function() end,
        on_init = function(_client)
          client = _client
          client:stop(true)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx }, 'expected handler')
        end,
      }
    end)

    it('should not trim vim.NIL from the end of a list', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'finish', client_id = 1 } },
        {
          NIL,
          {
            arguments = { 'EXTRACT_METHOD', { metadata = {} }, 3, 0, 6123, NIL },
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
    before_each(function()
      insert(dedent([[
        First line of text
        Second line of text
        Third line of text
        Fourth line of text
        å å ɧ 汉语 ↥ 🤦 🦄]]))
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

    it('Supports file creation with CreateFile payload', function()
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
      'Supports file creation in folder that needs to be created with CreateFile payload',
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

  describe('lsp.util.rename', function()
    local pathsep = n.get_pathsep()

    it('Can rename an existing file', function()
      local old = tmpname()
      write_file(old, 'Test content')
      local new = tmpname(false)
      local lines = exec_lua(function()
        local old_bufnr = vim.fn.bufadd(old)
        vim.fn.bufload(old_bufnr)
        vim.lsp.util.rename(old, new)
        -- the existing buffer is renamed in-place and its contents is kept
        local new_bufnr = vim.fn.bufadd(new)
        vim.fn.bufload(new_bufnr)
        return (old_bufnr == new_bufnr) and vim.api.nvim_buf_get_lines(new_bufnr, 0, -1, true)
      end)
      eq({ 'Test content' }, lines)
      local exists = vim.uv.fs_stat(old) ~= nil
      eq(false, exists)
      exists = vim.uv.fs_stat(new) ~= nil
      eq(true, exists)
      os.remove(new)
    end)

    it('Can rename a directory', function()
      -- only reserve the name, file must not exist for the test scenario
      local old_dir = tmpname(false)
      local new_dir = tmpname(false)

      n.mkdir_p(old_dir)

      local file = 'file.txt'
      write_file(old_dir .. pathsep .. file, 'Test content')

      local lines = exec_lua(function()
        local old_bufnr = vim.fn.bufadd(old_dir .. pathsep .. file)
        vim.fn.bufload(old_bufnr)
        vim.lsp.util.rename(old_dir, new_dir)
        -- the existing buffer is renamed in-place and its contents is kept
        local new_bufnr = vim.fn.bufadd(new_dir .. pathsep .. file)
        vim.fn.bufload(new_bufnr)
        return (old_bufnr == new_bufnr) and vim.api.nvim_buf_get_lines(new_bufnr, 0, -1, true)
      end)
      eq({ 'Test content' }, lines)
      eq(false, vim.uv.fs_stat(old_dir) ~= nil)
      eq(true, vim.uv.fs_stat(new_dir) ~= nil)
      eq(true, vim.uv.fs_stat(new_dir .. pathsep .. file) ~= nil)

      os.remove(new_dir)
    end)

    it('Does not touch buffers that do not match path prefix', function()
      local old = tmpname(false)
      local new = tmpname(false)
      n.mkdir_p(old)

      eq(
        true,
        exec_lua(function()
          local old_prefixed = 'explorer://' .. old
          local old_suffixed = old .. '.bak'
          local new_prefixed = 'explorer://' .. new
          local new_suffixed = new .. '.bak'

          local old_prefixed_buf = vim.fn.bufadd(old_prefixed)
          local old_suffixed_buf = vim.fn.bufadd(old_suffixed)
          local new_prefixed_buf = vim.fn.bufadd(new_prefixed)
          local new_suffixed_buf = vim.fn.bufadd(new_suffixed)

          vim.lsp.util.rename(old, new)

          return vim.api.nvim_buf_is_valid(old_prefixed_buf)
            and vim.api.nvim_buf_is_valid(old_suffixed_buf)
            and vim.api.nvim_buf_is_valid(new_prefixed_buf)
            and vim.api.nvim_buf_is_valid(new_suffixed_buf)
            and vim.api.nvim_buf_get_name(old_prefixed_buf) == old_prefixed
            and vim.api.nvim_buf_get_name(old_suffixed_buf) == old_suffixed
            and vim.api.nvim_buf_get_name(new_prefixed_buf) == new_prefixed
            and vim.api.nvim_buf_get_name(new_suffixed_buf) == new_suffixed
        end)
      )

      os.remove(new)
    end)

    it(
      'Does not rename file if target exists and ignoreIfExists is set or overwrite is false',
      function()
        local old = tmpname()
        write_file(old, 'Old File')
        local new = tmpname()
        write_file(new, 'New file')

        exec_lua(function()
          vim.lsp.util.rename(old, new, { ignoreIfExists = true })
        end)

        eq(true, vim.uv.fs_stat(old) ~= nil)
        eq('New file', read_file(new))

        exec_lua(function()
          vim.lsp.util.rename(old, new, { overwrite = false })
        end)

        eq(true, vim.uv.fs_stat(old) ~= nil)
        eq('New file', read_file(new))
      end
    )

    it('Maintains undo information for loaded buffer', function()
      local old = tmpname()
      write_file(old, 'line')
      local new = tmpname(false)

      local undo_kept = exec_lua(function()
        vim.opt.undofile = true
        vim.cmd.edit(old)
        vim.cmd.normal('dd')
        vim.cmd.write()
        local undotree = vim.fn.undotree()
        vim.lsp.util.rename(old, new)
        -- Renaming uses :saveas, which updates the "last write" information.
        -- Other than that, the undotree should remain the same.
        undotree.save_cur = undotree.save_cur + 1
        undotree.save_last = undotree.save_last + 1
        undotree.entries[1].save = undotree.entries[1].save + 1
        return vim.deep_equal(undotree, vim.fn.undotree())
      end)
      eq(false, vim.uv.fs_stat(old) ~= nil)
      eq(true, vim.uv.fs_stat(new) ~= nil)
      eq(true, undo_kept)
    end)

    it('Maintains undo information for unloaded buffer', function()
      local old = tmpname()
      write_file(old, 'line')
      local new = tmpname(false)

      local undo_kept = exec_lua(function()
        vim.opt.undofile = true
        vim.cmd.split(old)
        vim.cmd.normal('dd')
        vim.cmd.write()
        local undotree = vim.fn.undotree()
        vim.cmd.bdelete()
        vim.lsp.util.rename(old, new)
        vim.cmd.edit(new)
        return vim.deep_equal(undotree, vim.fn.undotree())
      end)
      eq(false, vim.uv.fs_stat(old) ~= nil)
      eq(true, vim.uv.fs_stat(new) ~= nil)
      eq(true, undo_kept)
    end)

    it('Does not rename file when it conflicts with a buffer without file', function()
      local old = tmpname()
      write_file(old, 'Old File')
      local new = tmpname(false)

      local lines = exec_lua(function()
        local old_buf = vim.fn.bufadd(old)
        vim.fn.bufload(old_buf)
        local conflict_buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(conflict_buf, new)
        vim.api.nvim_buf_set_lines(conflict_buf, 0, -1, true, { 'conflict' })
        vim.api.nvim_win_set_buf(0, conflict_buf)
        vim.lsp.util.rename(old, new)
        return vim.api.nvim_buf_get_lines(conflict_buf, 0, -1, true)
      end)
      eq({ 'conflict' }, lines)
      eq('Old File', read_file(old))
    end)

    it('Does override target if overwrite is true', function()
      local old = tmpname()
      write_file(old, 'Old file')
      local new = tmpname()
      write_file(new, 'New file')
      exec_lua(function()
        vim.lsp.util.rename(old, new, { overwrite = true })
      end)

      eq(false, vim.uv.fs_stat(old) ~= nil)
      eq(true, vim.uv.fs_stat(new) ~= nil)
      eq('Old file', read_file(new))
    end)
  end)

  describe('lsp.util.locations_to_items', function()
    it('Convert Location[] to items', function()
      local expected_template = {
        {
          filename = '/fake/uri',
          lnum = 1,
          end_lnum = 2,
          col = 3,
          end_col = 4,
          text = 'testing',
          user_data = {},
        },
      }
      local test_params = {
        {
          {
            uri = 'file:///fake/uri',
            range = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 1, character = 3 },
            },
          },
        },
        {
          {
            uri = 'file:///fake/uri',
            range = {
              start = { line = 0, character = 2 },
              -- LSP spec: if character > line length, default to the line length.
              ['end'] = { line = 1, character = 10000 },
            },
          },
        },
      }
      for _, params in ipairs(test_params) do
        local actual = exec_lua(function(params0)
          local bufnr = vim.uri_to_bufnr('file:///fake/uri')
          local lines = { 'testing', '123' }
          vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
          return vim.lsp.util.locations_to_items(params0, 'utf-16')
        end, params)
        local expected = vim.deepcopy(expected_template)
        expected[1].user_data = params[1]
        eq(expected, actual)
      end
    end)

    it('Convert LocationLink[] to items', function()
      local expected = {
        {
          filename = '/fake/uri',
          lnum = 1,
          end_lnum = 1,
          col = 3,
          end_col = 4,
          text = 'testing',
          user_data = {
            targetUri = 'file:///fake/uri',
            targetRange = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            },
            targetSelectionRange = {
              start = { line = 0, character = 2 },
              ['end'] = { line = 0, character = 3 },
            },
          },
        },
      }
      local actual = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri')
        local lines = { 'testing', '123' }
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
            },
          },
        }
        return vim.lsp.util.locations_to_items(locations, 'utf-16')
      end)
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
            text = '[File] TestA',
          },
          {
            col = 1,
            filename = '',
            kind = 'Module',
            lnum = 4,
            text = '[Module] TestB',
          },
          {
            col = 1,
            filename = '',
            kind = 'Namespace',
            lnum = 6,
            text = '[Namespace] TestC',
          },
        }
        eq(
          expected,
          exec_lua(function()
            local doc_syms = {
              {
                deprecated = false,
                detail = 'A',
                kind = 1,
                name = 'TestA',
                range = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 0,
                    line = 2,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 4,
                    line = 1,
                  },
                },
                children = {
                  {
                    children = {},
                    deprecated = false,
                    detail = 'B',
                    kind = 2,
                    name = 'TestB',
                    range = {
                      start = {
                        character = 0,
                        line = 3,
                      },
                      ['end'] = {
                        character = 0,
                        line = 4,
                      },
                    },
                    selectionRange = {
                      start = {
                        character = 0,
                        line = 3,
                      },
                      ['end'] = {
                        character = 4,
                        line = 3,
                      },
                    },
                  },
                },
              },
              {
                deprecated = false,
                detail = 'C',
                kind = 3,
                name = 'TestC',
                range = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 0,
                    line = 6,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 4,
                    line = 5,
                  },
                },
              },
            }
            return vim.lsp.util.symbols_to_items(doc_syms, nil)
          end)
        )
      end)

      it('DocumentSymbol has no children', function()
        local expected = {
          {
            col = 1,
            filename = '',
            kind = 'File',
            lnum = 2,
            text = '[File] TestA',
          },
          {
            col = 1,
            filename = '',
            kind = 'Namespace',
            lnum = 6,
            text = '[Namespace] TestC',
          },
        }
        eq(
          expected,
          exec_lua(function()
            local doc_syms = {
              {
                deprecated = false,
                detail = 'A',
                kind = 1,
                name = 'TestA',
                range = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 0,
                    line = 2,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 4,
                    line = 1,
                  },
                },
              },
              {
                deprecated = false,
                detail = 'C',
                kind = 3,
                name = 'TestC',
                range = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 0,
                    line = 6,
                  },
                },
                selectionRange = {
                  start = {
                    character = 0,
                    line = 5,
                  },
                  ['end'] = {
                    character = 4,
                    line = 5,
                  },
                },
              },
            }
            return vim.lsp.util.symbols_to_items(doc_syms, nil)
          end)
        )
      end)
    end)

    it('convert SymbolInformation[] to items', function()
      local expected = {
        {
          col = 1,
          filename = '/test_a',
          kind = 'File',
          lnum = 2,
          text = '[File] TestA',
        },
        {
          col = 1,
          filename = '/test_b',
          kind = 'Module',
          lnum = 4,
          text = '[Module] TestB',
        },
      }
      eq(
        expected,
        exec_lua(function()
          local sym_info = {
            {
              deprecated = false,
              kind = 1,
              name = 'TestA',
              location = {
                range = {
                  start = {
                    character = 0,
                    line = 1,
                  },
                  ['end'] = {
                    character = 0,
                    line = 2,
                  },
                },
                uri = 'file:///test_a',
              },
              containerName = 'TestAContainer',
            },
            {
              deprecated = false,
              kind = 2,
              name = 'TestB',
              location = {
                range = {
                  start = {
                    character = 0,
                    line = 3,
                  },
                  ['end'] = {
                    character = 0,
                    line = 4,
                  },
                },
                uri = 'file:///test_b',
              },
              containerName = 'TestBContainer',
            },
          }
          return vim.lsp.util.symbols_to_items(sym_info, nil)
        end)
      )
    end)
  end)

  describe('lsp.util.jump_to_location', function()
    local target_bufnr --- @type integer

    before_each(function()
      target_bufnr = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri')
        local lines = { '1st line of text', 'å å ɧ 汉语 ↥ 🤦 🦄' }
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      end)
    end)

    local location = function(start_line, start_char, end_line, end_char)
      return {
        uri = 'file:///fake/uri',
        range = {
          start = { line = start_line, character = start_char },
          ['end'] = { line = end_line, character = end_char },
        },
      }
    end

    local jump = function(msg)
      eq(true, exec_lua('return vim.lsp.util.jump_to_location(...)', msg, 'utf-16'))
      eq(target_bufnr, fn.bufnr('%'))
      return {
        line = fn.line('.'),
        col = fn.col('.'),
      }
    end

    it('jumps to a Location', function()
      local pos = jump(location(0, 9, 0, 9))
      eq(1, pos.line)
      eq(10, pos.col)
    end)

    it('jumps to a LocationLink', function()
      local pos = jump({
        targetUri = 'file:///fake/uri',
        targetSelectionRange = {
          start = { line = 0, character = 4 },
          ['end'] = { line = 0, character = 4 },
        },
        targetRange = {
          start = { line = 1, character = 5 },
          ['end'] = { line = 1, character = 5 },
        },
      })
      eq(1, pos.line)
      eq(5, pos.col)
    end)

    it('jumps to the correct multibyte column', function()
      local pos = jump(location(1, 2, 1, 2))
      eq(2, pos.line)
      eq(4, pos.col)
      eq('å', fn.expand('<cword>'))
    end)

    it('adds current position to jumplist before jumping', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local mark = api.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 1, 0 }, mark)

      api.nvim_win_set_cursor(0, { 2, 3 })
      jump(location(0, 9, 0, 9))

      mark = api.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 2, 3 }, mark)
    end)
  end)

  describe('lsp.util.show_document', function()
    local target_bufnr --- @type integer
    local target_bufnr2 --- @type integer

    before_each(function()
      target_bufnr = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri')
        local lines = { '1st line of text', 'å å ɧ 汉语 ↥ 🤦 🦄' }
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      end)

      target_bufnr2 = exec_lua(function()
        local bufnr = vim.uri_to_bufnr('file:///fake/uri2')
        local lines = { '1st line of text', 'å å ɧ 汉语 ↥ 🤦 🦄' }
        vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, lines)
        return bufnr
      end)
    end)

    local location = function(start_line, start_char, end_line, end_char, second_uri)
      return {
        uri = second_uri and 'file:///fake/uri2' or 'file:///fake/uri',
        range = {
          start = { line = start_line, character = start_char },
          ['end'] = { line = end_line, character = end_char },
        },
      }
    end

    local show_document = function(msg, focus, reuse_win)
      eq(
        true,
        exec_lua(
          'return vim.lsp.util.show_document(...)',
          msg,
          'utf-16',
          { reuse_win = reuse_win, focus = focus }
        )
      )
      if focus == true or focus == nil then
        eq(target_bufnr, fn.bufnr('%'))
      end
      return {
        line = fn.line('.'),
        col = fn.col('.'),
      }
    end

    it('jumps to a Location if focus is true', function()
      local pos = show_document(location(0, 9, 0, 9), true, true)
      eq(1, pos.line)
      eq(10, pos.col)
    end)

    it('jumps to a Location if focus is true via handler', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server()
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        local result = {
          uri = 'file:///fake/uri',
          selection = {
            start = { line = 0, character = 9 },
            ['end'] = { line = 0, character = 9 },
          },
          takeFocus = true,
        }
        local ctx = {
          client_id = client_id,
          method = 'window/showDocument',
        }
        vim.lsp.handlers['window/showDocument'](nil, result, ctx)
        vim.lsp.stop_client(client_id)
        return {
          cursor = vim.api.nvim_win_get_cursor(0),
        }
      end)
      eq(1, result.cursor[1])
      eq(9, result.cursor[2])
    end)

    it('jumps to a Location if focus not set', function()
      local pos = show_document(location(0, 9, 0, 9), nil, true)
      eq(1, pos.line)
      eq(10, pos.col)
    end)

    it('does not add current position to jumplist if not focus', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local mark = api.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 1, 0 }, mark)

      api.nvim_win_set_cursor(0, { 2, 3 })
      show_document(location(0, 9, 0, 9), false, true)
      show_document(location(0, 9, 0, 9, true), false, true)

      mark = api.nvim_buf_get_mark(target_bufnr, "'")
      eq({ 1, 0 }, mark)
    end)

    it('does not change cursor position if not focus and not reuse_win', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local cursor = api.nvim_win_get_cursor(0)

      show_document(location(0, 9, 0, 9), false, false)
      eq(cursor, api.nvim_win_get_cursor(0))
    end)

    it('does not change window if not focus', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local win = api.nvim_get_current_win()

      -- same document/bufnr
      show_document(location(0, 9, 0, 9), false, true)
      eq(win, api.nvim_get_current_win())

      -- different document/bufnr, new window/split
      show_document(location(0, 9, 0, 9, true), false, true)
      eq(2, #api.nvim_list_wins())
      eq(win, api.nvim_get_current_win())
    end)

    it("respects 'reuse_win' parameter", function()
      api.nvim_win_set_buf(0, target_bufnr)

      -- does not create a new window if the buffer is already open
      show_document(location(0, 9, 0, 9), false, true)
      eq(1, #api.nvim_list_wins())

      -- creates a new window even if the buffer is already open
      show_document(location(0, 9, 0, 9), false, false)
      eq(2, #api.nvim_list_wins())
    end)

    it('correctly sets the cursor of the split if range is given without focus', function()
      api.nvim_win_set_buf(0, target_bufnr)

      show_document(location(0, 9, 0, 9, true), false, true)

      local wins = api.nvim_list_wins()
      eq(2, #wins)
      table.sort(wins)

      eq({ 1, 0 }, api.nvim_win_get_cursor(wins[1]))
      eq({ 1, 9 }, api.nvim_win_get_cursor(wins[2]))
    end)

    it('does not change cursor of the split if not range and not focus', function()
      api.nvim_win_set_buf(0, target_bufnr)
      api.nvim_win_set_cursor(0, { 2, 3 })

      exec_lua(function()
        vim.cmd.new()
      end)
      api.nvim_win_set_buf(0, target_bufnr2)
      api.nvim_win_set_cursor(0, { 2, 3 })

      show_document({ uri = 'file:///fake/uri2' }, false, true)

      local wins = api.nvim_list_wins()
      eq(2, #wins)
      eq({ 2, 3 }, api.nvim_win_get_cursor(wins[1]))
      eq({ 2, 3 }, api.nvim_win_get_cursor(wins[2]))
    end)

    it('respects existing buffers', function()
      api.nvim_win_set_buf(0, target_bufnr)
      local win = api.nvim_get_current_win()

      exec_lua(function()
        vim.cmd.new()
      end)
      api.nvim_win_set_buf(0, target_bufnr2)
      api.nvim_win_set_cursor(0, { 2, 3 })
      local split = api.nvim_get_current_win()

      -- reuse win for open document/bufnr if called from split
      show_document(location(0, 9, 0, 9, true), false, true)
      eq({ 1, 9 }, api.nvim_win_get_cursor(split))
      eq(2, #api.nvim_list_wins())

      api.nvim_set_current_win(win)

      -- reuse win for open document/bufnr if called outside the split
      show_document(location(0, 9, 0, 9, true), false, true)
      eq({ 1, 9 }, api.nvim_win_get_cursor(split))
      eq(2, #api.nvim_list_wins())
    end)
  end)

  describe('lsp.util._make_floating_popup_size', function()
    before_each(function()
      exec_lua(function()
        _G.contents = { 'text tαxt txtα tex', 'text tααt tααt text', 'text tαxt tαxt' }
      end)
    end)

    it('calculates size correctly', function()
      eq(
        { 19, 3 },
        exec_lua(function()
          return { vim.lsp.util._make_floating_popup_size(_G.contents) }
        end)
      )
    end)

    it('calculates size correctly with wrapping', function()
      eq(
        { 15, 5 },
        exec_lua(function()
          return {
            vim.lsp.util._make_floating_popup_size(_G.contents, { width = 15, wrap_at = 14 }),
          }
        end)
      )
    end)

    it('handles NUL bytes in text', function()
      exec_lua(function()
        _G.contents = {
          '\000\001\002\003\004\005\006\007\008\009',
          '\010\011\012\013\014\015\016\017\018\019',
          '\020\021\022\023\024\025\026\027\028\029',
        }
      end)
      command('set list listchars=')
      eq(
        { 20, 3 },
        exec_lua(function()
          return { vim.lsp.util._make_floating_popup_size(_G.contents) }
        end)
      )
      command('set display+=uhex')
      eq(
        { 40, 3 },
        exec_lua(function()
          return { vim.lsp.util._make_floating_popup_size(_G.contents) }
        end)
      )
    end)
  end)

  describe('lsp.util.trim.trim_empty_lines', function()
    it('properly trims empty lines', function()
      eq(
        { { 'foo', 'bar' } },
        exec_lua(function()
          --- @diagnostic disable-next-line:deprecated
          return vim.lsp.util.trim_empty_lines({ { 'foo', 'bar' }, nil })
        end)
      )
    end)
  end)

  describe('lsp.util.convert_signature_help_to_markdown_lines', function()
    it('can handle negative activeSignature', function()
      local result = exec_lua(function()
        local signature_help = {
          activeParameter = 0,
          activeSignature = -1,
          signatures = {
            {
              documentation = 'some doc',
              label = 'TestEntity.TestEntity()',
              parameters = {},
            },
          },
        }
        return vim.lsp.util.convert_signature_help_to_markdown_lines(signature_help, 'cs', { ',' })
      end)
      local expected = { '```cs', 'TestEntity.TestEntity()', '```', 'some doc' }
      eq(expected, result)
    end)

    it('highlights active parameters in multiline signature labels', function()
      local _, hl = exec_lua(function()
        local signature_help = {
          activeSignature = 0,
          signatures = {
            {
              activeParameter = 1,
              label = 'fn bar(\n    _: void,\n    _: void,\n) void',
              parameters = {
                { label = '_: void' },
                { label = '_: void' },
              },
            },
          },
        }
        return vim.lsp.util.convert_signature_help_to_markdown_lines(signature_help, 'zig', { '(' })
      end)
      -- Note that although the highlight positions below are 0-indexed, the 2nd parameter
      -- corresponds to the 3rd line because the first line is the ``` from the
      -- Markdown block.
      local expected = { 3, 4, 3, 11 }
      eq(expected, hl)
    end)
  end)

  describe('lsp.util.get_effective_tabstop', function()
    local function test_tabstop(tabsize, shiftwidth)
      exec_lua(string.format(
        [[
        vim.bo.shiftwidth = %d
        vim.bo.tabstop = 2
      ]],
        shiftwidth
      ))
      eq(
        tabsize,
        exec_lua(function()
          return vim.lsp.util.get_effective_tabstop()
        end)
      )
    end

    it('with shiftwidth = 1', function()
      test_tabstop(1, 1)
    end)

    it('with shiftwidth = 0', function()
      test_tabstop(2, 0)
    end)
  end)

  describe('vim.lsp.buf.outgoing_calls', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua(function()
        require 'vim.lsp.handlers'['callHierarchy/outgoingCalls'](nil, nil, {}, nil)
        return #vim.fn.getqflist()
      end)
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right caller', function()
      local qflist = exec_lua(function()
        local rust_analyzer_response = {
          {
            fromRanges = {
              {
                ['end'] = {
                  character = 7,
                  line = 3,
                },
                start = {
                  character = 4,
                  line = 3,
                },
              },
            },
            to = {
              detail = 'fn foo()',
              kind = 12,
              name = 'foo',
              range = {
                ['end'] = {
                  character = 11,
                  line = 0,
                },
                start = {
                  character = 0,
                  line = 0,
                },
              },
              selectionRange = {
                ['end'] = {
                  character = 6,
                  line = 0,
                },
                start = {
                  character = 3,
                  line = 0,
                },
              },
              uri = 'file:///src/main.rs',
            },
          },
        }
        local handler = require 'vim.lsp.handlers'['callHierarchy/outgoingCalls']
        handler(nil, rust_analyzer_response, {})
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 5,
          end_col = 0,
          lnum = 4,
          end_lnum = 0,
          module = '',
          nr = 0,
          pattern = '',
          text = 'foo',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }

      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.incoming_calls', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua(function()
        require 'vim.lsp.handlers'['callHierarchy/incomingCalls'](nil, nil, {})
        return #vim.fn.getqflist()
      end)
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right callee', function()
      local qflist = exec_lua(function()
        local rust_analyzer_response = {
          {
            from = {
              detail = 'fn main()',
              kind = 12,
              name = 'main',
              range = {
                ['end'] = {
                  character = 1,
                  line = 4,
                },
                start = {
                  character = 0,
                  line = 2,
                },
              },
              selectionRange = {
                ['end'] = {
                  character = 7,
                  line = 2,
                },
                start = {
                  character = 3,
                  line = 2,
                },
              },
              uri = 'file:///src/main.rs',
            },
            fromRanges = {
              {
                ['end'] = {
                  character = 7,
                  line = 3,
                },
                start = {
                  character = 4,
                  line = 3,
                },
              },
            },
          },
        }

        local handler = require 'vim.lsp.handlers'['callHierarchy/incomingCalls']
        handler(nil, rust_analyzer_response, {})
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 5,
          end_col = 0,
          lnum = 4,
          end_lnum = 0,
          module = '',
          nr = 0,
          pattern = '',
          text = 'main',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }

      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.typehierarchy subtypes', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua(function()
        require 'vim.lsp.handlers'['typeHierarchy/subtypes'](nil, nil, {})
        return #vim.fn.getqflist()
      end)
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right subtypes', function()
      clear()
      exec_lua(create_server_definition)
      local qflist = exec_lua(function()
        local clangd_response = {
          {
            data = {
              parents = {
                {
                  parents = {
                    {
                      parents = {
                        {
                          parents = {},
                          symbolID = '62B3D268A01B9978',
                        },
                      },
                      symbolID = 'DC9B0AD433B43BEC',
                    },
                  },
                  symbolID = '06B5F6A19BA9F6A8',
                },
              },
              symbolID = 'EDC336589C09ABB2',
            },
            kind = 5,
            name = 'D2',
            range = {
              ['end'] = {
                character = 8,
                line = 3,
              },
              start = {
                character = 6,
                line = 3,
              },
            },
            selectionRange = {
              ['end'] = {
                character = 8,
                line = 3,
              },
              start = {
                character = 6,
                line = 3,
              },
            },
            uri = 'file:///home/jiangyinzuo/hello.cpp',
          },
          {
            data = {
              parents = {
                {
                  parents = {
                    {
                      parents = {
                        {
                          parents = {},
                          symbolID = '62B3D268A01B9978',
                        },
                      },
                      symbolID = 'DC9B0AD433B43BEC',
                    },
                  },
                  symbolID = '06B5F6A19BA9F6A8',
                },
              },
              symbolID = 'AFFCAED15557EF08',
            },
            kind = 5,
            name = 'D1',
            range = {
              ['end'] = {
                character = 8,
                line = 2,
              },
              start = {
                character = 6,
                line = 2,
              },
            },
            selectionRange = {
              ['end'] = {
                character = 8,
                line = 2,
              },
              start = {
                character = 6,
                line = 2,
              },
            },
            uri = 'file:///home/jiangyinzuo/hello.cpp',
          },
        }

        local server = _G._create_server({
          capabilities = {
            positionEncoding = 'utf-8',
          },
        })
        local client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        local handler = require 'vim.lsp.handlers'['typeHierarchy/subtypes']
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'class B : public A{};',
          'class C : public B{};',
          'class D1 : public C{};',
          'class D2 : public C{};',
          'class E : public D1, D2 {};',
        })
        handler(nil, clangd_response, { client_id = client_id, bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 7,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'D2',
          type = '',
          valid = 1,
          vcol = 0,
        },
        {
          bufnr = 2,
          col = 7,
          end_col = 0,
          end_lnum = 0,
          lnum = 3,
          module = '',
          nr = 0,
          pattern = '',
          text = 'D1',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }

      eq(expected, qflist)
    end)

    it('opens the quickfix list with the right subtypes and details', function()
      clear()
      exec_lua(create_server_definition)
      local qflist = exec_lua(function()
        local jdtls_response = {
          {
            data = { element = '=hello-java_ed323c3c/_<{Main.java[Main[A' },
            detail = '',
            kind = 5,
            name = 'A',
            range = {
              ['end'] = { character = 26, line = 3 },
              start = { character = 1, line = 3 },
            },
            selectionRange = {
              ['end'] = { character = 8, line = 3 },
              start = { character = 7, line = 3 },
            },
            tags = {},
            uri = 'file:///home/jiangyinzuo/hello-java/Main.java',
          },
          {
            data = { element = '=hello-java_ed323c3c/_<mylist{MyList.java[MyList[Inner' },
            detail = 'mylist',
            kind = 5,
            name = 'MyList$Inner',
            range = {
              ['end'] = { character = 37, line = 3 },
              start = { character = 1, line = 3 },
            },
            selectionRange = {
              ['end'] = { character = 19, line = 3 },
              start = { character = 14, line = 3 },
            },
            tags = {},
            uri = 'file:///home/jiangyinzuo/hello-java/mylist/MyList.java',
          },
        }

        local server = _G._create_server({
          capabilities = {
            positionEncoding = 'utf-8',
          },
        })
        local client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        local handler = require 'vim.lsp.handlers'['typeHierarchy/subtypes']
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'package mylist;',
          '',
          'public class MyList {',
          ' static class Inner extends MyList{}',
          '~}',
        })
        handler(nil, jdtls_response, { client_id = client_id, bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 2,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'A',
          type = '',
          valid = 1,
          vcol = 0,
        },
        {
          bufnr = 3,
          col = 2,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'MyList$Inner mylist',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }
      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.typehierarchy supertypes', function()
    it('does nothing for an empty response', function()
      local qflist_count = exec_lua(function()
        require 'vim.lsp.handlers'['typeHierarchy/supertypes'](nil, nil, {})
        return #vim.fn.getqflist()
      end)
      eq(0, qflist_count)
    end)

    it('opens the quickfix list with the right supertypes', function()
      clear()
      exec_lua(create_server_definition)
      local qflist = exec_lua(function()
        local clangd_response = {
          {
            data = {
              parents = {
                {
                  parents = {
                    {
                      parents = {
                        {
                          parents = {},
                          symbolID = '62B3D268A01B9978',
                        },
                      },
                      symbolID = 'DC9B0AD433B43BEC',
                    },
                  },
                  symbolID = '06B5F6A19BA9F6A8',
                },
              },
              symbolID = 'EDC336589C09ABB2',
            },
            kind = 5,
            name = 'D2',
            range = {
              ['end'] = {
                character = 8,
                line = 3,
              },
              start = {
                character = 6,
                line = 3,
              },
            },
            selectionRange = {
              ['end'] = {
                character = 8,
                line = 3,
              },
              start = {
                character = 6,
                line = 3,
              },
            },
            uri = 'file:///home/jiangyinzuo/hello.cpp',
          },
          {
            data = {
              parents = {
                {
                  parents = {
                    {
                      parents = {
                        {
                          parents = {},
                          symbolID = '62B3D268A01B9978',
                        },
                      },
                      symbolID = 'DC9B0AD433B43BEC',
                    },
                  },
                  symbolID = '06B5F6A19BA9F6A8',
                },
              },
              symbolID = 'AFFCAED15557EF08',
            },
            kind = 5,
            name = 'D1',
            range = {
              ['end'] = {
                character = 8,
                line = 2,
              },
              start = {
                character = 6,
                line = 2,
              },
            },
            selectionRange = {
              ['end'] = {
                character = 8,
                line = 2,
              },
              start = {
                character = 6,
                line = 2,
              },
            },
            uri = 'file:///home/jiangyinzuo/hello.cpp',
          },
        }

        local server = _G._create_server({
          capabilities = {
            positionEncoding = 'utf-8',
          },
        })
        local client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        local handler = require 'vim.lsp.handlers'['typeHierarchy/supertypes']
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'class B : public A{};',
          'class C : public B{};',
          'class D1 : public C{};',
          'class D2 : public C{};',
          'class E : public D1, D2 {};',
        })

        handler(nil, clangd_response, { client_id = client_id, bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 7,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'D2',
          type = '',
          valid = 1,
          vcol = 0,
        },
        {
          bufnr = 2,
          col = 7,
          end_col = 0,
          end_lnum = 0,
          lnum = 3,
          module = '',
          nr = 0,
          pattern = '',
          text = 'D1',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }

      eq(expected, qflist)
    end)

    it('opens the quickfix list with the right supertypes and details', function()
      clear()
      exec_lua(create_server_definition)
      local qflist = exec_lua(function()
        local jdtls_response = {
          {
            data = { element = '=hello-java_ed323c3c/_<{Main.java[Main[A' },
            detail = '',
            kind = 5,
            name = 'A',
            range = {
              ['end'] = { character = 26, line = 3 },
              start = { character = 1, line = 3 },
            },
            selectionRange = {
              ['end'] = { character = 8, line = 3 },
              start = { character = 7, line = 3 },
            },
            tags = {},
            uri = 'file:///home/jiangyinzuo/hello-java/Main.java',
          },
          {
            data = { element = '=hello-java_ed323c3c/_<mylist{MyList.java[MyList[Inner' },
            detail = 'mylist',
            kind = 5,
            name = 'MyList$Inner',
            range = {
              ['end'] = { character = 37, line = 3 },
              start = { character = 1, line = 3 },
            },
            selectionRange = {
              ['end'] = { character = 19, line = 3 },
              start = { character = 14, line = 3 },
            },
            tags = {},
            uri = 'file:///home/jiangyinzuo/hello-java/mylist/MyList.java',
          },
        }

        local server = _G._create_server({
          capabilities = {
            positionEncoding = 'utf-8',
          },
        })
        local client_id = vim.lsp.start({ name = 'dummy', cmd = server.cmd })
        local handler = require 'vim.lsp.handlers'['typeHierarchy/supertypes']
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'package mylist;',
          '',
          'public class MyList {',
          ' static class Inner extends MyList{}',
          '~}',
        })
        handler(nil, jdtls_response, { client_id = client_id, bufnr = bufnr })
        return vim.fn.getqflist()
      end)

      local expected = {
        {
          bufnr = 2,
          col = 2,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'A',
          type = '',
          valid = 1,
          vcol = 0,
        },
        {
          bufnr = 3,
          col = 2,
          end_col = 0,
          end_lnum = 0,
          lnum = 4,
          module = '',
          nr = 0,
          pattern = '',
          text = 'MyList$Inner mylist',
          type = '',
          valid = 1,
          vcol = 0,
        },
      }
      eq(expected, qflist)
    end)
  end)

  describe('vim.lsp.buf.rename', function()
    for _, test in ipairs({
      {
        it = 'does not attempt to rename on nil response',
        name = 'prepare_rename_nil',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
      },
      {
        it = 'handles prepareRename placeholder response',
        name = 'prepare_rename_placeholder',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          { NIL, NIL, { method = 'textDocument/rename', client_id = 1, bufnr = 1 } },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
        expected_text = 'placeholder', -- see fake lsp response
      },
      {
        it = 'handles range response',
        name = 'prepare_rename_range',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          { NIL, NIL, { method = 'textDocument/rename', client_id = 1, bufnr = 1 } },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
        expected_text = 'line', -- see test case and fake lsp response
      },
      {
        it = 'handles error',
        name = 'prepare_rename_error',
        expected_handlers = {
          { NIL, {}, { method = 'shutdown', client_id = 1 } },
          { NIL, {}, { method = 'start', client_id = 1 } },
        },
      },
    }) do
      it(test.it, function()
        local client --- @type vim.lsp.Client
        test_rpc_server {
          test_name = test.name,
          on_init = function(_client)
            client = _client
            eq(true, client.server_capabilities().renameProvider.prepareProvider)
          end,
          on_setup = function()
            exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              vim.lsp._stubs = {}
              --- @diagnostic disable-next-line:duplicate-set-field
              vim.fn.input = function(opts, _)
                vim.lsp._stubs.input_prompt = opts.prompt
                vim.lsp._stubs.input_text = opts.default
                return 'renameto' -- expect this value in fake lsp
              end
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '', 'this is line two' })
              vim.fn.cursor(2, 13) -- the space between "line" and "two"
            end)
          end,
          on_exit = function(code, signal)
            eq(0, code, 'exit code')
            eq(0, signal, 'exit signal')
          end,
          on_handler = function(err, result, ctx)
            -- Don't compare & assert params and version, they're not relevant for the testcase
            -- This allows us to be lazy and avoid declaring them
            ctx.params = nil
            ctx.version = nil

            eq(table.remove(test.expected_handlers), { err, result, ctx }, 'expected handler')
            if ctx.method == 'start' then
              exec_lua(function()
                vim.lsp.buf.rename()
              end)
            end
            if ctx.method == 'shutdown' then
              if test.expected_text then
                eq(
                  'New Name: ',
                  exec_lua(function()
                    return vim.lsp._stubs.input_prompt
                  end)
                )
                eq(
                  test.expected_text,
                  exec_lua(function()
                    return vim.lsp._stubs.input_text
                  end)
                )
              end
              client:stop()
            end
          end,
        }
      end)
    end
  end)

  describe('vim.lsp.buf.code_action', function()
    it('Calls client side command if available', function()
      local client --- @type vim.lsp.Client
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'code_action_with_resolve',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function() end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            exec_lua(function()
              vim.lsp.commands['dummy1'] = function(_)
                vim.lsp.commands['dummy2'] = function() end
              end
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              --- @diagnostic disable-next-line:duplicate-set-field
              vim.fn.inputlist = function()
                return 1
              end
              vim.lsp.buf.code_action()
            end)
          elseif ctx.method == 'shutdown' then
            eq(
              'function',
              exec_lua(function()
                return type(vim.lsp.commands['dummy2'])
              end)
            )
            client:stop()
          end
        end,
      }
    end)

    it('Calls workspace/executeCommand if no client side command', function()
      local client --- @type vim.lsp.Client
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
          ctx.version = nil
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              vim.fn.inputlist = function()
                return 1
              end
              vim.lsp.buf.code_action()
            end)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      })
    end)

    it('Filters and automatically applies action if requested', function()
      local client --- @type vim.lsp.Client
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'code_action_filter',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function() end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            exec_lua(function()
              vim.lsp.commands['preferred_command'] = function(_)
                vim.lsp.commands['executed_preferred'] = function() end
              end
              vim.lsp.commands['type_annotate_command'] = function(_)
                vim.lsp.commands['executed_type_annotate'] = function() end
              end
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              vim.lsp.buf.code_action({
                filter = function(a)
                  return a.isPreferred
                end,
                apply = true,
              })
              vim.lsp.buf.code_action({
                -- expect to be returned actions 'type-annotate' and 'type-annotate.foo'
                context = { only = { 'type-annotate' } },
                apply = true,
                filter = function(a)
                  if a.kind == 'type-annotate.foo' then
                    vim.lsp.commands['filtered_type_annotate_foo'] = function() end
                    return false
                  elseif a.kind == 'type-annotate' then
                    return true
                  else
                    assert(nil, 'unreachable')
                  end
                end,
              })
            end)
          elseif ctx.method == 'shutdown' then
            eq(
              'function',
              exec_lua(function()
                return type(vim.lsp.commands['executed_preferred'])
              end)
            )
            eq(
              'function',
              exec_lua(function()
                return type(vim.lsp.commands['filtered_type_annotate_foo'])
              end)
            )
            eq(
              'function',
              exec_lua(function()
                return type(vim.lsp.commands['executed_type_annotate'])
              end)
            )
            client:stop()
          end
        end,
      }
    end)

    it('Fallback to command execution on resolve error', function()
      clear()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            executeCommandProvider = {
              commands = { 'command:1' },
            },
            codeActionProvider = {
              resolveProvider = true,
            },
          },
          handlers = {
            ['textDocument/codeAction'] = function(_, _, callback)
              callback(nil, {
                {
                  title = 'Code Action 1',
                  command = {
                    title = 'Command 1',
                    command = 'command:1',
                  },
                },
              })
            end,
            ['codeAction/resolve'] = function(_, _, callback)
              callback('resolve failed', nil)
            end,
          },
        })

        local client_id = assert(vim.lsp.start({
          name = 'dummy',
          cmd = server.cmd,
        }))

        vim.lsp.buf.code_action({ apply = true })
        vim.lsp.stop_client(client_id)
        return server.messages
      end)
      eq('codeAction/resolve', result[4].method)
      eq('workspace/executeCommand', result[5].method)
      eq('command:1', result[5].params.command)
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
      local client --- @type vim.lsp.Client
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'clientside_commands',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function() end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            local fake_uri = 'file:///fake/uri'
            local cmd = exec_lua(function()
              local bufnr = vim.uri_to_bufnr(fake_uri)
              vim.fn.bufload(bufnr)
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'One line' })
              local lenses = {
                {
                  range = {
                    start = { line = 0, character = 0 },
                    ['end'] = { line = 0, character = 8 },
                  },
                  command = { title = 'Lens1', command = 'Dummy' },
                },
              }
              vim.lsp.codelens.on_codelens(
                nil,
                lenses,
                { method = 'textDocument/codeLens', client_id = 1, bufnr = bufnr }
              )
              local cmd_called = nil
              vim.lsp.commands['Dummy'] = function(command0)
                cmd_called = command0
              end
              vim.api.nvim_set_current_buf(bufnr)
              vim.lsp.codelens.run()
              return cmd_called
            end)
            eq({ command = 'Dummy', title = 'Lens1' }, cmd)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('releases buffer refresh lock', function()
      local client --- @type vim.lsp.Client
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      test_rpc_server {
        test_name = 'codelens_refresh_lock',
        on_init = function(client_)
          client = client_
        end,
        on_setup = function()
          exec_lua(function()
            local bufnr = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'One line' })
            vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)

            _G.CALLED = false
            _G.RESPONSE = nil
            local on_codelens = vim.lsp.codelens.on_codelens
            vim.lsp.codelens.on_codelens = function(err, result, ...)
              _G.CALLED = true
              _G.RESPONSE = { err = err, result = result }
              return on_codelens(err, result, ...)
            end
          end)
        end,
        on_exit = function(code, signal)
          eq(0, code, 'exit code')
          eq(0, signal, 'exit signal')
        end,
        on_handler = function(err, result, ctx)
          eq(table.remove(expected_handlers), { err, result, ctx })
          if ctx.method == 'start' then
            -- 1. first codelens request errors
            local response = exec_lua(function()
              _G.CALLED = false
              vim.lsp.codelens.refresh()
              vim.wait(100, function()
                return _G.CALLED
              end)
              return _G.RESPONSE
            end)
            eq({ err = { code = -32002, message = 'ServerNotInitialized' } }, response)

            -- 2. second codelens request runs
            response = exec_lua(function()
              _G.CALLED = false
              local cmd_called --- @type string?
              vim.lsp.commands['Dummy'] = function(command0)
                cmd_called = command0
              end
              vim.lsp.codelens.refresh()
              vim.wait(100, function()
                return _G.CALLED
              end)
              vim.lsp.codelens.run()
              vim.wait(100, function()
                return cmd_called ~= nil
              end)
              return cmd_called
            end)
            eq({ command = 'Dummy', title = 'Lens1' }, response)

            -- 3. third codelens request runs
            response = exec_lua(function()
              _G.CALLED = false
              local cmd_called --- @type string?
              vim.lsp.commands['Dummy'] = function(command0)
                cmd_called = command0
              end
              vim.lsp.codelens.refresh()
              vim.wait(100, function()
                return _G.CALLED
              end)
              vim.lsp.codelens.run()
              vim.wait(100, function()
                return cmd_called ~= nil
              end)
              return cmd_called
            end)
            eq({ command = 'Dummy', title = 'Lens2' }, response)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('refresh multiple buffers', function()
      local lens_title_per_fake_uri = {
        ['file:///fake/uri1'] = 'Lens1',
        ['file:///fake/uri2'] = 'Lens2',
      }
      clear()
      exec_lua(create_server_definition)

      -- setup lsp
      exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            codeLensProvider = {
              resolveProvider = true,
            },
          },
          handlers = {
            ['textDocument/codeLens'] = function(_, params, callback)
              local lenses = {
                {
                  range = {
                    start = { line = 0, character = 0 },
                    ['end'] = { line = 0, character = 0 },
                  },
                  command = {
                    title = lens_title_per_fake_uri[params.textDocument.uri],
                    command = 'Dummy',
                  },
                },
              }
              callback(nil, lenses)
            end,
          },
        })

        _G.CLIENT_ID = vim.lsp.start({
          name = 'dummy',
          cmd = server.cmd,
        })
      end)

      -- create buffers and setup handler
      exec_lua(function()
        local default_buf = vim.api.nvim_get_current_buf()
        for fake_uri in pairs(lens_title_per_fake_uri) do
          local bufnr = vim.uri_to_bufnr(fake_uri)
          vim.api.nvim_set_current_buf(bufnr)
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Some contents' })
          vim.lsp.buf_attach_client(bufnr, _G.CLIENT_ID)
        end
        vim.api.nvim_buf_delete(default_buf, { force = true })

        _G.REQUEST_COUNT = vim.tbl_count(lens_title_per_fake_uri)
        _G.RESPONSES = {}
        local on_codelens = vim.lsp.codelens.on_codelens
        vim.lsp.codelens.on_codelens = function(err, result, ctx, ...)
          table.insert(_G.RESPONSES, { err = err, result = result, ctx = ctx })
          return on_codelens(err, result, ctx, ...)
        end
      end)

      -- call codelens refresh
      local cmds = exec_lua(function()
        _G.RESPONSES = {}
        vim.lsp.codelens.refresh()
        vim.wait(100, function()
          return #_G.RESPONSES >= _G.REQUEST_COUNT
        end)

        local cmds = {}
        for _, resp in ipairs(_G.RESPONSES) do
          local uri = resp.ctx.params.textDocument.uri
          cmds[uri] = resp.result[1].command
        end
        return cmds
      end)
      eq({ command = 'Dummy', title = 'Lens1' }, cmds['file:///fake/uri1'])
      eq({ command = 'Dummy', title = 'Lens2' }, cmds['file:///fake/uri2'])
    end)
  end)

  describe('vim.lsp.buf.format', function()
    it('Aborts with notify if no client matches filter', function()
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_init',
        on_init = function(c)
          client = c
        end,
        on_handler = function()
          local notify_msg = exec_lua(function()
            local bufnr = vim.api.nvim_get_current_buf()
            vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
            local notify_msg --- @type string?
            local notify = vim.notify
            vim.notify = function(msg, _)
              notify_msg = msg
            end
            vim.lsp.buf.format({ name = 'does-not-exist' })
            vim.notify = notify
            return notify_msg
          end)
          eq('[LSP] Format request failed, no matching language servers.', notify_msg)
          client:stop()
        end,
      }
    end)

    it('Sends textDocument/formatting request to format buffer', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_formatting',
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == 'start' then
            local notify_msg = exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              local notify_msg --- @type string?
              local notify = vim.notify
              vim.notify = function(msg, _)
                notify_msg = msg
              end
              vim.lsp.buf.format({ bufnr = bufnr })
              vim.notify = notify
              return notify_msg
            end)
            eq(nil, notify_msg)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('Sends textDocument/rangeFormatting request to format a range', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'range_formatting',
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == 'start' then
            local notify_msg = exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'foo', 'bar' })
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              local notify_msg --- @type string?
              local notify = vim.notify
              vim.notify = function(msg, _)
                notify_msg = msg
              end
              vim.lsp.buf.format({
                bufnr = bufnr,
                range = {
                  start = { 1, 1 },
                  ['end'] = { 1, 1 },
                },
              })
              vim.notify = notify
              return notify_msg
            end)
            eq(nil, notify_msg)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('Sends textDocument/rangesFormatting request to format multiple ranges', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'ranges_formatting',
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == 'start' then
            local notify_msg = exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'foo', 'bar', 'baz' })
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)
              local notify_msg --- @type string?
              local notify = vim.notify
              vim.notify = function(msg, _)
                notify_msg = msg
              end
              vim.lsp.buf.format({
                bufnr = bufnr,
                range = {
                  {
                    start = { 1, 1 },
                    ['end'] = { 1, 1 },
                  },
                  {
                    start = { 2, 2 },
                    ['end'] = { 2, 2 },
                  },
                },
              })
              vim.notify = notify
              return notify_msg
            end)
            eq(nil, notify_msg)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('Can format async', function()
      local expected_handlers = {
        { NIL, {}, { method = 'shutdown', client_id = 1 } },
        { NIL, {}, { method = 'start', client_id = 1 } },
      }
      local client --- @type vim.lsp.Client
      test_rpc_server {
        test_name = 'basic_formatting',
        on_init = function(c)
          client = c
        end,
        on_handler = function(_, _, ctx)
          table.remove(expected_handlers)
          if ctx.method == 'start' then
            local result = exec_lua(function()
              local bufnr = vim.api.nvim_get_current_buf()
              vim.lsp.buf_attach_client(bufnr, _G.TEST_RPC_CLIENT_ID)

              local notify_msg --- @type string?
              local notify = vim.notify
              vim.notify = function(msg, _)
                notify_msg = msg
              end

              local handler = vim.lsp.handlers['textDocument/formatting']
              local handler_called = false
              vim.lsp.handlers['textDocument/formatting'] = function()
                handler_called = true
              end

              vim.lsp.buf.format({ bufnr = bufnr, async = true })
              vim.wait(1000, function()
                return handler_called
              end)

              vim.notify = notify
              vim.lsp.handlers['textDocument/formatting'] = handler
              return { notify = notify_msg, handler_called = handler_called }
            end)
            eq({ handler_called = true }, result)
          elseif ctx.method == 'shutdown' then
            client:stop()
          end
        end,
      }
    end)

    it('format formats range in visual mode', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            documentFormattingProvider = true,
            documentRangeFormattingProvider = true,
          },
        })
        local bufnr = vim.api.nvim_get_current_buf()
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        vim.api.nvim_win_set_buf(0, bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'foo', 'bar' })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.cmd.normal('v')
        vim.api.nvim_win_set_cursor(0, { 2, 3 })
        vim.lsp.buf.format({ bufnr = bufnr, false })
        vim.lsp.stop_client(client_id)
        return server.messages
      end)
      eq('textDocument/rangeFormatting', result[3].method)
      local expected_range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = 1, character = 4 },
      }
      eq(expected_range, result[3].params.range)
    end)

    it('format formats range in visual line mode', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local server = _G._create_server({
          capabilities = {
            documentFormattingProvider = true,
            documentRangeFormattingProvider = true,
          },
        })
        local bufnr = vim.api.nvim_get_current_buf()
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        vim.api.nvim_win_set_buf(0, bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'foo', 'bar baz' })
        vim.api.nvim_win_set_cursor(0, { 1, 2 })
        vim.cmd.normal('V')
        vim.api.nvim_win_set_cursor(0, { 2, 1 })
        vim.lsp.buf.format({ bufnr = bufnr, false })

        -- Format again with visual lines going from bottom to top
        -- Must result in same formatting
        vim.cmd.normal('<ESC>')
        vim.api.nvim_win_set_cursor(0, { 2, 1 })
        vim.cmd.normal('V')
        vim.api.nvim_win_set_cursor(0, { 1, 2 })
        vim.lsp.buf.format({ bufnr = bufnr, false })

        vim.lsp.stop_client(client_id)
        return server.messages
      end)
      local expected_methods = {
        'initialize',
        'initialized',
        'textDocument/rangeFormatting',
        '$/cancelRequest',
        'textDocument/rangeFormatting',
        '$/cancelRequest',
        'shutdown',
        'exit',
      }
      eq(
        expected_methods,
        vim.tbl_map(function(x)
          return x.method
        end, result)
      )
      -- uses first column of start line and last column of end line
      local expected_range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = 1, character = 7 },
      }
      eq(expected_range, result[3].params.range)
      eq(expected_range, result[5].params.range)
    end)

    it('Aborts with notify if no clients support requested method', function()
      exec_lua(create_server_definition)
      exec_lua(function()
        vim.notify = function(msg, _)
          _G.notify_msg = msg
        end
      end)
      local fail_msg = '[LSP] Format request failed, no matching language servers.'
      --- @param name string
      --- @param formatting boolean
      --- @param range_formatting boolean
      local function check_notify(name, formatting, range_formatting)
        local timeout_msg = '[LSP][' .. name .. '] timeout'
        exec_lua(function()
          local server = _G._create_server({
            capabilities = {
              documentFormattingProvider = formatting,
              documentRangeFormattingProvider = range_formatting,
            },
          })
          vim.lsp.start({ name = name, cmd = server.cmd })
          _G.notify_msg = nil
          vim.lsp.buf.format({ name = name, timeout_ms = 1 })
        end)
        eq(
          formatting and timeout_msg or fail_msg,
          exec_lua(function()
            return _G.notify_msg
          end)
        )
        exec_lua(function()
          _G.notify_msg = nil
          vim.lsp.buf.format({
            name = name,
            timeout_ms = 1,
            range = {
              start = { 1, 0 },
              ['end'] = {
                1,
                0,
              },
            },
          })
        end)
        eq(
          range_formatting and timeout_msg or fail_msg,
          exec_lua(function()
            return _G.notify_msg
          end)
        )
      end
      check_notify('none', false, false)
      check_notify('formatting', true, false)
      check_notify('rangeFormatting', false, true)
      check_notify('both', true, true)
    end)
  end)

  describe('lsp.buf.definition', function()
    it('jumps to single location', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local bufnr = vim.api.nvim_get_current_buf()
        local server = _G._create_server({
          capabilities = {
            definitionProvider = true,
          },
          handlers = {
            ['textDocument/definition'] = function(_, _, callback)
              local location = {
                range = {
                  start = { line = 0, character = 0 },
                  ['end'] = { line = 0, character = 0 },
                },
                uri = vim.uri_from_bufnr(bufnr),
              }
              callback(nil, location)
            end,
          },
        })
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'local x = 10', '', 'print(x)' })
        vim.api.nvim_win_set_cursor(win, { 3, 6 })
        local client_id = assert(vim.lsp.start({ name = 'dummy', cmd = server.cmd }))
        vim.lsp.buf.definition()
        vim.lsp.stop_client(client_id)
        return {
          cursor = vim.api.nvim_win_get_cursor(win),
          messages = server.messages,
          tagstack = vim.fn.gettagstack(win),
        }
      end)
      eq('textDocument/definition', result.messages[3].method)
      eq({ 1, 0 }, result.cursor)
      eq(1, #result.tagstack.items)
      eq('x', result.tagstack.items[1].tagname)
      eq(3, result.tagstack.items[1].from[2])
      eq(7, result.tagstack.items[1].from[3])
    end)
    it('merges results from multiple servers', function()
      exec_lua(create_server_definition)
      local result = exec_lua(function()
        local bufnr = vim.api.nvim_get_current_buf()
        local function serveropts(character)
          return {
            capabilities = {
              definitionProvider = true,
            },
            handlers = {
              ['textDocument/definition'] = function(_, _, callback)
                local location = {
                  range = {
                    start = { line = 0, character = character },
                    ['end'] = { line = 0, character = character },
                  },
                  uri = vim.uri_from_bufnr(bufnr),
                }
                callback(nil, location)
              end,
            },
          }
        end
        local server1 = _G._create_server(serveropts(0))
        local server2 = _G._create_server(serveropts(7))
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { 'local x = 10', '', 'print(x)' })
        vim.api.nvim_win_set_cursor(win, { 3, 6 })
        local client_id1 = assert(vim.lsp.start({ name = 'dummy', cmd = server1.cmd }))
        local client_id2 = assert(vim.lsp.start({ name = 'dummy', cmd = server2.cmd }))
        local response
        vim.lsp.buf.definition({
          on_list = function(r)
            response = r
          end,
        })
        vim.lsp.stop_client(client_id1)
        vim.lsp.stop_client(client_id2)
        return response
      end)
      eq(2, #result.items)
    end)
  end)

  describe('vim.lsp.tagfunc', function()
    before_each(function()
      clear()
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
        vim.lsp.stop_client(_G.client_id)
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
  end)

  describe('cmd', function()
    it('connects to lsp server via rpc.connect using ip address', function()
      exec_lua(create_tcp_echo_server)
      local result = exec_lua(function()
        local server, port, last_message = _G._create_tcp_server('127.0.0.1')
        vim.lsp.start({ name = 'dummy', cmd = vim.lsp.rpc.connect('127.0.0.1', port) })
        vim.wait(1000, function()
          return last_message() ~= nil
        end)
        local init = last_message()
        assert(init, 'server must receive `initialize` request')
        server:close()
        server:shutdown()
        return vim.json.decode(init)
      end)
      eq('initialize', result.method)
    end)

    it('connects to lsp server via rpc.connect using hostname', function()
      skip(is_os('bsd'), 'issue with host resolution in ci')
      exec_lua(create_tcp_echo_server)
      local result = exec_lua(function()
        local server, port, last_message = _G._create_tcp_server('::1')
        vim.lsp.start({ name = 'dummy', cmd = vim.lsp.rpc.connect('localhost', port) })
        vim.wait(1000, function()
          return last_message() ~= nil
        end)
        local init = last_message()
        assert(init, 'server must receive `initialize` request')
        server:close()
        server:shutdown()
        return vim.json.decode(init)
      end)
      eq('initialize', result.method)
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
        local function check(method, fname)
          local bufnr = fname and vim.fn.bufadd(fname) or nil
          local client = assert(vim.lsp.get_client_by_id(client_id))
          result[#result + 1] = {
            method = method,
            fname = fname,
            supported = client:supports_method(method, { bufnr = bufnr }),
          }
        end

        check('textDocument/formatting')
        check('textDocument/formatting', tmpfile)
        check('textDocument/rangeFormatting')
        check('textDocument/rangeFormatting', tmpfile)
        check('textDocument/completion')

        return result
      end)

      eq(5, #result)
      eq({ method = 'textDocument/formatting', supported = false }, result[1])
      eq({ method = 'textDocument/formatting', supported = true, fname = tmpfile }, result[2])
      eq({ method = 'textDocument/rangeFormatting', supported = true }, result[3])
      eq({ method = 'textDocument/rangeFormatting', supported = true, fname = tmpfile }, result[4])
      eq({ method = 'textDocument/completion', supported = false }, result[5])
    end)
  end)

  describe('vim.lsp._watchfiles', function()
    --- @type integer, integer, integer
    local created, changed, deleted

    setup(function()
      clear()
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

            vim.lsp.stop_client(client_id)

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

          vim.lsp.stop_client(client_id, true)
          return _G.watching
        end)
      end

      eq(is_os('mac') or is_os('win'), check_registered(nil)) -- start{_client}() defaults to make_client_capabilities().
      eq(false, check_registered(vim.empty_dict()))
      eq(
        false,
        check_registered({
          workspace = {
            ignoreMe = true,
          },
        })
      )
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
end)
