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

local global_helpers = require('test.helpers')
local shallowcopy = global_helpers.shallowcopy
local helpers = require('test.functional.helpers')(nil)
local request, run, uimeths = helpers.request, helpers.run, helpers.uimeths
local eq = helpers.eq
local dedent = helpers.dedent

local inspect = require('inspect')

local function isempty(v)
  return type(v) == 'table' and next(v) == nil
end

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
    popupmenu = nil,
    cmdline = {},
    cmdline_block = {},
    wildmenu_items = nil,
    wildmenu_selected = nil,
    _default_attr_ids = nil,
    _default_attr_ignore = nil,
    _mouse_enabled = true,
    _attrs = {},
    _hl_info = {},
    _attr_table = {[0]={{},{}}},
    _clear_attrs = {},
    _new_attrs = false,
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

function Screen:set_hlstate_cterm(val)
  self._hlstate_cterm = val
end

function Screen:attach(options)
  if options == nil then
    options = {}
  end
  if options.ext_newgrid == nil then
    options.ext_newgrid = true
  end
  self._options = options
  self._clear_attrs = (options.ext_newgrid and {{},{}}) or {}
  uimeths.attach(self._width, self._height, options)
  if self._options.rgb == nil then
    -- nvim defaults to rgb=true internally,
    -- simplify test code by doing the same.
    self._options.rgb = true
  end
end

function Screen:detach()
  uimeths.detach()
end

function Screen:try_resize(columns, rows)
  uimeths.try_resize(columns, rows)
end

function Screen:set_option(option, value)
  uimeths.set_option(option, value)
  self._options[option] = value
end

-- canonical order of ext keys, used  to generate asserts
local ext_keys = {
  'popupmenu', 'cmdline', 'cmdline_block', 'wildmenu_items', 'wildmenu_pos'
}

