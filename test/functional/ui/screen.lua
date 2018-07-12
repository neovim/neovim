-- This module contains the Screen class, a complete Nvim UI implementation
-- designed for functional testing (verifying screen state, in particular).
--
-- Screen:expect() takes a string representing the expected screen state and an
-- optional set of attribute identifiers for checking highlighted characters.
--
-- Example usage:
--
--     local screen = Screen.new(25, 10)
--     -- Attach the screen to the current Nvim instance.
--     screen:attach()
--     -- Enter insert-mode and type some text.
--     feed('ihello screen')
--     -- Assert the expected screen state.
--     screen:expect([[
--       hello screen             |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       -- INSERT --             |
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
-- Continuing the above example, say we want to assert that "-- INSERT --" is
-- highlighted with the bold attribute. The expect() call should look like this:
--
--     NonText = Screen.colors.Blue
--     screen:expect([[
--       hello screen             |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       ~                        |
--       {b:-- INSERT --}             |
--     ]], {b = {bold = true}}, {{bold = true, foreground = NonText}})
--
-- In this case "b" is a string associated with the set composed of one
-- attribute: bold. Note that since the {b:} markup is not a real part of the
-- screen, the delimiter "|" moved to the right. Also, the highlighting of the
-- NonText markers "~" is ignored in this test.
--
-- Tests will often share a group of attribute sets to expect(). Those can be
-- defined at the beginning of a test:
--
--    NonText = Screen.colors.Blue
--    screen:set_default_attr_ids( {
--      [1] = {reverse = true, bold = true},
--      [2] = {reverse = true}
--    })
--    screen:set_default_attr_ignore( {{}, {bold=true, foreground=NonText}} )
--
-- To help write screen tests, see Screen:snapshot_util().
-- To debug screen tests, see Screen:redraw_debug().

local helpers = require('test.functional.helpers')(nil)
local request, run, uimeths = helpers.request, helpers.run, helpers.uimeths
local dedent = helpers.dedent

local Screen = {}
Screen.__index = Screen

local debug_screen

local default_screen_timeout = 3500
if os.getenv('VALGRIND') then
  default_screen_timeout = default_screen_timeout * 3
end

if os.getenv('CI') then
  default_screen_timeout = default_screen_timeout * 3
end

do
  local spawn, nvim_prog = helpers.spawn, helpers.nvim_prog
  local session = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '-N', '--embed'})
  local status, rv = session:request('nvim_get_color_map')
  if not status then
    print('failed to get color map')
    os.exit(1)
  end
  local colors = rv
  local colornames = {}
  for name, rgb in pairs(colors) do
    -- we disregard the case that colornames might not be unique, as
    -- this is just a helper to get any canonical name of a color
    colornames[rgb] = name
  end
  session:close()
  Screen.colors = colors
  Screen.colornames = colornames
end

function Screen.debug(command)
  if not command then
    command = 'pynvim -n -c '
  end
  command = command .. request('vim_eval', '$NVIM_LISTEN_ADDRESS')
  if debug_screen then
    debug_screen:close()
  end
  debug_screen = io.popen(command, 'r')
  debug_screen:read()
end

function Screen.new(width, height)
  if not width then
    width = 53
  end
  if not height then
    height = 14
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
    _default_attr_ids = nil,
    _default_attr_ignore = nil,
    _mouse_enabled = true,
    _attrs = {},
    _cursor = {
      row = 1, col = 1
    },
    _busy = false
  }, Screen)
  self:_handle_resize(width, height)
  return self
end

function Screen:set_default_attr_ids(attr_ids)
  self._default_attr_ids = attr_ids
end

function Screen:set_default_attr_ignore(attr_ignore)
  self._default_attr_ignore = attr_ignore
end

function Screen:attach(options)
  if options == nil then
    options = {rgb=true}
  end
  uimeths.attach(self._width, self._height, options)
end

function Screen:detach()
  uimeths.detach()
end

function Screen:try_resize(columns, rows)
  uimeths.try_resize(columns, rows)
end

function Screen:set_option(option, value)
  uimeths.set_option(option, value)
end

