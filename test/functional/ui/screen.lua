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
--
-- Too illustrate how this works, let's say that in the above example we wanted
-- to assert that the "-- INSERT --" string is highlighted with the bold
-- attribute(which normally is), here's how the call to "expect" should look
-- like:
--
--     screen:expect([[
--       hello screen             \
--       ~                        \
--       ~                        \
--       ~                        \
--       ~                        \
--       ~                        \
--       ~                        \
--       ~                        \
--       ~                        \
--       {b:-- INSERT --}             \
--     ]], {b = {bold = true}})
--
-- In this case "b" is a string associated with the set composed of one
-- attribute: bold. Note that since the {b:} markup is not a real part of the
-- screen, the delimiter(|) had to be moved right
local helpers = require('test.functional.helpers')
local request, run, stop = helpers.request, helpers.run, helpers.stop
local eq, dedent = helpers.eq, helpers.dedent

local Screen = {}
Screen.__index = Screen

function Screen.new(width, height)
  if not width then
    width = 53
  end
  if not height then
    height = 14
  end
  return setmetatable({
    _default_attr_ids = nil,
    _width = width,
    _height = height,
    _rows = new_cell_grid(width, height),
    _mode = 'normal',
    _mouse_enabled = true,
    _bell = false,
    _visual_bell = false,
    _attrs = {},
    _cursor = {
      enabled = true, row = 1, col = 1
    },
    _scroll_region = {
      top = 1, bot = height, left = 1, right = width
    }
  }, Screen)
end

function Screen:set_default_attr_ids(attr_ids)
  self._default_attr_ids = attr_ids
end

function Screen:attach()
  request('ui_attach', self._width, self._height, true)
end

function Screen:detach()
  request('ui_detach')
end

function Screen:expect(expected, attr_ids)
  -- remove the last line and dedent
  expected = dedent(expected:gsub('\n[ ]+$', ''))
  local expected_rows = {}
  for row in expected:gmatch('[^\n]+') do
    -- the last character should be the screen delimiter
    row = row:sub(1, #row - 1)
    table.insert(expected_rows, row)
  end
  local ids = attr_ids or self._default_attr_ids
  self:_wait(function()
    for i = 1, self._height do
      local expected_row = expected_rows[i]
      local actual_row = self:_row_repr(self._rows[i], ids)
      if expected_row ~= actual_row then
        return 'Row '..tostring(i)..' didnt match.\nExpected: "'..
               expected_row..'"\nActual:   "'..actual_row..'"'
      end
    end
  end)
end

function Screen:_wait(check, timeout)
  local err, checked = false
  local function notification_cb(method, args)
    assert(method == 'redraw')
    self:_redraw(args)
    err = check()
    checked = true
    if not err then
      stop()
    end
    return true
  end
  run(nil, notification_cb, nil, timeout or 5000)
  if not checked then
    err = check()
  end
  if err then
    error(err)
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
  self._rows = new_cell_grid(width, height)
end

function Screen:_handle_clear()
  self:_clear_block(1, self._height, 1, self._width)
end

function Screen:_handle_eol_clear()
  local row, col = self._cursor.row, self._cursor.col
  self:_clear_block(row, 1, col, self._scroll_region.right - col)
end

function Screen:_handle_cursor_goto(row, col)
  self._cursor.row = row + 1
  self._cursor.col = col + 1
end

function Screen:_handle_cursor_on()
  self._cursor.enabled = true
end

function Screen:_handle_cursor_off()
  self._cursor.enabled = false
end

function Screen:_handle_mouse_on()
  self._mouse_enabled = true
end

function Screen:_handle_mouse_off()
  self._mouse_enabled = false
end

function Screen:_handle_insert_mode()
  self._mode = 'insert'
end

function Screen:_handle_normal_mode()
  self._mode = 'normal'
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
    self:_copy_row_section(target, source, left, right)
  end

  -- clear invalid rows
  for i = stop + 1, stop + count, step do
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
  self._bell = true
end

function Screen:_handle_visual_bell()
  self._visual_bell = true
end

function Screen:_handle_update_fg(fg)
  self._fg = fg
end

function Screen:_handle_update_bg(bg)
  self._bg = bg
end

function Screen:_clear_block(top, lines, left, columns)
  for i = top, top + lines - 1 do
    self:_clear_row_section(i, left, left + columns - 1)
  end
end

function Screen:_clear_row_section(rownum, startcol, stopcol)
  local row = self._rows[rownum]
  for i = startcol, stopcol do
    row[i].text = ' '
    row[i].attrs = {}
  end
end

function Screen:_copy_row_section(target, source, startcol, stopcol)
  for i = startcol, stopcol do
    target[i].text = source[i].text
    target[i].attrs = source[i].attrs
  end
end

function Screen:_row_repr(row, attr_ids)
  local rv = {}
  local current_attr_id
  for i = 1, self._width do
    local attr_id = get_attr_id(attr_ids, row[i].attrs)
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
    if self._rows[self._cursor.row] == row and self._cursor.col == i then
      table.insert(rv, '^')
    else
      table.insert(rv, row[i].text)
    end
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

function backward_find_meaningful(tbl, from)
  for i = from or #tbl, 1, -1 do
    if tbl[i] ~= ' ' then
      return i + 1
    end
  end
  return from
end

function new_cell_grid(width, height)
  local rows = {}
  for i = 1, height do
    local cols = {}
    for j = 1, width do
      table.insert(cols, {text = ' ', attrs = {}})
    end
    table.insert(rows, cols)
  end
  return rows
end

function get_attr_id(attr_ids, attrs)
  if not attr_ids then
    return
  end
  for id, a in pairs(attr_ids) do
    if a.bold == attrs.bold and a.standout == attrs.standout and
       a.underline == attrs.underline and a.undercurl == attrs.undercurl and
       a.italic == attrs.italic and a.reverse == attrs.reverse and
       a.foreground == attrs.foreground and
       a.background == attrs.background then
       return id
     end
  end
  return nil
end

return Screen
