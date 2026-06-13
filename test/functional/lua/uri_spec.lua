local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq
local is_os = t.is_os
local skip = t.skip
local write_file = t.write_file

describe('URI methods', function()
  before_each(function()
    clear()
  end)

  describe('file path to uri', function()
    describe('encode Unix file path', function()
      it('file path includes only ascii characters', function()
        exec_lua("filepath = '/Foo/Bar/Baz.txt'")

        eq('file:///Foo/Bar/Baz.txt', exec_lua('return vim.uri_from_fname(filepath)'))
      end)

      it('file path including white space', function()
        exec_lua("filepath = '/Foo /Bar/Baz.txt'")

        eq('file:///Foo%20/Bar/Baz.txt', exec_lua('return vim.uri_from_fname(filepath)'))
      end)

      it('file path including Unicode characters', function()
        exec_lua("filepath = '/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt'")

        -- The URI encoding should be case-insensitive
        eq(
          'file:///xy/%c3%a5%c3%a4%c3%b6/%c9%a7/%e6%b1%89%e8%af%ad/%e2%86%a5/%f0%9f%a4%a6/%f0%9f%a6%84/a%cc%8a/%d8%a8%d9%90%d9%8a%d9%8e%d9%91.txt',
          exec_lua('return vim.uri_from_fname(filepath)')
        )
      end)
    end)

    describe('encode Windows filepath', function()
      it('file path includes only ascii characters', function()
        exec_lua([[filepath = 'C:\\Foo\\Bar\\Baz.txt']])

        eq('file:///C:/Foo/Bar/Baz.txt', exec_lua('return vim.uri_from_fname(filepath)'))
      end)

      it('file path including white space', function()
        exec_lua([[filepath = 'C:\\Foo \\Bar\\Baz.txt']])

        eq('file:///C:/Foo%20/Bar/Baz.txt', exec_lua('return vim.uri_from_fname(filepath)'))
      end)

      it('file path including Unicode characters', function()
        exec_lua([[filepath = 'C:\\xy\\åäö\\ɧ\\汉语\\↥\\🤦\\🦄\\å\\بِيَّ.txt']])

        eq(
          'file:///C:/xy/%c3%a5%c3%a4%c3%b6/%c9%a7/%e6%b1%89%e8%af%ad/%e2%86%a5/%f0%9f%a4%a6/%f0%9f%a6%84/a%cc%8a/%d8%a8%d9%90%d9%8a%d9%8e%d9%91.txt',
          exec_lua('return vim.uri_from_fname(filepath)')
        )
      end)
    end)
  end)

  describe('uri to filepath', function()
    describe('decode Unix file path', function()
      it('file path includes only ascii characters', function()
        exec_lua("uri = 'file:///Foo/Bar/Baz.txt'")

        eq('/Foo/Bar/Baz.txt', exec_lua('return vim.uri_to_fname(uri)'))
      end)

      it('local file path without hostname', function()
        exec_lua("uri = 'file:/Foo/Bar/Baz.txt'")

        eq('/Foo/Bar/Baz.txt', exec_lua('return vim.uri_to_fname(uri)'))
      end)

      it('file path including white space', function()
        exec_lua("uri = 'file:///Foo%20/Bar/Baz.txt'")

        eq('/Foo /Bar/Baz.txt', exec_lua('return vim.uri_to_fname(uri)'))
      end)

      it('file path including Unicode characters', function()
        local test_case = [[
        local uri = 'file:///xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt'
        return vim.uri_to_fname(uri)
        ]]

        eq('/xy/åäö/ɧ/汉语/↥/🤦/🦄/å/بِيَّ.txt', exec_lua(test_case))
      end)

      it('file path with uri fragment', function()
        exec_lua("uri = 'file:///Foo/Bar/Baz.txt#fragment'")

        eq('/Foo/Bar/Baz.txt', exec_lua('return vim.uri_to_fname(uri)'))
      end)
    end)

    describe('decode Windows filepath', function()
      it('file path includes only ascii characters', function()
        local test_case = [[
        local uri = 'file:///C:/Foo/Bar/Baz.txt'
        return vim.uri_to_fname(uri)
        ]]

        eq('C:\\Foo\\Bar\\Baz.txt', exec_lua(test_case))
      end)

      it('local file path without hostname', function()
        local test_case = [[
        local uri = 'file:/C:/Foo/Bar/Baz.txt'
        return vim.uri_to_fname(uri)
        ]]

        eq('C:\\Foo\\Bar\\Baz.txt', exec_lua(test_case))
      end)

      it('file path includes only ascii characters with encoded colon character', function()
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

      it('file path including Unicode characters', function()
        local test_case = [[
        local uri = 'file:///C:/xy/%C3%A5%C3%A4%C3%B6/%C9%A7/%E6%B1%89%E8%AF%AD/%E2%86%A5/%F0%9F%A4%A6/%F0%9F%A6%84/a%CC%8A/%D8%A8%D9%90%D9%8A%D9%8E%D9%91.txt'
        return vim.uri_to_fname(uri)
        ]]

        eq('C:\\xy\\åäö\\ɧ\\汉语\\↥\\🤦\\🦄\\å\\بِيَّ.txt', exec_lua(test_case))
      end)
    end)

    describe('decode non-file URI', function()
      it('uri_to_fname returns non-file URI unchanged', function()
        eq(
          'jdt1.23+x-z://content/%5C/',
          exec_lua [[
          return vim.uri_to_fname('jdt1.23+x-z://content/%5C/')
        ]]
        )
      end)

      it('uri_to_fname returns non-file upper-case scheme URI unchanged', function()
        eq(
          'JDT://content/%5C/',
          exec_lua [[
          return vim.uri_to_fname('JDT://content/%5C/')
        ]]
        )
      end)

      it('uri_to_fname returns non-file scheme URI without authority unchanged', function()
        eq(
          'zipfile:///path/to/archive.zip%3A%3Afilename.txt',
          exec_lua [[
          return vim.uri_to_fname('zipfile:///path/to/archive.zip%3A%3Afilename.txt')
        ]]
        )
      end)
    end)

    describe('decode URI without scheme', function()
      it('fails because URI must have a scheme', function()
        eq(
          false,
          exec_lua [[
          return pcall(vim.uri_to_fname, 'not_an_uri.txt')
        ]]
        )
      end)

      it('uri_to_fname should not treat comma as a scheme character', function()
        eq(
          false,
          exec_lua [[
          return pcall(vim.uri_to_fname, 'foo,://bar')
        ]]
        )
      end)

      it('uri_to_fname returns non-file schema URI with fragment unchanged', function()
        eq(
          'scheme://path#fragment',
          exec_lua [[
          return vim.uri_to_fname('scheme://path#fragment')
        ]]
        )
      end)
    end)
  end)

  describe('uri from bufnr', function()
    it('Windows paths should not be treated as uris', function()
      skip(not is_os('win'), 'N/A on non-Windows')

      local file = t.tmpname()
      write_file(file, 'Test content')
      local test_case = string.format(
        [[
          local file = '%s'
          return vim.uri_from_bufnr(vim.fn.bufadd(file))
        ]],
        file
      )
      local expected_uri = 'file:///' .. t.fix_slashes(file)
      eq(expected_uri, exec_lua(test_case))
      os.remove(file)
    end)
  end)

  describe('uri to bufnr', function()
    it('uri_to_bufnr & uri_from_bufnr returns original uri for non-file uris', function()
      local uri =
        'jdt://contents/java.base/java.util/List.class?=sql/%5C/home%5C/user%5C/.jabba%5C/jdk%5C/openjdk%5C@1.14.0%5C/lib%5C/jrt-fs.jar%60java.base=/javadoc_location=/https:%5C/%5C/docs.oracle.com%5C/en%5C/java%5C/javase%5C/14%5C/docs%5C/api%5C/=/%3Cjava.util(List.class'
      local test_case = string.format(
        [[
        local uri = '%s'
        return vim.uri_from_bufnr(vim.uri_to_bufnr(uri))
      ]],
        uri
      )
      eq(uri, exec_lua(test_case))
    end)

    it(
      'uri_to_bufnr & uri_from_bufnr returns original uri for non-file uris without authority',
      function()
        local uri = 'zipfile:///path/to/archive.zip%3A%3Afilename.txt'
        local test_case = string.format(
          [[
        local uri = '%s'
        return vim.uri_from_bufnr(vim.uri_to_bufnr(uri))
      ]],
          uri
        )
        eq(uri, exec_lua(test_case))
      end
    )
  end)

  describe('encode to uri', function()
    it('rfc2732 including brackets', function()
      exec_lua("str = '[:]'")
      exec_lua("rfc = 'rfc2732'")
      eq('[%3a]', exec_lua('return vim.uri_encode(str, rfc)'))
    end)
  end)

  describe('uri_parse_nvim', function()
    it('parses basic nvim:// URI with edit command', function()
      local result = exec_lua([[return vim.uri_parse_nvim('nvim://edit?file=/path/to/file.txt')]])
      eq('edit', result.cmd)
      eq('/path/to/file.txt', result.file)
      eq(nil, result.line)
      eq(nil, result.column)
    end)

    it('parses nvim:// URI with tabedit command', function()
      local result =
        exec_lua([[return vim.uri_parse_nvim('nvim://tabedit?file=/path/to/file.txt&line=42')]])
      eq('tabedit', result.cmd)
      eq('/path/to/file.txt', result.file)
      eq(42, result.line)
    end)

    it('parses nvim:// URI with split command', function()
      local result = exec_lua([[return vim.uri_parse_nvim('nvim://split?file=/path/to/file.txt')]])
      eq('split', result.cmd)
      eq('/path/to/file.txt', result.file)
    end)

    it('parses nvim:// URI with vsplit command', function()
      local result = exec_lua([[return vim.uri_parse_nvim('nvim://vsplit?file=/path/to/file.txt')]])
      eq('vsplit', result.cmd)
      eq('/path/to/file.txt', result.file)
    end)

    it('parses nvim:// URI with line and column', function()
      local result = exec_lua(
        [[return vim.uri_parse_nvim('nvim://edit?file=/path/to/file.txt&line=42&column=10')]]
      )
      eq('/path/to/file.txt', result.file)
      eq(42, result.line)
      eq(10, result.column)
    end)

    it('parses nvim:// URI with server parameter', function()
      local result = exec_lua(
        [[return vim.uri_parse_nvim('nvim://tabedit?file=/path/to/file.txt&server=/tmp/nvim.sock')]]
      )
      eq('/path/to/file.txt', result.file)
      eq('/tmp/nvim.sock', result.server)
    end)

    it('parses nvim:// URI with relative path', function()
      local result =
        exec_lua([[return vim.uri_parse_nvim('nvim://edit?file=./relative/path.txt&line=10')]])
      eq('./relative/path.txt', result.file)
      eq(10, result.line)
    end)

    it('decodes percent-encoded file paths', function()
      local result =
        exec_lua([[return vim.uri_parse_nvim('nvim://edit?file=/path/to/my%20file.txt')]])
      eq('/path/to/my file.txt', result.file)
    end)

    it('returns error for non-nvim scheme', function()
      local err = exec_lua([[
        local _, e = vim.uri_parse_nvim('http://example.com')
        return e
      ]])
      eq('URI scheme must be "nvim"', err)
    end)

    it('returns error for missing file parameter', function()
      local err = exec_lua([[
        local _, e = vim.uri_parse_nvim('nvim://edit?line=42')
        return e
      ]])
      eq('Missing required "file" parameter', err)
    end)

    it('returns error for unsupported command', function()
      local err = exec_lua([[
        local _, e = vim.uri_parse_nvim('nvim://foo?file=/path/to/file.txt')
        return e
      ]])
      eq(
        'Unsupported command: foo. Expected one of: drop, edit, open, split, tabedit, tabnew, vsplit',
        err
      )
    end)

    it('resolves open command to default opencmd', function()
      local result = exec_lua([[return vim.uri_parse_nvim('nvim://open?file=/path/to/file.txt')]])
      eq('edit', result.cmd)
      eq('/path/to/file.txt', result.file)
    end)

    it('resolves open command to custom opencmd', function()
      local result = exec_lua([[
        vim.g.uri_opencmd = 'tabedit'
        local parsed = vim.uri_parse_nvim('nvim://open?file=/path/to/file.txt')
        vim.g.uri_opencmd = nil  -- reset
        return parsed
      ]])
      eq('tabedit', result.cmd)
      eq('/path/to/file.txt', result.file)
    end)

    it('returns error for invalid opencmd value', function()
      local err = exec_lua([[
        vim.g.uri_opencmd = 'invalid'
        local _, e = vim.uri_parse_nvim('nvim://open?file=/path/to/file.txt')
        vim.g.uri_opencmd = nil  -- reset
        return e
      ]])
      eq('Invalid vim.g.uri_opencmd value: invalid', err)
    end)

    it('returns error for missing query', function()
      local err = exec_lua([[
        local _, e = vim.uri_parse_nvim('nvim://edit')
        return e
      ]])
      eq('Unsupported nvim:// URI format. Expected: nvim://{cmd}?file=...', err)
    end)
  end)
end)
