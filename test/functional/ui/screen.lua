-- This module contains the Screen class, a complete Nvim UI implementation
-- designed for functional testing (verifying screen state, in particular).
--
-- Screen:expect() takes a string representing the expected screen state and an
-- optional set of attribute identifiers for checking highlighted characters.
--
-- Example usage:
--
--     -- Attach a screen to the current Nvim instance.
--     local screen = Screen.new(25, 10)
--     -- Enter insert-mode and type some text.
--     feed('ihello screen')
--     -- Assert the expected screen state.
--     screen:expect([[
--       hello screen^             |
--       {1:~                        }|*8
--       {5:-- INSERT --}             |
--     ]]) -- <- Last line is stripped
--
-- Since screen updates are received asynchronously, expect() actually specifies
-- the _eventual_ screen state.
--
-- This is how expect() works:
--  * It starts the event loop with a timeout.
--  * Each time it receives an update it checks that against the expected state.
--    * If the expected state matches the current state, the event loop will be
--      stopped and expect() will return.
--    * If the timeout expires, the last match error will be reported and the
--      test will fail.
--
-- The 30 most common highlight groups are predefined, see init_colors() below.
-- In this case "5" is a predefined highlight associated with the set composed of one
-- attribute: bold. Note that since the {5:} markup is not a real part of the
-- screen, the delimiter "|" moved to the right. Also, the highlighting of the
-- NonText markers "~" is visible.
--
-- Tests will often share a group of extra attribute sets to expect(). Those can be
-- defined at the beginning of a test:
--
--    screen:add_extra_attr_ids({
--      [100] = { background = Screen.colors.Plum1, underline = true },
--      [101] = { background = Screen.colors.Red1, bold = true, underline = true },
--    })
--
-- To help write screen tests, see Screen:snapshot_util().
-- To debug screen tests, see Screen:redraw_debug().

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local busted = require('busted')

local deepcopy = vim.deepcopy
local shallowcopy = t.shallowcopy
local concat_tables = t.concat_tables
local pesc = vim.pesc
local run_session = n.run_session
local eq = t.eq
local dedent = t.dedent
local get_session = n.get_session
local create_callindex = n.create_callindex

local inspect = vim.inspect

local function isempty(v)
  return type(v) == 'table' and next(v) == nil
end

--- @class test.functional.ui.screen.Grid
--- @field rows table[][]
--- @field width integer
--- @field height integer

--- @class test.functional.ui.screen
--- @field colors table<string,integer>
--- @field colornames table<integer,string>
--- @field uimeths table<string,function>
--- @field options? table<string,any>
--- @field timeout integer
--- @field win_position table<integer,table<string,integer>>
--- @field float_pos table<integer,table>
--- @field cmdline table<integer,table>
--- @field cmdline_hide_level integer?
--- @field cmdline_block table[]
--- @field hl_groups table<string,integer>
--- @field messages table<integer,table>
--- @field private _cursor {grid:integer,row:integer,col:integer}
--- @field private _grids table<integer,test.functional.ui.screen.Grid>
--- @field private _grid_win_extmarks table<integer,table>
--- @field private _attr_table table<integer,table>
--- @field private _hl_info table<integer,table>
local Screen = {}
Screen.__index = Screen

local default_timeout_factor = 1
if os.getenv('VALGRIND') then
  default_timeout_factor = default_timeout_factor * 3
end

if os.getenv('CI') then
  default_timeout_factor = default_timeout_factor * 3
end

local default_screen_timeout = default_timeout_factor * 3500

local function _init_colors()
  local session = get_session()
  local status, rv = session:request('nvim_get_color_map')
  if not status then
    error('failed to get color map')
  end
  local colors = rv --- @type table<string,integer>
  local colornames = {} --- @type table<integer,string>
  for name, rgb in pairs(colors) do
    -- we disregard the case that colornames might not be unique, as
    -- this is just a helper to get any canonical name of a color
    colornames[rgb] = name
  end
  Screen.colors = colors
  Screen.colornames = colornames

  Screen._global_default_attr_ids = {
    [1] = { foreground = Screen.colors.Blue1, bold = true },
    [2] = { reverse = true },
    [3] = { bold = true, reverse = true },
    [4] = { background = Screen.colors.LightMagenta },
    [5] = { bold = true },
    [6] = { foreground = Screen.colors.SeaGreen, bold = true },
    [7] = { background = Screen.colors.Gray, foreground = Screen.colors.DarkBlue },
    [8] = { foreground = Screen.colors.Brown },
    [9] = { background = Screen.colors.Red, foreground = Screen.colors.Grey100 },
    [10] = { background = Screen.colors.Yellow },
    [11] = {
      foreground = Screen.colors.Blue1,
      background = Screen.colors.LightMagenta,
      bold = true,
    },
    [12] = { background = Screen.colors.Gray },
    [13] = { background = Screen.colors.LightGrey, foreground = Screen.colors.DarkBlue },
    [14] = { background = Screen.colors.DarkGray, foreground = Screen.colors.LightGrey },
    [15] = { foreground = Screen.colors.Brown, bold = true },
    [16] = { foreground = Screen.colors.SlateBlue },
    [17] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Black },
    [18] = { foreground = Screen.colors.Blue1 },
    [19] = { foreground = Screen.colors.Red },
    [20] = { background = Screen.colors.Yellow, foreground = Screen.colors.Red },
    [21] = { background = Screen.colors.Grey90 },
    [22] = { background = Screen.colors.LightBlue },
    [23] = { foreground = Screen.colors.Blue1, background = Screen.colors.LightCyan, bold = true },
    [24] = { background = Screen.colors.LightGrey, underline = true },
    [25] = { foreground = Screen.colors.Cyan4 },
    [26] = { foreground = Screen.colors.Fuchsia },
    [27] = { background = Screen.colors.Red, bold = true },
    [28] = { foreground = Screen.colors.SlateBlue, underline = true },
    [29] = { foreground = Screen.colors.SlateBlue, bold = true },
    [30] = { background = Screen.colors.Red },
  }
end

--- @class test.functional.ui.screen.Opts
--- @field ext_linegrid? boolean
--- @field ext_multigrid? boolean
--- @field ext_newgrid? boolean
--- @field ext_popupmenu? boolean
--- @field ext_wildmenu? boolean
--- @field rgb? boolean
--- @field _debug_float? boolean

--- @param width? integer
--- @param height? integer
--- @param options? test.functional.ui.screen.Opts
--- @param session? test.Session|false
--- @return test.functional.ui.screen
function Screen.new(width, height, options, session)
  if not Screen.colors then
    _init_colors()
  end

  options = options or {}
  if options.ext_linegrid == nil then
    options.ext_linegrid = true
  end

  local self = setmetatable({
    timeout = default_screen_timeout,
    title = '',
    icon = '',
    bell = false,
    update_menu = false,
    visual_bell = false,
    suspended = false,
    mode = 'normal',
    options = {},
    pwd = '',
    popupmenu = nil,
    cmdline = {},
    cmdline_block = {},
    wildmenu_items = nil,
    wildmenu_selected = nil,
    win_position = {},
    win_viewport = {},
    win_viewport_margins = {},
    float_pos = {},
    msg_grid = nil,
    msg_grid_pos = nil,
    _session = nil,
    rpc_async = false,
    messages = {},
    msg_history = {},
    showmode = {},
    showcmd = {},
    ruler = {},
    hl_groups = {},
    _default_attr_ids = nil,
    mouse_enabled = true,
    _attrs = {},
    _hl_info = { [0] = {} },
    _attr_table = { [0] = { {}, {} } },
    _clear_attrs = nil,
    _new_attrs = false,
    _width = width or 53,
    _height = height or 14,
    _options = options,
    _grids = {},
    _grid_win_extmarks = {},
    _cursor = {
      grid = 1,
      row = 1,
      col = 1,
    },
    _busy = false,
  }, Screen)

  local function ui(method, ...)
    if self.rpc_async then
      self._session:notify('nvim_ui_' .. method, ...)
    else
      local status, rv = self._session:request('nvim_ui_' .. method, ...)
      if not status then
        error(rv[2])
      end
    end
  end

  self.uimeths = create_callindex(ui)

  -- session is often nil, which implies the default session
  if session ~= false then
    self:attach(session)
  end

  return self
