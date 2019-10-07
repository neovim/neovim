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

  describe('examples from ":help filename-modifiers"', function()
    local filename = "src/version.c"
    local cwd = getcwd()

    it(':p', function()
      eq(cwd .. '/src/version.c', fnamemodify(filename, ':p'))
    end)

    it(':p:.', function()
      eq('src/version.c', fnamemodify(filename, ':p:.'))
    end)

    it(':p:h', function()
      eq(cwd .. '/src', fnamemodify(filename, ':p:h'))
    end)

    it(':p:h:h', function()
      eq(cwd .. '', fnamemodify(filename, ':p:h:h'))
    end)

    it(':p:t', function()
      eq('version.c', fnamemodify(filename, ':p:t'))
    end)

    it(':p:r', function()
      eq(cwd .. '/src/version', fnamemodify(filename, ':p:r'))
    end)

    it(':s?version?main?:p', function()
      eq(cwd .. '/src/main.c', fnamemodify(filename, ':s?version?main?:p'))
    end)

    it(':p:gs?/?\\\\?', function()
      local converted_cwd = cwd:gsub('/', '\\')
      eq(converted_cwd .. '\\src\\version.c', fnamemodify(filename, ':p:gs?/?\\\\?'))
    end)

    it(':h', function()
      eq('src', fnamemodify(filename, ':h'))
    end)

    it(':t', function()
      eq('version.c', fnamemodify(filename, ':t'))
    end)

    it(':r', function()
      eq('src/version', fnamemodify(filename, ':r'))
    end)

    it(':t:r', function()
      eq('version', fnamemodify(filename, ':t:r'))
    end)

    it(':e', function()
      eq('c', fnamemodify(filename, ':e'))
    end)

    it(':s?version?main?', function()
      eq('src/main.c', fnamemodify(filename, ':s?version?main?'))
    end)
  end)

  describe('advanced examples from ":help filename-modifiers"', function()
    local filename = "src/version.c.gz"

    it(':e', function()
      eq('gz', fnamemodify(filename, ':e'))
    end)

    it(':e:e', function()
      eq('c.gz', fnamemodify(filename, ':e:e'))
    end)

    it(':e:e:e', function()
      eq('c.gz', fnamemodify(filename, ':e:e:e'))
    end)

    it(':e:e:r', function()
      eq('c', fnamemodify(filename, ':e:e:r'))
    end)

    it(':r', function()
      eq('src/version.c', fnamemodify(filename, ':r'))
    end)

    it(':r:e', function()
      eq('c', fnamemodify(filename, ':r:e'))
    end)

    it(':r:r', function()
      eq('src/version', fnamemodify(filename, ':r:r'))
    end)

    it(':r:r:r', function()
      eq('src/version', fnamemodify(filename, ':r:r:r'))
    end)
  end)

  describe('modify with :h', function()
    it('handles bare filenames', function()
      eq('.', fnamemodify('hello.txt', ':h'))
    end)

    it('handles paths', function()
      eq('path/to', fnamemodify('path/to/hello.txt', ':h'))
    end)
  end)

  describe('modify with :t', function()
    it('handles bare filenames', function()
      eq('hello.txt', fnamemodify('hello.txt', ':t'))
    end)

    it('handles paths', function()
      eq('hello.txt', fnamemodify('path/to/hello.txt', ':t'))
    end)
  end)

  describe('modify with :r', function()
    it('handles bare filenames', function()
      eq('hello', fnamemodify('hello.txt', ':r'))
    end)

    it('handles paths', function()
      eq('path/to/hello', fnamemodify('path/to/hello.txt', ':r'))
    end)
  end)

  describe('modify with :e', function()
    it('handles bare filenames', function()
      eq('txt', fnamemodify('hello.txt', ':e'))
    end)

    it('handles paths', function()
      eq('txt', fnamemodify('path/to/hello.txt', ':e'))
    end)
  end)

  describe('modify with regex replacements', function()
    it('handles a simple s///', function()
      eq('content-there-here.txt', fnamemodify('content-here-here.txt', ':s/here/there/'))
    end)

    it('handles global', function()
      eq('content-there-there.txt', fnamemodify('content-here-here.txt', ':gs/here/there/'))
    end)
  end)

  it('modify with shell escape', function()
    eq("'hello there! quote '\\'' newline\n'", fnamemodify("hello there! quote ' newline\n", ':S'))
  end)

  describe('combining :e and :r', function()
    describe('single-extension filename', function()
      it('handling a.c :e', function() eq('c', fnamemodify('a.c', ':e')) end)
      it('handling a.c :e:e', function() eq('c', fnamemodify('a.c', ':e:e')) end)
      it('handling a.c :e:e:r', function() eq('c', fnamemodify('a.c', ':e:e:r')) end)
      it('handling a.c :e:e:r:r', function() eq('c', fnamemodify('a.c', ':e:e:r:r')) end)
    end)

    describe('multiple-extension filename', function()
      it('handling a.spec.rb :e', function() eq('rb', fnamemodify('a.spec.rb', ':e:r')) end)
      it('handling a.spec.rb :e:r', function() eq('rb', fnamemodify('a.spec.rb', ':e:r')) end)
      it('handling a.spec.rb :e:e:r', function() eq('spec', fnamemodify('a.spec.rb', ':e:e:r')) end)
      it('handling a.spec.rb :e:e:r:r', function() eq('spec', fnamemodify('a.spec.rb', ':e:e:r:r')) end)
      it('handling a.b.spec.rb :e:e:r', function() eq('spec', fnamemodify('a.b.spec.rb', ':e:e:r')) end)
      it('handling a.b.spec.rb :e:e:e:r', function() eq('b.spec', fnamemodify('a.b.spec.rb', ':e:e:e:r')) end)
      it('handling a.b.spec.rb :e:e:e:r:r', function() eq('b', fnamemodify('a.b.spec.rb', ':e:e:e:r:r')) end)

      it('handling a.b.spec.rb :r:e', function() eq('spec', fnamemodify('a.b.spec.rb', ':r:e')) end)
      it('handling a.b.spec.rb :r:r:e', function() eq('b', fnamemodify('a.b.spec.rb', ':r:r:e')) end)

      describe('extraneous :e expansions', function()
        it('handling a.b.c.d.e :r:r:e', function() eq('c', fnamemodify('a.b.c.d.e', ':r:r:e')) end)
        it('handling a.b.c.d.e :r:r:e:e', function() eq('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e')) end)

        -- :e never includes the whole filename, so "a.b":e:e:e --> "b"
        it('handling a.b.c.d.e :r:r:e:e:e', function() eq('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e:e')) end)
        it('handling a.b.c.d.e :r:r:e:e:e:e', function() eq('b.c', fnamemodify('a.b.c.d.e', ':r:r:e:e:e:e')) end)
      end)
    end)
  end)
end)
