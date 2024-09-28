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

local function wantstate(vt, mode)
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
  -- state_cbs['sb_clear'] = vterm.state_sb_clear

  local selection_cbs = t.ffi.new('VTermSelectionCallbacks')
  selection_cbs['set'] = vterm.selection_set
  selection_cbs['query'] = vterm.selection_query

  vterm.vterm_state_set_callbacks(state, state_cbs, nil)

  -- In some tests we want to check the behaviour of overflowing the buffer, so make it nicely small
  vterm.vterm_state_set_selection_callbacks(state, selection_cbs, nil, nil, 16)
  vterm.vterm_state_set_bold_highbright(state, 1)
  vterm.vterm_state_reset(state, 1)

  local sense = true
  if mode == 'e' then
    vterm.want_state_erase = sense
  elseif mode == 'g' then
    vterm.want_state_putglyph = sense
  elseif mode == 'f' then
    local fallbacks = t.ffi.new('VTermStateFallbacks')
    fallbacks['control'] = vterm.parser_control
    fallbacks['csi'] = vterm.parser_csi
    fallbacks['osc'] = vterm.parser_osc
    fallbacks['dcs'] = vterm.parser_dcs
    fallbacks['apc'] = vterm.parser_apc
    fallbacks['pm'] = vterm.parser_pm
    fallbacks['sos'] = vterm.parser_sos
    vterm.vterm_state_set_unrecognised_fallbacks(state, sense and fallbacks or nil, nil)
  elseif mode == 'm' then
    vterm.want_state_moverect = sense
  elseif mode == 'p' then
    vterm.want_state_settermprop = sense
  elseif mode == 's' then
    vterm.want_state_scrollrect = sense
  end

  return state
end

local function reset(state, screen)
  if state then
    vterm.vterm_state_reset(state, 1)
    local state_pos = t.ffi.new('VTermPos')
    vterm.vterm_state_get_cursorpos(state, state_pos)
  end
  if screen then
    vterm.vterm_screen_reset(screen, 1)
  end
end

