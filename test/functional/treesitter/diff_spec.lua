local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local api = n.api
local command = n.command
local exec_lua = n.exec_lua

local function attrs()
  local colors = Screen.colors
  return {
    [131] = { foreground = colors.Red, background = colors.NvimLightRed },
    [132] = { bold = true, background = colors.NvimLightRed, foreground = colors.Brown },
    [134] = { foreground = colors.DarkCyan, background = colors.NvimLightRed },
    [135] = { foreground = colors.Fuchsia, background = colors.NvimLightRed },
    [137] = { bold = true, background = colors.NvimLightGreen, foreground = colors.Brown },
    [138] = { background = colors.NvimLightGreen, foreground = colors.SeaGreen },
    [139] = { foreground = colors.DarkCyan, background = colors.NvimLightGreen },
    [140] = { foreground = colors.Fuchsia, background = colors.NvimLightGreen },
  }
end

describe('treesitter highlighting (diff)', function()
  before_each(clear)

  it('highlights injected code over added and deleted line backgrounds', function()
    local screen = Screen.new(44, 4)
    screen:add_extra_attr_ids(attrs())
    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git a/foo.lua b/foo.lua',
      '--- a/foo.lua',
      '+++ b/foo.lua',
      '@@ -1,2 +1,2 @@',
      ' local x = 1',
      '-local y = 2',
      '+local y = 3',
    })
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    exec_lua(function()
      vim.treesitter.start(0, 'diff')
    end)
    api.nvim_win_set_cursor(0, { 5, 0 })
    command('normal! zt')

    screen:expect([[
      ^ {15:local} {25:x} {15:=} {26:1}                                |
      {131:-}{132:local}{131: }{134:y}{131: }{132:=}{131: }{135:2}                                |
      {138:+}{137:local}{138: }{139:y}{138: }{137:=}{138: }{140:3}                                |
                                                  |
    ]])
  end)
end)
