-- To test tui/input.c, this module spawns `nvim` inside :terminal and sends
-- bytes via jobsend().  Note: the functional/helpers.lua test-session methods
-- operate on the _host_ session, _not_ the child session.
local helpers = require('test.functional.helpers')(nil)
local Screen = require('test.functional.ui.screen')
local nvim_dir = helpers.nvim_dir
local feed_command, nvim = helpers.feed_command, helpers.nvim

local function feed_data(data)
  nvim('set_var', 'term_data', data)
  nvim('command', 'call jobsend(b:terminal_job_id, term_data)')
end

local function feed_termcode(data)
  -- feed with the job API
  nvim('command', 'call jobsend(b:terminal_job_id, "\\x1b'..data..'")')
end
-- some helpers for controlling the terminal. the codes were taken from
-- infocmp xterm-256color which is less what libvterm understands
-- civis/cnorm
local function hide_cursor() feed_termcode('[?25l') end
local function show_cursor() feed_termcode('[?25h') end
-- smcup/rmcup
local function enter_altscreen() feed_termcode('[?1049h') end
local function exit_altscreen() feed_termcode('[?1049l') end
-- character attributes
local function set_fg(num) feed_termcode('[38;5;'..num..'m') end
local function set_bg(num) feed_termcode('[48;5;'..num..'m') end
local function set_bold() feed_termcode('[1m') end
local function set_italic() feed_termcode('[3m') end
local function set_underline() feed_termcode('[4m') end
local function clear_attrs() feed_termcode('[0;10m') end
-- mouse
local function enable_mouse() feed_termcode('[?1002h') end
local function disable_mouse() feed_termcode('[?1002l') end

local default_command = '["'..nvim_dir..'/tty-test'..'"]'

local function screen_setup(extra_rows, command, cols, opts)
  extra_rows = extra_rows and extra_rows or 0
  command = command and command or default_command
  cols = cols and cols or 50

  nvim('command', 'highlight TermCursor cterm=reverse')
  nvim('command', 'highlight TermCursorNC ctermbg=11')

  local screen = Screen.new(cols, 7 + extra_rows)
  screen:set_default_attr_ids({
    [1] = {reverse = true},   -- focused cursor
    [2] = {background = 11},  -- unfocused cursor
    [3] = {bold = true},
    [4] = {foreground = 12},
    [5] = {bold = true, reverse = true},
    [6] = {background = 11},
    [7] = {foreground = 130},
    [8] = {foreground = 15, background = 1}, -- error message
    [9] = {foreground = 4},
    [10] = {foreground = 121},  -- "Press ENTER" in embedded :terminal session.
    [11] = {foreground = tonumber('0x00000b')},
    [12] = {reverse = true, foreground = tonumber('0x000079')},
  })

  screen:attach(opts or {rgb=false})

  feed_command('enew | call termopen('..command..')')
  nvim('input', '<CR>')
  local vim_errmsg = nvim('eval', 'v:errmsg')
  if vim_errmsg and "" ~= vim_errmsg then
    error(vim_errmsg)
  end

  feed_command('setlocal scrollback=10')
  feed_command('startinsert')

  -- tty-test puts the terminal into raw mode and echoes input. Tests work by
  -- feeding termcodes to control the display and asserting by screen:expect.
  if command == default_command and opts == nil then
    -- Wait for "tty ready" to be printed before each test or the terminal may
    -- still be in canonical mode (will echo characters for example).
    local empty_line = (' '):rep(cols)
    local expected = {
      'tty ready'..(' '):rep(cols - 9),
      '{1: }'    ..(' '):rep(cols - 1),
      empty_line,
      empty_line,
      empty_line,
      empty_line,
    }
    for _ = 1, extra_rows do
      table.insert(expected, empty_line)
    end

    table.insert(expected, '{3:-- TERMINAL --}' .. ((' '):rep(cols - 14)))
    screen:expect(table.concat(expected, '|\n')..'|')
  else
    -- This eval also acts as a wait().
    if 0 == nvim('eval', "exists('b:terminal_job_id')") then
      error("terminal job failed to start")
    end
  end
  return screen
end

return {
  feed_data = feed_data,
  feed_termcode = feed_termcode,
  hide_cursor = hide_cursor,
  show_cursor = show_cursor,
  enter_altscreen = enter_altscreen,
  exit_altscreen = exit_altscreen,
  set_fg = set_fg,
  set_bg = set_bg,
  set_bold = set_bold,
  set_italic = set_italic,
  set_underline = set_underline,
  clear_attrs = clear_attrs,
  enable_mouse = enable_mouse,
  disable_mouse = disable_mouse,
  screen_setup = screen_setup
}
