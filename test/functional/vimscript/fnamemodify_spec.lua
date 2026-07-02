local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local fnamemodify = n.fn.fnamemodify
local getcwd = n.fn.getcwd
local command = n.command
local write_file = t.write_file
local is_os = t.is_os
local chdir = n.fn.chdir

local function eq_slashconvert(expected, got)
  eq(t.fix_slashes(expected), t.fix_slashes(got))
end

describe('fnamemodify()', function()
  setup(function()
    write_file('Xtest-fnamemodify.txt', [[foobar]])
    t.mkdir('foo')
    write_file('foo/bar', [[bar]])
  end)

  before_each(clear)

  teardown(function()
    os.remove('Xtest-fnamemodify.txt')
    n.rmdir('foo')
  end)

  it('handles the root path', function()
    local root = assert(t.fix_slashes(n.pathroot()))
    eq(root, fnamemodify([[/]], ':p:h'))
    eq(root, fnamemodify([[/]], ':p'))
    if is_os('win') then
      eq(root, fnamemodify([[\]], ':p:h'))
      eq(root, fnamemodify([[\]], ':p'))
      command('set shellslash')
      eq(root, fnamemodify([[\]], ':p:h'))
      eq(root, fnamemodify([[\]], ':p'))
      eq(root, fnamemodify([[/]], ':p:h'))
      eq(root, fnamemodify([[/]], ':p'))

      local letter_colon = root:sub(1, 2)
      local old_dir = t.fix_slashes(getcwd()) .. '/'
      local foo_dir = old_dir .. 'foo/'
      eq(old_dir, fnamemodify(letter_colon, ':p'))
      eq(old_dir, fnamemodify(letter_colon .. '.', ':p'))
      eq(old_dir, fnamemodify(letter_colon .. './', ':p'))
      eq(foo_dir, fnamemodify(letter_colon .. './foo', ':p'))
      eq(foo_dir, fnamemodify(letter_colon .. 'foo', ':p'))
      chdir('foo')
      eq(old_dir, fnamemodify(letter_colon .. '..', ':p'))
      eq(old_dir, fnamemodify(letter_colon .. '../', ':p'))
      eq(foo_dir .. 'bar', fnamemodify(letter_colon .. 'bar', ':p'))
    end
    eq('/localhost/foo/bar', fnamemodify('///localhost/foo/bar', ':p'))
    eq('//localhost/foo/bar', fnamemodify('//localhost/foo/bar', ':p'))
  end)

  it(':8 works', function()
    eq('Xtest-fnamemodify.txt', fnamemodify([[Xtest-fnamemodify.txt]], ':8'))
  end)

  it('handles examples from ":help filename-modifiers"', function()
    -- src/ cannot be a symlink in this test.
    n.api.nvim_set_current_dir(t.paths.test_source_path)

    local filename = 'src/version.c'
    local cwd = getcwd()

    eq_slashconvert(cwd .. '/src/version.c', fnamemodify(filename, ':p'))

    eq_slashconvert('src/version.c', fnamemodify(filename, ':p:.'))
    eq_slashconvert(cwd .. '/src', fnamemodify(filename, ':p:h'))
    eq_slashconvert(cwd .. '', fnamemodify(filename, ':p:h:h'))
    eq('version.c', fnamemodify(filename, ':p:t'))
    eq_slashconvert(cwd .. '/src/version', fnamemodify(filename, ':p:r'))

    eq_slashconvert(cwd .. '/src/main.c', fnamemodify(filename, ':s?version?main?:p'))

    local converted_cwd = cwd:gsub('/', '\\')
    eq(converted_cwd .. '\\src\\version.c', fnamemodify(filename, ':p:gs?/?\\\\?'))

    eq('src', fnamemodify(filename, ':h'))
    eq('version.c', fnamemodify(filename, ':t'))
    eq_slashconvert('src/version', fnamemodify(filename, ':r'))
    eq('version', fnamemodify(filename, ':t:r'))
    eq('c', fnamemodify(filename, ':e'))

    eq_slashconvert('src/main.c', fnamemodify(filename, ':s?version?main?'))
  end)

  it('handles advanced examples from ":help filename-modifiers"', function()
    local filename = 'src/version.c.gz'

    eq('gz', fnamemodify(filename, ':e'))
    eq('c.gz', fnamemodify(filename, ':e:e'))
    eq('c.gz', fnamemodify(filename, ':e:e:e'))

    eq('c', fnamemodify(filename, ':e:e:r'))

    eq_slashconvert('src/version.c', fnamemodify(filename, ':r'))
    eq('c', fnamemodify(filename, ':r:e'))

    eq_slashconvert('src/version', fnamemodify(filename, ':r:r'))
    eq_slashconvert('src/version', fnamemodify(filename, ':r:r:r'))
  end)

  it('handles :h', function()
    -- generic path
    eq('.', fnamemodify('hello.txt', ':h'))
    eq('path/to', fnamemodify('path/to/hello.txt', ':h'))
    eq('/', fnamemodify('/', ':h'))
    eq('/', fnamemodify('/foo', ':h'))

    -- collapses more than two leading slashes into a single slash
    eq('/', fnamemodify('///', ':h'))
    eq('/', fnamemodify('////', ':h'))
    eq('/', fnamemodify('///foo', ':h'))
    eq('/foo', fnamemodify('///foo/bar', ':h'))
    eq('/foo', fnamemodify('///foo////bar', ':h'))
    eq('/foo', fnamemodify('////foo/bar', ':h'))

    -- preserves exactly two leading slashes
    eq('//', fnamemodify('//', ':h'))

    if not is_os('win') then
      -- POSIX permits special handling for exactly two leading slashes.
      eq('//', fnamemodify('//', ':h'))
      eq('//', fnamemodify('//foo', ':h'))
      eq('//foo', fnamemodify('//foo/bar', ':h'))
      eq('//foo', fnamemodify('//foo///bar', ':h'))
    else
      eq('//server', fnamemodify('//server', ':h'))
      eq('//server/share', fnamemodify('//server/share', ':h'))
      eq('//server/share/', fnamemodify('//server/share/', ':h'))
      eq('//server///share', fnamemodify('//server///share', ':h'))
      eq('//server/share/', fnamemodify('//server/share/foo', ':h'))

      eq([[\\foo\C$]], fnamemodify([[\\foo\C$]], ':h'))
      eq([[\\foo\C$\]], fnamemodify([[\\foo\C$\]], ':h'))
      eq([[\\foo\C$\]], fnamemodify([[\\foo\C$\bar]], ':h'))
      eq([[\\foo\C$\]], fnamemodify([[\\foo\C$\bar]], ':h:h'))
      eq([[//foo\C$/]], fnamemodify([[//foo\C$/bar]], ':h'))
      -- `C$` is a share name, not a file name
      eq('', fnamemodify('//foo/C$/bar', ':h:t'))

      eq('C:', fnamemodify('C:foo', ':h'))
      eq('C:/', fnamemodify('C:/foo', ':h'))

      eq('//?/C:/', fnamemodify('//?/C:/', ':h'))
      eq('//?/C:/', fnamemodify('//?/C:/foo', ':h'))
      eq(
        '//?/Volume{b75e2c83-0000-0000-0000-602f00000000}/',
        fnamemodify('//?/Volume{b75e2c83-0000-0000-0000-602f00000000}/foo', ':h')
      )
      eq(
        '//?/Volume{b75e2c83-0000-0000-0000-602f00000000}/',
        fnamemodify('///?/Volume{b75e2c83-0000-0000-0000-602f00000000}/foo', ':h')
      )
      eq('//?/UNC/server', fnamemodify('//?/UNC/server', ':h'))
      eq('//?/UNC/server/share', fnamemodify('//?/UNC/server/share', ':h'))
      eq('//?/UNC/server/share/', fnamemodify('//?/UNC/server/share/foo', ':h'))
    end
  end)

  it('handles :t', function()
    eq('bar.txt', fnamemodify('bar.txt', ':t'))
    eq('bar.txt', fnamemodify('path/to/bar.txt', ':t'))
    eq('bar', fnamemodify('foo///bar', ':t'))
    eq('bar', fnamemodify('/bar', ':t'))
    eq('bar', fnamemodify('///bar', ':t'))
    if not is_os('win') then
      eq('bar', fnamemodify('//bar', ':t'))
    else
      eq('', fnamemodify('//localhost', ':t'))
      eq('', fnamemodify('//localhost/C$', ':t'))
      eq('bar', fnamemodify('//localhost/C$/bar', ':t'))
      eq('', fnamemodify('//?/UNC/localhost', ':t'))
      eq('', fnamemodify('//?/UNC/localhost/C$', ':t'))
      eq('bar', fnamemodify('//?/UNC/localhost/C$/bar', ':t'))

      eq('', fnamemodify('//?/', ':t'))
      eq('', fnamemodify('//?/C:', ':t'))
      eq('bar', fnamemodify('//?/C:/bar', ':t'))
      eq('', fnamemodify('//?/Volume{b75e2c83-0000-0000-0000-602f00000000}', ':t'))
      eq('bar', fnamemodify('//?/Volume{b75e2c83-0000-0000-0000-602f00000000}/bar', ':t'))
    end
  end)

  it('handles :r', function()
    eq('bar', fnamemodify('bar.txt', ':r'))
    eq('path/to/bar', fnamemodify('path/to/bar.txt', ':r'))
    eq('foo///bar', fnamemodify('foo///bar.txt', ':r'))
    eq('/bar', fnamemodify('/bar.txt', ':r'))
    eq('/bar', fnamemodify('///bar.txt', ':r'))
    if not is_os('win') then
      eq('//bar', fnamemodify('//bar.txt', ':r'))
    else
      eq('//127.0.0.1', fnamemodify('//127.0.0.1', ':r'))
      eq('//127.0.0.1/C$', fnamemodify('//127.0.0.1/C$', ':r'))
      eq('//127.0.0.1/C$/bar', fnamemodify('//127.0.0.1/C$/bar.txt', ':r'))
      eq('//?/UNC/127.0.0.1', fnamemodify('//?/UNC/127.0.0.1', ':r'))
      eq('//?/UNC/127.0.0.1/C$', fnamemodify('//?/UNC/127.0.0.1/C$', ':r'))
      eq('//?/UNC/127.0.0.1/C$/bar', fnamemodify('//?/UNC/127.0.0.1/C$/bar.txt', ':r'))

      eq('//?/', fnamemodify('//?/', ':r'))
      eq('//?/C:', fnamemodify('//?/C:', ':r'))
      eq('//?/C:/bar', fnamemodify('//?/C:/bar.txt', ':r'))
      eq(
        '//?/Volume{b75e2c83-0000-0000-0000-602f00000000}',
        fnamemodify('//?/Volume{b75e2c83-0000-0000-0000-602f00000000}', ':r')
      )
      eq(
        '//?/Volume{b75e2c83-0000-0000-0000-602f00000000}/bar',
        fnamemodify('//?/Volume{b75e2c83-0000-0000-0000-602f00000000}/bar.txt', ':r')
      )
    end
  end)

  it('handles :e', function()
    eq('txt', fnamemodify('hello.txt', ':e'))
    eq('txt', fnamemodify('path/to/hello.txt', ':e'))
    eq('txt', fnamemodify('foo///bar.txt', ':e'))
    eq('txt', fnamemodify('/bar.txt', ':e'))
    eq('txt', fnamemodify('///bar.txt', ':e'))
    if not is_os('win') then
      eq('txt', fnamemodify('//bar.txt', ':e'))
    else
      eq('', fnamemodify('//127.0.0.1', ':e'))
      eq('', fnamemodify('//127.0.0.1/C$', ':e'))
      eq('txt', fnamemodify('//127.0.0.1/C$/bar.txt', ':e'))
      eq('', fnamemodify('//?/UNC/127.0.0.1', ':e'))
      eq('', fnamemodify('//?/UNC/127.0.0.1/C$', ':e'))
      eq('txt', fnamemodify('//?/UNC/127.0.0.1/C$/bar.txt', ':e'))

      eq('', fnamemodify('//?/', ':e'))
      eq('', fnamemodify('//?/C:', ':e'))
      eq('txt', fnamemodify('//?/C:/bar.txt', ':e'))
      eq('', fnamemodify('//?/Volume{b75e2c83-0000-0000-0000-602f00000000}', ':e'))
      eq('txt', fnamemodify('//?/Volume{b75e2c83-0000-0000-0000-602f00000000}/bar.txt', ':e'))
    end
  end)

  it('handles regex replacements', function()
    eq('content-there-here.txt', fnamemodify('content-here-here.txt', ':s/here/there/'))
    eq('content-there-there.txt', fnamemodify('content-here-here.txt', ':gs/here/there/'))

    eq([[\foo\bar]], fnamemodify('///foo/bar', ':gs?/?\\?'))
  end)

  it('handles shell escape', function()
    local expected

    if is_os('win') then
      -- we expand with double-quotes on Windows
      expected = [["hello there! quote ' newline]] .. '\n' .. [["]]
    else
      expected = [['hello there! quote '\'' newline]] .. '\n' .. [[']]
    end

    eq(expected, fnamemodify("hello there! quote ' newline\n", ':S'))
  end)

  it('can combine :e and :r', function()
    -- simple, single extension filename
    eq('c', fnamemodify('a.c', ':e'))
    eq('c', fnamemodify('a.c', ':e:e'))
    eq('c', fnamemodify('a.c', ':e:e:r'))
    eq('c', fnamemodify('a.c', ':e:e:r:r'))

    -- multi extension filename
    eq('rb', fnamemodify('a.spec.rb', ':e:r'))
    eq('rb', fnamemodify('a.spec.rb', ':e:r:r'))

    eq('spec', fnamemodify('a.spec.rb', ':e:e:r'))
    eq('spec', fnamemodify('a.spec.rb', ':e:e:r:r'))

    eq('spec', fnamemodify('a.b.spec.rb', ':e:e:r'))
    eq('b.spec', fnamemodify('a.b.spec.rb', ':e:e:e:r'))
    eq('b', fnamemodify('a.b.spec.rb', ':e:e:e:r:r'))

    eq('spec', fnamemodify('a.b.spec.rb', ':r:e'))
    eq('b', fnamemodify('a.b.spec.rb', ':r:r:e'))

    -- extraneous :e expansions
    eq('c', fnamemodify('a.b.c.d.e', ':r:r:e'))
    eq('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e'))

    -- :e never includes the whole filename, so "a.b":e:e:e --> "b"
    eq('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e:e'))
    eq('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e:e:e'))
  end)
end)
