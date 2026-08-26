local t = require('test.unit.testutil')
local describe = t.describe
local itp = t.gen_itp(t.it)
local bit = require('bit')

--- @alias TermKeyKey {utf8: string, type: integer, modifiers: integer, code: {codepoint: integer, sym: any, number: integer}}

--- @class termkey
--- @field TERMKEY_CANON_SPACESYMBOL integer
--- @field TERMKEY_FLAG_SPACESYMBOL integer
--- @field TERMKEY_FLAG_UTF8 integer
--- @field TERMKEY_FORMAT_ALTISMETA integer
--- @field TERMKEY_FORMAT_CARETCTRL integer
--- @field TERMKEY_FORMAT_LONGMOD integer
--- @field TERMKEY_FORMAT_LOWERMOD integer
--- @field TERMKEY_FORMAT_LOWERSPACE integer
--- @field TERMKEY_FORMAT_MOUSE_POS integer
--- @field TERMKEY_FORMAT_SPACEMOD integer
--- @field TERMKEY_FORMAT_WRAPBRACKET integer
--- @field TERMKEY_KEYMOD_ALT integer
--- @field TERMKEY_KEYMOD_CTRL integer
--- @field TERMKEY_MOUSE_DRAG integer
--- @field TERMKEY_MOUSE_PRESS integer
--- @field TERMKEY_MOUSE_RELEASE integer
--- @field TERMKEY_RES_AGAIN integer
--- @field TERMKEY_RES_KEY integer
--- @field TERMKEY_RES_NONE integer
--- @field TERMKEY_SYM_DOWN integer
--- @field TERMKEY_SYM_PAGEUP integer
--- @field TERMKEY_SYM_SPACE integer
--- @field TERMKEY_SYM_UNKNOWN integer
--- @field TERMKEY_SYM_UP integer
--- @field TERMKEY_TYPE_DCS integer
--- @field TERMKEY_TYPE_FUNCTION integer
--- @field TERMKEY_TYPE_KEYSYM integer
--- @field TERMKEY_TYPE_MODEREPORT integer
--- @field TERMKEY_TYPE_MOUSE integer
--- @field TERMKEY_TYPE_OSC integer
--- @field TERMKEY_TYPE_POSITION integer
--- @field TERMKEY_TYPE_UNICODE integer
--- @field TERMKEY_TYPE_UNKNOWN_CSI integer
--- @field termkey_canonicalise fun(any, any):any
--- @field termkey_destroy fun(any)
--- @field termkey_get_buffer_remaining fun(any):integer
--- @field termkey_get_buffer_size fun(any):integer
--- @field termkey_get_canonflags fun(any):any
--- @field termkey_get_keyname fun(any, any):any
--- @field termkey_getkey fun(any, any):any
--- @field termkey_getkey_force fun(any, any):any
--- @field termkey_interpret_csi fun(any, any, any, any, any):any
--- @field termkey_interpret_modereport fun(any, any, any, any, any):any
--- @field termkey_interpret_mouse fun(any, any, TermKeyKey, integer, integer, integer):any
--- @field termkey_interpret_position fun(any, any, any, any):any
--- @field termkey_interpret_string fun(any, TermKeyKey, any):any
--- @field termkey_lookup_keyname fun(any, any, any):any
--- @field termkey_new_abstract fun(string, integer):any
--- @field termkey_push_bytes fun(any, string, integer):integer
--- @field termkey_set_buffer_size fun(any, integer):integer
--- @field termkey_set_canonflags fun(any, any):any
--- @field termkey_set_flags fun(any, integer)
--- @field termkey_start fun(any):integer
--- @field termkey_stop fun(any):integer
--- @field termkey_strfkey fun(any, string, integer, any, any):integer
local termkey = t.cimport(
  './src/nvim/tui/termkey/termkey.h',
  './src/nvim/tui/termkey/termkey-internal.h',
  './src/nvim/tui/termkey/termkey_defs.h',
  './src/nvim/tui/termkey/driver-csi.h'
)

