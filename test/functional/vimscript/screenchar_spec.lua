local helpers = require('test.functional.helpers')(after_each)
local clear, eq, neq = helpers.clear, helpers.eq, helpers.neq
local command, meths, funcs = helpers.command, helpers.meths, helpers.funcs
local tbl_deep_extend = helpers.tbl_deep_extend

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

  local bufnr_1 = meths.create_buf(false, true)
  meths.buf_set_lines(bufnr_1, 0, -1, true, { 'aa' })
  local opts_1 = tbl_deep_extend('force', { row = 0, col = 0, zindex = 11 }, base_opts)
  meths.open_win(bufnr_1, false, opts_1)

  local bufnr_2 = meths.create_buf(false, true)
  meths.buf_set_lines(bufnr_2, 0, -1, true, { 'bb' })
  local opts_2 = tbl_deep_extend('force', { row = 0, col = 1, zindex = 10 }, base_opts)
  meths.open_win(bufnr_2, false, opts_2)

  command('redraw')
end

describe('screenchar() and family respect floating windows', function()
  before_each(function()
    clear()
    -- These commands result into visible text `aabc`.
    -- `aab` - from floating windows, `c` - from text in regular window.
    meths.buf_set_lines(0, 0, -1, true, { 'cccc' })
    setup_floating_windows()
  end)

  it('screenattr()', function()
    local attr_1 = funcs.screenattr(1, 1)
    local attr_2 = funcs.screenattr(1, 2)
    local attr_3 = funcs.screenattr(1, 3)
    local attr_4 = funcs.screenattr(1, 4)
    eq(attr_1, attr_2)
    eq(attr_1, attr_3)
    neq(attr_1, attr_4)
  end)

  it('screenchar()', function()
    eq(97, funcs.screenchar(1, 1))
    eq(97, funcs.screenchar(1, 2))
    eq(98, funcs.screenchar(1, 3))
    eq(99, funcs.screenchar(1, 4))
  end)

  it('screenchars()', function()
    eq({ 97 }, funcs.screenchars(1, 1))
    eq({ 97 }, funcs.screenchars(1, 2))
    eq({ 98 }, funcs.screenchars(1, 3))
    eq({ 99 }, funcs.screenchars(1, 4))
  end)

  it('screenstring()', function()
    eq('a', funcs.screenstring(1, 1))
    eq('a', funcs.screenstring(1, 2))
    eq('b', funcs.screenstring(1, 3))
    eq('c', funcs.screenstring(1, 4))
  end)
end)
