-- This module contains the Screen class, a complete Nvim screen implementation
-- designed for functional testing. The goal is to provide a simple and
-- intuitive API for verifying screen state after a set of actions.
--
-- The screen class exposes a single assertion method, "Screen:expect". This
-- method takes a string representing the expected screen state and an optional
-- set of attribute identifiers for checking highlighted characters(more on
-- this later).
--
-- The string passed to "expect" will be processed according to these rules:
--
--  - Each line of the string represents and is matched individually against
--    a screen row.
--  - The entire string is stripped of common indentation
--  - Expected screen rows are stripped of the last character. The last
--    character should be used to write pipes(|) that make clear where the
--    screen ends
--  - The last line is stripped, so the string must have (row count + 1)
--    lines.
--
-- Example usage:
--
--     local screen = Screen.new(25, 10)
--     -- attach the screen to the current Nvim instance
--     screen:attach()
--     --enter insert mode and type some text
--     feed('ihello screen')
--     -- declare an expectation for the eventual screen state
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
-- Since screen updates are received asynchronously, "expect" is actually
-- specifying the eventual screen state. This is how "expect" works: It will
-- start the event loop with a timeout of 5 seconds. Each time it receives an
-- update the expected state will be checked against the updated state.
--
-- If the expected state matches the current state, the event loop will be
-- stopped and "expect" will return.  If the timeout expires, the last match
-- error will be reported and the test will fail.
--
-- If the second argument is passed to "expect", the screen rows will be
-- transformed before being matched against the string lines. The
-- transformation rule is simple: Each substring "S" composed with characters
-- having the exact same set of attributes will be substituted by "{K:S}",
-- where K is a key associated the attribute set via the second argument of
-- "expect".
-- If a transformation table is present, unexpected attribute sets in the final
-- state is considered an error. To make testing simpler, a list of attribute
-- sets that should be ignored can be passed as a third argument. Alternatively,
-- this third argument can be "true" to indicate that all unexpected attribute
-- sets should be ignored.
--
-- To illustrate how this works, let's say that in the above example we wanted
-- to assert that the "-- INSERT --" string is highlighted with the bold
-- attribute(which normally is), here's how the call to "expect" should look
-- like:
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
-- screen, the delimiter(|) had to be moved right. Also, the highlighting of the
-- NonText markers (~) is ignored in this test.
--
-- Multiple expect:s will likely share a group of attribute sets to test.
-- Therefore these could be specified at the beginning of a test like this:
--    NonText = Screen.colors.Blue
--    screen:set_default_attr_ids( {
--      [1] = {reverse = true, bold = true},
--      [2] = {reverse = true}
--    })
--    screen:set_default_attr_ignore( {{}, {bold=true, foreground=NonText}} )
-- These can be overridden for a specific expect expression, by passing
-- different sets as parameters.
--
-- To help writing screen tests, there is a utility function
-- "screen:snapshot_util()", that can be placed in a test file at any point an
-- "expect(...)" should be. It will wait a short amount of time and then dump
-- the current state of the screen, in the form of an "expect(..)" expression
-- that would match it exactly. "snapshot_util" optionally also take the
-- transformation and ignore set as parameters, like expect, or uses the default
-- set. It will generate a larger attribute transformation set, if needed.
-- To generate a text-only test without highlight checks,
-- use `screen:snapshot_util({},true)`

local helpers = require('test.functional.helpers')
local request, run = helpers.request, helpers.run
local dedent = helpers.dedent

local Screen = {}
Screen.__index = Screen

local debug_screen

local default_screen_timeout = 3500
if os.getenv('VALGRIND') then
  default_screen_timeout = default_screen_timeout * 3
end

if os.getenv('CI_TARGET') then
  default_screen_timeout = default_screen_timeout * 3
end

do
  local spawn, nvim_prog = helpers.spawn, helpers.nvim_prog
  local session = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '-N', '--embed'})
  local status, rv = session:request('vim_get_color_map')
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
  session:exit(0)
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
    _default_attr_ids = nil,
    _default_attr_ignore = nil,
    _mode = 'normal',
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

function Screen:attach(rgb)
  if rgb == nil then
    rgb = true
  end
  request('ui_attach', self._width, self._height, rgb)
end

function Screen:detach()
  request('ui_detach')
end

function Screen:try_resize(columns, rows)
  request('ui_try_resize', columns, rows)
end

function Screen:expect(expected, attr_ids, attr_ignore)
  -- remove the last line and dedent
  expected = dedent(expected:gsub('\n[ ]+$', ''))
  local expected_rows = {}
  for row in expected:gmatch('[^\n]+') do
    -- the last character should be the screen delimiter
    row = row:sub(1, #row - 1)
    table.insert(expected_rows, row)
  end
  local ids = attr_ids or self._default_attr_ids
  local ignore = attr_ignore or self._default_attr_ignore
  self:wait(function()
    for i = 1, self._height do
      local expected_row = expected_rows[i]
      local actual_row = self:_row_repr(self._rows[i], ids, ignore)
      if expected_row ~= actual_row then
        return 'Row '..tostring(i)..' didn\'t match.\nExpected: "'..
               expected_row..'"\nActual:   "'..actual_row..'"'
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
Warning: Screen changes have been received after the expected state was seen.
This is probably due to an indeterminism in the test. Try adding
`wait()` (or even a separate `screen:expect(...)`) at a point of possible
indeterminism, typically in between a `feed()` or `execute()` which is non-
synchronous, and a synchronous api call.

Note that sometimes a `wait` can trigger redraws and consequently generate more
indeterminism. If adding `wait` calls seems to increase the frequency of these
messages, try removing every `wait` call in the test.

If everything else fails, use Screen:redraw_debug to help investigate what is
  causing the problem.
      ]])
    local tb = debug.traceback()
    local index = string.find(tb, '\n%s*%[C]')
    print(string.sub(tb,1,index))
  end

  if err then
    assert(false, err)
  end
end

function Screen:_redraw(updates)
  for _, update in ipairs(updates) do
    -- print('--')
    -- print(require('inspect')(update))
    local method = update[1]
    for i = 2, #update do
      local handler = self['_handle_'..method]
      handler(self, unpack(update[i]))
    end
    -- print(self:_current_screen())
  end
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

function Screen:_handle_mode_change(mode)
  assert(mode == 'insert' or mode == 'replace' or mode == 'normal')
  self._mode = mode
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

function Screen:_handle_update_fg(fg)
  self._fg = fg
end

function Screen:_handle_update_bg(bg)
  self._bg = bg
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

function Screen:snapshot_util(attrs, ignore)
  -- util to generate screen test
  pcall(function() self:wait(function() return "error" end, 250) end)
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
      for i, a in ipairs(self._default_attr_ids) do
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
      if f == "foreground" or f == "background" then
        if Screen.colornames[v] ~= nil then
          desc = "Screen.colors."..Screen.colornames[v]
        end
      end
      table.insert(items, f.." = "..desc)
    end
    return table.concat(items, ", ")
end

function backward_find_meaningful(tbl, from)  -- luacheck: ignore
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
       a.background == b.background
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
