local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local dedent = helpers.dedent
local insert = helpers.insert
local clear = helpers.clear
local command = helpers.command
local NIL = helpers.NIL

describe('LSP util', function()
  local test_text = dedent([[
  First line of text
  Second line of text
  Third line of text
  Fourth line of text
  ]])

  before_each(function()
    clear()
    insert(test_text)
  end)

  describe('get_buffer_text', function()
    it('should equal to test_text', function()
      eq(test_text, exec_lua("return vim.lsp.util.get_buffer_text(vim.api.nvim_get_current_buf())"))
    end)
  end)

  describe('get_filetype', function()
    it('should equal to blank', function()
      eq('', exec_lua("return vim.lsp.util.get_filetype(vim.api.nvim_get_current_buf())"))
      eq('', exec_lua("return vim.lsp.util.get_filetype()"))
    end)

    it('should equal to txt', function()
      command('set filetype=txt')
      eq('txt', exec_lua("return vim.lsp.util.get_filetype(vim.api.nvim_get_current_buf())"))
      eq('txt', exec_lua("return vim.lsp.util.get_filetype()"))
    end)
  end)

  describe('get_HoverContents_type', function()
    it('should equal to MarkedString[]', function()
      eq(
        'MarkedString[]',
        exec_lua("return vim.lsp.util.get_HoverContents_type({ { language='txt', value='test' } } )")
      )
      eq(
        'MarkedString[]',
        exec_lua("return vim.lsp.util.get_HoverContents_type({ { language='txt', value='test1' }, { language='txt', value='test2' } })")
      )
    end)

    it('should equal MarkedString', function()
      eq('MarkedString', exec_lua("return vim.lsp.util.get_HoverContents_type({ language='txt', value='test1' })"))
      eq('MarkedString', exec_lua("return vim.lsp.util.get_HoverContents_type('test')"))
      eq('MarkedString', exec_lua("return vim.lsp.util.get_HoverContents_type('')"))
    end)

    it('should equal to MarkupContent', function()
      eq('MarkupContent', exec_lua("return vim.lsp.util.get_HoverContents_type({ kind='plaintext', value='test' })"))
    end)

    it('should equal nil', function()
      eq(NIL, exec_lua("return vim.lsp.util.get_HoverContents_type(nil)"))
    end)
  end)
  describe('is_CompletionList', function()
    it('should be true', function()
      eq(true, exec_lua("return vim.lsp.util.is_CompletionList({ items = { 1 } })"))
      eq(true, exec_lua("return vim.lsp.util.is_CompletionList({ items = { 1, 2 } })"))
      eq(true, exec_lua("return vim.lsp.util.is_CompletionList({ items = {} })"))
    end)

    it('should be false', function()
      eq(false, exec_lua("return vim.lsp.util.is_CompletionList('items')"))
    end)
  end)
end)
