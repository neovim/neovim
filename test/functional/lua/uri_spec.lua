local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('URI methods', function()
  before_each(function()
    clear()
  end)

  describe('file path to uri', function()
    describe('encode Unix file path', function()
      it('file path includes only ascii charactors', function()
        exec_lua("filepath = '/Foo/Bar/Baz.txt'")

        eq('file:///Foo/Bar/Baz.txt', exec_lua("return vim.uri_from_fname(filepath)"))
      end)

      it('file path including white space', function()
        exec_lua("filepath = '/Foo /Bar/Baz.txt'")

        eq('file:///Foo%20/Bar/Baz.txt', exec_lua("return vim.uri_from_fname(filepath)"))
      end)

      it('file path including Unicode charactors', function()
        exec_lua("filepath = '/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt'")

        -- The URI encoding should be case-insensitive
        eq('file:///xy/%c3%a5%c3%a4%c3%b6/%c9%a7/%e6%b1%89%e8%af%ad/%e2%86%a5/%f0%9f%a4%a6/%f0%9f%a6%84/a%cc%8a/%d8%a8%d9%90%d9%8a%d9%8e%d9%91.txt', exec_lua("return vim.uri_from_fname(filepath)"))
      end)
    end)

    describe('encode Windows filepath', function()
      it('file path includes only ascii charactors', function()
        exec_lua([[filepath = 'C:\\Foo\\Bar\\Baz.txt']])

        eq('file:///C:/Foo/Bar/Baz.txt', exec_lua("return vim.uri_from_fname(filepath)"))
      end)

      it('file path including white space', function()
        exec_lua([[filepath = 'C:\\Foo \\Bar\\Baz.txt']])

        eq('file:///C:/Foo%20/Bar/Baz.txt', exec_lua("return vim.uri_from_fname(filepath)"))
      end)

      it('file path including Unicode charactors', function()
        exec_lua([[filepath = 'C:\\xy\\åäö\\ɧ\\汉语\\↥\\🤦\\🦄\\å\\بِيَّ.txt']])

        eq('file:///C:/xy/%c3%a5%c3%a4%c3%b6/%c9%a7/%e6%b1%89%e8%af%ad/%e2%86%a5/%f0%9f%a4%a6/%f0%9f%a6%84/a%cc%8a/%d8%a8%d9%90%d9%8a%d9%8e%d9%91.txt', exec_lua("return vim.uri_from_fname(filepath)"))
      end)
    end)
  end)

  describe('uri to filepath', function()
    describe('decode Unix file path', function()
      it('file path includes only ascii charactors', function()
        exec_lua("uri = 'file:///Foo/Bar/Baz.txt'")

        eq('/Foo/Bar/Baz.txt', exec_lua("return vim.uri_to_fname(uri)"))
      end)

      it('file path including white space', function()
        exec_lua("uri = 'file:///Foo%20/Bar/Baz.txt'")

        eq('/Foo /Bar/Baz.txt', exec_lua("return vim.uri_to_fname(uri)"))
      end)

      it('file path including Unicode charactors', function()
        local test_case = [[
        local uri = 'file:///xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt'
        return vim.uri_to_fname(uri)
        ]]

        eq('/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt', exec_lua(test_case))
      end)
    end)

    describe('decode Windows filepath', function()
      it('file path includes only ascii charactors', function()
        local test_case = [[
        local uri = 'file:///C:/Foo/Bar/Baz.txt'
        return vim.uri_to_fname(uri)
        ]]

        eq('C:\\Foo\\Bar\\Baz.txt', exec_lua(test_case))
      end)

      it('file path including white space', function()
        local test_case = [[
        local uri = 'file:///C:/Foo%20/Bar/Baz.txt'
        return vim.uri_to_fname(uri)
        ]]

        eq('C:\\Foo \\Bar\\Baz.txt', exec_lua(test_case))
      end)

      it('file path including Unicode charactors', function()
        local test_case = [[
        local uri = 'file:///C:/xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt'
        return vim.uri_to_fname(uri)
        ]]

        eq('C:\\xy\\åäö\\ɧ\\汉语\\↥\\🤦\\🦄\\å\\بِيَّ.txt', exec_lua(test_case))
      end)
    end)
  end)
end)
