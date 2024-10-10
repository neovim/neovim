local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

--- @class vterm
--- @field vterm_new fun(any, any):any
--- @field vterm_parser_set_callbacks fun(any, any, any):any
--- @field vterm_set_utf8 fun(any, any, any):any
--- @field parser_text fun()
--- @field parser_control fun()
--- @field parser_escape fun()
--- @field parser_csi fun()
--- @field parser_osc fun()
--- @field parser_dcs fun()
--- @field parser_apc fun()
--- @field parser_pm fun()
--- @field parser_sos fun()
--- @field vterm_input_write fun(any, any, any)
local vterm = t.cimport('./src/vterm/vterm.h', './src/vterm/vterm_internal.h')
local test_output_file = 'test_parser_output'

--- @return any
local function init()
  local vt = vterm.vterm_new(25, 80)
  -- vterm.vterm_output_set_callback(vt, term_output, nil)
  return vt
end

local function wantparser(vt)
  assert(vt)

  local parser_cbs = t.ffi.new('VTermParserCallbacks')
  parser_cbs['text'] = vterm.parser_text
  parser_cbs['control'] = vterm.parser_control
  parser_cbs['escape'] = vterm.parser_escape
  parser_cbs['csi'] = vterm.parser_csi
  parser_cbs['osc'] = vterm.parser_osc
  parser_cbs['dcs'] = vterm.parser_dcs
  parser_cbs['apc'] = vterm.parser_apc
  parser_cbs['pm'] = vterm.parser_pm
  parser_cbs['sos'] = vterm.parser_sos

  vterm.vterm_parser_set_callbacks(vt, parser_cbs, nil)
end

local function wantstate(vt, opts)
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
  -- state_cbs['setlineinfo'] = vterm.state_setlineinfo
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
  fallbacks['control'] = vterm.parser_control
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
  local f = assert(io.open(test_output_file, 'rb'))
  local actual = f:read('*a')
  f:close()

  vim.fs.rm(test_output_file)
  t.eq(expected .. '\n', actual)
end

local function cursor(row, col, state)
  local pos = t.ffi.new('VTermPos')
  vterm.vterm_state_get_cursorpos(state, pos)
  t.eq(row, pos.row)
  t.eq(col, pos.col)
end

local function resize(rows, cols, vt)
  vterm.vterm_set_size(vt, rows, cols)
