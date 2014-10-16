-- Sanity checks for window_* API calls via msgpack-rpc
local helpers = require('test.functional.helpers')
local clear, nvim, buffer, curbuf, curbuf_contents, window, curwin, eq, neq,
  ok = helpers.clear, helpers.nvim, helpers.buffer, helpers.curbuf,
  helpers.curbuf_contents, helpers.window, helpers.curwin, helpers.eq,
  helpers.neq, helpers.ok

describe('window_* functions', function()
  before_each(clear)

  describe('get_buffer', function()
    it('works', function()
      eq(curbuf(), window('get_buffer', nvim('get_windows')[1]))
      nvim('command', 'new')
      nvim('set_current_window', nvim('get_windows')[2])
      eq(curbuf(), window('get_buffer', nvim('get_windows')[2]))
      neq(window('get_buffer', nvim('get_windows')[1]),
        window('get_buffer', nvim('get_windows')[2]))
    end)
  end)

  describe('{get,set}_cursor', function()
    it('works', function()
      eq({1, 0}, curwin('get_cursor'))
      nvim('command', 'normal ityping\027o  some text')
      eq('typing\n  some text', curbuf_contents())
      eq({2, 10}, curwin('get_cursor'))
      curwin('set_cursor', {2, 6})
      nvim('command', 'normal i dumb')
      eq('typing\n  some dumb text', curbuf_contents())
    end)
  end)

  describe('{get,set}_height', function()
    it('works', function()
      nvim('command', 'vsplit')
      eq(window('get_height', nvim('get_windows')[2]),
        window('get_height', nvim('get_windows')[1]))
      nvim('set_current_window', nvim('get_windows')[2])
      nvim('command', 'split')
      eq(window('get_height', nvim('get_windows')[2]),
        window('get_height', nvim('get_windows')[1]) / 2)
      window('set_height', nvim('get_windows')[2], 2)
      eq(2, window('get_height', nvim('get_windows')[2]))
    end)
  end)

  describe('{get,set}_width', function()
    it('works', function()
      nvim('command', 'split')
      eq(window('get_width', nvim('get_windows')[2]),
        window('get_width', nvim('get_windows')[1]))
      nvim('set_current_window', nvim('get_windows')[2])
      nvim('command', 'vsplit')
      eq(window('get_width', nvim('get_windows')[2]),
        window('get_width', nvim('get_windows')[1]) / 2)
      window('set_width', nvim('get_windows')[2], 2)
      eq(2, window('get_width', nvim('get_windows')[2]))
    end)
  end)

  describe('{get,set}_var', function()
    it('works', function()
      curwin('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, curwin('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 'w:lua'))
    end)
  end)

  describe('{get,set}_option', function()
    it('works', function()
      curwin('set_option', 'colorcolumn', '4,3')
      eq('4,3', curwin('get_option', 'colorcolumn'))
      -- global-local option
      curwin('set_option', 'statusline', 'window-status')
      eq('window-status', curwin('get_option', 'statusline'))
      eq('', nvim('get_option', 'statusline'))
    end)
  end)

  describe('get_position', function()
    it('works', function()
      local height = window('get_height', nvim('get_windows')[1])
      local width = window('get_width', nvim('get_windows')[1])
      nvim('command', 'split')
      nvim('command', 'vsplit')
      eq({0, 0}, window('get_position', nvim('get_windows')[1]))
      local vsplit_pos = math.floor(width / 2)
      local split_pos = math.floor(height / 2)
      local win2row, win2col =
        unpack(window('get_position', nvim('get_windows')[2]))
      local win3row, win3col =
        unpack(window('get_position', nvim('get_windows')[3]))
      eq(0, win2row)
      eq(0, win3col)
      ok(vsplit_pos - 1 <= win2col and win2col <= vsplit_pos + 1)
      ok(split_pos - 1 <= win3row and win3row <= split_pos + 1)
    end)
  end)

  describe('get_position', function()
    it('works', function()
      nvim('command', 'tabnew')
      nvim('command', 'vsplit')
      eq(window('get_tabpage',
        nvim('get_windows')[1]), nvim('get_tabpages')[1])
      eq(window('get_tabpage',
        nvim('get_windows')[2]), nvim('get_tabpages')[2])
      eq(window('get_tabpage',
        nvim('get_windows')[3]), nvim('get_tabpages')[2])
    end)
  end)

  describe('is_valid', function()
    it('works', function()
      nvim('command', 'split')
      local win = nvim('get_windows')[2]
      nvim('set_current_window', win)
      ok(window('is_valid', win))
      nvim('command', 'close')
      ok(not window('is_valid', win))
    end)
  end)
end)
