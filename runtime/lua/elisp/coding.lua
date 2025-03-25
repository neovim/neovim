local vars = require 'elisp.vars'
local alloc = require 'elisp.alloc'
local b = require 'elisp.bytes'
local lisp = require 'elisp.lisp'
local lread = require 'elisp.lread'
local chars = require 'elisp.chars'
local signal = require 'elisp.signal'
local fns = require 'elisp.fns'
local charset = require 'elisp.charset'

---@class vim.elisp.coding_system
---@field id number
---@field common_flags number
---@field mode number
---@field src_multibyte boolean
---@field dst_multibyte boolean
---@field char_at_source boolean
---@field raw_destination boolean
---@field annotated boolean
---@field eol_seen number
---@field max_charset_id number
---@field safe_charsets string
---@field carryover_bytes number
---@field default_char number
---@field detector (fun(c:vim.elisp.coding_system,i:vim.elisp.coding_detection_info):boolean)|0
---@field decoder fun(c:vim.elisp.coding_system)
---@field encoder fun(c:vim.elisp.coding_system):boolean
---@field spec_undecided vim.elisp.coding_undecided_spec?
---@field spec_emacs_mule vim.elisp.coding_emacs_mule_spec?
---@field spec_utf_8_bom vim.elisp.coding_utf_bom_type?
---@field spec_utf_16 vim.elisp.coding_utf_16_spec
---@field spec_iso_2022 vim.elisp.coding_iso_2022_spec
---@class vim.elisp.coding_undecided_spec
---@field inhibit_nbd number
---@field inhibit_ied number
---@field prefer_utf_8 boolean
---@class vim.elisp.coding_emacs_mule_spec: vim.elisp.coding_composition_status
---@class vim.elisp.coding_composition_status
---@field state vim.elisp.coding_composition_state
---@field method vim.elisp.coding_composition_method
---@field old_form boolean
---@field length number
---@field nchars number
---@field ncomps number
---@field carryover number[]
---@class vim.elisp.coding_utf_16_spec
---@field bom vim.elisp.coding_utf_bom_type
---@field endian vim.elisp.coding_utf_16_endian_type
---@field surrogate number
---@class vim.elisp.coding_iso_2022_spec
---@field flags number
---@field current_invocation number[] (0-indexed)
---@field current_designation number[] (0-indexed)
---@field ctext_extended_segment_len number
---@field single_shifting boolean
---@field bol boolean
---@field embedded_utf_8 boolean
---@field cmp_status vim.elisp.coding_composition_status

---@enum vim.elisp.coding_arg
local coding_arg = {
  name = 1,
  mnemonic = 2,
  coding_type = 3,
  charset_list = 4,
  ascii_compatible_p = 5,
  decode_translation_table = 6,
  encode_translation_table = 7,
  post_read_conversion = 8,
  pre_write_conversion = 9,
  default_char = 10,
  for_unibyte = 11,
  plist = 12,
  eol_type = 13,
  max = 13,
}
---@enum vim.elisp.coding_arg_undecided
local coding_arg_undecided = {
  inhibit_null_byte_detection = coding_arg.max + 1,
  inhibit_iso_escape_detection = coding_arg.max + 2,
  prefer_utf_8 = coding_arg.max + 3,
  max = coding_arg.max + 3,
}
---@enum vim.elisp.coding_arg_utf_8
local coding_arg_utf_8 = {
  bom = coding_arg.max + 1,
  max = coding_arg.max + 1,
}
---@enum vim.elisp.coding_arg_utf_16
local coding_arg_utf_16 = {
  bom = coding_arg.max + 1,
  endian = coding_arg.max + 2,
  max = coding_arg.max + 2,
}
---@enum vim.elisp.coding_arg_iso_2022
local coding_arg_iso_2022 = {
  initial = coding_arg.max + 1,
  reg_usage = coding_arg.max + 2,
  request = coding_arg.max + 3,
  flags = coding_arg.max + 4,
  max = coding_arg.max + 4,
}
---@enum vim.elisp.coding_attr
local coding_attr = {
  base_name = 0,
  docstring = 1,
  mnemonic = 2,
  type = 3,
  charset_list = 4,
  ascii_compat = 5,
  decode_tbl = 6,
  encode_tbl = 7,
  trans_tbl = 8,
  post_read = 9,
  pre_write = 10,
  default_char = 11,
  for_unibyte = 12,
  plist = 13,
  category = 14,
  safe_charsets = 15,
  charset_valids = 16,
  ccl_decoder = 17,
  ccl_encoder = 18,
  ccl_valids = 19,
  iso_initial = 20,
  iso_usage = 21,
  iso_request = 22,
  iso_flags = 23,
  utf_bom = 24,
  utf_16_endian = 25,
  emacs_mule_full = 26,
  undecided_inhibit_null_byte_detection = 27,
  undecided_inhibit_iso_escape_detection = 28,
  undecided_prefer_utf_8 = 29,
  last_index = 30,
}
---@enum vim.elisp.coding_category
local coding_category = {
  iso_7 = 0,
  iso_7_tight = 1,
  iso_8_1 = 2,
  iso_8_2 = 3,
  iso_7_else = 4,
  iso_8_else = 5,
  utf_8_auto = 6,
  utf_8_nosig = 7,
  utf_8_sig = 8,
  utf_16_auto = 9,
  utf_16_be = 10,
  utf_16_le = 11,
  utf_16_be_nosig = 12,
  utf_16_le_nosig = 13,
  charset = 14,
  sjis = 15,
  big5 = 16,
  ccl = 17,
  emacs_mule = 18,
  raw_text = 19,
  undecided = 20,
  max = 21,
}
local coding_mask = {
  annotation = 0x00ff,
  annotate_composition = 0x0001,
  annotate_direction = 0x0002,
  annotate_charset = 0x0003,
  for_unibyte = 0x0100,
  require_flushing = 0x0200,
  require_decoding = 0x0400,
  require_encoding = 0x0800,
  require_detection = 0x1000,
  reset_at_bol = 0x2000,
}
---@enum vim.elisp.coding_composition_state
local coding_composition_state = {
  no = 0,
  char = 1,
  rule = 2,
  component_char = 3,
  component_rule = 4,
}
---@enum vim.elisp.coding_composition_method
local coding_composition_method = {
  relative = 0,
  with_rule = 1,
  with_altchars = 2,
  with_rule_altchars = 3,
  no = 4,
}
---@enum vim.elisp.coding_utf_bom_type
local coding_utf_bom_type = {
  detect = 0,
  without = 1,
  with = 2,
}
---@enum vim.elisp.coding_utf_16_endian_type
local coding_utf_16_endian_type = {
  big = 0,
  little = 1,
}
local coding_iso_flag = {
  long_form = 0x0001,
  reset_at_eol = 0x0002,
  reset_at_cntl = 0x0004,
  seven_bits = 0x0008,
  locking_shift = 0x0010,
  single_shift = 0x0020,
  designation = 0x0040,
  revision = 0x0080,
  direction = 0x0100,
  init_at_bol = 0x0200,
  designate_at_bol = 0x0400,
  safe = 0x0800,
  latin_extra = 0x1000,
  composition = 0x2000,
  use_roman = 0x8000,
  use_oldjis = 0x10000,
  level_4 = 0x20000,
  full_support = 0x100000,
}
local coding_mode = {
  last_block = 0x01,
  selective_display = 0x02,
  direction = 0x04,
  fixed_destination = 0x08,
  safe_encoding = 0x10,
}

