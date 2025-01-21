local t = require('test.unit.testutil')
local itp = t.gen_itp(it)
local bit = require('bit')

--- @class vterm
--- @field ENC_UTF8 integer
--- @field VTERM_ATTR_BLINK integer
--- @field VTERM_ATTR_BOLD integer
--- @field VTERM_ATTR_FONT integer
--- @field VTERM_ATTR_ITALIC integer
--- @field VTERM_ATTR_REVERSE integer
--- @field VTERM_ATTR_UNDERLINE integer
--- @field VTERM_BASELINE_RAISE integer
--- @field VTERM_KEY_ENTER integer
--- @field VTERM_KEY_FUNCTION_0 integer
--- @field VTERM_KEY_KP_0 integer
--- @field VTERM_KEY_NONE integer
--- @field VTERM_KEY_TAB integer
--- @field VTERM_KEY_UP integer
--- @field VTERM_KEY_BACKSPACE integer
--- @field VTERM_KEY_ESCAPE integer
--- @field VTERM_KEY_DEL integer
--- @field VTERM_MOD_ALT integer
--- @field VTERM_MOD_CTRL integer
--- @field VTERM_MOD_SHIFT integer
--- @field parser_apc function
--- @field parser_csi function
--- @field parser_dcs function
--- @field parser_osc function
--- @field parser_pm function
--- @field parser_sos function
--- @field parser_text function
--- @field print_color function
--- @field schar_get fun(any, any):integer
--- @field screen_sb_clear function
--- @field screen_sb_popline function
--- @field screen_sb_pushline function
--- @field selection_query function
--- @field selection_set function
--- @field state_erase function
--- @field state_movecursor function
--- @field state_moverect function
--- @field state_pos function
--- @field state_putglyph function
--- @field state_sb_clear function
--- @field state_scrollrect function
--- @field state_setpenattr function
--- @field state_settermprop function
--- @field term_output function
--- @field utf_ptr2char fun(any):integer
--- @field utf_ptr2len fun(any):integer
--- @field vterm_input_write function
--- @field vterm_keyboard_end_paste function
--- @field vterm_keyboard_key function
--- @field vterm_keyboard_start_paste function
--- @field vterm_keyboard_unichar function
--- @field vterm_lookup_encoding fun(any, any):any
--- @field vterm_mouse_button function
--- @field vterm_mouse_move function
--- @field vterm_new fun(any, any):any
--- @field vterm_obtain_screen fun(any):any
--- @field vterm_obtain_state fun(any): any
--- @field vterm_output_set_callback function
--- @field vterm_parser_set_callbacks fun(any, any, any):any
--- @field vterm_screen_convert_color_to_rgb function
--- @field vterm_screen_enable_altscreen function
--- @field vterm_screen_enable_reflow function
--- @field vterm_screen_get_attrs_extent function
--- @field vterm_screen_get_cell function
--- @field vterm_screen_get_text fun(any, any, any, any):any
--- @field vterm_screen_is_eol fun(any, any):any
--- @field vterm_screen_reset function
--- @field vterm_screen_set_callbacks function
--- @field vterm_set_size function
--- @field vterm_set_utf8 fun(any, any, any):any
--- @field vterm_state_focus_in function
--- @field vterm_state_focus_out function
--- @field vterm_state_get_cursorpos fun(any, any)
--- @field vterm_state_get_lineinfo fun(any, any):any
--- @field vterm_state_get_penattr function
--- @field vterm_state_reset function
--- @field vterm_state_set_bold_highbright function
--- @field vterm_state_set_callbacks function
--- @field vterm_state_set_selection_callbacks function
--- @field vterm_state_set_unrecognised_fallbacks function
local vterm = t.cimport(
  './src/nvim/grid.h',
  './src/nvim/mbyte.h',
  './src/nvim/vterm/encoding.h',
  './src/nvim/vterm/keyboard.h',
  './src/nvim/vterm/mouse.h',
  './src/nvim/vterm/parser.h',
  './src/nvim/vterm/pen.h',
  './src/nvim/vterm/screen.h',
  './src/nvim/vterm/state.h',
  './src/nvim/vterm/vterm.h',
  './src/nvim/vterm/vterm_internal.h',
  './test/unit/fixtures/vterm_test.h'
)

--- @return string
local function read_rm()
  local f = assert(io.open(t.paths.vterm_test_file, 'rb'))
  local text = f:read('*a')
  f:close()
  vim.fs.rm(t.paths.vterm_test_file, { force = true })
  return text
end

local function append(str)
  local f = assert(io.open(t.paths.vterm_test_file, 'a'))
  f:write(str)
  f:close()
  return 1
end

local function parser_control(control)
  return append(string.format('control %02x\n', control))
end

local function parser_escape(bytes)
  return append(string.format('escape %s\n', t.ffi.string(bytes)))
end

local function wantparser(vt)
  assert(vt)

  local parser_cbs = t.ffi.new('VTermParserCallbacks')
  parser_cbs['text'] = vterm.parser_text
  parser_cbs['control'] = parser_control
  parser_cbs['escape'] = parser_escape
  parser_cbs['csi'] = vterm.parser_csi
  parser_cbs['osc'] = vterm.parser_osc
  parser_cbs['dcs'] = vterm.parser_dcs
  parser_cbs['apc'] = vterm.parser_apc
  parser_cbs['pm'] = vterm.parser_pm
  parser_cbs['sos'] = vterm.parser_sos

  vterm.vterm_parser_set_callbacks(vt, parser_cbs, nil)
end

--- @return any
local function init()
  local vt = vterm.vterm_new(25, 80)
  vterm.vterm_output_set_callback(vt, vterm.term_output, nil)
  vterm.vterm_set_utf8(vt, true)
  return vt
end

local function state_setlineinfo()
  return 1
end

--- @return any
local function wantstate(vt, opts)
  opts = opts or {}
  assert(vt)
  local state = vterm.vterm_obtain_state(vt)

  local state_cbs = t.ffi.new('VTermStateCallbacks')
  state_cbs['putglyph'] = vterm.state_putglyph
  state_cbs['movecursor'] = vterm.state_movecursor
  state_cbs['scrollrect'] = vterm.state_scrollrect
  state_cbs['moverect'] = vterm.state_moverect
  state_cbs['erase'] = vterm.state_erase
  state_cbs['setpenattr'] = vterm.state_setpenattr
  state_cbs['settermprop'] = vterm.state_settermprop
  state_cbs['setlineinfo'] = state_setlineinfo
  state_cbs['sb_clear'] = vterm.state_sb_clear

  local selection_cbs = t.ffi.new('VTermSelectionCallbacks')
  selection_cbs['set'] = vterm.selection_set
  selection_cbs['query'] = vterm.selection_query

  vterm.vterm_state_set_callbacks(state, state_cbs, nil)

  -- In some tests we want to check the behaviour of overflowing the buffer, so make it nicely small
  vterm.vterm_state_set_selection_callbacks(state, selection_cbs, nil, nil, 16)
  vterm.vterm_state_set_bold_highbright(state, 1)
  vterm.vterm_state_reset(state, 1)

  local fallbacks = t.ffi.new('VTermStateFallbacks')
  fallbacks['control'] = parser_control
  fallbacks['csi'] = vterm.parser_csi
  fallbacks['osc'] = vterm.parser_osc
  fallbacks['dcs'] = vterm.parser_dcs
  fallbacks['apc'] = vterm.parser_apc
  fallbacks['pm'] = vterm.parser_pm
  fallbacks['sos'] = vterm.parser_sos

  vterm.want_state_scrollback = opts.b or false
  vterm.want_state_erase = opts.e or false
  vterm.vterm_state_set_unrecognised_fallbacks(state, opts.f and fallbacks or nil, nil)
  vterm.want_state_putglyph = opts.g or false
  vterm.want_state_moverect = opts.m or false
  vterm.want_state_settermprop = opts.p or false
  vterm.want_state_scrollrect = opts.s or false

  return state
end

--- @return any
local function wantscreen(vt, opts)
  opts = opts or {}
  local screen = vterm.vterm_obtain_screen(vt)
  local screen_cbs = t.ffi.new('VTermScreenCallbacks')

  -- TODO(dundargoc): fix
  -- screen_cbs['damage']      = vterm.screen_damage
  screen_cbs['moverect'] = vterm.state_moverect
  screen_cbs['movecursor'] = vterm.state_movecursor
  screen_cbs['settermprop'] = vterm.state_settermprop
  screen_cbs['sb_pushline'] = vterm.screen_sb_pushline
  screen_cbs['sb_popline'] = vterm.screen_sb_popline
  screen_cbs['sb_clear'] = vterm.screen_sb_clear

  vterm.vterm_screen_set_callbacks(screen, screen_cbs, nil)

  if opts.a then
    vterm.vterm_screen_enable_altscreen(screen, 1)
  end
  vterm.want_screen_scrollback = opts.b or false
  vterm.want_state_movecursor = opts.c or false
  -- TODO(dundargoc): fix
  -- vterm.want_screen_damage = opts.d or opts.D or false
  -- vterm.want_screen_cells = opts.D or false
  vterm.want_state_moverect = opts.m or false
  vterm.want_state_settermprop = opts.p or false
  if opts.r then
    vterm.vterm_screen_enable_reflow(screen, true)
  end

  return screen
end

local function reset(state, screen)
  if state then
    vterm.vterm_state_reset(state, 1)
    vterm.vterm_state_get_cursorpos(state, vterm.state_pos)
  end
  if screen then
    vterm.vterm_screen_reset(screen, 1)
  end
end

local function push(input, vt)
  vterm.vterm_input_write(vt, input, string.len(input))
end

local function expect(expected)
  local actual = read_rm()
  t.eq(expected .. '\n', actual)
end

local function expect_output(expected_preformat)
  local actual = read_rm()
  local expected = 'output '

  for c in string.gmatch(expected_preformat, '.') do
    if expected ~= 'output ' then
      expected = expected .. ','
    end
    expected = string.format('%s%x', expected, string.byte(c))
  end

  t.eq(expected .. '\n', actual)
end

local function cursor(row, col, state)
  local pos = t.ffi.new('VTermPos') --- @type {row: integer, col: integer}
  vterm.vterm_state_get_cursorpos(state, pos)
  t.eq(row, pos.row)
  t.eq(col, pos.col)
end

local function lineinfo(row, expected, state)
  local info = vterm.vterm_state_get_lineinfo(state, row)
  local dwl = info.doublewidth == 1
  local dhl = info.doubleheight == 1
  local cont = info.continuation == 1

  t.eq(dwl, expected.dwl or false)
  t.eq(dhl, expected.dhl or false)
  t.eq(cont, expected.cont or false)
end

local function pen(attribute, expected, state)
  local is_bool = { bold = true, italic = true, blink = true, reverse = true }
  local vterm_attribute = {
    bold = vterm.VTERM_ATTR_BOLD,
    underline = vterm.VTERM_ATTR_UNDERLINE,
    italic = vterm.VTERM_ATTR_ITALIC,
    blink = vterm.VTERM_ATTR_BLINK,
    reverse = vterm.VTERM_ATTR_REVERSE,
    font = vterm.VTERM_ATTR_FONT,
  }

  local val = t.ffi.new('VTermValue') --- @type {boolean: integer}
  vterm.vterm_state_get_penattr(state, vterm_attribute[attribute], val)
  local actual = val.boolean --- @type integer|boolean
  if is_bool[attribute] then
    actual = val.boolean == 1
  end
  t.eq(expected, actual)
end

local function resize(rows, cols, vt)
  vterm.vterm_set_size(vt, rows, cols)
end

local function screen_chars(start_row, start_col, end_row, end_col, expected, screen)
  local rect = t.ffi.new('VTermRect')
  rect['start_row'] = start_row
  rect['start_col'] = start_col
  rect['end_row'] = end_row
  rect['end_col'] = end_col

  local len = vterm.vterm_screen_get_text(screen, nil, 0, rect)

  local text = t.ffi.new('unsigned char[?]', len)
  vterm.vterm_screen_get_text(screen, text, len, rect)

  local actual = t.ffi.string(text, len)
  t.eq(expected, actual)
end

local function screen_text(start_row, start_col, end_row, end_col, expected, screen)
  local rect = t.ffi.new('VTermRect')
  rect['start_row'] = start_row
  rect['start_col'] = start_col
  rect['end_row'] = end_row
  rect['end_col'] = end_col

  local len = vterm.vterm_screen_get_text(screen, nil, 0, rect)

  local text = t.ffi.new('unsigned char[?]', len)
  vterm.vterm_screen_get_text(screen, text, len, rect)

  local actual = ''
  for i = 0, tonumber(len) - 1 do
    actual = string.format('%s%02x,', actual, text[i])
  end
  actual = actual:sub(1, -2)

  t.eq(expected, actual)
end

--- @param row integer
local function screen_row(row, expected, screen, end_col)
  local rect = t.ffi.new('VTermRect')
  rect['start_row'] = row
  rect['start_col'] = 0
  rect['end_row'] = row + 1
  rect['end_col'] = end_col or 80

  local len = vterm.vterm_screen_get_text(screen, nil, 0, rect)

  local text = t.ffi.new('unsigned char[?]', len)
  vterm.vterm_screen_get_text(screen, text, len, rect)

  t.eq(expected, t.ffi.string(text, len))
end

local function screen_cell(row, col, expected, screen)
  local pos = t.ffi.new('VTermPos')
  pos['row'] = row
  pos['col'] = col

  local cell = t.ffi.new('VTermScreenCell') ---@type any
  vterm.vterm_screen_get_cell(screen, pos, cell)

  local buf = t.ffi.new('unsigned char[32]')
  vterm.schar_get(buf, cell.schar)

  local actual = '{'
  local i = 0
  while buf[i] > 0 do
    local char = vterm.utf_ptr2char(buf + i)
    local charlen = vterm.utf_ptr2len(buf + i)
    if i > 0 then
      actual = actual .. ','
    end
    local invalid = char >= 128 and charlen == 1
    actual = string.format('%s%s%02x', actual, invalid and '?' or '', char)
    i = i + charlen
  end
  actual = string.format('%s} width=%d attrs={', actual, cell['width'])
  actual = actual .. (cell['attrs'].bold ~= 0 and 'B' or '')
  actual = actual
    .. (cell['attrs'].underline ~= 0 and string.format('U%d', cell['attrs'].underline) or '')
  actual = actual .. (cell['attrs'].italic ~= 0 and 'I' or '')
  actual = actual .. (cell['attrs'].blink ~= 0 and 'K' or '')
  actual = actual .. (cell['attrs'].reverse ~= 0 and 'R' or '')
  actual = actual .. (cell['attrs'].font ~= 0 and string.format('F%d', cell['attrs'].font) or '')
  actual = actual .. (cell['attrs'].small ~= 0 and 'S' or '')
  if cell['attrs'].baseline ~= 0 then
    actual = actual .. (cell['attrs'].baseline == vterm.VTERM_BASELINE_RAISE and '^' or '_')
  end
  actual = actual .. '} '

  actual = actual .. (cell['attrs'].dwl ~= 0 and 'dwl ' or '')
  if cell['attrs'].dhl ~= 0 then
    actual = actual .. string.format('dhl-%s ', cell['attrs'].dhl == 2 and 'bottom' or 'top')
  end

  actual = string.format('%sfg=', actual)
  vterm.vterm_screen_convert_color_to_rgb(screen, cell['fg'])
  vterm.print_color(cell['fg'])

  actual = actual .. read_rm()
  actual = actual .. ' bg='

  vterm.vterm_screen_convert_color_to_rgb(screen, cell['bg'])
  vterm.print_color(cell['bg'])

  actual = actual .. read_rm()

  t.eq(expected, actual)
end

local function screen_eol(row, col, expected, screen)
  local pos = t.ffi.new('VTermPos')
  pos['row'] = row
  pos['col'] = col

  local is_eol = vterm.vterm_screen_is_eol(screen, pos)
  t.eq(expected, is_eol)
end

local function screen_attrs_extent(row, col, expected, screen)
  local pos = t.ffi.new('VTermPos')
  pos['row'] = row
  pos['col'] = col

  local rect = t.ffi.new('VTermRect')
  rect['start_col'] = 0
  rect['end_col'] = -1
  vterm.vterm_screen_get_attrs_extent(screen, rect, pos, 1)

  local actual = string.format(
    '%d,%d-%d,%d',
    rect['start_row'],
    rect['start_col'],
    rect['end_row'],
    rect['end_col']
  )

  t.eq(expected, actual)
end

local function wantencoding()
  local encoding = t.ffi.new('VTermEncodingInstance')
  encoding['enc'] = vterm.vterm_lookup_encoding(vterm.ENC_UTF8, string.byte('u'))
  if encoding.enc.init then
    encoding.enc.init(encoding.enc, encoding['data'])
  end
  return encoding
