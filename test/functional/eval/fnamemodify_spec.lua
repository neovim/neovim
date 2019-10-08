local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local iswin = helpers.iswin
local fnamemodify = helpers.funcs.fnamemodify
local getcwd = helpers.funcs.getcwd
local command = helpers.command
local write_file = helpers.write_file

describe('fnamemodify()', function()
  setup(function()
    write_file('Xtest-fnamemodify.txt', [[foobar]])
  end)

  before_each(clear)

  teardown(function()
    os.remove('Xtest-fnamemodify.txt')
  end)

  it('handles the root path', function()
    local root = helpers.pathroot()
    eq(root, fnamemodify([[/]], ':p:h'))
    eq(root, fnamemodify([[/]], ':p'))
    if iswin() then
      eq(root, fnamemodify([[\]], ':p:h'))
      eq(root, fnamemodify([[\]], ':p'))
      command('set shellslash')
      root = string.sub(root, 1, -2)..'/'
      eq(root, fnamemodify([[\]], ':p:h'))
      eq(root, fnamemodify([[\]], ':p'))
      eq(root, fnamemodify([[/]], ':p:h'))
      eq(root, fnamemodify([[/]], ':p'))
    end
  end)

  it(':8 works', function()
    eq('Xtest-fnamemodify.txt', fnamemodify([[Xtest-fnamemodify.txt]], ':8'))
  end)

  it('handles examples from ":help filename-modifiers"', function()
    local filename = "src/version.c"
    local cwd = getcwd()

    eq(cwd .. '/src/version.c', fnamemodify(filename, ':p'))
    eq('src/version.c', fnamemodify(filename, ':p:.'))
    eq(cwd .. '/src', fnamemodify(filename, ':p:h'))
    eq(cwd .. '', fnamemodify(filename, ':p:h:h'))
    eq('version.c', fnamemodify(filename, ':p:t'))
    eq(cwd .. '/src/version', fnamemodify(filename, ':p:r'))

    eq(cwd .. '/src/main.c', fnamemodify(filename, ':s?version?main?:p'))

    local converted_cwd = cwd:gsub('/', '\\')
    eq(converted_cwd .. '\\src\\version.c', fnamemodify(filename, ':p:gs?/?\\\\?'))

    eq('src', fnamemodify(filename, ':h'))
    eq('version.c', fnamemodify(filename, ':t'))
    eq('src/version', fnamemodify(filename, ':r'))
    eq('version', fnamemodify(filename, ':t:r'))
    eq('c', fnamemodify(filename, ':e'))

    eq('src/main.c', fnamemodify(filename, ':s?version?main?'))
  end)

  it('handles advanced examples from ":help filename-modifiers"', function()
    local filename = "src/version.c.gz"

    eq('gz', fnamemodify(filename, ':e'))
    eq('c.gz', fnamemodify(filename, ':e:e'))
    eq('c.gz', fnamemodify(filename, ':e:e:e'))

    eq('c', fnamemodify(filename, ':e:e:r'))

    eq('src/version.c', fnamemodify(filename, ':r'))
    eq('c', fnamemodify(filename, ':r:e'))

    eq('src/version', fnamemodify(filename, ':r:r'))
    eq('src/version', fnamemodify(filename, ':r:r:r'))
  end)

  it('handles :h', function()
    eq('.', fnamemodify('hello.txt', ':h'))

    eq('path/to', fnamemodify('path/to/hello.txt', ':h'))
  end)

  it('handles :t', function()
    eq('hello.txt', fnamemodify('hello.txt', ':t'))
    eq('hello.txt', fnamemodify('path/to/hello.txt', ':t'))
  end)

  it('handles :r', function()
    eq('hello', fnamemodify('hello.txt', ':r'))
    eq('path/to/hello', fnamemodify('path/to/hello.txt', ':r'))
  end)

  it('handles :e', function()
    eq('txt', fnamemodify('hello.txt', ':e'))
    eq('txt', fnamemodify('path/to/hello.txt', ':e'))
  end)

  it('handles regex replacements', function()
    eq('content-there-here.txt', fnamemodify('content-here-here.txt', ':s/here/there/'))
    eq('content-there-there.txt', fnamemodify('content-here-here.txt', ':gs/here/there/'))
  end)

  it('handles shell escape', function()
    local expected

    if iswin() then
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
