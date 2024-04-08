local t = require('test.functional.testutil')(after_each)
local clear, eq, neq = t.clear, t.eq, t.neq
local command, api, fn = t.command, t.api, t.fn
local tbl_deep_extend = vim.tbl_deep_extend

-- Set up two overlapping floating windows
local setup_floating_windows = function()
  local base_opts = {
    relative = 'editor',
    height = 1,
    width = 2,
    anchor = 'NW',
    style = 'minimal',
    border = 'none',
  }

  local bufnr_1 = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(bufnr_1, 0, -1, true, { 'aa' })
  local opts_1 = tbl_deep_extend('force', { row = 0, col = 0, zindex = 11 }, base_opts)
  api.nvim_open_win(bufnr_1, false, opts_1)

  local bufnr_2 = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(bufnr_2, 0, -1, true, { 'bb' })
  local opts_2 = tbl_deep_extend('force', { row = 0, col = 1, zindex = 10 }, base_opts)
  api.nvim_open_win(bufnr_2, false, opts_2)

  command('redraw')
end

describe('screenchar() and family respect floating windows', function()
  before_each(function()
    clear()
    -- These commands result into visible text `aabc`.
    -- `aab` - from floating windows, `c` - from text in regular window.
    api.nvim_buf_set_lines(0, 0, -1, true, { 'cccc' })
    setup_floating_windows()
  end)

  it('screenattr()', function()
    local attr_1 = fn.screenattr(1, 1)
    local attr_2 = fn.screenattr(1, 2)
    local attr_3 = fn.screenattr(1, 3)
    local attr_4 = fn.screenattr(1, 4)
    eq(attr_1, attr_2)
    eq(attr_1, attr_3)
    neq(attr_1, attr_4)
  end)

  it('screenchar()', function()
    eq(97, fn.screenchar(1, 1))
    eq(97, fn.screenchar(1, 2))
    eq(98, fn.screenchar(1, 3))
    eq(99, fn.screenchar(1, 4))
  end)

  it('screenchars()', function()
    eq({ 97 }, fn.screenchars(1, 1))
    eq({ 97 }, fn.screenchars(1, 2))
    eq({ 98 }, fn.screenchars(1, 3))
    eq({ 99 }, fn.screenchars(1, 4))
  end)

  it('screenstring()', function()
    eq('a', fn.screenstring(1, 1))
    eq('a', fn.screenstring(1, 2))
    eq('b', fn.screenstring(1, 3))
    eq('c', fn.screenstring(1, 4))
  end)
end)
