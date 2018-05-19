local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
-- local eq = helpers.eq
-- local funcs = helpers.funcs
-- local command = helpers.command
local source = helpers.source
local dedent = helpers.dedent

local lua = helpers.exec_lua

describe('LSP Callback Configuration', function()
  before_each(function()
    clear()
    source(dedent([[
      lua << EOF
        lsp_callbacks = require('lsp.callbacks')
        lsp_config = require('lsp.config.callbacks')

        eq = function(a, b)
          if(a ~= b) then
            print(require('neovim.util').tostring(a))
            print(require('neovim.util').tostring(b))
          end

          assert(a == b)
        end
      EOF
    ]]))
  end)

  it('should have some default configurations', function()
    lua[[callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover')]]
    lua[[hover = lsp_callbacks.callbacks.textDocument.hover.default[1] ]]

    lua[[eq(callback_list[1], hover)]]
  end)

  it('should handle generic configurations', function()
    lua[[test_func = function(a, b) return a + b end]]

    lua[[lsp_config.add_callback('textDocument/hover', test_func)]]
    lua[[callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover')]]

    lua[[assert(callback_list[2] == test_func)]]
  end)

  it('should handle filetype configurations', function()
    lua[[filetype_func = function(a, b) return a + b end]]
    lua[[lsp_config.add_callback('textDocument/hover', filetype_func, false, 'python')]]

    -- Get the default callback list
    lua[[callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover')]]
    lua[[hover = lsp_callbacks.callbacks.textDocument.hover.default[1] ]]

    lua[[eq(callback_list[1], hover)]]

    -- Get the callback list for a filetype
    lua[[callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover', nil, 'python')]]
    lua[[eq(callback_list[2], filetype_func)]]

    -- Can override by getting default only
    lua[[callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover', nil, 'python', true)]]
    lua[[eq(1, #callback_list)]]
  end)

  it('should handle overriding default configuration', function()
      lua[[override_func = function(a, b) return a - b end]]

      lua[[lsp_config.add_callback('textDocument/definition', override_func, true)]]
      lua[[callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/definition')]]
      lua[[eq(callback_list[1], override_func)]]
      lua[[eq(#callback_list, 1)]]
  end)

  it('should handle running default callback even after adding configuration', function()
  end)

  it('should not run filetype configuration in other filetypes', function()
  end)

  it('should allow complete disabling of default configuration', function()
  end)

  it('should handle adding callbacks for new/custom methods', function()
  end)

  it('should be able to determine whether default configuration exists for a method', function()
  end)
end)