-- Asserts that the screen state eventually matches an expected state
--
-- This function can either be called with the positional forms
--
--  screen:expect(grid, [attr_ids, attr_ignore])
--  screen:expect(condition)
--
-- or to use additional arguments (or grid and condition at the same time)
-- the keyword form has to be used:
--
-- screen:expect{grid=[[...]], cmdline={...}, condition=function() ... end}
--
--
-- grid:        Expected screen state (string). Each line represents a screen
--              row. Last character of each row (typically "|") is stripped.
--              Common indentation is stripped.
-- attr_ids:    Expected text attributes. Screen rows are transformed according
--              to this table, as follows: each substring S composed of
--              characters having the same attributes will be substituted by
--              "{K:S}", where K is a key in `attr_ids`. Any unexpected
--              attributes in the final state are an error.
--              Use screen:set_default_attr_ids() to define attributes for many
--              expect() calls.
-- attr_ignore: Ignored text attributes, or `true` to ignore all. By default
--              nothing is ignored.
-- condition:   Function asserting some arbitrary condition. Return value is
--              ignored, throw an error (use eq() or similar) to signal failure.
-- any:         Lua pattern string expected to match a screen line.
-- mode:        Expected mode as signaled by "mode_change" event
--
-- The following keys should be used to expect the state of various ext_
-- features. Note that an absent key will assert that the item is currently
-- NOT present on the screen, also when positional form is used.
--
-- popupmenu:      Expected ext_popupmenu state,
-- cmdline:        Expected ext_cmdline state, as an array of cmdlines of
--                 different level.
-- cmdline_block:  Expected ext_cmdline block (for function definitions)
-- wildmenu_items: Expected items for ext_wildmenu
-- wildmenu_pos:   Expected position for ext_wildmenu
function Screen:expect(expected, attr_ids, attr_ignore)
  local grid, condition = nil, nil
  local expected_rows = {}
  if type(expected) == "table" then
    assert(not (attr_ids ~= nil or attr_ignore ~= nil))
    local is_key = {grid=true, attr_ids=true, attr_ignore=true, condition=true,
                    any=true, mode=true}
    for _, v in ipairs(ext_keys) do
      is_key[v] = true
    end
    for k, _ in pairs(expected) do
      if not is_key[k] then
        error("Screen:expect: Unknown keyword argument '"..k.."'")
      end
    end
    grid = expected.grid
    attr_ids = expected.attr_ids
    attr_ignore = expected.attr_ignore
    condition = expected.condition
    assert(not (expected.any ~= nil and grid ~= nil))
  elseif type(expected) == "string" then
    grid = expected
    expected = {}
  elseif type(expected) == "function" then
    assert(not (attr_ids ~= nil or attr_ignore ~= nil))
    condition = expected
    expected = {}
  else
    assert(false)
  end

  if grid ~= nil then
    -- Remove the last line and dedent. Note that gsub returns more then one
    -- value.
    grid = dedent(grid:gsub('\n[ ]+$', ''), 0)
    for row in grid:gmatch('[^\n]+') do
      row = row:sub(1, #row - 1) -- Last char must be the screen delimiter.
      table.insert(expected_rows, row)
    end
  end
  local attr_state = {
      ids = attr_ids or self._default_attr_ids,
      ignore = attr_ignore or self._default_attr_ignore,
  }
  if self._options.ext_hlstate then
    attr_state.id_to_index = self:hlstate_check_attrs(attr_state.ids or {})
  end
  self._new_attrs = false
  self:wait(function()
    if condition ~= nil then
      local status, res = pcall(condition)
      if not status then
        return tostring(res)
      end
    end

    if grid ~= nil and self._height ~= #expected_rows then
      return ("Expected screen state's row count(" .. #expected_rows
              .. ') differs from configured height(' .. self._height .. ') of Screen.')
    end

    if self._options.ext_hlstate and self._new_attrs then
      attr_state.id_to_index = self:hlstate_check_attrs(attr_state.ids or {})
    end

    local actual_rows = {}
    for i = 1, self._height do
      actual_rows[i] = self:_row_repr(self._rows[i], attr_state)
    end

    if expected.any ~= nil then
      -- Search for `any` anywhere in the screen lines.
      local actual_screen_str = table.concat(actual_rows, '\n')
      if nil == string.find(actual_screen_str, expected.any) then
        return (
          'Failed to match any screen lines.\n'
          .. 'Expected (anywhere): "' .. expected.any .. '"\n'
          .. 'Actual:\n  |' .. table.concat(actual_rows, '|\n  |') .. '|\n\n')
      end
    end

    if grid ~= nil then
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

    -- Extension features. The default expectations should cover the case of
    -- the ext_ feature being disabled, or the feature currently not activated
    -- (for instance no external cmdline visible). Some extensions require
    -- preprocessing to prepresent highlights in a reproducible way.
    local extstate = self:_extstate_repr(attr_state)

    -- convert assertion errors into invalid screen state descriptions
    local status, res = pcall(function()
      for _, k in ipairs(ext_keys) do
        -- Empty states is considered the default and need not be mentioned
        if not (expected[k] == nil and isempty(extstate[k])) then
          eq(expected[k], extstate[k], k)
        end
      end
      if expected.mode ~= nil then
        eq(expected.mode, self.mode, "mode")
      end
    end)
    if not status then
      return tostring(res)
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
      table.insert(cols, {text = ' ', attrs = self._clear_attrs, hl_id = 0})
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

function Screen:_handle_grid_resize(grid, width, height)
  assert(grid == 1)
  self:_handle_resize(width, height)
end


function Screen:_handle_mode_info_set(cursor_style_enabled, mode_info)
  self._cursor_style_enabled = cursor_style_enabled
  for _, item in pairs(mode_info) do
      -- attr IDs are not stable, but their value should be
      if item.attr_id ~= nil then
        item.attr = self._attr_table[item.attr_id][1]
        item.attr_id = nil
      end
      if item.attr_id_lm ~= nil then
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
    top = 1, bot = self._height, left = 1, right = self._width
  }
  eq(expected_region, self._scroll_region)
  self:_clear_block(1, self._height, 1, self._width)
end

function Screen:_handle_grid_clear(grid)
  assert(grid == 1)
  self:_clear_block(1, self._height, 1, self._width)
end

function Screen:_handle_eol_clear()
  local row, col = self._cursor.row, self._cursor.col
  self:_clear_block(row, row, col, self._scroll_region.right)
end

function Screen:_handle_cursor_goto(row, col)
  self._cursor.row = row + 1
  self._cursor.col = col + 1
end

function Screen:_handle_grid_cursor_goto(grid, row, col)
  assert(grid == 1)
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
  self:_handle_grid_scroll(1, top-1, bot, left-1, right, count, 0)
end

function Screen:_handle_grid_scroll(grid, top, bot, left, right, rows, cols)
  top = top+1
  left = left+1
  assert(grid == 1)
  assert(cols == 0)
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
    local target = self._rows[i]
    local source = self._rows[i + rows]
    for j = left, right do
      target[j].text = source[j].text
      target[j].attrs = source[j].attrs
      target[j].hl_id = source[j].hl_id
    end
  end

  -- clear invalid rows
  for i = stop + step, stop + rows, step do
    self:_clear_row_section(i, left, right)
  end
end

function Screen:_handle_hl_attr_define(id, rgb_attrs, cterm_attrs, info)
  self._attr_table[id] = {rgb_attrs, cterm_attrs}
  self._hl_info[id] = info
  self._new_attrs = true
end

function Screen:_handle_highlight_set(attrs)
  self._attrs = attrs
end

function Screen:_handle_put(str)
  local cell = self._rows[self._cursor.row][self._cursor.col]
  cell.text = str
  cell.attrs = self._attrs
  cell.hl_id = -1
  self._cursor.col = self._cursor.col + 1
end

function Screen:_handle_grid_line(grid, row, col, items)
  assert(grid == 1)
  local line = self._rows[row+1]
  local colpos = col+1
  local hl = self._clear_attrs
  local hl_id = 0
  for _,item in ipairs(items) do
    local text, hl_id_cell, count = unpack(item)
    if hl_id_cell ~= nil then
      hl_id = hl_id_cell
      hl = self._attr_table[hl_id]
    end
    for _ = 1, (count or 1) do
      local cell = line[colpos]
      cell.text = text
      cell.hl_id = hl_id
      cell.attrs = hl
      colpos = colpos+1
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
    rgb_fg=rgb_fg,
    rgb_bg=rgb_bg,
    rgb_sp=rgb_sp,
    cterm_fg=cterm_fg,
    cterm_bg=cterm_bg
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

function Screen:_handle_popupmenu_show(items, selected, row, col)
  self.popupmenu = {items=items,pos=selected, anchor={row, col}}
end

function Screen:_handle_popupmenu_select(selected)
  self.popupmenu.pos = selected
end

function Screen:_handle_popupmenu_hide()
  self.popupmenu = nil
end

function Screen:_handle_cmdline_show(content, pos, firstc, prompt, indent, level)
  if firstc == '' then firstc = nil end
  if prompt == '' then prompt = nil end
  if indent == 0 then indent = nil end
  self.cmdline[level] = {content=content, pos=pos, firstc=firstc,
                         prompt=prompt, indent=indent}
end

function Screen:_handle_cmdline_hide(level)
  self.cmdline[level] = nil
end

function Screen:_handle_cmdline_special_char(char, shift, level)
  -- cleared by next cmdline_show on the same level
  self.cmdline[level].special = {char, shift}
end

function Screen:_handle_cmdline_pos(pos, level)
  self.cmdline[level].pos = pos
end

function Screen:_handle_cmdline_block_show(block)
  self.cmdline_block = block
end

function Screen:_handle_cmdline_block_append(item)
  self.cmdline_block[#self.cmdline_block+1] = item
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

function Screen:_clear_block(top, bot, left, right)
  for i = top, bot do
    self:_clear_row_section(i, left, right)
  end
end

function Screen:_clear_row_section(rownum, startcol, stopcol)
  local row = self._rows[rownum]
  for i = startcol, stopcol do
    row[i].text = ' '
    row[i].attrs = self._clear_attrs
  end
end

function Screen:_row_repr(row, attr_state)
  local rv = {}
  local current_attr_id
  for i = 1, self._width do
    local attrs = row[i].attrs
    if self._options.ext_newgrid then
      attrs = attrs[(self._options.rgb and 1) or 2]
    end
    local attr_id = self:_get_attr_id(attr_state, attrs, row[i].hl_id)
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

function Screen:_extstate_repr(attr_state)
  local cmdline = {}
  for i, entry in pairs(self.cmdline) do
    entry = shallowcopy(entry)
    entry.content = self:_chunks_repr(entry.content, attr_state)
    cmdline[i] = entry
  end

  local cmdline_block = {}
  for i, entry in ipairs(self.cmdline_block) do
    cmdline_block[i] = self:_chunks_repr(entry, attr_state)
  end

  return {
    popupmenu=self.popupmenu,
    cmdline=cmdline,
    cmdline_block=cmdline_block,
    wildmenu_items=self.wildmenu_items,
    wildmenu_pos=self.wildmenu_pos,
  }
end

function Screen:_chunks_repr(chunks, attr_state)
  local repr_chunks = {}
  for i, chunk in ipairs(chunks) do
    local hl, text = unpack(chunk)
    local attrs
    if self._options.ext_newgrid then
      attrs = self._attr_table[hl][1]
    else
      attrs = hl
    end
    local attr_id = self:_get_attr_id(attr_state, attrs, hl)
    repr_chunks[i] = {text, attr_id}
  end
  return repr_chunks
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
  attrs = attrs or self._default_attr_ids
  if ignore == nil then
    ignore = self._default_attr_ignore
  end
  local attr_state = {
      ids = {},
      ignore = ignore,
      mutable = true, -- allow _row_repr to add missing highlights
  }

  if attrs ~= nil then
    for i, a in pairs(attrs) do
      attr_state.ids[i] = a
    end
  end
  if self._options.ext_hlstate then
    attr_state.id_to_index = self:hlstate_check_attrs(attr_state.ids)
  end

  local lines = {}
  for i = 1, self._height do
    table.insert(lines, "  "..self:_row_repr(self._rows[i], attr_state).."|")
  end

  local ext_state = self:_extstate_repr(attr_state)
  local keys = false
  for k, v in pairs(ext_state) do
    if isempty(v) then
      ext_state[k] = nil -- deleting keys while iterating is ok
    else
      keys = true
    end
  end

  local attrstr = ""
  if attr_state.modified then
    local attrstrs = {}
    for i, a in pairs(attr_state.ids) do
      local dict
      if self._options.ext_hlstate then
        dict = self:_pprint_hlstate(a)
      else
        dict = "{"..self:_pprint_attrs(a).."}"
      end
      local keyval = (type(i) == "number") and "["..tostring(i).."]" or i
      table.insert(attrstrs, "  "..keyval.." = "..dict..",")
    end
    attrstr = (", "..(keys and "attr_ids=" or "")
               .."{\n"..table.concat(attrstrs, "\n").."\n}")
  end
  print( "\nscreen:expect"..(keys and "{grid=" or "(").."[[")
  print( table.concat(lines, '\n'))
  io.stdout:write( "]]"..attrstr)
  for _, k in ipairs(ext_keys) do
    if ext_state[k] ~= nil then
      io.stdout:write(", "..k.."="..inspect(ext_state[k]))
    end
  end
  print((keys and "}" or ")").."\n")
  io.stdout:flush()
end

function Screen:_insert_hl_id(attr_state, hl_id)
  if attr_state.id_to_index[hl_id] ~= nil then
    return attr_state.id_to_index[hl_id]
  end
  local raw_info = self._hl_info[hl_id]
  local info = {}
  if #raw_info > 1 then
    for i, item in ipairs(raw_info) do
      info[i] = self:_insert_hl_id(attr_state, item.id)
    end
  else
    info[1] = {}
    for k, v in pairs(raw_info[1]) do
      if k ~= "id" then
        info[1][k] = v
      end
    end
  end

  local entry = self._attr_table[hl_id]
  local attrval
  if self._hlstate_cterm then
    attrval = {entry[1], entry[2], info} -- unpack() doesn't work
  else
    attrval = {entry[1], info}
  end


  table.insert(attr_state.ids, attrval)
  attr_state.id_to_index[hl_id] = #attr_state.ids
  return #attr_state.ids
end

function Screen:hlstate_check_attrs(attrs)
  local id_to_index = {}
  for i = 1,#self._attr_table do
    local iinfo = self._hl_info[i]
    local matchinfo = {}
    if #iinfo > 1 then
      for k,item in ipairs(iinfo) do
        matchinfo[k] = id_to_index[item.id]
      end
    else
      matchinfo = iinfo
    end
    for k,v in pairs(attrs) do
      local attr, info, attr_rgb, attr_cterm
      if self._hlstate_cterm then
        attr_rgb, attr_cterm, info = unpack(v)
        attr = {attr_rgb, attr_cterm}
      else
        attr, info = unpack(v)
      end
      if self:_equal_attr_def(attr, self._attr_table[i]) then
        if #info == #matchinfo then
          local match = false
          if #info == 1 then
            if self:_equal_info(info[1],matchinfo[1]) then
              match = true
            end
          else
            match = true
            for j = 1,#info do
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
  end
  return id_to_index
end


function Screen:_pprint_hlstate(item)
    --print(require('inspect')(item))
    local attrdict = "{"..self:_pprint_attrs(item[1]).."}, "
    local attrdict2, hlinfo
    if self._hlstate_cterm then
      attrdict2 = "{"..self:_pprint_attrs(item[2]).."}, "
      hlinfo = item[3]
    else
      attrdict2 = ""
      hlinfo = item[2]
    end
    local descdict = "{"..self:_pprint_hlinfo(hlinfo).."}"
    return "{"..attrdict..attrdict2..descdict.."}"
end

function Screen:_pprint_hlinfo(states)
  if #states == 1 then
    local items = {}
    for f, v in pairs(states[1]) do
      local desc = tostring(v)
      if type(v) == type("") then
        desc = '"'..desc..'"'
      end
      table.insert(items, f.." = "..desc)
    end
    return "{"..table.concat(items, ", ").."}"
  else
    return table.concat(states, ", ")
  end
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

function Screen:_get_attr_id(attr_state, attrs, hl_id)
  if not attr_state.ids then
    return
  end

  if self._options.ext_hlstate then
    local id = attr_state.id_to_index[hl_id]
    if id ~= nil or hl_id == 0 then
      return id
    end
    if attr_state.mutable then
      id = self:_insert_hl_id(attr_state, hl_id)
      attr_state.modified = true
      return id
    end
    return "UNEXPECTED "..self:_pprint_attrs(self._attr_table[hl_id][1])
  else
    for id, a in pairs(attr_state.ids) do
      if self:_equal_attrs(a, attrs) then
         return id
       end
    end
    if self:_equal_attrs(attrs, {}) or
        attr_state.ignore == true or
        self:_attr_index(attr_state.ignore, attrs) ~= nil then
      -- ignore this attrs
      return nil
    end
    if attr_state.mutable then
      table.insert(attr_state.ids, attrs)
      attr_state.modified = true
      return #attr_state.ids
    end
    return "UNEXPECTED "..self:_pprint_attrs(attrs)
  end
end

function Screen:_equal_attr_def(a, b)
  if self._hlstate_cterm then
    return self:_equal_attrs(a[1],b[1]) and self:_equal_attrs(a[2],b[2])
  else
    return self:_equal_attrs(a,b[1])
  end
end

function Screen:_equal_attrs(a, b)
    return a.bold == b.bold and a.standout == b.standout and
       a.underline == b.underline and a.undercurl == b.undercurl and
       a.italic == b.italic and a.reverse == b.reverse and
       a.foreground == b.foreground and a.background == b.background and
       a.special == b.special
end

function Screen:_equal_info(a, b)
    return a.kind == b.kind and a.hi_name == b.hi_name and
       a.ui_name == b.ui_name
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
