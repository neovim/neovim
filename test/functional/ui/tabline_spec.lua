local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, command, eq = n.clear, n.command, t.eq
local insert = n.insert
local api = n.api
local assert_alive = n.assert_alive

describe('ui/ext_tabline', function()
  local screen
  local event_tabs, event_curtab, event_curbuf, event_buffers

  before_each(function()
    clear()
    screen = Screen.new(25, 5, { rgb = true, ext_tabline = true })
    function screen:_handle_tabline_update(curtab, tabs, curbuf, buffers)
      event_curtab = curtab
      event_tabs = tabs
      event_curbuf = curbuf
      event_buffers = buffers
    end
  end)

  it('publishes UI events', function()
    command('tabedit another-tab')

    local expected_tabs = {
      { tab = 1, name = '[No Name]' },
      { tab = 2, name = 'another-tab' },
    }
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      condition = function()
        eq(2, event_curtab)
        eq(expected_tabs, event_tabs)
      end,
    }

    command('tabNext')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      condition = function()
        eq(1, event_curtab)
        eq(expected_tabs, event_tabs)
      end,
    }
  end)

  it('buffer UI events', function()
    local expected_buffers_initial = {
      { buffer = 1, name = '[No Name]' },
    }

    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      condition = function()
        eq(1, event_curbuf)
        eq(expected_buffers_initial, event_buffers)
      end,
    }

    command('badd another-buffer')
    command('bnext')

    local expected_buffers = {
      { buffer = 1, name = '[No Name]' },
      { buffer = 2, name = 'another-buffer' },
    }
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      condition = function()
        eq(2, event_curbuf)
        eq(expected_buffers, event_buffers)
      end,
    }
  end)
end)

