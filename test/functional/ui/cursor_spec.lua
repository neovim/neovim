local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, api = n.clear, n.api
local eq = t.eq
local eq_partial = t.eq_partial
local command = n.command

describe('ui/cursor', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
  end)

  it("'guicursor' is published as a UI event", function()
    local function cursor_mode(overrides)
      return vim.tbl_extend('force', {
        blinkoff = 0,
        blinkon = 0,
        blinkwait = 0,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 0,
        id_lm = 0,
        attr = {},
        attr_lm = {},
      }, overrides)
    end

    local expected_mode_info = {
      [1] = cursor_mode({ name = 'normal', mouse_shape = 0, short_name = 'n' }),
      [2] = cursor_mode({ name = 'visual', mouse_shape = 0, short_name = 'v' }),
      [3] = cursor_mode({
        cell_percentage = 25,
        cursor_shape = 'vertical',
        name = 'insert',
        mouse_shape = 0,
        short_name = 'i',
      }),
      [4] = cursor_mode({
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        name = 'replace',
        mouse_shape = 0,
        short_name = 'r',
      }),
      [5] = cursor_mode({ name = 'cmdline_normal', mouse_shape = 0, short_name = 'c' }),
      [6] = cursor_mode({
        cell_percentage = 25,
        cursor_shape = 'vertical',
        name = 'cmdline_insert',
        mouse_shape = 0,
        short_name = 'ci',
      }),
      [7] = cursor_mode({
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        name = 'cmdline_replace',
        mouse_shape = 0,
        short_name = 'cr',
      }),
      [8] = cursor_mode({
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        name = 'operator',
        mouse_shape = 0,
        short_name = 'o',
      }),
      [9] = cursor_mode({
        cell_percentage = 25,
        cursor_shape = 'vertical',
        name = 'visual_select',
        mouse_shape = 0,
        short_name = 've',
      }),
      [10] = { name = 'cmdline_hover', mouse_shape = 0, short_name = 'e' },
      [11] = { name = 'statusline_hover', mouse_shape = 0, short_name = 's' },
      [12] = { name = 'statusline_drag', mouse_shape = 0, short_name = 'sd' },
      [13] = { name = 'vsep_hover', mouse_shape = 0, short_name = 'vs' },
      [14] = { name = 'vsep_drag', mouse_shape = 0, short_name = 'vd' },
      [15] = { name = 'more', mouse_shape = 0, short_name = 'm' },
      [16] = { name = 'more_lastline', mouse_shape = 0, short_name = 'ml' },
      [17] = cursor_mode({ name = 'showmatch', short_name = 'sm' }),
      [18] = cursor_mode({
        blinkoff = 500,
        blinkon = 500,
        name = 'terminal',
        hl_id = 3,
        id_lm = 3,
        attr = { reverse = true },
        attr_lm = { reverse = true },
        short_name = 't',
      }),
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
        m.id_lm = 82
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
      eq_partial({
        normal = { cursor_shape = 'vertical', cell_percentage = 35 },
        visual_select = { cursor_shape = 'horizontal', cell_percentage = 35 },
        operator = { cursor_shape = 'vertical', cell_percentage = 50 },
        insert = { cursor_shape = 'block' },
        showmatch = { cursor_shape = 'vertical', cell_percentage = 42 },
        cmdline_replace = { cell_percentage = 90 },
      }, named)
      eq_partial({ blinkwait = 171, blinkoff = 172, blinkon = 173 }, named.normal)
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
          eq_partial({ cursor_shape = 'block', blinkon = 0, hl_id = 0, id_lm = 0 }, m)
        end
      end
    end)
  end)

  it("'set all&' reapplies 'guicursor'", function()
    command('set guicursor=n:ver25')
    screen:expect(function()
      eq('vertical', screen._mode_info[1].cursor_shape)
      eq(25, screen._mode_info[1].cell_percentage)
    end)

    command('set all&')
    screen:expect(function()
      eq_partial({ cursor_shape = 'block', blinkon = 0, blinkoff = 0 }, screen._mode_info[1])
      eq(true, screen._cursor_style_enabled)
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