---@type table<vim.elisp.coding_category,vim.elisp.coding_system>
---(0-indexed)
local coding_categories = {}
---@type vim.elisp.coding_category[]
---(0-indexed)
local coding_priorities = {}

local M = {}
function M.encode_file_name(s)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return s
end

---@type vim.elisp.F
local F = {}
local function coding_system_spec(coding_system_symbol)
  return vars.F.gethash(coding_system_symbol, vars.coding_system_hash_table, vars.Qnil)
end
local function coding_system_id(coding_system_symbol)
  return fns.hash_lookup(
    vars.coding_system_hash_table --[[@as vim.elisp._hash_table]],
    coding_system_symbol
  )
end
local function check_coding_system_get_spec(x)
  local spec = coding_system_spec(x)
  if lisp.nilp(spec) then
    error('TODO')
  end
  return spec
end
local function check_coding_system_get_id(x)
  local id = coding_system_id(x)
  if id < 0 then
    error('TODO')
  end
  return id
end
local function check_coding_system(x)
  if coding_system_id(x) < 0 then
    error('TODO')
  end
end
local function coding_id_name(id)
  return lisp.aref(
    (vars.coding_system_hash_table --[[@as vim.elisp._hash_table]]).key_and_value,
    id * 2
  )
end
local function coding_id_attrs(id)
  return lisp.aref(
    lisp.aref(
      (vars.coding_system_hash_table --[[@as vim.elisp._hash_table]]).key_and_value,
      id * 2 + 1
    ),
    0
  )
end
local function coding_id_eol_type(id)
  return lisp.aref(
    lisp.aref(
      (vars.coding_system_hash_table --[[@as vim.elisp._hash_table]]).key_and_value,
      id * 2 + 1
    ),
    2
  )
end
local function coding_system_p(coding_system)
  return coding_system_id(coding_system) >= 0 or error('TODO')
end
---@return number
local function encode_inhibit_flag(flag)
  return (lisp.nilp(flag) and -1) or (lisp.eq(flag, vars.Qt) and 1) or 0
end
local function setup_iso_safe_charsets(attrs)
  local flags = lisp.fixnum(lisp.aref(attrs, coding_attr.iso_flags))
  local charset_list = lisp.aref(attrs, coding_attr.charset_list)
  if
    bit.band(flags, coding_iso_flag.full_support) > 0
    and not lisp.eq(charset_list, vars.iso_2022_charset_list)
  then
    charset_list = vars.iso_2022_charset_list
    lisp.aset(attrs, coding_attr.charset_list, charset_list)
    lisp.aset(attrs, coding_attr.safe_charsets, vars.Qnil)
  end
  if lisp.stringp(lisp.aref(attrs, coding_attr.safe_charsets)) then
    return
  end
  local max_charset_id = 0
  local tail = charset_list
  while lisp.consp(tail) do
    local id = lisp.fixnum(lisp.xcar(tail))
    if id > max_charset_id then
      max_charset_id = id
    end
    tail = lisp.xcdr(tail)
  end
  local safe_charsets = {}
  for i = 1, max_charset_id + 1 do
    safe_charsets[i] = '\xff'
  end
  local request = lisp.aref(attrs, coding_attr.iso_request)
  local reg_usage = lisp.aref(attrs, coding_attr.iso_usage)
  local reg94 = lisp.fixnum(lisp.xcar(reg_usage))
  local reg96 = lisp.fixnum(lisp.xcdr(reg_usage))
  tail = charset_list
  while lisp.consp(tail) do
    local id = lisp.xcar(tail)
    local cs = vars.charset_table[lisp.fixnum(id)]
    local reg = vars.F.cdr(vars.F.assq(id, request))
    if not lisp.nilp(reg) then
      safe_charsets[lisp.fixnum(id) + 1] = string.char(lisp.fixnum(reg))
    elseif cs.iso_chars_96 then
      if reg96 < 4 then
        safe_charsets[lisp.fixnum(id) + 1] = string.char(reg96)
      end
    else
      if reg94 < 4 then
        safe_charsets[lisp.fixnum(id) + 1] = string.char(reg94)
      end
    end
    tail = lisp.xcdr(tail)
  end
  lisp.aset(
    attrs,
    coding_attr.safe_charsets,
    alloc.make_unibyte_string(table.concat(safe_charsets))
  )
end
local function coding_iso_initial(coding, reg)
  return lisp.fixnum(lisp.aref(lisp.aref(coding_id_attrs(coding.id), coding_attr.iso_initial), reg))
