local helpers = require('test.functional.helpers')(after_each)
local clear, eq, meths = helpers.clear, helpers.eq, helpers.meths
local command, funcs = helpers.command, helpers.funcs

before_each(clear)

describe('screenpos() function', function()
  it('works in floating window with border', function()
    local bufnr = meths.create_buf(false, true)
    local opts = {
      relative='editor',
      height=8,
      width=12,
      row=6,
      col=8,
      anchor='NW',
      style='minimal',
      border='none',
      focusable=1
    }
    local float = meths.open_win(bufnr, false, opts)
    command('redraw')
    local pos = funcs.screenpos(bufnr, 1, 1)
    eq(7, pos.row)
    eq(9, pos.col)

    -- only left border
    opts.border = {'', '', '', '', '', '', '', '|'}
    meths.win_set_config(float, opts)
    command('redraw')
    pos = funcs.screenpos(bufnr, 1, 1)
    eq(7, pos.row)
    eq(10, pos.col)

    -- only top border
    opts.border = {'', '_', '', '', '', '', '', ''}
    meths.win_set_config(float, opts)
    command('redraw')
    pos = funcs.screenpos(bufnr, 1, 1)
    eq(8, pos.row)
    eq(9, pos.col)

    -- both left and top border
    opts.border = 'single'
    meths.win_set_config(float, opts)
    command('redraw')
    pos = funcs.screenpos(bufnr, 1, 1)
    eq(8, pos.row)
    eq(10, pos.col)
  end)
end)
