local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')

local eq = t.eq
local create_server_definition = t_lsp.create_server_definition
local exec_lua = n.exec_lua

describe('LSP initialization', function()
  before_each(function()
    n.clear()
    exec_lua(create_server_definition)
  end)

  it('serializes empty initializationOptions as an object, not an array', function()
    local result = exec_lua(function()
      local captured_init_options_raw
      local server = _G._create_server({
        handlers = {
          initialize = function(_, params, _)
            -- Store the raw JSON to examine serialization
            captured_init_options_raw = vim.fn.json_encode(params.initializationOptions)
            return {
              capabilities = {},
            }
          end,
        },
      })

      -- Start an LSP client with empty init_options
      local client_id = vim.lsp.start({
        name = 'test-empty-init-options',
        cmd = server.cmd,
        -- This should be serialized as an object {}, not an array []
        init_options = {},
      })

      -- Wait for initialization to complete
      vim.wait(1000, function()
        return captured_init_options_raw ~= nil
      end)

      -- Stop the client
      vim.lsp.stop_client(client_id)

      return captured_init_options_raw
    end)

    -- Verify that empty initializationOptions are serialized as '{}' (object)
    -- and not '[]' (array)
    eq('{}', result)
  end)

  it('preserves non-empty initializationOptions correctly', function()
    local result = exec_lua(function()
      local captured_init_options
      local server = _G._create_server({
        handlers = {
          initialize = function(_, params, _)
            captured_init_options = params.initializationOptions
            return {
              capabilities = {},
            }
          end,
        },
      })

      -- Start an LSP client with non-empty init_options
      local client_id = vim.lsp.start({
        name = 'test-non-empty-init-options',
        cmd = server.cmd,
        init_options = {
          setting1 = 'value1',
          setting2 = 42,
        },
      })

      -- Wait for initialization to complete
      vim.wait(1000, function()
        return captured_init_options ~= nil
      end)

      -- Stop the client
      vim.lsp.stop_client(client_id)

      return captured_init_options
    end)

    -- Verify that non-empty initializationOptions are preserved correctly
    eq({
      setting1 = 'value1',
      setting2 = 42,
    }, result)
  end)
end)
