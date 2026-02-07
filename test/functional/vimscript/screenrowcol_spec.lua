local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, eq, api = n.clear, t.eq, n.api
local command, fn = n.command, n.fn
local feed = n.feed

describe('screenrow() and screencol() function', function()
  local function with_ext_multigrid(multigrid)
    before_each(function()
      clear()
      Screen.new(41, 41, { ext_multigrid = multigrid })
    end)

    it('works in floating window', function()
      local opts = {
        relative = 'editor',
        height = 8,
        width = 12,
        row = 6,
        col = 8,
        anchor = 'NW',
        style = 'minimal',
        border = 'none',
        focusable = 1,
      }
      local float = api.nvim_open_win(api.nvim_create_buf(false, true), false, opts)

      api.nvim_set_current_win(float)
      command('redraw')

      eq(7, fn.screenrow())
      eq(9, fn.screencol())
    end)

    it('works in vertical split', function()
      command('vsplit')
      command('wincmd l') -- move to right split
      feed('iA<CR>BC<ESC>') -- insert two lines
      command('redraw')

      eq(2, fn.screenrow())
      eq(23, fn.screencol()) -- 20 (left) | 1 (border) | 2 (2nd col)
    end)

    it('works in horizontal split', function()
      command('split')
      command('wincmd j') -- move to bottom split
      feed('iA<CR>BC<ESC>') -- insert two lines
      command('redraw')

      eq(22, fn.screenrow()) -- 19 (top) | 1 (border) | 2 (2nd row) + 17 (rest) | 2 (cmd)
      eq(2, fn.screencol())
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)

  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)
