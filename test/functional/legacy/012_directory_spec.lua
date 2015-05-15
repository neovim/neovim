-- Tests for 'directory' option.
-- - ".", in same dir as file
-- - "./dir", in directory relative to file
-- - "dir", in directory relative to current dir

local helpers          = require('test.functional.helpers')(after_each)
local lfs              = require('lfs')
local insert, eq       = helpers.insert, helpers.eq
local neq, eval        = helpers.neq, helpers.eval
local clear, execute   = helpers.clear, helpers.execute
local wait, write_file = helpers.wait, helpers.write_file

local function ls_dir_sorted(dirname)
  local files = {}
  for f in lfs.dir(dirname) do
    if f ~= "." and f~= ".." then
      table.insert(files, f)
    end
  end
  table.sort(files)
  return files
end

describe("'directory' option", function()
  setup(function()
    local text = [[
      start of testfile
      line 2 Abcdefghij
      line 3 Abcdefghij
      end of testfile
      ]]
    write_file('Xtest1', text)
    lfs.mkdir('Xtest.je')
    lfs.mkdir('Xtest2')
    write_file('Xtest2/Xtest3', text)
    clear()
  end)
  teardown(function()
    helpers.rmdir('Xtest.je')
    helpers.rmdir('Xtest2')
    os.remove('Xtest1')
  end)

  it('is working', function()
    insert([[
      start of testfile
      line 2 Abcdefghij
      line 3 Abcdefghij
      end of testfile]])

    execute('set swapfile')
    execute('set dir=.,~')

    -- sanity check: files should not exist yet.
    eq(nil, lfs.attributes('.Xtest1.swp')) -- unix
    eq(nil, lfs.attributes('Xtest1.swp'))  -- non-unix

    execute('e! Xtest1')
    wait()
    eq('Xtest1', eval('buffer_name("%")'))
    -- Verify that the swapfile exists. In the legacy test this was done by
    -- reading the output from :!ls.
    if eval('has("unix")') == 1 then
      neq(nil, lfs.attributes('.Xtest1.swp'))
    else
      neq(nil, lfs.attributes('Xtest1.swp'))
    end

    execute('set dir=./Xtest2,.,~')
    execute('e Xtest1')
    wait()

    -- swapfile should no longer exist in CWD.
    eq(nil, lfs.attributes('.Xtest1.swp')) -- for unix
    eq(nil, lfs.attributes('Xtest1.swp'))  -- for other systems

    eq({ "Xtest1.swp", "Xtest3" }, ls_dir_sorted("Xtest2"))

    execute('set dir=Xtest.je,~')
    execute('e Xtest2/Xtest3')
    eq(1, eval('&swapfile'))
    execute('swap')
    wait()

    eq({ "Xtest3" }, ls_dir_sorted("Xtest2"))
    eq({ "Xtest3.swp" }, ls_dir_sorted("Xtest.je"))
  end)
end)
