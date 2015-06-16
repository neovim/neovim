-- Tests for 'directory' option.
-- - ".", in same dir as file
-- - "./dir", in directory relative to file
-- - "dir", in directory relative to current dir

local helpers, lfs = require('test.functional.helpers'), require('lfs')
local feed, insert, source, eq, neq, eval, clear, execute, expect, wait,
  write_file = helpers.feed, helpers.insert, helpers.source, helpers.eq,
  helpers.neq, helpers.eval, helpers.clear, helpers.execute, helpers.expect,
  helpers.wait, helpers.write_file

describe('the directory option', function()
  setup(function()
    local text = [[
      start of testfile
      line 2 Abcdefghij
      line 3 Abcdefghij
      end of testfile]]
    clear()
    write_file('Xtest1', text)
    lfs.mkdir('Xtest.je')
    lfs.mkdir('Xtest2')
    write_file('Xtest2/Xtest3', text)
  end)
  teardown(function()
    os.execute('rm -rf Xtest*')
    os.remove('test.out')
  end)

  it('is working', function()
    insert([[
      start of testfile
      line 2 Abcdefghij
      line 3 Abcdefghij
      end of testfile]])

    -- First we need to set swapfile because helpers.lua unsets it on the
    -- command line.
    execute('set swapfile')
    execute('set dir=.,~')
    -- Assert that the swap file does not exist.
    eq(nil, lfs.attributes('.Xtest1.swp')) -- for unix
    eq(nil, lfs.attributes('Xtest1.swp'))  -- for other systems
    execute('!echo first line >test.out')
    execute('e! Xtest1')
    wait()
    -- Assert that the swapfile does exists. (Same as the vim commands below)
    if eval('has("unix")') == 1 then
      neq(nil, lfs.attributes('.Xtest1.swp'))
    else
      neq(nil, lfs.attributes('Xtest1.swp'))
    end
    execute('if has("unix")')
    -- Do an ls of the current dir to find the swap file, remove the leading
    -- dot to make the result the same for all systems.
    execute('  r!ls .X*.swp')
    execute([[  s/\.*X/X/]])
    execute('  .w >>test.out')
    execute('  undo')
    execute('else')
    execute('  !ls X*.swp >>test.out')
    execute('endif')
    execute('!echo under Xtest1.swp >>test.out')

    execute('set dir=./Xtest2,.,~')
    execute('e Xtest1')
    -- Swapfile in the current directory should not exist any longer.
    eq(nil, lfs.attributes('Xtest.swp'))
    eq('', io.popen('ls X*.swp'):read('*all'))
    execute('!ls X*.swp >>test.out')
    execute('!echo under under >>test.out')
    -- DONE
    -- There should be only one file in the directory Xtest2.
    eq('Xtest3\n', io.popen('ls Xtest2'):read('*all'))
    execute('!ls Xtest2 >>test.out')
    -- DONE???????
    execute('!echo under Xtest1.swp >>test.out')
    eq([[
      ]], io.open('test.out'):read('*all'))
    execute('set dir=Xtest.je,~')
    execute('e Xtest2/Xtest3')
    eq(1, eval('&swapfile'))
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
