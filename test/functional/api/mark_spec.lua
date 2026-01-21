local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, api, command = n.clear, n.api, n.command
local eq, matches, pcall_err = t.eq, t.matches, t.pcall_err
local fn, feed = n.fn, n.feed

describe('api/mark', function()
  before_each(clear)

  describe('nvim_mark_set', function()
    before_each(function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
    end)

    it('sets window-local marks in current window', function()
      eq(true, api.nvim_mark_set("'", 2, 5, {}))
      eq({ lnum = 2, col = 5 }, api.nvim_mark_get("'", {}))
    end)

    it('sets window-local marks in specified window', function()
      local win = api.nvim_get_current_win()
      command('new')
      eq(true, api.nvim_mark_set("'", 3, 1, { win = win }))
      eq({ lnum = 3, col = 1 }, api.nvim_mark_get("'", { win = win }))
    end)

    it('deletes window-local marks with row=0', function()
      command("mark '")
      eq(true, api.nvim_mark_set("'", 0, 0, {}))
      matches('Mark not set', pcall_err(api.nvim_mark_get, "'", {}))
    end)

    it('sets global marks', function()
      eq(true, api.nvim_mark_set('A', 3, 2, {}))
      local mark = api.nvim_mark_get('A', {})
      eq(3, mark.lnum)
      eq(2, mark.col)
    end)

    it('sets numbered global marks', function()
      eq(true, api.nvim_mark_set('0', 2, 1, {}))
      local mark = api.nvim_mark_get('0', {})
      eq(2, mark.lnum)
      eq(1, mark.col)
    end)

    it('sets buffer-local marks', function()
      eq(true, api.nvim_mark_set('a', 2, 4, {}))
      eq({ lnum = 2, col = 4 }, api.nvim_mark_get('a', {}))
    end)

    it('sets buffer-local marks in specified buffer', function()
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, 0, -1, true, { 'line1', 'line2' })
      eq(true, api.nvim_mark_set('z', 2, 1, { buf = buf }))
      eq({ lnum = 2, col = 1 }, api.nvim_mark_get('z', { buf = buf }))
    end)

    it('sets special buffer marks', function()
      eq(true, api.nvim_mark_set('"', 3, 0, {}))
      eq({ lnum = 3, col = 0 }, api.nvim_mark_get('"', {}))

      eq(true, api.nvim_mark_set('[', 1, 0, {}))
      eq({ lnum = 1, col = 0 }, api.nvim_mark_get('[', {}))

      eq(true, api.nvim_mark_set(']', 2, 0, {}))
      eq({ lnum = 2, col = 0 }, api.nvim_mark_get(']', {}))
    end)

    it('sets visual marks', function()
      eq(true, api.nvim_mark_set('<', 1, 2, {}))
      eq(true, api.nvim_mark_set('>', 3, 4, {}))
      eq({ lnum = 1, col = 2 }, api.nvim_mark_get('<', {}))
      eq({ lnum = 3, col = 4 }, api.nvim_mark_get('>', {}))
    end)

    it('visual marks work with gv command', function()
      api.nvim_mark_set('<', 2, 0, {})
      api.nvim_mark_set('>', 3, 0, {})
      command('normal! gv')
      eq('v', fn.mode())
    end)

    it('fails when using buf option for window-local marks', function()
      eq(
        "cannot use 'buf' for window-local marks",
        pcall_err(api.nvim_mark_set, "'", 1, 0, { buf = 0 })
      )
    end)

    it('fails when using buf or win option for global marks', function()
      local msg = "cannot use 'buf' or 'win' for global marks"
      eq(msg, pcall_err(api.nvim_mark_set, 'A', 1, 0, { buf = 0 }))
      eq(msg, pcall_err(api.nvim_mark_set, 'A', 1, 0, { win = 0 }))
    end)

    it('fails when using win option for buffer-local marks', function()
      eq(false, pcall(api.nvim_mark_set, 'a', 1, 0, { win = 0 }))
    end)

    it('fails for read-only marks', function()
      local msg = 'cannot be set manually'
      matches(msg, pcall_err(api.nvim_mark_set, '^', 1, 0, {}))
      matches(msg, pcall_err(api.nvim_mark_set, '.', 1, 0, {}))
      matches(msg, pcall_err(api.nvim_mark_set, ':', 1, 0, {}))
    end)

    it('fails with invalid mark names', function()
      eq(false, pcall(api.nvim_mark_set, '!', 1, 0, {}))
      eq(false, pcall(api.nvim_mark_set, 'fail', 1, 0, {}))
    end)

    it('fails with invalid buffer or window', function()
      eq('Invalid buffer id: 999', pcall_err(api.nvim_mark_set, 'a', 1, 0, { buf = 999 }))
      eq('Invalid window id: 999', pcall_err(api.nvim_mark_set, "'", 1, 0, { win = 999 }))
    end)
  end)

  describe('nvim_mark_get', function()
    it('gets window-local marks from current window', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      api.nvim_mark_set("'", 2, 3, {})
      eq({ lnum = 2, col = 3 }, api.nvim_mark_get("'", {}))
    end)

    it('gets window-local marks from specified window', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      local win = api.nvim_get_current_win()
      api.nvim_mark_set("'", 2, 3, { win = win })
      command('new')
      api.nvim_buf_set_lines(0, 0, -1, true, { 'other1', 'other2' })
      eq({ lnum = 2, col = 3 }, api.nvim_mark_get("'", { win = win }))
    end)

    it('fails when using buf option for window-local marks', function()
      eq(false, pcall(api.nvim_mark_get, "'", { buf = 0 }))
    end)

    it('gets global marks', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      api.nvim_buf_set_name(0, 'mark_test')
      local buf = api.nvim_get_current_buf()
      command('2mark A')
      local mark = api.nvim_mark_get('A', {})
      eq({ buf, 2, 0 }, { mark.buf, mark.lnum, mark.col })
      matches('mark_test$', mark.file)
    end)

    it('fails when using buf or win option for global marks', function()
      eq(false, pcall(api.nvim_mark_get, 'A', { buf = 0 }))
      eq(false, pcall(api.nvim_mark_get, 'A', { win = 0 }))
    end)

    it('gets buffer-local marks from current buffer', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      command('3mark a')
      local mark = api.nvim_mark_get('a', {})
      eq(3, mark.lnum)
      eq(0, mark.col)
    end)

    it('gets buffer-local marks from specified buffer', function()
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, 0, -1, true, { 'line1', 'line2' })
      api.nvim_mark_set('z', 2, 1, { buf = buf })
      eq({ lnum = 2, col = 1 }, api.nvim_mark_get('z', { buf = buf }))
    end)

    it('fails when using win option for buffer-local marks', function()
      eq(false, pcall(api.nvim_mark_get, 'a', { win = 0 }))
    end)

    it('returns empty array for unset marks', function()
      matches('Mark not set', pcall_err(api.nvim_mark_get, 'z', {}))
    end)

    it('fails with invalid mark names', function()
      eq(false, pcall(api.nvim_mark_get, '!', {}))
      eq(false, pcall(api.nvim_mark_get, 'fail', {}))
    end)

    it('gets special buffer marks', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      api.nvim_win_set_cursor(0, { 2, 3 })
      command('enew')
      command('bp')
      local mark = api.nvim_mark_get('"', {})
      eq(2, mark.lnum)
    end)

    it('gets visual marks', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3', 'line4' })
      feed('ggVj<Esc>')
      eq(1, api.nvim_mark_get('<', {}).lnum)
      eq(2, api.nvim_mark_get('>', {}).lnum)
    end)
  end)

  describe('nvim_mark_del', function()
    it('fails to delete window-local marks', function()
      local msg = 'cannot be deleted'
      matches(msg, pcall_err(api.nvim_mark_del, "'", {}))
      matches(msg, pcall_err(api.nvim_mark_del, '`', {}))
    end)

    it('fails to delete : mark', function()
      matches('cannot be deleted', pcall_err(api.nvim_mark_del, ':', {}))
    end)

    it('deletes global marks', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      command('2mark A')
      eq(true, api.nvim_mark_del('A', {}))
      matches('Mark not set', pcall_err(api.nvim_mark_get, 'A', {}))
    end)

    it('deletes numbered global marks', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2' })
      api.nvim_mark_set('0', 1, 1, {})
      eq(true, api.nvim_mark_del('0', {}))
      matches('Mark not set', pcall_err(api.nvim_mark_get, '0', {}))
    end)

    it('returns false for unset global marks', function()
      eq(false, api.nvim_mark_del('Z', {}))
    end)

    it('fails when using buf or win option for global marks', function()
      eq(false, pcall(api.nvim_mark_del, 'A', { buf = 0 }))
      eq(false, pcall(api.nvim_mark_del, 'A', { win = 0 }))
    end)

    it('deletes buffer-local marks', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      command('2mark a')
      eq(true, api.nvim_mark_del('a', {}))
      matches('Mark not set', pcall_err(api.nvim_mark_get, 'a', {}))
    end)

    it('deletes buffer-local marks in specified buffer', function()
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, 0, -1, true, { 'line1', 'line2' })
      api.nvim_mark_set('z', 2, 0, { buf = buf })
      eq(true, api.nvim_mark_del('z', { buf = buf }))
      matches('Mark not set', pcall_err(api.nvim_mark_get, 'z', { buf = buf }))
    end)

    it('returns false for unset buffer-local marks', function()
      eq(false, api.nvim_mark_del('b', {}))
    end)

    it('deletes special buffer marks', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      api.nvim_mark_set('"', 2, 0, {})
      eq(true, api.nvim_mark_del('"', {}))
      command('2mark [')
      eq(true, api.nvim_mark_del('[', {}))
      command('normal! ia') -- ^ mark
      eq(true, api.nvim_mark_del('^', {}))
    end)

    it('deletes visual marks', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2', 'line3' })
      feed('ggVG<Esc>')
      eq(true, api.nvim_mark_del('<', {}))
      eq(true, api.nvim_mark_del('>', {}))
      matches('Mark not set', pcall_err(api.nvim_mark_get, '<', {}))
      matches('Mark not set', pcall_err(api.nvim_mark_get, '>', {}))
    end)

    it('fails when using win option for buffer-local marks', function()
      eq(false, pcall(api.nvim_mark_del, 'a', { win = 0 }))
    end)

    it('fails for motion marks', function()
      local msg = 'cannot be deleted'
      matches(msg, pcall_err(api.nvim_mark_del, '{', {}))
      matches(msg, pcall_err(api.nvim_mark_del, '}', {}))
    end)

    it('fails with invalid mark names', function()
      matches('Invalid mark name', pcall_err(api.nvim_mark_del, '!', {}))
    end)

    it('fails with invalid buffer', function()
      eq(false, pcall(api.nvim_mark_del, 'a', { buf = 999 }))
    end)

    it('returns false when deleting already deleted mark', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'line1', 'line2' })
      command('mark c')
      eq(true, api.nvim_mark_del('c', {}))
      eq(false, api.nvim_mark_del('c', {}))
    end)
  end)
end)
