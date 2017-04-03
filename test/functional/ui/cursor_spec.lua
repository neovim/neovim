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
    command('redraw')
    screen:expect('', nil, nil, nil, true)  -- Tickle the event-loop.
    local expected_cursor_style = {
      cmdline_hover = {
        mouse_shape = 0,
        short_name = 'e' },
      cmdline_insert = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        hl_id = 45,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'ci' },
      cmdline_normal = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 45,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'c' },
      cmdline_replace = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        hl_id = 45,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'cr' },
      insert = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 25,
        cursor_shape = 'vertical',
        hl_id = 45,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'i' },
      more = {
        mouse_shape = 0,
        short_name = 'm' },
      more_lastline = {
        mouse_shape = 0,
        short_name = 'ml' },
      normal = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 45,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'n' },
      operator = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 50,
        cursor_shape = 'horizontal',
        hl_id = 45,
        id_lm = 45,
        mouse_shape = 0,
        short_name = 'o' },
      replace = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 20,
        cursor_shape = 'horizontal',
        hl_id = 45,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'r' },
      showmatch = {
        blinkoff = 150,
        blinkon = 175,
        blinkwait = 175,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 45,
        id_lm = 45,
        short_name = 'sm' },
      statusline_drag = {
        mouse_shape = 0,
        short_name = 'sd' },
      statusline_hover = {
        mouse_shape = 0,
        short_name = 's' },
      visual = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 0,
        cursor_shape = 'block',
        hl_id = 45,
        id_lm = 46,
        mouse_shape = 0,
        short_name = 'v' },
      visual_select = {
        blinkoff = 250,
        blinkon = 400,
        blinkwait = 700,
        cell_percentage = 35,
        cursor_shape = 'vertical',
        hl_id = 45,
        id_lm = 45,
        mouse_shape = 0,
        short_name = 've' },
      vsep_drag = {
        mouse_shape = 0,
        short_name = 'vd' },
      vsep_hover = {
        mouse_shape = 0,
        short_name = 'vs' }
      }
    -- Default 'guicursor' published on startup.
    eq(expected_cursor_style, screen._cursor_style)
    eq('normal', screen.mode)

    -- Event is published ONLY if the cursor style changed.
    screen._cursor_style = nil
    command('redraw')
    screen:expect('', nil, nil, nil, true)  -- Tickle the event-loop.
    eq(nil, screen._cursor_style)

    -- Change the cursor style.
    meths.set_option('guicursor', 'n-v-c:ver35-blinkwait171-blinkoff172-blinkon173,ve:hor35,o:ver50,i-ci:block,r-cr:hor90,sm:ver42')
    command('redraw')
    screen:expect('', nil, nil, nil, true)  -- Tickle the event-loop.
    eq('vertical', screen._cursor_style.normal.cursor_shape)
    eq('horizontal', screen._cursor_style.visual_select.cursor_shape)
    eq('vertical', screen._cursor_style.operator.cursor_shape)
    eq('block', screen._cursor_style.insert.cursor_shape)
    eq('vertical', screen._cursor_style.showmatch.cursor_shape)
    eq(171, screen._cursor_style.normal.blinkwait)
    eq(172, screen._cursor_style.normal.blinkoff)
    eq(173, screen._cursor_style.normal.blinkon)
  end)

  it("empty 'guicursor' sets cursor_shape=block in all modes", function()
    meths.set_option('guicursor', '')
    command('redraw')
    screen:expect('', nil, nil, nil, true)  -- Tickle the event-loop.
    for _, m in ipairs({ 'cmdline_insert', 'cmdline_normal', 'cmdline_replace', 'insert',
                         'showmatch', 'normal', 'replace', 'visual',
                         'visual_select', }) do
      eq('block', screen._cursor_style[m].cursor_shape)
      eq(0, screen._cursor_style[m].blinkon)
    end
  end)

end)
