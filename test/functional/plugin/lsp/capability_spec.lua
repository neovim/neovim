local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')

local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local eq = t.eq

local exec_lua = n.exec_lua

local clear_notrace = t_lsp.clear_notrace
local create_server_definition = t_lsp.create_server_definition

describe('vim.lsp._capability', function()
  ---@type integer, integer
  local buf, client_id

  before_each(function()
    clear_notrace()

    exec_lua(create_server_definition)
    exec_lua(function()
      _G.server = _G._create_server({
        textDocumentSync = vim.lsp.protocol.TextDocumentSyncKind.Full,
        codeLensProvider = {
          resolveProvider = true,
        },
        handlers = {},
      })

      buf = vim.api.nvim_get_current_buf()
      client_id = assert(vim.lsp.start({ name = 'dummy', cmd = _G.server.cmd }))
    end)
  end)

  after_each(function()
    local client = vim.lsp.get_client_by_id(client_id)
    if client then
      client:stop()
    end
  end)

  describe('is_enabled()', function()
    ---Each field means an explicitely set value, `nil` means it's not set and will be inherited.
    ---@class (private) test.functional.capability.enable_config
    ---@field global boolean capability.enable(<name>, global)
    ---@field client boolean? capability.enable(<name>, client, { client_id = <id> })
    ---@field buf boolean? capability.enable(<name>, buf, { bufnr = <bufnr> })
    ---@field client_buf boolean? capability.enable(<name>, client_buf, { client_id = <id>, bufnr = <bufnr> })

    ---@class (private) test.functional.capability.enable_state
    ---@field global boolean capability.is_enabled(<name>)
    ---@field client boolean capability.is_enabled(<name>, { client_id = <id> })
    ---@field buf boolean capability.is_enabled(<name>, { bufnr = <bufnr> })
    ---@field client_buf boolean capability.is_enabled(<name>, { client_id = <id>, bufnr = <bufnr> })

    ---@class (private) tests.functional.capability.is_enabled_test_case
    ---@field config test.functional.capability.enable_config
    ---@field expected test.functional.capability.enable_state

    ---@type tests.functional.capability.is_enabled_test_case[]
    local cases = {
      -- Various versions of "all true".
      {
        config = { global = true },
        expected = { global = true, client = true, buf = true, client_buf = true },
      },
      {
        config = { global = true, client = true },
        expected = { global = true, client = true, buf = true, client_buf = true },
      },
      {
        config = { global = true, buf = true },
        expected = { global = true, client = true, buf = true, client_buf = true },
      },
      {
        config = { global = true, client_buf = true },
        expected = { global = true, client = true, buf = true, client_buf = true },
      },
      {
        config = { global = true, client = true, buf = true },
        expected = { global = true, client = true, buf = true, client_buf = true },
      },
      {
        config = { global = true, client = true, client_buf = true },
        expected = { global = true, client = true, buf = true, client_buf = true },
      },
      {
        config = { global = true, buf = true, client_buf = true },
        expected = { global = true, client = true, buf = true, client_buf = true },
      },
      {
        config = { global = true, client = true, buf = true, client_buf = true },
        expected = { global = true, client = true, buf = true, client_buf = true },
      },

      -- Various versions of "all false".
      {
        config = { global = false },
        expected = { global = false, client = false, buf = false, client_buf = false },
      },
      {
        config = { global = false, client = false },
        expected = { global = false, client = false, buf = false, client_buf = false },
      },
      {
        config = { global = false, buf = false },
        expected = { global = false, client = false, buf = false, client_buf = false },
      },
      {
        config = { global = false, client_buf = false },
        expected = { global = false, client = false, buf = false, client_buf = false },
      },
      {
        config = { global = false, client = false, buf = false },
        expected = { global = false, client = false, buf = false, client_buf = false },
      },
      {
        config = { global = false, client = false, client_buf = false },
        expected = { global = false, client = false, buf = false, client_buf = false },
      },
      {
        config = { global = false, buf = false, client_buf = false },
        expected = { global = false, client = false, buf = false, client_buf = false },
      },
      {
        config = { global = false, client = false, buf = false, client_buf = false },
        expected = { global = false, client = false, buf = false, client_buf = false },
      },

      -- globally enabled, some disabled
      {
        config = { global = true, client = false },
        expected = { global = true, client = false, buf = true, client_buf = false },
      },
      {
        config = { global = true, buf = false },
        expected = { global = true, client = true, buf = false, client_buf = false },
      },
      {
        config = { global = true, client_buf = false },
        expected = { global = true, client = true, buf = true, client_buf = false },
      },
      {
        config = { global = true, client = false, buf = false },
        expected = { global = true, client = false, buf = false, client_buf = false },
      },
      {
        config = { global = true, client = false, client_buf = false },
        expected = { global = true, client = false, buf = true, client_buf = false },
      },
      {
        config = { global = true, buf = false, client_buf = false },
        expected = { global = true, client = true, buf = false, client_buf = false },
      },
      {
        config = { global = true, client = false, buf = false, client_buf = false },
        expected = { global = true, client = false, buf = false, client_buf = false },
      },

      -- globally disabled, some enabled
      {
        config = { global = false, client = true },
        expected = { global = false, client = true, buf = false, client_buf = true },
      },
      {
        config = { global = false, buf = true },
        expected = { global = false, client = false, buf = true, client_buf = false },
      },
      {
        config = { global = false, client_buf = true },
        expected = { global = false, client = false, buf = false, client_buf = true },
      },
      {
        config = { global = false, client = true, buf = true },
        expected = { global = false, client = true, buf = true, client_buf = true },
      },
      {
        config = { global = false, client = true, client_buf = true },
        expected = { global = false, client = true, buf = false, client_buf = true },
      },
      {
        config = { global = false, buf = true, client_buf = true },
        expected = { global = false, client = false, buf = true, client_buf = true },
      },
      {
        config = { global = false, client = true, buf = true, client_buf = true },
        expected = { global = false, client = true, buf = true, client_buf = true },
      },

      -- enabled globally and for client, some disabled
      {
        config = { global = true, client = true, buf = false },
        expected = { global = true, client = true, buf = false, client_buf = false },
      },
      {
        config = { global = true, client = true, client_buf = false },
        expected = { global = true, client = true, buf = true, client_buf = false },
      },
      {
        config = { global = true, client = true, buf = false, client_buf = false },
        expected = { global = true, client = true, buf = false, client_buf = false },
      },
      -- disabled globally and for client, some enabled
      {
        config = { global = false, client = false, buf = true },
        expected = { global = false, client = false, buf = true, client_buf = false },
      },
      {
        config = { global = false, client = false, client_buf = true },
        expected = { global = false, client = false, buf = false, client_buf = true },
      },
      {
        config = { global = false, client = false, buf = true, client_buf = true },
        expected = { global = false, client = false, buf = true, client_buf = true },
      },

      -- enabled globally and for buf, some disabled
      {
        config = { global = true, client = false, buf = true },
        expected = { global = true, client = false, buf = true, client_buf = false },
      },
      {
        config = { global = true, buf = true, client_buf = false },
        expected = { global = true, client = true, buf = true, client_buf = false },
      },
      {
        config = { global = true, client = false, buf = true, client_buf = false },
        expected = { global = true, client = false, buf = true, client_buf = false },
      },
      -- disabled globally and for buf, some enabled
      {
        config = { global = false, client = true, buf = false },
        expected = { global = false, client = true, buf = false, client_buf = false },
      },
      {
        config = { global = false, buf = false, client_buf = true },
        expected = { global = false, client = false, buf = false, client_buf = true },
      },
      {
        config = { global = false, client = true, buf = false, client_buf = true },
        expected = { global = false, client = true, buf = false, client_buf = true },
      },

      -- enabled globally and for client_buf, some disabled
      {
        config = { global = true, client = false, client_buf = true },
        expected = { global = true, client = false, buf = true, client_buf = true },
      },
      {
        config = { global = true, buf = false, client_buf = true },
        expected = { global = true, client = true, buf = false, client_buf = true },
      },
      {
        config = { global = true, client = false, buf = false, client_buf = true },
        expected = { global = true, client = false, buf = false, client_buf = true },
      },
      -- disabled globally and for client_buf, some enabled
      {
        config = { global = false, client = true, client_buf = false },
        expected = { global = false, client = true, buf = false, client_buf = false },
      },
      {
        config = { global = false, buf = true, client_buf = false },
        expected = { global = false, client = false, buf = true, client_buf = false },
      },
      {
        config = { global = false, client = true, buf = true, client_buf = false },
        expected = { global = false, client = true, buf = true, client_buf = false },
      },

      {
        config = { global = true, client = true, buf = true, client_buf = false },
        expected = { global = true, client = true, buf = true, client_buf = false },
      },
      {
        config = { global = true, client = true, buf = false, client_buf = true },
        expected = { global = true, client = true, buf = false, client_buf = true },
      },
      {
        config = { global = true, client = false, buf = true, client_buf = true },
        expected = { global = true, client = false, buf = true, client_buf = true },
      },
      {
        config = { global = false, client = true, buf = false, client_buf = false },
        expected = { global = false, client = true, buf = false, client_buf = false },
      },
      {
        config = { global = false, client = false, buf = true, client_buf = false },
        expected = { global = false, client = false, buf = true, client_buf = false },
      },
      {
        config = { global = false, client = false, buf = false, client_buf = true },
        expected = { global = false, client = false, buf = false, client_buf = true },
      },
    }

    for _, test_case in ipairs(cases) do
      local test_name = 'when enabling '
        .. vim.inspect(test_case.config, { newline = ' ', indent = '' })
      it(test_name, function()
        exec_lua(function()
          local cap = vim.lsp._capability
          local cfg = test_case.config
          assert(cfg.global ~= nil, 'global state must be explicit')

          cap.enable('diagnostics', cfg.global)

          if cfg.client ~= nil then
            cap.enable('diagnostics', cfg.client, { client_id = client_id })
          end

          if cfg.buf ~= nil then
            cap.enable('diagnostics', cfg.buf, { bufnr = buf })
          end

          if cfg.client_buf ~= nil then
            cap.enable('diagnostics', cfg.client_buf, { client_id = client_id, bufnr = buf })
          end
        end)

        local expected = test_case.expected
        ---@type test.functional.capability.enable_state
        local actual = exec_lua(function()
          local cap = vim.lsp._capability
          return {
            global = cap.is_enabled('diagnostics'),
            client = cap.is_enabled('diagnostics', { client_id = client_id }),
            buf = cap.is_enabled('diagnostics', { bufnr = buf }),
            client_buf = cap.is_enabled('diagnostics', { client_id = client_id, bufnr = buf }),
          }
        end)

        eq(expected.global, actual.global, 'global')
        eq(expected.client, actual.client, 'client')
        eq(expected.buf, actual.buf, 'buf')
        eq(expected.client_buf, actual.client_buf, 'client_buf')
      end)
    end
  end)
end)
