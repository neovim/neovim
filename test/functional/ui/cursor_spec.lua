local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, meths = helpers.clear, helpers.meths
local eq = helpers.eq
local command = helpers.command

describe('ui/cursor', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)

  after_each(function()
    screen:detach()
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
        mouse_shape = 0,
        short_name = 'n' },
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
        mouse_shape = 0,
        short_name = 'v' },
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
        mouse_shape = 0,
        short_name = 'i' },
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
        mouse_shape = 0,
        short_name = 'r' },
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
        mouse_shape = 0,
        short_name = 'c' },
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
        mouse_shape = 0,
        short_name = 'ci' },
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
        mouse_shape = 0,
        short_name = 'cr' },
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
        mouse_shape = 0,
        short_name = 'o' },
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
        mouse_shape = 0,
        short_name = 've' },
      [10] = {
        name = 'cmdline_hover',
        mouse_shape = 0,
        short_name = 'e' },
      [11] = {
        name = 'statusline_hover',
        mouse_shape = 0,
        short_name = 's' },
      [12] = {
        name = 'statusline_drag',
        mouse_shape = 0,
        short_name = 'sd' },
      [13] = {
        name = 'vsep_hover',
        mouse_shape = 0,
        short_name = 'vs' },
      [14] = {
        name = 'vsep_drag',
        mouse_shape = 0,
        short_name = 'vd' },
      [15] = {
        name = 'more',
        mouse_shape = 0,
        short_name = 'm' },
      [16] = {
        name = 'more_lastline',
        mouse_shape = 0,
        short_name = 'ml' },
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
        short_name = 'sm' },
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
    screen:expect{grid=[[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      test                     |
    ]], condition=function()
      eq(nil, screen._mode_info)
    end}

    -- Change the cursor style.
    helpers.command('hi Cursor guibg=DarkGray')
    helpers.command('set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr-o:hor20'
      ..',a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor'
      ..',sm:block-blinkwait175-blinkoff150-blinkon175')

    -- Update the expected values.
    for _, m in ipairs(expected_mode_info) do
      if m.name == 'showmatch' then
        if m.blinkon then m.blinkon = 175 end
        if m.blinkoff then m.blinkoff = 150 end
        if m.blinkwait then m.blinkwait = 175 end
      else
        if m.blinkon then m.blinkon = 250 end
        if m.blinkoff then m.blinkoff = 400 end
        if m.blinkwait then m.blinkwait = 700 end
      end
      if m.hl_id then
          m.hl_id = 54
          m.attr = {background = Screen.colors.DarkGray}
      end
      if m.id_lm then m.id_lm = 55 end
    end

    -- Assert the new expectation.
    screen:expect(function()
      eq(expected_mode_info, screen._mode_info)
      eq(true, screen._cursor_style_enabled)
      eq('normal', screen.mode)
    end)

    -- Change hl groups only, should update the styles
    helpers.command('hi Cursor guibg=Red')
    helpers.command('hi lCursor guibg=Green')

    -- Update the expected values.
    for _, m in ipairs(expected_mode_info) do
      if m.hl_id then
          m.attr = {background = Screen.colors.Red}
      end
      if m.id_lm then
          m.attr_lm = {background = Screen.colors.Green}
      end
    end
    -- Assert the new expectation.
    screen:expect(function()
      eq(expected_mode_info, screen._mode_info)
      eq(true, screen._cursor_style_enabled)
      eq('normal', screen.mode)
    end)

    -- Another cursor style.
    meths.set_option('guicursor', 'n-v-c:ver35-blinkwait171-blinkoff172-blinkon173'
      ..',ve:hor35,o:ver50,i-ci:block,r-cr:hor90,sm:ver42')
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
  end)

  it("empty 'guicursor' sets cursor_shape=block in all modes", function()
    meths.set_option('guicursor', '')
    screen:expect(function()
      -- Empty 'guicursor' sets enabled=false.
      eq(false, screen._cursor_style_enabled)
      for _, m in ipairs(screen._mode_info) do
        if m['cursor_shape'] ~= nil then
          eq('block', m.cursor_shape)
          eq(0, m.blinkon)
        end
      end
    end)
  end)

end)