end

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
    expect('escape 3d')

    -- Escape 2-byte
    push('\x1b(X', vt)
    expect('escape 2858')

    -- Split write Escape
    push('\x1b(', vt)
    push('Y', vt)
    expect('escape 2859')

    -- Escape cancels Escape, starts another
    push('\x1b(\x1b)Z', vt)
    expect('escape 295a')

    -- CAN cancels Escape, returns to normal mode
    push('\x1b(\x18AB', vt)
    expect('text 41,42')

    -- C0 in Escape interrupts and continues
    push('\x1b(\nX', vt)
    expect('control 0a\nescape 2858')

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
    expect('escape 39')

    -- CAN cancels CSI, returns to normal mode
    push('\x1b[12\x18AB', vt)
    expect('text 41,42')

    -- TODO(dundargoc): fix or remove
    -- C0 in Escape interrupts and continues
    -- push "\x1b(\nX"
    --   control 10
    --   escape "(X"

    -- OSC BEL
    push('\x1b]1;Hello\x07', vt)
    expect('osc [1;48656c6c6f]')

    -- OSC ST (7bit)
    push('\x1b]1;Hello\x1b\\', vt)
    expect('osc [1;48656c6c6f]')

    -- OSC ST (8bit)
    push('\x9d1;Hello\x9c', vt)
    expect('osc [1;48656c6c6f]')

    -- OSC in parts
    push('\x1b]52;abc', vt)
    expect('osc [52;616263')
    push('def', vt)
    expect('osc 646566')
    push('ghi\x1b\\', vt)
    expect('osc 676869]')

    -- OSC BEL without semicolon
    push('\x1b]1234\x07', vt)
    expect('osc [1234;]')

    -- OSC ST without semicolon
    push('\x1b]1234\x1b\\', vt)
    expect('osc [1234;]')

    -- Escape cancels OSC, starts Escape
    push('\x1b]Something\x1b9', vt)
    expect('escape 39')

    -- CAN cancels OSC, returns to normal mode
    push('\x1b]12\x18AB', vt)
    expect('text 41,42')

    -- C0 in OSC interrupts and continues
    push('\x1b]2;\nBye\x07', vt)
    expect('osc [2;\ncontrol 0a\nosc 427965]')

    -- DCS BEL
    push('\x1bPHello\x07', vt)
    expect('dcs [48656c6c6f]')

    -- DCS ST (7bit)
    push('\x1bPHello\x1b\\', vt)
    expect('dcs [48656c6c6f]')

    -- DCS ST (8bit)
    push('\x90Hello\x9c', vt)
    expect('dcs [48656c6c6f]')

    -- Split write of 7bit ST
    push('\x1bPABC\x1b', vt)
    expect('dcs [414243')
    push('\\', vt)
    expect('dcs ]')

    -- Escape cancels DCS, starts Escape
    push('\x1bPSomething\x1b9', vt)
    expect('escape 39')

    -- CAN cancels DCS, returns to normal mode
    push('\x1bP12\x18AB', vt)
    expect('text 41,42')

    -- C0 in OSC interrupts and continues
    push('\x1bPBy\ne\x07', vt)
    expect('dcs [4279\ncontrol 0a\ndcs 65]')

    -- APC BEL
    push('\x1b_Hello\x07', vt)
    expect('apc [48656c6c6f]')

    -- APC ST (7bit)
    push('\x1b_Hello\x1b\\', vt)
    expect('apc [48656c6c6f]')

    -- APC ST (8bit)
    push('\x9fHello\x9c', vt)
    expect('apc [48656c6c6f]')

    -- PM BEL
    push('\x1b^Hello\x07', vt)
    expect('pm [48656c6c6f]')

    -- PM ST (7bit)
    push('\x1b^Hello\x1b\\', vt)
    expect('pm [48656c6c6f]')

    -- PM ST (8bit)
    push('\x9eHello\x9c', vt)
    expect('pm [48656c6c6f]')

    -- SOS BEL
    push('\x1bXHello\x07', vt)
    expect('sos [48656c6c6f]')

    -- SOS ST (7bit)
    push('\x1bXHello\x1b\\', vt)
    expect('sos [48656c6c6f]')

    -- SOS ST (8bit)
    push('\x98Hello\x9c', vt)
    expect('sos [48656c6c6f]')

    push('\x1bXABC\x01DEF\x1b\\', vt)
    expect('sos [41424301444546]')
    push('\x1bXABC\x99DEF\x1b\\', vt)
    expect('sos [41424399444546]')

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

  pending('03encoding_utf8', function() end)

  itp('10state_putglyph', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, true)
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
    push('e' .. string.rep('\xCC\x81', 10), vt)
    expect('putglyph 65,301,301,301,301,301 1 0,0') -- and nothing more

    reset(state, nil)
    push('e', vt)
    expect('putglyph 65 1 0,0')
    push('\xCC\x81', vt)
    expect('putglyph 65,301 1 0,0')
    push('\xCC\x82', vt)
    expect('putglyph 65,301,302 1 0,0')

    -- DECSCA protected
    reset(state, nil)
    push('A\x1b[1"qB\x1b[2"qC', vt)
    expect('putglyph 41 1 0,0\nputglyph 42 1 0,1 prot\nputglyph 43 1 0,2')
  end)

  itp('11state_movecursor', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, true)
    local state = wantstate(vt, {})

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

    -- Cursor Horizonal Absolute
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
    vterm.vterm_set_utf8(vt, true)
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

    -- TODO(dundargoc): fix or remove
    -- -- DECRQSS on DECSTBM
    -- push "\x1bP\$qr\x1b\\"
    --   output "\x1bP1\$r3;10r\x1b\\"

    -- TODO(dundargoc): fix or remove
    -- -- DECRQSS on DECSLRM
    -- push "\x1bP\$qs\x1b\\"
    --   output "\x1bP1\$r10;40s\x1b\\"

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
    vterm.vterm_set_utf8(vt, true)
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
    -- TODO: ECMA-48 says we should move to line home, but neither xterm nor xfce4-terminal do this
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

    -- TODO(dundargoc): fix or remove
    -- -- DECRQSS on DECSCA
    -- push "\x1b[2\"q"
    -- push "\x1bP\$q\"q\x1b\\"
    --   output "\x1bP1\$r2\"q\x1b\\"

    state = wantstate(vt, { m = true, e = true, b = true })
    expect('erase 0..25,0..80') -- NOTE(dundargoc): strange, this should not be needed according to the original code

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
    local state = wantstate(vt, { g = true })

    -- Default
    reset(state, nil)
    push('#', vt)
    expect('putglyph 23 1 0,0')

    -- Designate G0=UK
    reset(state, nil)
    push('\x1b(A', vt)
    push('#', vt)
    expect('putglyph a3 1 0,0')

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

    -- TODO(dundargoc): fix or remove
    -- Mixed US-ASCII and UTF-8
    -- U+0108 == c4 88
    -- reset(state,nil)
    -- push "\x1b(B"
    -- push "AB\xc4\x88D"
    --   putglyph 0041 1 0,0
    --   putglyph 0042 1 0,1
    --   putglyph 0108 1 0,2
    --   putglyph 0044 1 0,3
  end)

  itp('15state_mode', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, true)
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

    -- TODO(dundargoc): fix or remove
    -- -- DECRQM on DECOM
    -- push "\x1b[?6h"
    -- push "\x1b[?6\$p"
    --   output "\x1b[?6;1\$y"
    -- push "\x1b[?6l"
    -- push "\x1b[?6\$p"
    --   output "\x1b[?6;2\$y"

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

  pending('17state_mouse', function() end)
  pending('18state_termprops', function() end)
  pending('20state_wrapping', function() end)
  pending('21state_tabstops', function() end)
  pending('22state_save', function() end)
  pending('25state_input', function() end)
  pending('26state_query', function() end)
  pending('27state_reset', function() end)
  pending('28state_dbl_wh', function() end)

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
    expect('osc [27;536f6d657468696e67]')

    -- Unrecognised DCS
    push('\x1bPz123\x1b\\', vt)
    expect('dcs [7a313233]')

    -- Unrecognised APC
    push('\x1b_z123\x1b\\', vt)
    expect('apc [7a313233]')

    -- Unrecognised PM
    push('\x1b^z123\x1b\\', vt)
    expect('pm [7a313233]')

    -- Unrecognised SOS
    push('\x1bXz123\x1b\\', vt)
    expect('sos [7a313233]')
  end)

  pending('30state_pen', function() end)

  itp('31state_rep', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, true)
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

  pending('32state_flow', function() end)

  pending('40state_selection', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, true)
    local _ = wantstate(vt, {})

    -- Set clipboard; final chunk len 4
    push('\x1b]52;c;SGVsbG8s\x1b\\', vt)
    expect('selection-set mask=0001 [48656c6c6f2c]')

    -- Set clipboard; final chunk len 3
    push('\x1b]52;c;SGVsbG8sIHc=\x1b\\', vt)
    expect('selection-set mask=0001 [48656c6c6f2c2077]')

    -- Set clipboard; final chunk len 2
    push('\x1b]52;c;SGVsbG8sIHdvcmxkCg==\x1b\\', vt)
    expect('selection-set mask=0001 [48656c6c6f2c20776f726c640a]')

    -- Set clipboard; split between chunks
    push('\x1b]52;c;SGVs', vt)
    expect('selection-set mask=0001 [48656c')
    push('bG8s\x1b\\', vt)
    expect('selection-set mask=0001 6c6f2c]')

    -- Set clipboard; split within chunk
    push('\x1b]52;c;SGVsbG', vt)
    expect('selection-set mask=0001 [48656c')
    push('8s\x1b\\', vt)
    expect('selection-set mask=0001 6c6f2c]')

    -- Set clipboard; empty first chunk
    push('\x1b]52;c;', vt)
    push('SGVsbG8s\x1b\\', vt)
    expect('selection-set mask=0001 [48656c6c6f2c]')

    -- Set clipboard; empty final chunk
    push('\x1b]52;c;SGVsbG8s', vt)
    expect('selection-set mask=0001 [48656c6c6f2c')
    push('\x1b\\', vt)
    expect('selection-set mask=0001 ]')

    -- Set clipboard; longer than buffer
    push('\x1b]52;c;' .. string.rep('LS0t', 10) .. '\x1b\\', vt)
    expect(
      'selection-set mask=0001 [2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d\nselection-set mask=0001 2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d]'
    )

    -- Clear clipboard
    push('\x1b]52;c;\x1b\\', vt)
    expect('selection-set mask=0001 []')

    -- Set invalid data clears and ignores
    push('\x1b]52;c;SGVs*SGVsbG8s\x1b\\', vt)
    expect('selection-set mask=0001 []')

    -- Query clipboard
    push('\x1b]52;c;?\x1b\\', vt)
    expect('selection-query mask=0001')

    -- -- Send clipboard; final chunk len 4
    -- SELECTION 1 ["Hello,"]
    --   output "\x1b]52;c;"
    --   output "SGVsbG8s"
    --   output "\x1b\\"
    --
    -- -- Send clipboard; final chunk len 3
    -- SELECTION 1 ["Hello, w"]
    --   output "\x1b]52;c;"
    --   output "SGVsbG8s"
    --   output "IHc=\x1b\\"
    --
    -- -- Send clipboard; final chunk len 2
    -- SELECTION 1 ["Hello, world\n"]
    --   output "\x1b]52;c;"
    --   output "SGVsbG8sIHdvcmxk"
    --   output "Cg==\x1b\\"
    --
    -- -- Send clipboard; split between chunks
    -- SELECTION 1 ["Hel"
    --   output "\x1b]52;c;"
    --   output "SGVs"
    -- SELECTION 1  "lo,"]
    --   output "bG8s"
    --   output "\x1b\\"
    --
    -- -- Send clipboard; split within chunk
    -- SELECTION 1 ["Hello"
    --   output "\x1b]52;c;"
    --   output "SGVs"
    -- SELECTION 1 ","]
    --   output "bG8s"
    --   output "\x1b\\"
  end)
  pending('60screen_ascii', function() end)
  pending('61screen_unicode', function() end)
  pending('62screen_damage', function() end)
  pending('63screen_resize', function() end)
  pending('64screen_pen', function() end)
  pending('65screen_protect', function() end)
  pending('66screen_extent', function() end)
  pending('67screen_dbl_wh', function() end)
  pending('68screen_termprops', function() end)
  pending('69screen_pushline', function() end)
  pending('69screen_reflow', function() end)
  pending('90vttest_01-movement-1', function() end)
  pending('90vttest_01-movement-2', function() end)
  pending('90vttest_01-movement-3', function() end)
  pending('90vttest_01-movement-4', function() end)
  pending('90vttest_02-screen-1', function() end)
  pending('90vttest_02-screen-2', function() end)
  pending('90vttest_02-screen-3', function() end)
  pending('90vttest_02-screen-4', function() end)
  pending('92lp1640917', function() end)
end)