end

function Screen:set_default_attr_ids(attr_ids)
  self._default_attr_ids = attr_ids
  self._attrs_overridden = true
end

function Screen:add_extra_attr_ids(extra_attr_ids)
  local attr_ids = vim.deepcopy(Screen._global_default_attr_ids)
  for id, attr in pairs(extra_attr_ids) do
    if type(id) == 'number' and id < 100 then
      error('extra attr ids should be at least 100 or be strings')
    end
    attr_ids[id] = attr
  end
  self._default_attr_ids = attr_ids
end

function Screen:get_default_attr_ids()
  return deepcopy(self._default_attr_ids)
end

function Screen:set_rgb_cterm(val)
  self._rgb_cterm = val
end

--- @param session? test.Session
function Screen:attach(session)
  session = session or get_session()
  local options = self._options

  if options.ext_linegrid == nil then
    options.ext_linegrid = true
  end

  self._session = session
  self._options = options
  self._clear_attrs = (not options.ext_linegrid) and {} or nil
  self:_handle_resize(self._width, self._height)
  self.uimeths.attach(self._width, self._height, options)
  if self._options.rgb == nil then
    -- nvim defaults to rgb=true internally,
    -- simplify test code by doing the same.
    self._options.rgb = true
  end
  if self._options.ext_multigrid then
    self._options.ext_linegrid = true
  end

  if self._default_attr_ids == nil then
    self._default_attr_ids = Screen._global_default_attr_ids
  end
end

function Screen:detach()
  self.uimeths.detach()
  self._session = nil
end

function Screen:try_resize(columns, rows)
  self._width = columns
  self._height = rows
  self.uimeths.try_resize(columns, rows)
end

function Screen:try_resize_grid(grid, columns, rows)
  self.uimeths.try_resize_grid(grid, columns, rows)
end

--- @param option 'ext_linegrid'|'ext_multigrid'|'ext_popupmenu'|'ext_wildmenu'|'rgb'
--- @param value boolean
function Screen:set_option(option, value)
  self.uimeths.set_option(option, value)
  --- @diagnostic disable-next-line:no-unknown
  self._options[option] = value
end

-- canonical order of ext keys, used  to generate asserts
local ext_keys = {
  'popupmenu',
  'cmdline',
  'cmdline_block',
  'wildmenu_items',
  'wildmenu_pos',
  'messages',
  'msg_history',
  'showmode',
  'showcmd',
  'ruler',
  'win_pos',
  'float_pos',
  'win_viewport',
  'win_viewport_margins',
}

local expect_keys = {
  grid = true,
  attr_ids = true,
  condition = true,
  mouse_enabled = true,
  any = true,
  mode = true,
  unchanged = true,
  intermediate = true,
  reset = true,
  timeout = true,
  request_cb = true,
  hl_groups = true,
  extmarks = true,
  win_pos = true,
}

for _, v in ipairs(ext_keys) do
  expect_keys[v] = true
end

