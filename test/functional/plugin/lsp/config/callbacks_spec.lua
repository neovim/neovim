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
        lsp_callbacks = require('vim.lsp.callbacks')
        lsp_config = require('vim.lsp.config')

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

  describe("any callbacks are not set", function()
    it('should have no builtin callbacks', function()
      eq(0, exec_lua("return count_callback()"))
    end)
  end)

  describe("'textDocument/hover' builtin callback is set", function()
    it("should have a 'textDocument/hover' builtin callback", function()
      exec_lua("lsp_config.set_builtin_callback('textDocument/hover')")
      exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

      eq(true, exec_lua("return lsp_callbacks._callback_mapping['textDocument/hover'].common[1] ~= nil"))
      eq(1, exec_lua("return count_callback()"))
    end)
  end)

  describe("all builtin callbacks are set", function()
    it('should have some builtin callbacks', function()
      exec_lua("lsp_config:set_all_builtin_callbacks()")
      exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")
      exec_lua("hover = lsp_callbacks._callback_mapping['textDocument/hover'].common[1] ")

      eq(true, exec_lua("return callback_list[1] == hover"))
    end)
  end)

  describe("add two callbacks that are not for specific filetypes to same method", function()
    before_each(function()
      exec_lua("lsp_config:set_all_builtin_callbacks()")
      exec_lua("test_func = function(a, b) return a + b end")
      exec_lua("lsp_config.add_callback('textDocument/hover', test_func)")
    end)

    describe("get callback of a method", function()
      it('should have two common callbacks', function()
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

        eq(true, exec_lua("return #callback_list == 2"))
        eq(true, exec_lua("return callback_list[2] == test_func"))
      end)
    end)

    describe("get callback of a method for specific filetypes", function()
      it('should have two common callbacks', function()
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover', 'python')")

        eq(true, exec_lua("return #callback_list == 2"))
        eq(true, exec_lua("return callback_list[2] == test_func"))
      end)
    end)
  end)

  describe("add two callbacks to the same method. one of those is for specific filetypes", function()
    before_each(function()
      exec_lua("lsp_config:set_all_builtin_callbacks()")
      exec_lua("filetype_func = function(a, b) return a + b end")
      exec_lua("lsp_config.add_callback('textDocument/hover', filetype_func, 'python')")
    end)

    describe("get callback of a method", function()
      it('should have a common callback', function()
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")
        exec_lua("hover_callback = lsp_callbacks._callback_mapping['textDocument/hover'].common[1] ")

        eq(true, exec_lua("return #callback_list == 1"))
        eq(true, exec_lua("return callback_list[1] == hover_callback"))
      end)
    end)

    describe("get callback of a method for specific filetypes", function()
      it('should have a specific filetype callback', function()
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover', 'python')")

        eq(true, exec_lua("return #callback_list == 1"))
        eq(true, exec_lua("return callback_list[1] == filetype_func"))
      end)
    end)
  end)

  describe("set a callback that is not for specific filetypes after adding a callbacks to the same method", function()
    it('should have only a callback which is defined after', function()
        exec_lua("lsp_config:set_all_builtin_callbacks()")
        exec_lua("override_func = function(a, b) return a - b end")

        exec_lua("lsp_config.set_callback('textDocument/hover', override_func)")
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

        eq(true, exec_lua("return callback_list[1] == override_func"))
        eq(true, exec_lua("return #callback_list == 1"))
    end)
  end)

  describe("set a callback that is for specific filetypes after adding a callbacks to the same method", function()
    it('should have only a callback which is defined after', function()
        exec_lua("lsp_config:set_all_builtin_callbacks()")
        exec_lua("override_func = function(a, b) return a - b end")

        exec_lua("lsp_config.set_callback('textDocument/hover', override_func, 'python')")
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

        eq(true, exec_lua("return callback_list[1] ~= override_func"))
        eq(true, exec_lua("return #callback_list == 1"))

        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover', 'python')")

        eq(true, exec_lua("return callback_list[1] == override_func"))
        eq(true, exec_lua("return #callback_list == 1"))
    end)
  end)
end)
