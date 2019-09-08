local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq

local shared = require('runtime.lua.vim.shared')

describe('utility functions', function()
  describe('trim()', function()
    it('should do nothing to whitespace inside of words', function()
      local test_string = 'there is loots      of whitespace'
      eq(test_string, shared.trim(test_string))
    end)

    it('should remove whitespace at the edges of strings', function()
      local test_string = '   this is still whitespace    inside     '
      eq('this is still whitespace    inside', shared.trim(test_string))
    end)
  end)

  describe('split()', function()
    it('should split on commas', function()
      eq({'foo', 'bar', 'baz'}, shared.split('foo,bar,baz', ','))
    end)
  end)

  describe('tbl_islist()', function()
    it('should return nil for empty table', function()
      eq(nil, shared.tbl_islist({}))
    end)

    it('should return true for an array', function()
      eq(true, shared.tbl_islist({'a', 'b', 'c'}))
    end)

    it('should return false for a table', function()
      eq(false, shared.tbl_islist({'a', '32', a='hello', b='baz'}))
      eq(false, shared.tbl_islist({1, a='hello', b='baz'}))
      eq(false, shared.tbl_islist({a='hello', b='baz', 1}))
      eq(false, shared.tbl_islist({1, 2, nil, a='hello'}))
    end)
  end)
end)

