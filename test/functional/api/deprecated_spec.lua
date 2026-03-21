-- Island of misfit toys.
--- @diagnostic disable: deprecated

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local clear, eval, eq, ok = n.clear, n.eval, t.eq, t.ok
local api, command, fn = n.api, n.command, n.fn
local pcall_err, assert_alive = t.pcall_err, n.assert_alive

describe('deprecated', function()
  before_each(n.clear)

  describe('nvim_notify', function()
    it('can notify a info message', function()
      n.api.nvim_notify('hello world', 2, {})
    end)

    it('can be overridden', function()
      n.command('lua vim.notify = function(...) return 42 end')
      t.eq(42, n.api.nvim_exec_lua("return vim.notify('Hello world')", {}))
      n.api.nvim_notify('hello world', 4, {})
    end)
  end)

  describe('nvim_*get_option functions', function()
    it('does not leak memory', function()
      -- String opts caused memory leaks in these functions in Github#32361
      n.exec_lua([[
        vim.api.nvim_get_option('rtp')
        vim.api.nvim_win_get_option(vim.api.nvim_get_current_win(), 'foldmethod')
        vim.api.nvim_buf_get_option(0, 'fileformat')
      ]])
    end)
  end)

  describe('API: highlight', function()
    clear()
    Screen.new() -- initialize Screen.colors

    local expected_rgb = {
      background = Screen.colors.Yellow,
      foreground = Screen.colors.Red,
      special = Screen.colors.Blue,
      bold = true,
    }
    local expected_cterm = {
      background = 10,
      underline = true,
    }
    local expected_rgb2 = {
      background = Screen.colors.Yellow,
      foreground = Screen.colors.Red,
      special = Screen.colors.Blue,
      bold = true,
      italic = true,
      reverse = true,
      underline = true,
      strikethrough = true,
      altfont = true,
      nocombine = true,
    }
    local expected_undercurl = {
      background = Screen.colors.Yellow,
      foreground = Screen.colors.Red,
      special = Screen.colors.Blue,
      undercurl = true,
    }

    before_each(function()
      clear()
      command(
        'hi NewHighlight cterm=underline ctermbg=green guifg=red guibg=yellow guisp=blue gui=bold'
      )
    end)

    it('nvim_get_hl_by_id', function()
      local hl_id = eval("hlID('NewHighlight')")
      eq(expected_cterm, api.nvim_get_hl_by_id(hl_id, false))

      hl_id = eval("hlID('NewHighlight')")
      -- Test valid id.
      eq(expected_rgb, api.nvim_get_hl_by_id(hl_id, true))

      -- Test invalid id.
      eq('Invalid highlight id: 30000', pcall_err(api.nvim_get_hl_by_id, 30000, false))

      -- Test all highlight properties.
      command('hi NewHighlight gui=underline,bold,italic,reverse,strikethrough,altfont,nocombine')
      eq(expected_rgb2, api.nvim_get_hl_by_id(hl_id, true))

      -- Test undercurl
      command('hi NewHighlight gui=undercurl')
      eq(expected_undercurl, api.nvim_get_hl_by_id(hl_id, true))

      -- Test nil argument.
      eq(
        'Wrong type for argument 1 when calling nvim_get_hl_by_id, expecting Integer',
        pcall_err(api.nvim_get_hl_by_id, { nil }, false)
      )

      -- Test 0 argument.
      eq('Invalid highlight id: 0', pcall_err(api.nvim_get_hl_by_id, 0, false))

      -- Test -1 argument.
      eq('Invalid highlight id: -1', pcall_err(api.nvim_get_hl_by_id, -1, false))

      -- Test highlight group without ctermbg value.
      command('hi Normal ctermfg=red ctermbg=yellow')
      command('hi NewConstant ctermfg=green guifg=white guibg=blue')
      hl_id = eval("hlID('NewConstant')")
      eq({ foreground = 10 }, api.nvim_get_hl_by_id(hl_id, false))

      -- Test highlight group without ctermfg value.
      command('hi clear NewConstant')
      command('hi NewConstant ctermbg=Magenta guifg=white guibg=blue')
      eq({ background = 13 }, api.nvim_get_hl_by_id(hl_id, false))

      -- Test highlight group with ctermfg and ctermbg values.
      command('hi clear NewConstant')
      command('hi NewConstant ctermfg=green ctermbg=Magenta guifg=white guibg=blue')
      eq({ foreground = 10, background = 13 }, api.nvim_get_hl_by_id(hl_id, false))
    end)

    it('nvim_get_hl_by_name', function()
      local expected_normal = { background = Screen.colors.Yellow, foreground = Screen.colors.Red }

      -- Test `Normal` default values.
      eq({}, api.nvim_get_hl_by_name('Normal', true))

      eq(expected_cterm, api.nvim_get_hl_by_name('NewHighlight', false))
      eq(expected_rgb, api.nvim_get_hl_by_name('NewHighlight', true))

      -- Test `Normal` modified values.
      command('hi Normal guifg=red guibg=yellow')
      eq(expected_normal, api.nvim_get_hl_by_name('Normal', true))

      -- Test invalid name.
      eq(
        "Invalid highlight name: 'unknown_highlight'",
        pcall_err(api.nvim_get_hl_by_name, 'unknown_highlight', false)
      )

      -- Test nil argument.
      eq(
        'Wrong type for argument 1 when calling nvim_get_hl_by_name, expecting String',
        pcall_err(api.nvim_get_hl_by_name, { nil }, false)
      )

      -- Test empty string argument.
      eq('Invalid highlight name', pcall_err(api.nvim_get_hl_by_name, '', false))

      -- Test "standout" attribute. #8054
      eq({ underline = true }, api.nvim_get_hl_by_name('cursorline', false))
      command(
        'hi CursorLine cterm=standout,underline term=standout,underline gui=standout,underline'
      )
      command('set cursorline')
      eq({ underline = true, standout = true }, api.nvim_get_hl_by_name('cursorline', false))

      -- Test cterm & Normal values. #18024 (tail) & #18980
      -- Ensure Normal, and groups that match Normal return their fg & bg cterm values
      api.nvim_set_hl(0, 'Normal', { ctermfg = 17, ctermbg = 213 })
      api.nvim_set_hl(0, 'NotNormal', { ctermfg = 17, ctermbg = 213, nocombine = true })
      -- Note colors are "cterm" values, not rgb-as-ints
      eq({ foreground = 17, background = 213 }, api.nvim_get_hl_by_name('Normal', false))
      eq(
        { foreground = 17, background = 213, nocombine = true },
        api.nvim_get_hl_by_name('NotNormal', false)
      )
    end)

    it('nvim_get_hl_id_by_name', function()
      -- precondition: use a hl group that does not yet exist
      eq(
        "Invalid highlight name: 'Shrubbery'",
        pcall_err(api.nvim_get_hl_by_name, 'Shrubbery', true)
      )
      eq(0, fn.hlID('Shrubbery'))

      local hl_id = api.nvim_get_hl_id_by_name('Shrubbery')
      ok(hl_id > 0)
      eq(hl_id, fn.hlID('Shrubbery'))

      command('hi Shrubbery guifg=#888888 guibg=#888888')
      eq(
        { foreground = tonumber('0x888888'), background = tonumber('0x888888') },
        api.nvim_get_hl_by_id(hl_id, true)
      )
      eq(
        { foreground = tonumber('0x888888'), background = tonumber('0x888888') },
        api.nvim_get_hl_by_name('Shrubbery', true)
      )
    end)

    it("nvim_buf_add_highlight to other buffer doesn't crash if undo is disabled #12873", function()
      command('vsplit file')
      local err, _ = pcall(api.nvim_set_option_value, 'undofile', false, { buf = 1 })
      eq(true, err)
      err, _ = pcall(api.nvim_set_option_value, 'undolevels', -1, { buf = 1 })
      eq(true, err)
      err, _ = pcall(api.nvim_buf_add_highlight, 1, -1, 'Question', 0, 0, -1)
      eq(true, err)
      assert_alive()
    end)
  end)
end)
