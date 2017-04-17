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
    local expected_cursor_style = {
      cmdline_hover = {
        mode_idx = 9,
        mouse_shape = 0,
        short_name = 'e' },
      cmdline_insert = {
        mode_idx = 5,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'ci' },
      cmdline_normal = {
        mode_idx = 4,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'c' },
      cmdline_replace = {
        mode_idx = 6,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'cr' },
      insert = {
        mode_idx = 2,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'i' },
      more = {
        mode_idx = 14,
        mouse_shape = 0,
        short_name = 'm' },
      more_lastline = {
        mode_idx = 15,
        mouse_shape = 0,
        short_name = 'ml' },
      normal = {
        mode_idx = 0,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'n' },
      operator = {
        mode_idx = 7,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 50,
        cursor_shape = 'horizontal',
        hl_id = 46,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'o' },
      replace = {
        mode_idx = 3,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'r' },
      showmatch = {
        mode_idx = 16,
        blinkoff = 150,
        blinkon = 175,
        blinkwait = 175,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 46,
        id_lm = 46,
        short_name = 'sm' },
      statusline_drag = {
        mode_idx = 11,
        mouse_shape = 0,
        short_name = 'sd' },
      statusline_hover = {
        mode_idx = 10,
        mouse_shape = 0,
        short_name = 's' },
      visual = {
        mode_idx = 1,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 46,
        id_lm = 47,
        mouse_shape = 0,
        short_name = 'v' },
      visual_select = {
        mode_idx = 8,
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 35,
        cursor_shape = 'vertical',
        hl_id = 46,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 've' },
      vsep_drag = {
        mode_idx = 13,
        mouse_shape = 0,
        short_name = 'vd' },
      vsep_hover = {
        mode_idx = 12,
        mouse_shape = 0,
        short_name = 'vs' }
    }

    screen:expect(function()
      -- Default 'guicursor' published on startup.
      eq(expected_cursor_style, screen._cursor_style)
      eq(true, screen._cursor_style_enabled)
      eq('normal', screen.mode)
    end)

    -- Event is published ONLY if the cursor style changed.
    screen._cursor_style = nil
    command("echo 'test'")
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      test                     |
    ]], nil, nil, function()
      eq(nil, screen._cursor_style)
    end)

    -- Change the cursor style.
    meths.set_option('guicursor', 'n-v-c:ver35-blinkwait171-blinkoff172-blinkon173,ve:hor35,o:ver50,i-ci:block,r-cr:hor90,sm:ver42')
    screen:expect(function()
      eq('vertical', screen._cursor_style.normal.cursor_shape)
      eq('horizontal', screen._cursor_style.visual_select.cursor_shape)
      eq('vertical', screen._cursor_style.operator.cursor_shape)
      eq('block', screen._cursor_style.insert.cursor_shape)
      eq('vertical', screen._cursor_style.showmatch.cursor_shape)
      eq(171, screen._cursor_style.normal.blinkwait)
      eq(172, screen._cursor_style.normal.blinkoff)
      eq(173, screen._cursor_style.normal.blinkon)
    end)
  end)

  it("empty 'guicursor' sets cursor_shape=block in all modes", function()
    meths.set_option('guicursor', '')
    screen:expect(function()
      -- Empty 'guicursor' sets enabled=false.
      eq(false, screen._cursor_style_enabled)
      for _, m in ipairs({ 'cmdline_insert', 'cmdline_normal', 'cmdline_replace', 'insert',
                           'showmatch', 'normal', 'replace', 'visual',
                           'visual_select', }) do
        eq('block', screen._cursor_style[m].cursor_shape)
        eq(0, screen._cursor_style[m].blinkon)
      end
    end)
  end)

end)