describe('tabline', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(42, 5)
  end)

  it("uses and restores the default 'tabline' expression", function()
    local default = "%!v:lua.require('vim._core.tabline').default()"
    eq(default, n.eval('&tabline'))

    command('set tabline=custom')
    eq('custom', n.eval('&tabline'))

    command('set tabline=')
    eq(default, n.eval('&tabline'))
  end)

  it('escapes item labels', function()
    api.nvim_buf_set_name(0, 'current%tab')
    local rendered = n.exec_lua [[
      local tabline = require('vim._core.tabline').default()
      return vim.api.nvim_eval_statusline(tabline, { use_tabline = true, maxwidth = 42 }).str
    ]]
    eq(true, rendered:find('current%tab', 1, true) ~= nil)
  end)

  it('accepts a local item formatter through a Lua wrapper', function()
    api.nvim_buf_set_name(0, '/projects/alpha/init.lua')
    api.nvim_buf_set_lines(0, 0, -1, false, { 'modified' })
    command('vsplit')
    api.nvim_open_win(0, false, {
      relative = 'editor',
      width = 1,
      height = 1,
      row = 0,
      col = 0,
      focusable = false,
    })
    command('tabedit /projects/beta/main.lua')

    local rendered = n.exec_lua [[
      local function tabitem(info)
        local wincount = vim.fn.tabpagewinnr(info.tabnr, '$')
        local bufnr = vim.api.nvim_win_get_buf(info.winid)
        local path = vim.api.nvim_buf_get_name(bufnr)
        local name = vim.fs.relpath(vim.fn.getcwd(-1, info.tabnr), path)
          or vim.api.nvim_eval_statusline('%t', { winid = info.winid, maxwidth = 9999 }).str
        return ('%d:%d%s %s'):format(
          info.tabnr,
          wincount,
          vim.fn.getbufvar(bufnr, '&modified') == 1 and '+' or '',
          name
        )
      end

      _G.MyTabline = function()
        return require('vim._core.tabline').default(tabitem)
      end

      vim.o.tabline = '%!v:lua.MyTabline()'
      return vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = 42 }).str
    ]]

    local expected = ' 1:2+ init.lua  2:1 main.lua '
    eq(expected, rendered:sub(1, #expected))
  end)

  it('keeps the current tab visible when truncated', function()
    api.nvim_buf_set_name(0, 'CURRENT')
    for i = 2, 10 do
      command('tabnew')
      api.nvim_buf_set_name(0, 'long-tab-name-' .. i)
    end
    command('tabfirst')

    local rendered = n.exec_lua [[
      local tabline = require('vim._core.tabline').default()
      return vim.api.nvim_eval_statusline(tabline, {
        use_tabline = true,
        maxwidth = vim.o.columns,
      }).str
    ]]
    eq(true, rendered:find('CURRENT', 1, true) ~= nil)
  end)

  it('redraws when tabline option is set', function()
    command('set tabline=asdf')
    command('set showtabline=2')
    screen:expect {
      grid = [[
      asdf                                      |
      ^                                          |
      {1:~                                         }|*2
                                                |
    ]],
    }
    command('set tabline=jkl')
    screen:expect {
      grid = [[
      jkl                                       |
      ^                                          |
      {1:~                                         }|*2
                                                |
    ]],
    }
  end)

  it('combines highlight attributes', function()
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.Blue1, bold = true }, -- StatusLine
      [2] = { bold = true, italic = true }, -- StatusLine
      [3] = { bold = true, italic = true, foreground = Screen.colors.Red }, -- NonText combined with StatusLine
    })
    command('hi TabLineBase gui=bold,italic')
    command('hi Identifier guifg=red')
    command('set tabline=Test%#Identifier#here')
    command('set showtabline=2')
    screen:expect {
      grid = [[
      {2:Test}{3:here                                  }|
      ^                                          |
      {1:~                                         }|*2
                                                |
    ]],
    }
  end)

  it('click definitions do not leak memory #21765', function()
    command('set tabline=%@MyClickFunc@MyClickText%T')
    command('set showtabline=2')
    command('redrawtabline')
  end)

  it('clicks work with truncated double-width label #24187', function()
    insert('tab1')
    command('tabnew')
    insert('tab2')
    command('tabprev')
    api.nvim_set_option_value('tabline', '%1T口口%2Ta' .. ('b'):rep(38) .. '%999Xc', {})
    screen:expect {
      grid = [[
      <abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc |
      tab^1                                      |
      {1:~                                         }|*2
                                                |
    ]],
    }
    assert_alive()
    api.nvim_input_mouse('left', 'press', '', 0, 0, 1)
    screen:expect {
      grid = [[
      <abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc |
      tab^2                                      |
      {1:~                                         }|*2
                                                |
    ]],
    }
    api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
    screen:expect {
      grid = [[
      <abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc |
      tab^1                                      |
      {1:~                                         }|*2
                                                |
    ]],
    }
    api.nvim_input_mouse('left', 'press', '', 0, 0, 39)
    screen:expect {
      grid = [[
      <abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc |
      tab^2                                      |
      {1:~                                         }|*2
                                                |
    ]],
    }
    api.nvim_input_mouse('left', 'press', '', 0, 0, 40)
    screen:expect {
      grid = [[
      tab^1                                      |
      {1:~                                         }|*3
                                                |
    ]],
    }
  end)

  it('middle-click closes tab', function()
    command('tabnew')
    command('tabnew')
    command('tabnew')
    command('tabprev')
    eq({ 3, 4 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
    api.nvim_input_mouse('middle', 'press', '', 0, 0, 1)
    eq({ 2, 3 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
    api.nvim_input_mouse('middle', 'press', '', 0, 0, 20)
    eq({ 2, 2 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
    api.nvim_input_mouse('middle', 'press', '', 0, 0, 1)
    eq({ 1, 1 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
  end)

  it('does not show floats with focusable=false', function()
    screen:set_default_attr_ids({
      [1] = { background = Screen.colors.Plum1 },
      [2] = { underline = true, background = Screen.colors.LightGrey },
      [3] = { bold = true },
      [4] = { reverse = true },
      [5] = { bold = true, foreground = Screen.colors.Blue1 },
      [6] = { foreground = Screen.colors.Fuchsia, bold = true },
      [7] = { foreground = Screen.colors.SeaGreen, bold = true },
    })
    command('tabnew')
    api.nvim_open_win(0, false, {
      focusable = false,
      relative = 'editor',
      height = 1,
      width = 1,
      row = 0,
      col = 0,
    })
    screen:expect {
      grid = [[
      {1: }{2:[No Name] }{3: [No Name] }{4:                   }{2:X}|
      ^                                          |
      {5:~                                         }|*2
                                                |
    ]],
    }
    command('tabs')
    screen:expect {
      grid = [[
      {6:Tab page 1}                                |
      #   [No Name]                             |
      {6:Tab page 2}                                |
      >   [No Name]                             |
      {7:Press ENTER or type command to continue}^   |
    ]],
    }
  end)
end)
