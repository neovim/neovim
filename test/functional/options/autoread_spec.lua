local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local api = n.api
local retry = t.retry
local write_file = t.write_file
local sleep = vim.uv.sleep

--- Returns true if the autoread module is watching the given buffer
--- (defaults to the current buffer).
local function is_watching(bufnr)
  return n.exec_lua(function(b)
    return require('nvim.autoread')._is_watching(b or vim.api.nvim_get_current_buf())
  end, bufnr)
end

--- Edits a fresh tempfile with the given initial content and asserts the watcher attached.
--- Returns the file path.
local function open_watched(content)
  local path = t.tmpname()
  write_file(path, content)
  command('edit ' .. path)
  eq(true, is_watching())
  return path
end

describe('autoread file watcher', function()
  before_each(function()
    clear({ args = { '--clean' } })
  end)

  it('watches file opened on startup (nvim foo.txt)', function()
    local path = t.tmpname()
    write_file(path, 'startup original\n')

    -- Spawn nvim with the file passed on the command line. This exercises the
    -- boot order: plugins must load before the initial file is read so that
    -- the BufReadPost autocmd is registered in time to attach a watcher.
    clear({ args = { '--clean', path } })

    eq({ 'startup original' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq(true, is_watching())

    write_file(path, 'startup changed\n')
    retry(nil, 3000, function()
      eq({ 'startup changed' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)

  it('reloads on external change; survives hide; undoable; bdelete stops watch', function()
    local path = open_watched('original content\n')
    local bufnr = api.nvim_get_current_buf()

    -- 1. Plain external change reloads the visible buffer.
    write_file(path, 'new content\n')
    retry(nil, 3000, function()
      eq({ 'new content' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)

    -- 2. Hide the buffer; watcher stays attached and still reloads.
    command('set hidden')
    command('enew')
    eq(true, is_watching(bufnr))
    write_file(path, 'while hidden\n')
    retry(nil, 3000, function()
      eq({ 'while hidden' }, api.nvim_buf_get_lines(bufnr, 0, -1, true))
    end)

    -- 3. The reload is undoable. Done last so the resulting modified state
    -- (buffer ≠ disk) doesn't block earlier auto-reload assertions.
    command('buffer ' .. bufnr)
    command('silent undo')
    eq({ 'new content' }, api.nvim_buf_get_lines(0, 0, -1, true))

    -- 4. bdelete stops the watcher.
    command('enew!')
    command('bdelete! ' .. bufnr)
    eq(false, is_watching(bufnr))
  end)

  it('does not reload when buffer has unsaved changes (conflict)', function()
    local path = open_watched('original\n')

    api.nvim_buf_set_lines(0, 0, -1, true, { 'local change' })
    eq(true, api.nvim_get_option_value('modified', { buf = 0 }))

    write_file(path, 'external change\n')

    -- Give the watcher time to fire; the buffer must NOT be reloaded because
    -- it has unsaved changes (autoread only reloads unmodified buffers).
    sleep(200)
    -- Also do a manual checktime to be sure
    command('silent! checktime')
    -- Buffer should still have local changes (autoread doesn't override modified buffers)
    eq({ 'local change' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  it('tracks autoread option changes', function()
    local path = open_watched('original\n')

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

  it('handles file deletion gracefully', function()
    local path = open_watched('will be deleted\n')

    os.remove(path)

    retry(nil, 3000, function()
      eq(false, is_watching())
    end)
    -- Buffer content remains unchanged.
    eq({ 'will be deleted' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  -- TODO: revisit this test
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
    local path = open_watched('original\n')

    -- Atomic save: write to temp file, rename over target.
    local tmp = path .. '.tmp'
    write_file(tmp, 'after rename\n')
    assert(vim.uv.fs_rename(tmp, path))

    retry(nil, 3000, function()
      eq({ 'after rename' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
    -- Watcher re-established on the new inode.
    eq(true, is_watching())

    -- Subsequent plain writes still reload.
    write_file(path, 'second change\n')
    retry(nil, 3000, function()
      eq({ 'second change' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)
end)
