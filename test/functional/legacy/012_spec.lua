-- Tests for 'directory' option.
-- - ".", in same dir as file
-- - "./dir", in directory relative to file
-- - "dir", in directory relative to current dir

local helpers, lfs = require('test.functional.helpers'), require('lfs')
local feed, insert, source, eq, neq, eval, clear, execute, expect, wait,
  write_file = helpers.feed, helpers.insert, helpers.source, helpers.eq,
  helpers.neq, helpers.eval, helpers.clear, helpers.execute, helpers.expect,
  helpers.wait, helpers.write_file

describe('12', function()
  setup(clear)

  it('is working', function()
    insert([[
      start of testfile
      line 2 Abcdefghij
      line 3 Abcdefghij
      end of testfile]])

    execute('set dir=.,~')
    execute('/start of testfile/,/end of testfile/w! Xtest1')
    -- Do an ls of the current dir to find the swap file (should not be there).
    execute('if has("unix")')
    execute('  !ls .X*.swp >test.out')
    execute('else')
    execute('  r !ls X*.swp >test.out')
    execute('endif')
    execute('!echo first line >>test.out')
    execute('e Xtest1')
    execute('if has("unix")')
    -- Do an ls of the current dir to find the swap file, remove the leading dot.
    -- To make the result the same for all systems.
    execute('  r!ls .X*.swp')
    execute([[  s/\.*X/X/]])
    execute('  .w >>test.out')
    execute('  undo')
    execute('else')
    execute('  !ls X*.swp >>test.out')
    execute('endif')
    execute('!echo under Xtest1.swp >>test.out')
    execute('!mkdir Xtest2')
    execute('set dir=./Xtest2,.,~')
    execute('e Xtest1')
    execute('!ls X*.swp >>test.out')
    execute('!echo under under >>test.out')
    execute('!ls Xtest2 >>test.out')
    execute('!echo under Xtest1.swp >>test.out')
    execute('!mkdir Xtest.je')
    execute('/start of testfile/,/end of testfile/w! Xtest2/Xtest3')
    execute('set dir=Xtest.je,~')
    execute('e Xtest2/Xtest3')
    execute('swap')
    execute('!ls Xtest2 >>test.out')
    execute('!echo under Xtest3 >>test.out')
    execute('!ls Xtest.je >>test.out')
    execute('!echo under Xtest3.swp >>test.out')
    execute('e! test.out')

    -- Assert buffer contents.
    expect([[
      first line
      Xtest1.swp
      under Xtest1.swp
      under under
      Xtest1.swp
      under Xtest1.swp
      Xtest3
      under Xtest3
      Xtest3.swp
      under Xtest3.swp]])
  end)
end)
