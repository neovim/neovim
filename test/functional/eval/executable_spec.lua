local helpers = require('test.functional.helpers')(after_each)
local eq, clear, call, iswin, write_file, command =
  helpers.eq, helpers.clear, helpers.call, helpers.iswin, helpers.write_file,
  helpers.command

describe('executable()', function()
  before_each(clear)

  it('returns 1 for commands in $PATH', function()
    local exe = iswin() and 'ping' or 'ls'
    eq(1, call('executable', exe))
  end)

  it('returns 0 for non-existent files', function()
    eq(0, call('executable', 'no_such_file_exists_209ufq23f'))
  end)

  it('sibling to nvim binary', function()
    -- Some executable in build/bin/, *not* in $PATH nor CWD.
    local sibling_exe = 'printargs-test'
    -- Windows: siblings are in Nvim's "pseudo-$PATH".
    local expected = iswin() and 1 or 0
    if iswin() then
      eq('arg1=lemon;arg2=sky;arg3=tree;',
         call('system', sibling_exe..' lemon sky tree'))
    end
    local is_executable = call('executable', sibling_exe)
    if iswin() and is_executable ~= expected then
      pending('XXX: sometimes fails on AppVeyor')
    else
      eq(expected, is_executable)
    end
  end)

  describe('exec-bit', function()
    setup(function()
      clear()
      write_file('Xtest_not_executable', 'non-executable file')
      write_file('Xtest_executable', 'executable file (exec-bit set)')
      if not iswin() then  -- N/A for Windows.
        call('system', {'chmod', '-x', 'Xtest_not_executable'})
        call('system', {'chmod', '+x', 'Xtest_executable'})
      end
    end)

    teardown(function()
      os.remove('Xtest_not_executable')
      os.remove('Xtest_executable')
    end)

    it('not set', function()
      eq(0, call('executable', 'Xtest_not_executable'))
      eq(0, call('executable', './Xtest_not_executable'))
    end)

    it('set, unqualified and not in $PATH', function()
      eq(0, call('executable', 'Xtest_executable'))
    end)

    it('set, qualified as a path', function()
      local expected = iswin() and 0 or 1
      eq(expected, call('executable', './Xtest_executable'))
    end)
  end)
end)

describe('executable() (Windows)', function()
  if not iswin() then return end  -- N/A for Unix.

  local exts = {'bat', 'exe', 'com', 'cmd'}
  setup(function()
    for _, ext in ipairs(exts) do
      write_file('test_executable_'..ext..'.'..ext, '')
    end
    write_file('test_executable_zzz.zzz', '')
  end)

  teardown(function()
    for _, ext in ipairs(exts) do
      os.remove('test_executable_'..ext..'.'..ext)
    end
    os.remove('test_executable_zzz.zzz')
  end)

  it('tries default extensions on a filename if $PATHEXT is empty', function()
    -- Empty $PATHEXT defaults to ".com;.exe;.bat;.cmd".
    clear({env={PATHEXT=''}})
    for _,ext in ipairs(exts) do
      eq(1, call('executable', 'test_executable_'..ext))
    end
    eq(0, call('executable', 'test_executable_zzz'))
  end)

  it('tries default extensions on a filepath if $PATHEXT is empty', function()
    -- Empty $PATHEXT defaults to ".com;.exe;.bat;.cmd".
    clear({env={PATHEXT=''}})
    for _,ext in ipairs(exts) do
      eq(1, call('executable', '.\\test_executable_'..ext))
    end
    eq(0, call('executable', '.\\test_executable_zzz'))
  end)

  it('full path with extension', function()
    -- Some executable we can expect in the test env.
    local exe = 'printargs-test'
    local exedir = helpers.eval("fnamemodify(v:progpath, ':h')")
    local exepath = exedir..'/'..exe..'.exe'
    eq(1, call('executable', exepath))
    eq('arg1=lemon;arg2=sky;arg3=tree;',
       call('system', exepath..' lemon sky tree'))
  end)

  it('full path without extension', function()
    -- Some executable we can expect in the test env.
    local exe = 'printargs-test'
    local exedir = helpers.eval("fnamemodify(v:progpath, ':h')")
    local exepath = exedir..'/'..exe
    eq('arg1=lemon;arg2=sky;arg3=tree;',
       call('system', exepath..' lemon sky tree'))
     eq(1, call('executable', exepath))
  end)

  it('respects $PATHEXT when trying extensions on a filename', function()
    clear({env={PATHEXT='.zzz'}})
    for _,ext in ipairs(exts) do
      eq(0, call('executable', 'test_executable_'..ext))
    end
    eq(1, call('executable', 'test_executable_zzz'))
  end)

  it('respects $PATHEXT when trying extensions on a filepath', function()
    clear({env={PATHEXT='.zzz'}})
    for _,ext in ipairs(exts) do
      eq(0, call('executable', '.\\test_executable_'..ext))
    end
    eq(1, call('executable', '.\\test_executable_zzz'))
  end)

  it("with weird $PATHEXT", function()
    clear({env={PATHEXT=';'}})
    eq(0, call('executable', '.\\test_executable_zzz'))
    clear({env={PATHEXT=';;;.zzz;;'}})
    eq(1, call('executable', '.\\test_executable_zzz'))
  end)

  it("unqualified filename, Unix-style 'shell'", function()
    clear({env={PATHEXT=''}})
    command('set shell=sh')
    for _,ext in ipairs(exts) do
      eq(1, call('executable', 'test_executable_'..ext..'.'..ext))
    end
    eq(1, call('executable', 'test_executable_zzz.zzz'))
  end)

  it("relative path, Unix-style 'shell' (backslashes)", function()
    clear({env={PATHEXT=''}})
    command('set shell=bash.exe')
    for _,ext in ipairs(exts) do
      eq(1, call('executable', '.\\test_executable_'..ext..'.'..ext))
      eq(1, call('executable', './test_executable_'..ext..'.'..ext))
    end
    eq(1, call('executable', '.\\test_executable_zzz.zzz'))
    eq(1, call('executable', './test_executable_zzz.zzz'))
  end)

  it('unqualified filename, $PATHEXT contains dot', function()
    clear({env={PATHEXT='.;.zzz'}})
    for _,ext in ipairs(exts) do
      eq(1, call('executable', 'test_executable_'..ext..'.'..ext))
    end
    eq(1, call('executable', 'test_executable_zzz.zzz'))
    clear({env={PATHEXT='.zzz;.'}})
    for _,ext in ipairs(exts) do
      eq(1, call('executable', 'test_executable_'..ext..'.'..ext))
    end
    eq(1, call('executable', 'test_executable_zzz.zzz'))
  end)

  it('relative path, $PATHEXT contains dot (backslashes)', function()
    clear({env={PATHEXT='.;.zzz'}})
    for _,ext in ipairs(exts) do
      eq(1, call('executable', '.\\test_executable_'..ext..'.'..ext))
      eq(1, call('executable', './test_executable_'..ext..'.'..ext))
    end
    eq(1, call('executable', '.\\test_executable_zzz.zzz'))
    eq(1, call('executable', './test_executable_zzz.zzz'))
  end)

  it('ignores case of extension', function()
    clear({env={PATHEXT='.ZZZ'}})
    eq(1, call('executable', 'test_executable_zzz.zzz'))
  end)

  it('relative path does not search $PATH', function()
    clear({env={PATHEXT=''}})
    eq(0, call('executable', './System32/notepad.exe'))
    eq(0, call('executable', '.\\System32\\notepad.exe'))
    eq(0, call('executable', '../notepad.exe'))
    eq(0, call('executable', '..\\notepad.exe'))
  end)
end)
