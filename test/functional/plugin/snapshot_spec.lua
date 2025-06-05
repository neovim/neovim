local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local eq = t.eq
local clear = n.clear
local exec_lua = n.exec_lua
local command = n.command

describe('snapshot.nvim', function()
  before_each(function()
    clear()
    exec_lua("require('vim.snapshot')")
  end)

  it('captures open and save snapshots', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'foo', 'bar'})
      require('vim.snapshot').capture_open_snapshot(0)
    ]])

    local snap = exec_lua("return require('vim.snapshot').get_snapshot(0, 'open')")
    eq({ 'foo', 'bar' }, snap)

    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'foo', 'baz'})
      require('vim.snapshot').capture_save_snapshot(0)
    ]])

    local save_snap = exec_lua("return require('vim.snapshot').get_snapshot(0, 'save')")
    eq({ 'foo', 'baz' }, save_snap)
  end)

  it('computes diff against on open snapshot', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'a', 'b', 'c'})
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 1, 2, false, {'B'})
    ]])

    local diff = exec_lua([[
      local snap = require('vim.snapshot')
      local result = snap.get_diff({ bufnr = 0, against = 'open' })
      return result.diff
    ]])
    eq({
      { type = 'same', left = 'a', right = 'a' },
      { type = 'remove', left = 'b', right = '' },
      { type = 'add', left = '', right = 'B' },
      { type = 'same', left = 'c', right = 'c' },
    }, diff)

    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 1, 2, false, {})
      vim.api.nvim_buf_set_lines(0, 1, 1, false, {'b'})
    ]])

    local diff_notmod = exec_lua([[
      local snap = require('vim.snapshot')
      local result = snap.get_diff({ bufnr = 0, against = 'open' })
      return result.diff
    ]])
    eq({
      { type = 'same', left = 'a', right = 'a' },
      { type = 'same', left = 'b', right = 'b' },
      { type = 'same', left = 'c', right = 'c' },
    }, diff_notmod)

    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'a', 'b', 'c'})
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 1, 2, false, {'b    '})
    ]])

    local diff = exec_lua([[
      local snap = require('vim.snapshot')
      local result = snap.get_diff({ bufnr = 0, against = 'open' })
      return result.diff
    ]])
    eq({
      { type = 'same', left = 'a', right = 'a' },
      { type = 'remove', left = 'b', right = '' },
      { type = 'add', left = '', right = 'b    ' },
      { type = 'same', left = 'c', right = 'c' },
    }, diff)

  end)

  it('computes diff against save snapshot', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'foo', 'bar'})
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'foo', 'baz'})
      require('vim.snapshot').capture_save_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'foo', 'qux'})
    ]])

    local diff = exec_lua([[
      local snap = require('vim.snapshot')
      local result = snap.get_diff({ bufnr = 0, against = 'save' })
      return result.diff
    ]])
    eq({
      { type = 'same', left = 'foo', right = 'foo' },
      { type = 'remove', left = 'baz', right = '' },
      { type = 'add', left = '', right = 'qux' },
    }, diff)
  end)

  it('handles unicode and multibyte characters', function()
    command('enew')
    exec_lua([[
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {'α', 'β', 'γ'})
        require('vim.snapshot').capture_open_snapshot(0)
        vim.api.nvim_buf_set_lines(0, 1, 2, false, {'δ'})
    ]])
    local diff = exec_lua([[
        local snap = require('vim.snapshot')
        local result = snap.get_diff({ bufnr = 0, against = 'open' })
        return result.diff
    ]])
    eq({
      { type = 'same', left = 'α', right = 'α' },
      { type = 'remove', left = 'β', right = '' },
      { type = 'add', left = '', right = 'δ' },
      { type = 'same', left = 'γ', right = 'γ' },
    }, diff)
  end)

  it('restores snapshot correctly when content differs against on open snapshot', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'one', 'two'})
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'changed'})
      require('vim.snapshot').restore_snapshot(0, 'open')
    ]])

    local lines = exec_lua('return vim.api.nvim_buf_get_lines(0, 0, -1, false)')
    eq({ 'one', 'two' }, lines)
  end)

  it('restores snapshot correctly when content differs against save snapshot', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'one', 'two'})
      require('vim.snapshot').capture_save_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'changed'})
      require('vim.snapshot').restore_snapshot(0, 'save')
    ]])

    local lines = exec_lua('return vim.api.nvim_buf_get_lines(0, 0, -1, false)')
    eq({ 'one', 'two' }, lines)
  end)

  it('restores notifies correctly when buffer contents are identical against on open snapshot', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'identical', 'lines'})
      require('vim.snapshot').capture_open_snapshot(0)
    ]])

    local notify_msg = exec_lua([[
      local _errmsg
      local _notify = vim.notify
      vim.notify = function(m, ...)
        _errmsg = m
        return _notify(m, ...)
      end
      require('vim.snapshot').restore_snapshot(0, 'open')
      vim.notify = _notify
      return _errmsg
    ]])
    eq(
      string.format('Snapshot %s identical — restore skipped in buffer %d', 'open', 0),
      notify_msg
    )
  end)

  it('restores notifies correctly when buffer contents are identical against save snapshot', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'identical', 'lines'})
      require('vim.snapshot').capture_save_snapshot(0)
    ]])

    local notify_msg = exec_lua([[
      local _errmsg
      local _notify = vim.notify
      vim.notify = function(m, ...)
        _errmsg = m
        return _notify(m, ...)
      end
      require('vim.snapshot').restore_snapshot(0, 'save')
      vim.notify = _notify
      return _errmsg
    ]])
    eq(
      string.format('Snapshot %s identical — restore skipped in buffer %d', 'save', 0),
      notify_msg
    )
  end)

  it('overwrites snapshot when capturing again', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'first', 'version'})
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'second', 'version'})
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'other', 'content'})
      require('vim.snapshot').restore_snapshot(0, 'open')
    ]])

    local lines = exec_lua('return vim.api.nvim_buf_get_lines(0, 0, -1, false)')
    eq({ 'second', 'version' }, lines)
  end)

  it('returns nil and presents error if no on open snapshot is found', function()
    command('enew')
    local result = exec_lua("return require('vim.snapshot').get_snapshot(0, 'open')")
    eq(vim.NIL, result)

    local ok, err = pcall(function()
      exec_lua([[
        require('vim.snapshot').get_diff({ bufnr = 0, against = 'open' })
      ]])
    end)
    assert(not ok)
    assert(string.match(err, "No snapshot found for open in buffer 0"))
  end)

  it('returns nil and presents error if no save snapshot is found', function()
    command('enew')
    local result = exec_lua("return require('vim.snapshot').get_snapshot(0, 'save')")
    eq(vim.NIL, result)

    local ok, err = pcall(function()
      exec_lua([[
        require('vim.snapshot').restore_snapshot(0, 'save')
      ]])
    end)
    assert(not ok)
    assert(string.match(err, "No snapshot found for save in buffer 0"))
  end)

  it('handles empty buffers', function()
    command('enew')
    exec_lua("require('vim.snapshot').capture_open_snapshot(0)")

    local diff = exec_lua([[
      local snap = require('vim.snapshot')
      local result = snap.get_diff({ bufnr = 0, against = 'open' })
      return result.diff
    ]])
    eq({
      { type = 'same', left = '', right = '' },
    }, diff)
  end)

  it('handles snapshots for non-current buffers', function()
    command('enew')
    local bufnr = exec_lua('return vim.api.nvim_create_buf(false, true)')
    exec_lua([[
      vim.api.nvim_buf_set_lines(..., 0, -1, false, {'x', 'y', 'z'})
      require('vim.snapshot').capture_open_snapshot(...)
    ]], bufnr)
    exec_lua([[
      vim.api.nvim_buf_set_lines(..., 1, 2, false, {'Y'})
    ]], bufnr)

    local diff = exec_lua([[
      local snap = require('vim.snapshot')
      local result = snap.get_diff({ bufnr = ..., against = 'open' })
      return result.diff
    ]], bufnr)
    eq({
      { type = 'same', left = 'x', right = 'x' },
      { type = 'remove', left = 'y', right = '' },
      { type = 'add', left = '', right = 'Y' },
      { type = 'same', left = 'z', right = 'z' },
    }, diff)

    exec_lua([[
      require('vim.snapshot').restore_snapshot(..., 'open')
    ]], bufnr)
    local lines = exec_lua('return vim.api.nvim_buf_get_lines(..., 0, -1, false)', bufnr)
    eq({ 'x', 'y', 'z' }, lines)
  end)

  it('renders diff view in a scratch buffer', function()
    command('enew')
    local buf = exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'one', 'two', 'three'})
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 1, 2, false, {'TWO'})
      local result = require('vim.snapshot').get_diff({ bufnr = 0, against = 'open' })
      require('vim.snapshot').render_diff_view(result)
      return vim.api.nvim_get_current_buf()
    ]])

    local _render = exec_lua("return vim.api.nvim_buf_get_lines(..., 0, -1, false)", buf)
    local expected = {
      "   one                                      │ one",
      "-  two                                      │ ",
      "+                                           │ TWO",
      "   three                                    │ three",
    }
    eq(expected, _render)

    local opts = exec_lua([[
      return {
        buftype = vim.bo[...].buftype,
        bufhidden = vim.bo[...].bufhidden,
        swapfile = vim.bo[...].swapfile,
      }
    ]], buf)
    eq({ buftype = 'nofile', bufhidden = 'wipe', swapfile = false }, opts)
  end)

  it('exports correctly formatted diff with header', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "a",
        "b",
        "c"
      })
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "a",
        "c",
        "d"
      })
    ]])

    local output = exec_lua([[
      return require('vim.snapshot').export_diff(0, 'open')
    ]])
    assert(output:match("=== Snapshot Diff ==="))
    assert(output:match("Timestamp:%s+%d%d%d%d%-%d%d%-%d%d"))
    assert(output:match("Buffer:%s+"))
    assert(output:match("a"))
    assert(output:match("- b"))
    assert(output:match("c"))
    assert(output:match("+ d"))
  end)

  it('registers LSP commands', function()
    exec_lua("require('vim.snapshot').register_lsp_commands()")

    local commands = exec_lua("return vim.tbl_keys(vim.lsp.commands)")
    table.sort(commands)
    eq({
      'snapshot.DiffWithOpen',
      'snapshot.DiffWithSave',
      'snapshot.RestoreOpenSnap',
      'snapshot.RestoreSaveSnap',
    }, commands)
  end)

  it('lsp_diff_with paths correctly to get_diff and render_diff_view', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'lsp', 'test'})
      require('vim.snapshot').capture_open_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 1, 2, false, {'changed'})
    ]])

    local ok = exec_lua([[
      local called_render = false
      local snap = require('vim.snapshot')
      local _render = snap.render_diff_view
      snap.render_diff_view = function(result)
        called_render = true
        return _render(result)
      end
      local _handler = snap.lsp_diff_with('open')
      local success, err = pcall(_handler, { bufnr = 0 })
      snap.render_diff_view = _render
      return success and called_render
    ]])
    eq(true, ok)
  end)

  it('lsp_restore_snapshot paths correctly and restores content', function()
    command('enew')
    exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'before'})
      require('vim.snapshot').capture_save_snapshot(0)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {'after'})
      local _handler = require('vim.snapshot').lsp_restore_snapshot('save')
      _handler({ bufnr = 0 })
    ]])

    local lines = exec_lua('return vim.api.nvim_buf_get_lines(0, 0, -1, false)')
    eq({ 'before' }, lines)
  end)
end)
