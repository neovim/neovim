-- Tests for autocommands on :close command
-- Write three files and open them, each in a window.
-- Then go to next window, with autocommand that deletes the previous one.
-- Do this twice, writing the file.
-- Also test deleting the buffer on a Unload event. 
-- If this goes wrong there will be the ATTENTION prompt.
-- Also test changing buffers in a BufDel autocommand. 
-- If this goes wrong there are ml_line errors and/or a Crash.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('WinLeave and BufUnload deletes buffer', function()
  setup(clear)

  it('is working', function()
    insert([[
      start of testfile
      	contents
      	contents
      	contents
      end of testfile]])

    -- Write three test files Xtestje(n)
    execute('/^start of testfile')
    execute('.,/^end of testfile/w! Xtestje1')
    execute('/^start of testfile')
    execute('.,/^end of testfile/w! Xtestje2')
    execute('/^start of testfile')
    execute('.,/^end of testfile/w! Xtestje3')

    -- Open all three test files in a new split window
    execute('e Xtestje1')
    feed('otestje1<Esc>')
    execute('w')
    execute('sp Xtestje2')
    feed('otestje2<Esc>')
    execute('w')
    execute('sp Xtestje3')
    feed('otestje3<Esc>')
    execute('w')

    -- Go to next split window (Xtestje2)
    -- Add au then go to Xtestje1 split window
    feed('<C-w><C-w><CR>')
    execute('au WinLeave Xtestje2 bwipe')
    feed('<C-w><C-w><CR>')
    execute('w! test.out')

    -- Add au such that when Xtestje1 is closed
    -- Xtestje3 buffer is closed as well leaving Xtestje1 opened
    execute('au WinLeave Xtestje1 bwipe Xtestje3')
    execute('close')
    execute('w >> test.out')

    -- Kill all the buffers except Xtestje1 and reset Xtestje1 au
    execute('e Xtestje1')
    execute('bwipe Xtestje2 Xtestje3 test.out')
    execute('au!')
    execute('au BufUnload Xtestje1 bwipe')
    execute('e Xtestje3')
    execute('w >> test.out')

    -- Append Xtestje2 to output
    -- Because Xtestje1 will not open from the BufUnload au
    execute('e Xtestje2')
    execute('sp Xtestje1')
    execute('e')
    execute('w >> test.out')

    -- Open Xtestje1 and kill all other buffers
    execute('au!')
    execute('only')
    execute('e Xtestje1')
    execute('bwipe Xtestje2 Xtestje3 test.out')

    -- Set au to open Xtestje1 when it's killed
    execute('au BufWipeout Xtestje1 buf Xtestje1')
    execute('bwipe')
    execute('w >> test.out')
    execute('e test.out')

    -- Assert buffer contents
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
      os.remove('test.out')
  end)
end)
