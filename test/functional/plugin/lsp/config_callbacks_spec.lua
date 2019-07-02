local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local source = helpers.source
local dedent = helpers.dedent

local exec_lua = helpers.exec_lua

describe('LSP Callback Configuration', function()
  before_each(function()
    clear()
    source(dedent([[
      lua << EOF
        inspect = require('inspect')
        lsp_callbacks = require('lsp.callbacks')
        lsp_config = require('lsp.config.callbacks')

        count_callback = function()
          local callback_length = 0
          for _k, _v in pairs(lsp_callbacks._callback_mapping) do
            callback_length = callback_length + 1
          end
          return callback_length
        end
      EOF
    ]]))
  end)

  it('should have no builtin callback', function()
    eq(0, exec_lua("return count_callback()"))
  end)

  it('should have a textDocument/hover builtin callback', function()
    exec_lua("lsp_callbacks.add_text_document_hover_callback()")
    exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

    eq(false, exec_lua("return lsp_callbacks._callback_mapping['textDocument/hover'].common[1] == null"))
    eq(1, exec_lua("return count_callback()"))
  end)

  it('should have some builtin configurations', function()
    exec_lua("lsp_callbacks.add_all_builtin_callbacks()")
    exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")
    exec_lua("hover = lsp_callbacks._callback_mapping['textDocument/hover'].common[1] ")

    eq(true, exec_lua("return callback_list[1] == hover"))
  end)

  it('should handle generic configurations', function()
    exec_lua("lsp_callbacks.add_all_builtin_callbacks()")
    exec_lua("test_func = function(a, b) return a + b end")

    exec_lua("lsp_config.add_callback('textDocument/hover', test_func)")
    exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

    eq(true, exec_lua("return callback_list[2] == test_func"))
  end)

  it('should handle filetype configurations', function()
    exec_lua("lsp_callbacks.add_all_builtin_callbacks()")
    exec_lua("filetype_func = function(a, b) return a + b end")
    exec_lua("lsp_config.add_callback('textDocument/hover', filetype_func, 'python')")

    -- Get the builtin callback list
    exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")
    exec_lua("hover = lsp_callbacks._callback_mapping['textDocument/hover'].common[1] ")

    eq(true, exec_lua("return callback_list[1] == hover"))

    -- Get the callback list for a filetype
    exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover', 'python')")
    eq(true, exec_lua("return callback_list[2] == filetype_func"))

    eq(true, exec_lua("return #callback_list == 2"))
  end)

  it('should handle overriding builtin configuration', function()
      exec_lua("lsp_callbacks.add_all_builtin_callbacks()")
      exec_lua("override_func = function(a, b) return a - b end")

      exec_lua("lsp_config.add_callback('textDocument/definition', override_func)")
      exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/definition')")

      eq(true, exec_lua("return callback_list[2] == override_func"))
      eq(true, exec_lua("return #callback_list == 2"))
  end)

  it('should handle running builtin callback even after adding configuration', function()
  end)

  it('should not run filetype configuration in other filetypes', function()
  end)

  it('should allow complete disabling of builtin configuration', function()
  end)

  it('should handle adding callbacks for new/custom methods', function()
  end)

  it('should be able to determine whether builtin configuration exists for a method', function()
  end)
end)
