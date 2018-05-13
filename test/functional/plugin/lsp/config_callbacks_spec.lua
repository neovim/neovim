local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
-- local eq = helpers.eq
-- local funcs = helpers.funcs
-- local command = helpers.command
local source = helpers.source
local dedent = helpers.dedent

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
    source(dedent([[
      lua << EOF
        local callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover')
        local hover = lsp_callbacks.callbacks.textDocument.hover.default[1]

        eq(callback_list[1], hover)
      EOF
    ]]))
  end)

  it('should handle generic configurations', function()
    source(dedent([[
      lua << EOF
      local test_func = function(a, b) return a + b end

      lsp_config.add_callback('textDocument/hover', test_func)
      local callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover')

      assert(callback_list[2] == test_func)
      EOF
    ]]))
  end)

  it('should handle filetype configurations', function()
    source(dedent([[
      lua << EOF
        local filetype_func = function(a, b) return a + b end

        lsp_config.add_callback('textDocument/hover', filetype_func, false, 'python')

        -- Get the default callback list
        local callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover')
        local hover = lsp_callbacks.callbacks.textDocument.hover.default[1]

        eq(callback_list[1], hover)

        -- Get the callback list for a filetype
        local callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover', nil, 'python')
        eq(callback_list[2], filetype_func)

        -- Can override by getting default only
        local callback_list = lsp_callbacks.get_list_of_callbacks('textDocument/hover', nil, 'python', true)
        -- eq(1, #callback_list)

      EOF
    ]]))
  end)

  it('should handle overriding default configuration', function()
    source(dedent([[
      lua << EOF
        local a = 1
      EOF
    ]]))
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
