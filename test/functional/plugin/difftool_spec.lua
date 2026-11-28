local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, setup, teardown, finally =
  t.describe, t.it, t.before_each, t.setup, t.teardown, t.finally
local clear = n.clear
local command = n.command
local eq = t.eq
local eq_partial = t.eq_partial
local fn = n.fn

local testdir_left = 'Xtest-difftool-left'
local testdir_right = 'Xtest-difftool-right'

setup(function()
  n.mkdir_p(testdir_left)
  n.mkdir_p(testdir_right)
  t.write_file(vim.fs.joinpath(testdir_left, 'file1.txt'), 'hello')
  t.write_file(vim.fs.joinpath(testdir_left, 'file2.txt'), 'foo')
  t.write_file(vim.fs.joinpath(testdir_left, 'file4 with space.txt'), 'hello')
  t.write_file(vim.fs.joinpath(testdir_right, 'file1.txt'), 'hello world') -- modified
  t.write_file(vim.fs.joinpath(testdir_right, 'file3.txt'), 'bar') -- added
  t.write_file(vim.fs.joinpath(testdir_right, 'file4 with space.txt'), 'hello world') -- modified
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

    -- Should show:
    -- file1.txt as modified (M)
    -- file2.txt as deleted (D)
    -- file3.txt as added (A)
    -- file4 with space.txt as modified (M)
    eq_partial({
      { text = 'M', user_data = { rel = 'file1.txt' } },
      { text = 'D', user_data = { rel = 'file2.txt' } },
      { text = 'A', user_data = { rel = 'file3.txt' } },
      { text = 'M', user_data = { rel = 'file4 with space.txt' } },
    }, fn.getqflist())
  end)

  it('has consistent split layout', function()
    command('set nosplitright')
    command(('DiffTool %s %s'):format(testdir_left, testdir_right))
    local wins = fn.getwininfo()
    local left_win_col = wins[1].wincol
    local right_win_col = wins[2].wincol
    assert(
      left_win_col < right_win_col,
      'Left window should be to the left of right window even with nosplitright set'
    )
  end)

  it('handles symlinks', function()
    -- Create a symlink in right dir pointing to file2.txt in left dir
    local symlink_path = vim.fs.joinpath(testdir_right, 'file2.txt')
    local target_path = vim.fs.joinpath('..', testdir_left, 'file2.txt')
    assert(vim.uv.fs_symlink(target_path, symlink_path) == true)
    finally(function()
      os.remove(symlink_path)
    end)
    assert(fn.getftype(symlink_path) == 'link')

    -- Run difftool
    command(('DiffTool %s %s'):format(testdir_left, testdir_right))

    -- file2.txt should not be reported as added or deleted anymore
    eq_partial({
      { text = 'M', user_data = { rel = 'file1.txt' } },
      { text = 'A', user_data = { rel = 'file3.txt' } },
      { text = 'M', user_data = { rel = 'file4 with space.txt' } },
    }, fn.getqflist())
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

  it('does not reset quickfix list when closing quickfix window', function()
    command(('DiffTool %s %s'):format(testdir_left, testdir_right))
    local qflist_before = fn.getqflist()
    assert(#qflist_before > 0, 'quickfix list should not be empty')

    -- Close the quickfix window
    command('cclose')

    -- Quickfix list should still be intact
    local qflist_after = fn.getqflist()
    eq(#qflist_before, #qflist_after)

    -- Autocmds should still be active
    local autocmds = fn.nvim_get_autocmds({ group = 'nvim.difftool.events' })
    assert(#autocmds > 0, 'autocmds should still exist after closing quickfix window')
  end)

  it('opens difftool automatically when started with nvim -d', function()
    -- Start Neovim with -d flag for directory diff
    clear({
      args = {
        '--cmd',
        'packadd nvim.difftool',
        '-d',
        testdir_left,
        testdir_right,
      },
    })

    -- Wait for difftool to open
    n.poke_eventloop()

    -- Verify we have 3 windows (left, right, and quickfix)
    eq(3, #fn.getwininfo())

    -- Verify quickfix list has the expected entries
    eq_partial({
      { text = 'M', user_data = { rel = 'file1.txt' } },
      { text = 'D', user_data = { rel = 'file2.txt' } },
      { text = 'A', user_data = { rel = 'file3.txt' } },
      { text = 'M', user_data = { rel = 'file4 with space.txt' } },
    }, fn.getqflist())
  end)

  it('shows a read-only unified diff', function()
    local left = vim.fs.joinpath(testdir_left, 'file1.txt')
    local right = vim.fs.joinpath(testdir_right, 'file1.txt')
    n.exec_lua(function(l, r)
      require('difftool').open(l, r, { layout = 'unified' })
    end, left, right)

    eq(1, #fn.getwininfo())
    eq('diff', fn.getbufvar(fn.bufnr(), '&filetype'))
    eq({
      '--- ' .. left,
      '+++ ' .. right,
      '@@ -1 +1 @@',
      '-hello',
      '\\ No newline at end of file',
      '+hello world',
      '\\ No newline at end of file',
    }, n.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('shows a unified diff for each quickfix entry', function()
    n.exec_lua(function(l, r)
      require('difftool').open(l, r, { layout = 'unified', method = 'builtin' })
    end, testdir_left, testdir_right)

    --- Hunk lines, below the `---`/`+++` headers
    local function hunk()
      return n.api.nvim_buf_get_lines(0, 2, -1, false)
    end

    -- Diff window plus quickfix window, and the files themselves are never opened
    eq(2, #fn.getwininfo())
    eq(0, fn.bufexists(vim.fs.joinpath(testdir_right, 'file1.txt')))

    -- file4 with space.txt is modified
    eq_partial({ text = 'M', user_data = { rel = 'file4 with space.txt' } }, fn.getqflist()[4])
    eq({
      '@@ -1 +1 @@',
      '-hello',
      '\\ No newline at end of file',
      '+hello world',
      '\\ No newline at end of file',
    }, hunk())

    -- file2.txt only exists on the left, so all of it is deleted
    command('cnext')
    eq({ '@@ -1 +0,0 @@', '-foo', '\\ No newline at end of file' }, hunk())

    -- Jumping from the quickfix window reuses the diff window
    fn.win_gotoid(fn.getqflist({ winid = 1 }).winid)
    command('cc 1')
    eq(2, #fn.getwininfo())
    eq('difftool://file1.txt', fn.bufname())

    -- Reopening while the diff is displayed shows the current diff, not the stale buffer
    t.write_file(vim.fs.joinpath(testdir_right, 'file1.txt'), 'changed')
    finally(function()
      t.write_file(vim.fs.joinpath(testdir_right, 'file1.txt'), 'hello world')
    end)
    n.exec_lua(function(l, r)
      require('difftool').open(l, r, { layout = 'unified', method = 'builtin' })
    end, testdir_left, testdir_right)
    eq(true, vim.list_contains(hunk(), '+changed'))

    -- Writing is rejected, so no file is created for the URI
    t.matches('E45', t.pcall_err(command, 'write'))

    -- `:q` closes the quickfix window too and exits
    n.expect_exit(1000, command, 'q')
  end)
end)
