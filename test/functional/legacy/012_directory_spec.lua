-- Tests for 'directory' option.
-- - ".", in same dir as file
-- - "./dir", in directory relative to file
-- - "dir", in directory relative to current dir

local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')

local eq = helpers.eq
local neq = helpers.neq
local wait = helpers.wait
local funcs = helpers.funcs
local meths = helpers.meths
local clear = helpers.clear
local insert = helpers.insert
local command = helpers.command
local write_file = helpers.write_file
local curbufmeths = helpers.curbufmeths

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
    command('qall!')
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

    meths.set_option('swapfile', true)
    curbufmeths.set_option('swapfile', true)
    meths.set_option('directory', '.')

    -- sanity check: files should not exist yet.
    eq(nil, lfs.attributes('.Xtest1.swp'))

    command('edit! Xtest1')
    wait()
    eq('Xtest1', funcs.buffer_name('%'))
    -- Verify that the swapfile exists. In the legacy test this was done by
    -- reading the output from :!ls.
    neq(nil, lfs.attributes('.Xtest1.swp'))

    meths.set_option('directory', './Xtest2,.')
    command('edit Xtest1')
    wait()

    -- swapfile should no longer exist in CWD.
    eq(nil, lfs.attributes('.Xtest1.swp'))

    eq({ "Xtest1.swp", "Xtest3" }, ls_dir_sorted("Xtest2"))

    meths.set_option('directory', 'Xtest.je')
    command('edit Xtest2/Xtest3')
    eq(true, curbufmeths.get_option('swapfile'))
    wait()

    eq({ "Xtest3" }, ls_dir_sorted("Xtest2"))
    eq({ "Xtest3.swp" }, ls_dir_sorted("Xtest.je"))
  end)
end)
