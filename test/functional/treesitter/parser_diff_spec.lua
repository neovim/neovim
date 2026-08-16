local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local clear = n.clear
local api = n.api
local command = n.command
local exec_lua = n.exec_lua

local function injected(lines)
  api.nvim_buf_set_lines(0, 0, -1, false, lines)
  return exec_lua(function()
    local parser = vim.treesitter.get_parser(0, 'diff')
    parser:parse(true)
    local result = {}
    for lang, child in pairs(parser:children()) do
      result[lang] = {}
      for _, region in ipairs(child:included_regions()) do
        local texts = {}
        for _, range in ipairs(region) do
          texts[#texts + 1] =
            table.concat(vim.api.nvim_buf_get_text(0, range[1], range[2], range[4], range[5], {}))
        end
        result[lang][#result[lang] + 1] = texts
      end
      table.sort(result[lang], function(a, b)
        return #a > #b
      end)
    end
    return result
  end)
end

describe('treesitter bundled parser: diff', function()
  before_each(clear)

  local function hunk()
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
  end

  it('highlights hunk content over the added and deleted line backgrounds', function()
    local screen = Screen.new(44, 4)
    local colors = Screen.colors
    screen:add_extra_attr_ids({
      [100] = { foreground = colors.SlateBlue, background = colors.NvimLightRed },
      [101] = { foreground = colors.Brown, background = colors.NvimLightRed, bold = true },
      [102] = { background = colors.NvimLightRed },
      [103] = { foreground = colors.Cyan4, background = colors.NvimLightRed },
      [104] = { foreground = colors.Magenta1, background = colors.NvimLightRed },
      [105] = { foreground = colors.SlateBlue, background = colors.NvimLightGreen },
      [106] = { foreground = colors.Brown, background = colors.NvimLightGreen, bold = true },
      [107] = { background = colors.NvimLightGreen },
      [108] = { foreground = colors.Cyan4, background = colors.NvimLightGreen },
      [109] = { foreground = colors.Magenta1, background = colors.NvimLightGreen },
    })
    hunk()

    screen:expect([[
      ^ {15:local} {25:x} {15:=} {26:1}                                |
      {100:-}{101:local}{102: }{103:y}{102: }{101:=}{102: }{104:2}                                |
      {105:+}{106:local}{107: }{108:y}{107: }{106:=}{107: }{109:3}                                |
                                                  |
    ]])
  end)

  it('drops the backgrounds when the specializations are linked away', function()
    local screen = Screen.new(44, 4)
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.SeaGreen4 },
    })
    command('hi! link @diff.plus.diff @diff.plus')
    command('hi! link @diff.minus.diff @diff.minus')
    hunk()

    screen:expect([[
      ^ {15:local} {25:x} {15:=} {26:1}                                |
      {19:-}{15:local}{19: }{25:y}{19: }{15:=}{19: }{26:2}                                |
      {100:+}{15:local}{100: }{25:y}{100: }{15:=}{100: }{26:3}                                |
                                                  |
    ]])
  end)

  it('injects the old and new file languages separately', function()
    eq(
      {
        c = { { 'int x = 1;', 'int y = 2;' } },
        lua = { { 'int x = 1;' } },
      },
      injected({
        'diff --git a/foo.lua b/foo.c',
        'rename from foo.lua',
        'rename to foo.c',
        '--- a/foo.lua',
        '+++ b/foo.c',
        '@@ -1,2 +1,2 @@',
        ' int x = 1;',
        '+int y = 2;',
      })
    )
  end)

  it('continues an injection past lines that are not changes', function()
    eq(
      {
        lua = {
          { 'local x = 1', 'local y = 3', 'local z = 4' },
          { 'local x = 1', 'local y = 2', 'local z = 4' },
        },
      },
      injected({
        'diff --git a/foo.lua b/foo.lua',
        '--- a/foo.lua',
        '+++ b/foo.lua',
        '@@ -1,4 +1,4 @@',
        ' local x = 1',
        '-local y = 2',
        '\\ No newline at end of file',
        '+local y = 3',
        ' local z = 4',
      })
    )
  end)

  it('resolves a filename followed by a timestamp', function()
    eq(
      {
        lua = { { 'local x = 1', 'local y = 2' }, { 'local x = 1' } },
      },
      injected({
        'diff -u foo.lua bar.lua',
        '--- foo.lua\t2026-01-01 12:00:00.000000000 +0000',
        '+++ bar.lua\t2026-01-02 12:00:00.000000000 +0000',
        '@@ -1,2 +1,2 @@',
        ' local x = 1',
        '+local y = 2',
      })
    )
  end)

  it('resolves a quoted filename', function()
    eq(
      {
        lua = { { 'local x = 1', 'local y = 2' }, { 'local x = 1' } },
      },
      injected({
        'diff --git "a/my foo.lua" "b/my foo.lua"',
        '--- "a/my foo.lua"',
        '+++ "b/my foo.lua"',
        '@@ -1,2 +1,2 @@',
        ' local x = 1',
        '+local y = 2',
      })
    )
  end)

  it('does not inject when the file has no parser', function()
    eq(
      {},
      injected({
        'diff --git a/foo.xyzzy b/foo.xyzzy',
        '--- a/foo.xyzzy',
        '+++ b/foo.xyzzy',
        '@@ -1,2 +1,2 @@',
        ' hello',
        '+world',
      })
    )
  end)

  it('does not inject the missing side of an added file', function()
    eq(
      {
        lua = { { 'local x = 1', 'local y = 2' } },
      },
      injected({
        'diff --git a/foo.lua b/foo.lua',
        'new file mode 100644',
        '--- /dev/null',
        '+++ b/foo.lua',
        '@@ -0,0 +1,2 @@',
        '+local x = 1',
        '+local y = 2',
      })
    )
  end)
end)