local function file_exists(name)
  local f = io.open(name, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function push(input, expected, vt, opts)
  if opts and opts.ignored then
    assert(not file_exists(test_output_file))
    return
  end

  vterm.vterm_input_write(vt, input, string.len(input))

  if not (opts and opts.split) then
    local f = assert(io.open(test_output_file, 'rb'))
    local actual = f:read('*a')
    f:close()

    vim.fs.rm(test_output_file)
    t.eq(expected .. '\n', actual)
  end
end

describe('vterm', function()
  itp('02parser', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, false)
    wantparser(vt)

    -- Basic text
    push('hello', 'text 68,65,6c,6c,6f', vt)

    -- C0
    push('\x03', 'control 03', vt)
    push('\x1f', 'control 1f', vt)

    -- C1 8bit
    push('\x83', 'control 83', vt)
    push('\x99', 'control 99', vt)

    -- C1 7bit
    push('\x1b\x43', 'control 83', vt)
    push('\x1b\x59', 'control 99', vt)

    -- High bytes
    push('\xa0\xcc\xfe', 'text a0,cc,fe', vt)

    -- Mixed
    push('1\n2', 'text 31\ncontrol 0a\ntext 32', vt)

    -- Escape
    push('\x1b=', 'escape 3d', vt)

    -- Escape 2-byte
    push('\x1b(X', 'escape 2858', vt)

    -- Split write Escape
    push('\x1b(', '', vt, { split = true })
    push('Y', 'escape 2859', vt)

    -- Escape cancels Escape, starts another
    push('\x1b(\x1b)Z', 'escape 295a', vt)

    -- CAN cancels Escape, returns to normal mode
    push('\x1b(\x18AB', 'text 41,42', vt)

    -- C0 in Escape interrupts and continues
    push('\x1b(\nX', 'control 0a\nescape 2858', vt)

    -- CSI 0 args
    push('\x1b[a', 'csi 61 *', vt)

    -- CSI 1 arg
    push('\x1b[9b', 'csi 62 9', vt)

    -- CSI 2 args
    push('\x1b[3;4c', 'csi 63 3,4', vt)

    -- CSI 1 arg 1 sub
    push('\x1b[1:2c', 'csi 63 1+,2', vt)

    -- CSI many digits
    push('\x1b[678d', 'csi 64 678', vt)

    -- CSI leading zero
    push('\x1b[007e', 'csi 65 7', vt)

    -- CSI qmark
    push('\x1b[?2;7f', 'csi 66 L=3f 2,7', vt)

    -- CSI greater
    push('\x1b[>c', 'csi 63 L=3e *', vt)

    -- CSI SP
    push('\x1b[12 q', 'csi 71 12 I=20', vt)

    -- Mixed CSI
    push('A\x1b[8mB', 'text 41\ncsi 6d 8\ntext 42', vt)

    -- Split write
    push('\x1b', '', vt, { split = true })
    push('[a', 'csi 61 *', vt)
    push('foo\x1b[', 'text 66,6f,6f', vt)
    push('4b', 'csi 62 4', vt)
    push('\x1b[12;', '', vt, { split = true })
    push('3c', 'csi 63 12,3', vt)

    -- Escape cancels CSI, starts Escape
    push('\x1b[123\x1b9', 'escape 39', vt)

    -- CAN cancels CSI, returns to normal mode
    push('\x1b[12\x18AB', 'text 41,42', vt)

    -- C0 in Escape interrupts and continues
    -- push( "\x1b[12\n;3X", "control 0a\ncsi 58 12,3 ", vt)

    -- OSC BEL
    push('\x1b]1;Hello\x07', 'osc [1;48656c6c6f]', vt)

    -- OSC ST (7bit)
    push('\x1b]1;Hello\x1b\\', 'osc [1;48656c6c6f]', vt)

    -- OSC ST (8bit)
    push('\x9d1;Hello\x9c', 'osc [1;48656c6c6f]', vt)

    -- OSC in parts
    push('\x1b]52;abc', 'osc [52;616263', vt)
    push('def', 'osc 646566', vt)
    push('ghi\x1b\\', 'osc 676869]', vt)

    -- OSC BEL without semicolon
    push('\x1b]1234\x07', 'osc [1234;]', vt)

    -- OSC ST without semicolon
    push('\x1b]1234\x1b\\', 'osc [1234;]', vt)

    -- Escape cancels OSC, starts Escape
    push('\x1b]Something\x1b9', 'escape 39', vt)

    -- CAN cancels OSC, returns to normal mode
    push('\x1b]12\x18AB', 'text 41,42', vt)

    -- C0 in OSC interrupts and continues
    push('\x1b]2;\nBye\x07', 'osc [2;\ncontrol 0a\nosc 427965]', vt)

    -- DCS BEL
    push('\x1bPHello\x07', 'dcs [48656c6c6f]', vt)

    -- DCS ST (7bit)
    push('\x1bPHello\x1b\\', 'dcs [48656c6c6f]', vt)

    -- DCS ST (8bit)
    push('\x90Hello\x9c', 'dcs [48656c6c6f]', vt)

    -- Split write of 7bit ST
    push('\x1bPABC\x1b', 'dcs [414243', vt)
    push('\\', 'dcs ]', vt)

    -- Escape cancels DCS, starts Escape
    push('\x1bPSomething\x1b9', 'escape 39', vt)

    -- CAN cancels DCS, returns to normal mode
    push('\x1bP12\x18AB', 'text 41,42', vt)

    -- C0 in OSC interrupts and continues
    push('\x1bPBy\ne\x07', 'dcs [4279\ncontrol 0a\ndcs 65]', vt)

    -- APC BEL
    push('\x1b_Hello\x07', 'apc [48656c6c6f]', vt)

    -- APC ST (7bit)
    push('\x1b_Hello\x1b\\', 'apc [48656c6c6f]', vt)

    -- APC ST (8bit)
    push('\x9fHello\x9c', 'apc [48656c6c6f]', vt)

    -- PM BEL
    push('\x1b^Hello\x07', 'pm [48656c6c6f]', vt)

    -- PM ST (7bit)
    push('\x1b^Hello\x1b\\', 'pm [48656c6c6f]', vt)

    -- PM ST (8bit)
    push('\x9eHello\x9c', 'pm [48656c6c6f]', vt)

    -- SOS BEL
    push('\x1bXHello\x07', 'sos [48656c6c6f]', vt)

    -- SOS ST (7bit)
    push('\x1bXHello\x1b\\', 'sos [48656c6c6f]', vt)

    -- SOS ST (8bit)
    push('\x98Hello\x9c', 'sos [48656c6c6f]', vt)

    push('\x1bXABC\x01DEF\x1b\\', 'sos [41424301444546]', vt)
    push('\x1bXABC\x99DEF\x1b\\', 'sos [41424399444546]', vt)

    -- NUL ignored
    push('\x00', '', vt, { ignored = true })

    -- NUL ignored within CSI
    push('\x1b[12\x003m', 'csi 6d 123', vt)

    -- DEL ignored
    push('\x7f', '', vt, { ignored = true })

    -- DEL ignored within CSI
    push('\x1b[12\x7f3m', 'csi 6d 123', vt)

    -- DEL inside text"
    push('AB\x7fC', 'text 41,42\ntext 43', vt)

    -- local outlen = vterm.vterm_output_get_buffer_current(vt)
  end)

  pending('03encoding_utf8', function() end)

  itp('10state_putglyph', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, true)
    local state = wantstate(vt, 'g')

    -- Low
    reset(state, nil)
    push('ABC', 'putglyph 41 1 0,0\nputglyph 42 1 0,1\nputglyph 43 1 0,2', vt)

    -- UTF-8 1 char
    -- U+00C1 = 0xC3 0x81  name: LATIN CAPITAL LETTER A WITH ACUTE
    -- U+00E9 = 0xC3 0xA9  name: LATIN SMALL LETTER E WITH ACUTE
    reset(state, nil)
    push('\xC3\x81\xC3\xA9', 'putglyph c1 1 0,0\nputglyph e9 1 0,1', vt)

    -- UTF-8 split writes
    reset(state, nil)
    push('\xC3', '', vt, { split = true })
    push('\x81', 'putglyph c1 1 0,0', vt)

    -- UTF-8 wide char
    -- U+FF10 = EF BC 90  name: FULLWIDTH DIGIT ZERO
    reset(state, nil)
    push('\xEF\xBC\x90 ', 'putglyph ff10 2 0,0\nputglyph 20 1 0,2', vt)

    -- UTF-8 emoji wide char
    -- U+1F600 = F0 9F 98 80  name: GRINNING FACE
    reset(state, nil)
    push('\xF0\x9F\x98\x80 ', 'putglyph 1f600 2 0,0\nputglyph 20 1 0,2', vt)

    -- UTF-8 combining chars
    -- U+0301 = CC 81  name: COMBINING ACUTE
    reset(state, nil)
    push('e\xCC\x81Z', 'putglyph 65,301 1 0,0\nputglyph 5a 1 0,1', vt)

    -- Combining across buffers
    reset(state, nil)
    push('e', 'putglyph 65 1 0,0', vt)
    push('\xCC\x81Z', 'putglyph 65,301 1 0,0\nputglyph 5a 1 0,1', vt)

    -- Spare combining chars get truncated
    reset(state, nil)
    push('e' .. string.rep('\xCC\x81', 10), 'putglyph 65,301,301,301,301,301 1 0,0', vt) -- and nothing more

    reset(state, nil)
    push('e', 'putglyph 65 1 0,0', vt)
    push('\xCC\x81', 'putglyph 65,301 1 0,0', vt)
    push('\xCC\x82', 'putglyph 65,301,302 1 0,0', vt)

    -- DECSCA protected
    reset(state, nil)
    push('A\x1b[1"qB\x1b[2"qC', 'putglyph 41 1 0,0\nputglyph 42 1 0,1 prot\nputglyph 43 1 0,2', vt)
  end)

  pending('11state_movecursor', function() end)
  pending('12state_scroll', function() end)
  pending('13state_edit', function() end)

  itp('14state_encoding', function()
    local vt = init()
    local state = wantstate(vt, 'g')

    -- Default
    reset(state, nil)
    push('#', 'putglyph 23 1 0,0', vt)

    -- Designate G0=UK
    -- reset(state,nil)
    -- push("\x1b(A", nil, vt, {split =true})
    -- push("##", 'putglyph a3 1 0,0', vt)

    -- Designate G0=DEC drawing
    reset(state, nil)
    push('\x1b(0', nil, vt, { split = true })
    push('a', 'putglyph 2592 1 0,0', vt)

    -- Designate G1 + LS1
    reset(state, nil)
    push('\x1b)0', nil, vt, { split = true })
    push('a', 'putglyph 61 1 0,0', vt)
    push('\x0e', nil, vt, { split = true })
    push('a', 'putglyph 2592 1 0,1', vt)
    -- LS0
    push('\x0f', nil, vt, { split = true })
    push('a', 'putglyph 61 1 0,2', vt)

    -- Designate G2 + LS2
    push('\x1b*0', nil, vt, { split = true })
    push('a', 'putglyph 61 1 0,3', vt)
    push('\x1bn', nil, vt, { split = true })
    push('a', 'putglyph 2592 1 0,4', vt)
    push('\x0f', nil, vt, { split = true })
    push('a', 'putglyph 61 1 0,5', vt)

    -- Designate G3 + LS3
    push('\x1b+0', nil, vt, { split = true })
    push('a', 'putglyph 61 1 0,6', vt)
    push('\x1bo', nil, vt, { split = true })
    push('a', 'putglyph 2592 1 0,7', vt)
    push('\x0f', nil, vt, { split = true })
    push('a', 'putglyph 61 1 0,8', vt)

    -- SS2
    push('a\x8eaa', 'putglyph 61 1 0,9\nputglyph 2592 1 0,10\nputglyph 61 1 0,11', vt)

    -- SS3
    push('a\x8faa', 'putglyph 61 1 0,12\nputglyph 2592 1 0,13\nputglyph 61 1 0,14', vt)

    -- LS1R
    reset(state, nil)
    push('\x1b~', nil, vt, { split = true })
    push('\xe1', 'putglyph 61 1 0,0', vt)
    push('\x1b)0', nil, vt, { split = true })
    push('\xe1', 'putglyph 2592 1 0,1', vt)

    -- LS2R
    reset(state, nil)
    push('\x1b}', nil, vt, { split = true })
    push('\xe1', 'putglyph 61 1 0,0', vt)
    push('\x1b*0', nil, vt, { split = true })
    push('\xe1', 'putglyph 2592 1 0,1', vt)

    -- LS3R
    reset(state, nil)
    push('\x1b|', nil, vt, { split = true })
    push('\xe1', 'putglyph 61 1 0,0', vt)
    push('\x1b+0', nil, vt, { split = true })
    push('\xe1', 'putglyph 2592 1 0,1', vt)

    -- Mixed US-ASCII and UTF-8
    -- U+0108 == 0xc4 88
    -- reset(state,nil)
    -- push( "\x1b(B", nil, vt, {split = true})
    -- push( "AB\xc4\x88D", 'putglyph 41 1 0,0\nputglyph 42 1 0,1\nputglyph 0108 1 0,2\nputglyph 44 1 0,3', vt)
  end)

  pending('15state_mode', function() end)
  pending('16state_resize', function() end)
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
    local state = wantstate(vt, 'f')
    reset(state, nil)

    -- Unrecognised control
    push('\x03', 'control 03', vt)

    -- Unrecognised CSI
    push('\x1b[?15;2z', 'csi 7a L=3f 15,2', vt)

    -- Unrecognised OSC
    push('\x1b]27;Something\x1b\\', 'osc [27;536f6d657468696e67]', vt)

    -- Unrecognised DCS
    push('\x1bPz123\x1b\\', 'dcs [7a313233]', vt)

    -- Unrecognised APC
    push('\x1b_z123\x1b\\', 'apc [7a313233]', vt)

    -- Unrecognised PM
    push('\x1b^z123\x1b\\', 'pm [7a313233]', vt)

    -- Unrecognised SOS
    push('\x1bXz123\x1b\\', 'sos [7a313233]', vt)
  end)

  pending('30state_pen', function() end)

  itp('31state_rep', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, true)
    local state = wantstate(vt, 'g')

    -- REP no argument
    reset(state, nil)
    push('a\x1b[b', 'putglyph 61 1 0,0\nputglyph 61 1 0,1', vt)

    -- REP zero (zero should be interpreted as one)
    reset(state, nil)
    push('a\x1b[0b', 'putglyph 61 1 0,0\nputglyph 61 1 0,1', vt)

    -- REP lowercase a times two
    reset(state, nil)
    push('a\x1b[2b', 'putglyph 61 1 0,0\nputglyph 61 1 0,1\nputglyph 61 1 0,2', vt)

    -- REP with UTF-8 1 char
    -- U+00E9 = C3 A9  name: LATIN SMALL LETTER E WITH ACUTE
    reset(state, nil)
    push('\xC3\xA9\x1b[b', 'putglyph e9 1 0,0\nputglyph e9 1 0,1', vt)

    -- REP with UTF-8 wide char
    -- U+00E9 = C3 A9  name: LATIN SMALL LETTER E WITH ACUTE
    reset(state, nil)
    push('\xEF\xBC\x90\x1b[b', 'putglyph ff10 2 0,0\nputglyph ff10 2 0,2', vt)

    -- REP with UTF-8 combining character
    reset(state, nil)
    push('e\xCC\x81\x1b[b', 'putglyph 65,301 1 0,0\nputglyph 65,301 1 0,1', vt)

    -- REP till end of line
    reset(state, nil)
    push(
      'a\x1b[1000bb',
      'putglyph 61 1 0,0\nputglyph 61 1 0,1\nputglyph 61 1 0,2\nputglyph 61 1 0,3\nputglyph 61 1 0,4\nputglyph 61 1 0,5\nputglyph 61 1 0,6\nputglyph 61 1 0,7\nputglyph 61 1 0,8\nputglyph 61 1 0,9\nputglyph 61 1 0,10\nputglyph 61 1 0,11\nputglyph 61 1 0,12\nputglyph 61 1 0,13\nputglyph 61 1 0,14\nputglyph 61 1 0,15\nputglyph 61 1 0,16\nputglyph 61 1 0,17\nputglyph 61 1 0,18\nputglyph 61 1 0,19\nputglyph 61 1 0,20\nputglyph 61 1 0,21\nputglyph 61 1 0,22\nputglyph 61 1 0,23\nputglyph 61 1 0,24\nputglyph 61 1 0,25\nputglyph 61 1 0,26\nputglyph 61 1 0,27\nputglyph 61 1 0,28\nputglyph 61 1 0,29\nputglyph 61 1 0,30\nputglyph 61 1 0,31\nputglyph 61 1 0,32\nputglyph 61 1 0,33\nputglyph 61 1 0,34\nputglyph 61 1 0,35\nputglyph 61 1 0,36\nputglyph 61 1 0,37\nputglyph 61 1 0,38\nputglyph 61 1 0,39\nputglyph 61 1 0,40\nputglyph 61 1 0,41\nputglyph 61 1 0,42\nputglyph 61 1 0,43\nputglyph 61 1 0,44\nputglyph 61 1 0,45\nputglyph 61 1 0,46\nputglyph 61 1 0,47\nputglyph 61 1 0,48\nputglyph 61 1 0,49\nputglyph 61 1 0,50\nputglyph 61 1 0,51\nputglyph 61 1 0,52\nputglyph 61 1 0,53\nputglyph 61 1 0,54\nputglyph 61 1 0,55\nputglyph 61 1 0,56\nputglyph 61 1 0,57\nputglyph 61 1 0,58\nputglyph 61 1 0,59\nputglyph 61 1 0,60\nputglyph 61 1 0,61\nputglyph 61 1 0,62\nputglyph 61 1 0,63\nputglyph 61 1 0,64\nputglyph 61 1 0,65\nputglyph 61 1 0,66\nputglyph 61 1 0,67\nputglyph 61 1 0,68\nputglyph 61 1 0,69\nputglyph 61 1 0,70\nputglyph 61 1 0,71\nputglyph 61 1 0,72\nputglyph 61 1 0,73\nputglyph 61 1 0,74\nputglyph 61 1 0,75\nputglyph 61 1 0,76\nputglyph 61 1 0,77\nputglyph 61 1 0,78\nputglyph 61 1 0,79\nputglyph 62 1 1,0',
      vt
    )
  end)

  pending('32state_flow', function() end)

  pending('40state_selection', function()
    local vt = init()
    vterm.vterm_set_utf8(vt, true)
    local _ = wantstate(vt, '')

    -- Set clipboard; final chunk len 4
    push('\x1b]52;c;SGVsbG8s\x1b\\', 'selection-set mask=0001 [48656c6c6f2c]', vt)

    -- Set clipboard; final chunk len 3
    push('\x1b]52;c;SGVsbG8sIHc=\x1b\\', 'selection-set mask=0001 [48656c6c6f2c2077]', vt)

    -- Set clipboard; final chunk len 2
    push(
      '\x1b]52;c;SGVsbG8sIHdvcmxkCg==\x1b\\',
      'selection-set mask=0001 [48656c6c6f2c20776f726c640a]',
      vt
    )

    -- Set clipboard; split between chunks
    push('\x1b]52;c;SGVs', 'selection-set mask=0001 [48656c', vt)
    push('bG8s\x1b\\', 'selection-set mask=0001 6c6f2c]', vt)

    -- Set clipboard; split within chunk
    push('\x1b]52;c;SGVsbG', 'selection-set mask=0001 [48656c', vt)
    push('8s\x1b\\', 'selection-set mask=0001 6c6f2c]', vt)

    -- Set clipboard; empty first chunk
    push('\x1b]52;c;', nil, vt, { split = true })
    push('SGVsbG8s\x1b\\', 'selection-set mask=0001 [48656c6c6f2c]', vt)

    -- Set clipboard; empty final chunk
    push('\x1b]52;c;SGVsbG8s', 'selection-set mask=0001 [48656c6c6f2c', vt)
    push('\x1b\\', 'selection-set mask=0001 ]', vt)

    -- Set clipboard; longer than buffer
    push(
      '\x1b]52;c;' .. string.rep('LS0t', 10) .. '\x1b\\',
      'selection-set mask=0001 [2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d\nselection-set mask=0001 2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d]',
      vt
    )

    -- Clear clipboard
    push('\x1b]52;c;\x1b\\', 'selection-set mask=0001 []', vt)

    -- Set invalid data clears and ignores
    push('\x1b]52;c;SGVs*SGVsbG8s\x1b\\', 'selection-set mask=0001 []', vt)

    -- Query clipboard
    push('\x1b]52;c;?\x1b\\', 'selection-query mask=0001', vt)

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
