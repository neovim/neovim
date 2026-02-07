local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, eq, api = n.clear, t.eq, n.api
local command, fn = n.command, n.fn
local feed = n.feed

describe('screenrow() and screencol() function', function()
  local function with_ext_multigrid(multigrid)
    setup(function()
      clear()
      Screen.new(40, 40, { ext_multigrid = multigrid })
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
      command('wincmd l')  -- move to right split
      feed('iA<CR>B<ESC>')  -- insert two lines
      command('redraw')

      eq(2, fn.screenrow())  -- line 2
      eq(21, fn.screencol())  -- 40 / 2 + 1
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)

  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)