-- Asserts that `expected` eventually matches the screen state.
--
-- expected:    Expected screen state (string). Each line represents a screen
--              row. Last character of each row (typically "|") is stripped.
--              Common indentation is stripped.
--              Used as `condition` if NOT a string; must be the ONLY arg then.
-- attr_ids:    Expected text attributes. Screen rows are transformed according
--              to this table, as follows: each substring S composed of
--              characters having the same attributes will be substituted by
--              "{K:S}", where K is a key in `attr_ids`. Any unexpected
--              attributes in the final state are an error.
-- attr_ignore: Ignored text attributes, or `true` to ignore all.
-- condition:   Function asserting some arbitrary condition.
-- any:         true: Succeed if `expected` matches ANY screen line(s).
--              false (default): `expected` must match screen exactly.
function Screen:expect(expected, attr_ids, attr_ignore, condition, any)
  local expected_rows = {}
  if type(expected) ~= "string" then
    assert(not (attr_ids or attr_ignore or condition or any))
    condition = expected
    expected = nil
  else
    -- Remove the last line and dedent. Note that gsub returns more then one
    -- value.
    expected = dedent(expected:gsub('\n[ ]+$', ''), 0)
    for row in expected:gmatch('[^\n]+') do
      row = row:sub(1, #row - 1) -- Last char must be the screen delimiter.
      table.insert(expected_rows, row)
    end
  end
  local ids = attr_ids or self._default_attr_ids
  local ignore = attr_ignore or self._default_attr_ignore
  self:wait(function()
    if condition ~= nil then
      local status, res = pcall(condition)
      if not status then
        return tostring(res)
      end
    end

    if expected and not any and self._height ~= #expected_rows then
      return ("Expected screen state's row count(" .. #expected_rows
              .. ') differs from configured height(' .. self._height .. ') of Screen.')
    end

    local actual_rows = {}
    for i = 1, self._height do
      actual_rows[i] = self:_row_repr(self._rows[i], ids, ignore)
    end

    if expected == nil then
      return
    elseif any then
      -- Search for `expected` anywhere in the screen lines.
      local actual_screen_str = table.concat(actual_rows, '\n')
      if nil == string.find(actual_screen_str, expected) then
        return (
          'Failed to match any screen lines.\n'
          .. 'Expected (anywhere): "' .. expected .. '"\n'
          .. 'Actual:\n  |' .. table.concat(actual_rows, '|\n  |') .. '|\n\n')
      end
    else
      -- `expected` must match the screen lines exactly.
      for i = 1, self._height do
        if expected_rows[i] ~= actual_rows[i] then
          local msg_expected_rows = {}
          for j = 1, #expected_rows do
            msg_expected_rows[j] = expected_rows[j]
          end
          msg_expected_rows[i] = '*' .. msg_expected_rows[i]
          actual_rows[i] = '*' .. actual_rows[i]
          return (
            'Row ' .. tostring(i) .. ' did not match.\n'
            ..'Expected:\n  |'..table.concat(msg_expected_rows, '|\n  |')..'|\n'
            ..'Actual:\n  |'..table.concat(actual_rows, '|\n  |')..'|\n\n'..[[
To print the expect() call that would assert the current screen state, use
screen:snapshot_util(). In case of non-deterministic failures, use
screen:redraw_debug() to show all intermediate screen states.  ]])
        end
      end
    end
  end)
end

function Screen:wait(check, timeout)
  local err, checked = false
  local success_seen = false
  local failure_after_success = false
  local function notification_cb(method, args)
    assert(method == 'redraw')
    self:_redraw(args)
    err = check()
    checked = true
    if not err then
      success_seen = true
      helpers.stop()
    elseif success_seen and #args > 0 then
      failure_after_success = true
      --print(require('inspect')(args))
    end

    return true
  end
  run(nil, notification_cb, nil, timeout or self.timeout)
  if not checked then
    err = check()
  end

  if failure_after_success then
    print([[

Warning: Screen changes were received after the expected state. This indicates
indeterminism in the test. Try adding wait() (or screen:expect(...)) between
asynchronous (feed(), nvim_input()) and synchronous API calls.
  - Use Screen:redraw_debug() to investigate the problem.
  - wait() can trigger redraws and consequently generate more indeterminism.
    In that case try removing every wait().
      ]])
    local tb = debug.traceback()
    local index = string.find(tb, '\n%s*%[C]')
    print(string.sub(tb,1,index))
  end

  if err then
    assert(false, err)
  end
end

function Screen:sleep(ms)
  pcall(function() self:wait(function() return "error" end, ms) end)
end

function Screen:_redraw(updates)
  for _, update in ipairs(updates) do
    -- print('--')
    -- print(require('inspect')(update))
    local method = update[1]
    for i = 2, #update do
      local handler_name = '_handle_'..method
      local handler = self[handler_name]
      if handler ~= nil then
        handler(self, unpack(update[i]))
      else
        assert(self._on_event,
          "Add Screen:"..handler_name.." or call Screen:set_on_event_handler")
        self._on_event(method, update[i])
      end
    end
    -- print(self:_current_screen())
  end
end

function Screen:set_on_event_handler(callback)
  self._on_event = callback
end

function Screen:_handle_resize(width, height)
  local rows = {}
  for _ = 1, height do
    local cols = {}
    for _ = 1, width do
      table.insert(cols, {text = ' ', attrs = {}})
    end
    table.insert(rows, cols)
  end
  self._cursor.row = 1
  self._cursor.col = 1
  self._rows = rows
  self._width = width
  self._height = height
  self._scroll_region = {
    top = 1, bot = height, left = 1, right = width
  }
end

function Screen:_handle_mode_info_set(cursor_style_enabled, mode_info)
  self._cursor_style_enabled = cursor_style_enabled
  self._mode_info = mode_info
end

function Screen:_handle_clear()
  self:_clear_block(self._scroll_region.top, self._scroll_region.bot,
                    self._scroll_region.left, self._scroll_region.right)
end

function Screen:_handle_eol_clear()
  local row, col = self._cursor.row, self._cursor.col
  self:_clear_block(row, row, col, self._scroll_region.right)
end

function Screen:_handle_cursor_goto(row, col)
  self._cursor.row = row + 1
  self._cursor.col = col + 1
end

function Screen:_handle_busy_start()
  self._busy = true
end

function Screen:_handle_busy_stop()
  self._busy = false
end

function Screen:_handle_mouse_on()
  self._mouse_enabled = true
end

function Screen:_handle_mouse_off()
  self._mouse_enabled = false
end

function Screen:_handle_mode_change(mode, idx)
  assert(mode == self._mode_info[idx+1].name)
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
  local start, stop, step

  if count > 0 then
    start = top
    stop = bot - count
    step = 1
  else
    start = bot
    stop = top - count
    step = -1
  end

  -- shift scroll region
  for i = start, stop, step do
    local target = self._rows[i]
    local source = self._rows[i + count]
    for j = left, right do
      target[j].text = source[j].text
      target[j].attrs = source[j].attrs
    end
  end

  -- clear invalid rows
  for i = stop + step, stop + count, step do
    self:_clear_row_section(i, left, right)
  end
end

function Screen:_handle_highlight_set(attrs)
  self._attrs = attrs
end

function Screen:_handle_put(str)
  local cell = self._rows[self._cursor.row][self._cursor.col]
  cell.text = str
  cell.attrs = self._attrs
  self._cursor.col = self._cursor.col + 1
end

function Screen:_handle_bell()
  self.bell = true
end

function Screen:_handle_visual_bell()
  self.visual_bell = true
end

function Screen:_handle_default_colors_set()
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

function Screen:_clear_block(top, bot, left, right)
  for i = top, bot do
    self:_clear_row_section(i, left, right)
  end
end

function Screen:_clear_row_section(rownum, startcol, stopcol)
  local row = self._rows[rownum]
  for i = startcol, stopcol do
    row[i].text = ' '
    row[i].attrs = {}
  end
end

function Screen:_row_repr(row, attr_ids, attr_ignore)
  local rv = {}
  local current_attr_id
  for i = 1, self._width do
    local attr_id = self:_get_attr_id(attr_ids, attr_ignore, row[i].attrs)
    if current_attr_id and attr_id ~= current_attr_id then
      -- close current attribute bracket, add it before any whitespace
      -- up to the current cell
      -- table.insert(rv, backward_find_meaningful(rv, i), '}')
      table.insert(rv, '}')
      current_attr_id = nil
    end
    if not current_attr_id and attr_id then
      -- open a new attribute bracket
      table.insert(rv, '{' .. attr_id .. ':')
      current_attr_id = attr_id
    end
    if not self._busy and self._rows[self._cursor.row] == row and self._cursor.col == i then
      table.insert(rv, '^')
    end
    table.insert(rv, row[i].text)
  end
  if current_attr_id then
    table.insert(rv, '}')
  end
  -- return the line representation, but remove empty attribute brackets and
  -- trailing whitespace
  return table.concat(rv, '')--:gsub('%s+$', '')
end


function Screen:_current_screen()
  -- get a string that represents the current screen state(debugging helper)
  local rv = {}
  for i = 1, self._height do
    table.insert(rv, "'"..self:_row_repr(self._rows[i]).."'")
  end
  return table.concat(rv, '\n')
end

-- Generates tests. Call it where Screen:expect() would be. Waits briefly, then
-- dumps the current screen state in the form of Screen:expect().
-- Use snapshot_util({},true) to generate a text-only (no attributes) test.
--
-- @see Screen:redraw_debug()
function Screen:snapshot_util(attrs, ignore)
  self:sleep(250)
  self:print_snapshot(attrs, ignore)
end

function Screen:redraw_debug(attrs, ignore, timeout)
  self:print_snapshot(attrs, ignore)
  local function notification_cb(method, args)
    assert(method == 'redraw')
    for _, update in ipairs(args) do
      print(require('inspect')(update))
    end
    self:_redraw(args)
    self:print_snapshot(attrs, ignore)
    return true
  end
  if timeout == nil then
    timeout = 250
  end
  run(nil, notification_cb, nil, timeout)
end

function Screen:print_snapshot(attrs, ignore)
  if ignore == nil then
    ignore = self._default_attr_ignore
  end
  if attrs == nil then
    attrs = {}
    if self._default_attr_ids ~= nil then
      for i, a in pairs(self._default_attr_ids) do
        attrs[i] = a
      end
    end

    if ignore ~= true then
      for i = 1, self._height do
        local row = self._rows[i]
        for j = 1, self._width do
          local attr = row[j].attrs
          if self:_attr_index(attrs, attr) == nil and self:_attr_index(ignore, attr) == nil then
            if not self:_equal_attrs(attr, {}) then
              table.insert(attrs, attr)
            end
          end
        end
      end
    end
  end

  local rv = {}
  for i = 1, self._height do
    table.insert(rv, "  "..self:_row_repr(self._rows[i],attrs, ignore).."|")
  end
  local attrstrs = {}
  local alldefault = true
  for i, a in ipairs(attrs) do
    if self._default_attr_ids == nil or self._default_attr_ids[i] ~= a then
      alldefault = false
    end
    local dict = "{"..self:_pprint_attrs(a).."}"
    table.insert(attrstrs, "["..tostring(i).."] = "..dict)
  end
  local attrstr = "{"..table.concat(attrstrs, ", ").."}"
  print( "\nscreen:expect([[")
  print( table.concat(rv, '\n'))
  if alldefault then
    print( "]])\n")
  else
    print( "]], "..attrstr..")\n")
  end
  io.stdout:flush()
end

function Screen:_pprint_attrs(attrs)
    local items = {}
    for f, v in pairs(attrs) do
      local desc = tostring(v)
      if f == "foreground" or f == "background" or f == "special" then
        if Screen.colornames[v] ~= nil then
          desc = "Screen.colors."..Screen.colornames[v]
        end
      end
      table.insert(items, f.." = "..desc)
    end
    return table.concat(items, ", ")
end

local function backward_find_meaningful(tbl, from)  -- luacheck: no unused
  for i = from or #tbl, 1, -1 do
    if tbl[i] ~= ' ' then
      return i + 1
    end
  end
  return from
end

function Screen:_get_attr_id(attr_ids, ignore, attrs)
  if not attr_ids then
    return
  end
  for id, a in pairs(attr_ids) do
    if self:_equal_attrs(a, attrs) then
       return id
     end
  end
  if self:_equal_attrs(attrs, {}) or
      ignore == true or self:_attr_index(ignore, attrs) ~= nil then
    -- ignore this attrs
    return nil
  end
  return "UNEXPECTED "..self:_pprint_attrs(attrs)
end

function Screen:_equal_attrs(a, b)
    return a.bold == b.bold and a.standout == b.standout and
       a.underline == b.underline and a.undercurl == b.undercurl and
       a.italic == b.italic and a.reverse == b.reverse and
       a.foreground == b.foreground and
       a.background == b.background and
       a.special == b.special
end

function Screen:_attr_index(attrs, attr)
  if not attrs then
    return nil
  end
  for i,a in pairs(attrs) do
    if self:_equal_attrs(a, attr) then
      return i
    end
  end
  return nil
end

return Screen
