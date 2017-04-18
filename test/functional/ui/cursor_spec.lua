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
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'normal',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'n' },
      [2] = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'visual',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'v' },
      [3] = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        name = 'insert',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'i' },
      [4] = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        name = 'replace',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'r' },
      [5] = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'cmdline_normal',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'c' },
      [6] = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        name = 'cmdline_insert',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'ci' },
      [7] = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        name = 'cmdline_replace',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'cr' },
      [8] = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 50,
        cursor_shape = 'horizontal',
        name = 'operator',
        hl_id = 46,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'o' },
      [9] = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 35,
        cursor_shape = 'vertical',
        name = 'visual_select',
        hl_id = 46,
        id_lm = 46,
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
        blinkoff = 150,
        blinkon = 175,
        blinkwait = 175,
        cell_percentage = 0,
        cursor_shape = 'block',
        name = 'showmatch',
        hl_id = 46,
        id_lm = 46,
        short_name = 'sm' },
      }

    screen:expect(function()
      -- Default 'guicursor' published on startup.
      eq(expected_mode_info, screen._mode_info)
      eq(true, screen._cursor_style_enabled)
      eq('normal', screen.mode)
    end)

    -- Event is published ONLY if the cursor style changed.
    screen._mode_info = nil
    command("echo 'test'")
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      test                     |
    ]], nil, nil, function()
      eq(nil, screen._mode_info)
    end)

    -- Change the cursor style.
    meths.set_option('guicursor', 'n-v-c:ver35-blinkwait171-blinkoff172-blinkon173,ve:hor35,o:ver50,i-ci:block,r-cr:hor90,sm:ver42')
    screen:expect(function()
      local named = {}
      for _, m in ipairs(screen._mode_info) do
        named[m.name] = m
      end
      eq('vertical', named.normal.cursor_shape)
      eq('horizontal', named.visual_select.cursor_shape)
      eq('vertical', named.operator.cursor_shape)
      eq('block', named.insert.cursor_shape)
      eq('vertical', named.showmatch.cursor_shape)
      eq(171, named.normal.blinkwait)
      eq(172, named.normal.blinkoff)
      eq(173, named.normal.blinkon)
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
