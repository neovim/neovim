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
    it('should have no callbacks', function()
      eq(0, exec_lua("return count_callback()"))
    end)
  end)

  describe("add two callbacks that are not for specific filetypes to same method", function()
    before_each(function()
      exec_lua("test_func_1 = function(a, b) return a + b end")
      exec_lua("test_func_2 = function(a, b, c) return a + b + c end")
      exec_lua("lsp_callbacks.add_callback('textDocument/hover', test_func_1)")
      exec_lua("lsp_callbacks.add_callback('textDocument/hover', test_func_2)")
    end)

    describe("get callback of a method", function()
      it('should have two common callbacks', function()
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

        eq(true, exec_lua("return #callback_list == 2"))
        eq(true, exec_lua("return callback_list[1] == test_func_1"))
        eq(true, exec_lua("return callback_list[2] == test_func_2"))
      end)
    end)

    describe("get callback of a method for specific filetypes", function()
      it('should have two common callbacks', function()
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover', 'python')")

        eq(true, exec_lua("return #callback_list == 2"))
        eq(true, exec_lua("return callback_list[1] == test_func_1"))
        eq(true, exec_lua("return callback_list[2] == test_func_2"))
      end)
    end)
  end)

  describe("add two callbacks to the same method. one of those is for specific filetypes", function()
    before_each(function()
      exec_lua("common_func = function(a, b) return a + b end")
      exec_lua("filetype_func = function(a, b, c) return a + b + c end")
      exec_lua("lsp_callbacks.add_callback('textDocument/hover', common_func)")
      exec_lua("lsp_callbacks.add_callback('textDocument/hover', filetype_func, 'python')")
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
        exec_lua("common_func = function(a, b) return a + b end")
        exec_lua("override_func = function(a, b) return a - b end")

        exec_lua("lsp_callbacks.set_callback('textDocument/hover', override_func)")
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

        eq(true, exec_lua("return callback_list[1] == override_func"))
        eq(true, exec_lua("return #callback_list == 1"))
    end)
  end)

  describe("set a callback that is for specific filetypes after adding a callbacks to the same method", function()
    it('should have only a callback which is defined after', function()
        exec_lua("common_func = function(a, b) return a + b end")
        exec_lua("override_func = function(a, b) return a - b end")

        exec_lua("lsp_callbacks.set_callback('textDocument/hover', common_func)")
        exec_lua("lsp_callbacks.set_callback('textDocument/hover', override_func, 'python')")
        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover')")

        eq(true, exec_lua("return callback_list[1] ~= override_func"))
        eq(true, exec_lua("return #callback_list == 1"))

        exec_lua("callback_list = lsp_callbacks._get_list_of_callbacks('textDocument/hover', 'python')")

        eq(true, exec_lua("return callback_list[1] == override_func"))
        eq(true, exec_lua("return #callback_list == 1"))
    end)
  end)
end)
