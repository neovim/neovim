-- Tests for 'directory' option.
-- - ".", in same dir as file
-- - "./dir", in directory relative to file
-- - "dir", in directory relative to current dir

local t = require('test.functional.testutil')(after_each)

local eq = t.eq
local neq = t.neq
local poke_eventloop = t.poke_eventloop
local fn = t.fn
local api = t.api
local clear = t.clear
local insert = t.insert
local command = t.command
local write_file = t.write_file
local expect_exit = t.expect_exit
local mkdir = t.mkdir

local function ls_dir_sorted(dirname)
  local files = {}
  for f in vim.fs.dir(dirname) do
    if f ~= '.' and f ~= '..' then
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
    mkdir('Xtest.je')
    mkdir('Xtest2')
    write_file('Xtest2/Xtest3', text)
    clear()
  end)
  teardown(function()
    expect_exit(command, 'qall!')
    t.rmdir('Xtest.je')
    t.rmdir('Xtest2')
    os.remove('Xtest1')
  end)

  it('is working', function()
    insert([[
      start of testfile
      line 2 Abcdefghij
      line 3 Abcdefghij
      end of testfile]])

    api.nvim_set_option_value('swapfile', true, {})
    api.nvim_set_option_value('swapfile', true, {})
    api.nvim_set_option_value('directory', '.', {})

    -- sanity check: files should not exist yet.
    eq(nil, vim.uv.fs_stat('.Xtest1.swp'))

    command('edit! Xtest1')
    poke_eventloop()
    eq('Xtest1', fn.buffer_name('%'))
    -- Verify that the swapfile exists. In the legacy test this was done by
    -- reading the output from :!ls.
    neq(nil, vim.uv.fs_stat('.Xtest1.swp'))

    api.nvim_set_option_value('directory', './Xtest2,.', {})
    command('edit Xtest1')
    poke_eventloop()

    -- swapfile should no longer exist in CWD.
    eq(nil, vim.uv.fs_stat('.Xtest1.swp'))

    eq({ 'Xtest1.swp', 'Xtest3' }, ls_dir_sorted('Xtest2'))

    api.nvim_set_option_value('directory', 'Xtest.je', {})
    command('bdelete')
    command('edit Xtest2/Xtest3')
    eq(true, api.nvim_get_option_value('swapfile', {}))
    poke_eventloop()

    eq({ 'Xtest3' }, ls_dir_sorted('Xtest2'))
    eq({ 'Xtest3.swp' }, ls_dir_sorted('Xtest.je'))
  end)
end)
