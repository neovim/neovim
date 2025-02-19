local t = require('test.unit.testutil')
local itp = t.gen_itp(it)
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
    local tk = termkey.termkey_new_abstract('vt100', 0)
    t.neq(tk, nil)

    t.eq(termkey.termkey_get_buffer_size(tk), 256)
    t.eq(tk.is_started, 1) -- tk->is_started true after construction

    termkey.termkey_stop(tk)
    t.neq(tk.is_started, 1) -- tk->is_started false after termkey_stop()

    termkey.termkey_start(tk)
    t.eq(tk.is_started, 1) -- tk->is_started true after termkey_start()

    termkey.termkey_destroy(tk)
  end)

  itp('02getkey', function()
    local tk = termkey.termkey_new_abstract('vt100', 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    t.eq(termkey.termkey_get_buffer_remaining(tk), 256) -- buffer free initially 256

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_NONE) -- getkey yields RES_NONE when empty

    t.eq(termkey.termkey_push_bytes(tk, 'h', 1), 1) -- push_bytes returns 1

    t.eq(termkey.termkey_get_buffer_remaining(tk), 255) -- buffer free 255 after push_bytes

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY after h

    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type after h
    t.eq(key.code.codepoint, string.byte('h')) -- key.code.codepoint after h
    t.eq(key.modifiers, 0) -- key.modifiers after h
    t.eq(t.ffi.string(key.utf8), 'h') -- key.utf8 after h

    t.eq(termkey.termkey_get_buffer_remaining(tk), 256) -- buffer free 256 after getkey

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_NONE) -- getkey yields RES_NONE a second time

    termkey.termkey_push_bytes(tk, '\x01', 1)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY after C-a

    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type after C-a
    t.eq(key.code.codepoint, string.byte('a')) -- key.code.codepoint after C-a
    t.eq(key.modifiers, termkey.TERMKEY_KEYMOD_CTRL) -- key.modifiers after C-a

    termkey.termkey_push_bytes(tk, '\033OA', 3)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY after Up

    -- is_int(key.type,        TERMKEY_TYPE_KEYSYM,  "key.type after Up");
    -- is_int(key.code.sym,    TERMKEY_SYM_UP,       "key.code.sym after Up");
    t.eq(key.modifiers, 0) -- key.modifiers after Up

    t.eq(termkey.termkey_push_bytes(tk, '\033O', 2), 2) -- push_bytes returns 2

    -- is_int(termkey_get_buffer_remaining(tk), 254, "buffer free 254 after partial write");

    -- is_int(termkey_getkey(tk, &key), TERMKEY_RES_AGAIN, "getkey yields RES_AGAIN after partial write");

    termkey.termkey_push_bytes(tk, 'C', 1)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY after Right completion

    -- is_int(key.type,        TERMKEY_TYPE_KEYSYM,  "key.type after Right");
    -- is_int(key.code.sym,    TERMKEY_SYM_RIGHT,    "key.code.sym after Right");
    -- is_int(key.modifiers,   0,                    "key.modifiers after Right");

    -- is_int(termkey_get_buffer_remaining(tk), 256, "buffer free 256 after completion");

    termkey.termkey_push_bytes(tk, '\033[27;5u', 7)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY after Ctrl-Escape

    -- is_int(key.type,        TERMKEY_TYPE_KEYSYM, "key.type after Ctrl-Escape");
    -- is_int(key.code.sym,    TERMKEY_SYM_ESCAPE,  "key.code.sym after Ctrl-Escape");
    -- is_int(key.modifiers,   TERMKEY_KEYMOD_CTRL, "key.modifiers after Ctrl-Escape");

    termkey.termkey_push_bytes(tk, '\0', 1)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY after Ctrl-Space

    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type after Ctrl-Space
    -- t.eq(key.code.codepoint, string.byte(' ')) -- key.code.codepoint after Ctrl-Space
    -- is_int(key.modifiers,      TERMKEY_KEYMOD_CTRL,  "key.modifiers after Ctrl-Space");

    termkey.termkey_destroy(tk)
  end)

  itp('03utf8', function()
    local tk = termkey.termkey_new_abstract('vt100', termkey.TERMKEY_FLAG_UTF8)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    termkey.termkey_push_bytes(tk, 'a', 1)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY low ASCII
    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type low ASCII
    t.eq(key.code.codepoint, string.byte('a')) -- key.code.codepoint low ASCII

    -- 2-byte UTF-8 range is U+0080 to U+07FF (0xDF 0xBF)
    -- However, we'd best avoid the C1 range, so we'll start at U+00A0 (0xC2 0xA0)

    termkey.termkey_push_bytes(tk, '\xC2\xA0', 2)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 2 low
    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type UTF-8 2 low
    t.eq(key.code.codepoint, 0x00A0) -- key.code.codepoint UTF-8 2 low

    termkey.termkey_push_bytes(tk, '\xDF\xBF', 2)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 2 high
    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type UTF-8 2 high
    t.eq(key.code.codepoint, 0x07FF) -- key.code.codepoint UTF-8 2 high

    -- 3-byte UTF-8 range is U+0800 (0xE0 0xA0 0x80) to U+FFFD (0xEF 0xBF 0xBD)

    termkey.termkey_push_bytes(tk, '\xE0\xA0\x80', 3)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 3 low
    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type UTF-8 3 low
    t.eq(key.code.codepoint, 0x0800) -- key.code.codepoint UTF-8 3 low

    termkey.termkey_push_bytes(tk, '\xEF\xBF\xBD', 3)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 3 high
    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type UTF-8 3 high
    t.eq(key.code.codepoint, 0xFFFD) -- key.code.codepoint UTF-8 3 high

    -- 4-byte UTF-8 range is U+10000 (0xF0 0x90 0x80 0x80) to U+10FFFF (0xF4 0x8F 0xBF 0xBF)

    termkey.termkey_push_bytes(tk, '\xF0\x90\x80\x80', 4)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 low
    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type UTF-8 4 low
    t.eq(key.code.codepoint, 0x10000) -- key.code.codepoint UTF-8 4 low

    termkey.termkey_push_bytes(tk, '\xF4\x8F\xBF\xBF', 4)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 high
    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type UTF-8 4 high
    t.eq(key.code.codepoint, 0x10FFFF) -- key.code.codepoint UTF-8 4 high

    -- Invalid continuations

    termkey.termkey_push_bytes(tk, '\xC2!', 2)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 2 invalid cont
    t.eq(key.code.codepoint, 0xFFFD) -- key.code.codepoint UTF-8 2 invalid cont
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 2 invalid after
    t.eq(key.code.codepoint, string.byte('!')) -- key.code.codepoint UTF-8 2 invalid after

    termkey.termkey_push_bytes(tk, '\xE0!', 2)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 3 invalid cont
    t.eq(key.code.codepoint, 0xFFFD) -- key.code.codepoint UTF-8 3 invalid cont
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 3 invalid after
    t.eq(key.code.codepoint, string.byte('!')) -- key.code.codepoint UTF-8 3 invalid after

    termkey.termkey_push_bytes(tk, '\xE0\xA0!', 3)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 3 invalid cont 2
    t.eq(key.code.codepoint, 0xFFFD) -- key.code.codepoint UTF-8 3 invalid cont 2
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 3 invalid after
    t.eq(key.code.codepoint, string.byte('!')) -- key.code.codepoint UTF-8 3 invalid after

    termkey.termkey_push_bytes(tk, '\xF0!', 2)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 invalid cont
    t.eq(key.code.codepoint, 0xFFFD) -- key.code.codepoint UTF-8 4 invalid cont
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 invalid after
    t.eq(key.code.codepoint, string.byte('!')) -- key.code.codepoint UTF-8 4 invalid after

    termkey.termkey_push_bytes(tk, '\xF0\x90!', 3)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 invalid cont 2
    t.eq(key.code.codepoint, 0xFFFD) -- key.code.codepoint UTF-8 4 invalid cont 2
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 invalid after
    t.eq(key.code.codepoint, string.byte('!')) -- key.code.codepoint UTF-8 4 invalid after

    termkey.termkey_push_bytes(tk, '\xF0\x90\x80!', 4)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 invalid cont 3
    t.eq(key.code.codepoint, 0xFFFD) -- key.code.codepoint UTF-8 4 invalid cont 3
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 invalid after
    t.eq(key.code.codepoint, string.byte('!')) -- key.code.codepoint UTF-8 4 invalid after

    -- Partials

    termkey.termkey_push_bytes(tk, '\xC2', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_AGAIN) -- getkey yields RES_AGAIN UTF-8 2 partial

    termkey.termkey_push_bytes(tk, '\xA0', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 2 partial
    t.eq(key.code.codepoint, 0x00A0) -- key.code.codepoint UTF-8 2 partial

    termkey.termkey_push_bytes(tk, '\xE0', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_AGAIN) -- getkey yields RES_AGAIN UTF-8 3 partial

    termkey.termkey_push_bytes(tk, '\xA0', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_AGAIN) -- getkey yields RES_AGAIN UTF-8 3 partial

    termkey.termkey_push_bytes(tk, '\x80', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 3 partial
    t.eq(key.code.codepoint, 0x0800) -- key.code.codepoint UTF-8 3 partial

    termkey.termkey_push_bytes(tk, '\xF0', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_AGAIN) -- getkey yields RES_AGAIN UTF-8 4 partial

    termkey.termkey_push_bytes(tk, '\x90', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_AGAIN) -- getkey yields RES_AGAIN UTF-8 4 partial

    termkey.termkey_push_bytes(tk, '\x80', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_AGAIN) -- getkey yields RES_AGAIN UTF-8 4 partial

    termkey.termkey_push_bytes(tk, '\x80', 1)
    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY UTF-8 4 partial
    t.eq(key.code.codepoint, 0x10000) -- key.code.codepoint UTF-8 4 partial

    termkey.termkey_destroy(tk)
  end)

  itp('04flags', function()
    local tk = termkey.termkey_new_abstract('vt100', 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    termkey.termkey_push_bytes(tk, ' ', 1)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY after space

    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type after space
    t.eq(key.code.codepoint, string.byte(' ')) -- key.code.codepoint after space
    t.eq(key.modifiers, 0) -- key.modifiers after space

    termkey.termkey_set_flags(tk, termkey.TERMKEY_FLAG_SPACESYMBOL)

    termkey.termkey_push_bytes(tk, ' ', 1)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY after space

    t.eq(key.type, termkey.TERMKEY_TYPE_KEYSYM) -- key.type after space with FLAG_SPACESYMBOL
    t.eq(key.code.sym, termkey.TERMKEY_SYM_SPACE) -- key.code.sym after space with FLAG_SPACESYMBOL
    t.eq(key.modifiers, 0) -- key.modifiers after space with FLAG_SPACESYMBOL

    termkey.termkey_destroy(tk)
  end)

  itp('06buffer', function()
    local tk = termkey.termkey_new_abstract('vt100', 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    t.eq(termkey.termkey_get_buffer_remaining(tk), 256) -- buffer free initially 256
    t.eq(termkey.termkey_get_buffer_size(tk), 256) -- buffer size initially 256

    t.eq(termkey.termkey_push_bytes(tk, 'h', 1), 1) -- push_bytes returns 1

    t.eq(termkey.termkey_get_buffer_remaining(tk), 255) -- buffer free 255 after push_bytes
    t.eq(termkey.termkey_get_buffer_size(tk), 256) -- buffer size 256 after push_bytes

    t.eq(not not termkey.termkey_set_buffer_size(tk, 512), true) -- buffer set size OK

    t.eq(termkey.termkey_get_buffer_remaining(tk), 511) -- buffer free 511 after push_bytes
    t.eq(termkey.termkey_get_buffer_size(tk), 512) -- buffer size 512 after push_bytes

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- buffered key still usable after resize

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
    local tk = termkey.termkey_new_abstract('vt100', 0)

    local sym = termkey_keyname2sym(tk, 'SomeUnknownKey')
    t.eq(sym, termkey.TERMKEY_SYM_UNKNOWN) -- keyname2sym SomeUnknownKey

    sym = termkey_keyname2sym(tk, 'Space')
    t.eq(sym[0], termkey.TERMKEY_SYM_SPACE) -- keyname2sym Space

    local _end = termkey.termkey_lookup_keyname(tk, 'Up', sym)
    t.neq(_end, nil) -- termkey_get_keyname Up returns non-NULL
    t.eq(t.ffi.string(_end), '') -- termkey_get_keyname Up return points at endofstring
    t.eq(sym[0], termkey.TERMKEY_SYM_UP) -- termkey_get_keyname Up yields Up symbol

    _end = termkey.termkey_lookup_keyname(tk, 'DownMore', sym)
    t.neq(_end, nil) -- termkey_get_keyname DownMore returns non-NULL
    t.eq(t.ffi.string(_end), 'More') -- termkey_get_keyname DownMore return points at More
    t.eq(sym[0], termkey.TERMKEY_SYM_DOWN) -- termkey_get_keyname DownMore yields Down symbol

    _end = termkey.termkey_lookup_keyname(tk, 'SomeUnknownKey', sym)
    t.eq(_end, nil) -- termkey_get_keyname SomeUnknownKey returns NULL

    t.eq(t.ffi.string(termkey.termkey_get_keyname(tk, termkey.TERMKEY_SYM_SPACE)), 'Space') -- "get_keyname SPACE");

    termkey.termkey_destroy(tk)
  end)

  itp('11strfkey', function()
    local tk = termkey.termkey_new_abstract('vt100', 0)
    ---@type TermKeyKey
    local key = t.ffi.new(
      'TermKeyKey',
      { type = termkey.TERMKEY_TYPE_UNICODE, code = { codepoint = string.byte('A') } }
    )
    local buffer = t.ffi.new('char[16]')

    local len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(len, 1) -- length for unicode/A/0
    t.eq(t.ffi.string(buffer), 'A') -- buffer for unicode/A/0

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_WRAPBRACKET
    )
    t.eq(len, 1) -- length for unicode/A/0 wrapbracket
    t.eq(t.ffi.string(buffer), 'A') -- buffer for unicode/A/0 wrapbracket

    ---@type TermKeyKey
    key = t.ffi.new('TermKeyKey', {
      type = termkey.TERMKEY_TYPE_UNICODE,
      code = { codepoint = string.byte('b') },
      modifiers = termkey.TERMKEY_KEYMOD_CTRL,
    })

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(len, 3) -- length for unicode/b/CTRL
    t.eq(t.ffi.string(buffer), 'C-b') -- buffer for unicode/b/CTRL

    len =
      termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, termkey.TERMKEY_FORMAT_LONGMOD)
    t.eq(len, 6) -- length for unicode/b/CTRL longmod
    t.eq(t.ffi.string(buffer), 'Ctrl-b') -- buffer for unicode/b/CTRL longmod

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      bit.bor(termkey.TERMKEY_FORMAT_LONGMOD, termkey.TERMKEY_FORMAT_SPACEMOD)
    )
    t.eq(len, 6) -- length for unicode/b/CTRL longmod|spacemod
    t.eq(t.ffi.string(buffer), 'Ctrl b') -- buffer for unicode/b/CTRL longmod|spacemod

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      bit.bor(termkey.TERMKEY_FORMAT_LONGMOD, termkey.TERMKEY_FORMAT_LOWERMOD)
    )
    t.eq(len, 6) -- length for unicode/b/CTRL longmod|lowermod
    t.eq(t.ffi.string(buffer), 'ctrl-b') -- buffer for unicode/b/CTRL longmod|lowermod

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
    t.eq(len, 6) -- length for unicode/b/CTRL longmod|spacemod|lowermode
    t.eq(t.ffi.string(buffer), 'ctrl b') -- buffer for unicode/b/CTRL longmod|spacemod|lowermode

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_CARETCTRL
    )
    t.eq(len, 2) -- length for unicode/b/CTRL caretctrl
    t.eq(t.ffi.string(buffer), '^B') -- buffer for unicode/b/CTRL caretctrl

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_WRAPBRACKET
    )
    t.eq(len, 5) -- length for unicode/b/CTRL wrapbracket
    t.eq(t.ffi.string(buffer), '<C-b>') -- buffer for unicode/b/CTRL wrapbracket

    ---@type TermKeyKey
    key = t.ffi.new('TermKeyKey', {
      type = termkey.TERMKEY_TYPE_UNICODE,
      code = { codepoint = string.byte('c') },
      modifiers = termkey.TERMKEY_KEYMOD_ALT,
    })

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(len, 3) -- length for unicode/c/ALT
    t.eq(t.ffi.string(buffer), 'A-c') -- buffer for unicode/c/ALT

    len =
      termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, termkey.TERMKEY_FORMAT_LONGMOD)
    t.eq(len, 5) -- length for unicode/c/ALT longmod
    t.eq(t.ffi.string(buffer), 'Alt-c') -- buffer for unicode/c/ALT longmod

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_ALTISMETA
    )
    t.eq(len, 3) -- length for unicode/c/ALT altismeta
    t.eq(t.ffi.string(buffer), 'M-c') -- buffer for unicode/c/ALT altismeta

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      bit.bor(termkey.TERMKEY_FORMAT_LONGMOD, termkey.TERMKEY_FORMAT_ALTISMETA)
    )
    t.eq(len, 6) -- length for unicode/c/ALT longmod|altismeta
    t.eq(t.ffi.string(buffer), 'Meta-c') -- buffer for unicode/c/ALT longmod|altismeta

    ---@type TermKeyKey
    key = t.ffi.new(
      'TermKeyKey',
      { type = termkey.TERMKEY_TYPE_KEYSYM, code = { sym = termkey.TERMKEY_SYM_UP } }
    )

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(len, 2) -- length for sym/Up/0
    t.eq(t.ffi.string(buffer), 'Up') -- buffer for sym/Up/0

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_WRAPBRACKET
    )
    t.eq(len, 4) -- length for sym/Up/0 wrapbracket
    t.eq(t.ffi.string(buffer), '<Up>') -- buffer for sym/Up/0 wrapbracket

    ---@type TermKeyKey
    key = t.ffi.new(
      'TermKeyKey',
      { type = termkey.TERMKEY_TYPE_KEYSYM, code = { sym = termkey.TERMKEY_SYM_PAGEUP } }
    )

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(len, 6) -- length for sym/PageUp/0
    t.eq(t.ffi.string(buffer), 'PageUp') -- buffer for sym/PageUp/0

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_LOWERSPACE
    )
    t.eq(len, 7) -- length for sym/PageUp/0 lowerspace
    t.eq(t.ffi.string(buffer), 'page up') -- buffer for sym/PageUp/0 lowerspace

    -- If size of buffer is too small, strfkey should return something consistent
    len = termkey.termkey_strfkey(tk, buffer, 4, key, 0)
    t.eq(len, 6) -- length for sym/PageUp/0
    t.eq(t.ffi.string(buffer), 'Pag') -- buffer of len 4 for sym/PageUp/0

    len = termkey.termkey_strfkey(tk, buffer, 4, key, termkey.TERMKEY_FORMAT_LOWERSPACE)
    t.eq(len, 7) -- length for sym/PageUp/0 lowerspace
    t.eq(t.ffi.string(buffer), 'pag') -- buffer of len 4 for sym/PageUp/0 lowerspace

    key = t.ffi.new('TermKeyKey', { type = termkey.TERMKEY_TYPE_FUNCTION, code = { number = 5 } }) ---@type TermKeyKey

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(len, 2) -- length for func/5/0
    t.eq(t.ffi.string(buffer), 'F5') -- buffer for func/5/0

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_WRAPBRACKET
    )
    t.eq(len, 4) -- length for func/5/0 wrapbracket
    t.eq(t.ffi.string(buffer), '<F5>') -- buffer for func/5/0 wrapbracket

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_LOWERSPACE
    )
    t.eq(len, 2) -- length for func/5/0 lowerspace
    t.eq(t.ffi.string(buffer), 'f5') -- buffer for func/5/0 lowerspace

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

    local tk = termkey.termkey_new_abstract('vt100', 0)
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

    t.eq(termkey_keycmp(tk, key1, key1), 0) -- cmpkey same structure
    t.eq(termkey_keycmp(tk, key1, key2), 0) -- cmpkey identical structure

    key2.modifiers = termkey.TERMKEY_KEYMOD_CTRL

    t.eq(termkey_keycmp(tk, key1, key2) < 0, true) -- cmpkey orders CTRL after nomod
    t.eq(termkey_keycmp(tk, key2, key1) > 0, true) -- cmpkey orders nomod before CTRL

    key2.code.codepoint = string.byte('B')
    key2.modifiers = 0

    t.eq(termkey_keycmp(tk, key1, key2) < 0, true) -- cmpkey orders 'B' after 'A'
    t.eq(termkey_keycmp(tk, key2, key1) > 0, true) -- cmpkey orders 'A' before 'B'

    key1.modifiers = termkey.TERMKEY_KEYMOD_CTRL

    t.eq(termkey_keycmp(tk, key1, key2) < 0, true) -- cmpkey orders nomod 'B' after CTRL 'A'
    t.eq(termkey_keycmp(tk, key2, key1) > 0, true) -- cmpkey orders CTRL 'A' before nomod 'B'

    key2.type = termkey.TERMKEY_TYPE_KEYSYM
    key2.code.sym = termkey.TERMKEY_SYM_UP

    t.eq(termkey_keycmp(tk, key1, key2) < 0, true) -- cmpkey orders KEYSYM after UNICODE
    t.eq(termkey_keycmp(tk, key2, key1) > 0, true) -- cmpkey orders UNICODE before KEYSYM

    key1.type = termkey.TERMKEY_TYPE_KEYSYM
    key1.code.sym = termkey.TERMKEY_SYM_SPACE
    key1.modifiers = 0
    key2.type = termkey.TERMKEY_TYPE_UNICODE
    key2.code.codepoint = string.byte(' ')
    key2.modifiers = 0

    t.eq(termkey_keycmp(tk, key1, key2), 0) -- cmpkey considers KEYSYM/SPACE and UNICODE/SP identical

    termkey.termkey_set_canonflags(
      tk,
      bit.bor(termkey.termkey_get_canonflags(tk), termkey.TERMKEY_CANON_SPACESYMBOL)
    )
    t.eq(termkey_keycmp(tk, key1, key2), 0) -- "cmpkey considers KEYSYM/SPACE and UNICODE/SP identical under SPACESYMBOL");

    termkey.termkey_destroy(tk)
  end)

  itp('30mouse', function()
    local tk = termkey.termkey_new_abstract('vt100', 0)
    local key = t.ffi.new('TermKeyKey', { type = -1 }) ---@type TermKeyKey
    local ev = t.ffi.new('TermKeyMouseEvent[1]')
    local button = t.ffi.new('int[1]')
    local line = t.ffi.new('int[1]')
    local col = t.ffi.new('int[1]')
    local buffer = t.ffi.new('char[32]')

    termkey.termkey_push_bytes(tk, '\x1b[M !!', 6)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for mouse press

    t.eq(key.type, termkey.TERMKEY_TYPE_MOUSE) -- key.type for mouse press

    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_PRESS) -- mouse event for press
    t.eq(button[0], 1) -- mouse button for press
    t.eq(line[0], 1) -- mouse line for press
    t.eq(col[0], 1) -- mouse column for press
    t.eq(key.modifiers, 0) -- modifiers for press

    local len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(len, 13) -- string length for press
    t.eq(t.ffi.string(buffer), 'MousePress(1)') -- string buffer for press

    len = termkey.termkey_strfkey(
      tk,
      buffer,
      t.ffi.sizeof(buffer),
      key,
      termkey.TERMKEY_FORMAT_MOUSE_POS
    )
    t.eq(len, 21) -- string length for press
    t.eq(t.ffi.string(buffer), 'MousePress(1) @ (1,1)') -- string buffer for press

    termkey.termkey_push_bytes(tk, '\x1b[M@"!', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_DRAG) -- mouse event for drag
    t.eq(button[0], 1) --  mouse button for drag
    t.eq(line[0], 1) --  mouse line for drag
    t.eq(col[0], 2) --  mouse column for drag
    t.eq(key.modifiers, 0) -- modifiers for press

    termkey.termkey_push_bytes(tk, '\x1b[M##!', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_RELEASE) -- mouse event for release
    t.eq(line[0], 1) -- mouse line for release
    t.eq(col[0], 3) -- mouse column for release
    t.eq(key.modifiers, 0) -- modifiers for press

    termkey.termkey_push_bytes(tk, '\x1b[M0++', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_PRESS) -- mouse event for Ctrl-press
    t.eq(button[0], 1) -- mouse button for Ctrl-press
    t.eq(line[0], 11) -- mouse line for Ctrl-press
    t.eq(col[0], 11) -- mouse column for Ctrl-press
    t.eq(key.modifiers, termkey.TERMKEY_KEYMOD_CTRL) -- modifiers for Ctrl-press

    len = termkey.termkey_strfkey(tk, buffer, t.ffi.sizeof(buffer), key, 0)
    t.eq(len, 15) -- string length for Ctrl-press
    t.eq(t.ffi.string(buffer), 'C-MousePress(1)') -- string buffer for Ctrl-press

    termkey.termkey_push_bytes(tk, '\x1b[M`!!', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_PRESS) -- mouse event for wheel down
    t.eq(button[0], 4) -- mouse button for wheel down

    termkey.termkey_push_bytes(tk, '\x1b[Mb!!', 6)

    termkey.termkey_getkey(tk, key)
    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_PRESS) -- mouse event for wheel left
    t.eq(button[0], 6) -- mouse button for wheel left

    -- rxvt protocol
    termkey.termkey_push_bytes(tk, '\x1b[0;20;20M', 10)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for mouse press rxvt protocol

    t.eq(key.type, termkey.TERMKEY_TYPE_MOUSE) -- key.type for mouse press rxvt protocol

    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_PRESS) -- mouse event for press rxvt protocol
    t.eq(button[0], 1) -- mouse button for press rxvt protocol
    t.eq(line[0], 20) -- mouse line for press rxvt protocol
    t.eq(col[0], 20) -- mouse column for press rxvt protocol
    t.eq(key.modifiers, 0) -- modifiers for press rxvt protocol

    termkey.termkey_push_bytes(tk, '\x1b[3;20;20M', 10)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for mouse release rxvt protocol

    t.eq(key.type, termkey.TERMKEY_TYPE_MOUSE) -- key.type for mouse release rxvt protocol

    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_RELEASE) -- mouse event for release rxvt protocol
    t.eq(line[0], 20) -- mouse line for release rxvt protocol
    t.eq(col[0], 20) -- mouse column for release rxvt protocol
    t.eq(key.modifiers, 0) -- modifiers for release rxvt protocol

    -- SGR protocol
    termkey.termkey_push_bytes(tk, '\x1b[<0;30;30M', 11)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for mouse press SGR encoding

    t.eq(key.type, termkey.TERMKEY_TYPE_MOUSE) -- key.type for mouse press SGR encoding

    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_PRESS) -- mouse event for press SGR
    t.eq(button[0], 1) -- mouse button for press SGR
    t.eq(line[0], 30) -- mouse line for press SGR
    t.eq(col[0], 30) -- mouse column for press SGR
    t.eq(key.modifiers, 0) -- modifiers for press SGR

    termkey.termkey_push_bytes(tk, '\x1b[<0;30;30m', 11)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for mouse release SGR encoding

    t.eq(key.type, termkey.TERMKEY_TYPE_MOUSE) -- key.type for mouse release SGR encoding

    t.eq(termkey.termkey_interpret_mouse(tk, key, ev, button, line, col), termkey.TERMKEY_RES_KEY) -- interpret_mouse yields RES_KEY

    t.eq(ev[0], termkey.TERMKEY_MOUSE_RELEASE) -- mouse event for release SGR

    termkey.termkey_push_bytes(tk, '\x1b[<0;500;300M', 13)

    termkey.termkey_getkey(tk, key)
    termkey.termkey_interpret_mouse(tk, key, ev, button, line, col)

    t.eq(line[0], 300) -- mouse line for press SGR wide
    t.eq(col[0], 500) -- mouse column for press SGR wide

    termkey.termkey_destroy(tk)
  end)

  itp('31position', function()
    local tk = termkey.termkey_new_abstract('vt100', 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey
    local line = t.ffi.new('int[1]')
    local col = t.ffi.new('int[1]')

    termkey.termkey_push_bytes(tk, '\x1b[?15;7R', 8)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for position report

    t.eq(key.type, termkey.TERMKEY_TYPE_POSITION) -- key.type for position report

    t.eq(termkey.termkey_interpret_position(tk, key, line, col), termkey.TERMKEY_RES_KEY) -- interpret_position yields RES_KEY

    t.eq(line[0], 15) -- line for position report
    t.eq(col[0], 7) -- column for position report

    -- A plain CSI R is likely to be <F3> though.
    -- This is tricky :/

    termkey.termkey_push_bytes(tk, '\x1b[R', 3)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for <F3>

    t.eq(key.type, termkey.TERMKEY_TYPE_FUNCTION) -- key.type for <F3>
    t.eq(key.code.number, 3) -- key.code.number for <F3>

    termkey.termkey_destroy(tk)
  end)

  itp('32modereport', function()
    local tk = termkey.termkey_new_abstract('vt100', 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey
    local initial = t.ffi.new('int[1]')
    local mode = t.ffi.new('int[1]')
    local value = t.ffi.new('int[1]')

    termkey.termkey_push_bytes(tk, '\x1b[?1;2$y', 8)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for mode report

    t.eq(key.type, termkey.TERMKEY_TYPE_MODEREPORT) -- key.type for mode report

    t.eq(
      termkey.termkey_interpret_modereport(tk, key, initial, mode, value),
      termkey.TERMKEY_RES_KEY
    ) -- interpret_modereoprt yields RES_KEY

    t.eq(initial[0], 63) -- initial indicator from mode report
    t.eq(mode[0], 1) -- mode number from mode report
    t.eq(value[0], 2) -- mode value from mode report

    termkey.termkey_push_bytes(tk, '\x1b[4;1$y', 7)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for mode report

    t.eq(key.type, termkey.TERMKEY_TYPE_MODEREPORT) -- key.type for mode report

    t.eq(
      termkey.termkey_interpret_modereport(tk, key, initial, mode, value),
      termkey.TERMKEY_RES_KEY
    ) -- interpret_modereoprt yields RES_KEY

    t.eq(initial[0], 0) -- initial indicator from mode report
    t.eq(mode[0], 4) -- mode number from mode report
    t.eq(value[0], 1) -- mode value from mode report

    termkey.termkey_destroy(tk)
  end)

  itp('38csi', function()
    local tk = termkey.termkey_new_abstract('vt100', 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey
    local args = t.ffi.new('TermKeyCsiParam[16]')
    local nargs = t.ffi.new('size_t[1]')
    local command = t.ffi.new('unsigned[1]')

    termkey.termkey_push_bytes(tk, '\x1b[5;25v', 7)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for CSI v

    t.eq(key.type, termkey.TERMKEY_TYPE_UNKNOWN_CSI) -- key.type for unknown CSI

    t.eq(termkey.termkey_interpret_csi(tk, key, args, nargs, command), termkey.TERMKEY_RES_KEY) -- interpret_csi yields RES_KEY

    t.eq(nargs[0], 2) -- nargs for unknown CSI
    -- t.eq(args[0],   5) -- args[0] for unknown CSI
    -- t.eq(args[1],  25) -- args[1] for unknown CSI
    t.eq(command[0], 118) -- command for unknown CSI

    termkey.termkey_push_bytes(tk, '\x1b[?w', 4)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for CSI ? w
    t.eq(key.type, termkey.TERMKEY_TYPE_UNKNOWN_CSI) -- key.type for unknown CSI
    t.eq(termkey.termkey_interpret_csi(tk, key, args, nargs, command), termkey.TERMKEY_RES_KEY) -- interpret_csi yields RES_KEY
    t.eq(command[0], bit.bor(bit.lshift(63, 8), 119)) -- command for unknown CSI

    termkey.termkey_push_bytes(tk, '\x1b[?$x', 5)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for CSI ? $x
    t.eq(key.type, termkey.TERMKEY_TYPE_UNKNOWN_CSI) -- key.type for unknown CSI
    t.eq(termkey.termkey_interpret_csi(tk, key, args, nargs, command), termkey.TERMKEY_RES_KEY) -- interpret_csi yields RES_KEY
    t.eq(command[0], bit.bor(bit.lshift(36, 16), bit.lshift(63, 8), 120)) -- command for unknown CSI

    termkey.termkey_destroy(tk)
  end)

  itp('39dcs', function()
    local tk = termkey.termkey_new_abstract('xterm', 0)
    local key = t.ffi.new('TermKeyKey') ---@type TermKeyKey

    -- 7bit DCS
    termkey.termkey_push_bytes(tk, '\x1bP1$r1 q\x1b\\', 10)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for DCS

    t.eq(key.type, termkey.TERMKEY_TYPE_DCS) -- key.type for DCS
    t.eq(key.modifiers, 0) -- key.modifiers for DCS

    local str = t.ffi.new('const char*[1]')
    t.eq(termkey.termkey_interpret_string(tk, key, str), termkey.TERMKEY_RES_KEY) -- termkey_interpret_string() gives string
    t.eq(t.ffi.string(str[0]), '1$r1 q') -- termkey_interpret_string() yields correct string

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_NONE) -- getkey again yields RES_NONE

    -- 8bit DCS
    termkey.termkey_push_bytes(tk, '\x901$r2 q\x9c', 8)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for DCS

    t.eq(key.type, termkey.TERMKEY_TYPE_DCS) -- key.type for DCS
    t.eq(key.modifiers, 0) -- key.modifiers for DCS

    t.eq(termkey.termkey_interpret_string(tk, key, str), termkey.TERMKEY_RES_KEY) -- "termkey_interpret_string() gives string");
    t.eq(t.ffi.string(str[0]), '1$r2 q') -- "termkey_interpret_string() yields correct string");

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_NONE) -- "getkey again yields RES_NONE");

    -- 7bit OSC
    termkey.termkey_push_bytes(tk, '\x1b]15;abc\x1b\\', 10)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_KEY) -- getkey yields RES_KEY for OSC

    t.eq(key.type, termkey.TERMKEY_TYPE_OSC) -- key.type for OSC
    t.eq(key.modifiers, 0) -- key.modifiers for OSC

    t.eq(termkey.termkey_interpret_string(tk, key, str), termkey.TERMKEY_RES_KEY) -- "termkey_interpret_string() gives string");
    t.eq(t.ffi.string(str[0]), '15;abc') -- "termkey_interpret_string() yields correct string");

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_NONE) -- getkey again yields RES_NONE

    -- False alarm
    termkey.termkey_push_bytes(tk, '\x1bP', 2)

    t.eq(termkey.termkey_getkey(tk, key), termkey.TERMKEY_RES_AGAIN) -- getkey yields RES_AGAIN for false alarm

    t.eq(termkey.termkey_getkey_force(tk, key), termkey.TERMKEY_RES_KEY) -- getkey_force yields RES_KEY for false alarm

    t.eq(key.type, termkey.TERMKEY_TYPE_UNICODE) -- key.type for false alarm
    t.eq(key.code.codepoint, string.byte('P')) -- key.code.codepoint for false alarm
    t.eq(key.modifiers, termkey.TERMKEY_KEYMOD_ALT) -- key.modifiers for false alarm

    termkey.termkey_destroy(tk)
  end)
end)
