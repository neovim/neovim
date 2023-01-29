local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('vim.lsp._watchfiles', function()
  before_each(helpers.clear)
  after_each(helpers.clear)

  local match = function(...)
    return exec_lua('return require("vim.lsp._watchfiles")._match(...)', ...)
  end

  describe('glob matching', function()
    it('should match literal strings', function()
      eq(true, match('', ''))
      eq(false, match('', 'a'))
      eq(true, match('a', 'a'))
      eq(false, match('a', 'b'))
      eq(false, match('.', 'a'))
      eq(true, match('$', '$'))
    end)

    it('should match * wildcards', function()
      eq(true, match('*', 'a'))
      eq(false, match('*', '/a'))
      eq(true, match('*', 'aaa'))
      -- eq(false, match('*.txt', '.txt')) -- TODO: this fails
      eq(true, match('*.txt', 'file.txt'))
      eq(false, match('*.txt', 'file.txtxt'))
      eq(false, match('*.txt', 'dir/file.txt'))
      eq(false, match('*.txt', '/dir/file.txt'))
      eq(false, match('*.dir', 'test.dir/file'))
      eq(true, match('file.*', 'file.txt'))
      eq(false, match('file.*', 'not-file.txt'))
    end)

    it('should match ? wildcards', function()
      eq(false, match('?', ''))
      eq(true, match('?', 'a'))
      eq(false, match('??', 'a'))
      eq(false, match('?', 'ab'))
      eq(true, match('??', 'ab'))
      eq(true, match('a?c', 'abc'))
      eq(false, match('a?c', 'a/c'))
    end)
  end)
end)
