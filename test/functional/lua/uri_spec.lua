local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local source = helpers.source
local dedent = helpers.dedent
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('URI', function()
  before_each(function()
    clear()
    source(dedent([[
      lua << EOF
        URI = require('uri')
      EOF
    ]]))

  end)

  describe('file path to uri', function()
    describe('encode Unix file path', function()
      it('file path includes only ascii charactors', function()
        exec_lua("filepath = '/Foo/Bar/Baz.txt'")

        eq('file:///Foo/Bar/Baz.txt', exec_lua("return URI.from_filepath(filepath):tostring()"))
      end)

      it('file path including white space', function()
        exec_lua("filepath = '/Foo /Bar/Baz.txt'")

        eq('file:///Foo%20/Bar/Baz.txt', exec_lua("return URI.from_filepath(filepath):tostring()"))
      end)

      it('file path including Unicode charactors', function()
        exec_lua("filepath = '/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt'")

        eq('file:///xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt', exec_lua("return URI.from_filepath(filepath):tostring()"))
      end)
    end)

    describe('encode Windows filepath', function()
      it('file path includes only ascii charactors', function()
        exec_lua([[filepath = 'C:\\Foo\\Bar\\Baz.txt']])

        eq('file:///C:/Foo/Bar/Baz.txt', exec_lua("return URI.from_filepath(filepath):tostring()"))
      end)

      it('file path including white space', function()
        exec_lua([[filepath = 'C:\\Foo \\Bar\\Baz.txt']])

        eq('file:///C:/Foo%20/Bar/Baz.txt', exec_lua("return URI.from_filepath(filepath):tostring()"))
      end)

      it('file path including Unicode charactors', function()
        exec_lua([[filepath = 'C:\\xy\\åäö\\ɧ\\汉语\\↥\\🤦\\🦄\\å\\بِيَّ.txt']])

        eq('file:///C:/xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt', exec_lua("return URI.from_filepath(filepath):tostring()"))
      end)
    end)
  end)

  describe('uri to filepath', function()
    describe('decode Unix file path', function()
      it('file path includes only ascii charactors', function()
        exec_lua("uri = 'file:///Foo/Bar/Baz.txt'")

        eq('/Foo/Bar/Baz.txt', exec_lua("return URI.filepath_from_uri(uri)"))
      end)

      it('file path including white space', function()
        exec_lua("uri = 'file:///Foo%20/Bar/Baz.txt'")

        eq('/Foo /Bar/Baz.txt', exec_lua("return URI.filepath_from_uri(uri)"))
      end)

      it('file path including Unicode charactors', function()
        exec_lua("uri = 'file:///xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt'")

        eq('/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt', exec_lua("return URI.filepath_from_uri(uri)"))
      end)
    end)

    describe('decode Windows filepath', function()
      it('file path includes only ascii charactors', function()
        exec_lua("uri = 'file:///C:/Foo/Bar/Baz.txt'")

        eq('C:\\Foo\\Bar\\Baz.txt', exec_lua("return URI.filepath_from_uri(uri)"))
      end)

      it('file path including white space', function()
        exec_lua("uri = 'file:///C:/Foo%20/Bar/Baz.txt'")

        eq('C:\\Foo \\Bar\\Baz.txt', exec_lua("return URI.filepath_from_uri(uri)"))
      end)

      it('file path including Unicode charactors', function()
        exec_lua("uri = 'file:///C:/xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt'")

        eq('C:\\xy\\åäö\\ɧ\\汉语\\↥\\🤦\\🦄\\å\\بِيَّ.txt', exec_lua("return URI.filepath_from_uri(uri)"))
      end)
    end)
  end)
end)