--- @class test.function.ui.screen.Expect
---
--- Expected screen state (string). Each line represents a screen
--- row. Last character of each row (typically "|") is stripped.
--- Common indentation is stripped.
--- "{MATCH:x}" in a line is matched against Lua pattern `x`.
--- "*n" at the end of a line means it repeats `n` times.
--- @field grid? string
---
--- Expected text attributes. Screen rows are transformed according
--- to this table, as follows: each substring S composed of
--- characters having the same attributes will be substituted by
--- "{K:S}", where K is a key in `attr_ids`. Any unexpected
--- attributes in the final state are an error.
--- Use an empty table for a text-only (no attributes) expectation.
--- Use screen:set_default_attr_ids() to define attributes for many
--- expect() calls.
--- @field attr_ids? table<integer,table<string,any>>
---
--- Expected win_extmarks accumulated for the grids. For each grid,
--- the win_extmark messages are accumulated into an array.
--- @field extmarks? table<integer,table>
---
--- Function asserting some arbitrary condition. Return value is
--- ignored, throw an error (use eq() or similar) to signal failure.
--- @field condition? fun()
---
--- Lua pattern string expected to match a screen line. NB: the
--- following chars are magic characters
---    ( ) . % + - * ? [ ^ $
--- and must be escaped with a preceding % for a literal match.
--- @field any? string
---
--- Expected mode as signaled by "mode_change" event
--- @field mode? string
---
--- Test that the screen state is unchanged since the previous
--- expect(...). Any flush event resulting in a different state is
--- considered an error. Not observing any events until timeout
--- is acceptable.
--- @field unchanged? boolean
---
--- Test that the final state is the same as the previous expect,
--- but expect an intermediate state that is different. If possible
--- it is better to use an explicit screen:expect(...) for this
--- intermediate state.
--- @field intermediate? boolean
---
--- Reset the state internal to the test Screen before starting to
--- receive updates. This should be used after command("redraw!")
--- or some other mechanism that will invoke "redraw!", to check
--- that all screen state is transmitted again. This includes
--- state related to ext_ features as mentioned below.
--- @field reset? boolean
---
--- maximum time that will be waited until the expected state is
--- seen (or maximum time to observe an incorrect change when
--- `unchanged` flag is used)
--- @field timeout? integer
---
--- @field mouse_enabled? boolean
---
--- @field win_viewport? table<integer,table<string,integer>>
--- @field win_pos? table<integer,table<string,integer>>
--- @field float_pos? [integer,integer]
--- @field hl_groups? table<string,integer>
---
--- The following keys should be used to expect the state of various ext_
--- features. Note that an absent key will assert that the item is currently
--- NOT present on the screen, also when positional form is used.
---
--- Expected ext_popupmenu state,
--- @field popupmenu? table
---
--- Expected ext_cmdline state, as an array of cmdlines of
--- different level.
--- @field cmdline? table
---
--- Expected ext_cmdline block (for function definitions)
--- @field cmdline_block? table
---
--- items for ext_wildmenu
--- @field wildmenu_items? table
---
--- position for ext_wildmenu
--- @field wildmenu_pos? table

--- Asserts that the screen state eventually matches an expected state.
---
--- Can be called with positional args:
---    screen:expect(grid, [attr_ids])
---    screen:expect(condition)
--- or keyword args (supports more options):
---    screen:expect({ grid=[[...]], cmdline={...}, condition=function() ... end })
---
--- @param expected string|function|test.function.ui.screen.Expect
--- @param attr_ids? table<integer,table<string,any>>
function Screen:expect(expected, attr_ids, ...)
  --- @type string, fun()
  local grid, condition

  assert(next({ ... }) == nil, 'invalid args to expect()')

  if type(expected) == 'table' then
    assert(attr_ids == nil)
    for k, _ in
      pairs(expected --[[@as table<string,any>]])
    do
      if not expect_keys[k] then
        error("Screen:expect: Unknown keyword argument '" .. k .. "'")
      end
    end
    grid = expected.grid
    attr_ids = expected.attr_ids
    condition = expected.condition
    assert(expected.any == nil or grid == nil)
  elseif type(expected) == 'string' then
    grid = expected
    expected = {}
  elseif type(expected) == 'function' then
    assert(attr_ids == nil)
    condition = expected
    expected = {}
  else
    assert(false)
  end

  local expected_rows = {} --- @type string[]
  if grid then
    -- Dedent (ignores last line if it is blank).
    grid = dedent(grid, 0)
    for row in grid:gmatch('[^\n]+') do
      table.insert(expected_rows, row)
    end
  end

  local attr_state = {
    ids = attr_ids or self._default_attr_ids,
  }

  if isempty(attr_ids) then
    attr_state.ids = nil
  end

  if self._options.ext_linegrid then
    attr_state.id_to_index = self:linegrid_check_attrs(attr_state.ids or {})
  end

  self._new_attrs = false
  self:_wait(function()
    if condition then
      --- @type boolean, string
      local status, res = pcall(condition)
      if not status then
        return tostring(res)
      end
    end

    if self._options.ext_linegrid and self._new_attrs then
      attr_state.id_to_index = self:linegrid_check_attrs(attr_state.ids or {})
    end

    local actual_rows
    if expected.any or grid then
      actual_rows = self:render(not expected.any, attr_state)
    end

    if expected.any then
      -- Search for `any` anywhere in the screen lines.
      local actual_screen_str = table.concat(actual_rows, '\n')
      if not actual_screen_str:find(expected.any) then
        return (
          'Failed to match any screen lines.\n'
          .. 'Expected (anywhere): "'
          .. expected.any
          .. '"\n'
          .. 'Actual:\n  |'
          .. table.concat(actual_rows, '\n  |')
          .. '\n\n'
        )
      end
    end

    if grid then
      for i, row in ipairs(expected_rows) do
        local count --- @type integer?
        row, count = row:match('^(.*%|)%*(%d+)$')
        if row then
          count = tonumber(count)
          table.remove(expected_rows, i)
          for _ = 1, count do
            table.insert(expected_rows, i, row)
          end
        end
      end
      local err_msg = nil
      -- `expected` must match the screen lines exactly.
      if #actual_rows ~= #expected_rows then
        err_msg = 'Expected screen height '
          .. #expected_rows
          .. ' differs from actual height '
          .. #actual_rows
          .. '.'
      end
      local msg_expected_rows = shallowcopy(expected_rows)
      local msg_actual_rows = shallowcopy(actual_rows)
      for i, row in ipairs(expected_rows) do
        local pat = nil --- @type string?
        if actual_rows[i] and row ~= actual_rows[i] then
          local after = row
          while true do
            local s, e, m = after:find('{MATCH:(.-)}')
            if not s then
              pat = pat and (pat .. pesc(after))
              break
            end
            --- @type string
            pat = (pat or '') .. pesc(after:sub(1, s - 1)) .. m
            after = after:sub(e + 1)
          end
        end
        if row ~= actual_rows[i] and (not pat or not actual_rows[i]:match(pat)) then
          msg_expected_rows[i] = '*' .. msg_expected_rows[i]
          if i <= #actual_rows then
            msg_actual_rows[i] = '*' .. msg_actual_rows[i]
          end
          if err_msg == nil then
            err_msg = 'Row ' .. tostring(i) .. ' did not match.'
          end
        end
      end
      if err_msg ~= nil then
        return (
          err_msg
          .. '\nExpected:\n  |'
          .. table.concat(msg_expected_rows, '\n  |')
          .. '\n'
          .. 'Actual:\n  |'
          .. table.concat(msg_actual_rows, '\n  |')
          .. '\n\n'
          .. [[
To print the expect() call that would assert the current screen state, use
screen:snapshot_util(). In case of non-deterministic failures, use
screen:redraw_debug() to show all intermediate screen states.]]
        )
      end
    end

    -- UI extensions. The default expectations should cover the case of
    -- the ext_ feature being disabled, or the feature currently not activated
    -- (e.g. no external cmdline visible). Some extensions require
    -- preprocessing to represent highlights in a reproducible way.
    local extstate = self:_extstate_repr(attr_state)
    if expected.mode ~= nil then
      extstate.mode = self.mode
    end
    if expected.mouse_enabled ~= nil then
      extstate.mouse_enabled = self.mouse_enabled
    end
    if expected.win_viewport == nil then
      extstate.win_viewport = nil
    end
    if expected.win_viewport_margins == nil then
      extstate.win_viewport_margins = nil
    end
    if expected.win_pos == nil then
      extstate.win_pos = nil
    end
    if expected.cmdline == nil then
      extstate.cmdline = nil
    end

    if expected.float_pos then
      expected.float_pos = deepcopy(expected.float_pos)
      for _, v in pairs(expected.float_pos) do
        if not v.external and v[7] == nil then
          v[7] = 50
        end
      end
    end

    -- Convert assertion errors into invalid screen state descriptions.
    for _, k in ipairs(concat_tables(ext_keys, { 'mode', 'mouse_enabled' })) do
      -- Empty states are considered the default and need not be mentioned.
      if not (expected[k] == nil and isempty(extstate[k])) then
        local status, res = pcall(eq, expected[k], extstate[k], k)
        if not status then
          return (
            tostring(res)
            .. '\nHint: full state of "'
            .. k
            .. '":\n  '
            .. inspect(extstate[k])
          )
        end
      end
    end

    if expected.hl_groups ~= nil then
      for name, id in pairs(expected.hl_groups) do
        local expected_hl = attr_state.ids[id]
        local actual_hl = self._attr_table[self.hl_groups[name]][(self._options.rgb and 1) or 2]
        local status, res = pcall(eq, expected_hl, actual_hl, 'highlight ' .. name)
        if not status then
          return tostring(res)
        end
      end
    end

    if expected.extmarks ~= nil then
      for gridid, expected_marks in pairs(expected.extmarks) do
        local stored_marks = self._grid_win_extmarks[gridid]
        if stored_marks == nil then
          return 'no win_extmark for grid ' .. tostring(gridid)
        end
        local status, res =
          pcall(eq, expected_marks, stored_marks, 'extmarks for grid ' .. tostring(gridid))
        if not status then
          return tostring(res)
        end
      end
      for gridid, _ in pairs(self._grid_win_extmarks) do
        local expected_marks = expected.extmarks[gridid]
        if expected_marks == nil then
          return 'unexpected win_extmark for grid ' .. tostring(gridid)
        end
      end
    end
  end, expected)
  -- Only test the abort state of a cmdline level once.
  if self.cmdline_hide_level ~= nil then
    self.cmdline[self.cmdline_hide_level] = nil
    self.cmdline_hide_level = nil
  end
end

function Screen:expect_unchanged(intermediate, waittime_ms)
  -- Collect the current screen state.
  local kwargs = self:get_snapshot()

  if intermediate then
    kwargs.intermediate = true
  else
    kwargs.unchanged = true
  end

  kwargs.timeout = waittime_ms
  -- Check that screen state does not change.
  self:expect(kwargs)
end

--- @private
--- @param check fun(): string
--- @param flags table<string,any>
function Screen:_wait(check, flags)
  local err --- @type string?
  local checked = false
  local success_seen = false
  local failure_after_success = false
  local did_flush = true
  local warn_immediate = not (flags.unchanged or flags.intermediate)

  if flags.intermediate and flags.unchanged then
    error("Choose only one of 'intermediate' and 'unchanged', not both")
  end

  if flags.reset then
    -- throw away all state, we expect it to be retransmitted
    self:_reset()
  end

  -- Maximum timeout, after which a incorrect state will be regarded as a
  -- failure
  local timeout = flags.timeout or self.timeout

  -- Minimal timeout before the loop is allowed to be stopped so we
  -- always do some check for failure after success.
  local minimal_timeout = default_timeout_factor * 2

  local immediate_seen, intermediate_seen = false, false
  if not check() then
    minimal_timeout = default_timeout_factor * 20
    immediate_seen = true
  end

  -- For an "unchanged" test, flags.timeout is the time during which the state
  -- must not change, so always wait this full time.
  if flags.unchanged then
    minimal_timeout = flags.timeout or default_timeout_factor * 20
  end

  assert(timeout >= minimal_timeout)
  local did_minimal_timeout = false

  local function notification_cb(method, args)
    assert(
      method == 'redraw',
      string.format('notification_cb: unexpected method (%s, args=%s)', method, inspect(args))
    )
    did_flush = self:_redraw(args)
    if not did_flush then
      return
    end
    err = check()
    checked = true
    if err and immediate_seen then
      intermediate_seen = true
    end

    if not err and (not flags.intermediate or intermediate_seen) then
      success_seen = true
      if did_minimal_timeout then
        self._session:stop()
      end
    elseif err and success_seen and #args > 0 then
      success_seen = false
      failure_after_success = true
      -- print(inspect(args))
    end

    return true
  end
  local eof = run_session(self._session, flags.request_cb, notification_cb, nil, minimal_timeout)
  if not did_flush then
    if eof then
      err = 'no flush received'
    end
  elseif not checked then
    err = check()
    if not err and flags.unchanged then
      -- expecting NO screen change: use a shorter timeout
      success_seen = true
    end
  end

  if not success_seen and not eof then
    did_minimal_timeout = true
    eof =
      run_session(self._session, flags.request_cb, notification_cb, nil, timeout - minimal_timeout)
    if not did_flush then
      err = 'no flush received'
    end
  end

  local did_warn = false
  if warn_immediate and immediate_seen then
    print([[

warning: Screen test succeeded immediately. Try to avoid this unless the
purpose of the test really requires it.]])
    if intermediate_seen then
      print([[
There are intermediate states between the two identical expects.
Use screen:snapshot_util() or screen:redraw_debug() to find them, and add them
to the test if they make sense.
]])
    else
      print([[If necessary, silence this warning with 'unchanged' argument of screen:expect.]])
    end
    did_warn = true
  end

  if failure_after_success then
    print([[

warning: Screen changes were received after the expected state. This indicates
indeterminism in the test. Try adding screen:expect(...) (or poke_eventloop())
between asynchronous (feed(), nvim_input()) and synchronous API calls.
  - Use screen:redraw_debug() to investigate; it may find relevant intermediate
    states that should be added to the test to make it more robust.
  - If the purpose of the test is to assert state after some user input sent
    with feed(), adding screen:expect() before the feed() will help to ensure
    the input is sent when Nvim is in a predictable state. This is preferable
    to poke_eventloop(), for being closer to real user interaction.
  - poke_eventloop() can trigger redraws and thus generate more indeterminism.
    Try removing poke_eventloop().
      ]])
    did_warn = true
  end

  if err then
    if eof then
      err = err .. '\n\n' .. eof[2]
    end
    busted.fail(err .. '\n\nSnapshot:\n' .. self:_print_snapshot(), 3)
  elseif did_warn then
    if eof then
      print(eof[2])
    end
    local tb = debug.traceback()
    local index = string.find(tb, '\n%s*%[C]')
    print(string.sub(tb, 1, index))
  end

  if flags.intermediate then
    assert(intermediate_seen, 'expected intermediate screen state before final screen state')
  elseif flags.unchanged then
    assert(not intermediate_seen, 'expected screen state to be unchanged')
  end
end

function Screen:sleep(ms, request_cb)
  local function notification_cb(method, args)
    assert(method == 'redraw')
    self:_redraw(args)
  end
  run_session(self._session, request_cb, notification_cb, nil, ms)
end

--- @private
--- @param updates {[1]:string, [integer]:any[]}[]
function Screen:_redraw(updates)
  local did_flush = false
  for k, update in ipairs(updates) do
    -- print('--', inspect(update))
    local method = update[1]
    for i = 2, #update do
      local handler_name = '_handle_' .. method
      --- @type function
      local handler = self[handler_name]
      assert(handler ~= nil, 'missing handler: Screen:' .. handler_name)
      local status, res = pcall(handler, self, unpack(update[i]))
      if not status then
        error(
          handler_name
            .. ' failed'
            .. '\n  payload: '
            .. inspect(update)
            .. '\n  error:   '
            .. tostring(res)
        )
      end
    end
    if k == #updates and method == 'flush' then
      did_flush = true
    end
  end
  return did_flush
end

function Screen:_handle_resize(width, height)
  self:_handle_grid_resize(1, width, height)
  self._scroll_region = {
    top = 1,
    bot = height,
    left = 1,
    right = width,
  }
  self._grid = self._grids[1]
end

local function min(x, y)
  if x < y then
    return x
  else
    return y
  end
end

function Screen:_handle_grid_resize(grid, width, height)
  local rows = {}
  for _ = 1, height do
    local cols = {}
    for _ = 1, width do
      table.insert(cols, { text = ' ', attrs = self._clear_attrs, hl_id = 0 })
    end
    table.insert(rows, cols)
  end
  if grid > 1 and self._grids[grid] ~= nil then
    local old = self._grids[grid]
    for i = 1, min(height, old.height) do
      for j = 1, min(width, old.width) do
        rows[i][j] = old.rows[i][j]
      end
    end
  end

  if self._cursor.grid == grid then
    self._cursor.row = 1 -- -1 ?
    self._cursor.col = 1
  end
  self._grids[grid] = {
    rows = rows,
    width = width,
    height = height,
  }
end

function Screen:_handle_msg_set_pos(grid, row, scrolled, char)
  self.msg_grid = grid
  self.msg_grid_pos = row
  self.msg_scrolled = scrolled
  self.msg_sep_char = char
end

function Screen:_handle_flush() end

function Screen:_reset()
  -- TODO: generalize to multigrid later
  self:_handle_grid_clear(1)

  -- TODO: share with initialization, so it generalizes?
  self.popupmenu = nil
  self.cmdline = {}
  self.cmdline_block = {}
  self.wildmenu_items = nil
  self.wildmenu_pos = nil
  self._grid_win_extmarks = {}
end

--- @param cursor_style_enabled boolean
--- @param mode_info table[]
function Screen:_handle_mode_info_set(cursor_style_enabled, mode_info)
  self._cursor_style_enabled = cursor_style_enabled
  for _, item in pairs(mode_info) do
    -- attr IDs are not stable, but their value should be
    if item.attr_id ~= nil and self._attr_table[item.attr_id] ~= nil then
      item.attr = self._attr_table[item.attr_id][1]
      item.attr_id = nil
    end
    if item.attr_id_lm ~= nil and self._attr_table[item.attr_id_lm] ~= nil then
      item.attr_lm = self._attr_table[item.attr_id_lm][1]
      item.attr_id_lm = nil
    end
  end
  self._mode_info = mode_info
end

function Screen:_handle_clear()
  -- the first implemented UI protocol clients (python-gui and builitin TUI)
  -- allowed the cleared region to be restricted by setting the scroll region.
  -- this was never used by nvim tough, and not documented and implemented by
  -- newer clients, to check we remain compatible with both kind of clients,
  -- ensure the scroll region is in a reset state.
  local expected_region = {
    top = 1,
    bot = self._grid.height,
    left = 1,
    right = self._grid.width,
  }
  eq(expected_region, self._scroll_region)
  self:_handle_grid_clear(1)
end

function Screen:_handle_grid_clear(grid)
  self:_clear_block(self._grids[grid], 1, self._grids[grid].height, 1, self._grids[grid].width)
end

function Screen:_handle_grid_destroy(grid)
  self._grids[grid] = nil
  if self._options.ext_multigrid then
    self.win_position[grid] = nil
    self.win_viewport[grid] = nil
    self.win_viewport_margins[grid] = nil
  end
end

function Screen:_handle_eol_clear()
  local row, col = self._cursor.row, self._cursor.col
  self:_clear_block(self._grid, row, row, col, self._grid.width)
end

function Screen:_handle_cursor_goto(row, col)
  self._cursor.row = row + 1
  self._cursor.col = col + 1
end

function Screen:_handle_grid_cursor_goto(grid, row, col)
  self._cursor.grid = grid
  assert(row >= 0 and col >= 0)
  self._cursor.row = row + 1
  self._cursor.col = col + 1
end

function Screen:_handle_win_pos(grid, win, startrow, startcol, width, height)
  self.win_position[grid] = {
    win = win,
    startrow = startrow,
    startcol = startcol,
    width = width,
    height = height,
  }
  self.float_pos[grid] = nil
end

function Screen:_handle_win_viewport(
  grid,
  win,
  topline,
  botline,
  curline,
  curcol,
  linecount,
  scroll_delta
)
  -- accumulate scroll delta
  local last_scroll_delta = self.win_viewport[grid] and self.win_viewport[grid].sum_scroll_delta
    or 0
  self.win_viewport[grid] = {
    win = win,
    topline = topline,
    botline = botline,
    curline = curline,
    curcol = curcol,
    linecount = linecount,
    sum_scroll_delta = scroll_delta + last_scroll_delta,
  }
end

function Screen:_handle_win_viewport_margins(grid, win, top, bottom, left, right)
  self.win_viewport_margins[grid] = {
    win = win,
    top = top,
    bottom = bottom,
    left = left,
    right = right,
  }
end

function Screen:_handle_win_float_pos(grid, ...)
  self.win_position[grid] = nil
  self.float_pos[grid] = { ... }
end

function Screen:_handle_win_external_pos(grid)
  self.win_position[grid] = nil
  self.float_pos[grid] = { external = true }
end

function Screen:_handle_win_hide(grid)
  self.win_position[grid] = nil
  self.float_pos[grid] = nil
end

function Screen:_handle_win_close(grid)
  self.float_pos[grid] = nil
end

function Screen:_handle_win_extmark(grid, ...)
  if self._grid_win_extmarks[grid] == nil then
    self._grid_win_extmarks[grid] = {}
  end
  table.insert(self._grid_win_extmarks[grid], { ... })
end

function Screen:_handle_busy_start()
  self._busy = true
end

function Screen:_handle_busy_stop()
  self._busy = false
end

function Screen:_handle_mouse_on()
  self.mouse_enabled = true
end

function Screen:_handle_mouse_off()
  self.mouse_enabled = false
end

function Screen:_handle_mode_change(mode, idx)
  assert(mode == self._mode_info[idx + 1].name)
  self.mode = mode
end

function Screen:_handle_set_scroll_region(top, bot, left, right)
  self._scroll_region.top = top + 1
  self._scroll_region.bot = bot + 1
  self._scroll_region.left = left + 1
  self._scroll_region.right = right + 1
end

function Screen:_handle_scroll(count)
  local top = self._scroll_region.top
  local bot = self._scroll_region.bot
  local left = self._scroll_region.left
  local right = self._scroll_region.right
  self:_handle_grid_scroll(1, top - 1, bot, left - 1, right, count, 0)
end

--- @param g any
--- @param top integer
--- @param bot integer
--- @param left integer
--- @param right integer
--- @param rows integer
--- @param cols integer
function Screen:_handle_grid_scroll(g, top, bot, left, right, rows, cols)
  top = top + 1
  left = left + 1
  assert(cols == 0)
  local grid = self._grids[g]
  --- @type integer, integer, integer
  local start, stop, step

  if rows > 0 then
    start = top
    stop = bot - rows
    step = 1
  else
    start = bot
    stop = top - rows
    step = -1
  end

  -- shift scroll region
  for i = start, stop, step do
    local target = grid.rows[i]
    local source = grid.rows[i + rows]
    for j = left, right do
      target[j].text = source[j].text
      target[j].attrs = source[j].attrs
      target[j].hl_id = source[j].hl_id
    end
  end

  -- clear invalid rows
  for i = stop + step, stop + rows, step do
    self:_clear_row_section(grid, i, left, right, true)
  end
end

function Screen:_handle_hl_attr_define(id, rgb_attrs, cterm_attrs, info)
  self._attr_table[id] = { rgb_attrs, cterm_attrs }
  self._hl_info[id] = info
  self._new_attrs = true
end

--- @param name string
--- @param id integer
function Screen:_handle_hl_group_set(name, id)
  self.hl_groups[name] = id
end

function Screen:get_hl(val)
  if self._options.ext_newgrid then
    return self._attr_table[val][1]
  end
  return val
end

function Screen:_handle_highlight_set(attrs)
  self._attrs = attrs
end

function Screen:_handle_put(str)
  assert(not self._options.ext_linegrid)
  local cell = self._grid.rows[self._cursor.row][self._cursor.col]
  cell.text = str
  cell.attrs = self._attrs
  cell.hl_id = -1
  self._cursor.col = self._cursor.col + 1
end

--- @param grid integer
--- @param row integer
--- @param col integer
--- @param items integer[][]
function Screen:_handle_grid_line(grid, row, col, items)
  assert(self._options.ext_linegrid)
  assert(#items > 0)
  local line = self._grids[grid].rows[row + 1]
  local colpos = col + 1
  local hl_id = 0
  for _, item in ipairs(items) do
    local text, hl_id_cell, count = item[1], item[2], item[3]
    if hl_id_cell ~= nil then
      hl_id = hl_id_cell
    end
    for _ = 1, (count or 1) do
      local cell = line[colpos]
      cell.text = text
      cell.hl_id = hl_id
      colpos = colpos + 1
    end
  end
end

function Screen:_handle_bell()
  self.bell = true
end

function Screen:_handle_visual_bell()
  self.visual_bell = true
end

function Screen:_handle_default_colors_set(rgb_fg, rgb_bg, rgb_sp, cterm_fg, cterm_bg)
  self.default_colors = {
    rgb_fg = rgb_fg,
    rgb_bg = rgb_bg,
    rgb_sp = rgb_sp,
    cterm_fg = cterm_fg,
    cterm_bg = cterm_bg,
  }
end

function Screen:_handle_update_fg(fg)
  self._fg = fg
end

function Screen:_handle_update_bg(bg)
  self._bg = bg
end

function Screen:_handle_update_sp(sp)
  self._sp = sp
end

function Screen:_handle_suspend()
  self.suspended = true
end

function Screen:_handle_update_menu()
  self.update_menu = true
end

function Screen:_handle_set_title(title)
  self.title = title
end

function Screen:_handle_set_icon(icon)
  self.icon = icon
end

function Screen:_handle_option_set(name, value)
  self.options[name] = value
end

function Screen:_handle_chdir(path)
  self.pwd = vim.fs.normalize(path, { expand_env = false })
end

function Screen:_handle_popupmenu_show(items, selected, row, col, grid)
  self.popupmenu = { items = items, pos = selected, anchor = { grid, row, col } }
end

function Screen:_handle_popupmenu_select(selected)
  self.popupmenu.pos = selected
end

function Screen:_handle_popupmenu_hide()
  self.popupmenu = nil
end

function Screen:_handle_cmdline_show(content, pos, firstc, prompt, indent, level, hl_id)
  if firstc == '' then
    firstc = nil
  end
  if prompt == '' then
    prompt = nil
  end
  if indent == 0 then
    indent = nil
  end

  -- check position is valid #10000
  local len = 0
  for _, chunk in ipairs(content) do
    len = len + string.len(chunk[2])
  end
  assert(pos <= len)

  self.cmdline[level] = {
    content = content,
    pos = pos,
    firstc = firstc,
    prompt = prompt,
    indent = indent,
    hl_id = prompt and hl_id,
  }
end

function Screen:_handle_cmdline_hide(level, abort)
  self.cmdline[level] = { abort = abort }
  self.cmdline_hide_level = level
end

function Screen:_handle_cmdline_special_char(char, shift, level)
  -- cleared by next cmdline_show on the same level
  self.cmdline[level].special = { char, shift }
end

function Screen:_handle_cmdline_pos(pos, level)
  self.cmdline[level].pos = pos
end

function Screen:_handle_cmdline_block_show(block)
  self.cmdline_block = block
end

function Screen:_handle_cmdline_block_append(item)
  self.cmdline_block[#self.cmdline_block + 1] = item
end

function Screen:_handle_cmdline_block_hide()
  self.cmdline_block = {}
end

function Screen:_handle_wildmenu_show(items)
  self.wildmenu_items = items
end

function Screen:_handle_wildmenu_select(pos)
  self.wildmenu_pos = pos
end

function Screen:_handle_wildmenu_hide()
  self.wildmenu_items, self.wildmenu_pos = nil, nil
end

function Screen:_handle_msg_show(kind, chunks, replace_last, history)
  local pos = #self.messages
  if not replace_last or pos == 0 then
    pos = pos + 1
  end
  self.messages[pos] = { kind = kind, content = chunks, history = history }
end

function Screen:_handle_msg_clear()
  self.messages = {}
end

function Screen:_handle_msg_showcmd(msg)
  self.showcmd = msg
end

function Screen:_handle_msg_showmode(msg)
  self.showmode = msg
end

function Screen:_handle_msg_ruler(msg)
  self.ruler = msg
end

function Screen:_handle_msg_history_show(entries)
  self.msg_history = entries
end

function Screen:_handle_msg_history_clear()
  self.msg_history = {}
end

function Screen:_clear_block(grid, top, bot, left, right)
  for i = top, bot do
    self:_clear_row_section(grid, i, left, right)
  end
end

function Screen:_clear_row_section(grid, rownum, startcol, stopcol, invalid)
  local row = grid.rows[rownum]
  for i = startcol, stopcol do
    row[i].text = (invalid and '�' or ' ')
    row[i].attrs = self._clear_attrs
    row[i].hl_id = 0
  end
end

function Screen:_row_repr(gridnr, rownr, attr_state, cursor)
  local rv = {}
  local current_attr_id
  local i = 1
  local has_windows = self._options.ext_multigrid and gridnr == 1
  local row = self._grids[gridnr].rows[rownr]
  if has_windows and self.msg_grid and self.msg_grid_pos < rownr then
    return '[' .. self.msg_grid .. ':' .. string.rep('-', #row) .. ']'
  end
  while i <= #row do
    local did_window = false
    if has_windows then
      for id, pos in pairs(self.win_position) do
        if
          i - 1 == pos.startcol
          and pos.startrow <= rownr - 1
          and rownr - 1 < pos.startrow + pos.height
        then
          if current_attr_id then
            -- close current attribute bracket
            table.insert(rv, '}')
            current_attr_id = nil
          end
          table.insert(rv, '[' .. id .. ':' .. string.rep('-', pos.width) .. ']')
          i = i + pos.width
          did_window = true
        end
      end
    end

    if not did_window then
      local attr_id = self:_get_attr_id(attr_state, row[i].attrs, row[i].hl_id)
      if current_attr_id and attr_id ~= current_attr_id then
        -- close current attribute bracket
        table.insert(rv, '}')
        current_attr_id = nil
      end
      if not current_attr_id and attr_id then
        -- open a new attribute bracket
        table.insert(rv, '{' .. attr_id .. ':')
        current_attr_id = attr_id
      end
      if not self._busy and cursor and self._cursor.col == i then
        table.insert(rv, '^')
      end
      table.insert(rv, row[i].text)
      i = i + 1
    end
  end
  if current_attr_id then
    table.insert(rv, '}')
  end
  -- return the line representation, but remove empty attribute brackets and
  -- trailing whitespace
  return table.concat(rv, '') --:gsub('%s+$', '')
end

function Screen:_extstate_repr(attr_state)
  local cmdline = {}
  for i, entry in pairs(self.cmdline) do
    entry = shallowcopy(entry)
    if entry.content ~= nil then
      entry.content = self:_chunks_repr(entry.content, attr_state)
    end
    cmdline[i] = entry
  end

  local cmdline_block = {}
  for i, entry in ipairs(self.cmdline_block) do
    cmdline_block[i] = self:_chunks_repr(entry, attr_state)
  end

  local messages = {}
  for i, entry in ipairs(self.messages) do
    messages[i] = {
      kind = entry.kind,
      content = self:_chunks_repr(entry.content, attr_state),
      history = entry.history,
    }
  end

  local msg_history = {}
  for i, entry in ipairs(self.msg_history) do
    msg_history[i] = { kind = entry[1], content = self:_chunks_repr(entry[2], attr_state) }
  end

  local win_viewport = (next(self.win_viewport) and self.win_viewport) or nil
  local win_viewport_margins = (next(self.win_viewport_margins) and self.win_viewport_margins)
    or nil

  return {
    popupmenu = self.popupmenu,
    cmdline = cmdline,
    cmdline_block = cmdline_block,
    wildmenu_items = self.wildmenu_items,
    wildmenu_pos = self.wildmenu_pos,
    messages = messages,
    showmode = self:_chunks_repr(self.showmode, attr_state),
    showcmd = self:_chunks_repr(self.showcmd, attr_state),
    ruler = self:_chunks_repr(self.ruler, attr_state),
    msg_history = msg_history,
    float_pos = self.float_pos,
    win_viewport = win_viewport,
    win_viewport_margins = win_viewport_margins,
    win_pos = self.win_position,
  }
end

function Screen:_chunks_repr(chunks, attr_state)
  local repr_chunks = {}
  for i, chunk in ipairs(chunks) do
    local hl, text, id = unpack(chunk)
    local attrs
    if self._options.ext_linegrid then
      attrs = self._attr_table[hl][1]
    else
      attrs = hl
    end
    local attr_id = self:_get_attr_id(attr_state, attrs, hl)
    repr_chunks[i] = { text, attr_id, attr_id and id or nil }
  end
  return repr_chunks
end

-- Generates tests. Call it where Screen:expect() would be. Waits briefly, then
-- dumps the current screen state in the form of Screen:expect().
-- Use snapshot_util({}) to generate a text-only (no attributes) test.
--
-- @see Screen:redraw_debug()
function Screen:snapshot_util(request_cb)
  -- TODO: simplify this later when existing tests have been updated
  self:sleep(250, request_cb)
  self:print_snapshot()
end

function Screen:redraw_debug(timeout)
  self:print_snapshot()
  local function notification_cb(method, args)
    assert(method == 'redraw')
    for _, update in ipairs(args) do
      -- mode_info_set is quite verbose, comment out the condition to debug it.
      if update[1] ~= 'mode_info_set' then
        print(inspect(update))
      end
    end
    self:_redraw(args)
    self:print_snapshot()
    return true
  end
  if timeout == nil then
    timeout = 250
  end
  run_session(self._session, nil, notification_cb, nil, timeout)
end

--- @param headers boolean
--- @param attr_state any
--- @param preview? boolean
--- @return string[]
function Screen:render(headers, attr_state, preview)
  headers = headers and (self._options.ext_multigrid or self._options._debug_float)
  local rv = {}
  for igrid, grid in vim.spairs(self._grids) do
    if headers then
      local suffix = ''
      if
        igrid > 1
        and self.win_position[igrid] == nil
        and self.float_pos[igrid] == nil
        and self.msg_grid ~= igrid
      then
        suffix = ' (hidden)'
      end
      table.insert(rv, '## grid ' .. igrid .. suffix)
    end
    local height = grid.height
    if igrid == self.msg_grid then
      height = self._grids[1].height - self.msg_grid_pos
    end
    for i = 1, height do
      local cursor = self._cursor.grid == igrid and self._cursor.row == i
      local prefix = (headers or preview) and '  ' or ''
      table.insert(rv, prefix .. self:_row_repr(igrid, i, attr_state, cursor) .. '|')
    end
  end
  return rv
end

-- Returns the current screen state in the form of a screen:expect()
-- keyword-args map.
function Screen:get_snapshot()
  local attr_state = {
    ids = {},
    mutable = true, -- allow _row_repr to add missing highlights
  }
  local attrs = self._default_attr_ids

  if attrs ~= nil then
    for i, a in pairs(attrs) do
      attr_state.ids[i] = a
    end
  end
  if self._options.ext_linegrid then
    attr_state.id_to_index = self:linegrid_check_attrs(attr_state.ids or {})
  end

  local lines = self:render(true, attr_state, true)

  for i, row in ipairs(lines) do
    local count = 1
    while i < #lines and lines[i + 1] == row do
      count = count + 1
      table.remove(lines, i + 1)
    end
    if count > 1 then
      lines[i] = lines[i] .. '*' .. count
    end
  end

  local ext_state = self:_extstate_repr(attr_state)
  for k, v in pairs(ext_state) do
    if isempty(v) then
      ext_state[k] = nil -- deleting keys while iterating is ok
    end
  end

  -- Build keyword-args for screen:expect().
  local kwargs = {}
  if attr_state.modified then
    kwargs['attr_ids'] = {}
    for i, a in pairs(attr_state.ids) do
      kwargs['attr_ids'][i] = a
    end
  end
  kwargs['grid'] = table.concat(lines, '\n')
  for _, k in ipairs(ext_keys) do
    if ext_state[k] ~= nil then
      kwargs[k] = ext_state[k]
    end
  end

  return kwargs, ext_state, attr_state
end

local function fmt_ext_state(name, state)
  local function remove_all_metatables(item, path)
    if path[#path] ~= inspect.METATABLE then
      return item
    end
  end
  if name == 'win_viewport' then
    local str = '{\n'
    for k, v in pairs(state) do
      str = (
        str
        .. '  ['
        .. k
        .. '] = {win = '
        .. v.win
        .. ', topline = '
        .. v.topline
        .. ', botline = '
        .. v.botline
        .. ', curline = '
        .. v.curline
        .. ', curcol = '
        .. v.curcol
        .. ', linecount = '
        .. v.linecount
        .. ', sum_scroll_delta = '
        .. v.sum_scroll_delta
        .. '};\n'
      )
    end
    return str .. '}'
  elseif name == 'float_pos' then
    local str = '{\n'
    for k, v in pairs(state) do
      str = str .. '  [' .. k .. '] = {' .. v[1]
      for i = 2, #v do
        str = str .. ', ' .. inspect(v[i])
      end
      str = str .. '};\n'
    end
    return str .. '}'
  else
    -- TODO(bfredl): improve formatting of more states
    return inspect(state, { process = remove_all_metatables })
  end
end

function Screen:_print_snapshot()
  local kwargs, ext_state, attr_state = self:get_snapshot()
  local attrstr = ''
  local modify_attrs = not self._attrs_overridden
  if attr_state.modified then
    local attrstrs = {}
    for i, a in pairs(attr_state.ids) do
      local dict
      if self._options.ext_linegrid then
        dict = self:_pprint_hlitem(a)
      else
        dict = '{ ' .. self:_pprint_attrs(a) .. ' }'
      end
      local keyval = (type(i) == 'number') and '[' .. tostring(i) .. ']' or i
      if not (type(i) == 'number' and modify_attrs and i <= 30) then
        table.insert(attrstrs, '  ' .. keyval .. ' = ' .. dict .. ',')
      end
      if modify_attrs then
        self._default_attr_ids = attr_state.ids
      end
    end
    local fn_name = modify_attrs and 'add_extra_attr_ids' or 'set_default_attr_ids'
    attrstr = ('screen:' .. fn_name .. '({\n' .. table.concat(attrstrs, '\n') .. '\n})\n\n')
  end

  local extstr = ''
  for _, k in ipairs(ext_keys) do
    if ext_state[k] ~= nil and not (k == 'win_viewport' and not self.options.ext_multigrid) then
      extstr = extstr .. '\n  ' .. k .. ' = ' .. fmt_ext_state(k, ext_state[k]) .. ','
    end
  end

  return ('%sscreen:expect(%s%s%s%s%s'):format(
    attrstr,
    #extstr > 0 and '{\n  grid = [[\n  ' or '[[\n',
    #extstr > 0 and kwargs.grid:gsub('\n', '\n  ') or kwargs.grid,
    #extstr > 0 and '\n  ]],' or '\n]]',
    extstr,
    #extstr > 0 and '\n})' or ')'
  )
end

function Screen:print_snapshot()
  print('\n' .. self:_print_snapshot() .. '\n')
  io.stdout:flush()
end

function Screen:_insert_hl_id(attr_state, hl_id)
  if attr_state.id_to_index[hl_id] ~= nil then
    return attr_state.id_to_index[hl_id]
  end
  local raw_info = self._hl_info[hl_id]
  local info = nil
  if self._options.ext_hlstate then
    info = {}
    if #raw_info > 1 then
      for i, item in ipairs(raw_info) do
        info[i] = self:_insert_hl_id(attr_state, item.id)
      end
    else
      info[1] = {}
      for k, v in pairs(raw_info[1]) do
        if k ~= 'id' then
          info[1][k] = v
        end
      end
    end
  end

  local entry = self._attr_table[hl_id]
  local attrval
  if self._rgb_cterm then
    attrval = { entry[1], entry[2], info } -- unpack() doesn't work
  elseif self._options.ext_hlstate then
    attrval = { entry[1], info }
  else
    attrval = self._options.rgb and entry[1] or entry[2]
  end

  table.insert(attr_state.ids, attrval)
  attr_state.id_to_index[hl_id] = #attr_state.ids
  return #attr_state.ids
end

function Screen:linegrid_check_attrs(attrs)
  local id_to_index = {}
  for i, def_attr in pairs(self._attr_table) do
    local iinfo = self._hl_info[i]
    local matchinfo = {}
    if #iinfo > 1 then
      for k, item in ipairs(iinfo) do
        matchinfo[k] = id_to_index[item.id]
      end
    else
      matchinfo = iinfo
    end
    for k, v in pairs(attrs) do
      local attr, info, attr_rgb, attr_cterm
      if self._rgb_cterm then
        attr_rgb, attr_cterm, info = unpack(v)
        attr = { attr_rgb, attr_cterm }
        info = info or {}
      elseif self._options.ext_hlstate then
        attr, info = unpack(v)
      else
        attr = v
        info = {}
      end
      if self:_equal_attr_def(attr, def_attr) then
        if #info == #matchinfo then
          local match = false
          if #info == 1 then
            if self:_equal_info(info[1], matchinfo[1]) then
              match = true
            end
          else
            match = true
            for j = 1, #info do
              if info[j] ~= matchinfo[j] then
                match = false
              end
            end
          end
          if match then
            id_to_index[i] = k
          end
        end
      end
    end
    if
      self:_equal_attr_def(self._rgb_cterm and { {}, {} } or {}, def_attr)
      and #self._hl_info[i] == 0
    then
      id_to_index[i] = ''
    end
  end
  return id_to_index
end

function Screen:_pprint_hlitem(item)
  -- print(inspect(item))
  local multi = self._rgb_cterm or self._options.ext_hlstate
  local cterm = (not self._rgb_cterm and not self._options.rgb)
  local attrdict = '{ ' .. self:_pprint_attrs(multi and item[1] or item, cterm) .. ' }'
  local attrdict2, hlinfo
  local descdict = ''
  if self._rgb_cterm then
    attrdict2 = ', { ' .. self:_pprint_attrs(item[2], true) .. ' }'
    hlinfo = item[3]
  else
    attrdict2 = ''
    hlinfo = item[2]
  end
  if self._options.ext_hlstate then
    descdict = ', { ' .. self:_pprint_hlinfo(hlinfo) .. ' }'
  end
  return (multi and '{ ' or '') .. attrdict .. attrdict2 .. descdict .. (multi and ' }' or '')
end

function Screen:_pprint_hlinfo(states)
  if #states == 1 then
    local items = {}
    for f, v in pairs(states[1]) do
      local desc = tostring(v)
      if type(v) == type('') then
        desc = '"' .. desc .. '"'
      end
      table.insert(items, f .. ' = ' .. desc)
    end
    return '{' .. table.concat(items, ', ') .. '}'
  else
    return table.concat(states, ', ')
  end
end

function Screen:_pprint_attrs(attrs, cterm)
  local items = {}
  for f, v in pairs(attrs) do
    local desc = tostring(v)
    if f == 'foreground' or f == 'background' or f == 'special' then
      if Screen.colornames[v] ~= nil then
        desc = 'Screen.colors.' .. Screen.colornames[v]
      elseif cterm then
        desc = tostring(v)
      else
        desc = string.format("tonumber('0x%06x')", v)
      end
    end
    table.insert(items, f .. ' = ' .. desc)
  end
  return table.concat(items, ', ')
end

---@diagnostic disable-next-line: unused-local, unused-function
local function backward_find_meaningful(tbl, from) -- luacheck: no unused
  for i = from or #tbl, 1, -1 do
    if tbl[i] ~= ' ' then
      return i + 1
    end
  end
  return from
end

function Screen:_get_attr_id(attr_state, attrs, hl_id)
  if not attr_state.ids then
    return
  end

  if self._options.ext_linegrid then
    local id = attr_state.id_to_index[hl_id]
    if id == '' then -- sentinel for empty it
      return nil
    elseif id ~= nil then
      return id
    end
    if attr_state.mutable then
      id = self:_insert_hl_id(attr_state, hl_id)
      attr_state.modified = true
      return id
    end
    local kind = self._options.rgb and 1 or 2
    return 'UNEXPECTED ' .. self:_pprint_attrs(self._attr_table[hl_id][kind])
  else
    if self:_equal_attrs(attrs, {}) then
      -- ignore this attrs
      return nil
    end
    for id, a in pairs(attr_state.ids) do
      if self:_equal_attrs(a, attrs) then
        return id
      end
    end
    if attr_state.mutable then
      table.insert(attr_state.ids, attrs)
      attr_state.modified = true
      return #attr_state.ids
    end
    return 'UNEXPECTED ' .. self:_pprint_attrs(attrs)
  end
end

function Screen:_equal_attr_def(a, b)
  if self._rgb_cterm then
    return self:_equal_attrs(a[1], b[1]) and self:_equal_attrs(a[2], b[2])
  elseif self._options.rgb then
    return self:_equal_attrs(a, b[1])
  else
    return self:_equal_attrs(a, b[2])
  end
end

function Screen:_equal_attrs(a, b)
  return a.bold == b.bold
    and a.standout == b.standout
    and a.underline == b.underline
    and a.undercurl == b.undercurl
    and a.underdouble == b.underdouble
    and a.underdotted == b.underdotted
    and a.underdashed == b.underdashed
    and a.italic == b.italic
    and a.reverse == b.reverse
    and a.foreground == b.foreground
    and a.background == b.background
    and a.special == b.special
    and a.blend == b.blend
    and a.strikethrough == b.strikethrough
    and a.fg_indexed == b.fg_indexed
    and a.bg_indexed == b.bg_indexed
    and a.url == b.url
end

function Screen:_equal_info(a, b)
  return a.kind == b.kind and a.hi_name == b.hi_name and a.ui_name == b.ui_name
end

function Screen:_attr_index(attrs, attr)
  if not attrs then
    return nil
  end
  for i, a in pairs(attrs) do
    if self:_equal_attrs(a, attr) then
      return i
    end
  end
  return nil
end

return Screen
