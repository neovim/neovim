local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local api = n.api
local retry = t.retry
local write_file = t.write_file
local sleep = vim.uv.sleep

local testdir = 'Xtest-autoread'

--- Returns true if the autoread module is watching the given buffer
--- (defaults to the current buffer).
local function is_watching(bufnr)
  return n.exec_lua(function(b)
    return require('nvim.autoread')._is_watching(b or vim.api.nvim_get_current_buf())
  end, bufnr)
end

describe('autoread file watcher', function()
  before_each(function()
    n.mkdir_p(testdir)
    clear({ args = { '--clean' } })
  end)

  after_each(function()
    n.rmdir(testdir)
  end)

  it('watches file opened on startup (nvim foo.txt)', function()
    local path = testdir .. '/test_startup.txt'
    write_file(path, 'startup original\n')

    -- Spawn nvim with the file passed on the command line. This exercises the
    -- boot order: plugins must load before the initial file is read so that
    -- the BufReadPost autocmd is registered in time to attach a watcher.
    clear({ args = { '--clean', path } })

    eq({ 'startup original' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq(true, is_watching())

    -- Modify file externally; watcher should already be active.
    write_file(path, 'startup changed\n')

    retry(nil, 3000, function()
      eq({ 'startup changed' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)

  it('reloads buffer when file changes externally', function()
    local path = testdir .. '/test_reload.txt'
    write_file(path, 'original content\n')

    command('edit ' .. path)
    eq({ 'original content' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq(true, is_watching())

    -- Modify file externally
    write_file(path, 'new content\n')

    -- The watcher + debounce should trigger checktime
    retry(nil, 3000, function()
      eq({ 'new content' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)

  it('does not reload when buffer has unsaved changes (conflict)', function()
    local path = testdir .. '/test_conflict.txt'
    write_file(path, 'original\n')

    command('edit ' .. path)
    eq(true, is_watching())

    -- Make a local change so the buffer is modified
    api.nvim_buf_set_lines(0, 0, -1, true, { 'local change' })
    eq(true, api.nvim_get_option_value('modified', { buf = 0 }))

    -- Modify file externally
    write_file(path, 'external change\n')

    -- Give watcher time to fire; buffer should NOT be reloaded
    -- because it has unsaved changes (autoread only reloads unmodified buffers)
    sleep(200)
    -- Also do a manual checktime to be sure
    command('silent! checktime')
    -- Buffer should still have local changes (autoread doesn't override modified buffers)
    eq({ 'local change' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  it('tracks autoread option changes', function()
    local path = testdir .. '/test_reenable.txt'
    write_file(path, 'original\n')

    command('edit ' .. path)
    eq(true, is_watching())
    command('setlocal noautoread')
    eq(false, is_watching())

    -- Modify externally while noautoread
    write_file(path, 'while disabled\n')
    sleep(200)
    eq({ 'original' }, api.nvim_buf_get_lines(0, 0, -1, true))

    -- Re-enable autoread
    command('setlocal autoread')
    eq(true, is_watching())

    -- Modify again
    write_file(path, 'after reenable\n')

    retry(nil, 3000, function()
      eq({ 'after reenable' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)

  it('stops watcher on bdelete', function()
    local path = testdir .. '/test_bdelete.txt'
    write_file(path, 'content\n')

    command('edit ' .. path)
    local bufnr = api.nvim_get_current_buf()
    eq(true, is_watching(bufnr))

    command('enew')
    command('bdelete ' .. bufnr)
    eq(false, is_watching(bufnr))
  end)

  it('reloads hidden buffer when file changes', function()
    local path = testdir .. '/test_hidden.txt'
    write_file(path, 'original\n')

    command('set hidden')
    command('edit ' .. path)
    local bufnr = api.nvim_get_current_buf()
    eq(true, is_watching(bufnr))

    -- Switch to a different buffer (hides the first one)
    command('enew')
    eq(true, is_watching(bufnr))

    -- Modify file externally
    write_file(path, 'updated hidden\n')

    retry(nil, 3000, function()
      eq({ 'updated hidden' }, api.nvim_buf_get_lines(bufnr, 0, -1, true))
    end)
  end)

  it('handles file deletion gracefully', function()
    local path = testdir .. '/test_delete.txt'
    write_file(path, 'will be deleted\n')

    command('edit ' .. path)
    eq({ 'will be deleted' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq(true, is_watching())

    -- Delete the file
    os.remove(path)

    retry(nil, 3000, function()
      eq(false, is_watching())
    end)
    -- Buffer content should remain unchanged
    eq({ 'will be deleted' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  it('handles rapid changes with debouncing', function()
    local path = testdir .. '/test_debounce.txt'
    write_file(path, 'v1\n')

    command('edit ' .. path)
    eq({ 'v1' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq(true, is_watching())

    -- Make several rapid changes
    write_file(path, 'v2\n')
    write_file(path, 'v3\n')
    write_file(path, 'v4\n')
    write_file(path, 'final\n')

    -- Should eventually settle on final content
    retry(nil, 3000, function()
      eq({ 'final' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)

  it('detects changes after atomic rename (external editor save)', function()
    local path = testdir .. '/test_rename.txt'
    write_file(path, 'original\n')

    command('edit ' .. path)
    eq({ 'original' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq(true, is_watching())

    -- Simulate atomic save: write to temp file, rename over target
    local tmp = path .. '.tmp'
    write_file(tmp, 'after rename\n')
    assert(vim.uv.fs_rename(tmp, path))

    retry(nil, 3000, function()
      eq({ 'after rename' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
    -- Watcher should have been re-established on the new inode.
    eq(true, is_watching())

    -- Verify the watcher still works for subsequent plain writes
    write_file(path, 'second change\n')

    retry(nil, 3000, function()
      eq({ 'second change' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)

  it('auto-reload is undoable', function()
    local path = testdir .. '/test_undo.txt'
    write_file(path, 'original\n')

    command('edit ' .. path)
    eq({ 'original' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq(true, is_watching())

    -- Modify externally
    write_file(path, 'changed externally\n')

    retry(nil, 3000, function()
      eq({ 'changed externally' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)

    -- Undo should restore original content
    command('silent undo')
    eq({ 'original' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)
end)