describe('termkey', function()
  itp('01base', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    t.neq(nil, tk)

    t.eq(256, termkey.termkey_get_buffer_size(tk))
    t.eq(1, tk.is_started) -- tk->is_started true after construction

    termkey.termkey_stop(tk)
    t.neq(1, tk.is_started) -- tk->is_started false after termkey_stop()

    termkey.termkey_start(tk)
    t.eq(1, tk.is_started) -- tk->is_started true after termkey_start()

    termkey.termkey_destroy(tk)
  end)

  itp('02getkey', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    t.eq(256, termkey.termkey_get_buffer_remaining(tk)) -- buffer free initially 256

    t.eq(termkey.TERMKEY_RES_NONE, termkey.termkey_getkey(tk, key)) -- getkey yields RES_NONE when empty

    t.eq(1, termkey.termkey_push_bytes(tk, 'h', 1)) -- push_bytes returns 1

    t.eq(255, termkey.termkey_get_buffer_remaining(tk)) -- buffer free 255 after push_bytes

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY after h

    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type after h
    t.eq(string.byte('h'), key.code.codepoint) -- key.code.codepoint after h
    t.eq(0, key.modifiers) -- key.modifiers after h
    t.eq('h', t.ffi.string(key.utf8)) -- key.utf8 after h

    t.eq(256, termkey.termkey_get_buffer_remaining(tk)) -- buffer free 256 after getkey

    t.eq(termkey.TERMKEY_RES_NONE, termkey.termkey_getkey(tk, key)) -- getkey yields RES_NONE a second time

    termkey.termkey_push_bytes(tk, '\x01', 1)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY after C-a

    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type after C-a
    t.eq(string.byte('a'), key.code.codepoint) -- key.code.codepoint after C-a
    t.eq(termkey.TERMKEY_KEYMOD_CTRL, key.modifiers) -- key.modifiers after C-a

    termkey.termkey_push_bytes(tk, '\033OA', 3)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY after Up

    -- is_int(key.type,        TERMKEY_TYPE_KEYSYM,  "key.type after Up");
    -- is_int(key.code.sym,    TERMKEY_SYM_UP,       "key.code.sym after Up");
    t.eq(0, key.modifiers) -- key.modifiers after Up

    t.eq(2, termkey.termkey_push_bytes(tk, '\033O', 2)) -- push_bytes returns 2

    -- is_int(termkey_get_buffer_remaining(tk), 254, "buffer free 254 after partial write");

    -- is_int(termkey_getkey(tk, &key), TERMKEY_RES_AGAIN, "getkey yields RES_AGAIN after partial write");

    termkey.termkey_push_bytes(tk, 'C', 1)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY after Right completion

    -- is_int(key.type,        TERMKEY_TYPE_KEYSYM,  "key.type after Right");
    -- is_int(key.code.sym,    TERMKEY_SYM_RIGHT,    "key.code.sym after Right");
    -- is_int(key.modifiers,   0,                    "key.modifiers after Right");

    -- is_int(termkey_get_buffer_remaining(tk), 256, "buffer free 256 after completion");

    termkey.termkey_push_bytes(tk, '\033[27;5u', 7)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY after Ctrl-Escape

    -- is_int(key.type,        TERMKEY_TYPE_KEYSYM, "key.type after Ctrl-Escape");
    -- is_int(key.code.sym,    TERMKEY_SYM_ESCAPE,  "key.code.sym after Ctrl-Escape");
    -- is_int(key.modifiers,   TERMKEY_KEYMOD_CTRL, "key.modifiers after Ctrl-Escape");

    termkey.termkey_push_bytes(tk, '\0', 1)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY after Ctrl-Space

    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type after Ctrl-Space
    -- t.eq(string.byte(' '), key.code.codepoint) -- key.code.codepoint after Ctrl-Space
    -- is_int(key.modifiers,      TERMKEY_KEYMOD_CTRL,  "key.modifiers after Ctrl-Space");

    termkey.termkey_destroy(tk)
  end)

  itp('03utf8', function()
    local tk = termkey.termkey_new_abstract(nil, termkey.TERMKEY_FLAG_UTF8)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    termkey.termkey_push_bytes(tk, 'a', 1)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY low ASCII
    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type low ASCII
    t.eq(string.byte('a'), key.code.codepoint) -- key.code.codepoint low ASCII

    -- 2-byte UTF-8 range is U+0080 to U+07FF (0xDF 0xBF)
    -- However, we'd best avoid the C1 range, so we'll start at U+00A0 (0xC2 0xA0)

    termkey.termkey_push_bytes(tk, '\xC2\xA0', 2)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 2 low
    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type UTF-8 2 low
    t.eq(0x00A0, key.code.codepoint) -- key.code.codepoint UTF-8 2 low

    termkey.termkey_push_bytes(tk, '\xDF\xBF', 2)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 2 high
    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type UTF-8 2 high
    t.eq(0x07FF, key.code.codepoint) -- key.code.codepoint UTF-8 2 high

    -- 3-byte UTF-8 range is U+0800 (0xE0 0xA0 0x80) to U+FFFD (0xEF 0xBF 0xBD)

    termkey.termkey_push_bytes(tk, '\xE0\xA0\x80', 3)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 3 low
    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type UTF-8 3 low
    t.eq(0x0800, key.code.codepoint) -- key.code.codepoint UTF-8 3 low

    termkey.termkey_push_bytes(tk, '\xEF\xBF\xBD', 3)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 3 high
    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type UTF-8 3 high
    t.eq(0xFFFD, key.code.codepoint) -- key.code.codepoint UTF-8 3 high

    -- 4-byte UTF-8 range is U+10000 (0xF0 0x90 0x80 0x80) to U+10FFFF (0xF4 0x8F 0xBF 0xBF)

    termkey.termkey_push_bytes(tk, '\xF0\x90\x80\x80', 4)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 low
    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type UTF-8 4 low
    t.eq(0x10000, key.code.codepoint) -- key.code.codepoint UTF-8 4 low

    termkey.termkey_push_bytes(tk, '\xF4\x8F\xBF\xBF', 4)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 high
    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type UTF-8 4 high
    t.eq(0x10FFFF, key.code.codepoint) -- key.code.codepoint UTF-8 4 high

    -- Invalid continuations

    termkey.termkey_push_bytes(tk, '\xC2!', 2)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 2 invalid cont
    t.eq(0xFFFD, key.code.codepoint) -- key.code.codepoint UTF-8 2 invalid cont
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 2 invalid after
    t.eq(string.byte('!'), key.code.codepoint) -- key.code.codepoint UTF-8 2 invalid after

    termkey.termkey_push_bytes(tk, '\xE0!', 2)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 3 invalid cont
    t.eq(0xFFFD, key.code.codepoint) -- key.code.codepoint UTF-8 3 invalid cont
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 3 invalid after
    t.eq(string.byte('!'), key.code.codepoint) -- key.code.codepoint UTF-8 3 invalid after

    termkey.termkey_push_bytes(tk, '\xE0\xA0!', 3)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 3 invalid cont 2
    t.eq(0xFFFD, key.code.codepoint) -- key.code.codepoint UTF-8 3 invalid cont 2
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 3 invalid after
    t.eq(string.byte('!'), key.code.codepoint) -- key.code.codepoint UTF-8 3 invalid after

    termkey.termkey_push_bytes(tk, '\xF0!', 2)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 invalid cont
    t.eq(0xFFFD, key.code.codepoint) -- key.code.codepoint UTF-8 4 invalid cont
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 invalid after
    t.eq(string.byte('!'), key.code.codepoint) -- key.code.codepoint UTF-8 4 invalid after

    termkey.termkey_push_bytes(tk, '\xF0\x90!', 3)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 invalid cont 2
    t.eq(0xFFFD, key.code.codepoint) -- key.code.codepoint UTF-8 4 invalid cont 2
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 invalid after
    t.eq(string.byte('!'), key.code.codepoint) -- key.code.codepoint UTF-8 4 invalid after

    termkey.termkey_push_bytes(tk, '\xF0\x90\x80!', 4)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 invalid cont 3
    t.eq(0xFFFD, key.code.codepoint) -- key.code.codepoint UTF-8 4 invalid cont 3
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 invalid after
    t.eq(string.byte('!'), key.code.codepoint) -- key.code.codepoint UTF-8 4 invalid after

    -- Partials

    termkey.termkey_push_bytes(tk, '\xC2', 1)
    t.eq(termkey.TERMKEY_RES_AGAIN, termkey.termkey_getkey(tk, key)) -- getkey yields RES_AGAIN UTF-8 2 partial

    termkey.termkey_push_bytes(tk, '\xA0', 1)
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 2 partial
    t.eq(0x00A0, key.code.codepoint) -- key.code.codepoint UTF-8 2 partial

    termkey.termkey_push_bytes(tk, '\xE0', 1)
    t.eq(termkey.TERMKEY_RES_AGAIN, termkey.termkey_getkey(tk, key)) -- getkey yields RES_AGAIN UTF-8 3 partial

    termkey.termkey_push_bytes(tk, '\xA0', 1)
    t.eq(termkey.TERMKEY_RES_AGAIN, termkey.termkey_getkey(tk, key)) -- getkey yields RES_AGAIN UTF-8 3 partial

    termkey.termkey_push_bytes(tk, '\x80', 1)
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 3 partial
    t.eq(0x0800, key.code.codepoint) -- key.code.codepoint UTF-8 3 partial

    termkey.termkey_push_bytes(tk, '\xF0', 1)
    t.eq(termkey.TERMKEY_RES_AGAIN, termkey.termkey_getkey(tk, key)) -- getkey yields RES_AGAIN UTF-8 4 partial

    termkey.termkey_push_bytes(tk, '\x90', 1)
    t.eq(termkey.TERMKEY_RES_AGAIN, termkey.termkey_getkey(tk, key)) -- getkey yields RES_AGAIN UTF-8 4 partial

    termkey.termkey_push_bytes(tk, '\x80', 1)
    t.eq(termkey.TERMKEY_RES_AGAIN, termkey.termkey_getkey(tk, key)) -- getkey yields RES_AGAIN UTF-8 4 partial

    termkey.termkey_push_bytes(tk, '\x80', 1)
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY UTF-8 4 partial
    t.eq(0x10000, key.code.codepoint) -- key.code.codepoint UTF-8 4 partial

    termkey.termkey_destroy(tk)
  end)

  itp('04flags', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    termkey.termkey_push_bytes(tk, ' ', 1)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY after space

    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type after space
    t.eq(string.byte(' '), key.code.codepoint) -- key.code.codepoint after space
    t.eq(0, key.modifiers) -- key.modifiers after space

    termkey.termkey_set_flags(tk, termkey.TERMKEY_FLAG_SPACESYMBOL)

    termkey.termkey_push_bytes(tk, ' ', 1)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY after space

    t.eq(termkey.TERMKEY_TYPE_KEYSYM, key.type) -- key.type after space with FLAG_SPACESYMBOL
    t.eq(termkey.TERMKEY_SYM_SPACE, key.code.sym) -- key.code.sym after space with FLAG_SPACESYMBOL
    t.eq(0, key.modifiers) -- key.modifiers after space with FLAG_SPACESYMBOL

    termkey.termkey_destroy(tk)
  end)

  itp('06buffer', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    t.eq(256, termkey.termkey_get_buffer_remaining(tk)) -- buffer free initially 256
    t.eq(256, termkey.termkey_get_buffer_size(tk)) -- buffer size initially 256

    t.eq(1, termkey.termkey_push_bytes(tk, 'h', 1)) -- push_bytes returns 1

    t.eq(255, termkey.termkey_get_buffer_remaining(tk)) -- buffer free 255 after push_bytes
    t.eq(256, termkey.termkey_get_buffer_size(tk)) -- buffer size 256 after push_bytes

    t.eq(true, not not termkey.termkey_set_buffer_size(tk, 512)) -- buffer set size OK

    t.eq(511, termkey.termkey_get_buffer_remaining(tk)) -- buffer free 511 after push_bytes
    t.eq(512, termkey.termkey_get_buffer_size(tk)) -- buffer size 512 after push_bytes

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- buffered key still usable after resize

    termkey.termkey_destroy(tk)
  end)

  local function termkey_keyname2sym(tk, keyname)
    local sym = t.ffi.new('TermKeySym[1]')
    local endp = termkey.termkey_lookup_keyname(tk, keyname, sym)
    if endp == nil then
      return termkey.TERMKEY_SYM_UNKNOWN
    end
    return sym
  end

  itp('10keyname', function()
    local tk = termkey.termkey_new_abstract(nil, 0)

    local sym = termkey_keyname2sym(tk, 'SomeUnknownKey')
    t.eq(termkey.TERMKEY_SYM_UNKNOWN, sym) -- keyname2sym SomeUnknownKey

    sym = termkey_keyname2sym(tk, 'Space')
    t.eq(termkey.TERMKEY_SYM_SPACE, sym[0]) -- keyname2sym Space

    local _end = termkey.termkey_lookup_keyname(tk, 'Up', sym)
    t.neq(nil, _end) -- termkey_get_keyname Up returns non-NULL
    t.eq('', t.ffi.string(_end)) -- termkey_get_keyname Up return points at endofstring
    t.eq(termkey.TERMKEY_SYM_UP, sym[0]) -- termkey_get_keyname Up yields Up symbol

    _end = termkey.termkey_lookup_keyname(tk, 'DownMore', sym)
    t.neq(nil, _end) -- termkey_get_keyname DownMore returns non-NULL
    t.eq('More', t.ffi.string(_end)) -- termkey_get_keyname DownMore return points at More
    t.eq(termkey.TERMKEY_SYM_DOWN, sym[0]) -- termkey_get_keyname DownMore yields Down symbol

    _end = termkey.termkey_lookup_keyname(tk, 'SomeUnknownKey', sym)
    t.eq(nil, _end) -- termkey_get_keyname SomeUnknownKey returns NULL

    t.eq('Space', t.ffi.string(termkey.termkey_get_keyname(tk, termkey.TERMKEY_SYM_SPACE))) -- "get_keyname SPACE");

    termkey.termkey_destroy(tk)
  end)

  itp('11strfkey', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    ---@type TermKeyKey
    local key = t.ffi.new(
      'TermKeyKey',
      { type = termkey.TERMKEY_TYPE_UNICODE, code = { codepoint = string.byte('A') } }
    )
    local buffer = t.ffi.new('char[16]')

    local len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(1, len) -- length for unicode/A/0
    t.eq('A', t.ffi.string(buffer)) -- buffer for unicode/A/0

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_WRAPBRACKET
    )
    t.eq(1, len) -- length for unicode/A/0 wrapbracket
    t.eq('A', t.ffi.string(buffer)) -- buffer for unicode/A/0 wrapbracket

    ---@type TermKeyKey
    key = t.ffi.new('TermKeyKey', {
      type = termkey.TERMKEY_TYPE_UNICODE,
      code = { codepoint = string.byte('b') },
      modifiers = termkey.TERMKEY_KEYMOD_CTRL,
    })

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(3, len) -- length for unicode/b/CTRL
    t.eq('C-b', t.ffi.string(buffer)) -- buffer for unicode/b/CTRL

    len =
      termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, termkey.TERMKEY_FORMAT_LONGMOD)
    t.eq(6, len) -- length for unicode/b/CTRL longmod
    t.eq('Ctrl-b', t.ffi.string(buffer)) -- buffer for unicode/b/CTRL longmod

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      bit.bor(termkey.TERMKEY_FORMAT_LONGMOD, termkey.TERMKEY_FORMAT_SPACEMOD)
    )
    t.eq(6, len) -- length for unicode/b/CTRL longmod|spacemod
    t.eq('Ctrl b', t.ffi.string(buffer)) -- buffer for unicode/b/CTRL longmod|spacemod

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      bit.bor(termkey.TERMKEY_FORMAT_LONGMOD, termkey.TERMKEY_FORMAT_LOWERMOD)
    )
    t.eq(6, len) -- length for unicode/b/CTRL longmod|lowermod
    t.eq('ctrl-b', t.ffi.string(buffer)) -- buffer for unicode/b/CTRL longmod|lowermod

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      bit.bor(
        termkey.TERMKEY_FORMAT_LONGMOD,
        termkey.TERMKEY_FORMAT_SPACEMOD,
        termkey.TERMKEY_FORMAT_LOWERMOD
      )
    )
    t.eq(6, len) -- length for unicode/b/CTRL longmod|spacemod|lowermode
    t.eq('ctrl b', t.ffi.string(buffer)) -- buffer for unicode/b/CTRL longmod|spacemod|lowermode

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_CARETCTRL
    )
    t.eq(2, len) -- length for unicode/b/CTRL caretctrl
    t.eq('^B', t.ffi.string(buffer)) -- buffer for unicode/b/CTRL caretctrl

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_WRAPBRACKET
    )
    t.eq(5, len) -- length for unicode/b/CTRL wrapbracket
    t.eq('<C-b>', t.ffi.string(buffer)) -- buffer for unicode/b/CTRL wrapbracket

    ---@type TermKeyKey
    key = t.ffi.new('TermKeyKey', {
      type = termkey.TERMKEY_TYPE_UNICODE,
      code = { codepoint = string.byte('c') },
      modifiers = termkey.TERMKEY_KEYMOD_ALT,
    })

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(3, len) -- length for unicode/c/ALT
    t.eq('A-c', t.ffi.string(buffer)) -- buffer for unicode/c/ALT

    len =
      termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, termkey.TERMKEY_FORMAT_LONGMOD)
    t.eq(5, len) -- length for unicode/c/ALT longmod
    t.eq('Alt-c', t.ffi.string(buffer)) -- buffer for unicode/c/ALT longmod

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_ALTISMETA
    )
    t.eq(3, len) -- length for unicode/c/ALT altismeta
    t.eq('M-c', t.ffi.string(buffer)) -- buffer for unicode/c/ALT altismeta

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      bit.bor(termkey.TERMKEY_FORMAT_LONGMOD, termkey.TERMKEY_FORMAT_ALTISMETA)
    )
    t.eq(6, len) -- length for unicode/c/ALT longmod|altismeta
    t.eq('Meta-c', t.ffi.string(buffer)) -- buffer for unicode/c/ALT longmod|altismeta

    ---@type TermKeyKey
    key = t.ffi.new(
      'TermKeyKey',
      { type = termkey.TERMKEY_TYPE_KEYSYM, code = { sym = termkey.TERMKEY_SYM_UP } }
    )

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(2, len) -- length for sym/Up/0
    t.eq('Up', t.ffi.string(buffer)) -- buffer for sym/Up/0

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_WRAPBRACKET
    )
    t.eq(4, len) -- length for sym/Up/0 wrapbracket
    t.eq('<Up>', t.ffi.string(buffer)) -- buffer for sym/Up/0 wrapbracket

    ---@type TermKeyKey
    key = t.ffi.new(
      'TermKeyKey',
      { type = termkey.TERMKEY_TYPE_KEYSYM, code = { sym = termkey.TERMKEY_SYM_PAGEUP } }
    )

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(6, len) -- length for sym/PageUp/0
    t.eq('PageUp', t.ffi.string(buffer)) -- buffer for sym/PageUp/0

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_LOWERSPACE
    )
    t.eq(7, len) -- length for sym/PageUp/0 lowerspace
    t.eq('page up', t.ffi.string(buffer)) -- buffer for sym/PageUp/0 lowerspace

    -- If size of buffer is too small, strfkey should return something consistent
    len = termkey.termkey_strfkey(tk, buffer, 4, key, 0)
    t.eq(6, len) -- length for sym/PageUp/0
    t.eq('Pag', t.ffi.string(buffer)) -- buffer of len 4 for sym/PageUp/0

    len = termkey.termkey_strfkey(tk, buffer, 4, key, termkey.TERMKEY_FORMAT_LOWERSPACE)
    t.eq(7, len) -- length for sym/PageUp/0 lowerspace
    t.eq('pag', t.ffi.string(buffer)) -- buffer of len 4 for sym/PageUp/0 lowerspace

    key = t.ffi.new('TermKeyKey', { type = termkey.TERMKEY_TYPE_FUNCTION, code = { number = 5 } }) ---@type TermKeyKey

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(2, len) -- length for func/5/0
    t.eq('F5', t.ffi.string(buffer)) -- buffer for func/5/0

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_WRAPBRACKET
    )
    t.eq(4, len) -- length for func/5/0 wrapbracket
    t.eq('<F5>', t.ffi.string(buffer)) -- buffer for func/5/0 wrapbracket

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_LOWERSPACE
    )
    t.eq(2, len) -- length for func/5/0 lowerspace
    t.eq('f5', t.ffi.string(buffer)) -- buffer for func/5/0 lowerspace

    termkey.termkey_destroy(tk)
  end)

  itp('13cmpkey', function()
    local function termkey_keycmp(tk, key1, key2)
      termkey.termkey_canonicalise(tk, key1)
      termkey.termkey_canonicalise(tk, key2)

      if key1.type ~= key2.type then
        return key1.type - key2.type
      end

      if key1.type == termkey.TERMKEY_TYPE_UNICODE then
        if key1.code.codepoint ~= key2.code.codepoint then
          return key1.code.codepoint - key2.code.codepoint
        end
      end

      return key1.modifiers - key2.modifiers
    end

    local tk = termkey.termkey_new_abstract(nil, 0)
    ---@type TermKeyKey
    local key1 = t.ffi.new('TermKeyKey', {
      type = termkey.TERMKEY_TYPE_UNICODE,
      code = { codepoint = string.byte('A') },
      modifiers = 0,
    })
    ---@type TermKeyKey
    local key2 = t.ffi.new('TermKeyKey', {
      type = termkey.TERMKEY_TYPE_UNICODE,
      code = { codepoint = string.byte('A') },
      modifiers = 0,
    })

    t.eq(0, termkey_keycmp(tk, key1, key1)) -- cmpkey same structure
    t.eq(0, termkey_keycmp(tk, key1, key2)) -- cmpkey identical structure

    key2.modifiers = termkey.TERMKEY_KEYMOD_CTRL

    t.eq(true, termkey_keycmp(tk, key1, key2) < 0) -- cmpkey orders CTRL after nomod
    t.eq(true, termkey_keycmp(tk, key2, key1) > 0) -- cmpkey orders nomod before CTRL

    key2.code.codepoint = string.byte('B')
    key2.modifiers = 0

    t.eq(true, termkey_keycmp(tk, key1, key2) < 0) -- cmpkey orders 'B' after 'A'
    t.eq(true, termkey_keycmp(tk, key2, key1) > 0) -- cmpkey orders 'A' before 'B'

    key1.modifiers = termkey.TERMKEY_KEYMOD_CTRL

    t.eq(true, termkey_keycmp(tk, key1, key2) < 0) -- cmpkey orders nomod 'B' after CTRL 'A'
    t.eq(true, termkey_keycmp(tk, key2, key1) > 0) -- cmpkey orders CTRL 'A' before nomod 'B'

    key2.type = termkey.TERMKEY_TYPE_KEYSYM
    key2.code.sym = termkey.TERMKEY_SYM_UP

    t.eq(true, termkey_keycmp(tk, key1, key2) < 0) -- cmpkey orders KEYSYM after UNICODE
    t.eq(true, termkey_keycmp(tk, key2, key1) > 0) -- cmpkey orders UNICODE before KEYSYM

    key1.type = termkey.TERMKEY_TYPE_KEYSYM
    key1.code.sym = termkey.TERMKEY_SYM_SPACE
    key1.modifiers = 0
    key2.type = termkey.TERMKEY_TYPE_UNICODE
    key2.code.codepoint = string.byte(' ')
    key2.modifiers = 0

    t.eq(0, termkey_keycmp(tk, key1, key2)) -- cmpkey considers KEYSYM/SPACE and UNICODE/SP identical

    termkey.termkey_set_canonflags(
      tk,
      bit.bor(termkey.termkey_get_canonflags(tk), termkey.TERMKEY_CANON_SPACESYMBOL)
    )
    t.eq(0, termkey_keycmp(tk, key1, key2)) -- "cmpkey considers KEYSYM/SPACE and UNICODE/SP identical under SPACESYMBOL");

    termkey.termkey_destroy(tk)
  end)

  itp('30mouse', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    local key = t.ffi.new('TermKeyKey', { type = -1 }) ---@type TermKeyKey
    local ev = t.ffi.new('TermKeyMouseEvent[1]')
    local button = t.ffi.new('int[1]')
    local line = t.ffi.new('int[1]')
    local col = t.ffi.new('int[1]')
    local buffer = t.ffi.new('char[32]')

    termkey.termkey_push_bytes(tk, '\x1b[M !!', 6)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for mouse press

    t.eq(termkey.TERMKEY_TYPE_MOUSE, key.type) -- key.type for mouse press

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_PRESS, ev[0]) -- mouse event for press
    t.eq(1, button[0]) -- mouse button for press
    t.eq(1, line[0]) -- mouse line for press
    t.eq(1, col[0]) -- mouse column for press
    t.eq(0, key.modifiers) -- modifiers for press

    local len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(13, len) -- string length for press
    t.eq('MousePress(1)', t.ffi.string(buffer)) -- string buffer for press

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_MOUSE_POS
    )
    t.eq(21, len) -- string length for press
    t.eq('MousePress(1) @ (1,1)', t.ffi.string(buffer)) -- string buffer for press

    termkey.termkey_push_bytes(tk, '\x1b[M@"!', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_DRAG, ev[0]) -- mouse event for drag
    t.eq(1, button[0]) --  mouse button for drag
    t.eq(1, line[0]) --  mouse line for drag
    t.eq(2, col[0]) --  mouse column for drag
    t.eq(0, key.modifiers) -- modifiers for press

    termkey.termkey_push_bytes(tk, '\x1b[M##!', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_RELEASE, ev[0]) -- mouse event for release
    t.eq(1, line[0]) -- mouse line for release
    t.eq(3, col[0]) -- mouse column for release
    t.eq(0, key.modifiers) -- modifiers for press

    termkey.termkey_push_bytes(tk, '\x1b[M0++', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_PRESS, ev[0]) -- mouse event for Ctrl-press
    t.eq(1, button[0]) -- mouse button for Ctrl-press
    t.eq(11, line[0]) -- mouse line for Ctrl-press
    t.eq(11, col[0]) -- mouse column for Ctrl-press
    t.eq(termkey.TERMKEY_KEYMOD_CTRL, key.modifiers) -- modifiers for Ctrl-press

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(15, len) -- string length for Ctrl-press
    t.eq('C-MousePress(1)', t.ffi.string(buffer)) -- string buffer for Ctrl-press

    termkey.termkey_push_bytes(tk, '\x1b[M`!!', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_PRESS, ev[0]) -- mouse event for wheel down
    t.eq(4, button[0]) -- mouse button for wheel down

    termkey.termkey_push_bytes(tk, '\x1b[Mb!!', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_PRESS, ev[0]) -- mouse event for wheel left
    t.eq(6, button[0]) -- mouse button for wheel left

    -- rxvt protocol
    termkey.termkey_push_bytes(tk, '\x1b[0;20;20M', 10)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for mouse press rxvt protocol

    t.eq(termkey.TERMKEY_TYPE_MOUSE, key.type) -- key.type for mouse press rxvt protocol

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_PRESS, ev[0]) -- mouse event for press rxvt protocol
    t.eq(1, button[0]) -- mouse button for press rxvt protocol
    t.eq(20, line[0]) -- mouse line for press rxvt protocol
    t.eq(20, col[0]) -- mouse column for press rxvt protocol
    t.eq(0, key.modifiers) -- modifiers for press rxvt protocol

    termkey.termkey_push_bytes(tk, '\x1b[3;20;20M', 10)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for mouse release rxvt protocol

    t.eq(termkey.TERMKEY_TYPE_MOUSE, key.type) -- key.type for mouse release rxvt protocol

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_RELEASE, ev[0]) -- mouse event for release rxvt protocol
    t.eq(20, line[0]) -- mouse line for release rxvt protocol
    t.eq(20, col[0]) -- mouse column for release rxvt protocol
    t.eq(0, key.modifiers) -- modifiers for release rxvt protocol

    -- SGR protocol
    termkey.termkey_push_bytes(tk, '\x1b[<0;30;30M', 11)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for mouse press SGR encoding

    t.eq(termkey.TERMKEY_TYPE_MOUSE, key.type) -- key.type for mouse press SGR encoding

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_PRESS, ev[0]) -- mouse event for press SGR
    t.eq(1, button[0]) -- mouse button for press SGR
    t.eq(30, line[0]) -- mouse line for press SGR
    t.eq(30, col[0]) -- mouse column for press SGR
    t.eq(0, key.modifiers) -- modifiers for press SGR

    termkey.termkey_push_bytes(tk, '\x1b[<0;30;30m', 11)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for mouse release SGR encoding

    t.eq(termkey.TERMKEY_TYPE_MOUSE, key.type) -- key.type for mouse release SGR encoding

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)) -- interpret_mouse yields RES_KEY

    t.eq(termkey.TERMKEY_MOUSE_RELEASE, ev[0]) -- mouse event for release SGR

    termkey.termkey_push_bytes(tk, '\x1b[<0;500;300M', 13)

    termkey.termkey_getkey(tk, key)
    termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)

    t.eq(300, line[0]) -- mouse line for press SGR wide
    t.eq(500, col[0]) -- mouse column for press SGR wide

    termkey.termkey_destroy(tk)
  end)

  itp('31position', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey
    local line = t.ffi.new('int[1]')
    local col = t.ffi.new('int[1]')

    termkey.termkey_push_bytes(tk, '\x1b[?15;7R', 8)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for position report

    t.eq(termkey.TERMKEY_TYPE_POSITION, key.type) -- key.type for position report

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_position(tk, key, line, col)) -- interpret_position yields RES_KEY

    t.eq(15, line[0]) -- line for position report
    t.eq(7, col[0]) -- column for position report

    -- A plain CSI R is likely to be <F3> though.
    -- This is tricky :/

    termkey.termkey_push_bytes(tk, '\x1b[R', 3)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for <F3>

    t.eq(termkey.TERMKEY_TYPE_FUNCTION, key.type) -- key.type for <F3>
    t.eq(3, key.code.number) -- key.code.number for <F3>

    termkey.termkey_destroy(tk)
  end)

  itp('32modereport', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey
    local initial = t.ffi.new('int[1]')
    local mode = t.ffi.new('int[1]')
    local value = t.ffi.new('int[1]')

    termkey.termkey_push_bytes(tk, '\x1b[?1;2$y', 8)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for mode report

    t.eq(termkey.TERMKEY_TYPE_MODEREPORT, key.type) -- key.type for mode report

    t.eq(
      termkey.TERMKEY_RES_KEY,
      termkey.termkey_interpret_modereport(tk, key, initial, mode, value)
    ) -- interpret_modereoprt yields RES_KEY

    t.eq(63, initial[0]) -- initial indicator from mode report
    t.eq(1, mode[0]) -- mode number from mode report
    t.eq(2, value[0]) -- mode value from mode report

    termkey.termkey_push_bytes(tk, '\x1b[4;1$y', 7)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for mode report

    t.eq(termkey.TERMKEY_TYPE_MODEREPORT, key.type) -- key.type for mode report

    t.eq(
      termkey.TERMKEY_RES_KEY,
      termkey.termkey_interpret_modereport(tk, key, initial, mode, value)
    ) -- interpret_modereoprt yields RES_KEY

    t.eq(0, initial[0]) -- initial indicator from mode report
    t.eq(4, mode[0]) -- mode number from mode report
    t.eq(1, value[0]) -- mode value from mode report

    termkey.termkey_destroy(tk)
  end)

  itp('38csi', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey
    local args = t.ffi.new('TermKeyCsiParam[16]')
    local nargs = t.ffi.new('size_t[1]')
    local command = t.ffi.new('unsigned[1]')

    termkey.termkey_push_bytes(tk, '\x1b[5;25v', 7)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for CSI v

    t.eq(termkey.TERMKEY_TYPE_UNKNOWN_CSI, key.type) -- key.type for unknown CSI

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_csi(tk, key, args, nargs, command)) -- interpret_csi yields RES_KEY

    t.eq(2, nargs[0]) -- nargs for unknown CSI
    -- t.eq(5,   args[0]) -- args[0] for unknown CSI
    -- t.eq(25,  args[1]) -- args[1] for unknown CSI
    t.eq(118, command[0]) -- command for unknown CSI

    termkey.termkey_push_bytes(tk, '\x1b[?w', 4)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for CSI ? w
    t.eq(termkey.TERMKEY_TYPE_UNKNOWN_CSI, key.type) -- key.type for unknown CSI
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_csi(tk, key, args, nargs, command)) -- interpret_csi yields RES_KEY
    t.eq(bit.bor(bit.lshift(63, 8), 119), command[0]) -- command for unknown CSI

    termkey.termkey_push_bytes(tk, '\x1b[?$x', 5)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for CSI ? $x
    t.eq(termkey.TERMKEY_TYPE_UNKNOWN_CSI, key.type) -- key.type for unknown CSI
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_csi(tk, key, args, nargs, command)) -- interpret_csi yields RES_KEY
    t.eq(bit.bor(bit.lshift(36, 16), bit.lshift(63, 8), 120), command[0]) -- command for unknown CSI

    termkey.termkey_destroy(tk)
  end)

  itp('39dcs', function()
    local tk = termkey.termkey_new_abstract(nil, 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    -- 7bit DCS
    termkey.termkey_push_bytes(tk, '\x1bP1$r1 q\x1b\\', 10)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for DCS

    t.eq(termkey.TERMKEY_TYPE_DCS, key.type) -- key.type for DCS
    t.eq(0, key.modifiers) -- key.modifiers for DCS

    local str = t.ffi.new('const char*[1]')
    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_string(tk, key, str)) -- termkey_interpret_string() gives string
    t.eq('1$r1 q', t.ffi.string(str[0])) -- termkey_interpret_string() yields correct string

    t.eq(termkey.TERMKEY_RES_NONE, termkey.termkey_getkey(tk, key)) -- getkey again yields RES_NONE

    -- 8bit DCS
    termkey.termkey_push_bytes(tk, '\x901$r2 q\x9c', 8)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for DCS

    t.eq(termkey.TERMKEY_TYPE_DCS, key.type) -- key.type for DCS
    t.eq(0, key.modifiers) -- key.modifiers for DCS

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_string(tk, key, str)) -- "termkey_interpret_string() gives string");
    t.eq('1$r2 q', t.ffi.string(str[0])) -- "termkey_interpret_string() yields correct string");

    t.eq(termkey.TERMKEY_RES_NONE, termkey.termkey_getkey(tk, key)) -- "getkey again yields RES_NONE");

    -- 7bit OSC
    termkey.termkey_push_bytes(tk, '\x1b]15;abc\x1b\\', 10)

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey(tk, key)) -- getkey yields RES_KEY for OSC

    t.eq(termkey.TERMKEY_TYPE_OSC, key.type) -- key.type for OSC
    t.eq(0, key.modifiers) -- key.modifiers for OSC

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_interpret_string(tk, key, str)) -- "termkey_interpret_string() gives string");
    t.eq('15;abc', t.ffi.string(str[0])) -- "termkey_interpret_string() yields correct string");

    t.eq(termkey.TERMKEY_RES_NONE, termkey.termkey_getkey(tk, key)) -- getkey again yields RES_NONE

    -- False alarm
    termkey.termkey_push_bytes(tk, '\x1bP', 2)

    t.eq(termkey.TERMKEY_RES_AGAIN, termkey.termkey_getkey(tk, key)) -- getkey yields RES_AGAIN for false alarm

    t.eq(termkey.TERMKEY_RES_KEY, termkey.termkey_getkey_force(tk, key)) -- getkey_force yields RES_KEY for false alarm

    t.eq(termkey.TERMKEY_TYPE_UNICODE, key.type) -- key.type for false alarm
    t.eq(string.byte('P'), key.code.codepoint) -- key.code.codepoint for false alarm
    t.eq(termkey.TERMKEY_KEYMOD_ALT, key.modifiers) -- key.modifiers for false alarm

    termkey.termkey_destroy(tk)
  end)
end)
