-- Tests for
-- - "gf" on ${VAR},
-- - ":checkpath!" with various 'include' settings.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('17', function()
  setup(clear)
  teardown(function()
    os.remove('Xbase.a')
    os.remove('Xbase.b')
    os.remove('Xbase.c')
    os.execute('rm -rf Xdir1')
  end)

  it('is working', function()
    insert([=[
      	${CDIR}/test17a.in
      	$TDIR/test17a.in
      ]=])

    execute('set isfname=@,48-57,/,.,-,_,+,,,$,:,~,{,}')
    execute('function! DeleteDirectory(dir)')
    execute(' if has("win16") || has("win32") || has("win64") || has("dos16") || has("dos32")')
    execute('  exec "silent !rmdir /Q /S " . a:dir')
    execute(' else')
    execute('  exec "silent !rm -rf " . a:dir')
    execute(' endif')
    execute('endfun')
    execute('if has("unix")')
    execute('let $CDIR = "."')
    execute('/CDIR')
    execute('else')
    execute('let $TDIR = "."')
    execute('/TDIR')
    execute('endif')
    -- Dummy writing for making that sure gf doesn't fail even if the current
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
    execute('call delete("./Xbase.a")')
    execute('call DeleteDirectory("Xdir1")')
    execute('!mkdir Xdir1')
    execute('!mkdir "Xdir1/dir2"')
    execute('e! Xdir1/dir2/foo.a')
    feed('i#include   "bar.a"<esc>')
    execute('w')
    execute('e Xdir1/dir2/bar.a')
    feed('i#include      "baz.a"<esc>')
    execute('w')
    execute('e Xdir1/dir2/baz.a')
    feed('i#include            "foo.a"<esc>')
    execute('w')
    execute('e Xbase.a')
    execute('set path=Xdir1/dir2')
    feed('i#include    <foo.a><esc>')
    execute('w')
    execute('redir! >>test.out')
    execute('checkpath!')
    execute('redir END')
    execute('brewind')
    -- Check for 'include' with \zs and \ze.
    execute('call delete("./Xbase.b")')
    execute('call DeleteDirectory("Xdir1")')
    execute('!mkdir Xdir1')
    execute('!mkdir "Xdir1/dir2"')
    execute([=[let &include='^\s*%inc\s*/\zs[^/]\+\ze']=])
    execute('function! DotsToSlashes()')
    execute([[  return substitute(v:fname, '\.', '/', 'g') . '.b']])
    execute('endfunction')
    execute([[let &includeexpr='DotsToSlashes()']])
    execute('e! Xdir1/dir2/foo.b')
    feed('i%inc   /bar/<esc>')
    execute('w')
    execute('e Xdir1/dir2/bar.b')
    feed('i%inc      /baz/<esc>')
    execute('w')
    execute('e Xdir1/dir2/baz.b')
    feed('i%inc            /foo/<esc>')
    execute('w')
    execute('e Xbase.b')
    execute('set path=Xdir1/dir2')
    feed('i%inc    /foo/<esc>')
    execute('w')
    execute('redir! >>test.out')
    execute('checkpath!')
    execute('redir END')
    execute('brewind')
    -- Check for 'include' with \zs and no \ze.
    execute('call delete("./Xbase.c")')
    execute('call DeleteDirectory("Xdir1")')
    execute('!mkdir Xdir1')
    execute('!mkdir "Xdir1/dir2"')
    execute([=[let &include='^\s*%inc\s*\%([[:upper:]][^[:space:]]*\s\+\)\?\zs\S\+\ze']=])
    execute('function! StripNewlineChar()')
    execute([[  if v:fname =~ '\n$']])
    execute('    return v:fname[:-2]')
    execute('  endif')
    execute('  return v:fname')
    execute('endfunction')
    execute([[let &includeexpr='StripNewlineChar()']])
    execute('e! Xdir1/dir2/foo.c')
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
    execute('e test.out')
    execute([[%s#\\#/#g]])
    execute('set ff&')
    execute('w')

    -- Assert buffer contents.
    expect([=[
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
            foo.c  (Already listed)]=])
  end)
end)