end

local function encin(input, encoding)
  local len = string.len(input)

  local cp = t.ffi.new('uint32_t[?]', len)
  local cpi = t.ffi.new('int[1]')
  local pos = t.ffi.new('size_t[1]', 0)

  encoding.enc.decode(encoding.enc, encoding.data, cp, cpi, len, input, pos, len)

  local f = assert(io.open(t.paths.vterm_test_file, 'w'))
  if tonumber(cpi[0]) > 0 then
    f:write('encout ')
    for i = 0, cpi[0] - 1 do
      if i == 0 then
        f:write(string.format('%x', cp[i]))
      else
        f:write(string.format(',%x', cp[i]))
      end
    end
    f:write('\n')
  end
  f:close()
end

local function strpe_modifiers(input_mod)
  local mod = t.ffi.new('VTermModifier') ---@type any
  if input_mod.C then
    mod = bit.bor(mod, vterm.VTERM_MOD_CTRL)
  end
  if input_mod.S then
    mod = bit.bor(mod, vterm.VTERM_MOD_SHIFT)
  end
  if input_mod.A then
    mod = bit.bor(mod, vterm.VTERM_MOD_ALT)
  end
  return mod
end

local function strp_key(input_key)
  if input_key == 'up' then
    return vterm.VTERM_KEY_UP
  end

  if input_key == 'tab' then
    return vterm.VTERM_KEY_TAB
  end

  if input_key == 'enter' then
    return vterm.VTERM_KEY_ENTER
  end

  if input_key == 'bs' then
    return vterm.VTERM_KEY_BACKSPACE
  end

  if input_key == 'del' then
    return vterm.VTERM_KEY_DEL
  end

  if input_key == 'esc' then
    return vterm.VTERM_KEY_ESCAPE
  end

  if input_key == 'f1' then
    return vterm.VTERM_KEY_FUNCTION_0 + 1
  end

  if input_key == 'kp0' then
    return vterm.VTERM_KEY_KP_0
  end

  return vterm.VTERM_KEY_NONE
end

local function mousemove(row, col, vt, input_mod)
  input_mod = input_mod or {}
  local mod = strpe_modifiers(input_mod)
  vterm.vterm_mouse_move(vt, row, col, mod)
end

local function mousebtn(press, button, vt, input_mod)
  input_mod = input_mod or {}
  local mod = strpe_modifiers(input_mod)
  local flag = press == 'd' or press == 'D'
  vterm.vterm_mouse_button(vt, button, flag, mod)
end

local function inchar(c, vt, input_mod)
  input_mod = input_mod or {}
  local mod = strpe_modifiers(input_mod)
  vterm.vterm_keyboard_unichar(vt, c, mod)
end

local function inkey(input_key, vt, input_mod)
  input_mod = input_mod or {}
  local mod = strpe_modifiers(input_mod)
  local key = strp_key(input_key)
  vterm.vterm_keyboard_key(vt, key, mod)
end

before_each(function()
  vim.fs.rm(t.paths.vterm_test_file, { force = true })
end)

