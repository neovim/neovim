local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq

local util = require('runtime.lua.util')

describe('utility functions', function()
  describe('handle_uri()', function()
    it('should return the same item if we are not sure how to handle it', function()
      local test_string = 'this_is_not_a_prefix://file.txt'
      eq(test_string, util.handle_uri(test_string))
    end)

    it('should return a stripped file:// prefix', function()
      local test_string = 'file:///tmp/file.txt'
      eq('/tmp/file.txt', util.handle_uri(test_string))
    end)
  end)

  describe('trim()', function()
    it('should do nothing to whitespace inside of words', function()
      local test_string = 'there is loots      of whitespace'
      eq(test_string, util.trim(test_string))
    end)

    it('should remove whitespace at the edges of strings', function()
      local test_string = '   this is still whitespace    inside     '
      eq('this is still whitespace    inside', util.trim(test_string))
    end)
  end)

  describe('split()', function()
    it('should split on commas', function()
      eq({'foo', 'bar', 'baz'}, util.split('foo,bar,baz', ','))
    end)
  end)

  describe('is_array()', function()
    it('should return nil for empty table', function()
      eq(nil, util.is_array({}))
    end)

    it('should return true for an array', function()
      eq(true, util.is_array({'a', 'b', 'c'}))
    end)

    it('should return false for a table', function()
      eq(false, util.is_array({a='hello', b='baz'}))
    end)
  end)
end)

