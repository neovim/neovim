local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local fn = n.fn

local pathsep = n.get_pathsep()
local testdir_left = 'Xtest-difftool-left'
local testdir_right = 'Xtest-difftool-right'

setup(function()
  n.mkdir_p(testdir_left)
  n.mkdir_p(testdir_right)
  t.write_file(testdir_left .. pathsep .. 'file1.txt', 'hello')
  t.write_file(testdir_left .. pathsep .. 'file2.txt', 'foo')
  t.write_file(testdir_right .. pathsep .. 'file1.txt', 'hello world') -- modified
  t.write_file(testdir_right .. pathsep .. 'file3.txt', 'bar') -- added
end)

teardown(function()
  n.rmdir(testdir_left)
  n.rmdir(testdir_right)
end)

describe('nvim.difftool', function()
  before_each(function()
    clear()
    command('packadd nvim.difftool')
  end)

  it('shows added, modified, and deleted files in quickfix', function()
    command(('DiffTool %s %s'):format(testdir_left, testdir_right))
    local qflist = fn.getqflist()
    local entries = {}
    for _, item in ipairs(qflist) do
      table.insert(entries, { text = item.text, rel = item.user_data and item.user_data.rel })
    end

    -- Should show:
    -- file1.txt as modified (M)
    -- file2.txt as deleted (D)
    -- file3.txt as added (A)
    eq({
      { text = 'M', rel = 'file1.txt' },
      { text = 'D', rel = 'file2.txt' },
      { text = 'A', rel = 'file3.txt' },
    }, entries)
  end)

  it('has autocmds when diff window is opened', function()
    command(('DiffTool %s %s'):format(testdir_left, testdir_right))
    local autocmds = fn.nvim_get_autocmds({ group = 'nvim.difftool.events' })
    assert(#autocmds > 0)
  end)

  it('cleans up autocmds when diff window is closed', function()
    command(('DiffTool %s %s'):format(testdir_left, testdir_right))
    command('q')
    local ok = pcall(fn.nvim_get_autocmds, { group = 'nvim.difftool.events' })
    eq(false, ok)
  end)
end)
