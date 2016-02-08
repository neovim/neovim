-- Tests for 'directory' option.
-- - ".", in same dir as file
-- - "./dir", in directory relative to file
-- - "dir", in directory relative to current dir

local helpers, lfs = require('test.functional.helpers'), require('lfs')
local feed, insert, source, eq, neq, eval, clear, execute, expect, wait,
  write_file = helpers.feed, helpers.insert, helpers.source, helpers.eq,
  helpers.neq, helpers.eval, helpers.clear, helpers.execute, helpers.expect,
  helpers.wait, helpers.write_file

local function expect_test_out(text)
  wait()
  return eq(helpers.dedent(text), io.open('test.out'):read('*all'))
end

describe('directory option', function()
  setup(function()
    local text = [[
      start of testfile
      line 2 Abcdefghij
      line 3 Abcdefghij
      end of testfile
      ]]
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

    execute('e! Xtest1')
    wait()
    eq('Xtest1', eval('buffer_name("%")'))
    -- Assert that the swapfile does exists.  In the legacy test this was done
    -- by reading the output from :!ls.
    if eval('has("unix")') == 1 then
      neq(nil, lfs.attributes('.Xtest1.swp'))
    else
      neq(nil, lfs.attributes('Xtest1.swp'))
    end

    execute('set dir=./Xtest2,.,~')
    execute('e Xtest1')
    wait()
    -- Swapfile in the current directory should not exist any longer.
    eq(nil, lfs.attributes('.Xtest1.swp')) -- for unix
    eq(nil, lfs.attributes('Xtest1.swp'))  -- for other systems
    -- In the old test Xtest2/Xtest3 was not yet present because it was not
    -- written in setup().
    eq('.\n..\nXtest1.swp\nXtest3\n', io.popen('ls -a Xtest2'):read('*all'))

    execute('set dir=Xtest.je,~')
    execute('e Xtest2/Xtest3')
    eq(1, eval('&swapfile'))
    execute('swap')
    wait()
    eq('.\n..\nXtest3\n', io.popen('ls -a Xtest2'):read('*all'))
    wait()
    eq('.\n..\nXtest3.swp\n', io.popen('ls -a Xtest.je'):read('*all'))
  end)
end)