describe('vterm', function()
  itp('02parser', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, false)
    wantparser(vt)

    -- Basic text
    push('hello', vt)
    expect('text 68,65,6c,6c,6f')

    -- C0
    push('\x03', vt)
    expect('control 03')
    push('\x1f', vt)
    expect('control 1f')

    -- C1 8bit
    push('\x83', vt)
    expect('control 83')
    push('\x99', vt)
    expect('control 99')

    -- C1 7bit
    push('\x1b\x43', vt)
    expect('control 83')
    push('\x1b\x59', vt)
    expect('control 99')

    -- High bytes
    push('\xa0\xcc\xfe', vt)
    expect('text a0,cc,fe')

    -- Mixed
    push('1\n2', vt)
    expect('text 31\ncontrol 0a\ntext 32')

    -- Escape
    push('\x1b=', vt)
    expect('escape =')

    -- Escape 2-byte
    push('\x1b(X', vt)
    expect('escape (X')

    -- Split write Escape
    push('\x1b(', vt)
    push('Y', vt)
    expect('escape (Y')

    -- Escape cancels Escape, starts another
    push('\x1b(\x1b)Z', vt)
    expect('escape )Z')

    -- CAN cancels Escape, returns to normal mode
    push('\x1b(\x18AB', vt)
    expect('text 41,42')

    -- C0 in Escape interrupts and continues
    push('\x1b(\nX', vt)
    expect('control 0a\nescape (X')

    -- CSI 0 args
    push('\x1b[a', vt)
    expect('csi 61 *')

    -- CSI 1 arg
    push('\x1b[9b', vt)
    expect('csi 62 9')

    -- CSI 2 args
    push('\x1b[3;4c', vt)
    expect('csi 63 3,4')

    -- CSI 1 arg 1 sub
    push('\x1b[1:2c', vt)
    expect('csi 63 1+,2')

    -- CSI many digits
    push('\x1b[678d', vt)
    expect('csi 64 678')

    -- CSI leading zero
    push('\x1b[007e', vt)
    expect('csi 65 7')

    -- CSI qmark
    push('\x1b[?2;7f', vt)
    expect('csi 66 L=3f 2,7')

    -- CSI greater
    push('\x1b[>c', vt)
    expect('csi 63 L=3e *')

    -- CSI SP
    push('\x1b[12 q', vt)
    expect('csi 71 12 I=20')

    -- Mixed CSI
    push('A\x1b[8mB', vt)
    expect('text 41\ncsi 6d 8\ntext 42')

    -- Split write
    push('\x1b', vt)
    push('[a', vt)
    expect('csi 61 *')
    push('foo\x1b[', vt)
    expect('text 66,6f,6f')
    push('4b', vt)
    expect('csi 62 4')
    push('\x1b[12;', vt)
    push('3c', vt)
    expect('csi 63 12,3')

    -- Escape cancels CSI, starts Escape
    push('\x1b[123\x1b9', vt)
    expect('escape 9')

    -- CAN cancels CSI, returns to normal mode
    push('\x1b[12\x18AB', vt)
    expect('text 41,42')

    -- C0 in Escape interrupts and continues
    push('\x1b(\nX', vt)
    expect('control 0a\nescape (X')

    -- OSC BEL
    push('\x1b]1;Hello\x07', vt)
    expect('osc [1;Hello]')

    -- OSC ST (7bit)
    push('\x1b]1;Hello\x1b\\', vt)
    expect('osc [1;Hello]')

    -- OSC ST (8bit)
    push('\x9d1;Hello\x9c', vt)
    expect('osc [1;Hello]')

    -- OSC in parts
    push('\x1b]52;abc', vt)
    expect('osc [52;abc')
    push('def', vt)
    expect('osc def')
    push('ghi\x1b\\', vt)
    expect('osc ghi]')

    -- OSC BEL without semicolon
    push('\x1b]1234\x07', vt)
    expect('osc [1234;]')

    -- OSC ST without semicolon
    push('\x1b]1234\x1b\\', vt)
    expect('osc [1234;]')

    -- Escape cancels OSC, starts Escape
    push('\x1b]Something\x1b9', vt)
    expect('escape 9')

    -- CAN cancels OSC, returns to normal mode
    push('\x1b]12\x18AB', vt)
    expect('text 41,42')

    -- C0 in OSC interrupts and continues
    push('\x1b]2;\nBye\x07', vt)
    expect('osc [2;\ncontrol 0a\nosc Bye]')

    -- DCS BEL
    push('\x1bPHello\x07', vt)
    expect('dcs [Hello]')

    -- DCS ST (7bit)
    push('\x1bPHello\x1b\\', vt)
    expect('dcs [Hello]')

    -- DCS ST (8bit)
    push('\x90Hello\x9c', vt)
    expect('dcs [Hello]')

    -- Split write of 7bit ST
    push('\x1bPABC\x1b', vt)
    expect('dcs [ABC')
    push('\\', vt)
    expect('dcs ]')

    -- Escape cancels DCS, starts Escape
    push('\x1bPSomething\x1b9', vt)
    expect('escape 9')

    -- CAN cancels DCS, returns to normal mode
    push('\x1bP12\x18AB', vt)
    expect('text 41,42')

    -- C0 in OSC interrupts and continues
    push('\x1bPBy\ne\x07', vt)
    expect('dcs [By\ncontrol 0a\ndcs e]')

    -- APC BEL
    push('\x1b_Hello\x07', vt)
    expect('apc [Hello]')

    -- APC ST (7bit)
    push('\x1b_Hello\x1b\\', vt)
    expect('apc [Hello]')

    -- APC ST (8bit)
    push('\x9fHello\x9c', vt)
    expect('apc [Hello]')

    -- PM BEL
    push('\x1b^Hello\x07', vt)
    expect('pm [Hello]')

    -- PM ST (7bit)
    push('\x1b^Hello\x1b\\', vt)
    expect('pm [Hello]')

    -- PM ST (8bit)
    push('\x9eHello\x9c', vt)
    expect('pm [Hello]')

    -- SOS BEL
    push('\x1bXHello\x07', vt)
    expect('sos [Hello]')

    -- SOS ST (7bit)
    push('\x1bXHello\x1b\\', vt)
    expect('sos [Hello]')

    -- SOS ST (8bit)
    push('\x98Hello\x9c', vt)
    expect('sos [Hello]')

    push('\x1bXABC\x01DEF\x1b\\', vt)
    expect('sos [ABC\x01DEF]')
    push('\x1bXABC\x99DEF\x1b\\', vt)
    expect('sos [ABC\x99DEF]')

    -- NUL ignored
    push('\x00', vt)

    -- NUL ignored within CSI
    push('\x1b[12\x003m', vt)
    expect('csi 6d 123')

    -- DEL ignored
    push('\x7f', vt)

    -- DEL ignored within CSI
    push('\x1b[12\x7f3m', vt)
    expect('csi 6d 123')

    -- DEL inside text"
    push('AB\x7fC', vt)
    expect('text 41,42\ntext 43')
  end)

  itp('03encoding_utf8', function()
    local encoding = wantencoding()

    -- Low
    encin('123', encoding)
    expect('encout 31,32,33')

    -- We want to prove the UTF-8 parser correctly handles all the sequences.
    -- Easy way to do this is to check it does low/high boundary cases, as that
    -- leaves only two for each sequence length
    --
    -- These ranges are therefore:
    --
    -- Two bytes:
    -- U+0080 = 000 10000000 =>    00010   000000
    --                       => 11000010 10000000 = C2 80
    -- U+07FF = 111 11111111 =>    11111   111111
    --                       => 11011111 10111111 = DF BF
    --
    -- Three bytes:
    -- U+0800 = 00001000 00000000 =>     0000   100000   000000
    --                            => 11100000 10100000 10000000 = E0 A0 80
    -- U+FFFD = 11111111 11111101 =>     1111   111111   111101
    --                            => 11101111 10111111 10111101 = EF BF BD
    -- (We avoid U+FFFE and U+FFFF as they're invalid codepoints)
    --
    -- Four bytes:
    -- U+10000  = 00001 00000000 00000000 =>      000   010000   000000   000000
    --                                    => 11110000 10010000 10000000 10000000 = F0 90 80 80
    -- U+1FFFFF = 11111 11111111 11111111 =>      111   111111   111111   111111
    --                                    => 11110111 10111111 10111111 10111111 = F7 BF BF BF

    -- 2 byte
    encin('\xC2\x80\xDF\xBF', encoding)
    expect('encout 80,7ff')

    -- 3 byte
    encin('\xE0\xA0\x80\xEF\xBF\xBD', encoding)
    expect('encout 800,fffd')

    -- 4 byte
    encin('\xF0\x90\x80\x80\xF7\xBF\xBF\xBF', encoding)
    expect('encout 10000,1fffff')

    -- Next up, we check some invalid sequences
    --  + Early termination (back to low bytes too soon)
    --  + Early restart (another sequence introduction before the previous one was finished)

    -- Early termination
    encin('\xC2!', encoding)
    expect('encout fffd,21')

    encin('\xE0!\xE0\xA0!', encoding)
    expect('encout fffd,21,fffd,21')

    encin('\xF0!\xF0\x90!\xF0\x90\x80!', encoding)
    expect('encout fffd,21,fffd,21,fffd,21')

    -- Early restart
    encin('\xC2\xC2\x90', encoding)
    expect('encout fffd,90')

    encin('\xE0\xC2\x90\xE0\xA0\xC2\x90', encoding)
    expect('encout fffd,90,fffd,90')

    encin('\xF0\xC2\x90\xF0\x90\xC2\x90\xF0\x90\x80\xC2\x90', encoding)
    expect('encout fffd,90,fffd,90,fffd,90')

    -- Test the overlong sequences by giving an overlong encoding of U+0000 and
    -- an encoding of the highest codepoint still too short
    --
    -- Two bytes:
    -- U+0000 = C0 80
    -- U+007F = 000 01111111 =>    00001   111111 =>
    --                       => 11000001 10111111 => C1 BF
    --
    -- Three bytes:
    -- U+0000 = E0 80 80
    -- U+07FF = 00000111 11111111 =>     0000   011111   111111
    --                            => 11100000 10011111 10111111 = E0 9F BF
    --
    -- Four bytes:
    -- U+0000 = F0 80 80 80
    -- U+FFFF = 11111111 11111111 =>      000   001111   111111   111111
    --                            => 11110000 10001111 10111111 10111111 = F0 8F BF BF

    -- Overlong
    encin('\xC0\x80\xC1\xBF', encoding)
    expect('encout fffd,fffd')

    encin('\xE0\x80\x80\xE0\x9F\xBF', encoding)
    expect('encout fffd,fffd')

    encin('\xF0\x80\x80\x80\xF0\x8F\xBF\xBF', encoding)
    expect('encout fffd,fffd')

    -- UTF-16 surrogates U+D800 and U+DFFF
    -- UTF-16 Surrogates
    encin('\xED\xA0\x80\xED\xBF\xBF', encoding)
    expect('encout fffd,fffd')

    -- Split write
    encin('\xC2', encoding)
    encin('\xA0', encoding)
    expect('encout a0')

    encin('\xE0', encoding)
    encin('\xA0\x80', encoding)
    expect('encout 800')
    encin('\xE0\xA0', encoding)
    encin('\x80', encoding)
    expect('encout 800')

    encin('\xF0', encoding)
    encin('\x90\x80\x80', encoding)
    expect('encout 10000')
    encin('\xF0\x90', encoding)
    encin('\x80\x80', encoding)
    expect('encout 10000')
    encin('\xF0\x90\x80', encoding)
    encin('\x80', encoding)
    expect('encout 10000')
  end)

  itp('10state_putglyph', function()
    local vt = init()
    local state = wantstate(vt, { g = true })

    -- Low
    reset(state, nil)
    push('ABC', vt)
    expect('putglyph 41 1 0,0\nputglyph 42 1 0,1\nputglyph 43 1 0,2')

    -- UTF-8 1 char
    -- U+00C1 = 0xC3 0x81  name: LATIN CAPITAL LETTER A WITH ACUTE
    -- U+00E9 = 0xC3 0xA9  name: LATIN SMALL LETTER E WITH ACUTE
    reset(state, nil)
    push('\xC3\x81\xC3\xA9', vt)
    expect('putglyph c1 1 0,0\nputglyph e9 1 0,1')

    -- UTF-8 split writes
    reset(state, nil)
    push('\xC3', vt)
    push('\x81', vt)
    expect('putglyph c1 1 0,0')

    -- UTF-8 wide char
    -- U+FF10 = EF BC 90  name: FULLWIDTH DIGIT ZERO
    reset(state, nil)
    push('\xEF\xBC\x90 ', vt)
    expect('putglyph ff10 2 0,0\nputglyph 20 1 0,2')

    -- UTF-8 emoji wide char
    -- U+1F600 = F0 9F 98 80  name: GRINNING FACE
    reset(state, nil)
    push('\xF0\x9F\x98\x80 ', vt)
    expect('putglyph 1f600 2 0,0\nputglyph 20 1 0,2')

    -- UTF-8 combining chars
    -- U+0301 = CC 81  name: COMBINING ACUTE
    reset(state, nil)
    push('e\xCC\x81Z', vt)
    expect('putglyph 65,301 1 0,0\nputglyph 5a 1 0,1')

    -- Combining across buffers
    reset(state, nil)
    push('e', vt)
    expect('putglyph 65 1 0,0')
    push('\xCC\x81Z', vt)
    expect('putglyph 65,301 1 0,0\nputglyph 5a 1 0,1')

    -- Spare combining chars get truncated
    reset(state, nil)
    push('e' .. string.rep('\xCC\x81', 20), vt)
    expect('putglyph 65,301,301,301,301,301,301,301,301,301,301,301,301,301,301 1 0,0') -- and nothing more

    reset(state, nil)
    push('e', vt)
    expect('putglyph 65 1 0,0')
    push('\xCC\x81', vt)
    expect('putglyph 65,301 1 0,0')
    push('\xCC\x82', vt)
    expect('putglyph 65,301,302 1 0,0')

    -- emoji with ZWJ and variant selectors, as one chunk
    reset(state, nil)
    push('🏳️‍🌈🏳️‍⚧️🏴‍☠️', vt)
    expect([[putglyph 1f3f3,fe0f,200d,1f308 2 0,0
putglyph 1f3f3,fe0f,200d,26a7,fe0f 2 0,2
putglyph 1f3f4,200d,2620,fe0f 2 0,4]])

    -- emoji, one code point at a time
    reset(state, nil)
    push('🏳', vt)
    expect('putglyph 1f3f3 2 0,0')
    push('\xef\xb8\x8f', vt)
    expect('putglyph 1f3f3,fe0f 2 0,0')
    push('\xe2\x80\x8d', vt)
    expect('putglyph 1f3f3,fe0f,200d 2 0,0')
    push('🌈', vt)
    expect('putglyph 1f3f3,fe0f,200d,1f308 2 0,0')

    -- modifier can change width
    push('❤', vt)
    expect('putglyph 2764 1 0,2')
    push('\xef\xb8\x8f', vt)
    expect('putglyph 2764,fe0f 2 0,2')

    -- also works batched
    push('❤️', vt)
    expect('putglyph 2764,fe0f 2 0,4')

    -- DECSCA protected
    reset(state, nil)
    push('A\x1b[1"qB\x1b[2"qC', vt)
    expect('putglyph 41 1 0,0\nputglyph 42 1 0,1 prot\nputglyph 43 1 0,2')
  end)

  itp('11state_movecursor', function()
    local vt = init()
    local state = wantstate(vt)

    -- Implicit
    push('ABC', vt)
    cursor(0, 3, state)

    -- Backspace
    push('\b', vt)
    cursor(0, 2, state)
    -- Horizontal Tab
    push('\t', vt)
    cursor(0, 8, state)
    -- Carriage Return
    push('\r', vt)
    cursor(0, 0, state)
    -- Linefeed
    push('\n', vt)
    cursor(1, 0, state)

    -- Backspace bounded by lefthand edge
    push('\x1b[4;2H', vt)
    cursor(3, 1, state)
    push('\b', vt)
    cursor(3, 0, state)
    push('\b', vt)
    cursor(3, 0, state)

    -- Backspace cancels phantom
    push('\x1b[4;80H', vt)
    cursor(3, 79, state)
    push('X', vt)
    cursor(3, 79, state)
    push('\b', vt)
    cursor(3, 78, state)

    -- HT bounded by righthand edge
    push('\x1b[1;78H', vt)
    cursor(0, 77, state)
    push('\t', vt)
    cursor(0, 79, state)
    push('\t', vt)
    cursor(0, 79, state)

    reset(state, nil)

    -- Index
    push('ABC\x1bD', vt)
    cursor(1, 3, state)
    -- Reverse Index
    push('\x1bM', vt)
    cursor(0, 3, state)
    -- Newline
    push('\x1bE', vt)
    cursor(1, 0, state)

    reset(state, nil)

    -- Cursor Forward
    push('\x1b[B', vt)
    cursor(1, 0, state)
    push('\x1b[3B', vt)
    cursor(4, 0, state)
    push('\x1b[0B', vt)
    cursor(5, 0, state)

    -- Cursor Down
    push('\x1b[C', vt)
    cursor(5, 1, state)
    push('\x1b[3C', vt)
    cursor(5, 4, state)
    push('\x1b[0C', vt)
    cursor(5, 5, state)

    -- Cursor Up
    push('\x1b[A', vt)
    cursor(4, 5, state)
    push('\x1b[3A', vt)
    cursor(1, 5, state)
    push('\x1b[0A', vt)
    cursor(0, 5, state)

    -- Cursor Backward
    push('\x1b[D', vt)
    cursor(0, 4, state)
    push('\x1b[3D', vt)
    cursor(0, 1, state)
    push('\x1b[0D', vt)
    cursor(0, 0, state)

    -- Cursor Next Line
    push('   ', vt)
    cursor(0, 3, state)
    push('\x1b[E', vt)
    cursor(1, 0, state)
    push('   ', vt)
    cursor(1, 3, state)
    push('\x1b[2E', vt)
    cursor(3, 0, state)
    push('\x1b[0E', vt)
    cursor(4, 0, state)

    -- Cursor Previous Line
    push('   ', vt)
    cursor(4, 3, state)
    push('\x1b[F', vt)
    cursor(3, 0, state)
    push('   ', vt)
    cursor(3, 3, state)
    push('\x1b[2F', vt)
    cursor(1, 0, state)
    push('\x1b[0F', vt)
    cursor(0, 0, state)

    -- Cursor Horizontal Absolute
    push('\n', vt)
    cursor(1, 0, state)
    push('\x1b[20G', vt)
    cursor(1, 19, state)
    push('\x1b[G', vt)
    cursor(1, 0, state)

    -- Cursor Position
    push('\x1b[10;5H', vt)
    cursor(9, 4, state)
    push('\x1b[8H', vt)
    cursor(7, 0, state)
    push('\x1b[H', vt)
    cursor(0, 0, state)

    -- Cursor Position cancels phantom
    push('\x1b[10;78H', vt)
    cursor(9, 77, state)
    push('ABC', vt)
    cursor(9, 79, state)
    push('\x1b[10;80H', vt)
    push('C', vt)
    cursor(9, 79, state)
    push('X', vt)
    cursor(10, 1, state)

    reset(state, nil)

    -- Bounds Checking
    push('\x1b[A', vt)
    cursor(0, 0, state)
    push('\x1b[D', vt)
    cursor(0, 0, state)
    push('\x1b[25;80H', vt)
    cursor(24, 79, state)
    push('\x1b[B', vt)
    cursor(24, 79, state)
    push('\x1b[C', vt)
    cursor(24, 79, state)
    push('\x1b[E', vt)
    cursor(24, 0, state)
    push('\x1b[H', vt)
    cursor(0, 0, state)
    push('\x1b[F', vt)
    cursor(0, 0, state)
    push('\x1b[999G', vt)
    cursor(0, 79, state)
    push('\x1b[99;99H', vt)
    cursor(24, 79, state)

    reset(state, nil)

    -- Horizontal Position Absolute
    push('\x1b[5`', vt)
    cursor(0, 4, state)

    -- Horizontal Position Relative
    push('\x1b[3a', vt)
    cursor(0, 7, state)

    -- Horizontal Position Backward
    push('\x1b[3j', vt)
    cursor(0, 4, state)

    -- Horizontal and Vertical Position
    push('\x1b[3;3f', vt)
    cursor(2, 2, state)

    -- Vertical Position Absolute
    push('\x1b[5d', vt)
    cursor(4, 2, state)

    -- Vertical Position Relative
    push('\x1b[2e', vt)
    cursor(6, 2, state)

    -- Vertical Position Backward
    push('\x1b[2k', vt)
    cursor(4, 2, state)

    reset(state, nil)

    -- Horizontal Tab
    push('\t', vt)
    cursor(0, 8, state)
    push('   ', vt)
    cursor(0, 11, state)
    push('\t', vt)
    cursor(0, 16, state)
    push('       ', vt)
    cursor(0, 23, state)
    push('\t', vt)
    cursor(0, 24, state)
    push('        ', vt)
    cursor(0, 32, state)
    push('\t', vt)
    cursor(0, 40, state)

    -- Cursor Horizontal Tab
    push('\x1b[I', vt)
    cursor(0, 48, state)
    push('\x1b[2I', vt)
    cursor(0, 64, state)

    -- Cursor Backward Tab
    push('\x1b[Z', vt)
    cursor(0, 56, state)
    push('\x1b[2Z', vt)
    cursor(0, 40, state)
  end)

  itp('12state_scroll', function()
    local vt = init()
    local state = wantstate(vt, { s = true })

    -- Linefeed
    push(string.rep('\n', 24), vt)
    cursor(24, 0, state)
    push('\n', vt)
    expect('scrollrect 0..25,0..80 => +1,+0')
    cursor(24, 0, state)

    reset(state, nil)

    -- Index
    push('\x1b[25H', vt)
    push('\x1bD', vt)
    expect('scrollrect 0..25,0..80 => +1,+0')

    reset(state, nil)

    -- Reverse Index
    push('\x1bM', vt)
    expect('scrollrect 0..25,0..80 => -1,+0')

    reset(state, nil)

    -- Linefeed in DECSTBM
    push('\x1b[1;10r', vt)
    cursor(0, 0, state)
    push(string.rep('\n', 9), vt)
    cursor(9, 0, state)
    push('\n', vt)
    expect('scrollrect 0..10,0..80 => +1,+0')
    cursor(9, 0, state)

    -- Linefeed outside DECSTBM
    push('\x1b[20H', vt)
    cursor(19, 0, state)
    push('\n', vt)
    cursor(20, 0, state)

    -- Index in DECSTBM
    push('\x1b[9;10r', vt)
    push('\x1b[10H', vt)
    push('\x1bM', vt)
    cursor(8, 0, state)
    push('\x1bM', vt)
    expect('scrollrect 8..10,0..80 => -1,+0')

    -- Reverse Index in DECSTBM
    push('\x1b[25H', vt)
    cursor(24, 0, state)
    push('\n', vt)
    -- no scrollrect
    cursor(24, 0, state)

    -- Linefeed in DECSTBM+DECSLRM
    push('\x1b[?69h', vt)
    push('\x1b[3;10r\x1b[10;40s', vt)
    push('\x1b[10;10H\n', vt)
    expect('scrollrect 2..10,9..40 => +1,+0')

    -- IND/RI in DECSTBM+DECSLRM
    push('\x1bD', vt)
    expect('scrollrect 2..10,9..40 => +1,+0')
    push('\x1b[3;10H\x1bM', vt)
    expect('scrollrect 2..10,9..40 => -1,+0')

    -- DECRQSS on DECSTBM
    push('\x1bP$qr\x1b\\', vt)
    expect_output('\x1bP1$r3;10r\x1b\\')

    -- DECRQSS on DECSLRM
    push('\x1bP$qs\x1b\\', vt)
    expect_output('\x1bP1$r10;40s\x1b\\')

    -- Setting invalid DECSLRM with !DECVSSM is still rejected
    push('\x1b[?69l\x1b[;0s\x1b[?69h', vt)

    reset(state, nil)

    -- Scroll Down
    push('\x1b[S', vt)
    expect('scrollrect 0..25,0..80 => +1,+0')
    cursor(0, 0, state)
    push('\x1b[2S', vt)
    expect('scrollrect 0..25,0..80 => +2,+0')
    cursor(0, 0, state)
    push('\x1b[100S', vt)
    expect('scrollrect 0..25,0..80 => +25,+0')

    -- Scroll Up
    push('\x1b[T', vt)
    expect('scrollrect 0..25,0..80 => -1,+0')
    cursor(0, 0, state)
    push('\x1b[2T', vt)
    expect('scrollrect 0..25,0..80 => -2,+0')
    cursor(0, 0, state)
    push('\x1b[100T', vt)
    expect('scrollrect 0..25,0..80 => -25,+0')

    -- SD/SU in DECSTBM
    push('\x1b[5;20r', vt)
    push('\x1b[S', vt)
    expect('scrollrect 4..20,0..80 => +1,+0')
    push('\x1b[T', vt)
    expect('scrollrect 4..20,0..80 => -1,+0')

    reset(state, nil)

    -- SD/SU in DECSTBM+DECSLRM
    push('\x1b[?69h', vt)
    push('\x1b[3;10r\x1b[10;40s', vt)
    cursor(0, 0, state)
    push('\x1b[3;10H', vt)
    cursor(2, 9, state)
    push('\x1b[S', vt)
    expect('scrollrect 2..10,9..40 => +1,+0')
    push('\x1b[?69l', vt)
    push('\x1b[S', vt)
    expect('scrollrect 2..10,0..80 => +1,+0')

    -- Invalid boundaries
    reset(state, nil)

    push('\x1b[100;105r\x1bD', vt)
    push('\x1b[5;2r\x1bD', vt)

    reset(state, nil)
    state = wantstate(vt, { m = true, e = true })

    -- Scroll Down move+erase emulation
    push('\x1b[S', vt)
    expect('moverect 1..25,0..80 -> 0..24,0..80\nerase 24..25,0..80')
    cursor(0, 0, state)
    push('\x1b[2S', vt)
    expect('moverect 2..25,0..80 -> 0..23,0..80\nerase 23..25,0..80')
    cursor(0, 0, state)

    -- Scroll Up move+erase emulation
    push('\x1b[T', vt)
    expect('moverect 0..24,0..80 -> 1..25,0..80\nerase 0..1,0..80')
    cursor(0, 0, state)
    push('\x1b[2T', vt)
    expect('moverect 0..23,0..80 -> 2..25,0..80\nerase 0..2,0..80')
    cursor(0, 0, state)

    -- DECSTBM resets cursor position
    push('\x1b[5;5H', vt)
    cursor(4, 4, state)
    push('\x1b[r', vt)
    cursor(0, 0, state)
  end)

  itp('13state_edit', function()
    local vt = init()
    local state = wantstate(vt, { s = true, e = true, b = true })

    -- ICH
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('ACD', vt)
    push('\x1b[2D', vt)
    cursor(0, 1, state)
    push('\x1b[@', vt)
    expect('scrollrect 0..1,1..80 => +0,-1')
    cursor(0, 1, state)
    push('B', vt)
    cursor(0, 2, state)
    push('\x1b[3@', vt)
    expect('scrollrect 0..1,2..80 => +0,-3')

    -- ICH with DECSLRM
    push('\x1b[?69h', vt)
    push('\x1b[;50s', vt)
    push('\x1b[20G\x1b[@', vt)
    expect('scrollrect 0..1,19..50 => +0,-1')

    -- ICH outside DECSLRM
    push('\x1b[70G\x1b[@', vt)
    -- nothing happens

    -- DCH
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('ABBC', vt)
    push('\x1b[3D', vt)
    cursor(0, 1, state)
    push('\x1b[P', vt)
    expect('scrollrect 0..1,1..80 => +0,+1')
    cursor(0, 1, state)
    push('\x1b[3P', vt)
    expect('scrollrect 0..1,1..80 => +0,+3')
    cursor(0, 1, state)

    -- DCH with DECSLRM
    push('\x1b[?69h', vt)
    push('\x1b[;50s', vt)
    push('\x1b[20G\x1b[P', vt)
    expect('scrollrect 0..1,19..50 => +0,+1')

    -- DCH outside DECSLRM
    push('\x1b[70G\x1b[P', vt)
    -- nothing happens

    -- ECH
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('ABC', vt)
    push('\x1b[2D', vt)
    cursor(0, 1, state)
    push('\x1b[X', vt)
    expect('erase 0..1,1..2')
    cursor(0, 1, state)
    push('\x1b[3X', vt)
    expect('erase 0..1,1..4')
    cursor(0, 1, state)
    -- ECH more columns than there are should be bounded
    push('\x1b[100X', vt)
    expect('erase 0..1,1..80')

    -- IL
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('A\r\nC', vt)
    cursor(1, 1, state)
    push('\x1b[L', vt)
    expect('scrollrect 1..25,0..80 => -1,+0')
    -- TODO(libvterm): ECMA-48 says we should move to line home, but neither xterm nor xfce4-terminal do this
    cursor(1, 1, state)
    push('\rB', vt)
    cursor(1, 1, state)
    push('\x1b[3L', vt)
    expect('scrollrect 1..25,0..80 => -3,+0')

    -- IL with DECSTBM
    push('\x1b[5;15r', vt)
    push('\x1b[5H\x1b[L', vt)
    expect('scrollrect 4..15,0..80 => -1,+0')

    -- IL outside DECSTBM
    push('\x1b[20H\x1b[L', vt)
    -- nothing happens

    -- IL with DECSTBM+DECSLRM
    push('\x1b[?69h', vt)
    push('\x1b[10;50s', vt)
    push('\x1b[5;10H\x1b[L', vt)
    expect('scrollrect 4..15,9..50 => -1,+0')

    -- DL
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('A\r\nB\r\nB\r\nC', vt)
    cursor(3, 1, state)
    push('\x1b[2H', vt)
    cursor(1, 0, state)
    push('\x1b[M', vt)
    expect('scrollrect 1..25,0..80 => +1,+0')
    cursor(1, 0, state)
    push('\x1b[3M', vt)
    expect('scrollrect 1..25,0..80 => +3,+0')
    cursor(1, 0, state)

    -- DL with DECSTBM
    push('\x1b[5;15r', vt)
    push('\x1b[5H\x1b[M', vt)
    expect('scrollrect 4..15,0..80 => +1,+0')

    -- DL outside DECSTBM
    push('\x1b[20H\x1b[M', vt)
    -- nothing happens

    -- DL with DECSTBM+DECSLRM
    push('\x1b[?69h', vt)
    push('\x1b[10;50s', vt)
    push('\x1b[5;10H\x1b[M', vt)
    expect('scrollrect 4..15,9..50 => +1,+0')

    -- DECIC
    reset(state, nil)
    expect('erase 0..25,0..80')
    push("\x1b[20G\x1b[5'}", vt)
    expect('scrollrect 0..25,19..80 => +0,-5')

    -- DECIC with DECSTBM+DECSLRM
    push('\x1b[?69h', vt)
    push('\x1b[4;20r\x1b[20;60s', vt)
    push("\x1b[4;20H\x1b[3'}", vt)
    expect('scrollrect 3..20,19..60 => +0,-3')

    -- DECIC outside DECSLRM
    push("\x1b[70G\x1b['}", vt)
    -- nothing happens

    -- DECDC
    reset(state, nil)
    expect('erase 0..25,0..80')
    push("\x1b[20G\x1b[5'~", vt)
    expect('scrollrect 0..25,19..80 => +0,+5')

    -- DECDC with DECSTBM+DECSLRM
    push('\x1b[?69h', vt)
    push('\x1b[4;20r\x1b[20;60s', vt)
    push("\x1b[4;20H\x1b[3'~", vt)
    expect('scrollrect 3..20,19..60 => +0,+3')

    -- DECDC outside DECSLRM
    push("\x1b[70G\x1b['~", vt)
    -- nothing happens

    -- EL 0
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('ABCDE', vt)
    push('\x1b[3D', vt)
    cursor(0, 2, state)
    push('\x1b[0K', vt)
    expect('erase 0..1,2..80')
    cursor(0, 2, state)

    -- EL 1
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('ABCDE', vt)
    push('\x1b[3D', vt)
    cursor(0, 2, state)
    push('\x1b[1K', vt)
    expect('erase 0..1,0..3')
    cursor(0, 2, state)

    -- EL 2
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('ABCDE', vt)
    push('\x1b[3D', vt)
    cursor(0, 2, state)
    push('\x1b[2K', vt)
    expect('erase 0..1,0..80')
    cursor(0, 2, state)

    -- SEL
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('\x1b[11G', vt)
    cursor(0, 10, state)
    push('\x1b[?0K', vt)
    expect('erase 0..1,10..80 selective')
    cursor(0, 10, state)
    push('\x1b[?1K', vt)
    expect('erase 0..1,0..11 selective')
    cursor(0, 10, state)
    push('\x1b[?2K', vt)
    expect('erase 0..1,0..80 selective')
    cursor(0, 10, state)

    -- ED 0
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('\x1b[2;2H', vt)
    cursor(1, 1, state)
    push('\x1b[0J', vt)
    expect('erase 1..2,1..80\nerase 2..25,0..80')
    cursor(1, 1, state)

    -- ED 1
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('\x1b[2;2H', vt)
    cursor(1, 1, state)
    push('\x1b[1J', vt)
    expect('erase 0..1,0..80\nerase 1..2,0..2')
    cursor(1, 1, state)

    -- ED 2
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('\x1b[2;2H', vt)
    cursor(1, 1, state)
    push('\x1b[2J', vt)
    expect('erase 0..25,0..80')
    cursor(1, 1, state)

    -- ED 3
    push('\x1b[3J', vt)
    expect('sb_clear')

    -- SED
    reset(state, nil)
    expect('erase 0..25,0..80')
    push('\x1b[5;5H', vt)
    cursor(4, 4, state)
    push('\x1b[?0J', vt)
    expect('erase 4..5,4..80 selective\nerase 5..25,0..80 selective')
    cursor(4, 4, state)
    push('\x1b[?1J', vt)
    expect('erase 0..4,0..80 selective\nerase 4..5,0..5 selective')
    cursor(4, 4, state)
    push('\x1b[?2J', vt)
    expect('erase 0..25,0..80 selective')
    cursor(4, 4, state)

    -- DECRQSS on DECSCA
    push('\x1b[2"q', vt)
    push('\x1bP$q"q\x1b\\', vt)
    expect_output('\x1bP1$r2"q\x1b\\')

    state = wantstate(vt, { m = true, e = true, b = true })
    expect('erase 0..25,0..80') -- TODO(dundargoc): strange, this should not be needed according to the original code

    -- ICH move+erase emuation
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('ACD', vt)
    push('\x1b[2D', vt)
    cursor(0, 1, state)
    push('\x1b[@', vt)
    expect('moverect 0..1,1..79 -> 0..1,2..80\nerase 0..1,1..2')
    cursor(0, 1, state)
    push('B', vt)
    cursor(0, 2, state)
    push('\x1b[3@', vt)
    expect('moverect 0..1,2..77 -> 0..1,5..80\nerase 0..1,2..5')

    -- DCH move+erase emulation
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('ABBC', vt)
    push('\x1b[3D', vt)
    cursor(0, 1, state)
    push('\x1b[P', vt)
    expect('moverect 0..1,2..80 -> 0..1,1..79\nerase 0..1,79..80')
    cursor(0, 1, state)
    push('\x1b[3P', vt)
    expect('moverect 0..1,4..80 -> 0..1,1..77\nerase 0..1,77..80')
    cursor(0, 1, state)
  end)

  itp('14state_encoding', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, false)
    local state = wantstate(vt, { g = true })

    -- Default
    reset(state, nil)
    push('#', vt)
    expect('putglyph 23 1 0,0')

    -- Designate G0=DEC drawing
    reset(state, nil)
    push('\x1b(0', vt)
    push('a', vt)
    expect('putglyph 2592 1 0,0')

    -- Designate G1 + LS1
    reset(state, nil)
    push('\x1b)0', vt)
    push('a', vt)
    expect('putglyph 61 1 0,0')
    push('\x0e', vt)
    push('a', vt)
    expect('putglyph 2592 1 0,1')
    -- LS0
    push('\x0f', vt)
    push('a', vt)
    expect('putglyph 61 1 0,2')

    -- Designate G2 + LS2
    push('\x1b*0', vt)
    push('a', vt)
    expect('putglyph 61 1 0,3')
    push('\x1bn', vt)
    push('a', vt)
    expect('putglyph 2592 1 0,4')
    push('\x0f', vt)
    push('a', vt)
    expect('putglyph 61 1 0,5')

    -- Designate G3 + LS3
    push('\x1b+0', vt)
    push('a', vt)
    expect('putglyph 61 1 0,6')
    push('\x1bo', vt)
    push('a', vt)
    expect('putglyph 2592 1 0,7')
    push('\x0f', vt)
    push('a', vt)
    expect('putglyph 61 1 0,8')

    -- SS2
    push('a\x8eaa', vt)
    expect('putglyph 61 1 0,9\nputglyph 2592 1 0,10\nputglyph 61 1 0,11')

    -- SS3
    push('a\x8faa', vt)
    expect('putglyph 61 1 0,12\nputglyph 2592 1 0,13\nputglyph 61 1 0,14')

    -- LS1R
    reset(state, nil)
    push('\x1b~', vt)
    push('\xe1', vt)
    expect('putglyph 61 1 0,0')
    push('\x1b)0', vt)
    push('\xe1', vt)
    expect('putglyph 2592 1 0,1')

    -- LS2R
    reset(state, nil)
    push('\x1b}', vt)
    push('\xe1', vt)
    expect('putglyph 61 1 0,0')
    push('\x1b*0', vt)
    push('\xe1', vt)
    expect('putglyph 2592 1 0,1')

    -- LS3R
    reset(state, nil)
    push('\x1b|', vt)
    push('\xe1', vt)
    expect('putglyph 61 1 0,0')
    push('\x1b+0', vt)
    push('\xe1', vt)
    expect('putglyph 2592 1 0,1')

    vterm.vterm_set_utf8(vt, true)
    -- U+0108 == c4 88
    reset(state, nil)
    push('\x1b(B', vt)
    push('AB\xc4\x88D', vt)
    expect('putglyph 41 1 0,0\nputglyph 42 1 0,1\nputglyph 108 1 0,2\nputglyph 44 1 0,3')
  end)

  itp('15state_mode', function()
    local vt = init()
    local state = wantstate(vt, { g = true, m = true, e = true })

    -- Insert/Replace Mode
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('AC\x1b[DB', vt)
    expect('putglyph 41 1 0,0\nputglyph 43 1 0,1\nputglyph 42 1 0,1')
    push('\x1b[4h', vt)
    push('\x1b[G', vt)
    push('AC\x1b[DB', vt)
    expect(
      'moverect 0..1,0..79 -> 0..1,1..80\nerase 0..1,0..1\nputglyph 41 1 0,0\nmoverect 0..1,1..79 -> 0..1,2..80\nerase 0..1,1..2\nputglyph 43 1 0,1\nmoverect 0..1,1..79 -> 0..1,2..80\nerase 0..1,1..2\nputglyph 42 1 0,1'
    )

    -- Insert mode only happens once for UTF-8 combining
    push('e', vt)
    expect('moverect 0..1,2..79 -> 0..1,3..80\nerase 0..1,2..3\nputglyph 65 1 0,2')
    push('\xCC\x81', vt)
    expect('putglyph 65,301 1 0,2')

    -- Newline/Linefeed mode
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('\x1b[5G\n', vt)
    cursor(1, 4, state)
    push('\x1b[20h', vt)
    push('\x1b[5G\n', vt)
    cursor(2, 0, state)

    -- DEC origin mode
    reset(state, nil)
    expect('erase 0..25,0..80')
    cursor(0, 0, state)
    push('\x1b[5;15r', vt)
    push('\x1b[H', vt)
    cursor(0, 0, state)
    push('\x1b[3;3H', vt)
    cursor(2, 2, state)
    push('\x1b[?6h', vt)
    push('\x1b[H', vt)
    cursor(4, 0, state)
    push('\x1b[3;3H', vt)
    cursor(6, 2, state)

    -- DECRQM on DECOM
    push('\x1b[?6h', vt)
    push('\x1b[?6$p', vt)
    expect_output('\x1b[?6;1$y')
    push('\x1b[?6l', vt)
    push('\x1b[?6$p', vt)
    expect_output('\x1b[?6;2$y')

    -- Origin mode with DECSLRM
    push('\x1b[?6h', vt)
    push('\x1b[?69h', vt)
    push('\x1b[20;60s', vt)
    push('\x1b[H', vt)
    cursor(4, 19, state)

    push('\x1b[?69l', vt)

    -- Origin mode bounds cursor to scrolling region
    push('\x1b[H', vt)
    push('\x1b[10A', vt)
    cursor(4, 0, state)
    push('\x1b[20B', vt)
    cursor(14, 0, state)

    -- Origin mode without scroll region
    push('\x1b[?6l', vt)
    push('\x1b[r\x1b[?6h', vt)
    cursor(0, 0, state)
  end)

  itp('16state_resize', function()
    local vt = init()
    local state = wantstate(vt, { g = true })

    -- Placement
    reset(state, nil)
    push('AB\x1b[79GCDE', vt)
    expect(
      'putglyph 41 1 0,0\nputglyph 42 1 0,1\nputglyph 43 1 0,78\nputglyph 44 1 0,79\nputglyph 45 1 1,0'
    )

    -- Resize
    reset(state, nil)
    resize(27, 85, vt)
    push('AB\x1b[79GCDE', vt)
    expect(
      'putglyph 41 1 0,0\nputglyph 42 1 0,1\nputglyph 43 1 0,78\nputglyph 44 1 0,79\nputglyph 45 1 0,80'
    )
    cursor(0, 81, state)

    -- Resize without reset
    resize(28, 90, vt)
    cursor(0, 81, state)
    push('FGHI', vt)
    expect('putglyph 46 1 0,81\nputglyph 47 1 0,82\nputglyph 48 1 0,83\nputglyph 49 1 0,84')
    cursor(0, 85, state)

    -- Resize shrink moves cursor
    resize(25, 80, vt)
    cursor(0, 79, state)

    -- Resize grow doesn't cancel phantom
    reset(state, nil)
    push('\x1b[79GAB', vt)
    expect('putglyph 41 1 0,78\nputglyph 42 1 0,79')
    cursor(0, 79, state)
    resize(30, 100, vt)
    cursor(0, 80, state)
    push('C', vt)
    expect('putglyph 43 1 0,80')
    cursor(0, 81, state)
  end)

  itp('17state_mouse', function()
    local vt = init()
    local state = wantstate(vt, { p = true })

    -- DECRQM on with mouse off
    push('\x1b[?1000$p', vt)
    expect_output('\x1b[?1000;2$y')
    push('\x1b[?1002$p', vt)
    expect_output('\x1b[?1002;2$y')
    push('\x1b[?1003$p', vt)
    expect_output('\x1b[?1003;2$y')

    -- Mouse in simple button report mode
    reset(state, nil)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')
    push('\x1b[?1000h', vt)
    expect('settermprop 8 1')

    -- Press 1
    mousemove(0, 0, vt)
    mousebtn('d', 1, vt)
    expect_output('\x1b[M\x20\x21\x21')

    -- Release 1
    mousebtn('u', 1, vt)
    expect_output('\x1b[M\x23\x21\x21')

    -- Ctrl-Press 1
    mousebtn('d', 1, vt, { C = true })
    expect_output('\x1b[M\x30\x21\x21')
    mousebtn('u', 1, vt, { C = true })
    expect_output('\x1b[M\x33\x21\x21')

    -- Button 2
    mousebtn('d', 2, vt)
    expect_output('\x1b[M\x21\x21\x21')
    mousebtn('u', 2, vt)
    expect_output('\x1b[M\x23\x21\x21')

    -- Position
    mousemove(10, 20, vt)
    mousebtn('d', 1, vt)
    expect_output('\x1b[M\x20\x35\x2b')

    mousebtn('u', 1, vt)
    expect_output('\x1b[M\x23\x35\x2b')
    mousemove(10, 21, vt)
    -- no output

    -- Wheel events
    mousebtn('d', 4, vt)
    expect_output('\x1b[M\x60\x36\x2b')
    mousebtn('d', 4, vt)
    expect_output('\x1b[M\x60\x36\x2b')
    mousebtn('d', 5, vt)
    expect_output('\x1b[M\x61\x36\x2b')
    mousebtn('d', 6, vt)
    expect_output('\x1b[M\x62\x36\x2b')
    mousebtn('d', 7, vt)
    expect_output('\x1b[M\x63\x36\x2b')

    -- DECRQM on mouse button mode
    push('\x1b[?1000$p', vt)
    expect_output('\x1b[?1000;1$y')
    push('\x1b[?1002$p', vt)
    expect_output('\x1b[?1002;2$y')
    push('\x1b[?1003$p', vt)
    expect_output('\x1b[?1003;2$y')

    -- Drag events
    reset(state, nil)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')
    push('\x1b[?1002h', vt)
    expect('settermprop 8 2')

    mousemove(5, 5, vt)
    mousebtn('d', 1, vt)
    expect_output('\x1b[M\x20\x26\x26')
    mousemove(5, 6, vt)
    expect_output('\x1b[M\x40\x27\x26')
    mousemove(6, 6, vt)
    expect_output('\x1b[M\x40\x27\x27')
    mousemove(6, 6, vt)
    -- no output
    mousebtn('u', 1, vt)
    expect_output('\x1b[M\x23\x27\x27')
    mousemove(6, 7, vt)
    -- no output

    -- DECRQM on mouse drag mode
    push('\x1b[?1000$p', vt)
    expect_output('\x1b[?1000;2$y')
    push('\x1b[?1002$p', vt)
    expect_output('\x1b[?1002;1$y')
    push('\x1b[?1003$p', vt)
    expect_output('\x1b[?1003;2$y')

    -- Non-drag motion events
    push('\x1b[?1003h', vt)
    expect('settermprop 8 3')

    mousemove(6, 8, vt)
    expect_output('\x1b[M\x43\x29\x27')

    -- DECRQM on mouse motion mode
    push('\x1b[?1000$p', vt)
    expect_output('\x1b[?1000;2$y')
    push('\x1b[?1002$p', vt)
    expect_output('\x1b[?1002;2$y')
    push('\x1b[?1003$p', vt)
    expect_output('\x1b[?1003;1$y')

    -- Bounds checking
    mousemove(300, 300, vt)
    expect_output('\x1b[M\x43\xff\xff')
    mousebtn('d', 1, vt)
    expect_output('\x1b[M\x20\xff\xff')
    mousebtn('u', 1, vt)
    expect_output('\x1b[M\x23\xff\xff')

    -- DECRQM on standard encoding mode
    push('\x1b[?1005$p', vt)
    expect_output('\x1b[?1005;2$y')
    push('\x1b[?1006$p', vt)
    expect_output('\x1b[?1006;2$y')
    push('\x1b[?1015$p', vt)
    expect_output('\x1b[?1015;2$y')

    -- UTF-8 extended encoding mode
    -- 300 + 32 + 1 = 333 = U+014d = \xc5\x8d
    push('\x1b[?1005h', vt)
    mousebtn('d', 1, vt)
    expect_output('\x1b[M\x20\xc5\x8d\xc5\x8d')
    mousebtn('u', 1, vt)
    expect_output('\x1b[M\x23\xc5\x8d\xc5\x8d')

    -- DECRQM on UTF-8 extended encoding mode
    push('\x1b[?1005$p', vt)
    expect_output('\x1b[?1005;1$y')
    push('\x1b[?1006$p', vt)
    expect_output('\x1b[?1006;2$y')
    push('\x1b[?1015$p', vt)
    expect_output('\x1b[?1015;2$y')

    -- SGR extended encoding mode
    push('\x1b[?1006h', vt)
    mousebtn('d', 1, vt)
    expect_output('\x1b[<0;301;301M')
    mousebtn('u', 1, vt)
    expect_output('\x1b[<0;301;301m')

    -- Button 8 on SGR extended encoding mode
    mousebtn('d', 8, vt)
    expect_output('\x1b[<128;301;301M')
    mousebtn('u', 8, vt)
    expect_output('\x1b[<128;301;301m')

    -- Button 9 on SGR extended encoding mode
    mousebtn('d', 9, vt)
    expect_output('\x1b[<129;301;301M')
    mousebtn('u', 9, vt)
    expect_output('\x1b[<129;301;301m')

    -- DECRQM on SGR extended encoding mode
    push('\x1b[?1005$p', vt)
    expect_output('\x1b[?1005;2$y')
    push('\x1b[?1006$p', vt)
    expect_output('\x1b[?1006;1$y')
    push('\x1b[?1015$p', vt)
    expect_output('\x1b[?1015;2$y')

    -- rxvt extended encoding mode
    push('\x1b[?1015h', vt)
    mousebtn('d', 1, vt)
    expect_output('\x1b[0;301;301M')
    mousebtn('u', 1, vt)
    expect_output('\x1b[3;301;301M')

    -- Button 8 on rxvt extended encoding mode
    mousebtn('d', 8, vt)
    expect_output('\x1b[128;301;301M')
    mousebtn('u', 8, vt)
    expect_output('\x1b[3;301;301M')

    -- Button 9 on rxvt extended encoding mode
    mousebtn('d', 9, vt)
    expect_output('\x1b[129;301;301M')
    mousebtn('u', 9, vt)
    expect_output('\x1b[3;301;301M')

    -- DECRQM on rxvt extended encoding mode
    push('\x1b[?1005$p', vt)
    expect_output('\x1b[?1005;2$y')
    push('\x1b[?1006$p', vt)
    expect_output('\x1b[?1006;2$y')
    push('\x1b[?1015$p', vt)
    expect_output('\x1b[?1015;1$y')

    -- Mouse disabled reports nothing
    reset(state, nil)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')
    mousemove(0, 0, vt)
    mousebtn('d', 1, vt)
    mousebtn('u', 1, vt)

    -- DECSM can set multiple modes at once
    push('\x1b[?1002;1006h', vt)
    expect('settermprop 8 2')
    mousebtn('d', 1, vt)
    expect_output('\x1b[<0;1;1M')
  end)

  itp('18state_termprops', function()
    local vt = init()
    local state = wantstate(vt, { p = true })

    reset(state, nil)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')

    -- Cursor visibility
    push('\x1b[?25h', vt)
    expect('settermprop 1 true')
    push('\x1b[?25$p', vt)
    expect_output('\x1b[?25;1$y')
    push('\x1b[?25l', vt)
    expect('settermprop 1 false')
    push('\x1b[?25$p', vt)
    expect_output('\x1b[?25;2$y')

    -- Cursor blink
    push('\x1b[?12h', vt)
    expect('settermprop 2 true')
    push('\x1b[?12$p', vt)
    expect_output('\x1b[?12;1$y')
    push('\x1b[?12l', vt)
    expect('settermprop 2 false')
    push('\x1b[?12$p', vt)
    expect_output('\x1b[?12;2$y')

    -- Cursor shape
    push('\x1b[3 q', vt)
    expect('settermprop 2 true\nsettermprop 7 2')

    -- Title
    push('\x1b]2;Here is my title\a', vt)
    expect('settermprop 4 ["Here is my title"]')

    -- Title split write
    push('\x1b]2;Here is', vt)
    expect('settermprop 4 ["Here is"')
    push(' another title\a', vt)
    expect('settermprop 4 " another title"]')
  end)

  itp('20state_wrapping', function()
    local vt = init()
    local state = wantstate(vt, { g = true, m = true })

    -- 79th Column
    push('\x1b[75G', vt)
    push(string.rep('A', 5), vt)
    expect(
      'putglyph 41 1 0,74\nputglyph 41 1 0,75\nputglyph 41 1 0,76\nputglyph 41 1 0,77\nputglyph 41 1 0,78'
    )
    cursor(0, 79, state)

    -- 80th Column Phantom
    push('A', vt)
    expect('putglyph 41 1 0,79')
    cursor(0, 79, state)

    -- Line Wraparound
    push('B', vt)
    expect('putglyph 42 1 1,0')
    cursor(1, 1, state)

    -- Line Wraparound during combined write
    push('\x1b[78G', vt)
    push('BBBCC', vt)
    expect(
      'putglyph 42 1 1,77\nputglyph 42 1 1,78\nputglyph 42 1 1,79\nputglyph 43 1 2,0\nputglyph 43 1 2,1'
    )
    cursor(2, 2, state)

    -- DEC Auto Wrap Mode
    reset(state, nil)
    push('\x1b[?7l', vt)
    push('\x1b[75G', vt)
    push(string.rep('D', 6), vt)
    expect(
      'putglyph 44 1 0,74\nputglyph 44 1 0,75\nputglyph 44 1 0,76\nputglyph 44 1 0,77\nputglyph 44 1 0,78\nputglyph 44 1 0,79'
    )
    cursor(0, 79, state)
    push('D', vt)
    expect('putglyph 44 1 0,79')
    cursor(0, 79, state)
    push('\x1b[?7h', vt)

    -- 80th column causes linefeed on wraparound
    push('\x1b[25;78HABC', vt)
    expect('putglyph 41 1 24,77\nputglyph 42 1 24,78\nputglyph 43 1 24,79')
    cursor(24, 79, state)
    push('D', vt)
    expect('moverect 1..25,0..80 -> 0..24,0..80\nputglyph 44 1 24,0')

    -- 80th column phantom linefeed phantom cancelled by explicit cursor move
    push('\x1b[25;78HABC', vt)
    expect('putglyph 41 1 24,77\nputglyph 42 1 24,78\nputglyph 43 1 24,79')
    cursor(24, 79, state)
    push('\x1b[25;1HD', vt)
    expect('putglyph 44 1 24,0')
  end)

  itp('21state_tabstops', function()
    local vt = init()
    local state = wantstate(vt, { g = true })

    -- Initial
    reset(state, nil)
    push('\tX', vt)
    expect('putglyph 58 1 0,8')
    push('\tX', vt)
    expect('putglyph 58 1 0,16')
    cursor(0, 17, state)

    -- HTS
    push('\x1b[5G\x1bH', vt)
    push('\x1b[G\tX', vt)
    expect('putglyph 58 1 0,4')
    cursor(0, 5, state)

    -- TBC 0
    push('\x1b[9G\x1b[g', vt)
    push('\x1b[G\tX\tX', vt)
    expect('putglyph 58 1 0,4\nputglyph 58 1 0,16')
    cursor(0, 17, state)

    -- TBC 3
    push('\x1b[3g\x1b[50G\x1bH\x1b[G', vt)
    cursor(0, 0, state)
    push('\tX', vt)
    expect('putglyph 58 1 0,49')
    cursor(0, 50, state)

    -- Tabstops after resize
    reset(state, nil)
    resize(30, 100, vt)
    -- Should be 100/8 = 12 tabstops
    push('\tX', vt)
    expect('putglyph 58 1 0,8')
    push('\tX', vt)
    expect('putglyph 58 1 0,16')
    push('\tX', vt)
    expect('putglyph 58 1 0,24')
    push('\tX', vt)
    expect('putglyph 58 1 0,32')
    push('\tX', vt)
    expect('putglyph 58 1 0,40')
    push('\tX', vt)
    expect('putglyph 58 1 0,48')
    push('\tX', vt)
    expect('putglyph 58 1 0,56')
    push('\tX', vt)
    expect('putglyph 58 1 0,64')
    push('\tX', vt)
    expect('putglyph 58 1 0,72')
    push('\tX', vt)
    expect('putglyph 58 1 0,80')
    push('\tX', vt)
    expect('putglyph 58 1 0,88')
    push('\tX', vt)
    expect('putglyph 58 1 0,96')
    cursor(0, 97, state)
  end)

  itp('22state_save', function()
    local vt = init()
    local state = wantstate(vt, { p = true })

    reset(state, nil)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')

    -- Set up state
    push('\x1b[2;2H', vt)
    cursor(1, 1, state)
    push('\x1b[1m', vt)
    pen('bold', true, state)

    -- Save
    push('\x1b[?1048h', vt)

    -- Change state
    push('\x1b[5;5H', vt)
    cursor(4, 4, state)
    push('\x1b[4 q', vt)
    expect('settermprop 2 false\nsettermprop 7 2')
    push('\x1b[22;4m', vt)
    pen('bold', false, state)
    pen('underline', 1, state)

    -- Restore
    push('\x1b[?1048l', vt)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')
    cursor(1, 1, state)
    pen('bold', true, state)
    pen('underline', 0, state)

    -- Save/restore using DECSC/DECRC
    push('\x1b[2;2H\x1b7', vt)
    cursor(1, 1, state)

    push('\x1b[5;5H', vt)
    cursor(4, 4, state)
    push('\x1b8', vt)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')
    cursor(1, 1, state)

    -- Save twice, restore twice happens on both edge transitions
    push('\x1b[2;10H\x1b[?1048h\x1b[6;10H\x1b[?1048h', vt)
    push('\x1b[H', vt)
    cursor(0, 0, state)
    push('\x1b[?1048l', vt)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')
    cursor(5, 9, state)
    push('\x1b[H', vt)
    cursor(0, 0, state)
    push('\x1b[?1048l', vt)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')
    cursor(5, 9, state)
  end)

  itp('25state_input', function()
    local vt = init()
    local state = wantstate(vt)

    -- Disambiguate escape codes enabled
    push('\x1b[>1u', vt)

    -- Unmodified ASCII
    inchar(0x41, vt)
    expect_output('A')
    inchar(0x61, vt)
    expect_output('a')

    -- Ctrl modifier on ASCII letters
    inchar(0x41, vt, { C = true })
    expect_output('\x1b[97;6u')
    inchar(0x61, vt, { C = true })
    expect_output('\x1b[97;5u')

    -- Alt modifier on ASCII letters
    inchar(0x41, vt, { A = true })
    expect_output('\x1b[97;4u')
    inchar(0x61, vt, { A = true })
    expect_output('\x1b[97;3u')

    -- Ctrl-Alt modifier on ASCII letters
    inchar(0x41, vt, { C = true, A = true })
    expect_output('\x1b[97;8u')
    inchar(0x61, vt, { C = true, A = true })
    expect_output('\x1b[97;7u')

    -- Ctrl-I is disambiguated
    inchar(0x49, vt)
    expect_output('I')
    inchar(0x69, vt)
    expect_output('i')
    inchar(0x49, vt, { C = true })
    expect_output('\x1b[105;6u')
    inchar(0x69, vt, { C = true })
    expect_output('\x1b[105;5u')
    inchar(0x49, vt, { A = true })
    expect_output('\x1b[105;4u')
    inchar(0x69, vt, { A = true })
    expect_output('\x1b[105;3u')
    inchar(0x49, vt, { A = true, C = true })
    expect_output('\x1b[105;8u')
    inchar(0x69, vt, { A = true, C = true })
    expect_output('\x1b[105;7u')

    -- Ctrl+Digits
    for i = 0, 9 do
      local c = 0x30 + i
      inchar(c, vt)
      expect_output(tostring(i))
      inchar(c, vt, { C = true })
      expect_output(string.format('\x1b[%d;5u', c))
      inchar(c, vt, { C = true, S = true })
      expect_output(string.format('\x1b[%d;6u', c))
      inchar(c, vt, { C = true, A = true })
      expect_output(string.format('\x1b[%d;7u', c))
      inchar(c, vt, { C = true, A = true, S = true })
      expect_output(string.format('\x1b[%d;8u', c))
    end

    -- Special handling of Space
    inchar(0x20, vt)
    expect_output(' ')
    inchar(0x20, vt, { S = true })
    expect_output('\x1b[32;2u')
    inchar(0x20, vt, { C = true })
    expect_output('\x1b[32;5u')
    inchar(0x20, vt, { C = true, S = true })
    expect_output('\x1b[32;6u')
    inchar(0x20, vt, { A = true })
    expect_output('\x1b[32;3u')
    inchar(0x20, vt, { S = true, A = true })
    expect_output('\x1b[32;4u')
    inchar(0x20, vt, { C = true, A = true })
    expect_output('\x1b[32;7u')
    inchar(0x20, vt, { S = true, C = true, A = true })
    expect_output('\x1b[32;8u')

    -- Cursor keys in reset (cursor) mode
    inkey('up', vt)
    expect_output('\x1b[A')
    inkey('up', vt, { S = true })
    expect_output('\x1b[1;2A')
    inkey('up', vt, { C = true })
    expect_output('\x1b[1;5A')
    inkey('up', vt, { S = true, C = true })
    expect_output('\x1b[1;6A')
    inkey('up', vt, { A = true })
    expect_output('\x1b[1;3A')
    inkey('up', vt, { S = true, A = true })
    expect_output('\x1b[1;4A')
    inkey('up', vt, { C = true, A = true })
    expect_output('\x1b[1;7A')
    inkey('up', vt, { S = true, C = true, A = true })
    expect_output('\x1b[1;8A')

    -- Cursor keys in application mode
    push('\x1b[?1h', vt)
    -- Plain "Up" should be SS3 A now
    inkey('up', vt)
    expect_output('\x1bOA')
    -- Modified keys should still use CSI
    inkey('up', vt, { S = true })
    expect_output('\x1b[1;2A')
    inkey('up', vt, { C = true })
    expect_output('\x1b[1;5A')

    -- Tab
    inkey('tab', vt)
    expect_output('\x09')
    inkey('tab', vt, { S = true })
    expect_output('\x1b[9;2u')
    inkey('tab', vt, { C = true })
    expect_output('\x1b[9;5u')
    inkey('tab', vt, { A = true })
    expect_output('\x1b[9;3u')
    inkey('tab', vt, { C = true, A = true })
    expect_output('\x1b[9;7u')

    -- Backspace
    inkey('bs', vt)
    expect_output('\x7f')
    inkey('bs', vt, { S = true })
    expect_output('\x1b[127;2u')
    inkey('bs', vt, { C = true })
    expect_output('\x1b[127;5u')
    inkey('bs', vt, { A = true })
    expect_output('\x1b[127;3u')
    inkey('bs', vt, { C = true, A = true })
    expect_output('\x1b[127;7u')

    -- DEL
    inkey('del', vt)
    expect_output('\x1b[3~')
    inkey('del', vt, { S = true })
    expect_output('\x1b[3;2~')
    inkey('del', vt, { C = true })
    expect_output('\x1b[3;5~')
    inkey('del', vt, { A = true })
    expect_output('\x1b[3;3~')
    inkey('del', vt, { C = true, A = true })
    expect_output('\x1b[3;7~')

    -- ESC
    inkey('esc', vt)
    expect_output('\x1b[27;1u')
    inkey('esc', vt, { S = true })
    expect_output('\x1b[27;2u')
    inkey('esc', vt, { C = true })
    expect_output('\x1b[27;5u')
    inkey('esc', vt, { A = true })
    expect_output('\x1b[27;3u')
    inkey('esc', vt, { C = true, A = true })
    expect_output('\x1b[27;7u')

    -- Enter in linefeed mode
    inkey('enter', vt)
    expect_output('\x0d')
    inkey('enter', vt, { S = true })
    expect_output('\x1b[13;2u')
    inkey('enter', vt, { C = true })
    expect_output('\x1b[13;5u')
    inkey('enter', vt, { A = true })
    expect_output('\x1b[13;3u')
    inkey('enter', vt, { C = true, A = true })
    expect_output('\x1b[13;7u')

    -- Enter in newline mode
    push('\x1b[20h', vt)
    inkey('enter', vt)
    expect_output('\x0d\x0a')

    -- Unmodified F1 is SS3 P
    inkey('f1', vt)
    expect_output('\x1bOP')

    -- Modified F1 is CSI P
    inkey('f1', vt, { S = true })
    expect_output('\x1b[1;2P')
    inkey('f1', vt, { A = true })
    expect_output('\x1b[1;3P')
    inkey('f1', vt, { C = true })
    expect_output('\x1b[1;5P')

    -- Keypad in DECKPNM
    inkey('kp0', vt)
    expect_output('\x1b[57399;1u')

    -- Keypad in DECKPAM
    push('\x1b=', vt)
    inkey('kp0', vt)
    expect_output('\x1bOp')

    -- Bracketed paste mode off
    vterm.vterm_keyboard_start_paste(vt)
    vterm.vterm_keyboard_end_paste(vt)

    -- Bracketed paste mode on
    push('\x1b[?2004h', vt)
    vterm.vterm_keyboard_start_paste(vt)
    expect_output('\x1b[200~')
    vterm.vterm_keyboard_end_paste(vt)
    expect_output('\x1b[201~')

    -- Focus reporting disabled
    vterm.vterm_state_focus_in(state)
    vterm.vterm_state_focus_out(state)

    -- Focus reporting enabled
    state = wantstate(vt, { p = true })
    push('\x1b[?1004h', vt)
    expect('settermprop 9 true')
    vterm.vterm_state_focus_in(state)
    expect_output('\x1b[I')
    vterm.vterm_state_focus_out(state)
    expect_output('\x1b[O')

    -- Disambiguate escape codes disabled
    push('\x1b[<u', vt)

    -- Unmodified ASCII
    inchar(0x41, vt)
    expect_output('A')
    inchar(0x61, vt)
    expect_output('a')

    -- Ctrl modifier on ASCII letters
    inchar(0x41, vt, { C = true })
    expect_output('\x01')
    inchar(0x61, vt, { C = true })
    expect_output('\x01')

    -- Alt modifier on ASCII letters
    inchar(0x41, vt, { A = true })
    expect_output('\x1bA')
    inchar(0x61, vt, { A = true })
    expect_output('\x1ba')

    -- Ctrl-Alt modifier on ASCII letters
    inchar(0x41, vt, { C = true, A = true })
    expect_output('\x1b\x01')
    inchar(0x61, vt, { C = true, A = true })
    expect_output('\x1b\x01')

    -- Ctrl-I is ambiguous
    inchar(0x49, vt)
    expect_output('I')
    inchar(0x69, vt)
    expect_output('i')
    inchar(0x49, vt, { C = true })
    expect_output('\x09')
    inchar(0x69, vt, { C = true })
    expect_output('\x09')
    inchar(0x49, vt, { A = true })
    expect_output('\x1bI')
    inchar(0x69, vt, { A = true })
    expect_output('\x1bi')
    inchar(0x49, vt, { A = true, C = true })
    expect_output('\x1b\x09')
    inchar(0x69, vt, { A = true, C = true })
    expect_output('\x1b\x09')

    -- Ctrl+Digits
    inchar(0x30, vt, { C = true })
    expect_output('0')
    inchar(0x31, vt, { C = true })
    expect_output('1')
    inchar(0x32, vt, { C = true })
    expect_output('\x00')
    inchar(0x33, vt, { C = true })
    expect_output('\x1b')
    inchar(0x34, vt, { C = true })
    expect_output('\x1c')
    inchar(0x35, vt, { C = true })
    expect_output('\x1d')
    inchar(0x36, vt, { C = true })
    expect_output('\x1e')
    inchar(0x37, vt, { C = true })
    expect_output('\x1f')
    inchar(0x38, vt, { C = true })
    expect_output('\x7f')
    inchar(0x39, vt, { C = true })
    expect_output('9')

    -- Ctrl+/
    inchar(0x2F, vt, { C = true })
    expect_output('\x1f')
  end)

  itp('26state_query', function()
    local vt = init()
    local state = wantstate(vt)

    -- DA
    reset(state, nil)
    push('\x1b[c', vt)
    expect_output('\x1b[?1;2c')

    -- XTVERSION
    reset(state, nil)
    push('\x1b[>q', vt)
    expect_output('\x1bP>|libvterm(0.3)\x1b\\')

    -- DSR
    reset(state, nil)
    push('\x1b[5n', vt)
    expect_output('\x1b[0n')

    -- CPR
    push('\x1b[6n', vt)
    expect_output('\x1b[1;1R')
    push('\x1b[10;10H\x1b[6n', vt)
    expect_output('\x1b[10;10R')

    -- DECCPR
    push('\x1b[?6n', vt)
    expect_output('\x1b[?10;10R')

    -- DECRQSS on DECSCUSR
    push('\x1b[3 q', vt)
    push('\x1bP$q q\x1b\\', vt)
    expect_output('\x1bP1$r3 q\x1b\\')

    -- DECRQSS on SGR
    push('\x1b[1;5;7m', vt)
    push('\x1bP$qm\x1b\\', vt)
    expect_output('\x1bP1$r1;5;7m\x1b\\')

    -- DECRQSS on SGR ANSI colours
    push('\x1b[0;31;42m', vt)
    push('\x1bP$qm\x1b\\', vt)
    expect_output('\x1bP1$r31;42m\x1b\\')

    -- DECRQSS on SGR ANSI hi-bright colours
    push('\x1b[0;93;104m', vt)
    push('\x1bP$qm\x1b\\', vt)
    expect_output('\x1bP1$r93;104m\x1b\\')

    -- DECRQSS on SGR 256-palette colours
    push('\x1b[0;38:5:56;48:5:78m', vt)
    push('\x1bP$qm\x1b\\', vt)
    expect_output('\x1bP1$r38:5:56;48:5:78m\x1b\\')

    -- DECRQSS on SGR RGB8 colours
    push('\x1b[0;38:2:24:68:112;48:2:13:57:101m', vt)
    push('\x1bP$qm\x1b\\', vt)
    expect_output('\x1bP1$r38:2:24:68:112;48:2:13:57:101m\x1b\\')

    -- S8C1T on DSR
    push('\x1b G', vt)
    push('\x1b[5n', vt)
    expect_output('\x9b0n')
    push('\x1b F', vt)
  end)

  itp('27state_reset', function()
    local vt = init()
    local state = wantstate(vt)

    reset(state, nil)

    -- RIS homes cursor
    push('\x1b[5;5H', vt)
    cursor(4, 4, state)
    state = wantstate(vt, { m = true })
    push('\x1bc', vt)
    cursor(0, 0, state)
    wantstate(vt)

    -- RIS cancels scrolling region
    push('\x1b[5;10r', vt)
    wantstate(vt, { s = true })
    push('\x1bc\x1b[25H\n', vt)
    expect('scrollrect 0..25,0..80 => +1,+0')
    wantstate(vt)

    -- RIS erases screen
    push('ABCDE', vt)
    state = wantstate(vt, { e = true })
    push('\x1bc', vt)
    expect('erase 0..25,0..80')
    wantstate(vt)

    -- RIS clears tabstops
    push('\x1b[5G\x1bH\x1b[G\t', vt)
    cursor(0, 4, state)
    push('\x1bc\t', vt)
    cursor(0, 8, state)
  end)

  itp('28state_dbl_wh', function()
    local vt = init()
    local state = wantstate(vt, { g = true })

    -- Single Width, Single Height
    reset(state, nil)
    push('\x1b#5', vt)
    push('Hello', vt)
    expect(
      'putglyph 48 1 0,0\nputglyph 65 1 0,1\nputglyph 6c 1 0,2\nputglyph 6c 1 0,3\nputglyph 6f 1 0,4'
    )

    -- Double Width, Single Height
    reset(state, nil)
    push('\x1b#6', vt)
    push('Hello', vt)
    expect(
      'putglyph 48 1 0,0 dwl\nputglyph 65 1 0,1 dwl\nputglyph 6c 1 0,2 dwl\nputglyph 6c 1 0,3 dwl\nputglyph 6f 1 0,4 dwl'
    )
    cursor(0, 5, state)
    push('\x1b[40GAB', vt)
    expect('putglyph 41 1 0,39 dwl\nputglyph 42 1 1,0')
    cursor(1, 1, state)

    -- Double Height
    reset(state, nil)
    push('\x1b#3', vt)
    push('Hello', vt)
    expect(
      'putglyph 48 1 0,0 dwl dhl-top\nputglyph 65 1 0,1 dwl dhl-top\nputglyph 6c 1 0,2 dwl dhl-top\nputglyph 6c 1 0,3 dwl dhl-top\nputglyph 6f 1 0,4 dwl dhl-top'
    )
    cursor(0, 5, state)
    push('\r\n\x1b#4', vt)
    push('Hello', vt)
    expect(
      'putglyph 48 1 1,0 dwl dhl-bottom\nputglyph 65 1 1,1 dwl dhl-bottom\nputglyph 6c 1 1,2 dwl dhl-bottom\nputglyph 6c 1 1,3 dwl dhl-bottom\nputglyph 6f 1 1,4 dwl dhl-bottom'
    )
    cursor(1, 5, state)

    -- Double Width scrolling
    reset(state, nil)
    push('\x1b[20H\x1b#6ABC', vt)
    expect('putglyph 41 1 19,0 dwl\nputglyph 42 1 19,1 dwl\nputglyph 43 1 19,2 dwl')
    push('\x1b[25H\n', vt)
    push('\x1b[19;4HDE', vt)
    expect('putglyph 44 1 18,3 dwl\nputglyph 45 1 18,4 dwl')
    push('\x1b[H\x1bM', vt)
    push('\x1b[20;6HFG', vt)
    expect('putglyph 46 1 19,5 dwl\nputglyph 47 1 19,6 dwl')
  end)

  itp('29state_fallback', function()
    local vt = init()
    local state = wantstate(vt, { f = true })
    reset(state, nil)

    -- Unrecognised control
    push('\x03', vt)
    expect('control 03')

    -- Unrecognised CSI
    push('\x1b[?15;2z', vt)
    expect('csi 7a L=3f 15,2')

    -- Unrecognised OSC
    push('\x1b]27;Something\x1b\\', vt)
    expect('osc [27;Something]')

    -- Unrecognised DCS
    push('\x1bPz123\x1b\\', vt)
    expect('dcs [z123]')

    -- Unrecognised APC
    push('\x1b_z123\x1b\\', vt)
    expect('apc [z123]')

    -- Unrecognised PM
    push('\x1b^z123\x1b\\', vt)
    expect('pm [z123]')

    -- Unrecognised SOS
    push('\x1bXz123\x1b\\', vt)
    expect('sos [z123]')
  end)

  itp('30state_pen', function()
    local vt = init()
    local state = wantstate(vt)

    -- Reset
    push('\x1b[m', vt)
    pen('bold', false, state)
    pen('underline', 0, state)
    pen('italic', false, state)
    pen('blink', false, state)
    pen('reverse', false, state)
    pen('font', 0, state)
    -- TODO(dundargoc): fix
    -- ?pen foreground = rgb(240,240,240,is_default_fg)
    -- ?pen background = rgb(0,0,0,is_default_bg)

    -- Bold
    push('\x1b[1m', vt)
    pen('bold', true, state)
    push('\x1b[22m', vt)
    pen('bold', false, state)
    push('\x1b[1m\x1b[m', vt)
    pen('bold', false, state)

    -- Underline
    push('\x1b[4m', vt)
    pen('underline', 1, state)
    push('\x1b[21m', vt)
    pen('underline', 2, state)
    push('\x1b[24m', vt)
    pen('underline', 0, state)
    push('\x1b[4m\x1b[4:0m', vt)
    pen('underline', 0, state)
    push('\x1b[4:1m', vt)
    pen('underline', 1, state)
    push('\x1b[4:2m', vt)
    pen('underline', 2, state)
    push('\x1b[4:3m', vt)
    pen('underline', 3, state)
    push('\x1b[4m\x1b[m', vt)
    pen('underline', 0, state)

    -- Italic
    push('\x1b[3m', vt)
    pen('italic', true, state)
    push('\x1b[23m', vt)
    pen('italic', false, state)
    push('\x1b[3m\x1b[m', vt)
    pen('italic', false, state)

    -- Blink
    push('\x1b[5m', vt)
    pen('blink', true, state)
    push('\x1b[25m', vt)
    pen('blink', false, state)
    push('\x1b[5m\x1b[m', vt)
    pen('blink', false, state)

    -- Reverse
    push('\x1b[7m', vt)
    pen('reverse', true, state)
    push('\x1b[27m', vt)
    pen('reverse', false, state)
    push('\x1b[7m\x1b[m', vt)
    pen('reverse', false, state)

    -- Font Selection
    push('\x1b[11m', vt)
    pen('font', 1, state)
    push('\x1b[19m', vt)
    pen('font', 9, state)
    push('\x1b[10m', vt)
    pen('font', 0, state)
    push('\x1b[11m\x1b[m', vt)
    pen('font', 0, state)

    -- TODO(dundargoc): fix
    -- Foreground
    -- push "\x1b[31m"
    --   ?pen foreground = idx(1)
    -- push "\x1b[32m"
    --   ?pen foreground = idx(2)
    -- push "\x1b[34m"
    --   ?pen foreground = idx(4)
    -- push "\x1b[91m"
    --   ?pen foreground = idx(9)
    -- push "\x1b[38:2:10:20:30m"
    --   ?pen foreground = rgb(10,20,30)
    -- push "\x1b[38:5:1m"
    --   ?pen foreground = idx(1)
    -- push "\x1b[39m"
    --   ?pen foreground = rgb(240,240,240,is_default_fg)
    --
    -- Background
    -- push "\x1b[41m"
    --   ?pen background = idx(1)
    -- push "\x1b[42m"
    --   ?pen background = idx(2)
    -- push "\x1b[44m"
    --   ?pen background = idx(4)
    -- push "\x1b[101m"
    --   ?pen background = idx(9)
    -- push "\x1b[48:2:10:20:30m"
    --   ?pen background = rgb(10,20,30)
    -- push "\x1b[48:5:1m"
    --   ?pen background = idx(1)
    -- push "\x1b[49m"
    --   ?pen background = rgb(0,0,0,is_default_bg)
    --
    -- Bold+ANSI colour == highbright
    -- push "\x1b[m\x1b[1;37m"
    --   ?pen bold = on
    --   ?pen foreground = idx(15)
    -- push "\x1b[m\x1b[37;1m"
    --   ?pen bold = on
    --   ?pen foreground = idx(15)
    --
    -- Super/Subscript
    -- push "\x1b[73m"
    --   ?pen small = on
    --   ?pen baseline = raise
    -- push "\x1b[74m"
    --   ?pen small = on
    --   ?pen baseline = lower
    -- push "\x1b[75m"
    --   ?pen small = off
    --   ?pen baseline = normal
    --
    -- DECSTR resets pen attributes
    -- push "\x1b[1;4m"
    --   ?pen bold = on
    --   ?pen underline = 1
    -- push "\x1b[!p"
    --   ?pen bold = off
    --   ?pen underline = 0
  end)

  itp('31state_rep', function()
    local vt = init()
    local state = wantstate(vt, { g = true })

    -- REP no argument
    reset(state, nil)
    push('a\x1b[b', vt)
    expect('putglyph 61 1 0,0\nputglyph 61 1 0,1')

    -- REP zero (zero should be interpreted as one)
    reset(state, nil)
    push('a\x1b[0b', vt)
    expect('putglyph 61 1 0,0\nputglyph 61 1 0,1')

    -- REP lowercase a times two
    reset(state, nil)
    push('a\x1b[2b', vt)
    expect('putglyph 61 1 0,0\nputglyph 61 1 0,1\nputglyph 61 1 0,2')

    -- REP with UTF-8 1 char
    -- U+00E9 = C3 A9  name: LATIN SMALL LETTER E WITH ACUTE
    reset(state, nil)
    push('\xC3\xA9\x1b[b', vt)
    expect('putglyph e9 1 0,0\nputglyph e9 1 0,1')

    -- REP with UTF-8 wide char
    -- U+00E9 = C3 A9  name: LATIN SMALL LETTER E WITH ACUTE
    reset(state, nil)
    push('\xEF\xBC\x90\x1b[b', vt)
    expect('putglyph ff10 2 0,0\nputglyph ff10 2 0,2')

    -- REP with UTF-8 combining character
    reset(state, nil)
    push('e\xCC\x81\x1b[b', vt)
    expect('putglyph 65,301 1 0,0\nputglyph 65,301 1 0,1')

    -- REP till end of line
    reset(state, nil)
    push('a\x1b[1000bb', vt)
    expect(
      'putglyph 61 1 0,0\nputglyph 61 1 0,1\nputglyph 61 1 0,2\nputglyph 61 1 0,3\nputglyph 61 1 0,4\nputglyph 61 1 0,5\nputglyph 61 1 0,6\nputglyph 61 1 0,7\nputglyph 61 1 0,8\nputglyph 61 1 0,9\nputglyph 61 1 0,10\nputglyph 61 1 0,11\nputglyph 61 1 0,12\nputglyph 61 1 0,13\nputglyph 61 1 0,14\nputglyph 61 1 0,15\nputglyph 61 1 0,16\nputglyph 61 1 0,17\nputglyph 61 1 0,18\nputglyph 61 1 0,19\nputglyph 61 1 0,20\nputglyph 61 1 0,21\nputglyph 61 1 0,22\nputglyph 61 1 0,23\nputglyph 61 1 0,24\nputglyph 61 1 0,25\nputglyph 61 1 0,26\nputglyph 61 1 0,27\nputglyph 61 1 0,28\nputglyph 61 1 0,29\nputglyph 61 1 0,30\nputglyph 61 1 0,31\nputglyph 61 1 0,32\nputglyph 61 1 0,33\nputglyph 61 1 0,34\nputglyph 61 1 0,35\nputglyph 61 1 0,36\nputglyph 61 1 0,37\nputglyph 61 1 0,38\nputglyph 61 1 0,39\nputglyph 61 1 0,40\nputglyph 61 1 0,41\nputglyph 61 1 0,42\nputglyph 61 1 0,43\nputglyph 61 1 0,44\nputglyph 61 1 0,45\nputglyph 61 1 0,46\nputglyph 61 1 0,47\nputglyph 61 1 0,48\nputglyph 61 1 0,49\nputglyph 61 1 0,50\nputglyph 61 1 0,51\nputglyph 61 1 0,52\nputglyph 61 1 0,53\nputglyph 61 1 0,54\nputglyph 61 1 0,55\nputglyph 61 1 0,56\nputglyph 61 1 0,57\nputglyph 61 1 0,58\nputglyph 61 1 0,59\nputglyph 61 1 0,60\nputglyph 61 1 0,61\nputglyph 61 1 0,62\nputglyph 61 1 0,63\nputglyph 61 1 0,64\nputglyph 61 1 0,65\nputglyph 61 1 0,66\nputglyph 61 1 0,67\nputglyph 61 1 0,68\nputglyph 61 1 0,69\nputglyph 61 1 0,70\nputglyph 61 1 0,71\nputglyph 61 1 0,72\nputglyph 61 1 0,73\nputglyph 61 1 0,74\nputglyph 61 1 0,75\nputglyph 61 1 0,76\nputglyph 61 1 0,77\nputglyph 61 1 0,78\nputglyph 61 1 0,79\nputglyph 62 1 1,0'
    )
  end)

  itp('32state_flow', function()
    local vt = init()
    local state = wantstate(vt)

    -- Many of these test cases inspired by
    -- https://blueprints.launchpad.net/libvterm/+spec/reflow-cases

    -- Spillover text marks continuation on second line
    reset(state, nil)
    push(string.rep('A', 100), vt)
    push('\r\n', vt)
    lineinfo(0, {}, state)
    lineinfo(1, { cont = true }, state)

    -- CRLF in column 80 does not mark continuation
    reset(state, nil)
    push(string.rep('B', 80), vt)
    push('\r\n', vt)
    push(string.rep('B', 20), vt)
    push('\r\n', vt)
    lineinfo(0, {}, state)
    lineinfo(1, {}, state)

    -- EL cancels continuation of following line
    reset(state, nil)
    push(string.rep('D', 100), vt)
    lineinfo(1, { cont = true }, state)
    push('\x1bM\x1b[79G\x1b[K', vt)
    lineinfo(1, {}, state)
  end)

  itp('40state_selection', function()
    local vt = init()
    wantstate(vt)

    -- Set clipboard; final chunk len 4
    push('\x1b]52;c;SGVsbG8s\x1b\\', vt)
    expect('selection-set mask=0001 [Hello,]')

    -- Set clipboard; final chunk len 3
    push('\x1b]52;c;SGVsbG8sIHc=\x1b\\', vt)
    expect('selection-set mask=0001 [Hello, w]')

    -- Set clipboard; final chunk len 2
    push('\x1b]52;c;SGVsbG8sIHdvcmxkCg==\x1b\\', vt)
    expect('selection-set mask=0001 [Hello, world\n]')

    -- Set clipboard; split between chunks
    push('\x1b]52;c;SGVs', vt)
    expect('selection-set mask=0001 [Hel')
    push('bG8s\x1b\\', vt)
    expect('selection-set mask=0001 lo,]')

    -- Set clipboard; split within chunk
    push('\x1b]52;c;SGVsbG', vt)
    expect('selection-set mask=0001 [Hel')
    push('8s\x1b\\', vt)
    expect('selection-set mask=0001 lo,]')

    -- Set clipboard; empty first chunk
    push('\x1b]52;c;', vt)
    push('SGVsbG8s\x1b\\', vt)
    expect('selection-set mask=0001 [Hello,]')

    -- Set clipboard; empty final chunk
    push('\x1b]52;c;SGVsbG8s', vt)
    expect('selection-set mask=0001 [Hello,')
    push('\x1b\\', vt)
    expect('selection-set mask=0001 ]')

    -- Set clipboard; longer than buffer
    push('\x1b]52;c;' .. string.rep('LS0t', 10) .. '\x1b\\', vt)
    expect('selection-set mask=0001 [---------------\nselection-set mask=0001 ---------------]')

    -- Clear clipboard
    push('\x1b]52;c;\x1b\\', vt)
    expect('selection-set mask=0001 []')

    -- Set invalid data clears and ignores
    push('\x1b]52;c;SGVs*SGVsbG8s\x1b\\', vt)
    expect('selection-set mask=0001 []')

    -- Query clipboard
    push('\x1b]52;c;?\x1b\\', vt)
    expect('selection-query mask=0001')

    -- TODO(dundargoc): fix
    -- Send clipboard; final chunk len 4
    -- SELECTION 1 ["Hello,"]
    --   output "\x1b]52;c;"
    --   output "SGVsbG8s"
    --   output "\x1b\\"
    --
    -- Send clipboard; final chunk len 3
    -- SELECTION 1 ["Hello, w"]
    --   output "\x1b]52;c;"
    --   output "SGVsbG8s"
    --   output "IHc=\x1b\\"
    --
    -- Send clipboard; final chunk len 2
    -- SELECTION 1 ["Hello, world\n"]
    --   output "\x1b]52;c;"
    --   output "SGVsbG8sIHdvcmxk"
    --   output "Cg==\x1b\\"
    --
    -- Send clipboard; split between chunks
    -- SELECTION 1 ["Hel"
    --   output "\x1b]52;c;"
    --   output "SGVs"
    -- SELECTION 1  "lo,"]
    --   output "bG8s"
    --   output "\x1b\\"
    --
    -- Send clipboard; split within chunk
    -- SELECTION 1 ["Hello"
    --   output "\x1b]52;c;"
    --   output "SGVs"
    -- SELECTION 1 ","]
    --   output "bG8s"
    --   output "\x1b\\"
  end)

  itp('60screen_ascii', function()
    local vt = init()
    local screen = wantscreen(vt, { a = true, c = true })

    -- Get
    reset(nil, screen)
    push('ABC', vt)
    expect('movecursor 0,3')
    screen_chars(0, 0, 1, 3, 'ABC', screen)
    screen_chars(0, 0, 1, 80, 'ABC', screen)
    screen_text(0, 0, 1, 3, '41,42,43', screen)
    screen_text(0, 0, 1, 80, '41,42,43', screen)
    screen_cell(0, 0, '{41} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(0, 1, '{42} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(0, 2, '{43} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_row(0, 'ABC', screen)
    screen_eol(0, 0, 0, screen)
    screen_eol(0, 2, 0, screen)
    screen_eol(0, 3, 1, screen)
    push('\x1b[H', vt)
    expect('movecursor 0,0')
    screen_row(0, 'ABC', screen)
    screen_text(0, 0, 1, 80, '41,42,43', screen)
    push('E', vt)
    expect('movecursor 0,1')
    screen_row(0, 'EBC', screen)
    screen_text(0, 0, 1, 80, '45,42,43', screen)

    screen = wantscreen(vt, { a = true })

    -- Erase
    reset(nil, screen)
    push('ABCDE\x1b[H\x1b[K', vt)
    -- TODO(dundargoc): fix
    -- screen_row(0, '', screen)
    screen_text(0, 0, 1, 80, '', screen)

    -- Copycell
    reset(nil, screen)
    push('ABC\x1b[H\x1b[@', vt)
    push('1', vt)
    screen_row(0, '1ABC', screen)

    reset(nil, screen)
    push('ABC\x1b[H\x1b[P', vt)
    screen_chars(0, 0, 1, 1, 'B', screen)
    screen_chars(0, 1, 1, 2, 'C', screen)
    screen_chars(0, 0, 1, 80, 'BC', screen)

    -- Space padding
    reset(nil, screen)
    push('Hello\x1b[CWorld', vt)
    screen_row(0, 'Hello World', screen)
    screen_text(0, 0, 1, 80, '48,65,6c,6c,6f,20,57,6f,72,6c,64', screen)

    -- Linefeed padding
    reset(nil, screen)
    push('Hello\r\nWorld', vt)
    screen_chars(0, 0, 2, 80, 'Hello\nWorld', screen)
    screen_text(0, 0, 2, 80, '48,65,6c,6c,6f,0a,57,6f,72,6c,64', screen)

    -- Altscreen
    reset(nil, screen)
    push('P', vt)
    screen_row(0, 'P', screen)
    -- TODO(dundargoc): fix
    -- push('\x1b[?1049h', vt)
    -- screen_row(0, '', screen)
    -- push('\x1b[2K\x1b[HA', vt)
    -- screen_row(0, 'A', screen)
    -- push('\x1b[?1049l', vt)
    -- screen_row(0, 'P', screen)
  end)

  itp('61screen_unicode', function()
    local vt = init()
    local screen = wantscreen(vt)

    -- Single width UTF-8
    -- U+00C1 = C3 81  name: LATIN CAPITAL LETTER A WITH ACUTE
    -- U+00E9 = C3 A9  name: LATIN SMALL LETTER E WITH ACUTE
    reset(nil, screen)
    push('\xC3\x81\xC3\xA9', vt)
    screen_row(0, 'Áé', screen)
    screen_text(0, 0, 1, 80, 'c3,81,c3,a9', screen)
    screen_cell(0, 0, '{c1} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Wide char
    -- U+FF10 = EF BC 90  name: FULLWIDTH DIGIT ZERO
    reset(nil, screen)
    push('0123\x1b[H', vt)
    push('\xEF\xBC\x90', vt)
    screen_row(0, '０23', screen)
    screen_text(0, 0, 1, 80, 'ef,bc,90,32,33', screen)
    screen_cell(0, 0, '{ff10} width=2 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Combining char
    -- U+0301 = CC 81  name: COMBINING ACUTE
    reset(nil, screen)
    push('0123\x1b[H', vt)
    push('e\xCC\x81', vt)
    screen_row(0, 'é123', screen)
    screen_text(0, 0, 1, 80, '65,cc,81,31,32,33', screen)
    screen_cell(0, 0, '{65,301} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- 10 combining accents should not crash
    reset(nil, screen)
    push('e\xCC\x81\xCC\x82\xCC\x83\xCC\x84\xCC\x85\xCC\x86\xCC\x87\xCC\x88\xCC\x89\xCC\x8A', vt)
    screen_cell(
      0,
      0,
      '{65,301,302,303,304,305,306,307,308,309,30a} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)',
      screen
    )

    -- 40 combining accents in two split writes of 20 should not crash
    reset(nil, screen)
    push(
      'e\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81',
      vt
    )
    push(
      '\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81\xCC\x81',
      vt
    )
    screen_cell(
      0,
      0,
      '{65,301,301,301,301,301,301,301,301,301,301,301,301,301,301} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)',
      screen
    )

    -- Outputting CJK doublewidth in 80th column should wraparound to next line and not crash"
    reset(nil, screen)
    push('\x1b[80G\xEF\xBC\x90', vt)
    screen_cell(0, 79, '{} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(1, 0, '{ff10} width=2 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Outputting emoji with ZWJ and variant selectors
    reset(nil, screen)
    push('🏳️‍🌈🏳️‍⚧️🏴‍☠️', vt)

    -- stylua: ignore start
    screen_cell(0, 0, '{1f3f3,fe0f,200d,1f308} width=2 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(0, 2, '{1f3f3,fe0f,200d,26a7,fe0f} width=2 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(0, 4, '{1f3f4,200d,2620,fe0f} width=2 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    -- stylua: ignore end
  end)

  pending('62screen_damage', function() end)

  itp('63screen_resize', function()
    local vt = init()
    local state = wantstate(vt)
    local screen = wantscreen(vt)

    -- Resize wider preserves cells
    reset(state, screen)
    resize(25, 80, vt)
    push('AB\r\nCD', vt)
    screen_chars(0, 0, 1, 80, 'AB', screen)
    screen_chars(1, 0, 2, 80, 'CD', screen)
    resize(25, 100, vt)
    screen_chars(0, 0, 1, 100, 'AB', screen)
    screen_chars(1, 0, 2, 100, 'CD', screen)

    -- Resize wider allows print in new area
    reset(state, screen)
    resize(25, 80, vt)
    push('AB\x1b[79GCD', vt)
    screen_chars(0, 0, 1, 2, 'AB', screen)
    screen_chars(0, 78, 1, 80, 'CD', screen)
    resize(25, 100, vt)
    screen_chars(0, 0, 1, 2, 'AB', screen)
    screen_chars(0, 78, 1, 80, 'CD', screen)
    push('E', vt)
    screen_chars(0, 78, 1, 81, 'CDE', screen)

    -- Resize shorter with blanks just truncates
    reset(state, screen)
    resize(25, 80, vt)
    push('Top\x1b[10HLine 10', vt)
    screen_row(0, 'Top', screen)
    screen_row(9, 'Line 10', screen)
    cursor(9, 7, state)
    resize(20, 80, vt)
    screen_row(0, 'Top', screen)
    screen_row(9, 'Line 10', screen)
    cursor(9, 7, state)

    -- Resize shorter with content must scroll
    reset(state, screen)
    resize(25, 80, vt)
    push('Top\x1b[25HLine 25\x1b[15H', vt)
    screen_row(0, 'Top', screen)
    screen_row(24, 'Line 25', screen)
    cursor(14, 0, state)
    screen = wantscreen(vt, { b = true })
    resize(20, 80, vt)
    expect(
      'sb_pushline 80 = 54 6f 70\nsb_pushline 80 =\nsb_pushline 80 =\nsb_pushline 80 =\nsb_pushline 80 ='
    )
    -- TODO(dundargoc): fix or remove
    -- screen_row( 0  , "",screen)
    screen_row(19, 'Line 25', screen)
    cursor(9, 0, state)

    -- Resize shorter does not lose line with cursor
    -- See also https://github.com/neovim/libvterm/commit/1b745d29d45623aa8d22a7b9288c7b0e331c7088
    reset(state, screen)
    wantscreen(vt)
    resize(25, 80, vt)
    screen = wantscreen(vt, { b = true })
    push('\x1b[24HLine 24\r\nLine 25\r\n', vt)
    expect('sb_pushline 80 =')
    screen_row(23, 'Line 25', screen)
    cursor(24, 0, state)
    resize(24, 80, vt)
    expect('sb_pushline 80 =')
    screen_row(22, 'Line 25', screen)
    cursor(23, 0, state)

    -- Resize shorter does not send the cursor to a negative row
    -- See also https://github.com/vim/vim/pull/6141
    reset(state, screen)
    wantscreen(vt)
    resize(25, 80, vt)
    screen = wantscreen(vt, { b = true })
    push('\x1b[24HLine 24\r\nLine 25\x1b[H', vt)
    cursor(0, 0, state)
    resize(20, 80, vt)
    expect(
      'sb_pushline 80 =\nsb_pushline 80 =\nsb_pushline 80 =\nsb_pushline 80 =\nsb_pushline 80 ='
    )
    cursor(0, 0, state)

    -- Resize taller attempts to pop scrollback
    reset(state, screen)
    screen = wantscreen(vt)
    resize(25, 80, vt)
    push('Line 1\x1b[25HBottom\x1b[15H', vt)
    screen_row(0, 'Line 1', screen)
    screen_row(24, 'Bottom', screen)
    cursor(14, 0, state)
    screen = wantscreen(vt, { b = true })
    resize(30, 80, vt)
    expect('sb_popline 80\nsb_popline 80\nsb_popline 80\nsb_popline 80\nsb_popline 80')
    screen_row(0, 'ABCDE', screen)
    screen_row(5, 'Line 1', screen)
    screen_row(29, 'Bottom', screen)
    cursor(19, 0, state)
    screen = wantscreen(vt)

    -- Resize can operate on altscreen
    reset(state, screen)
    screen = wantscreen(vt, { a = true })
    resize(25, 80, vt)
    push('Main screen\x1b[?1049h\x1b[HAlt screen', vt)
    resize(30, 80, vt)
    screen_row(0, 'Alt screen', screen)
    push('\x1b[?1049l', vt)
    screen_row(0, 'Main screen', screen)
  end)

  itp('64screen_pen', function()
    local vt = init()
    local screen = wantscreen(vt)

    reset(nil, screen)

    -- Plain
    push('A', vt)
    screen_cell(0, 0, '{41} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Bold
    push('\x1b[1mB', vt)
    screen_cell(0, 1, '{42} width=1 attrs={B} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Italic
    push('\x1b[3mC', vt)
    screen_cell(0, 2, '{43} width=1 attrs={BI} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Underline
    push('\x1b[4mD', vt)
    screen_cell(0, 3, '{44} width=1 attrs={BU1I} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Reset
    push('\x1b[mE', vt)
    screen_cell(0, 4, '{45} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Font
    push('\x1b[11mF\x1b[m', vt)
    screen_cell(0, 5, '{46} width=1 attrs={F1} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Foreground
    push('\x1b[31mG\x1b[m', vt)
    screen_cell(0, 6, '{47} width=1 attrs={} fg=rgb(224,0,0) bg=rgb(0,0,0)', screen)

    -- Background
    push('\x1b[42mH\x1b[m', vt)
    screen_cell(0, 7, '{48} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,224,0)', screen)

    -- Super/subscript
    push('x\x1b[74m0\x1b[73m2\x1b[m', vt)
    screen_cell(0, 8, '{78} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(0, 9, '{30} width=1 attrs={S_} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(0, 10, '{32} width=1 attrs={S^} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- EL sets only colours to end of line, not other attrs
    push('\x1b[H\x1b[7;33;44m\x1b[K', vt)
    screen_cell(0, 0, '{} width=1 attrs={} fg=rgb(224,224,0) bg=rgb(0,0,224)', screen)
    screen_cell(0, 79, '{} width=1 attrs={} fg=rgb(224,224,0) bg=rgb(0,0,224)', screen)

    -- DECSCNM xors reverse for entire screen
    push('R\x1b[?5h', vt)
    screen_cell(0, 0, '{52} width=1 attrs={} fg=rgb(224,224,0) bg=rgb(0,0,224)', screen)
    screen_cell(1, 0, '{} width=1 attrs={R} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    push('\x1b[?5$p', vt)
    expect_output('\x1b[?5;1$y')
    push('\x1b[?5l', vt)
    screen_cell(0, 0, '{52} width=1 attrs={R} fg=rgb(224,224,0) bg=rgb(0,0,224)', screen)
    screen_cell(1, 0, '{} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    -- TODO(dundargoc): fix
    -- push('\x1b[?5$p')
    -- expect_output('\x1b[?5;2$y')

    -- Set default colours
    reset(nil, screen)
    push('ABC\x1b[31mDEF\x1b[m', vt)
    screen_cell(0, 0, '{41} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(0, 3, '{44} width=1 attrs={} fg=rgb(224,0,0) bg=rgb(0,0,0)', screen)
    -- TODO(dundargoc): fix
    -- SETDEFAULTCOL rgb(252,253,254)
    --   ?screen_cell 0,0  = {41} width=1 attrs={} fg=rgb(252,253,254) bg=rgb(0,0,0)
    --   ?screen_cell 0,3  = {44} width=1 attrs={} fg=rgb(224,0,0) bg=rgb(0,0,0)
    -- SETDEFAULTCOL rgb(250,250,250) rgb(10,20,30)
    --   ?screen_cell 0,0  = {41} width=1 attrs={} fg=rgb(250,250,250) bg=rgb(10,20,30)
    --   ?screen_cell 0,3  = {44} width=1 attrs={} fg=rgb(224,0,0) bg=rgb(10,20,30)
  end)

  itp('65screen_protect', function()
    local vt = init()
    local screen = wantscreen(vt)

    -- Selective erase
    reset(nil, screen)
    push('A\x1b[1"qB\x1b["qC', vt)
    screen_row(0, 'ABC', screen)
    push('\x1b[G\x1b[?J', vt)
    screen_row(0, ' B', screen)

    -- Non-selective erase
    reset(nil, screen)
    push('A\x1b[1"qB\x1b["qC', vt)
    screen_row(0, 'ABC', screen)
    -- TODO(dundargoc): fix
    -- push('\x1b[G\x1b[J', vt)
    -- screen_row(0, '', screen)
  end)

  itp('66screen_extent', function()
    local vt = init()
    local screen = wantscreen(vt)

    -- Bold extent
    reset(nil, screen)
    push('AB\x1b[1mCD\x1b[mE', vt)
    screen_attrs_extent(0, 0, '0,0-1,1', screen)
    screen_attrs_extent(0, 1, '0,0-1,1', screen)
    screen_attrs_extent(0, 2, '0,2-1,3', screen)
    screen_attrs_extent(0, 3, '0,2-1,3', screen)
    screen_attrs_extent(0, 4, '0,4-1,79', screen)
  end)

  itp('67screen_dbl_wh', function()
    local vt = init()
    local screen = wantscreen(vt)

    reset(nil, screen)

    -- Single Width, Single Height
    reset(nil, screen)
    push('\x1b#5', vt)
    push('abcde', vt)
    screen_cell(0, 0, '{61} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Double Width, Single Height
    reset(nil, screen)
    push('\x1b#6', vt)
    push('abcde', vt)
    screen_cell(0, 0, '{61} width=1 attrs={} dwl fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- Double Height
    reset(nil, screen)
    push('\x1b#3', vt)
    push('abcde', vt)
    push('\r\n\x1b#4', vt)
    push('abcde', vt)
    screen_cell(0, 0, '{61} width=1 attrs={} dwl dhl-top fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(
      1,
      0,
      '{61} width=1 attrs={} dwl dhl-bottom fg=rgb(240,240,240) bg=rgb(0,0,0)',
      screen
    )

    -- Late change
    reset(nil, screen)
    push('abcde', vt)
    screen_cell(0, 0, '{61} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    push('\x1b#6', vt)
    screen_cell(0, 0, '{61} width=1 attrs={} dwl fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)

    -- DWL doesn't spill over on scroll
    reset(nil, screen)
    push('\x1b[25H\x1b#6Final\r\n', vt)
    screen_cell(23, 0, '{46} width=1 attrs={} dwl fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
    screen_cell(24, 0, '{} width=1 attrs={} fg=rgb(240,240,240) bg=rgb(0,0,0)', screen)
  end)

  itp('68screen_termprops', function()
    local vt = init()
    local screen = wantscreen(vt, { p = true })

    reset(nil, screen)
    expect('settermprop 1 true\nsettermprop 2 true\nsettermprop 7 1')

    -- Cursor visibility
    push('\x1b[?25h', vt)
    expect('settermprop 1 true')
    push('\x1b[?25l', vt)
    expect('settermprop 1 false')

    -- Title
    push('\x1b]2;Here is my title\a', vt)
    expect('settermprop 4 ["Here is my title"]')
  end)

  itp('69screen_pushline', function()
    local vt = init()
    -- Run these tests on a much smaller default screen, so debug output is nowhere near as noisy
    resize(5, 10, vt)
    local state = wantstate(vt)
    local screen = wantscreen(vt, { r = true })
    reset(state, screen)

    -- Resize wider reflows wide lines
    reset(state, screen)
    push(string.rep('A', 12), vt)
    screen_row(0, 'AAAAAAAAAA', screen, vt.cols)
    screen_row(1, 'AA', screen, vt.cols)
    lineinfo(1, { cont = true }, state)
    cursor(1, 2, state)
    resize(5, 15, vt)
    screen_row(0, 'AAAAAAAAAAAA', screen, vt.cols)
    -- TODO(dundargoc): fix
    -- screen_row(1, '', screen, vt.cols)
    lineinfo(1, {}, state)
    cursor(0, 12, state)
    resize(5, 20, vt)
    screen_row(0, 'AAAAAAAAAAAA', screen, vt.cols)
    -- TODO(dundargoc): fix
    -- screen_row( 1 ,'',screen, vt.cols)
    lineinfo(1, {}, state)
    cursor(0, 12, state)

    -- Resize narrower can create continuation lines
    reset(state, screen)
    resize(5, 10, vt)
    push('ABCDEFGHI', vt)
    screen_row(0, 'ABCDEFGHI', screen, vt.cols)
    -- TODO(dundargoc): fix
    -- screen_row( 1 , "",screen, vt.cols)
    lineinfo(1, {}, state)
    cursor(0, 9, state)
    resize(5, 8, vt)
    -- TODO(dundargoc): fix
    -- screen_row( 0 , "ABCDEFGH",screen,vt.cols)
    screen_row(1, 'I', screen, vt.cols)
    lineinfo(1, { cont = true }, state)
    cursor(1, 1, state)
    resize(5, 6, vt)
    screen_row(0, 'ABCDEF', screen, vt.cols)
    screen_row(1, 'GHI', screen, vt.cols)
    lineinfo(1, { cont = true }, state)
    cursor(1, 3, state)

    -- Shell wrapped prompt behaviour
    reset(state, screen)
    resize(5, 10, vt)
    push('PROMPT GOES HERE\r\n> \r\n\r\nPROMPT GOES HERE\r\n> ', vt)
    screen_row(0, '> ', screen, vt.cols)
    -- TODO(dundargoc): fix
    -- screen_row( 1 , "",screen,vt.cols)
    screen_row(2, 'PROMPT GOE', screen, vt.cols)
    screen_row(3, 'S HERE', screen, vt.cols)
    lineinfo(3, { cont = true }, state)
    screen_row(4, '> ', screen, vt.cols)
    cursor(4, 2, state)
    resize(5, 11, vt)
    screen_row(0, '> ', screen, vt.cols)
    -- TODO(dundargoc): fix
    -- screen_row( 1 , "",screen,vt.cols)
    screen_row(2, 'PROMPT GOES', screen, vt.cols)
    screen_row(3, ' HERE', screen, vt.cols)
    lineinfo(3, { cont = true }, state)
    screen_row(4, '> ', screen, vt.cols)
    cursor(4, 2, state)
    resize(5, 12, vt)
    screen_row(0, '> ', screen, vt.cols)
    -- TODO(dundargoc): fix
    -- screen_row( 1 , "",screen,vt.cols)
    screen_row(2, 'PROMPT GOES ', screen, vt.cols)
    screen_row(3, 'HERE', screen, vt.cols)
    lineinfo(3, { cont = true }, state)
    screen_row(4, '> ', screen, vt.cols)
    cursor(4, 2, state)
    resize(5, 16, vt)
    screen_row(0, '> ', screen, vt.cols)
    -- TODO(dundargoc): fix
    -- screen_row( 1 , "",screen,vt.cols)
    -- screen_row( 2 , "PROMPT GOES HERE",screen,vt.cols)
    lineinfo(3, {}, state)
    screen_row(3, '> ', screen, vt.cols)
    cursor(3, 2, state)

    -- Cursor goes missing
    -- For more context: https://github.com/neovim/neovim/pull/21124
    reset(state, screen)
    resize(5, 5, vt)
    resize(3, 1, vt)
    push('\x1b[2;1Habc\r\n\x1b[H', vt)
    resize(1, 1, vt)
    cursor(0, 0, state)
  end)

  pending('90vttest_01-movement-1', function() end)
  pending('90vttest_01-movement-2', function() end)

  itp('90vttest_01-movement-3', function()
    -- Test of cursor-control characters inside ESC sequences
    local vt = init()
    local state = wantstate(vt)
    local screen = wantscreen(vt)

    reset(state, screen)

    push('A B C D E F G H I', vt)
    push('\x0d\x0a', vt)
    push('A\x1b[2\bCB\x1b[2\bCC\x1b[2\bCD\x1b[2\bCE\x1b[2\bCF\x1b[2\bCG\x1b[2\bCH\x1b[2\bCI', vt)
    push('\x0d\x0a', vt)
    push(
      'A \x1b[\x0d2CB\x1b[\x0d4CC\x1b[\x0d6CD\x1b[\x0d8CE\x1b[\x0d10CF\x1b[\x0d12CG\x1b[\x0d14CH\x1b[\x0d16CI',
      vt
    )
    push('\x0d\x0a', vt)
    push(
      'A \x1b[1\x0bAB \x1b[1\x0bAC \x1b[1\x0bAD \x1b[1\x0bAE \x1b[1\x0bAF \x1b[1\x0bAG \x1b[1\x0bAH \x1b[1\x0bAI \x1b[1\x0bA',
      vt
    )

    -- Output

    for i = 0, 2 do
      screen_row(i, 'A B C D E F G H I', screen)
    end
    screen_row(3, 'A B C D E F G H I ', screen)

    cursor(3, 18, state)
  end)

  itp('90vttest_01-movement-4', function()
    -- Test of leading zeroes in ESC sequences
    local vt = init()
    local screen = wantscreen(vt)

    reset(nil, screen)

    push('\x1b[00000000004;000000001HT', vt)
    push('\x1b[00000000004;000000002Hh', vt)
    push('\x1b[00000000004;000000003Hi', vt)
    push('\x1b[00000000004;000000004Hs', vt)
    push('\x1b[00000000004;000000005H ', vt)
    push('\x1b[00000000004;000000006Hi', vt)
    push('\x1b[00000000004;000000007Hs', vt)
    push('\x1b[00000000004;000000008H ', vt)
    push('\x1b[00000000004;000000009Ha', vt)
    push('\x1b[00000000004;0000000010H ', vt)
    push('\x1b[00000000004;0000000011Hc', vt)
    push('\x1b[00000000004;0000000012Ho', vt)
    push('\x1b[00000000004;0000000013Hr', vt)
    push('\x1b[00000000004;0000000014Hr', vt)
    push('\x1b[00000000004;0000000015He', vt)
    push('\x1b[00000000004;0000000016Hc', vt)
    push('\x1b[00000000004;0000000017Ht', vt)
    push('\x1b[00000000004;0000000018H ', vt)
    push('\x1b[00000000004;0000000019Hs', vt)
    push('\x1b[00000000004;0000000020He', vt)
    push('\x1b[00000000004;0000000021Hn', vt)
    push('\x1b[00000000004;0000000022Ht', vt)
    push('\x1b[00000000004;0000000023He', vt)
    push('\x1b[00000000004;0000000024Hn', vt)
    push('\x1b[00000000004;0000000025Hc', vt)
    push('\x1b[00000000004;0000000026He', vt)

    -- Output

    screen_row(3, 'This is a correct sentence', screen)
  end)

  pending('90vttest_02-screen-1', function() end)
  pending('90vttest_02-screen-2', function() end)

  itp('90vttest_02-screen-3', function()
    -- Origin mode
    local vt = init()
    local screen = wantscreen(vt)

    reset(nil, screen)

    push('\x1b[?6h', vt)
    push('\x1b[23;24r', vt)
    push('\n', vt)
    push('Bottom', vt)
    push('\x1b[1;1H', vt)
    push('Above', vt)

    -- Output
    screen_row(22, 'Above', screen)
    screen_row(23, 'Bottom', screen)
  end)

  itp('90vttest_02-screen-4', function()
    -- Origin mode (2)
    local vt = init()
    local screen = wantscreen(vt)

    reset(nil, screen)

    push('\x1b[?6l', vt)
    push('\x1b[23;24r', vt)
    push('\x1b[24;1H', vt)
    push('Bottom', vt)
    push('\x1b[1;1H', vt)
    push('Top', vt)

    -- Output
    screen_row(23, 'Bottom', screen)
    screen_row(0, 'Top', screen)
  end)

  itp('Mouse reporting should not break by idempotent DECSM 1002', function()
    -- Regression test for https://bugs.launchpad.net/libvterm/+bug/1640917
    -- Related: https://github.com/neovim/neovim/issues/5583
    local vt = init()
    wantstate(vt, {})

    push('\x1b[?1002h', vt)
    mousemove(0, 0, vt)
    mousebtn('d', 1, vt)
    expect_output('\x1b[M\x20\x21\x21')
    mousemove(1, 0, vt)
    expect_output('\x1b[M\x40\x21\x22')
    push('\x1b[?1002h', vt)
    mousemove(2, 0, vt)
    expect_output('\x1b[M\x40\x21\x23')
  end)
end)
