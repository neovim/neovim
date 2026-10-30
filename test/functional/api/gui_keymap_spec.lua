-- The GUI's keymaps (nvim_gui_set_keymap): a mapping layer looked up first,
-- before the current buffer's mappings and the global ones.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local clear = n.clear
local exec_lua = n.exec_lua
local api = n.api
local pcall_err = t.pcall_err

describe('nvim_gui_set_keymap', function()
  before_each(clear)

  --- Which map ran for `keys`.
  local function hit(keys)
    return exec_lua(function(k)
      _G.hit = nil
      vim.api.nvim_feedkeys(vim.keycode(k), 'x', false)
      return _G.hit
    end, keys)
  end

  it('wins over a global mapping of the same keys', function()
    exec_lua(function()
      vim.keymap.set('n', 'Q', function()
        _G.hit = 'global'
      end)
      vim.keymap.set('n', 'Q', function()
        _G.hit = 'gui'
      end, { gui = true })
    end)
    eq('gui', hit('Q'))
  end)

  it("comes before the current buffer's own mapping", function()
    exec_lua(function()
      vim.keymap.set('n', 'Q', function()
        _G.hit = 'gui'
      end, { gui = true })
      vim.keymap.set('n', 'Q', function()
        _G.hit = 'buffer'
      end, { buf = 0 })
    end)
    eq('gui', hit('Q'))
    -- Without the GUI's: the buffer's own.
    api.nvim_gui_del_keymap('n', 'Q')
    eq('buffer', hit('Q'))
  end)

  it('takes string rhs, <leader> and multi-key sequences', function()
    n.command('let mapleader = ","')
    api.nvim_gui_set_keymap('n', '<leader>x', '<Cmd>let g:x = 1<CR>', {})
    n.feed(',x')
    eq(1, api.nvim_get_var('x'))
  end)

  it('is listed, and deleted', function()
    api.nvim_gui_set_keymap('n', 'Q', '<Nop>', { desc = 'nothing' })
    local maps = api.nvim_gui_get_keymap('n')
    eq(1, #maps)
    eq('Q', maps[1].lhs)
    eq('nothing', maps[1].desc)
    eq({}, api.nvim_get_keymap('n'))
    exec_lua(function()
      vim.keymap.del('n', 'Q', { gui = true })
    end)
    eq({}, api.nvim_gui_get_keymap('n'))
  end)

  it('has no abbreviations', function()
    eq(
      'The GUI has keymaps, not abbreviations',
      pcall_err(api.nvim_gui_set_keymap, 'ia', 'teh', 'the', {})
    )
  end)
end)
