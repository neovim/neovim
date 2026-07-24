local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local command = n.command
local eq = t.eq
local api = n.api
local retry = t.retry
local rmdir = n.rmdir
local write_file = t.write_file
local sleep = vim.uv.sleep

--- Returns true if the autoread module is watching the given buffer
--- (defaults to the current buffer).
local function is_watching(bufnr)
  return n.exec_lua(function(b)
    return require('nvim.autoread')._is_watching(b or vim.api.nvim_get_current_buf())
  end, bufnr)
end

--- Returns the autoread watcher mode for the given buffer.
local function watching_mode(bufnr)
  return n.exec_lua(function(b)
    return require('nvim.autoread')._watching_mode(b or vim.api.nvim_get_current_buf())
  end, bufnr)
end

--- Shortens the 'autoread' debounce window so each test doesn't pay the 100ms time-cost.
local function shorten_debounce()
  n.exec_lua([[require('nvim.autoread')._set_debounce(10)]])
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
    shorten_debounce()
  end)

  it('watches file opened on startup (nvim foo.txt)', function()
    local path = t.tmpname()
    write_file(path, 'startup original\n')

    -- Spawn nvim with the file passed on the command line. This exercises the
    -- boot order: plugins must load before the initial file is read so that
    -- the BufReadPost autocmd is registered in time to attach a watcher.
    clear({ args = { '--clean', path } })
    shorten_debounce()

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
    sleep(50)
    -- Also do a manual :checktime to be sure
    command('silent! checktime')
    -- Buffer should still have local changes (autoread doesn't override modified buffers)
    eq({ 'local change' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  it('tracks autoread option changes', function()
    local path = open_watched('original\n')

    command('setlocal noautoread')
    eq(false, is_watching())

    -- Modify externally while 'noautoread'.
    write_file(path, 'while disabled\n')
    sleep(50)
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

  it('shares one directory watcher after the default threshold', function()
    local dir = vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname(false)) .. '/nvim_XXXXXXXXXX')
    finally(function()
      rmdir(dir)
    end)

    local path1 = dir .. '/one.txt'
    local path2 = dir .. '/two.txt'
    local path3 = dir .. '/three.txt'
    write_file(path1, 'one original\n')
    write_file(path2, 'two original\n')
    write_file(path3, 'three original\n')

    command('edit ' .. path1)
    local buf1 = api.nvim_get_current_buf()
    eq('file', watching_mode(buf1))

    command('edit ' .. path2)
    local buf2 = api.nvim_get_current_buf()
    eq('file', watching_mode(buf1))
    eq('file', watching_mode(buf2))

    command('edit ' .. path3)
    local buf3 = api.nvim_get_current_buf()
    eq('dir', watching_mode(buf1))
    eq('dir', watching_mode(buf2))
    eq('dir', watching_mode(buf3))

    write_file(path1, 'one changed\n')
    write_file(path2, 'two changed\n')
    write_file(path3, 'three changed\n')

    retry(nil, 3000, function()
      eq({ 'one changed' }, api.nvim_buf_get_lines(buf1, 0, -1, true))
      eq({ 'two changed' }, api.nvim_buf_get_lines(buf2, 0, -1, true))
      eq({ 'three changed' }, api.nvim_buf_get_lines(buf3, 0, -1, true))
    end)
  end)

  it('can disable shared directory watchers', function()
    n.exec_lua([[vim.g.autoread_watch_dir = false]])

    local dir = vim.uv.fs_mkdtemp(vim.fs.dirname(t.tmpname(false)) .. '/nvim_XXXXXXXXXX')
    finally(function()
      rmdir(dir)
    end)

    local path1 = dir .. '/one.txt'
    local path2 = dir .. '/two.txt'
    local path3 = dir .. '/three.txt'
    write_file(path1, 'one original\n')
    write_file(path2, 'two original\n')
    write_file(path3, 'three original\n')

    command('edit ' .. path1)
    local buf1 = api.nvim_get_current_buf()
    command('edit ' .. path2)
    local buf2 = api.nvim_get_current_buf()
    command('edit ' .. path3)
    local buf3 = api.nvim_get_current_buf()

    eq('file', watching_mode(buf1))
    eq('file', watching_mode(buf2))
    eq('file', watching_mode(buf3))
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

  it('coalesces rapid changes via debouncing', function()
    -- Use a wide debounce window so all write_file calls reliably land inside it.
    n.exec_lua([[require('nvim.autoread')._set_debounce(200)]])

    local path = open_watched('v1\n')

    -- Count buffer reloads triggered by the watcher.
    n.exec_lua([[
      _G.reloads = 0
      vim.api.nvim_create_autocmd('FileChangedShellPost', {
        callback = function() _G.reloads = _G.reloads + 1 end,
      })
    ]])

    -- 4 back-to-back writes well inside one debounce window.
    write_file(path, 'v2\n')
    write_file(path, 'v3\n')
    write_file(path, 'v4\n')
    write_file(path, 'final\n')

    retry(nil, 3000, function()
      eq({ 'final' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)

    -- Debouncing collapses 4 writes into (ideally) 1 reload. But we assert "<=2" bc OS filewatch
    -- events may arrive in multiple batches under CI load => a straggler may arrive after the
    -- debounce window and trigger a second reload.
    -- The buffer already holds "final" (checked above); without debouncing each write would reload.
    sleep(250)
    local reloads = n.exec_lua('return _G.reloads')
    t.ok(reloads >= 1 and reloads <= 2, '1 or 2 reloads (4 writes coalesced)', reloads)
  end)

  it("bumps 'busy' on each watched buffer while a reload is pending", function()
    -- Use a long debounce-window so we can sample 'busy' during pending autoreads.
    n.exec_lua([[require('nvim.autoread')._set_debounce(5000)]])

    local path1 = open_watched('a1\n')
    local buf1 = api.nvim_get_current_buf()
    command('enew')
    local path2 = open_watched('a2\n')
    local buf2 = api.nvim_get_current_buf()

    eq(0, api.nvim_get_option_value('busy', { buf = buf1 }))
    eq(0, api.nvim_get_option_value('busy', { buf = buf2 }))

    -- Trigger external changes on both watched files concurrently.
    write_file(path1, 'b1\n')
    write_file(path2, 'b2\n')

    eq(
      true,
      n.exec_lua(function(b1, b2)
        return vim.wait(2000, function()
          return vim.bo[b1].busy == 1 and vim.bo[b2].busy == 1
        end, 5)
      end, buf1, buf2)
    )

    -- A short debounce + fresh write lets the pending reload complete, clearing 'busy'.
    n.exec_lua([[require('nvim.autoread')._set_debounce(10)]])
    write_file(path1, 'c1\n')
    write_file(path2, 'c2\n')

    -- Confirm busy=0 after the autoread.
    retry(nil, 3000, function()
      eq({ 'c1' }, api.nvim_buf_get_lines(buf1, 0, -1, true))
      eq({ 'c2' }, api.nvim_buf_get_lines(buf2, 0, -1, true))
      eq(0, api.nvim_get_option_value('busy', { buf = buf1 }))
      eq(0, api.nvim_get_option_value('busy', { buf = buf2 }))
    end)
  end)

  it('handles autocmd error during reload', function()
    local path = open_watched('original\n')
    local bufnr = api.nvim_get_current_buf()

    -- Define a broken autocmd.
    n.exec_lua([[
      vim.api.nvim_create_autocmd('FileChangedShellPost', {
        callback = function() error('boom from test autocmd') end,
      })
    ]])

    write_file(path, 'changed\n')

    -- autoread should surface the error, and do its cleanup despite the failed autocmd.
    retry(nil, 3000, function()
      t.matches('autoread:.*boom from test autocmd', n.eval('v:errmsg'))
      eq(0, api.nvim_get_option_value('busy', { buf = bufnr }))
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