end
---@param coding_system vim.elisp.obj
---@param coding vim.elisp.coding_system
local function setup_coding_system(coding_system, coding)
  if lisp.nilp(coding_system) then
    coding_system = vars.Qundecided
  end

  coding.id = check_coding_system_get_id(coding_system)
  local attrs = coding_id_attrs(coding.id)
  local eol_type = not lisp.nilp(vars.V.inhibit_eol_conversion) and vars.Qunix
    or coding_id_eol_type(coding.id)

  coding.mode = 0
  if lisp.vectorp(eol_type) then
    coding.common_flags = bit.bor(coding_mask.require_decoding, coding_mask.require_detection)
  elseif not lisp.eq(eol_type, vars.Qunix) then
    error('TODO')
  else
    coding.common_flags = 0
  end
  if not lisp.nilp(lisp.aref(attrs, coding_attr.post_read)) then
    error('TODO')
  end
  if not lisp.nilp(lisp.aref(attrs, coding_attr.pre_write)) then
    error('TODO')
  end
  if not lisp.nilp(lisp.aref(attrs, coding_attr.for_unibyte)) then
    coding.common_flags = bit.bor(coding.common_flags, coding_mask.for_unibyte)
  end

  local val = lisp.aref(attrs, coding_attr.safe_charsets)
  coding.max_charset_id = lisp.schars(val) - 1
  coding.safe_charsets = lisp.sdata(val)
  coding.default_char = lisp.fixnum(lisp.aref(attrs, coding_attr.default_char))
  coding.carryover_bytes = 0
  coding.raw_destination = false

  local coding_type = lisp.aref(attrs, coding_attr.type)
  if lisp.eq(coding_type, vars.Qundecided) then
    coding.detector = 0
    coding.decoder = decode_coding_raw_text
    coding.encoder = encode_coding_raw_text
    coding.common_flags = bit.bor(coding.common_flags, coding_mask.require_detection)
    coding.spec_undecided = {} --[[@as unknown]]
    coding.spec_undecided.inhibit_nbd =
      encode_inhibit_flag(lisp.aref(attrs, coding_attr.undecided_inhibit_null_byte_detection))
    coding.spec_undecided.inhibit_ied =
      encode_inhibit_flag(lisp.aref(attrs, coding_attr.undecided_inhibit_iso_escape_detection))
    coding.spec_undecided.prefer_utf_8 =
      not lisp.nilp(lisp.aref(attrs, coding_attr.undecided_prefer_utf_8))
  elseif lisp.eq(coding_type, vars.Qiso_2022) then
    local flags = lisp.fixnum(lisp.aref(attrs, coding_attr.iso_flags))
    coding.spec_iso_2022 = {
      current_invocation = {},
      current_designation = {},
      cmp_status = {},
    } --[[@as unknown]]
    coding.spec_iso_2022.current_invocation[0] = 0
    coding.spec_iso_2022.current_invocation[1] = bit.band(flags, coding_iso_flag.seven_bits) > 0
        and -1
      or 0
    for i = 0, 3 do
      coding.spec_iso_2022.current_designation[i] = coding_iso_initial(coding, i)
    end
    coding.spec_iso_2022.single_shifting = false
    coding.spec_iso_2022.bol = true
    coding.detector = detect_coding_iso_2022
    coding.decoder = decode_coding_iso_2022
    coding.encoder = encode_coding_iso_2022
    if bit.band(flags, coding_iso_flag.safe) > 0 then
      coding.mode = bit.bor(coding.mode, coding_mode.safe_encoding)
    end
    coding.common_flags = bit.bor(
      coding.common_flags,
      coding_mask.require_decoding,
      coding_mask.require_encoding,
      coding_mask.require_flushing
    )
    if bit.band(flags, coding_iso_flag.composition) > 0 then
      coding.common_flags = bit.bor(coding.common_flags, coding_mask.annotate_composition)
    end
    if bit.band(flags, coding_iso_flag.designation) > 0 then
      coding.common_flags = bit.bor(coding.common_flags, coding_mask.annotate_charset)
    end
    if bit.band(flags, coding_iso_flag.full_support) > 0 then
      setup_iso_safe_charsets(attrs)
      val = lisp.aref(attrs, coding_attr.safe_charsets)
      coding.max_charset_id = lisp.schars(val) - 1
      coding.safe_charsets = lisp.sdata(val)
    end
    coding.spec_iso_2022.flags = flags
    coding.spec_iso_2022.cmp_status.state = coding_composition_state.no
    coding.spec_iso_2022.cmp_status.method = coding_composition_method.no
    coding.spec_iso_2022.ctext_extended_segment_len = 0
    coding.spec_iso_2022.embedded_utf_8 = false
  elseif lisp.eq(coding_type, vars.Qcharset) then
    coding.detector = detect_coding_charset
    coding.decoder = decode_coding_charset
    coding.encoder = encode_coding_charset
    coding.common_flags =
      bit.bor(coding.common_flags, coding_mask.require_decoding, coding_mask.require_encoding)
  elseif lisp.eq(coding_type, vars.Qutf_8) then
    val = lisp.aref(attrs, coding_attr.utf_bom)
    coding.spec_utf_8_bom = (lisp.consp(val) and coding_utf_bom_type.detect)
      or (lisp.eq(val, vars.Qt) and coding_utf_bom_type.with)
      or coding_utf_bom_type.without
    coding.detector = detect_coding_utf_8
    coding.decoder = decode_coding_utf_8
    coding.encoder = encode_coding_utf_8
    coding.common_flags =
      bit.bor(coding.common_flags, coding_mask.require_decoding, coding_mask.require_encoding)
    if coding.spec_utf_8_bom == coding_utf_bom_type.detect then
      coding.common_flags = bit.bor(coding.common_flags, coding_mask.require_detection)
    end
  elseif lisp.eq(coding_type, vars.Qutf_16) then
    val = lisp.aref(attrs, coding_attr.utf_bom)
    coding.spec_utf_16 = {} --[[@as unknown]]
    coding.spec_utf_16.bom = (lisp.consp(val) and coding_utf_bom_type.detect)
      or (lisp.eq(val, vars.Qt) and coding_utf_bom_type.with)
      or coding_utf_bom_type.without
    val = lisp.aref(attrs, coding_attr.utf_16_endian)
    coding.spec_utf_16.endian = (lisp.eq(val, vars.Qbig) and coding_utf_16_endian_type.big)
      or coding_utf_16_endian_type.little
    coding.spec_utf_16.surrogate = 0
    coding.detector = detect_coding_utf_16
    coding.decoder = decode_coding_utf_16
    coding.encoder = encode_coding_utf_16
    coding.common_flags =
      bit.bor(coding.common_flags, coding_mask.require_decoding, coding_mask.require_encoding)
    if coding.spec_utf_16.bom == coding_utf_bom_type.detect then
      coding.common_flags = bit.bor(coding.common_flags, coding_mask.require_detection)
    end
  elseif lisp.eq(coding_type, vars.Qccl) then
    error('TODO')
  elseif lisp.eq(coding_type, vars.Qemacs_mule) then
    coding.detector = detect_coding_emacs_mule
    coding.decoder = decode_coding_emacs_mule
    coding.encoder = encode_coding_emacs_mule
    coding.common_flags =
      bit.bor(coding.common_flags, coding_mask.require_decoding, coding_mask.require_encoding)
    if
      not lisp.nilp(lisp.aref(attrs, coding_attr.emacs_mule_full))
      and not lisp.eq(lisp.aref(attrs, coding_attr.charset_list), vars.emacs_mule_charset_list)
    then
      error('TODO')
    end
    coding.spec_emacs_mule = {} --[[@as unknown]]
    coding.spec_emacs_mule.state = coding_composition_state.no
    coding.spec_emacs_mule.method = coding_composition_method.no
  elseif lisp.eq(coding_type, vars.Qshift_jis) then
    coding.detector = detect_coding_sjis
    coding.decoder = decode_coding_sjis
    coding.encoder = encode_coding_sjis
    coding.common_flags =
      bit.bor(coding.common_flags, coding_mask.require_decoding, coding_mask.require_encoding)
  elseif lisp.eq(coding_type, vars.Qbig5) then
    coding.detector = detect_coding_big5
    coding.decoder = decode_coding_big5
    coding.encoder = encode_coding_big5
    coding.common_flags =
      bit.bor(coding.common_flags, coding_mask.require_decoding, coding_mask.require_encoding)
  else
    assert(lisp.eq(coding_type, vars.Qraw_text))
    coding.detector = 0
    coding.decoder = decode_coding_raw_text
    coding.encoder = encode_coding_raw_text
    if not lisp.eq(eol_type, vars.Qunix) then
      coding.common_flags = bit.bor(coding.common_flags, coding_mask.require_decoding)
      if not lisp.vectorp(eol_type) then
        coding.common_flags = bit.bor(coding.common_flags, coding_mask.require_encoding)
      end
    end
  end
end
---@param base vim.elisp.obj
---@return vim.elisp.obj
local function make_subsidiaries(base)
  local suffixes = { '-unix', '-dos', '-mac' }
  local subsidiaries = alloc.make_vector(3, 'nil')
  for k, v in ipairs(suffixes) do
    lisp.aset(subsidiaries, k - 1, lread.intern(lisp.sdata(lisp.symbol_name(base)) .. v))
  end
  return subsidiaries
