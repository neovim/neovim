local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local signal = require 'elisp.signal'
local b = require 'elisp.bytes'
local data = require 'elisp.data'
local fns = require 'elisp.fns'
local alloc = require 'elisp.alloc'
local chartab = require 'elisp.chartab'
local chars = require 'elisp.chars'
local specpdl = require 'elisp.specpdl'
local lread = require 'elisp.lread'

local current_global_map

local M = {}
local modifiers_t = {
  up = 1,
  down = 2,
  drag = 4,
  click = 8,
  double = 16,
  triple = 32,
}

---@type vim.elisp.F
local F = {}
F.make_keymap = {
  'make-keymap',
  0,
  1,
  0,
  [[Construct and return a new keymap, of the form (keymap CHARTABLE . ALIST).
CHARTABLE is a char-table that holds the bindings for all characters
without modifiers.  All entries in it are initially nil, meaning
"command undefined".  ALIST is an assoc-list which holds bindings for
function keys, mouse events, and any other things that appear in the
input stream.  Initially, ALIST is nil.

The optional arg STRING supplies a menu name for the keymap
in case you use it as a menu with `x-popup-menu'.]],
}
function F.make_keymap.f(s)
  local tail = not lisp.nilp(s) and lisp.list(s) or vars.Qnil
  return vars.F.cons(
    vars.Qkeymap,
    vars.F.cons(vars.F.make_char_table(vars.Qkeymap, vars.Qnil), tail)
  )
end
---@param error_if_not_keymap boolean
local function get_keymap(obj, error_if_not_keymap, autoload)
  if lisp.nilp(obj) then
    if error_if_not_keymap then
      signal.wrong_type_argument(vars.Qkeymapp, obj)
    end
    return vars.Qnil
  end
  if lisp.consp(obj) and lisp.eq(lisp.xcar(obj), vars.Qkeymap) then
    return obj
  end
  local tem = data.indirect_function(obj)
  if lisp.consp(tem) then
    if lisp.eq(lisp.xcar(tem), vars.Qkeymap) then
      return tem
    end
    if
      (autoload or not error_if_not_keymap)
      and lisp.eq(lisp.xcar(tem), vars.Qautoload)
      and lisp.symbolp(obj)
    then
      local tail = vars.F.nth(lisp.make_fixnum(4), tem)
      if lisp.eq(tail, vars.Qkeymap) then
        if autoload then
          error('TODO')
        else
          return obj
        end
      end
    end
  end
  if error_if_not_keymap then
    signal.wrong_type_argument(vars.Qkeymapp, obj)
  end
  return vars.Qnil
end
local function possibly_translate_key_sequence(key)
  if lisp.vectorp(key) and lisp.asize(key) == 1 and lisp.stringp(lisp.aref(key, 0)) then
    error('TODO')
  end
  return key
end
local function parse_modifiers_uncached(sym)
  lisp.check_symbol(sym)
  local mods = 0
  local name = lisp.symbol_name(sym)
  local i = 0
  if _G.vim_elisp_later then
    error('TODO: maybe ...-1 is incorrect, and it should just be ...')
  end
  while i < lisp.sbytes(name) - 1 do
    local this_mod_end = 0
    local this_mod = 0
    local c = lisp.sref(name, i)
    if c == 'A' then
      error('TODO')
    elseif c == 'C' then
      error('TODO')
    elseif c == 'H' then
      error('TODO')
    elseif c == 'M' then
      error('TODO')
    elseif c == 'S' then
      error('TODO')
    elseif c == 's' then
      error('TODO')
    elseif c == 'd' then
      error('TODO')
    elseif c == 't' then
      error('TODO')
    elseif c == 'u' then
      error('TODO')
    end
    if this_mod_end == 0 then
      break
    end
    error('TODO')
  end
  if
    (
      bit.band(
        mods,
        bit.bor(modifiers_t.down, modifiers_t.drag, modifiers_t.double, modifiers_t.triple)
      ) == 0
    )
    and i + 7 == lisp.sbytes(name)
    and lisp.sdata(name):sub(i - 1, i - 1 + 6) == 'mouse-'
    and b '0' <= lisp.sref(name, i + 6)
    and lisp.sref(name, i + 6) <= b '9'
  then
    error('TODO')
  end
  if
    (bit.band(mods, bit.bor(modifiers_t.double, modifiers_t.triple)) == 0)
    and i + 6 == lisp.sbytes(name)
    and lisp.sdata(name):sub(i - 1, i - 1 + 6) == 'mouse-'
  then
    error('TODO')
  end
  return mods, i
end
local function lispy_modifier_list(modifiers)
  local ret = vars.Qnil
  while modifiers > 0 do
    error('TODO')
  end
  return ret
end
local function parse_modifiers(sym)
  if lisp.fixnump(sym) then
    error('TODO')
  elseif not lisp.symbolp(sym) then
    error('TODO')
  end
  local elements = vars.F.get(sym, vars.Qevent_symbol_element_mask)
  if lisp.consp(elements) then
    return elements
  end
  local modifiers, end_ = parse_modifiers_uncached(sym)
  local unmodified =
    vars.F.intern(alloc.make_string(lisp.sdata(lisp.symbol_name(sym)):sub(end_ + 1)), vars.Qnil)
  local mask = lisp.make_fixnum(modifiers)
  elements = lisp.list(unmodified, mask)
  vars.F.put(sym, vars.Qevent_symbol_element_mask, elements)
  vars.F.put(
    sym,
    vars.Qevent_symbol_elements,
    vars.F.cons(unmodified, lispy_modifier_list(modifiers))
  )
  return elements
end
local function apply_modifiers_uncached(modifiers, base)
  local new_mods = {}
  for _, v in ipairs({
    { b.CHAR_ALT, 'A' },
    { b.CHAR_CTL, 'C' },
    { b.CHAR_HYPER, 'H' },
    { b.CHAR_SHIFT, 'S' },
    { b.CHAR_SUPER, 's' },
    { modifiers_t.double, 'double' },
    { modifiers_t.triple, 'triple' },
    { modifiers_t.up, 'up' },
    { modifiers_t.down, 'down' },
    { modifiers_t.drag, 'drag' },
    { modifiers_t.click, 'click' },
  }) do
    if bit.band(modifiers, v[1]) > 0 then
      table.insert(new_mods, v[2] .. '-')
    end
  end
  local new_name = alloc.make_multibyte_string(table.concat(new_mods) .. base, -1)
  return vars.F.intern(new_name, vars.Qnil)
end
local function apply_modifiers(modifiers, base)
  if lisp.fixnump(base) then
    error('TODO')
  end
  local cache = vars.F.get(base, vars.Qmodifier_cache)
  local idx = lisp.make_fixnum(bit.band(modifiers, bit.bnot(modifiers_t.click)))
  local entry = fns.assq_no_quit(idx, cache)
  local new_symbol
  if lisp.consp(entry) then
    new_symbol = lisp.xcdr(entry)
  else
    new_symbol = apply_modifiers_uncached(modifiers, lisp.sdata(lisp.symbol_name(base)))
    entry = vars.F.cons(idx, new_symbol)
    vars.F.put(base, vars.Qmodifier_cache, vars.F.cons(entry, cache))
  end
  if lisp.nilp(vars.F.get(new_symbol, vars.Qevent_kind)) then
    local kind = vars.F.get(base, vars.Qevent_kind)
    if not lisp.nilp(kind) then
      vars.F.put(new_symbol, vars.Qevent_kind, kind)
    end
  end
  return new_symbol
end
local function reorder_modifiers(sym)
  local parsed = parse_modifiers(sym)
  return apply_modifiers(lisp.fixnum(lisp.xcar(lisp.xcdr(parsed))), lisp.xcar(parsed))
end
local function store_in_keymap(keymap, idx, def, remove)
  if lisp.eq(idx, vars.Qkeymap) then
    signal.error("`keymap' is reserved for embedded parent maps")
  end
  if not lisp.consp(keymap) or not lisp.eq(lisp.xcar(keymap), vars.Qkeymap) then
    signal.error('attempt to define a key in a non-keymap')
  end
  if lisp.consp(idx) and lisp.chartablep(lisp.xcar(idx)) then
    error('TODO')
  else
    idx = lisp.event_head(idx)
  end
  if lisp.symbolp(idx) then
    idx = reorder_modifiers(idx)
  elseif lisp.fixnump(idx) then
    idx = lisp.make_fixnum(bit.band(lisp.fixnum(idx), bit.bor(b.CHAR_META, b.CHAR_META - 1)))
  end
  local tail = lisp.xcdr(keymap)
  local insertion_point = keymap
  while lisp.consp(tail) do
    local elt = lisp.xcar(tail)
    if lisp.vectorp(elt) then
      error('TODO')
    elseif lisp.chartablep(elt) then
      local sdef = def
      if remove then
        sdef = vars.Qnil
      elseif lisp.nilp(def) then
        sdef = vars.Qt
      end
      if lisp.fixnatp(idx) and bit.band(lisp.fixnum(idx), b.CHAR_MODIFIER_MASK) == 0 then
        vars.F.aset(elt, idx, sdef)
        return def
      end
      insertion_point = tail
    elseif lisp.consp(elt) then
      if lisp.eq(vars.Qkeymap, lisp.xcar(elt)) then
        error('TODO')
      elseif lisp.eq(idx, lisp.xcar(elt)) then
        if remove then
          error('TODO')
        else
          lisp.xsetcdr(elt, def)
        end
        return def
      elseif
        lisp.consp(idx)
        and lisp.chartablep(lisp.xcar(idx))
        and lisp.chartablep(lisp.xcar(elt))
      then
        error('TODO')
      end
    elseif lisp.eq(elt, vars.Qkeymap) then
      break
    end
    tail = lisp.xcdr(tail)
  end
  if not remove then
    local elt
    if lisp.consp(idx) and lisp.chartablep(lisp.xcar(idx)) then
      error('TODO')
    else
      elt = vars.F.cons(idx, def)
    end
    lisp.xsetcdr(insertion_point, vars.F.cons(elt, lisp.xcdr(insertion_point)))
  end
  return def
end
local function get_keyelt(obj, autoload)
  while true do
    if not lisp.consp(obj) then
      return obj
    elseif lisp.eq(lisp.xcar(obj), vars.Qmenu_item) then
      error('TODO')
    elseif lisp.stringp(lisp.xcar(obj)) then
      obj = lisp.xcdr(obj)
    else
      return obj
    end
  end
end
local function keymapp(m)
  return not lisp.nilp(get_keymap(m, false, false))
end
local function access_keymap_1(map, idx, t_ok, noinherit, autoload)
  idx = lisp.event_head(idx)
  if lisp.symbolp(idx) then
    idx = reorder_modifiers(idx)
  elseif lisp.fixnump(idx) then
    idx = lisp.make_fixnum(bit.band(lisp.fixnum(idx), bit.bor(b.CHAR_META, b.CHAR_META - 1)))
  end
  if lisp.fixnump(idx) and bit.band(lisp.fixnum(idx), b.CHAR_META) > 0 then
    error('TODO')
  end
  local tail = lisp.consp(map) and lisp.eq(vars.Qkeymap, lisp.xcar(map)) and lisp.xcdr(map) or map
  local retval = nil
  local t_bindning = nil
  while true do
    if not lisp.consp(tail) then
      tail = get_keymap(tail, false, autoload)
      if not lisp.consp(tail) then
        break
      end
    end

    local val = nil
    local binding = lisp.xcar(tail)
    local submap = get_keymap(binding, false, autoload)
    if lisp.eq(binding, vars.Qkeymap) then
      if noinherit or (retval == nil or lisp.nilp(retval)) then
        break
      end
      error('TODO')
    elseif lisp.consp(submap) then
      error('TODO')
    elseif lisp.consp(binding) then
      local key = lisp.xcar(binding)
      if lisp.eq(key, idx) then
        val = lisp.xcdr(binding)
      elseif t_ok and lisp.eq(key, vars.Qt) then
        error('TODO')
      end
    elseif lisp.vectorp(binding) then
      error('TODO')
    elseif lisp.chartablep(binding) then
      if lisp.fixnump(idx) and bit.band(lisp.fixnum(idx), b.CHAR_MODIFIER_MASK) == 0 then
        val = vars.F.aref(binding, idx)
        if lisp.nilp(val) then
          val = nil
        end
      end
    end
    if val then
      if lisp.eq(val, vars.Qt) then
        val = vars.Qnil
      end
      val = get_keyelt(val, autoload)
      if not keymapp(val) then
        error('TODO')
      elseif retval == nil or lisp.nilp(retval) then
        retval = val
      else
        error('TODO')
      end
    end

    tail = lisp.xcdr(tail)
  end
  return retval ~= nil and retval or (t_bindning ~= nil and get_keyelt(t_bindning, autoload) or nil)
end
---@return vim.elisp.obj
local function access_keymap(map, idx, t_ok, noinherit, autoload)
  return access_keymap_1(map, idx, t_ok, noinherit, autoload) or vars.Qnil
end
local function silly_event_symbol_error(sym)
  if _G.vim_elisp_later then
    error('TODO')
  end
end
local function define_as_prefix(keymap, c)
  local cmd = vars.F.make_sparse_keymap(vars.Qnil)
  store_in_keymap(keymap, c, cmd, false)
  return cmd
end
local function lucid_event_type_list_p(obj)
  if not lisp.consp(obj) then
    return false
  end
  local car = lisp.xcar(obj)
  if
    lisp.eq(car, vars.Qhelp_echo)
    or lisp.eq(car, vars.Qvertical_line)
    or lisp.eq(car, vars.Qmode_line)
    or lisp.eq(car, vars.Qtab_line)
    or lisp.eq(car, vars.Qheader_line)
  then
    return false
  end
  local tail = obj
  local ret = lisp.for_each_tail_safe(obj, function(o)
    local elt = lisp.xcar(o)
    if not (lisp.fixnump(elt) or lisp.symbolp(elt)) then
      return false
    end
    tail = lisp.xcdr(o)
  end)
  if ret ~= nil then
    return ret
  end
  return lisp.nilp(tail)
end
local function parse_solitary_modifier(sym)
  if not lisp.symbolp(sym) then
    return 0
  end
  local name = lisp.symbol_name(sym)
  local c = lisp.sref(name, 0)
  local r
  local function multi_letter_mod(bit, mname)
    if lisp.sdata(name) == mname then
      r = bit
      return true
    end
  end
  if c == b 'A' then
    error('TODO')
  elseif c == b 'a' then
    error('TODO')
  elseif c == b 'C' then
    error('TODO')
  elseif c == b 'c' then
    if multi_letter_mod(b.CHAR_CTL, 'ctrl') then
      return r
    end
    if multi_letter_mod(b.CHAR_CTL, 'control') then
      return r
    end
    error('TODO')
  elseif c == b 'H' then
    error('TODO')
  elseif c == b 'h' then
    error('TODO')
  elseif c == b 'M' then
    error('TODO')
  elseif c == b 'm' then
    if multi_letter_mod(b.CHAR_META, 'meta') then
      return r
    end
  elseif c == b 'S' then
    error('TODO')
  elseif c == b 's' then
    if multi_letter_mod(b.CHAR_SHIFT, 'shift') then
      return r
    end
    if multi_letter_mod(b.CHAR_SUPER, 'super') then
      return r
    end
    error('TODO')
  elseif c == b 'd' then
    error('TODO')
  elseif c == b 't' then
    error('TODO')
  elseif c == b 'u' then
    error('TODO')
  end
  return 0
end
---@param c number
---@return number
local function make_ctrl_char(c)
  if not chars.asciicharp(c) then
    return bit.bor(c, b.CHAR_CTL)
  end
  local upper = bit.band(c, bit.bnot(127))
  c = bit.band(c, 127)
  if c >= 64 and c < 96 then
    local oc = c
    c = bit.band(c, bit.bnot(96))
    if oc >= b 'A' and oc <= b 'Z' then
      c = bit.bor(c, b.CHAR_SHIFT)
    end
  elseif c >= b 'a' and c <= b 'z' then
    c = bit.band(c, bit.bnot(96))
  elseif c >= b ' ' then
    c = bit.bor(c, b.CHAR_CTL)
  end
  c = bit.bor(c, bit.band(upper, bit.bnot(b.CHAR_CTL)))
  return c
end
F.event_convert_list = {
  'event-convert-list',
  1,
  1,
  0,
  [[Convert the event description list EVENT-DESC to an event type.
EVENT-DESC should contain one base event type (a character or symbol)
and zero or more modifier names (control, meta, hyper, super, shift, alt,
drag, down, double or triple).  The base must be last.

The return value is an event type (a character or symbol) which has
essentially the same base event type and all the specified modifiers.
(Some compatibility base types, like symbols that represent a
character, are not returned verbatim.)]],
}
function F.event_convert_list.f(event_desc)
  local base = vars.Qnil
  local modifiers = 0
  lisp.for_each_tail_safe(event_desc, function(tail)
    local elt = lisp.xcar(tail)
    local this = 0
    if lisp.symbolp(elt) and lisp.consp(lisp.xcdr(tail)) then
      this = parse_solitary_modifier(elt)
    end
    if this ~= 0 then
      modifiers = bit.bor(modifiers, this)
    elseif not lisp.nilp(base) then
      signal.error('Two bases given in one event')
    else
      base = elt
    end
  end)
  if lisp.symbolp(base) and lisp.schars(lisp.symbol_name(base)) == 1 then
    error('TODO')
  end
  if lisp.fixnump(base) then
    if
      bit.band(modifiers, b.CHAR_SHIFT) > 0
      and lisp.fixnum(base) >= b 'a'
      and lisp.fixnum(base) <= b 'z'
    then
      base = lisp.make_fixnum(lisp.fixnum(base) - (b 'a' - b 'A'))
      modifiers = bit.band(modifiers, bit.bnot(b.CHAR_SHIFT))
    end
    if bit.band(modifiers, b.CHAR_CTL) > 0 then
      return lisp.make_fixnum(
        bit.bor(bit.band(modifiers, bit.bnot(b.CHAR_CTL)), make_ctrl_char(lisp.fixnum(base)))
      )
    else
      return lisp.make_fixnum(bit.bor(modifiers, lisp.fixnum(base)))
    end
  elseif lisp.symbolp(base) then
    return apply_modifiers(modifiers, base)
  else
    signal.error('Invalid base event')
    error('unreachable')
  end
end
F.define_key = {
  'define-key',
  3,
  4,
  0,
  [[In KEYMAP, define key sequence KEY as DEF.
This is a legacy function; see `keymap-set' for the recommended
function to use instead.

KEYMAP is a keymap.

KEY is a string or a vector of symbols and characters, representing a
sequence of keystrokes and events.  Non-ASCII characters with codes
above 127 (such as ISO Latin-1) can be represented by vectors.
Two types of vector have special meanings:
 [remap COMMAND] remaps any key binding for COMMAND.
 [t] creates a default definition, which applies to any event with no
    other definition in KEYMAP.

DEF is anything that can be a key's definition:
 nil (means key is undefined in this keymap),
 a command (a Lisp function suitable for interactive calling),
 a string (treated as a keyboard macro),
 a keymap (to define a prefix key),
 a symbol (when the key is looked up, the symbol will stand for its
    function definition, which should at that time be one of the above,
    or another symbol whose function definition is used, etc.),
 a cons (STRING . DEFN), meaning that DEFN is the definition
    (DEFN should be a valid definition in its own right) and
    STRING is the menu item name (which is used only if the containing
    keymap has been created with a menu name, see `make-keymap'),
 or a cons (MAP . CHAR), meaning use definition of CHAR in keymap MAP,
 or an extended menu item definition.
 (See info node `(elisp)Extended Menu Items'.)

If REMOVE is non-nil, the definition will be removed.  This is almost
the same as setting the definition to nil, but makes a difference if
the KEYMAP has a parent, and KEY is shadowing the same binding in the
parent.  With REMOVE, subsequent lookups will return the binding in
the parent, and with a nil DEF, the lookups will return nil.

If KEYMAP is a sparse keymap with a binding for KEY, the existing
binding is altered.  If there is no binding for KEY, the new pair
binding KEY to DEF is added at the front of KEYMAP.]],
}
function F.define_key.f(keymap, key, def, remove)
  keymap = get_keymap(keymap, true, true)
  local length = lisp.check_vector_or_string(key)
  if length == 0 then
    return vars.Qnil
  end
  local meta_bit = (lisp.vectorp(key) or (lisp.stringp(key) and lisp.string_multibyte(key)))
      and b.CHAR_META
    or 0x80
  if lisp.vectorp(def) and lisp.asize(def) > 0 and lisp.consp(lisp.aref(def, 0)) then
    local tmp = alloc.make_vector(lisp.asize(def), 'nil')
    for i = lisp.asize(def) - 1, 0, -1 do
      local defi = lisp.aref(def, i)
      if lisp.consp(defi) and lucid_event_type_list_p(defi) then
        defi = vars.F.event_convert_list(defi)
      end
      lisp.aset(tmp, i, defi)
    end
    def = tmp
  end
  key = possibly_translate_key_sequence(key)
  local idx = 0
  local metized = false
  while true do
    local c = vars.F.aref(key, lisp.make_fixnum(idx))
    if lisp.consp(c) then
      if lucid_event_type_list_p(c) then
        c = vars.F.event_convert_list(c)
      elseif chars.characterp(lisp.xcar(c)) then
        chars.check_character(lisp.xcdr(c))
      end
    end
    if lisp.symbolp(c) then
      silly_event_symbol_error(c)
    end
    if lisp.fixnump(c) and bit.band(lisp.fixnum(c), meta_bit) > 0 and not metized then
      c = vars.V.meta_prefix_char
      metized = true
    else
      if lisp.fixnump(c) then
        c = lisp.make_fixnum(bit.band(lisp.fixnum(c), bit.bnot(meta_bit)))
      end
      metized = false
      idx = idx + 1
    end
    if
      not lisp.fixnump(c)
      and not lisp.symbolp(c)
      and (not lisp.consp(c) or (lisp.fixnump(lisp.xcar(c)) and idx ~= length))
    then
      error('TODO')
    end
    if idx == length then
      return store_in_keymap(keymap, c, def, not lisp.nilp(remove))
    end
    local cmd = access_keymap(keymap, c, false, true, true)
    if lisp.nilp(cmd) then
      cmd = define_as_prefix(keymap, c)
    end
    keymap = get_keymap(cmd, false, true)
    if not lisp.consp(keymap) then
      error('TODO')
    end
  end
end
F.make_sparse_keymap = {
  'make-sparse-keymap',
  0,
  1,
  0,
  [[Construct and return a new sparse keymap.
Its car is `keymap' and its cdr is an alist of (CHAR . DEFINITION),
which binds the character CHAR to DEFINITION, or (SYMBOL . DEFINITION),
which binds the function key or mouse event SYMBOL to DEFINITION.
Initially the alist is nil.

The optional arg STRING supplies a menu name for the keymap
in case you use it as a menu with `x-popup-menu'.]],
}
function F.make_sparse_keymap.f(s)
  if not lisp.nilp(s) then
    return lisp.list(vars.Qkeymap, s)
  end
  return lisp.list(vars.Qkeymap)
end
F.use_global_map = { 'use-global-map', 1, 1, 0, [[Select KEYMAP as the global keymap.]] }
function F.use_global_map.f(keymap)
  keymap = get_keymap(keymap, true, true)
  current_global_map = keymap
  if _G.vim_elisp_later then
    error('TODO')
  end
  return vars.Qnil
end
local function keymap_parent(keymap, autoload)
  keymap = get_keymap(keymap, true, autoload)
  local list = lisp.xcdr(keymap)
  while lisp.consp(list) do
    if keymapp(list) then
      return list
    end
    list = lisp.xcdr(list)
  end
  return get_keymap(list, false, autoload)
end
local function keymap_memberp(map, maps)
  if lisp.nilp(map) then
    return false
  end
  while keymapp(maps) and not lisp.eq(map, maps) do
    maps = keymap_parent(maps, false)
  end
  return lisp.eq(map, maps)
end
F.set_keymap_parent = {
  'set-keymap-parent',
  2,
  2,
  0,
  [[Modify KEYMAP to set its parent map to PARENT.
Return PARENT.  PARENT should be nil or another keymap.]],
}
function F.set_keymap_parent.f(keymap, parent)
  keymap = get_keymap(keymap, true, true)
  if not lisp.nilp(parent) then
    parent = get_keymap(parent, true, false)
    if keymap_memberp(keymap, parent) then
      signal.error('Cyclic keymap inheritance')
    end
  end
  local prev = keymap
  while true do
    local list = lisp.xcdr(prev)
    if not lisp.consp(list) or keymapp(list) then
      lisp.xsetcdr(prev, parent)
      return parent
    end
    prev = list
  end
end
F.keymapp = {
  'keymapp',
  1,
  1,
  0,
  [[Return t if OBJECT is a keymap.

A keymap is a list (keymap . ALIST),
or a symbol whose function definition is itself a keymap.
ALIST elements look like (CHAR . DEFN) or (SYMBOL . DEFN);
a vector of densely packed bindings for small character codes
is also allowed as an element.]],
}
function F.keymapp.f(obj)
  return keymapp(obj) and vars.Qt or vars.Qnil
end
F.current_global_map = { 'current-global-map', 0, 0, 0, [[Return the current global keymap.]] }
function F.current_global_map.f()
  return current_global_map
end
local function lookup_key_1(keymap, key, accept_default)
  local t_ok = not lisp.nilp(accept_default)
  if not lisp.consp(keymap) and not lisp.nilp(keymap) then
    keymap = get_keymap(keymap, true, true)
  end
  local length = lisp.check_vector_or_string(key)
  if length == 0 then
    return keymap
  end
  key = possibly_translate_key_sequence(key)
  local idx = 0
  while true do
    local c = vars.F.aref(key, lisp.make_fixnum(idx))
    idx = idx + 1
    if lisp.consp(c) and lucid_event_type_list_p(c) then
      error('TODO')
    end
    if
      lisp.stringp(key)
      and bit.band(lisp.fixnum(c), 0x80) > 0
      and not lisp.string_multibyte(key)
    then
      error('TODO')
    end
    if
      not lisp.fixnump(c)
      and not lisp.symbolp(c)
      and not lisp.consp(c)
      and not lisp.stringp(c)
    then
      error('TODO')
    end
    local cmd = access_keymap(keymap, c, t_ok, false, true)
    if idx == length then
      return cmd
    end
    keymap = get_keymap(cmd, false, true)
    if not lisp.consp(keymap) then
      return lisp.make_fixnum(idx)
    end
  end
end
F.lookup_key = {
  'lookup-key',
  2,
  3,
  0,
  [[Look up key sequence KEY in KEYMAP.  Return the definition.
This is a legacy function; see `keymap-lookup' for the recommended
function to use instead.

A value of nil means undefined.  See doc of `define-key'
for kinds of definitions.

A number as value means KEY is "too long";
that is, characters or symbols in it except for the last one
fail to be a valid sequence of prefix characters in KEYMAP.
The number is how many characters at the front of KEY
it takes to reach a non-prefix key.
KEYMAP can also be a list of keymaps.

Normally, `lookup-key' ignores bindings for t, which act as default
bindings, used when nothing else in the keymap applies; this makes it
usable as a general function for probing keymaps.  However, if the
third optional argument ACCEPT-DEFAULT is non-nil, `lookup-key' will
recognize the default bindings, just as `read-key-sequence' does.]],
}
function F.lookup_key.f(keymap, key, accept_default)
  local found = lookup_key_1(keymap, key, accept_default)
  if not lisp.nilp(found) and not lisp.numberp(found) then
    return found
  end
  if lisp.vectorp(key) and lisp.asize(key) > 0 and lisp.eq(lisp.aref(key, 0), vars.Qmenu_bar) then
  else
    return found
  end
  local key_len = lisp.asize(key)
  local new_key = alloc.make_vector(key_len, vars.Qnil)
  local function f(tbl)
    for i = 0, key_len - 1 do
      local item = lisp.aref(key, i)
      if not lisp.symbolp(item) then
        lisp.aset(new_key, i, item)
      else
        local key_item = vars.F.symbol_name(item)
        local new_item
        if not lisp.string_multibyte(key_item) then
          new_item = vars.F.downcase(item)
        else
          error('TODO')
        end
        lisp.aset(new_key, i, vars.F.intern(new_item, vars.Qnil))
      end
    end
    found = lookup_key_1(keymap, new_key, accept_default)
    if not lisp.nilp(found) and not lisp.numberp(found) then
      return true
    end
    for i = 0, key_len - 1 do
      if not lisp.symbolp(lisp.aref(new_key, i)) then
        goto continue
      end
      local lc_key = vars.F.symbol_name(lisp.aref(new_key, i))
      if not lisp.sdata(lc_key):find(' ') then
        goto continue
      end
      error('TODO')
      ::continue::
    end
    found = lookup_key_1(keymap, new_key, accept_default)
    if not lisp.nilp(found) and not lisp.numberp(found) then
      return true
    end
  end
  if
    f(--[[unicode_case_table]])
  then
    return found
  end
  if
    f(--[[vars.F.current_case_table()]])
  then
    return found
  end
  return found
end
local function map_keymap_call(key, val, fun)
  vars.F.funcall({ fun, key, val })
end
local function map_keymap_item(fun, args, key, val)
  if lisp.eq(val, vars.Qt) then
    val = vars.Qnil
  end
  fun(key, val, args)
end
local function map_keymap_internal(map, fun, args)
  local tail = (lisp.consp(map) and lisp.eq(vars.Qkeymap, lisp.xcar(map))) and lisp.xcdr(map) or map
  while lisp.consp(tail) and not lisp.eq(vars.Qkeymap, lisp.xcar(tail)) do
    local binding = lisp.xcar(tail)
    if keymapp(binding) then
      break
    elseif lisp.consp(binding) then
      map_keymap_item(fun, args, lisp.xcar(binding), lisp.xcdr(binding))
    elseif lisp.vectorp(binding) then
      for c = 0, lisp.asize(binding) - 1 do
        map_keymap_item(fun, args, lisp.make_fixnum(c), lisp.aref(binding, c))
      end
    elseif lisp.chartablep(binding) then
      chartab.map_char_table(function(key, val)
        if lisp.nilp(val) then
          return
        end
        if lisp.consp(key) then
          key = vars.F.cons(lisp.xcar(key), lisp.xcdr(key))
        end
        map_keymap_item(fun, args, key, val)
      end, vars.Qnil, binding)
    end
    tail = lisp.xcdr(tail)
  end
  return tail
end
local function map_keymap(map, fun, args, autoload)
  map = get_keymap(map, true, autoload)
  while lisp.consp(map) do
    if keymapp(lisp.xcar(map)) then
      map_keymap(lisp.xcar(map), fun, args, autoload)
      map = lisp.xcdr(map)
    else
      map = map_keymap_internal(map, fun, args)
    end
    if not lisp.consp(map) then
      map = get_keymap(map, false, autoload)
    end
  end
end
F.map_keymap = {
  'map-keymap',
  2,
  3,
  0,
  [[Call FUNCTION once for each event binding in KEYMAP.
FUNCTION is called with two arguments: the event that is bound, and
the definition it is bound to.  The event may be a character range.

If KEYMAP has a parent, the parent's bindings are included as well.
This works recursively: if the parent has itself a parent, then the
grandparent's bindings are also included and so on.

For more information, see Info node `(elisp) Keymaps'.

usage: (map-keymap FUNCTION KEYMAP)]],
}
function F.map_keymap.f(function_, keymap, sorf_first)
  if not lisp.nilp(sorf_first) then
    error('TODO')
  end
  map_keymap(keymap, map_keymap_call, function_, true)
  return vars.Qnil
end
---@param ch number
---@return string
local function key_description(ch)
  local p = ''
  local c = bit.band(ch, bit.bor(b.CHAR_META, bit.bnot(-b.CHAR_META)))
  local c2 = bit.band(
    c,
    bit.bnot(bit.bor(b.CHAR_ALT, b.CHAR_CTL, b.CHAR_HYPER, b.CHAR_META, b.CHAR_SHIFT, b.CHAR_SUPER))
  )
  if not chars.characterp(lisp.make_fixnum(c)) then
    error('TODO')
  end
  local tab_as_ci = (c2 == b '\t' and bit.band(c, b.CHAR_META) ~= 0)
  if bit.band(c, b.CHAR_ALT) ~= 0 then
    error('TODO')
  end
  if
    bit.band(c, b.CHAR_CTL) ~= 0
    or (c2 < b ' ' and c2 ~= 27 and c2 ~= b '\t' and c2 ~= b '\r')
    or tab_as_ci
  then
    p = p .. 'C-'
    c = bit.band(c, bit.bnot(b.CHAR_CTL))
  end
  if bit.band(c, b.CHAR_HYPER) ~= 0 then
    error('TODO')
  end
  if bit.band(c, b.CHAR_META) ~= 0 then
    error('TODO')
  end
  if bit.band(c, b.CHAR_SHIFT) ~= 0 then
    error('TODO')
  end
  if bit.band(c, b.CHAR_SUPER) ~= 0 then
    error('TODO')
  end
  if c < 32 then
    if c == 27 then
      error('TODO')
    elseif tab_as_ci then
      error('TODO')
    elseif c == b '\t' then
      error('TODO')
    elseif
      c == b '\r' --[[ctrl-m]]
    then
      error('TODO')
    else
      if
        c > 0 and c <= 26 --[[ctrl-z]]
      then
        p = p .. string.char(c + 96)
      else
        p = p .. string.char(c + 64)
      end
    end
  elseif c == 127 then
    error('TODO')
  elseif c == b ' ' then
    error('TODO')
  elseif c < 128 then
    p = p .. string.char(c)
  else
    error('TODO')
  end
  return p
end
F.single_key_description = {
  'single-key-description',
  1,
  2,
  0,
  [[Return a pretty description of a character event KEY.
Control characters turn into C-whatever, etc.
Optional argument NO-ANGLES non-nil means don't put angle brackets
around function keys and event symbols.

See `text-char-description' for describing character codes.]],
}
function F.single_key_description.f(key, no_angles)
  if lisp.consp(key) and lucid_event_type_list_p(key) then
    error('TODO')
  end
  if lisp.consp(key) and lisp.fixnump(lisp.xcar(key)) and lisp.fixnump(lisp.xcdr(key)) then
    error('TODO')
  end
  key = lisp.event_head(key)
  if lisp.fixnump(key) then
    local p = key_description(lisp.fixnum(key))
    return alloc.make_specified_string(p, -1, true)
  else
    error('TODO')
  end
end
F.key_description = {
  'key-description',
  1,
  2,
  0,
  [[Return a pretty description of key-sequence KEYS.
Optional arg PREFIX is the sequence of keys leading up to KEYS.
For example, [?\\C-x ?l] is converted into the string \"C-x l\".

For an approximate inverse of this, see `kbd'.]],
}
function F.key_description.f(keys, prefix)
  local add_meta = false
  local lists = { prefix, keys }
  local args = {}
  local sep = alloc.make_string(' ')
  for _, list in ipairs(lists) do
    if not (lisp.nilp(list) or lisp.stringp(list) or lisp.vectorp(list) or lisp.consp(list)) then
      signal.wrong_type_argument(vars.Qarrayp, list)
    end
    local listlen = lisp.fixnum(vars.F.length(list))
    local i = 0
    local i_bytes = 0
    while i < listlen do
      local key
      if lisp.stringp(list) then
        local c, bytes = chars.fetchstringcharadvance(list, i_bytes)
        i_bytes = i_bytes + bytes
        i = i + 1
        if chars.singlebytecharp(c) and bit.band(c, 128) ~= 0 then
          c = bit.bxor(c, bit.bor(128, b.CHAR_META))
        end
        key = lisp.make_fixnum(c)
      else
        error('TODO')
      end
      if add_meta then
        error('TODO')
      elseif lisp.eq(key, vars.V.meta_prefix_char) then
        error('TODO')
      end
      table.insert(args, vars.F.single_key_description(key, vars.Qnil))
      table.insert(args, sep)
    end
  end
  if add_meta then
    error('TODO')
  elseif #args == 0 then
    return alloc.make_string('')
  else
    table.remove(args, #args)
    return vars.F.concat(args)
  end
end
F.recursive_edit = {
  'recursive-edit',
  0,
  0,
  '',
  [[Invoke the editor command loop recursively.
To get out of the recursive edit, a command can throw to `exit' -- for
instance (throw \\='exit nil).

The following values (last argument to `throw') can be used when
throwing to \\='exit:

- t causes `recursive-edit' to quit, so that control returns to the
  command loop one level up.

- A string causes `recursive-edit' to signal an error, printing that
  string as the error message.

- A function causes `recursive-edit' to call that function with no
  arguments, and then return normally.

- Any other value causes `recursive-edit' to return normally to the
  function that called it.

This function is called by the editor initialization to begin editing.]],
}
function F.recursive_edit.f()
  if _G.vim_elisp_later then
    local count = specpdl.index()
    error('TODO: temporarily_switch_to_single_kboard')
  end
  require 'elisp.main_thread'.recursive_edit()
  return vars.Qnil
end

function M.init()
  vars.F.put(vars.Qkeymap, vars.Qchar_table_extra_slots, lisp.make_fixnum(0))

  vars.modifier_symbols = {}
  for _, v in ipairs({
    'up',
    'dow',
    'drag',
    'click',
    'double',
    'triple',
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    'alt',
    'super',
    'hyper',
    'shift',
    'control',
    'meta',
  }) do
    if v == 0 then
      table.insert(vars.modifier_symbols, 0)
    else
      local sym = lisp.make_empty_ptr(lisp.type.symbol)
      lread.define_symbol(sym, v)
      table.insert(vars.modifier_symbols, sym)
    end
  end

  vars.V.minibuffer_local_map = vars.F.make_sparse_keymap(vars.Qnil)
  vars.V.function_key_map = vars.F.make_sparse_keymap(vars.Qnil)
  vars.V.key_translation_map = vars.F.make_sparse_keymap(vars.Qnil)
  current_global_map = vars.Qnil
  vars.V.special_event_map = lisp.list(vars.Qkeymap)

  vars.V.command_error_function = lread.intern('command-error-default-function')
end

function M.init_syms()
  vars.defsubr(F, 'make_keymap')
  vars.defsubr(F, 'event_convert_list')
  vars.defsubr(F, 'define_key')
  vars.defsubr(F, 'make_sparse_keymap')
  vars.defsubr(F, 'use_global_map')
  vars.defsubr(F, 'set_keymap_parent')
  vars.defsubr(F, 'keymapp')
  vars.defsubr(F, 'current_global_map')
  vars.defsubr(F, 'lookup_key')
  vars.defsubr(F, 'map_keymap')
  vars.defsubr(F, 'single_key_description')
  vars.defsubr(F, 'key_description')
  vars.defsubr(F, 'recursive_edit')

  vars.defvar_lisp(
    'minibuffer_local_map',
    'minibuffer-local-map',
    [[Default keymap to use when reading from the minibuffer.]]
  )

  vars.defvar_lisp(
    'function_key_map',
    'function-key-map',
    [[The parent keymap of all `local-function-key-map' instances.
Function key definitions that apply to all terminal devices should go
here.  If a mapping is defined in both the current
`local-function-key-map' binding and this variable, then the local
definition will take precedence.]]
  )

  vars.defsym('Qkeymap', 'keymap')
  vars.defsym('Qkeymapp', 'keymapp')
  vars.defsym('Qmenu_item', 'menu-item')
  vars.defsym('Qevent_symbol_element_mask', 'event-symbol-element-mask')
  vars.defsym('Qevent_symbol_elements', 'event-symbol-elements')
  vars.defsym('Qmodifier_cache', 'modifier-cache')
  vars.defsym('Qevent_kind', 'event-kind')

  vars.defsym('Qhelp_echo', 'help-echo')
  vars.defsym('Qvertical_line', 'vertical-line')
  vars.defsym('Qmode_line', 'mode-line')
  vars.defsym('Qmenu_bar', 'menu-bar')
  vars.defsym('Qtab_line', 'tab-line')
  vars.defsym('Qheader_line', 'header-line')

  vars.defvar_lisp(
    'meta_prefix_char',
    'meta-prefix-char',
    [[Meta-prefix character code.
Meta-foo as command input turns into this character followed by foo.]]
  )
  vars.V.meta_prefix_char = lisp.make_fixnum(27)

  vars.defvar_lisp(
    'special_event_map',
    'special-event-map',
    [[Keymap defining bindings for special events to execute at low level.]]
  )

  vars.defvar_lisp(
    'minor_mode_map_alist',
    'minor-mode-map-alist',
    [[Alist of keymaps to use for minor modes.
Each element looks like (VARIABLE . KEYMAP); KEYMAP is used to read
key sequences and look up bindings if VARIABLE's value is non-nil.
If two active keymaps bind the same key, the keymap appearing earlier
in the list takes precedence.]]
  )
  vars.V.minor_mode_map_alist = vars.Qnil

  vars.defvar_lisp(
    'help_char',
    'help-char',
    [[Character to recognize as meaning Help.
    When it is read, do `(eval help-form)', and display result if it's a string.
    If the value of `help-form' is nil, this char can be read normally.]]
  )
  vars.V.help_char = lisp.make_fixnum(8) -- ctrl-h

  vars.defvar_lisp(
    'command_error_function',
    'command-error-function',
    [[Function to output error messages.
Called with three arguments:
- the error data, a list of the form (SIGNALED-CONDITION . SIGNAL-DATA)
  such as what `condition-case' would bind its variable to,
- the context (a string which normally goes at the start of the message),
- the Lisp function within which the error was signaled.

For instance, to make error messages stand out more in the echo area,
you could say something like:

    (setq command-error-function
          (lambda (data _ _)
            (message "%s" (propertize (error-message-string data)
                                      \\='face \\='error))))

Also see `set-message-function' (which controls how non-error messages
are displayed).]]
  )

  vars.defvar_lisp(
    'key_translation_map',
    'key-translation-map',
    [[Keymap of key translations that can override keymaps.
This keymap works like `input-decode-map', but comes after `function-key-map'.
Another difference is that it is global rather than terminal-local.]]
  )
end
return M
