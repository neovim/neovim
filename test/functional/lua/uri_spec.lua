local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq
local is_os = t.is_os
local skip = t.skip
local write_file = t.write_file

describe('vim.uri', function()
  before_each(function()
    clear()
  end)

  describe('from_fname()', function()
    it('Unix filepath', function()
      exec_lua("filepath = '/Foo/Bar/Baz.txt'")

      eq('file:///Foo/Bar/Baz.txt', exec_lua('return vim.uri.from_fname(filepath)'))
      -- Resolves a relative path.
      eq(
        exec_lua(function()
          local cwd = assert(vim.uv.cwd())
          return {
            vim.uri.from_fname(cwd .. '/a.txt'),
            vim.uri.from_fname(vim.fs.dirname(cwd) .. '/b'),
          }
        end),
        exec_lua(function()
          return { vim.uri.from_fname('a.txt'), vim.uri.from_fname('../b') }
        end)
      )

      exec_lua("filepath = '/Foo /Bar/Baz.txt'")
      eq('file:///Foo%20/Bar/Baz.txt', exec_lua('return vim.uri.from_fname(filepath)'))

      exec_lua("filepath = '/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt'")
      -- The URI encoding should be case-insensitive
      eq(
        'file:///xy/%c3%a5%c3%a4%c3%b6/%c9%a7/%e6%b1%89%e8%af%ad/%e2%86%a5/%f0%9f%a4%a6/%f0%9f%a6%84/a%cc%8a/%d8%a8%d9%90%d9%8a%d9%8e%d9%91.txt',
        exec_lua('return vim.uri.from_fname(filepath)')
      )
    end)

    it('Windows filepath', function()
      exec_lua([[filepath = 'C:\\Foo\\Bar\\Baz.txt']])
      eq('file:///C:/Foo/Bar/Baz.txt', exec_lua('return vim.uri.from_fname(filepath)'))

      exec_lua([[filepath = 'C:\\Foo \\Bar\\Baz.txt']])
      eq('file:///C:/Foo%20/Bar/Baz.txt', exec_lua('return vim.uri.from_fname(filepath)'))

      exec_lua([[filepath = 'C:\\xy\\åäö\\ɧ\\汉语\\↥\\🤦\\🦄\\å\\بِيَّ.txt']])
      eq(
        'file:///C:/xy/%c3%a5%c3%a4%c3%b6/%c9%a7/%e6%b1%89%e8%af%ad/%e2%86%a5/%f0%9f%a4%a6/%f0%9f%a6%84/a%cc%8a/%d8%a8%d9%90%d9%8a%d9%8e%d9%91.txt',
        exec_lua('return vim.uri.from_fname(filepath)')
      )
    end)

    it('roundtrip to_fname(from_fname(path))', function()
      local paths =
        { '/a/c#/b?c', '/a/%25/%A0.txt', '/a b/#@file@#', 'C:/a b/c#', '//server/share/a b' }
      eq(
        paths,
        exec_lua(function()
          return vim.tbl_map(function(path)
            return vim.uri.to_fname(vim.uri.from_fname(path))
          end, paths)
        end)
      )
    end)
  end)

  describe('to_fname()', function()
    it('Unix filepath', function()
      exec_lua("uri = 'file:///Foo/Bar/Baz.txt'")

      eq('/Foo/Bar/Baz.txt', exec_lua('return vim.uri.to_fname(uri)'))

      -- Filepath without hostname:
      exec_lua("uri = 'file:/Foo/Bar/Baz.txt'")
      eq('/Foo/Bar/Baz.txt', exec_lua('return vim.uri.to_fname(uri)'))
      eq(
        { '/Foo/Bar', '/Foo/Bar', '/Foo/Bar', '/', '/Foo' },
        exec_lua(function()
          local uris = {
            'file:Foo/Bar',
            'file:////Foo/Bar',
            'file://localhost/Foo/Bar',
            'file://',
            'FILE:///Foo',
          }
          return vim.tbl_map(vim.uri.to_fname, uris)
        end)
      )

      -- Filepath with whitespace:
      exec_lua("uri = 'file:///Foo%20/Bar/Baz.txt'")
      eq('/Foo /Bar/Baz.txt', exec_lua('return vim.uri.to_fname(uri)'))

      local test_case = [[
      local uri = 'file:///xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt'
      return vim.uri.to_fname(uri)
      ]]
      eq('/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt', exec_lua(test_case))

      -- Filepath with uri query, fragment.
      exec_lua("uri = 'file:///Foo/Bar/Baz.txt?query#fragment'")
      eq('/Foo/Bar/Baz.txt', exec_lua('return vim.uri.to_fname(uri)'))
    end)

    describe('Windows filepath', function()
      it('filepath includes only ascii characters', function()
        local test_case = [[
        local uri = 'file:///C:/Foo/Bar/Baz.txt'
        return vim.uri.to_fname(uri)
        ]]

        eq('C:/Foo/Bar/Baz.txt', exec_lua(test_case))
      end)

      it('local filepath without hostname', function()
        local test_case = [[
        local uri = 'file:/C:/Foo/Bar/Baz.txt'
        return vim.uri.to_fname(uri)
        ]]

        eq('C:/Foo/Bar/Baz.txt', exec_lua(test_case))
        -- Drive letter, not a host.
        eq(
          { 'C:/Foo/Bar/Baz.txt', 'C:\\Foo\\Bar', 'C:\\Foo\\Bar' },
          exec_lua(function()
            local uris = { 'file://C:/Foo/Bar/Baz.txt', 'file://C:\\Foo\\Bar', 'C:\\Foo\\Bar' }
            return vim.tbl_map(vim.uri.to_fname, uris)
          end)
        )
      end)

      it('filepath includes only ascii characters with encoded colon character', function()
        local test_case = [[
        local uri = 'file:///C%3A/Foo/Bar/Baz.txt'
        return vim.uri.to_fname(uri)
        ]]

        eq('C:/Foo/Bar/Baz.txt', exec_lua(test_case))
      end)

      it('filepath including white space', function()
        local test_case = [[
        local uri = 'file:///C:/Foo%20/Bar/Baz.txt'
        return vim.uri.to_fname(uri)
        ]]

        eq('C:/Foo /Bar/Baz.txt', exec_lua(test_case))
      end)

      it('filepath including Unicode characters', function()
        local test_case = [[
        local uri = 'file:///C:/xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt'
        return vim.uri.to_fname(uri)
        ]]

        eq('C:/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt', exec_lua(test_case))
      end)

      it('filepath with host is a UNC path', function()
        eq('//server/share/a b', exec_lua([[return vim.uri.to_fname('file://server/share/a%20b')]]))
        if is_os('win') then
          eq(
            'file://server/share/a%20b',
            exec_lua([[return vim.uri.from_fname('\\\\server\\share\\a b')]])
          )
        end
      end)
    end)

    it('non-file URI returns unchanged', function()
      eq(
        'jdt1.23+x-z://content/%5C/',
        exec_lua [[
        return vim.uri.to_fname('jdt1.23+x-z://content/%5C/')
      ]]
      )

      -- Upper-case scheme returns unchanged.
      eq(
        'JDT://content/%5C/',
        exec_lua [[
        return vim.uri.to_fname('JDT://content/%5C/')
      ]]
      )

      -- Returns URI without authority unchanged.
      eq(
        'zipfile:///path/to/archive.zip%3A%3Afilename.txt',
        exec_lua [[
        return vim.uri.to_fname('zipfile:///path/to/archive.zip%3A%3Afilename.txt')
      ]]
      )
    end)

    describe('URI without scheme', function()
      it('fails (scheme is required)', function()
        eq(
          false,
          exec_lua [[
          return pcall(vim.uri.to_fname, 'not_an_uri.txt')
        ]]
        )
      end)

      it('does not treat comma as a scheme character', function()
        eq(
          false,
          exec_lua [[
          return pcall(vim.uri.to_fname, 'foo,://bar')
        ]]
        )
      end)

      it('returns non-file scheme URI with fragment unchanged', function()
        eq(
          'scheme://path#fragment',
          exec_lua [[
          return vim.uri.to_fname('scheme://path#fragment')
        ]]
        )
      end)
    end)
  end)

  describe('from_buf()', function()
    it('Windows paths should not be treated as uris', function()
      skip(not is_os('win'), 'N/A on non-Windows')

      local file = t.tmpname()
      write_file(file, 'Test content')
      local test_case = string.format(
        [[
          local file = '%s'
          return vim.uri.from_buf(vim.fn.bufadd(file))
        ]],
        file
      )
      local expected_uri = ('file:///%s'):format(file)
      eq(expected_uri, exec_lua(test_case))
      os.remove(file)
    end)
  end)

  describe('to_buf()', function()
    it('to_buf & from_buf returns original uri for non-file uris', function()
      local uri =
        'jdt://contents/java.base/java.util/List.class?=sql/%5C/home%5C/user%5C/.jabba%5C/jdk%5C/openjdk%5C@1.14.0%5C/lib%5C/jrt-fs.jar%60java.base=/javadoc_location=/https:%5C/%5C/docs.oracle.com%5C/en%5C/java%5C/javase%5C/14%5C/docs%5C/api%5C/=/%3Cjava.util(List.class'
      local test_case = string.format(
        [[
        local uri = '%s'
        return vim.uri.from_buf(vim.uri.to_buf(uri))
      ]],
        uri
      )
      eq(uri, exec_lua(test_case))
    end)

    it('to_buf & from_buf returns original uri for non-file uris without authority', function()
      local uri = 'zipfile:///path/to/archive.zip%3A%3Afilename.txt'
      local test_case = string.format(
        [[
        local uri = '%s'
        return vim.uri.from_buf(vim.uri.to_buf(uri))
      ]],
        uri
      )
      eq(uri, exec_lua(test_case))
      -- Deprecated aliases.
      eq(uri, exec_lua('return vim.uri_from_bufnr(vim.uri_to_bufnr(...))', uri))
    end)
  end)

  describe('encode()', function()
    it('rfc2732 including brackets', function()
      exec_lua("str = '[:]'")
      exec_lua("rfc = 'rfc2732'")
      eq('[%3a]', exec_lua('return vim.uri.encode(str, rfc)'))
    end)

    it('encode/decode roundtrip', function()
      eq(
        { '/a:b@c$d%23%3f%25%20', '%2fa%3ab%40c%24d' },
        exec_lua(function()
          return { vim.uri.encode('/a:b@c$d#?% '), vim.uri.encode('/a:b@c$d', 'rfc2396') }
        end)
      )
      -- Hex case, no double-decoding, malformed escapes.
      eq(
        'åå %41 %zz%',
        exec_lua(function()
          return vim.uri.decode('%c3%a5%C3%A5%20%2541%20%zz%')
        end)
      )
      -- Roundtrips all bytes.
      eq(
        {},
        exec_lua(function()
          local bytes = {} ---@type string[]
          for i = 0, 255 do
            bytes[#bytes + 1] = string.char(i)
          end
          local s = table.concat(bytes)
          local failed = {} ---@type string[]
          for _, rfc in ipairs({ 'rfc2396', 'rfc2732', 'rfc3986' }) do
            if vim.uri.decode(vim.uri.encode(s, rfc)) ~= s then
              failed[#failed + 1] = rfc
            end
          end
          return failed
        end)
      )
    end)
  end)

  it('parse()', function()
    local uris = {
      'https://u@example.com:80/a%20b?q=1#f?#',
      'file:///a',
      'deno:/https/a',
      'mailto:a@example.com',
      'inmemory:',
      'foo:api/files',
      'f3ile:#d',
      'file:////shares/p',
      'stuff:?',
      'C:/a',
      '/a',
    }
    local parsed = exec_lua(function()
      return vim.tbl_map(function(uri)
        local u = vim.uri.parse(uri)
        -- Roundtrip: tostring() gives the original URI.
        assert(not u or tostring(u) == uri, uri)
        return u or {}
      end, uris)
    end)
    eq({
      {
        scheme = 'https',
        authority = 'u@example.com:80',
        path = '/a%20b',
        query = 'q=1',
        fragment = 'f?#',
      },
      { scheme = 'file', authority = '', path = '/a' },
      { scheme = 'deno', path = '/https/a' },
      { scheme = 'mailto', path = 'a@example.com' },
      { scheme = 'inmemory', path = '' },
      { scheme = 'foo', path = 'api/files' },
      { scheme = 'f3ile', path = '', fragment = 'd' },
      { scheme = 'file', authority = '', path = '//shares/p' },
      { scheme = 'stuff', path = '', query = '' },
      {},
      {},
    }, parsed)
  end)
end)
