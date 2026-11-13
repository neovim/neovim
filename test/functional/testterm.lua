-- Functions to test :terminal and the Nvim TUI.
-- Starts a child process in a `:terminal` and sends bytes to the child via nvim_chan_send().
-- Note: the global functional/testutil.lua test-session is _host_ session, _not_
-- the child session.
--
-- - Use `setup_screen()` to test `:terminal` behavior with an arbitrary command.
-- - Use `setup_child_nvim()` to test the Nvim TUI.
--    - NOTE: Only use this if your test actually needs the full lifecycle/capabilities of the
--    builtin Nvim TUI. Most tests should just use `Screen.new()` directly, or plain old API calls.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local testprg = n.testprg
local exec_lua = n.exec_lua
local api = n.api
local nvim_prog = n.nvim_prog
local retry = t.retry
local eq = t.eq

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

--- @param session test.Session
--- @return fun(code: string, ...):any
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

-- some helpers for controlling the terminal. the codes were taken from
-- infocmp xterm-256color.
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
    [110] = { fg_indexed = true, foreground = tonumber('0xf0c674') },
    [111] = { fg_indexed = true, foreground = tonumber('0x7aa6da') },
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

  local env = t.shallowcopy(opts.env) or {}
  env.VIMRUNTIME = env.VIMRUNTIME or os.getenv('VIMRUNTIME')
  env.NVIM_TEST = env.NVIM_TEST or os.getenv('NVIM_TEST')
  -- Child servers need the socket dir set by runner.lua.
  env.XDG_RUNTIME_DIR = env.XDG_RUNTIME_DIR or os.getenv('XDG_RUNTIME_DIR')

  local screen = M.setup_screen(opts.extra_rows, argv, opts.cols, env)
  if t.is_os('win') then
    M.override_screen_expect_for_conpty(screen)
  end
  return screen
end

--- Moves the blank cells and cursor marker at the edges of each attribute group of a screen line out
--- of the group, leaving `{MATCH:…}` patterns as they are.
---
--- @param line string
--- @return string
local function strip_blank_attrs(line)
  -- Split the line into groups of chunks, where a chunk is a character or a {MATCH:…} pattern, and
  -- text outside attribute groups is a group without an id.
  local groups = {} --- @type { id: string?, [integer]: string }[]
  local group = { id = nil } --- @type { id: string?, [integer]: string }
  local i = 1
  while i <= #line do
    local _, match_end = line:find('^{MATCH:.-}', i)
    local id, text_start = line:match('^{(%d+):()', i)
    if match_end then
      group[#group + 1] = line:sub(i, match_end)
      i = match_end + 1
    elseif not group.id and id then
      groups[#groups + 1] = group
      group = { id = id }
      i = text_start
    elseif group.id and line:sub(i, i) == '}' then
      groups[#groups + 1] = group
      group = { id = nil }
      i = i + 1
    else
      group[#group + 1] = line:sub(i, i)
      i = i + 1
    end
  end
  groups[#groups + 1] = group

  local out = {} --- @type string[]
  local out_id --- @type string? Attribute group open in `out`.
  local function emit(s, id)
    if out_id ~= id then
      out[#out + 1] = (out_id and '}' or '') .. (id and '{' .. id .. ':' or '')
      out_id = id
    end
    out[#out + 1] = s
  end
  for _, g in ipairs(groups) do
    local first, last = #g + 1, 0
    for j, chunk in ipairs(g) do
      if chunk ~= ' ' and chunk ~= '^' then
        first = math.min(first, j)
        last = j
      end
    end
    for j, chunk in ipairs(g) do
      emit(chunk, (j >= first and j <= last) and g.id or nil)
    end
  end
  emit('', nil)
  return table.concat(out)
end

--- FIXME: On Windows, ConPTY may redraw blank cells with the wrong attributes. Remove this
--- function when that's fixed.
---
--- Ignores the attributes of blank cells at the edges of attribute groups, on both sides of
--- `screen:expect()`.
---
--- @param screen test.functional.ui.screen
function M.override_screen_expect_for_conpty(screen)
  local orig_row_repr = screen._row_repr
  function screen._row_repr(...)
    return strip_blank_attrs(orig_row_repr(...))
  end

  local function strip_grid(grid)
    -- Dedent first, and keep screen:expect() from dedenting blank cells moved out of a group.
    return (
      t.dedent(grid, 0):gsub('[^\n]+', function(line)
        local row, suffix = line:match('^(.*)(|%**%d*)$')
        return row and strip_blank_attrs(row):gsub('^ ', '{MATCH: }') .. suffix or line
      end)
    )
  end
  local function strip_patterns(patterns)
    if type(patterns) == 'string' then
      return strip_blank_attrs(patterns)
    end
    return patterns and vim.tbl_map(strip_blank_attrs, patterns)
  end

  local orig_screen_expect = screen.expect
  function screen.expect(self, expected, attr_ids, ...)
    if type(expected) == 'string' then
      expected = strip_grid(expected)
    elseif type(expected) == 'table' then
      expected = t.shallowcopy(expected)
      expected.grid = expected.grid and strip_grid(expected.grid)
      expected.any = strip_patterns(expected.any)
      expected.none = strip_patterns(expected.none)
    end
    orig_screen_expect(self, expected, attr_ids, ...)
  end
end

--- Asserts that the exit code of chan eventually matches the expected exit code
---
--- @param code integer expected exit code
--- @param chan? integer channel id, defaults to current buffer's channel
function M.expect_exitcode(code, chan)
  chan = chan or api.nvim_get_option_value('channel', { buf = 0 }) or 0
  eq(true, chan > 0, 'Expected a valid channel ID, but got: ' .. chan)

  retry(nil, nil, function()
    local info = api.nvim_get_chan_info(chan)
    eq(code, info.exitcode)
  end)
end

return M
