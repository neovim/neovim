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
  pending('10state_putglyph', function() end)
  pending('11state_movecursor', function() end)
  pending('12state_scroll', function() end)
  pending('13state_edit', function() end)
  pending('14state_encoding', function() end)
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
  pending('29state_fallback', function() end)
  pending('30state_pen', function() end)
  pending('31state_rep', function() end)
  pending('32state_flow', function() end)
  pending('40state_selection', function() end)
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
