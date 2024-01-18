local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('glob', function()
  before_each(helpers.clear)
  after_each(helpers.clear)

  local match = function(...)
    return exec_lua(
      [[
      local pattern = select(1, ...)
      local str = select(2, ...)
      return require("vim.glob").to_lpeg(pattern):match(str) ~= nil
    ]],
      ...
    )
  end

  describe('glob matching', function()
    it('should match literal strings', function()
      eq(true, match('', ''))
      eq(false, match('', 'a'))
      eq(true, match('a', 'a'))
      eq(true, match('/', '/'))
      eq(true, match('abc', 'abc'))
      eq(false, match('abc', 'abcdef'))
      eq(false, match('abc', 'a'))
      eq(false, match('abc', 'bc'))
      eq(false, match('a', 'b'))
      eq(false, match('.', 'a'))
      eq(true, match('$', '$'))
      eq(true, match('/dir', '/dir'))
      eq(true, match('dir/', 'dir/'))
      eq(true, match('dir/subdir', 'dir/subdir'))
      eq(false, match('dir/subdir', 'subdir'))
      eq(false, match('dir/subdir', 'dir/subdir/file'))
      eq(true, match('🤠', '🤠'))
    end)

    it('should match * wildcards', function()
      eq(false, match('*', ''))
      eq(true, match('*', 'a'))
      eq(false, match('*', '/'))
      eq(false, match('*', '/a'))
      eq(false, match('*', 'a/'))
      eq(true, match('*', 'aaa'))
      eq(true, match('*a', 'aa'))
      eq(true, match('*a', 'abca'))
      eq(true, match('*.txt', 'file.txt'))
      eq(false, match('*.txt', 'file.txtxt'))
      eq(false, match('*.txt', 'dir/file.txt'))
      eq(false, match('*.txt', '/dir/file.txt'))
      eq(false, match('*.txt', 'C:/dir/file.txt'))
      eq(false, match('*.dir', 'test.dir/file'))
      eq(true, match('file.*', 'file.txt'))
      eq(false, match('file.*', 'not-file.txt'))
      eq(true, match('*/file.txt', 'dir/file.txt'))
      eq(false, match('*/file.txt', 'dir/subdir/file.txt'))
      eq(false, match('*/file.txt', '/dir/file.txt'))
      eq(true, match('dir/*', 'dir/file.txt'))
      eq(false, match('dir/*', 'dir'))
      eq(false, match('dir/*.txt', 'file.txt'))
      eq(true, match('dir/*.txt', 'dir/file.txt'))
      eq(false, match('dir/*.txt', 'dir/subdir/file.txt'))
      eq(false, match('dir/*/file.txt', 'dir/file.txt'))
      eq(true, match('dir/*/file.txt', 'dir/subdir/file.txt'))
      eq(false, match('dir/*/file.txt', 'dir/subdir/subdir/file.txt'))

      -- The spec does not describe this, but VSCode only interprets ** when it's by
      -- itself in a path segment, and otherwise interprets ** as consecutive * directives.
      -- see: https://github.com/microsoft/vscode/blob/eef30e7165e19b33daa1e15e92fa34ff4a5df0d3/src/vs/base/common/glob.ts#L112
      eq(true, match('a**', 'abc')) -- '**' should parse as two '*'s when not by itself in a path segment
      eq(true, match('**c', 'abc'))
      eq(false, match('a**', 'ab')) -- each '*' should still represent at least one character
      eq(false, match('**c', 'bc'))
      eq(true, match('a**', 'abcd'))
      eq(true, match('**d', 'abcd'))
      eq(false, match('a**', 'abc/d'))
      eq(false, match('**d', 'abc/d'))
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

    it('should match ** wildcards', function()
      eq(true, match('**', ''))
      eq(true, match('**', 'a'))
      eq(true, match('**', '/'))
      eq(true, match('**', 'a/'))
      eq(true, match('**', '/a'))
      eq(true, match('**', 'C:/a'))
      eq(true, match('**', 'a/a'))
      eq(true, match('**', 'a/a/a'))
      eq(false, match('/**', '')) -- /** matches leading / literally
      eq(true, match('/**', '/'))
      eq(true, match('/**', '/a/b/c'))
      eq(true, match('**/', '')) -- **/ absorbs trailing /
      eq(true, match('**/', '/a/b/c'))
      eq(true, match('**/**', ''))
      eq(true, match('**/**', 'a'))
      eq(false, match('a/**', ''))
      eq(false, match('a/**', 'a'))
      eq(true, match('a/**', 'a/b'))
      eq(true, match('a/**', 'a/b/c'))
      eq(false, match('a/**', 'b/a'))
      eq(false, match('a/**', '/a'))
      eq(false, match('**/a', ''))
      eq(true, match('**/a', 'a'))
      eq(false, match('**/a', 'a/b'))
      eq(true, match('**/a', '/a'))
      eq(true, match('**/a', '/b/a'))
      eq(true, match('**/a', '/c/b/a'))
      eq(true, match('**/a', '/a/a'))
      eq(true, match('**/a', '/abc/a'))
      eq(false, match('a/**/c', 'a'))
      eq(false, match('a/**/c', 'c'))
      eq(true, match('a/**/c', 'a/c'))
      eq(true, match('a/**/c', 'a/b/c'))
      eq(true, match('a/**/c', 'a/b/b/c'))
      eq(false, match('**/a/**', 'a'))
      eq(true, match('**/a/**', 'a/'))
      eq(false, match('**/a/**', '/dir/a'))
      eq(false, match('**/a/**', 'dir/a'))
      eq(true, match('**/a/**', 'dir/a/'))
      eq(true, match('**/a/**', 'a/dir'))
      eq(true, match('**/a/**', 'dir/a/dir'))
      eq(true, match('**/a/**', '/a/dir'))
      eq(true, match('**/a/**', 'C:/a/dir'))
      eq(false, match('**/a/**', 'a.txt'))
    end)

    it('should match {} groups', function()
      eq(true, match('{}', ''))
      eq(false, match('{}', 'a'))
      eq(true, match('a{}', 'a'))
      eq(true, match('{}a', 'a'))
      eq(true, match('{,}', ''))
      eq(true, match('{a,}', ''))
      eq(true, match('{a,}', 'a'))
      eq(true, match('{a}', 'a'))
      eq(false, match('{a}', 'aa'))
      eq(false, match('{a}', 'ab'))
      eq(true, match('{a?c}', 'abc'))
      eq(false, match('{ab}', 'a'))
      eq(false, match('{ab}', 'b'))
      eq(true, match('{ab}', 'ab'))
      eq(true, match('{a,b}', 'a'))
      eq(true, match('{a,b}', 'b'))
      eq(false, match('{a,b}', 'ab'))
      eq(true, match('{ab,cd}', 'ab'))
      eq(false, match('{ab,cd}', 'a'))
      eq(true, match('{ab,cd}', 'cd'))
      eq(true, match('{a,b,c}', 'c'))
      eq(true, match('{a,{b,c}}', 'c'))
    end)

    it('should match [] groups', function()
      eq(true, match('[]', '[]')) -- empty [] is a literal
      eq(false, match('[a-z]', ''))
      eq(true, match('[a-z]', 'a'))
      eq(false, match('[a-z]', 'ab'))
      eq(true, match('[a-z]', 'z'))
      eq(true, match('[a-z]', 'j'))
      eq(false, match('[a-f]', 'j'))
      eq(false, match('[a-z]', '`')) -- 'a' - 1
      eq(false, match('[a-z]', '{')) -- 'z' + 1
      eq(false, match('[a-z]', 'A'))
      eq(false, match('[a-z]', '5'))
      eq(true, match('[A-Z]', 'A'))
      eq(true, match('[A-Z]', 'Z'))
      eq(true, match('[A-Z]', 'J'))
      eq(false, match('[A-Z]', '@')) -- 'A' - 1
      eq(false, match('[A-Z]', '[')) -- 'Z' + 1
      eq(false, match('[A-Z]', 'a'))
      eq(false, match('[A-Z]', '5'))
      eq(true, match('[a-zA-Z0-9]', 'z'))
      eq(true, match('[a-zA-Z0-9]', 'Z'))
      eq(true, match('[a-zA-Z0-9]', '9'))
      eq(false, match('[a-zA-Z0-9]', '&'))
    end)

    it('should match [!...] groups', function()
      eq(true, match('[!]', '[!]')) -- [!] is a literal
      eq(false, match('[!a-z]', ''))
      eq(false, match('[!a-z]', 'a'))
      eq(false, match('[!a-z]', 'z'))
      eq(false, match('[!a-z]', 'j'))
      eq(true, match('[!a-f]', 'j'))
      eq(false, match('[!a-f]', 'jj'))
      eq(true, match('[!a-z]', '`')) -- 'a' - 1
      eq(true, match('[!a-z]', '{')) -- 'z' + 1
      eq(false, match('[!a-zA-Z0-9]', 'a'))
      eq(false, match('[!a-zA-Z0-9]', 'A'))
      eq(false, match('[!a-zA-Z0-9]', '0'))
      eq(true, match('[!a-zA-Z0-9]', '!'))
    end)

    it('should match complex patterns', function()
      eq(false, match('**/*.{c,h}', ''))
      eq(false, match('**/*.{c,h}', 'c'))
      eq(false, match('**/*.{c,h}', 'file.m'))
      eq(true, match('**/*.{c,h}', 'file.c'))
      eq(true, match('**/*.{c,h}', 'file.h'))
      eq(true, match('**/*.{c,h}', '/file.c'))
      eq(true, match('**/*.{c,h}', 'dir/subdir/file.c'))
      eq(true, match('**/*.{c,h}', 'dir/subdir/file.h'))
      eq(true, match('**/*.{c,h}', '/dir/subdir/file.c'))
      eq(true, match('**/*.{c,h}', 'C:/dir/subdir/file.c'))
      eq(true, match('/dir/**/*.{c,h}', '/dir/file.c'))
      eq(false, match('/dir/**/*.{c,h}', 'dir/file.c'))
      eq(true, match('/dir/**/*.{c,h}', '/dir/subdir/subdir/file.c'))

      eq(true, match('{[0-9],[a-z]}', '0'))
      eq(true, match('{[0-9],[a-z]}', 'a'))
      eq(false, match('{[0-9],[a-z]}', 'A'))
    end)
  end)
end)
