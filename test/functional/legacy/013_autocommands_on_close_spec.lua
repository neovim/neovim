-- Tests for autocommands on :close command
--
-- Write three files and open them, each in a window.
-- Then go to next window, with autocommand that deletes the previous one.
-- Do this twice, writing the file.
--
-- Also test deleting the buffer on a Unload event.  If this goes wrong there
-- will be the ATTENTION prompt.
--
-- Also test changing buffers in a BufDel autocommand.  If this goes wrong there
-- are ml_line errors and/or a Crash.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('autocommands on close', function()
  setup(clear)

  it('is working', function()
    insert([=[
      start of testfile
      	contents
      	contents
      	contents
      end of testfile]=])

    -- Write the current buffer to "test13.in", else subsequent
    -- steps will fail
    execute('w! test13.in')
    execute(':/^start of testfile/,/^end of testfile/w! Xtestje1')
    execute(':/^start of testfile/,/^end of testfile/w! Xtestje2')
    execute(':/^start of testfile/,/^end of testfile/w! Xtestje3')
    execute('e Xtestje1')
    feed('otestje1<esc>')
    execute('write')
    execute('sp Xtestje2')
    feed('otestje2<esc>')
    execute('write')
    execute('sp Xtestje3')
    feed('otestje3<esc>')
    execute('w')
    feed('<c-w><c-w><cr>')
    execute('au WinLeave Xtestje2 bwipe')
    feed('<c-w><c-w><cr>')
    execute('w! test.out')
    execute('au WinLeave Xtestje1 bwipe Xtestje3')
    execute('close')
    execute('w >>test.out')
    execute('e Xtestje1')
    execute('bwipe Xtestje2 Xtestje3 test.out')
    execute('au!')
    execute('au! BufUnload Xtestje1 bwipe')
    execute('e Xtestje3')
    execute('w >>test.out')
    execute('e Xtestje2')
    execute('sp Xtestje1')
    execute('e')
    execute('w >>test.out')
    execute('au!')
    execute('only')
    execute('e Xtestje1')
    execute('bwipe Xtestje2 Xtestje3 test.out test13.in')
    execute('au BufWipeout Xtestje1 buf Xtestje1')
    execute('bwipe')
    execute('w >>test.out')

    ---- Open the output to see if it meets the expectations.
    execute('e! test.out')

    -- Assert buffer contents.
    expect([=[
      start of testfile
      testje1
      	contents
      	contents
      	contents
      end of testfile
      start of testfile
      testje1
      	contents
      	contents
      	contents
      end of testfile
      start of testfile
      testje3
      	contents
      	contents
      	contents
      end of testfile
      start of testfile
      testje2
      	contents
      	contents
      	contents
      end of testfile
      start of testfile
      testje1
      	contents
      	contents
      	contents
      end of testfile]=])

  end)
  teardown(function()
    os.remove('Xtestje1')
    os.remove('Xtestje2')
    os.remove('Xtestje3')
    os.remove('test13.in')
    os.remove('test.out')
  end)
end)
