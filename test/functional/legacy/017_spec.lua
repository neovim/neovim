-- Tests for
-- - "gf" on ${VAR},
-- - ":checkpath!" with various 'include' settings.

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local write_file = helpers.write_file

local rmdir = function(dir)
  os.execute('rm -rf '..dir)
end

describe('17', function()
  setup(function()
    clear()
    write_file('test17a.in', [[
      This file is just to test "gf" in test 17.
      The contents is not important.
      Just testing!
      ]])
  end)
  teardown(function()
    os.remove('test17a.in')
    os.remove('Xbase.a')
    os.remove('Xbase.b')
    os.remove('Xbase.c')
    os.execute('rm -rf Xdir1')
  end)

  it('is working', function()
    insert([[
      	${CDIR}/test17a.in
      	$TDIR/test17a.in
      ]])

    source([[
      set isfname=@,48-57,/,.,-,_,+,,,$,:,~,{,}
      if has("unix")
        let $CDIR = "."
        /CDIR
      else
        let $TDIR = "."
        /TDIR
      endif]])
    -- Dummy writing for making sure that gf doesn't fail even if the current
    -- file is modified. It can be occurred when executing the following
    -- command directly on Windows without fixing the 'fileformat':
    -- > nmake -f Make_dos.mak test17.out
    execute('w! test.out')
    feed('gf')
    execute('set ff=unix')
    execute('w! test.out')
    execute('brewind')
    -- Check for 'include' without \zs or \ze.
    execute('lang C')
    os.remove('Xbase.a')
    rmdir('Xdir1')
    lfs.mkdir('Xdir1')
    lfs.mkdir('Xdir1/dir2')
    write_file('Xdir1/dir2/foo.a', '#include   "bar.a"')
    write_file('Xdir1/dir2/bar.a', '#include      "baz.a"')
    write_file('Xdir1/dir2/baz.a', '#include            "foo.a"')
    write_file('Xbase.a', '#include    <foo.a>')
    execute('e Xbase.a')
    execute('set path=Xdir1/dir2')
    execute('redir! >>test.out')
    execute('checkpath!')
    execute('redir END')
    execute('brewind')

    -- Check for 'include' with \zs and \ze.
    os.remove('Xbase.b')
    rmdir('Xdir1')
    lfs.mkdir('Xdir1')
    lfs.mkdir('Xdir1/dir2')
    source([[
      let &include='^\s*%inc\s*/\zs[^/]\+\ze'
      function! DotsToSlashes()
        return substitute(v:fname, '\.', '/', 'g') . '.b'
      endfunction
      let &includeexpr='DotsToSlashes()'
    ]])
    write_file('Xdir1/dir2/foo.b', '%inc   /bar/')
    write_file('Xdir1/dir2/bar.b', '%inc      /baz/')
    write_file('Xdir1/dir2/baz.b', '%inc            /foo/')
    write_file('Xbase.b', '%inc    /foo/')
    execute('e Xbase.b')
    execute('set path=Xdir1/dir2')
    execute('redir! >>test.out')
    execute('checkpath!')
    execute('redir END')
    execute('brewind')
    -- Check for 'include' with \zs and no \ze.
    os.remove('Xbase.c')
    rmdir('Xdir1')
    lfs.mkdir('Xdir1')
    lfs.mkdir('Xdir1/dir2')
    source([=[
      let &include='^\s*%inc\s*\%([[:upper:]][^[:space:]]*\s\+\)\?\zs\S\+\ze'
      function! StripNewlineChar()
        if v:fname =~ '\n$'
          return v:fname[:-2]
        endif
        return v:fname
      endfunction
      let &includeexpr='StripNewlineChar()'
      e! Xdir1/dir2/foo.c]=])
    feed('i%inc   bar.c<esc>')
    execute('w')
    execute('e Xdir1/dir2/bar.c')
    feed('i%inc      baz.c<esc>')
    execute('w')
    execute('e Xdir1/dir2/baz.c')
    feed('i%inc            foo.c<esc>')
    execute('w')
    execute('e Xdir1/dir2/FALSE.c')
    feed('i%inc            foo.c<esc>')
    execute('w')
    execute('e Xbase.c')
    execute('set path=Xdir1/dir2')
    feed('i%inc    FALSE.c foo.c<esc>')
    execute('w')
    execute('redir! >>test.out')
    execute('checkpath!')
    execute('redir END')
    execute('brewind')
    -- Change "\" to "/" for Windows and fix 'fileformat'.
    execute('e! test.out')
    execute([[%s#\\#/#g]])

    -- Assert buffer contents.
    expect([[
      This file is just to test "gf" in test 17.
      The contents is not important.
      Just testing!


      --- Included files in path ---
      Xdir1/dir2/foo.a
      Xdir1/dir2/foo.a -->
        Xdir1/dir2/bar.a
        Xdir1/dir2/bar.a -->
          Xdir1/dir2/baz.a
          Xdir1/dir2/baz.a -->
            "foo.a"  (Already listed)


      --- Included files in path ---
      Xdir1/dir2/foo.b
      Xdir1/dir2/foo.b -->
        Xdir1/dir2/bar.b
        Xdir1/dir2/bar.b -->
          Xdir1/dir2/baz.b
          Xdir1/dir2/baz.b -->
            foo  (Already listed)


      --- Included files in path ---
      Xdir1/dir2/foo.c
      Xdir1/dir2/foo.c -->
        Xdir1/dir2/bar.c
        Xdir1/dir2/bar.c -->
          Xdir1/dir2/baz.c
          Xdir1/dir2/baz.c -->
            foo.c  (Already listed)]])
  end)
end)
