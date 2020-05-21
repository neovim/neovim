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

      it('file path includes only ascii charactors with encoded colon character', function()
        local test_case = [[
        local uri = 'file:///C%3A/Foo/Bar/Baz.txt'
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

    describe('decode non-file URI', function()
      it('uri_to_fname returns non-file URI unchanged', function()
        eq('jdt1.23+x-z://content/%5C/', exec_lua [[
          return vim.uri_to_fname('jdt1.23+x-z://content/%5C/')
        ]])
      end)

      it('uri_to_fname returns non-file upper-case scheme URI unchanged', function()
        eq('JDT://content/%5C/', exec_lua [[
          return vim.uri_to_fname('JDT://content/%5C/')
        ]])
      end)
    end)

    describe('decode URI without scheme', function()
      it('fails because URI must have a scheme', function()
        eq(false, exec_lua [[
          return pcall(vim.uri_to_fname, 'not_an_uri.txt')
        ]])
      end)
    end)

  end)

  describe('uri to bufnr', function()
    it('uri_to_bufnr & uri_from_bufnr returns original uri for non-file uris', function()
      local uri = 'jdt://contents/java.base/java.util/List.class?=sql/%5C/home%5C/user%5C/.jabba%5C/jdk%5C/openjdk%5C@1.14.0%5C/lib%5C/jrt-fs.jar%60java.base=/javadoc_location=/https:%5C/%5C/docs.oracle.com%5C/en%5C/java%5C/javase%5C/14%5C/docs%5C/api%5C/=/%3Cjava.util(List.class'
      local test_case = string.format([[
        local uri = '%s'
        return vim.uri_from_bufnr(vim.uri_to_bufnr(uri))
      ]], uri)
      eq(uri, exec_lua(test_case))
    end)
  end)
end)
