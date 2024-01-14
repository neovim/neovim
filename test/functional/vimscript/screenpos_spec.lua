local helpers = require('test.functional.helpers')(after_each)
local clear, eq, meths = helpers.clear, helpers.eq, helpers.meths
local command, funcs = helpers.command, helpers.funcs
local feed = helpers.feed

before_each(clear)

describe('screenpos() function', function()
  it('works in floating window with border', function()
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
    local float = meths.open_win(meths.create_buf(false, true), false, opts)
    command('redraw')
    eq({row = 7, col = 9, endcol = 9, curscol = 9}, funcs.screenpos(float, 1, 1))

    -- only left border
    opts.border = {'', '', '', '', '', '', '', '|'}
    meths.win_set_config(float, opts)
    command('redraw')
    eq({row = 7, col = 10, endcol = 10, curscol = 10}, funcs.screenpos(float, 1, 1))

    -- only top border
    opts.border = {'', '_', '', '', '', '', '', ''}
    meths.win_set_config(float, opts)
    command('redraw')
    eq({row = 8, col = 9, endcol = 9, curscol = 9}, funcs.screenpos(float, 1, 1))

    -- both left and top border
    opts.border = 'single'
    meths.win_set_config(float, opts)
    command('redraw')
    eq({row = 8, col = 10, endcol = 10, curscol = 10}, funcs.screenpos(float, 1, 1))
  end)

  it('works for folded line with virt_lines attached to line above', function()
    meths.buf_set_lines(0, 0, -1, true, {'aaa', 'bbb', 'ccc', 'ddd'})
    local ns = meths.create_namespace('')
    meths.buf_set_extmark(0, ns, 0, 0, { virt_lines = {{{'abb'}}, {{'acc'}}, {{'add'}}} })
    command('2,3fold')
    eq({row = 5, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 2, 1))
    eq({row = 5, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 3, 1))
    eq({row = 6, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 4, 1))

    feed('<C-E>')
    eq({row = 4, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 2, 1))
    eq({row = 4, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 3, 1))
    eq({row = 5, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 4, 1))

    feed('<C-E>')
    eq({row = 3, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 2, 1))
    eq({row = 3, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 3, 1))
    eq({row = 4, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 4, 1))

    feed('<C-E>')
    eq({row = 2, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 2, 1))
    eq({row = 2, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 3, 1))
    eq({row = 3, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 4, 1))

    feed('<C-E>')
    eq({row = 1, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 2, 1))
    eq({row = 1, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 3, 1))
    eq({row = 2, col = 1, endcol = 1, curscol = 1}, funcs.screenpos(0, 4, 1))
  end)
end)
