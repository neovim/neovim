local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local t = require('test.testutil')
local clear = n.clear
local api = n.api
local command = n.command
local exec_lua = n.exec_lua
local write_file = t.write_file

local diff_lines = {
  'diff --git a/foo.lua b/foo.lua',
  '--- a/foo.lua',
  '+++ b/foo.lua',
  '@@ -1,2 +1,2 @@',
  ' local x = 1',
  '-local y = 2',
  '+local y = 3',
}

describe('diff hunk highlighting', function()
  before_each(function()
    clear()
    command('filetype plugin on')
    api.nvim_set_hl(0, 'DiffAdd', { fg = 'NvimLightGrey1', bg = 'NvimDarkGreen' })
    api.nvim_set_hl(0, 'DiffDelete', { fg = 'NvimLightGrey1', bg = 'NvimDarkRed' })
  end)

  it('highlights code inside lua hunks via tree-sitter', function()
    local screen = Screen.new(44, 8)
    screen:add_extra_attr_ids({
      [131] = { foreground = Screen.colors.Red, background = Screen.colors.NvimDarkRed },
      [132] = {
        bold = true,
        background = Screen.colors.NvimDarkRed,
        foreground = Screen.colors.Brown,
      },
      [133] = { foreground = Screen.colors.NvimLightGrey1, background = Screen.colors.NvimDarkRed },
      [134] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkRed },
      [135] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkRed },
      [136] = { foreground = Screen.colors.SeaGreen, background = Screen.colors.NvimDarkGreen },
      [137] = {
        bold = true,
        background = Screen.colors.NvimDarkGreen,
        foreground = Screen.colors.Brown,
      },
      [138] = {
        foreground = Screen.colors.NvimLightGrey1,
        background = Screen.colors.NvimDarkGreen,
      },
      [139] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkGreen },
      [140] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkGreen },
    })
    api.nvim_buf_set_lines(0, 0, -1, false, diff_lines)
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       {15:local} {25:x} {15:=} {26:1}                                |
      {131:-}{132:local}{133: }{134:y}{133: }{132:=}{133: }{135:2}{133:                                }|
      {136:+}{137:local}{138: }{139:y}{138: }{137:=}{138: }{140:3}{138:                                }|
                                                  |
    ]])
  end)

  it('highlights the viewport of a large hunk without blocking', function()
    local screen = Screen.new(44, 8)
    screen:add_extra_attr_ids({
      [131] = { foreground = Screen.colors.SeaGreen, background = Screen.colors.NvimDarkGreen },
      [132] = {
        bold = true,
        background = Screen.colors.NvimDarkGreen,
        foreground = Screen.colors.Brown,
      },
      [133] = {
        foreground = Screen.colors.NvimLightGrey1,
        background = Screen.colors.NvimDarkGreen,
      },
      [134] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkGreen },
      [135] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkGreen },
    })
    local lines = {
      'diff --git a/big.lua b/big.lua',
      '--- /dev/null',
      '+++ b/big.lua',
      '@@ -0,0 +1,2000 @@',
    }
    for i = 1, 2000 do
      lines[#lines + 1] = ('+local v%d = %d'):format(i, i)
    end
    api.nvim_buf_set_lines(0, 0, -1, false, lines)
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/big.lua b/big.lua              |
      --- /dev/null                               |
      +++ b/big.lua                               |
      @@ -0,0 +1,2000 @@                          |
      {131:+}{132:local}{133: }{134:v1}{133: }{132:=}{133: }{135:1}{133:                               }|
      {131:+}{132:local}{133: }{134:v2}{133: }{132:=}{133: }{135:2}{133:                               }|
      {131:+}{132:local}{133: }{134:v3}{133: }{132:=}{133: }{135:3}{133:                               }|
                                                  |
    ]])
  end)

  it('does not highlight when disabled via vim.g.diffhl', function()
    local screen = Screen.new(44, 8)
    api.nvim_set_var('diffhl', false)
    api.nvim_buf_set_lines(0, 0, -1, false, diff_lines)
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       local x = 1                                |
      -local y = 2                                |
      +local y = 3                                |
                                                  |
    ]])
  end)

  it('re-highlights when a parser becomes available on runtimepath', function()
    local screen = Screen.new(44, 8)
    screen:add_extra_attr_ids({
      [131] = { foreground = Screen.colors.Red, background = Screen.colors.NvimDarkRed },
      [132] = { foreground = Screen.colors.NvimLightGrey1, background = Screen.colors.NvimDarkRed },
      [133] = { foreground = Screen.colors.SeaGreen, background = Screen.colors.NvimDarkGreen },
      [134] = {
        foreground = Screen.colors.NvimLightGrey1,
        background = Screen.colors.NvimDarkGreen,
      },
      [135] = {
        bold = true,
        background = Screen.colors.NvimDarkRed,
        foreground = Screen.colors.Brown,
      },
      [136] = { background = Screen.colors.NvimDarkRed, foreground = Screen.colors.Cyan4 },
      [137] = { background = Screen.colors.NvimDarkRed, foreground = Screen.colors.Fuchsia },
      [138] = {
        bold = true,
        background = Screen.colors.NvimDarkGreen,
        foreground = Screen.colors.Brown,
      },
      [139] = { background = Screen.colors.NvimDarkGreen, foreground = Screen.colors.Cyan4 },
      [140] = { background = Screen.colors.NvimDarkGreen, foreground = Screen.colors.Fuchsia },
    })
    exec_lua(function()
      local so = vim.api.nvim_get_runtime_file('parser/lua.so', false)[1]
      _G.parser_dir = vim.fn.fnamemodify(so, ':h:h')
      vim.opt.rtp:remove(_G.parser_dir)
    end)
    api.nvim_buf_set_lines(0, 0, -1, false, diff_lines)
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       local x = 1                                |
      {131:-}{132:local y = 2                                }|
      {133:+}{134:local y = 3                                }|
                                                  |
    ]])
    exec_lua(function()
      vim.opt.rtp:append(_G.parser_dir)
    end)
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       {15:local} {25:x} {15:=} {26:1}                                |
      {131:-}{135:local}{132: }{136:y}{132: }{135:=}{132: }{137:2}{132:                                }|
      {133:+}{138:local}{134: }{139:y}{134: }{138:=}{134: }{140:3}{134:                                }|
                                                  |
    ]])
  end)

  it('keeps highlighting after an autoread reload', function()
    local screen = Screen.new(44, 8)
    screen:add_extra_attr_ids({
      [131] = { foreground = Screen.colors.Red, background = Screen.colors.NvimDarkRed },
      [132] = {
        bold = true,
        background = Screen.colors.NvimDarkRed,
        foreground = Screen.colors.Brown,
      },
      [133] = { foreground = Screen.colors.NvimLightGrey1, background = Screen.colors.NvimDarkRed },
      [134] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkRed },
      [135] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkRed },
      [136] = { foreground = Screen.colors.SeaGreen, background = Screen.colors.NvimDarkGreen },
      [137] = {
        bold = true,
        background = Screen.colors.NvimDarkGreen,
        foreground = Screen.colors.Brown,
      },
      [138] = {
        foreground = Screen.colors.NvimLightGrey1,
        background = Screen.colors.NvimDarkGreen,
      },
      [139] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkGreen },
      [140] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkGreen },
    })
    local dir = 'Xtest-diffhl'
    n.mkdir_p(dir)
    finally(function()
      n.rmdir(dir)
    end)
    local path = dir .. '/foo.diff'
    write_file(path, table.concat(diff_lines, '\n') .. '\n')
    command('edit ' .. path)
    command('set autoread')
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       {15:local} {25:x} {15:=} {26:1}                                |
      {131:-}{132:local}{133: }{134:y}{133: }{132:=}{133: }{135:2}{133:                                }|
      {136:+}{137:local}{138: }{139:y}{138: }{137:=}{138: }{140:3}{138:                                }|
                                                  |
    ]])
    write_file(path, table.concat({
      'diff --git a/foo.lua b/foo.lua',
      '--- a/foo.lua',
      '+++ b/foo.lua',
      '@@ -1,2 +1,2 @@',
      ' local x = 1',
      '-local y = 2',
      '+local y = 30',
    }, '\n') .. '\n')
    command('checktime')
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@ -1,2 +1,2 @@                             |
       {15:local} {25:x} {15:=} {26:1}                                |
      {131:-}{132:local}{133: }{134:y}{133: }{132:=}{133: }{135:2}{133:                                }|
      {136:+}{137:local}{138: }{139:y}{138: }{137:=}{138: }{140:30}{138:                               }|
                                                  |
    ]])
  end)

  it('highlights deleted-file hunks via the old path', function()
    local screen = Screen.new(44, 8)
    screen:add_extra_attr_ids({
      [131] = { foreground = Screen.colors.Red, background = Screen.colors.NvimDarkRed },
      [132] = {
        bold = true,
        background = Screen.colors.NvimDarkRed,
        foreground = Screen.colors.Brown,
      },
      [133] = { foreground = Screen.colors.NvimLightGrey1, background = Screen.colors.NvimDarkRed },
      [134] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkRed },
      [135] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkRed },
    })
    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git a/foo.lua b/foo.lua',
      'deleted file mode 100644',
      '--- a/foo.lua',
      '+++ /dev/null',
      '@@ -1,2 +0,0 @@',
      '-local x = 1',
      '-local y = 2',
    })
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.lua              |
      deleted file mode 100644                    |
      --- a/foo.lua                               |
      +++ /dev/null                               |
      @@ -1,2 +0,0 @@                             |
      {131:-}{132:local}{133: }{134:x}{133: }{132:=}{133: }{135:1}{133:                                }|
      {131:-}{132:local}{133: }{134:y}{133: }{132:=}{133: }{135:2}{133:                                }|
                                                  |
    ]])
  end)

  it('highlights hunks for spaced and quoted (non-ascii) paths', function()
    local screen = Screen.new(44, 8)
    screen:add_extra_attr_ids({
      [131] = { foreground = Screen.colors.Red, background = Screen.colors.NvimDarkRed },
      [132] = {
        bold = true,
        background = Screen.colors.NvimDarkRed,
        foreground = Screen.colors.Brown,
      },
      [133] = { foreground = Screen.colors.NvimLightGrey1, background = Screen.colors.NvimDarkRed },
      [134] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkRed },
      [135] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkRed },
      [136] = { foreground = Screen.colors.SeaGreen, background = Screen.colors.NvimDarkGreen },
      [137] = {
        bold = true,
        background = Screen.colors.NvimDarkGreen,
        foreground = Screen.colors.Brown,
      },
      [138] = {
        foreground = Screen.colors.NvimLightGrey1,
        background = Screen.colors.NvimDarkGreen,
      },
      [139] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkGreen },
      [140] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkGreen },
    })
    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git a/my file.lua b/my file.lua',
      '--- a/my file.lua',
      '+++ b/my file.lua',
      '@@ -1,1 +1,1 @@',
      '-local y = 2',
      '+local y = 3',
    })
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/my file.lua b/my file.lua      |
      --- a/my file.lua                           |
      +++ b/my file.lua                           |
      @@ -1,1 +1,1 @@                             |
      {131:-}{132:local}{133: }{134:y}{133: }{132:=}{133: }{135:2}{133:                                }|
      {136:+}{137:local}{138: }{139:y}{138: }{137:=}{138: }{140:3}{138:                                }|
      {1:~                                           }|
                                                  |
    ]])

    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git "a/\\303\\251.lua" "b/\\303\\251.lua"',
      '--- "a/\\303\\251.lua"',
      '+++ "b/\\303\\251.lua"',
      '@@ -1,1 +1,1 @@',
      '-local y = 2',
      '+local y = 3',
    })
    screen:expect([[
      ^diff --git "a/\303\251.lua" "b/\303\251.lua"|
      --- "a/\303\251.lua"                        |
      +++ "b/\303\251.lua"                        |
      @@ -1,1 +1,1 @@                             |
      {131:-}{132:local}{133: }{134:y}{133: }{132:=}{133: }{135:2}{133:                                }|
      {136:+}{137:local}{138: }{139:y}{138: }{137:=}{138: }{140:3}{138:                                }|
      {1:~                                           }|
                                                  |
    ]])
  end)

  it('highlights each side in its own language for a rename with type change', function()
    local screen = Screen.new(44, 10)
    screen:add_extra_attr_ids({
      [131] = { foreground = Screen.colors.Red, background = Screen.colors.NvimDarkRed },
      [132] = {
        bold = true,
        background = Screen.colors.NvimDarkRed,
        foreground = Screen.colors.Brown,
      },
      [133] = { foreground = Screen.colors.NvimLightGrey1, background = Screen.colors.NvimDarkRed },
      [134] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkRed },
      [135] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkRed },
      [136] = { foreground = Screen.colors.SeaGreen, background = Screen.colors.NvimDarkGreen },
      [137] = { foreground = Screen.colors.SlateBlue, background = Screen.colors.NvimDarkGreen },
      [138] = {
        foreground = Screen.colors.NvimLightGrey1,
        background = Screen.colors.NvimDarkGreen,
      },
      [139] = { foreground = Screen.colors.DarkCyan, background = Screen.colors.NvimDarkGreen },
      [140] = {
        bold = true,
        background = Screen.colors.NvimDarkGreen,
        foreground = Screen.colors.Brown,
      },
      [141] = { foreground = Screen.colors.Fuchsia, background = Screen.colors.NvimDarkGreen },
    })
    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git a/foo.lua b/foo.c',
      'rename from foo.lua',
      'rename to foo.c',
      '--- a/foo.lua',
      '+++ b/foo.c',
      '@@ -1,1 +1,1 @@',
      '-local x = 1',
      '+int x = 1;',
    })
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/foo.lua b/foo.c                |
      rename from foo.lua                         |
      rename to foo.c                             |
      --- a/foo.lua                               |
      +++ b/foo.c                                 |
      @@ -1,1 +1,1 @@                             |
      {131:-}{132:local}{133: }{134:x}{133: }{132:=}{133: }{135:1}{133:                                }|
      {136:+}{137:int}{138: }{139:x}{138: }{140:=}{138: }{141:1}{137:;}{138:                                 }|
      {1:~                                           }|
                                                  |
    ]])
  end)

  it('tints added and removed lines without a parser', function()
    local screen = Screen.new(44, 8)
    screen:add_extra_attr_ids({
      [131] = { background = Screen.colors.NvimDarkRed, foreground = Screen.colors.Red },
      [132] = { background = Screen.colors.NvimDarkRed, foreground = Screen.colors.NvimLightGrey1 },
      [133] = { background = Screen.colors.NvimDarkGreen, foreground = Screen.colors.SeaGreen },
      [134] = {
        background = Screen.colors.NvimDarkGreen,
        foreground = Screen.colors.NvimLightGrey1,
      },
    })
    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --git a/notes.xyz b/notes.xyz',
      '--- a/notes.xyz',
      '+++ b/notes.xyz',
      '@@ -1,2 +1,2 @@',
      ' context line',
      '-old value',
      '+new value',
    })
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --git a/notes.xyz b/notes.xyz          |
      --- a/notes.xyz                             |
      +++ b/notes.xyz                             |
      @@ -1,2 +1,2 @@                             |
       context line                               |
      {131:-}{132:old value                                  }|
      {133:+}{134:new value                                  }|
                                                  |
    ]])
  end)

  it('tints combined (merge) diff hunks', function()
    local screen = Screen.new(44, 10)
    screen:add_extra_attr_ids({
      [131] = { background = Screen.colors.NvimDarkRed, foreground = Screen.colors.Red },
      [132] = { background = Screen.colors.NvimDarkRed, foreground = Screen.colors.NvimLightGrey1 },
      [133] = { background = Screen.colors.NvimDarkGreen, foreground = Screen.colors.SeaGreen },
      [134] = {
        background = Screen.colors.NvimDarkGreen,
        foreground = Screen.colors.NvimLightGrey1,
      },
    })
    api.nvim_buf_set_lines(0, 0, -1, false, {
      'diff --cc foo.lua',
      'index 1111111,2222222..3333333',
      '--- a/foo.lua',
      '+++ b/foo.lua',
      '@@@ -1,2 -1,2 +1,2 @@@',
      '  local x = 1',
      '- local y = 2',
      ' -local y = 3',
      '++local y = 4',
    })
    api.nvim_set_option_value('filetype', 'diff', { buf = 0 })
    screen:expect([[
      ^diff --cc foo.lua                           |
      index 1111111,2222222..3333333              |
      --- a/foo.lua                               |
      +++ b/foo.lua                               |
      @@@ -1,2 -1,2 +1,2 @@@                      |
        local x = 1                               |
      {131:- }{132:local y = 2                               }|
      {131: -}{132:local y = 3                               }|
      {133:++}{134:local y = 4                               }|
                                                  |
    ]])
  end)
end)
