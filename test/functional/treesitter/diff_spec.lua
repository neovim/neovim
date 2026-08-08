local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local api = n.api
local command = n.command
local exec_lua = n.exec_lua

local function attrs()
  local colors = Screen.colors
  return {
    [141] = { background = colors.NvimLightRed, foreground = colors.SlateBlue },
    [142] = { background = colors.NvimLightRed },
    [143] = { background = colors.NvimLightGreen, foreground = colors.SlateBlue },
    [144] = { background = colors.NvimLightGreen },
    [132] = { background = colors.NvimLightRed, foreground = colors.Brown, bold = true },
    [134] = { background = colors.NvimLightRed, foreground = colors.Cyan4 },
    [135] = { background = colors.NvimLightRed, foreground = colors.Fuchsia },
    [137] = { background = colors.NvimLightGreen, foreground = colors.Brown, bold = true },
    [139] = { background = colors.NvimLightGreen, foreground = colors.Cyan4 },
    [140] = { background = colors.NvimLightGreen, foreground = colors.Fuchsia },
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
      {141:-}{132:local}{142: }{134:y}{142: }{132:=}{142: }{135:2}                                |
      {143:+}{137:local}{144: }{139:y}{144: }{137:=}{144: }{140:3}                                |
                                                  |
    ]])
  end)
end)
