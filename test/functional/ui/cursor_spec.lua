local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, api = n.clear, n.api
local eq = t.eq
local command = n.command

describe('ui/cursor', function()
  ---@type test.functional.ui.screen
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
  end)

  it("'guicursor' is published as a UI event", function()
    local expected_mode_info = {
      [1] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'normal',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 'n',
        used_for = 3,
      },
      [2] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'visual',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 'v',
        used_for = 3,
      },
      [3] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        name = 'insert',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 'i',
        used_for = 3,
      },
      [4] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        name = 'replace',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 'r',
        used_for = 3,
      },
      [5] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'cmdline_normal',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 'c',
        used_for = 3,
      },
      [6] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        name = 'cmdline_insert',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 'ci',
        used_for = 3,
      },
      [7] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        name = 'cmdline_replace',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 'cr',
        used_for = 3,
      },
      [8] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        name = 'operator',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 'o',
        used_for = 3,
      },
      [9] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        name = 'visual_select',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        mouse_shape = '',
        short_name = 've',
        used_for = 3,
      },
      [10] = {
        name = 'cmdline_hover',
        mouse_shape = '',
        short_name = 'e',
        used_for = 1,
      },
      [11] = {
        name = 'statusline_hover',
        mouse_shape = '',
        short_name = 's',
        used_for = 1,
      },
      [12] = {
        name = 'statusline_drag',
        mouse_shape = '',
        short_name = 'sd',
        used_for = 1,
      },
      [13] = {
        name = 'vsep_hover',
        mouse_shape = '',
        short_name = 'vs',
        used_for = 1,
      },
      [14] = {
        name = 'vsep_drag',
        mouse_shape = '',
        short_name = 'vd',
        used_for = 1,
      },
      [15] = {
        name = 'more',
        mouse_shape = '',
        short_name = 'm',
        used_for = 1,
      },
      [16] = {
        name = 'more_lastline',
        mouse_shape = '',
        short_name = 'ml',
        used_for = 1,
      },
      [17] = {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'showmatch',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
        short_name = 'sm',
        used_for = 2,
      },
      [18] = {
        blinkoff = 500,
        blinkon = 500,
        blinkwait = 0,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'terminal',
        hl_id = 3,
        id_lm = 3,
        attr = { reverse = true },
        attr_lm = { reverse = true },
        short_name = 't',
        used_for = 2,
      },
    }

    screen:expect(function()
      -- Default 'guicursor', published on startup.
      eq(expected_mode_info, screen._mode_info)
      eq(true, screen._cursor_style_enabled)
      eq('normal', screen.mode)
    end)

    -- Event is published ONLY if the cursor style changed.
    screen._mode_info = nil
    command("echo 'test'")
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
      test                     |
    ]],
      condition = function()
        eq(nil, screen._mode_info)
      end,
    }

    -- Change the cursor style.
    n.command('hi Cursor guibg=DarkGray')
    n.command(
      'set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr-o:hor20'
        .. ',a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor'
        .. ',sm:block-blinkwait175-blinkoff150-blinkon175'
    )

    -- Update the expected values.
    for _, m in ipairs(expected_mode_info) do
      if m.name == 'showmatch' then
        if m.blinkon then
          m.blinkon = 175
        end
        if m.blinkoff then
          m.blinkoff = 150
        end
        if m.blinkwait then
          m.blinkwait = 175
        end
      else
        if m.blinkon then
          m.blinkon = 250
        end
        if m.blinkoff then
          m.blinkoff = 400
        end
        if m.blinkwait then
          m.blinkwait = 700
        end
      end
      if m.hl_id then
        m.hl_id = 67
        m.attr = { background = Screen.colors.DarkGray }
      end
      if m.id_lm then
        m.id_lm = 78
        m.attr_lm = {}
      end
    end

    -- Assert the new expectation.
    screen:expect(function()
      for i, v in ipairs(expected_mode_info) do
        eq(v, screen._mode_info[i])
      end
      eq(true, screen._cursor_style_enabled)
      eq('normal', screen.mode)
    end)

    -- Change hl groups only, should update the styles
    n.command('hi Cursor guibg=Red')
    n.command('hi lCursor guibg=Green')

    -- Update the expected values.
    for _, m in ipairs(expected_mode_info) do
      if m.hl_id then
        m.attr = { background = Screen.colors.Red }
      end
      if m.id_lm then
        m.attr_lm = { background = Screen.colors.Green }
      end
    end
    -- Assert the new expectation.
    screen:expect(function()
      eq(expected_mode_info, screen._mode_info)
      eq(true, screen._cursor_style_enabled)
      eq('normal', screen.mode)
    end)

    -- update the highlight again to hide cursor
    n.command('hi Cursor blend=100')

    for _, m in ipairs(expected_mode_info) do
      if m.hl_id then
        m.attr = { background = Screen.colors.Red, blend = 100 }
      end
    end
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
      test                     |
    ]],
      condition = function()
        eq(expected_mode_info, screen._mode_info)
      end,
    }

    -- Another cursor style.
    api.nvim_set_option_value(
      'guicursor',
      'n-v-c:ver35-blinkwait171-blinkoff172-blinkon173'
        .. ',ve:hor35,o:ver50,i-ci:block,r-cr:hor90,sm:ver42',
      {}
    )
    screen:expect(function()
      local named = {}
      for _, m in ipairs(screen._mode_info) do
        named[m.name] = m
      end
      eq('vertical', named.normal.cursor_shape)
      eq(35, named.normal.cell_percentage)
      eq('horizontal', named.visual_select.cursor_shape)
      eq(35, named.visual_select.cell_percentage)
      eq('vertical', named.operator.cursor_shape)
      eq(50, named.operator.cell_percentage)
      eq('block', named.insert.cursor_shape)
      eq('vertical', named.showmatch.cursor_shape)
      eq(90, named.cmdline_replace.cell_percentage)
      eq(171, named.normal.blinkwait)
      eq(172, named.normal.blinkoff)
      eq(173, named.normal.blinkon)
      eq(42, named.showmatch.cell_percentage)
    end)

    -- If there is no setting for guicursor, it becomes the default setting.
    api.nvim_set_option_value(
      'guicursor',
      'n:ver35-blinkwait171-blinkoff172-blinkon173-Cursor/lCursor',
      {}
    )
    screen:expect(function()
      for _, m in ipairs(screen._mode_info) do
        if m.name ~= 'normal' then
          eq('block', m.cursor_shape or 'block')
          eq(0, m.blinkon or 0)
          eq(0, m.blinkoff or 0)
          eq(0, m.blinkwait or 0)
          eq(0, m.hl_id or 0)
          eq(0, m.id_lm or 0)
        end
      end
    end)
  end)

  it("empty 'guicursor' sets cursor_shape=block in all modes", function()
    api.nvim_set_option_value('guicursor', '', {})
    screen:expect(function()
      -- Empty 'guicursor' sets enabled=false.
      eq(false, screen._cursor_style_enabled)
      for _, m in ipairs(screen._mode_info) do
        if m['cursor_shape'] ~= nil then
          eq('block', m.cursor_shape)
          eq(0, m.blinkon)
          eq(0, m.hl_id)
          eq(0, m.id_lm)
        end
      end
    end)
  end)

  it(':sleep does not hide cursor when sleeping', function()
    n.feed(':sleep 300m | echo 42')
    screen:expect([[
                               |
      {1:~                        }|*3
      :sleep 300m | echo 42^    |
    ]])
    n.feed('\n')
    screen:expect({
      grid = [[
      ^                         |
      {1:~                        }|*3
      :sleep 300m | echo 42    |
    ]],
      timeout = 100,
    })
    screen:expect([[
      ^                         |
      {1:~                        }|*3
      42                       |
    ]])
  end)

  it(':sleep! hides cursor when sleeping', function()
    n.feed(':sleep! 300m | echo 42')
    screen:expect([[
                               |
      {1:~                        }|*3
      :sleep! 300m | echo 42^   |
    ]])
    n.feed('\n')
    screen:expect({
      grid = [[
                               |
      {1:~                        }|*3
      :sleep! 300m | echo 42   |
    ]],
      timeout = 100,
    })
    screen:expect([[
      ^                         |
      {1:~                        }|*3
      42                       |
    ]])
  end)
end)
