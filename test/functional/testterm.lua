-- Functions to test :terminal and the Nvim TUI.
-- Starts a child process in a `:terminal` and sends bytes to the child via nvim_chan_send().
-- Note: the global functional/testutil.lua test-session is _host_ session, _not_
-- the child session.
--
-- - Use `setup_screen()` to test `:terminal` behavior with an arbitrary command.
-- - Use `setup_child_nvim()` to test the Nvim TUI.
--    - NOTE: Only use this if your test actually needs the full lifecycle/capabilities of the
--    builtin Nvim TUI. Most tests should just use `Screen.new()` directly, or plain old API calls.

local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local testprg = n.testprg
local exec_lua = n.exec_lua
local api = n.api
local nvim_prog = n.nvim_prog

local M = {}

function M.feed_data(data)
  if type(data) == 'table' then
    data = table.concat(data, '\n')
  end
  exec_lua('vim.api.nvim_chan_send(vim.b.terminal_job_id, ...)', data)
end

function M.feed_termcode(data)
  M.feed_data('\027' .. data)
end

function M.feed_csi(data)
  M.feed_termcode('[' .. data)
end

function M.make_lua_executor(session)
  return function(code, ...)
    local status, rv = session:request('nvim_exec_lua', code, { ... })
    if not status then
      session:stop()
      error(rv[2])
    end
    return rv
  end
end

-- some t for controlling the terminal. the codes were taken from
-- infocmp xterm-256color which is less what libvterm understands
-- civis/cnorm
function M.hide_cursor()
  M.feed_termcode('[?25l')
end
function M.show_cursor()
  M.feed_termcode('[?25h')
end
-- smcup/rmcup
function M.enter_altscreen()
  M.feed_termcode('[?1049h')
end
function M.exit_altscreen()
  M.feed_termcode('[?1049l')
end
-- character attributes
function M.set_fg(num)
  M.feed_termcode('[38;5;' .. num .. 'm')
end
function M.set_bg(num)
  M.feed_termcode('[48;5;' .. num .. 'm')
end
function M.set_bold()
  M.feed_termcode('[1m')
end
function M.set_italic()
  M.feed_termcode('[3m')
end
function M.set_underline()
  M.feed_termcode('[4m')
end
function M.set_underdouble()
  M.feed_termcode('[4:2m')
end
function M.set_undercurl()
  M.feed_termcode('[4:3m')
end
function M.set_reverse()
  M.feed_termcode('[7m')
end
function M.set_strikethrough()
  M.feed_termcode('[9m')
end
function M.clear_attrs()
  M.feed_termcode('[0;10m')
end
-- mouse
function M.enable_mouse()
  M.feed_termcode('[?1002h')
end
function M.disable_mouse()
  M.feed_termcode('[?1002l')
end

local default_command = { testprg('tty-test') }

--- Runs `cmd` in a :terminal, and returns a `Screen` object.
---
---@param extra_rows? integer Extra rows to add to the default screen.
---@param cmd? string|string[] Command to run in the terminal (default: `{ 'tty-test' }`)
---@param cols? integer Create screen with this many columns (default: 50)
---@param env? table Environment set on the `cmd` job.
---@param screen_opts? table Options for `Screen.new()`.
---@return test.functional.ui.screen # Screen attached to the global (not child) Nvim session.
function M.setup_screen(extra_rows, cmd, cols, env, screen_opts)
  extra_rows = extra_rows and extra_rows or 0
  cmd = cmd and cmd or default_command
  cols = cols and cols or 50

  api.nvim_command('highlight TermCursor cterm=reverse')
  api.nvim_command('highlight StatusLineTerm ctermbg=2 ctermfg=0')
  api.nvim_command('highlight StatusLineTermNC ctermbg=2 ctermfg=8')

  local screen = Screen.new(cols, 7 + extra_rows, screen_opts or { rgb = false })
  screen:add_extra_attr_ids({
    [100] = { foreground = 12 },
    [101] = { foreground = 15, background = 1 },
    [102] = { foreground = 121 },
    [103] = { foreground = 11 },
    [104] = { foreground = 81 },
    [105] = { underline = true, reverse = true },
    [106] = { underline = true, reverse = true, bold = true },
    [107] = { underline = true },
    [108] = { background = 248, foreground = Screen.colors.Black },
    [109] = { bold = true, background = 121, foreground = Screen.colors.Grey0 },
    [110] = { fg_indexed = true, foreground = tonumber('0xe0e000') },
    [111] = { fg_indexed = true, foreground = tonumber('0x4040ff') },
    [112] = { foreground = 4 },
    [113] = { foreground = Screen.colors.SeaGreen4 },
    [114] = { undercurl = true },
    [115] = { underdouble = true },
    [116] = { underline = true, foreground = 12 },
    [117] = { background = 1 },
    [118] = { background = 1, reverse = true },
    [119] = { background = 2, foreground = 8 },
    [120] = { foreground = Screen.colors.Black, background = 2 },
    [121] = { foreground = 130 },
    [122] = { background = 46 },
    [123] = { foreground = 2 },
  })

  api.nvim_command('enew')
  api.nvim_call_function('jobstart', { cmd, { term = true, env = (env and env or nil) } })
  api.nvim_input('<CR>')
  local vim_errmsg = api.nvim_eval('v:errmsg')
  if vim_errmsg and '' ~= vim_errmsg then
    error(vim_errmsg)
  end

  api.nvim_command('setlocal scrollback=10')
  api.nvim_command('startinsert')
  api.nvim_input('<Ignore>') -- Add input to separate two RPC requests

  -- tty-test puts the terminal into raw mode and echoes input. Tests work by
  -- feeding termcodes to control the display and asserting by screen:expect.
  if cmd == default_command and screen_opts == nil then
    -- Wait for "tty ready" to be printed before each test or the terminal may
    -- still be in canonical mode (will echo characters for example).
    local empty_line = (' '):rep(cols)
    local expected = {
      'tty ready' .. (' '):rep(cols - 9),
      '^' .. (' '):rep(cols),
      empty_line,
      empty_line,
      empty_line,
      empty_line,
    }
    for _ = 1, extra_rows do
      table.insert(expected, empty_line)
    end

    table.insert(expected, '{5:-- TERMINAL --}' .. ((' '):rep(cols - 14)))
    screen:expect(table.concat(expected, '|\n') .. '|')
  else
    -- This eval also acts as a poke_eventloop().
    if 0 == api.nvim_eval("exists('b:terminal_job_id')") then
      error('terminal job failed to start')
    end
  end
  return screen
end

--- Spawns Nvim with `args` in a :terminal, and returns a `Screen` object.
---
--- @note Only use this if you actually need the full lifecycle/capabilities of the builtin Nvim
--- TUI. Most tests should just use `Screen.new()` directly, or plain old API calls.
---
---@param args? string[] Args passed to child Nvim.
---@param opts? table Options
---@return test.functional.ui.screen # Screen attached to the global (not child) Nvim session.
function M.setup_child_nvim(args, opts)
  opts = opts or {}
  local argv = { nvim_prog, unpack(args or {}) }

  local env = opts.env or {}
  if not env.VIMRUNTIME then
    env.VIMRUNTIME = os.getenv('VIMRUNTIME')
  end

  return M.setup_screen(opts.extra_rows, argv, opts.cols, env)
end

return M