end
F.define_coding_system_internal = {
  'define-coding-system-internal',
  coding_arg.max,
  -2,
  0,
  [[For internal use only.
usage: (define-coding-system-internal ...)]],
}
function F.define_coding_system_internal.fa(args)
  if #args < coding_arg.max then
    vars.F.signal(
      vars.Qwrong_number_of_arguments,
      vars.F.cons(lread.intern('define-coding-system-internal'), lisp.make_fixnum(#args))
    )
  end
  local attrs = alloc.make_vector(coding_attr.last_index, 'nil')
  local max_charset_id = 0

  local name = args[coding_arg.name]
  lisp.check_symbol(name)
  lisp.aset(attrs, coding_attr.base_name, name)

  local val = args[coding_arg.mnemonic]
  if lisp.stringp(val) then
    val = lisp.make_fixnum(chars.stringchar(lisp.sdata(val)))
  else
    chars.check_character(val)
  end
  lisp.aset(attrs, coding_attr.mnemonic, val)

  local coding_type = args[coding_arg.coding_type]
  lisp.check_symbol(coding_type)
  lisp.aset(attrs, coding_attr.type, coding_type)

  local charset_list = args[coding_arg.charset_list]
  if lisp.symbolp(charset_list) then
    if lisp.eq(charset_list, vars.Qiso_2022) then
      if not lisp.eq(coding_type, vars.Qiso_2022) then
        signal.error('Invalid charset-list')
      end
      charset_list = vars.iso_2022_charset_list
    elseif lisp.eq(charset_list, vars.Qemacs_mule) then
      if not lisp.eq(coding_type, vars.Qemacs_mule) then
        signal.error('Invalid charset-list')
      end
      charset_list = vars.emacs_mule_charset_list
    end
    local tail = charset_list
    while lisp.consp(tail) do
      if not lisp.ranged_fixnump(0, lisp.xcar(tail), 0x7fffffff - 1) then
        signal.error('Invalid charset-list')
      end
      if max_charset_id < lisp.fixnum(lisp.xcar(tail)) then
        max_charset_id = lisp.fixnum(lisp.xcar(tail))
      end
      tail = lisp.xcdr(tail)
    end
  else
    charset_list = vars.F.copy_sequence(charset_list)
    local tail = charset_list
    while lisp.consp(tail) do
      val = lisp.xcar(tail)
      local cs = charset.check_charset_get_charset(val)
      if
        lisp.eq(coding_type, vars.Qiso_2022) and cs.iso_final < 0
        or lisp.eq(coding_type, vars.Qemacs_mule) and cs.emacs_mule_id < 0
      then
        signal.error(
          "Can't handle charset `%s'",
          lisp.sdata(lisp.symbol_name(charset.charset_name(cs)))
        )
      end
      lisp.xsetcar(tail, lisp.make_fixnum(cs.id))
      if max_charset_id < cs.id then
        max_charset_id = cs.id
      end
      tail = lisp.xcdr(tail)
    end
  end
  lisp.aset(attrs, coding_attr.charset_list, charset_list)

  local safe_charsets = {}
  for i = 1, max_charset_id + 1 do
    safe_charsets[i] = '\xff'
  end
  local tail = charset_list
  while lisp.consp(tail) do
    safe_charsets[lisp.fixnum(lisp.xcar(tail)) + 1] = '\0'
    tail = lisp.xcdr(tail)
  end
  lisp.aset(
    attrs,
    coding_attr.safe_charsets,
    alloc.make_unibyte_string(table.concat(safe_charsets))
  )

  lisp.aset(attrs, coding_attr.ascii_compat, args[coding_arg.ascii_compatible_p])

  val = args[coding_arg.decode_translation_table]
  if not lisp.chartablep(val) and not lisp.consp(val) then
    lisp.check_symbol(val)
  end
  lisp.aset(attrs, coding_attr.decode_tbl, val)

  val = args[coding_arg.encode_translation_table]
  if not lisp.chartablep(val) and not lisp.consp(val) then
    lisp.check_symbol(val)
  end
  lisp.aset(attrs, coding_attr.encode_tbl, val)

  val = args[coding_arg.post_read_conversion]
  lisp.check_symbol(val)
  lisp.aset(attrs, coding_attr.post_read, val)

  val = args[coding_arg.pre_write_conversion]
  lisp.check_symbol(val)
  lisp.aset(attrs, coding_attr.pre_write, val)

  val = args[coding_arg.default_char]
  if lisp.nilp(val) then
    lisp.aset(attrs, coding_attr.default_char, lisp.make_fixnum(b ' '))
  else
    chars.check_character(val)
    lisp.aset(attrs, coding_attr.default_char, val)
  end

  val = args[coding_arg.for_unibyte]
  lisp.aset(attrs, coding_attr.for_unibyte, lisp.nilp(val) and vars.Qnil or vars.Qt)

  val = args[coding_arg.plist]
  lisp.check_list(val)
  lisp.aset(attrs, coding_attr.plist, val)

  local category
  if lisp.eq(coding_type, vars.Qcharset) then
    val = alloc.make_vector(256, 'nil')
    tail = charset_list
    while lisp.consp(tail) do
      local cs = vars.charset_table[lisp.fixnum(lisp.xcar(tail))]
      local dim = cs.dimension
      local idx = (dim - 1) * 4
      if cs.ascii_compatible_p then
        lisp.aset(attrs, coding_attr.ascii_compat, vars.Qt)
      end
      for i = cs.code_space[idx], cs.code_space[idx + 1] do
        local tmp = lisp.aref(val, i)
        local dim2
        if lisp.nilp(tmp) then
          tmp = lisp.xcar(tail)
        elseif lisp.fixnatp(tmp) then
          dim2 = vars.charset_table[lisp.fixnum(tmp)].dimension
          if dim < dim2 then
            tmp = lisp.list(lisp.xcar(tail), tmp)
          else
            tmp = lisp.list(tmp, lisp.xcar(tail))
          end
        else
          local tmp2 = tmp
          while lisp.consp(tmp2) do
            dim2 = vars.charset_table[lisp.fixnum(lisp.xcar(tmp2))].dimension
            if dim < dim2 then
              break
            end
            tmp2 = lisp.xcdr(tmp2)
          end
          if lisp.nilp(tmp2) then
            tmp = vars.F.nconc { tmp, lisp.list(lisp.xcar(tail)) }
          else
            lisp.xsetcdr(tmp2, vars.F.cons(lisp.xcar(tail), lisp.xcdr(tmp2)))
            lisp.xsetcar(tmp2, lisp.xcar(tmp2))
          end
        end
        lisp.aset(val, i, tmp)
      end
      tail = lisp.xcdr(tail)
    end
    lisp.aset(attrs, coding_attr.charset_valids, val)
    category = coding_category.charset
  elseif lisp.eq(coding_type, vars.Qccl) then
    error('TODO')
  elseif lisp.eq(coding_type, vars.Qutf_16) then
    lisp.aset(attrs, coding_attr.ascii_compat, vars.Qnil)
    if #args < coding_arg_utf_16.max then
      vars.F.signal(
        vars.Qwrong_number_of_arguments,
        vars.F.cons(lread.intern('define-coding-system-internal'), lisp.make_fixnum(#args))
      )
    end
    local bom = args[coding_arg_utf_16.bom]
    if not lisp.nilp(bom) and not lisp.eq(bom, vars.Qt) then
      lisp.check_cons(bom)
      val = lisp.xcar(bom)
      check_coding_system(val)
      val = lisp.xcdr(bom)
      check_coding_system(val)
    end
    lisp.aset(attrs, coding_attr.utf_bom, bom)
    local endian = args[coding_arg_utf_16.endian]
    lisp.check_symbol(endian)
    if lisp.nilp(endian) then
      endian = vars.Qbig
    elseif not lisp.eq(endian, vars.Qbig) and not lisp.eq(endian, vars.Qlittle) then
      signal.error('Invalid endian: %s', lisp.sdata(lisp.symbol_name(endian)))
    end
    lisp.aset(attrs, coding_attr.utf_16_endian, endian)
    category = (lisp.consp(bom) and coding_category.utf_16_auto)
      or (lisp.nilp(bom) and (lisp.eq(endian, vars.Qbig) and coding_category.utf_16_be_nosig or coding_category.utf_16_le_nosig))
      or (lisp.eq(endian, vars.Qbig) and coding_category.utf_16_be or coding_category.utf_16_le)
  elseif lisp.eq(coding_type, vars.Qiso_2022) then
    if #args < coding_arg_iso_2022.max then
      vars.F.signal(
        vars.Qwrong_number_of_arguments,
        vars.F.cons(lread.intern('define-coding-system-internal'), lisp.make_fixnum(#args))
      )
    end
    local initial = vars.F.copy_sequence(args[coding_arg_iso_2022.initial])
    lisp.check_vector(initial)
    for i = 0, 3 do
      val = lisp.aref(initial, i)
      if not lisp.nilp(val) then
        local cs = charset.check_charset_get_charset(val)
        lisp.aset(initial, i, lisp.make_fixnum(cs.id))
        if i == 0 and cs.ascii_compatible_p then
          lisp.aset(attrs, coding_attr.ascii_compat, vars.Qt)
        end
      else
        lisp.aset(initial, i, lisp.make_fixnum(-1))
      end
    end
    local reg_usage = args[coding_arg_iso_2022.reg_usage]
    lisp.check_cons(reg_usage)
    lisp.check_fixnum(lisp.xcar(reg_usage))
    lisp.check_fixnum(lisp.xcdr(reg_usage))
    local request = vars.F.copy_sequence(args[coding_arg_iso_2022.request])
    tail = request
    while lisp.consp(tail) do
      val = lisp.xcar(tail)
      lisp.check_cons(val)
      local id = charset.check_charset_get_id(lisp.xcar(val))
      lisp.check_fixnum_range(lisp.xcdr(val), 0, 3)
      lisp.xsetcar(val, lisp.make_fixnum(id))
      tail = lisp.xcdr(tail)
    end
    local flags = args[coding_arg_iso_2022.flags]
    lisp.check_fixnat(flags)
    local i = bit.bor(lisp.fixnum(flags), 0x7fffffff)
    if lisp.eq(args[coding_arg.charset_list], vars.Qiso_2022) then
      i = bit.bor(i, coding_iso_flag.full_support)
    end
    flags = lisp.make_fixnum(i)
    lisp.aset(attrs, coding_attr.iso_initial, initial)
    lisp.aset(attrs, coding_attr.iso_usage, reg_usage)
    lisp.aset(attrs, coding_attr.iso_request, request)
    lisp.aset(attrs, coding_attr.iso_flags, flags)
    setup_iso_safe_charsets(attrs)
    if bit.band(i, coding_iso_flag.seven_bits) > 0 then
      category = (
        bit.band(i, bit.bor(coding_iso_flag.locking_shift, coding_iso_flag.single_shift)) > 0
        and coding_category.iso_7_else
      )
        or (lisp.eq(args[coding_arg.charset_list], vars.Qiso_2022) and coding_category.iso_7)
        or coding_category.iso_7_tight
    else
      local id = lisp.fixnum(lisp.aref(initial, 1))
      category = (
        (
          bit.band(i, coding_iso_flag.locking_shift) > 0
          or lisp.eq(args[coding_arg.charset_list], vars.Qiso_2022)
          or id < 0
        ) and coding_category.iso_8_else
      )
        or vars.charset_table[id].dimension == 1 and coding_category.iso_8_1
        or coding_category.iso_8_2
    end
    if category ~= coding_category.iso_8_1 and category ~= coding_category.iso_8_2 then
      lisp.aset(attrs, coding_attr.ascii_compat, vars.Qnil)
    end
  elseif lisp.eq(coding_type, vars.Qemacs_mule) then
    if lisp.eq(args[coding_arg.charset_list], vars.Qemacs_mule) then
      lisp.aset(attrs, coding_attr.emacs_mule_full, vars.Qt)
    end
    lisp.aset(attrs, coding_attr.ascii_compat, vars.Qt)
    category = coding_category.emacs_mule
  elseif lisp.eq(coding_type, vars.Qshift_jis) then
    local charset_list_len = lisp.list_length(charset_list)
    if charset_list_len ~= 3 and charset_list_len ~= 4 then
      signal.error('There should be three or four charsets')
    end
    local cs = vars.charset_table[lisp.fixnum(lisp.xcar(charset_list))]
    if cs.dimension ~= 1 then
      signal.error(
        'Dimension of charset %s is not one',
        lisp.sdata(lisp.symbol_name(charset.charset_name(cs)))
      )
    end
    if cs.ascii_compatible_p then
      lisp.aset(attrs, coding_attr.ascii_compat, vars.Qt)
    end
    charset_list = lisp.xcdr(charset_list)
    cs = vars.charset_table[lisp.fixnum(lisp.xcar(charset_list))]
    if cs.dimension ~= 1 then
      signal.error(
        'Dimension of charset %s is not one',
        lisp.sdata(lisp.symbol_name(charset.charset_name(cs)))
      )
    end
    charset_list = lisp.xcdr(charset_list)
    cs = vars.charset_table[lisp.fixnum(lisp.xcar(charset_list))]
    if cs.dimension ~= 2 then
      signal.error(
        'Dimension of charset %s is not two',
        lisp.sdata(lisp.symbol_name(charset.charset_name(cs)))
      )
    end
    charset_list = lisp.xcdr(charset_list)
    if not lisp.nilp(charset_list) then
      cs = vars.charset_table[lisp.fixnum(lisp.xcar(charset_list))]
      if cs.dimension ~= 2 then
        signal.error(
          'Dimension of charset %s is not two',
          lisp.sdata(lisp.symbol_name(charset.charset_name(cs)))
        )
      end
    end
    category = coding_category.sjis
    vars.sjis_coding_system = name
  elseif lisp.eq(coding_type, vars.Qbig5) then
    if lisp.list_length(charset_list) ~= 2 then
      signal.error('There should be just two charsets')
    end
    local cs = vars.charset_table[lisp.fixnum(lisp.xcar(charset_list))]
    if cs.dimension ~= 1 then
      signal.error(
        'Dimension of charset %s is not one',
        lisp.sdata(lisp.symbol_name(charset.charset_name(cs)))
      )
    end
    if cs.ascii_compatible_p then
      lisp.aset(attrs, coding_attr.ascii_compat, vars.Qt)
    end
    charset_list = lisp.xcdr(charset_list)
    cs = vars.charset_table[lisp.fixnum(lisp.xcar(charset_list))]
    if cs.dimension ~= 2 then
      signal.error(
        'Dimension of charset %s is not two',
        lisp.sdata(lisp.symbol_name(charset.charset_name(cs)))
      )
    end
    category = coding_category.big5
    vars.big5_coding_system = name
  elseif lisp.eq(coding_type, vars.Qraw_text) then
    category = coding_category.raw_text
    lisp.aset(attrs, coding_attr.ascii_compat, vars.Qt)
  elseif lisp.eq(coding_type, vars.Qutf_8) then
    if #args < coding_arg_utf_8.max then
      vars.F.signal(
        vars.Qwrong_number_of_arguments,
        vars.F.cons(lread.intern('define-coding-system-internal'), lisp.make_fixnum(#args))
      )
    end
    local bom = args[coding_arg_utf_8.bom]
    if not lisp.nilp(bom) and not lisp.eq(bom, vars.Qt) then
      lisp.check_cons(bom)
      val = lisp.xcar(bom)
      check_coding_system(val)
      val = lisp.xcdr(bom)
      check_coding_system(val)
    end
    lisp.aset(attrs, coding_attr.utf_bom, bom)
    if lisp.nilp(bom) then
      lisp.aset(attrs, coding_attr.ascii_compat, vars.Qt)
    end
    category = (lisp.consp(bom) and coding_category.utf_8_auto)
      or (lisp.nilp(bom) and coding_category.utf_8_nosig)
      or coding_category.utf_8_sig
  elseif lisp.eq(coding_type, vars.Qundecided) then
    if #args < coding_arg_undecided.max then
      vars.F.signal(
        vars.Qwrong_number_of_arguments,
        vars.F.cons(lread.intern('define-coding-system-internal'), lisp.make_fixnum(#args))
      )
    end
    lisp.aset(
      attrs,
      coding_attr.undecided_inhibit_null_byte_detection,
      args[coding_arg_undecided.inhibit_null_byte_detection]
    )
    lisp.aset(
      attrs,
      coding_attr.undecided_inhibit_iso_escape_detection,
      args[coding_arg_undecided.inhibit_iso_escape_detection]
    )
    lisp.aset(attrs, coding_attr.undecided_prefer_utf_8, args[coding_arg_undecided.prefer_utf_8])
    category = coding_category.undecided
  else
    signal.error('Invalid coding system type: %s', lisp.sdata(lisp.symbol_name(coding_type)))
  end
  lisp.aset(attrs, coding_attr.category, lisp.make_fixnum(category))

  lisp.aset(
    attrs,
    coding_attr.plist,
    vars.F.cons(
      vars.QCcategory,
      vars.F.cons(
        lisp.aref(vars.coding_category_table, category),
        lisp.aref(attrs, coding_attr.plist)
      )
    )
  )
  lisp.aset(
    attrs,
    coding_attr.plist,
    vars.F.cons(
      vars.QCascii_compatible_p,
      vars.F.cons(lisp.aref(attrs, coding_attr.ascii_compat), lisp.aref(attrs, coding_attr.plist))
    )
  )

  local eol_type = args[coding_arg.eol_type]
  if
    not lisp.nilp(eol_type)
    and not lisp.eq(eol_type, vars.Qunix)
    and not lisp.eq(eol_type, vars.Qdos)
    and not lisp.eq(eol_type, vars.Qmac)
  then
    signal.error('Invalid eol-type')
  end

  if lisp.nilp(eol_type) then
    eol_type = make_subsidiaries(name)
    for i = 0, 2 do
      local this_name = lisp.aref(eol_type, i)
      local this_aliases = lisp.list(this_name)
      local this_eol_type = i == 0 and vars.Qunix or i == 1 and vars.Qdos or vars.Qmac
      local this_spec = alloc.make_vector(3, 'nil')
      lisp.aset(this_spec, 0, attrs)
      lisp.aset(this_spec, 1, this_aliases)
      lisp.aset(this_spec, 2, this_eol_type)
      vars.F.puthash(this_name, this_spec, vars.coding_system_hash_table)
      vars.V.coding_system_list = vars.F.cons(this_name, vars.V.coding_system_list)
      val = vars.F.assoc(vars.F.symbol_name(this_name), vars.V.coding_system_alist, vars.Qnil)
      if lisp.nilp(val) then
        vars.V.coding_system_alist = vars.F.cons(
          vars.F.cons(vars.F.symbol_name(this_name), vars.Qnil),
          vars.V.coding_system_alist
        )
      end
    end
  end

  local aliases = lisp.list(name)
  local spec_vec = alloc.make_vector(3, 'nil')
  lisp.aset(spec_vec, 0, attrs)
  lisp.aset(spec_vec, 1, aliases)
  lisp.aset(spec_vec, 2, eol_type)

  vars.F.puthash(name, spec_vec, vars.coding_system_hash_table)
  vars.V.coding_system_list = vars.F.cons(name, vars.V.coding_system_list)
  val = vars.F.assoc(vars.F.symbol_name(name), vars.V.coding_system_alist, vars.Qnil)
  if lisp.nilp(val) then
    vars.V.coding_system_alist =
      vars.F.cons(vars.F.cons(vars.F.symbol_name(name), vars.Qnil), vars.V.coding_system_alist)
  end

  local id = coding_categories[category].id
  if id < 0 or lisp.eq(name, coding_id_name(id)) then
    setup_coding_system(name, coding_categories[category])
  end

  return vars.Qnil
end
F.define_coding_system_alias =
  { 'define-coding-system-alias', 2, 2, 0, [[Define ALIAS as an alias for CODING-SYSTEM.]] }
function F.define_coding_system_alias.f(alias, coding_system)
  lisp.check_symbol(alias)
  local spec = check_coding_system_get_spec(coding_system)
  local aliases = lisp.aref(spec, 1)
  while not lisp.nilp(lisp.xcdr(aliases)) do
    aliases = lisp.xcdr(aliases)
  end
  lisp.xsetcdr(aliases, lisp.list(alias))

  local eol_type = lisp.aref(spec, 2)
  if lisp.vectorp(eol_type) then
    local subsidiaries = make_subsidiaries(alias)
    for i = 0, 2 do
      vars.F.define_coding_system_alias(lisp.aref(subsidiaries, i), lisp.aref(eol_type, i))
    end
  end

  vars.F.puthash(alias, spec, vars.coding_system_hash_table)
  vars.V.coding_system_list = vars.F.cons(alias, vars.V.coding_system_list)
  local val = vars.F.assoc(vars.F.symbol_name(alias), vars.V.coding_system_alist, vars.Qnil)
  if lisp.nilp(val) then
    vars.V.coding_system_alist =
      vars.F.cons(vars.F.cons(vars.F.symbol_name(alias), vars.Qnil), vars.V.coding_system_alist)
  end
  return vars.Qnil
end
F.coding_system_put = {
  'coding-system-put',
  3,
  3,
  0,
  [[Change value of CODING-SYSTEM's property PROP to VAL.

The following properties, if set by this function, override the values
of the corresponding attributes set by `define-coding-system':

  `:mnemonic', `:default-char', `:ascii-compatible-p'
  `:decode-translation-table', `:encode-translation-table',
  `:post-read-conversion', `:pre-write-conversion'

See `define-coding-system' for the description of these properties.
See `coding-system-get' and `coding-system-plist' for accessing the
property list of a coding-system.]],
}
function F.coding_system_put.f(coding_system, prop, val)
  local spec = check_coding_system_get_spec(coding_system)
  local attrs = lisp.aref(spec, 0)
  if lisp.eq(prop, vars.QCmnemonic) then
    error('TODO')
  elseif lisp.eq(prop, vars.QCdefault_char) then
    error('TODO')
  elseif lisp.eq(prop, vars.QCdecode_translation_table) then
    error('TODO')
  elseif lisp.eq(prop, vars.QCencode_translation_table) then
    error('TODO')
  elseif lisp.eq(prop, vars.QCpost_read_conversion) then
    error('TODO')
  elseif lisp.eq(prop, vars.QCpre_write_conversion) then
    error('TODO')
  elseif lisp.eq(prop, vars.QCascii_compatible_p) then
    lisp.aset(attrs, coding_attr.ascii_compat, val)
  end
  lisp.aset(attrs, coding_attr.plist, fns.plist_put(lisp.aref(attrs, coding_attr.plist), prop, val))
  return val
end
F.coding_system_p = {
  'coding-system-p',
  1,
  1,
  0,
  [[Return t if OBJECT is nil or a coding-system.
See the documentation of `define-coding-system' for information
about coding-system objects.]],
}
function F.coding_system_p.f(obj)
  if lisp.nilp(obj) or coding_system_id(obj) >= 0 then
    return vars.Qt
  end
  if not lisp.symbolp(obj) or lisp.nilp(vars.F.get(obj, vars.Qcoding_system_define_form)) then
    return vars.Qnil
  end
  return vars.Qt
end
F.check_coding_system = {
  'check-coding-system',
  1,
  1,
  0,
  [[Check validity of CODING-SYSTEM.
If valid, return CODING-SYSTEM, else signal a `coding-system-error' error.
It is valid if it is nil or a symbol defined as a coding system by the
function `define-coding-system'.]],
}
function F.check_coding_system.f(coding_system)
  local define_form = vars.F.get(coding_system, vars.Qcoding_system_define_form)
  if not lisp.nilp(define_form) then
    error('TODO')
  end
  if not lisp.nilp(vars.F.coding_system_p(coding_system)) then
    return coding_system
  end
  signal.xsignal(vars.Qcoding_system_error, coding_system)
  error('unreachable')
end
F.set_safe_terminal_coding_system_internal =
  { 'set-safe-terminal-coding-system-internal', 1, 1, 0, [[Internal use only.]] }
function F.set_safe_terminal_coding_system_internal.f(coding_system)
  lisp.check_symbol(coding_system)
  setup_coding_system(vars.F.check_coding_system(coding_system), vars.safe_terminal_coding)
  vars.safe_terminal_coding.common_flags =
    bit.band(vars.safe_terminal_coding.common_flags, bit.bnot(coding_mask.annotate_composition))
  vars.safe_terminal_coding.src_multibyte = true
  vars.safe_terminal_coding.dst_multibyte = false
  return vars.Qnil
end
F.set_coding_system_priority = {
  'set-coding-system-priority',
  0,
  -2,
  0,
  [[Assign higher priority to the coding systems given as arguments.
If multiple coding systems belong to the same category,
all but the first one are ignored.

usage: (set-coding-system-priority &rest coding-systems)]],
}
function F.set_coding_system_priority.fa(args)
  local changed = {}
  local priorities = {}
  local j = 0
  for i = 1, #args do
    local spec = check_coding_system_get_spec(args[i])
    local attr = lisp.aref(spec, 0)
    local category = lisp.fixnum(lisp.aref(attr, coding_attr.category))
    if changed[category] then
      goto continue
    end
    changed[category] = true
    priorities[j] = category
    j = j + 1
    if
      coding_categories[category].id >= 0
      and not lisp.eq(args[i], coding_id_name(coding_categories[category].id))
    then
      setup_coding_system(args[i], coding_categories[category])
    end
    vars.F.set(lisp.aref(vars.coding_category_table, category), args[i])
    ::continue::
  end
  local k = 0
  for i = j, coding_category.max - 1 do
    while k < coding_category.max and changed[coding_priorities[k]] do
      k = k + 1
    end
    assert(k < coding_category.max)
    priorities[i] = coding_priorities[k]
    k = k + 1
  end
  coding_priorities = priorities
  vars.V.coding_system_list = vars.Qnil
  for i = coding_category.max - 1, 0, -1 do
    vars.V.coding_system_list =
      vars.F.cons(lisp.aref(vars.coding_category_table, priorities[i]), vars.V.coding_system_list)
  end
  return vars.Qnil
end
F.coding_system_base = {
  'coding-system-base',
  1,
  1,
  0,
  [[Return the base of CODING-SYSTEM.
Any alias or subsidiary coding system is not a base coding system.]],
}
function F.coding_system_base.f(coding_system)
  if lisp.nilp(coding_system) then
    return vars.Qno_conversion
  end
  local spec = check_coding_system_get_spec(coding_system)
  local attrs = lisp.aref(spec, 0)
  return lisp.aref(attrs, coding_attr.base_name)
end
F.coding_system_eol_type = {
  'coding-system-eol-type',
  1,
  1,
  0,
  [[Return eol-type of CODING-SYSTEM.
An eol-type is an integer 0, 1, 2, or a vector of coding systems.

Integer values 0, 1, and 2 indicate a format of end-of-line; LF, CRLF,
and CR respectively.

A vector value indicates that a format of end-of-line should be
detected automatically.  Nth element of the vector is the subsidiary
coding system whose eol-type is N.]],
}
function F.coding_system_eol_type.f(coding_system)
  if lisp.nilp(coding_system) then
    coding_system = vars.Qno_conversion
  end
  if not coding_system_p(coding_system) then
    return vars.Qnil
  end
  local spec = coding_system_spec(coding_system)
  local eol_type = lisp.aref(spec, 2)
  if lisp.vectorp(eol_type) then
    return vars.F.copy_sequence(eol_type)
  end
  local n = lisp.eq(eol_type, vars.Qunix) and 0 or (lisp.eq(eol_type, vars.Qdos) and 1 or 2)
  return lisp.make_fixnum(n)
end

function M.init()
  for i = 0, coding_category.max - 1 do
    coding_categories[i] = { id = -1 } --[[@as unknown]]
    coding_priorities[i] = i
  end

  vars.coding_system_hash_table = vars.F.make_hash_table(vars.QCtest, vars.Qeq)
  vars.coding_category_table = alloc.make_vector(coding_category.max, 'nil')
  lisp.aset(
    vars.coding_category_table,
    coding_category.iso_7,
    lread.intern_c_string('coding-category-iso-7')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.iso_7_tight,
    lread.intern_c_string('coding-category-iso-7-tight')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.iso_8_1,
    lread.intern_c_string('coding-category-iso-8-1')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.iso_8_2,
    lread.intern_c_string('coding-category-iso-8-2')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.iso_7_else,
    lread.intern_c_string('coding-category-iso-7-else')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.iso_8_else,
    lread.intern_c_string('coding-category-iso-8-else')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.utf_8_auto,
    lread.intern_c_string('coding-category-utf-8-auto')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.utf_8_nosig,
    lread.intern_c_string('coding-category-utf-8')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.utf_8_sig,
    lread.intern_c_string('coding-category-utf-8-sig')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.utf_16_be,
    lread.intern_c_string('coding-category-utf-16-be')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.utf_16_auto,
    lread.intern_c_string('coding-category-utf-16-auto')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.utf_16_le,
    lread.intern_c_string('coding-category-utf-16-le')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.utf_16_be_nosig,
    lread.intern_c_string('coding-category-utf-16-be-nosig')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.utf_16_le_nosig,
    lread.intern_c_string('coding-category-utf-16-le-nosig')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.charset,
    lread.intern_c_string('coding-category-charset')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.sjis,
    lread.intern_c_string('coding-category-sjis')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.big5,
    lread.intern_c_string('coding-category-big5')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.ccl,
    lread.intern_c_string('coding-category-ccl')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.emacs_mule,
    lread.intern_c_string('coding-category-emacs-mule')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.raw_text,
    lread.intern_c_string('coding-category-raw-text')
  )
  lisp.aset(
    vars.coding_category_table,
    coding_category.undecided,
    lread.intern_c_string('coding-category-undecided')
  )

  local args = {}
  for i = 1, coding_arg_undecided.max do
    args[i] = vars.Qnil
  end
  args[coding_arg.name] = vars.Qno_conversion
  args[coding_arg.mnemonic] = lisp.make_fixnum(b '=')
  args[coding_arg.coding_type] = vars.Qraw_text
  args[coding_arg.ascii_compatible_p] = vars.Qt
  args[coding_arg.default_char] = lisp.make_fixnum(0)
  args[coding_arg.for_unibyte] = vars.Qt
  args[coding_arg.eol_type] = vars.Qunix

  local plist = {
    vars.QCname,
    args[coding_arg.name],
    vars.QCmnemonic,
    args[coding_arg.mnemonic],
    lread.intern_c_string(':coding-type'),
    args[coding_arg.coding_type],
    vars.QCascii_compatible_p,
    args[coding_arg.ascii_compatible_p],
    vars.QCdefault_char,
    args[coding_arg.default_char],
    lread.intern_c_string(':for-unibyte'),
    args[coding_arg.for_unibyte],
    lread.intern_c_string(':docstring'),
    alloc.make_pure_c_string(
      'Do no conversion.\n'
        .. '\n'
        .. 'When you visit a file with this coding, the file is read into a\n'
        .. 'unibyte buffer as is, thus each byte of a file is treated as a\n'
        .. 'character.'
    ),
    lread.intern_c_string(':eol-type'),
    args[coding_arg.eol_type],
  }
  args[coding_arg.plist] = vars.F.list(plist)
  vars.F.define_coding_system_internal(args)

  args[coding_arg.name] = vars.Qundecided
  plist[2] = args[coding_arg.name]
  args[coding_arg.mnemonic] = lisp.make_fixnum(b '-')
  plist[4] = args[coding_arg.mnemonic]
  args[coding_arg.coding_type] = vars.Qundecided
  plist[6] = args[coding_arg.coding_type]
  plist[9] = lread.intern_c_string(':charset-list')
  args[coding_arg.charset_list] = lisp.list(vars.Qascii)
  plist[10] = args[coding_arg.charset_list]
  args[coding_arg.for_unibyte] = vars.Qnil
  plist[12] = args[coding_arg.for_unibyte]
  plist[14] =
    alloc.make_pure_c_string('No conversion on encoding, ' .. 'automatic conversion on decoding.')
  args[coding_arg.eol_type] = vars.Qnil
  plist[16] = args[coding_arg.eol_type]
  args[coding_arg.plist] = vars.F.list(plist)
  args[coding_arg_undecided.inhibit_null_byte_detection] = lisp.make_fixnum(0)
  args[coding_arg_undecided.inhibit_iso_escape_detection] = lisp.make_fixnum(0)
  vars.F.define_coding_system_internal(args)

  vars.safe_terminal_coding = {} --[[@as unknown]]
  setup_coding_system(vars.Qno_conversion, vars.safe_terminal_coding)

  for i = 0, coding_category.max - 1 do
    vars.F.set(lisp.aref(vars.coding_category_table, i), vars.Qno_conversion)
  end

  vars.big5_coding_system = vars.Qnil
  vars.sjis_coding_system = vars.Qnil

  vars.F.put(vars.Qtranslation_table, vars.Qchar_table_extra_slots, lisp.make_fixnum(2))
end
function M.init_syms()
  vars.defsym('QCcategory', ':category')
  vars.defsym('QCmnemonic', ':mnemonic')
  vars.defsym('QCdefault_char', ':default-char')
  vars.defsym('QCdecode_translation_table', ':decode-translation-table')
  vars.defsym('QCencode_translation_table', ':encode-translation-table')
  vars.defsym('QCpost_read_conversion', ':post-read-conversion')
  vars.defsym('QCpre_write_conversion', ':pre-write-conversion')

  vars.defsym('Qunix', 'unix')
  vars.defsym('Qdos', 'dos')
  vars.defsym('Qmac', 'mac')

  vars.defsym('Qno_conversion', 'no-conversion')
  vars.defsym('Qundecided', 'undecided')
  vars.defsym('Qbig', 'big')
  vars.defsym('Qlittle', 'little')

  vars.defsym('Qraw_text', 'raw-text')
  vars.defsym('Qiso_2022', 'iso-2022')
  vars.defsym('Qemacs_mule', 'emacs-mule')
  vars.defsym('Qcharset', 'charset')
  vars.defsym('Qccl', 'ccl')
  vars.defsym('Qutf_8', 'utf-8')
  vars.defsym('Qutf_16', 'utf-16')
  vars.defsym('Qshift_jis', 'shift-jis')
  vars.defsym('Qbig5', 'big5')

  vars.defsym('Qcoding_system_define_form', 'coding-system-define-form')

  vars.defsym('Qtranslation_table', 'translation-table')

  vars.defvar_lisp(
    'coding_system_list',
    'coding-system-list',
    [[List of coding systems.

Do not alter the value of this variable manually.  This variable should be
updated by the functions `define-coding-system' and
`define-coding-system-alias'.]]
  )
  vars.V.coding_system_list = vars.Qnil
  vars.defvar_lisp(
    'coding_system_alist',
    'coding-system-alist',
    [[Alist of coding system names.
Each element is one element list of coding system name.
This variable is given to `completing-read' as COLLECTION argument.

Do not alter the value of this variable manually.  This variable should be
updated by `define-coding-system-alias'.]]
  )
  vars.V.coding_system_alist = vars.Qnil

  vars.defvar_bool(
    'inhibit_eol_conversion',
    'inhibit-eol-conversion',
    [[
Non-nil means always inhibit code conversion of end-of-line format.
See info node `Coding Systems' and info node `Text and Binary' concerning
such conversion.]]
  )
  vars.V.inhibit_eol_conversion = vars.Qnil

  vars.defvar_lisp(
    'latin_extra_code_table',
    'latin-extra-code-table',
    [[
Table of extra Latin codes in the range 128..159 (inclusive).
This is a vector of length 256.
If Nth element is non-nil, the existence of code N in a file
\(or output of subprocess) doesn't prevent it to be detected as
a coding system of ISO 2022 variant which has a flag
`accept-latin-extra-code' t (e.g. iso-latin-1) on reading a file
or reading output of a subprocess.
Only 128th through 159th elements have a meaning.]]
  )
  vars.V.latin_extra_code_table = alloc.make_vector(256, 'nil')

  vars.defvar_lisp(
    'default_process_coding_system',
    'default-process-coding-system',
    [[
Cons of coding systems used for process I/O by default.
The car part is used for decoding a process output,
the cdr part is used for encoding a text to be sent to a process.]]
  )
  vars.V.default_process_coding_system = vars.Qnil

  vars.defsubr(F, 'define_coding_system_internal')
  vars.defsubr(F, 'define_coding_system_alias')
  vars.defsubr(F, 'coding_system_put')
  vars.defsubr(F, 'coding_system_p')
  vars.defsubr(F, 'check_coding_system')
  vars.defsubr(F, 'set_safe_terminal_coding_system_internal')
  vars.defsubr(F, 'set_coding_system_priority')
  vars.defsubr(F, 'coding_system_base')
  vars.defsubr(F, 'coding_system_eol_type')
end
return M
