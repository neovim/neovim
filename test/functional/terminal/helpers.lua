local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local nvim_dir = helpers.nvim_dir
local execute, nvim, wait = helpers.execute, helpers.nvim, helpers.wait

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


local function screen_setup(extra_height, command)
  nvim('command', 'highlight TermCursor cterm=reverse')
  nvim('command', 'highlight TermCursorNC ctermbg=11')
  nvim('set_var', 'terminal_scrollback_buffer_size', 10)
  if not extra_height then extra_height = 0 end
  if not command then command = default_command end
  local screen = Screen.new(50, 7 + extra_height)
  screen:set_default_attr_ids({
    [1] = {reverse = true},   -- focused cursor
    [2] = {background = 11},  -- unfocused cursor
  })
  screen:set_default_attr_ignore({
    [1] = {bold = true},
    [2] = {foreground = 12},
    [3] = {bold = true, reverse = true},
    [5] = {background = 11},
    [6] = {foreground = 130},
    [7] = {foreground = 15, background = 1}, -- error message
  })

  screen:attach(false)
  -- tty-test puts the terminal into raw mode and echoes all input. tests are
  -- done by feeding it with terminfo codes to control the display and
  -- verifying output with screen:expect.
  execute('enew | call termopen('..command..') | startinsert')
  if command == default_command then
    -- wait for "tty ready" to be printed before each test or the terminal may
    -- still be in canonical mode(will echo characters for example)
    --
    local empty_line =  '                                                   '
    local expected = {
      'tty ready                                          ',
      '{1: }                                                  ',
      empty_line,
      empty_line,
      empty_line,
      empty_line,
    }
    for _ = 1, extra_height do
      table.insert(expected, empty_line)
    end

    table.insert(expected, '-- TERMINAL --                                     ')
    screen:expect(table.concat(expected, '\n'))
  else
    wait()
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
