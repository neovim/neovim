local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local signal = require 'elisp.signal'
local b = require 'elisp.bytes'
local alloc = require 'elisp.alloc'
local lread = require 'elisp.lread'
local fns = require 'elisp.fns'
local overflow = require 'elisp.overflow'
local chartab = require 'elisp.chartab'
local specpdl = require 'elisp.specpdl'
local chars = require 'elisp.chars'
local caching = require 'elisp.caching'

---@enum vim.elisp.charset_method
local charset_method = {
  offset = 0,
  map = 1,
  subset = 2,
  superset = 3,
}

---@class vim.elisp.charset
---@field id number
---@field hash_index number
---@field dimension number
---@field code_space number[][15] (0-indexed)
---@field code_space_mask number[][256] (0-indexed)
---@field code_linear_p boolean
---@field iso_chars_96 boolean
---@field ascii_compatible_p boolean
---@field supplementary_p boolean
---@field compact_codes_p boolean
---@field unified_p boolean
---@field iso_final number
---@field iso_revision number
---@field emacs_mule_id number
---@field method vim.elisp.charset_method
---@field min_code number
---@field max_code number
---@field char_index_offset number
---@field min_char number
---@field max_char number
---@field invalid_code number
---@field fast_map number[][190] (0-indexed)
---@field code_offset number

---@enum vim.elisp.charset_idx
local charset_idx = {
  id = 0,
  name = 1,
  plist = 2,
  map = 3,
  decoder = 4,
  encoder = 5,
  subset = 6,
  superset = 7,
  unify_map = 8,
  deunifier = 9,
  max = 10,
}
---@enum vim.elisp.charset_arg
local charset_arg = {
  name = 1,
  dimension = 2,
  code_space = 3,
  min_code = 4,
  max_code = 5,
  iso_final = 6,
  iso_revision = 7,
  emacs_mule_id = 8,
  ascii_compatible_p = 9,
  supplementary_p = 10,
  invalid_code = 11,
  code_offset = 12,
  map = 13,
  subset = 14,
  superset = 15,
  unify_map = 16,
  plist = 17,
  max = 17,
}

local M = {}
---@type vim.elisp.F
local F = {}
local function charset_symbol_attributes(sym)
  return vars.F.gethash(sym, vars.charset_hash_table, vars.Qnil)
end
local function charset_attributes(charset)
  return lisp.aref(
    (vars.charset_hash_table --[[@as vim.elisp._hash_table]]).key_and_value,
    charset.hash_index * 2 + 1
  )
end
---@param cs vim.elisp.charset
---@return vim.elisp.obj
function M.charset_name(cs)
  return lisp.aref(charset_attributes(cs), charset_idx.name)
end
---@param name vim.elisp.obj
---@param dimension number
---@param code_space_chars string
---@param min_code number
---@param max_code number
---@param iso_final number
---@param iso_revision number
---@param emacs_mule_id number
---@param ascii_compatible boolean
---@param supplementary boolean
---@param code_offset number
---@return number
local function define_charset_internal(
  name,
  dimension,
  code_space_chars,
  min_code,
  max_code,
  iso_final,
  iso_revision,
  emacs_mule_id,
  ascii_compatible,
  supplementary,
  code_offset
)
  local code_space_vector = alloc.make_vector(8, 'nil')
  local i = 0
  for c in (code_space_chars .. '\0'):gmatch '.' do
    lisp.aset(code_space_vector, i, lisp.make_fixnum(string.byte(c)))
    i = i + 1
    if i == 8 then
      break
    end
  end
  ---@type vim.elisp.obj[]
  local args = {}
  args[charset_arg.name] = name
  args[charset_arg.dimension] = lisp.make_fixnum(dimension)
  args[charset_arg.code_space] = code_space_vector
  args[charset_arg.min_code] = lisp.make_fixnum(min_code)
  args[charset_arg.max_code] = lisp.make_fixnum(max_code)
  args[charset_arg.iso_final] = (iso_final < 0 and vars.Qnil or lisp.make_fixnum(iso_final))
  args[charset_arg.iso_revision] = lisp.make_fixnum(iso_revision)
  args[charset_arg.emacs_mule_id] = (
    emacs_mule_id < 0 and vars.Qnil or lisp.make_fixnum(emacs_mule_id)
  )
  args[charset_arg.ascii_compatible_p] = ascii_compatible and vars.Qt or vars.Qnil
  args[charset_arg.supplementary_p] = supplementary and vars.Qt or vars.Qnil
  args[charset_arg.invalid_code] = vars.Qnil
  args[charset_arg.code_offset] = lisp.make_fixnum(code_offset)
  args[charset_arg.map] = vars.Qnil
  args[charset_arg.subset] = vars.Qnil
  args[charset_arg.superset] = vars.Qnil
  args[charset_arg.unify_map] = vars.Qnil
  args[charset_arg.plist] = lisp.list(
    vars.QCname,
    args[charset_arg.name],
    lread.intern_c_string(':dimension'),
    args[charset_arg.dimension],
    lread.intern_c_string(':code-space'),
    args[charset_arg.code_space],
    lread.intern_c_string(':iso-final-char'),
    args[charset_arg.iso_final],
    lread.intern_c_string(':emacs-mule-id'),
    args[charset_arg.emacs_mule_id],
    vars.QCascii_compatible_p,
    args[charset_arg.ascii_compatible_p],
    lread.intern_c_string(':code-offset'),
    args[charset_arg.code_offset]
  )
  vars.F.define_charset_internal(args)
  return lisp.fixnum(lisp.aref(charset_symbol_attributes(name), charset_idx.id))
end
local function code_point_to_index(charset, code)
  return charset.code_linear_p and (code - charset.min_code)
    or (
      (
          bit.band(charset.code_space_mask[bit.rshift(code, 24)], 0x8) > 0
          and bit.band(charset.code_space_mask[bit.band(bit.rshift(code, 16), 0xff)], 0x4) > 0
          and bit.band(charset.code_space_mask[bit.band(bit.rshift(code, 8), 0xff)], 0x2) > 0
          and bit.band(charset.code_space_mask[bit.band(code, 0xff)], 0x1) > 0
        )
        and (((bit.rshift(code, 24) - charset.code_space[12]) * charset.code_space[11]) + ((bit.band(
          bit.rshift(code, 16),
          0xff
        ) - charset.code_space[8]) * charset.code_space[7]) + ((bit.band(
          bit.rshift(code, 8),
          0xff
        ) - charset.code_space[4]) * charset.code_space[3]) + (bit.band(code, 0xff) - charset.code_space[0]) - charset.char_index_offset)
      or -1
    )
end
local function charset_fast_map_set(c, fast_map)
  if c < 0x10000 then
    fast_map[bit.rshift(c, 10)] =
      bit.bor(fast_map[bit.rshift(c, 10)], bit.lshift(1, bit.band(bit.rshift(c, 7), 7)))
  else
    fast_map[bit.rshift(c, 15)] =
      bit.bor(fast_map[bit.rshift(c, 15) + 62], bit.lshift(1, bit.band(bit.rshift(c, 12), 7)))
  end
end
---@param readcharfun vim.elisp.lread.readcharfun
---@return number
local function read_hex(readcharfun)
  while true do
    local c = readcharfun.read()
    if c == b '#' then
      while c ~= b '\n' do
        c = readcharfun.read()
      end
    elseif c == b '0' then
      c = readcharfun.read()
      if c == b 'x' then
        break
      else
        signal.error('charset map file invalid syntax: expected x after 0')
      end
    elseif c < 0 then
      return -1
    end
  end
  ---@type number?
  local n = 0
  while true do
    local c = readcharfun.read()
    local digit = chars.charhexdigit(c)
    if digit < 0 then
      break
    end
    n = overflow.add(overflow.mul_2exp(n, 4), digit)
    if n == nil then
      signal.error('charset map file invalid syntax: overflow')
    end
  end
  readcharfun.unread()
  return assert(n)
end
local function load_charset_map(charset, entries, control_flag)
  if control_flag ~= 0 then
    error('TODO')
  end
  local min_char = entries[1][3]
  local max_char = min_char
  local nonascii_min_char = b.MAX_CHAR
  for i = 1, #entries do
    local from, to, from_c = unpack(entries[i])
    local from_index = code_point_to_index(charset, from)
    local to_index, to_c
    if from == to then
      to_index = from_index
      to_c = from_c
    else
      to_index = code_point_to_index(charset, to)
      to_c = from_c + (to_index - from_index)
    end
    if from_index < 0 or to_index < 0 then
      error('TODO')
    end
    local lim_index = to_index + 1
    if to_c > max_char then
      max_char = to_c
    elseif from_c < min_char then
      min_char = from_c
    end
    if control_flag == 1 then
      error('TODO')
    elseif control_flag == 2 then
      error('TODO')
    elseif control_flag == 3 then
      error('TODO')
    elseif control_flag == 4 then
      error('TODO')
    else
      assert(control_flag == 0)
      if charset.ascii_compatible_p then
        if not chars.asciicharp(from_c) then
          if from_c < nonascii_min_char then
            nonascii_min_char = from_c
          end
        elseif not chars.asciicharp(to_c) then
          nonascii_min_char = 0x80
        end
      end
      while from_c <= to_c do
        charset_fast_map_set(from_c, charset.fast_map)
        from_c = from_c + 1
      end
    end
  end
  if control_flag == 0 then
    charset.min_char = (charset.ascii_compatible_p and nonascii_min_char or min_char)
    charset.max_char = max_char
  elseif control_flag == 4 then
    error('TODO')
  end
end
local function load_charset_map_from_file(charset, mapfile, control_flag)
  local min_code = charset.min_code
  local max_code = charset.max_code
  local suffixes = lisp.list(alloc.make_unibyte_string('.map'), alloc.make_unibyte_string('.txt'))
  local fd
  local count = specpdl.index()
  specpdl.record_unwind_protect(function()
    if fd and fd ~= -1 then
      io.close(fd --[[@as file*]])
    end
  end)
  specpdl.bind(vars.Qfile_name_handler_alist, vars.Qnil)
  local path = {}
  fd = lread.openp(vars.V.charset_map_path, mapfile, suffixes, path, vars.Qnil, false, false)
  if fd == -1 then
    signal.error('Field loading charset map %s')
  end
  ---@cast fd file*
  local content = fd:read('*a')
  local readcharfun = lread.make_readcharfun(alloc.make_unibyte_string(content))
  specpdl.unbind_to(count, nil)
  local entries = caching.cache(lisp.sdata(path[1]), function(cache_content)
    return assert(loadstring(cache_content))()
  end, function(entries)
    local lua_code = { 'return {' }
    for _, e in ipairs(entries) do
      table.insert(lua_code, string.format('{%d,%d,%d},', e[1], e[2], e[3]))
    end
    table.insert(lua_code, '}')
    return string.dump(assert(loadstring(table.concat(lua_code, '\n'))), true)
  end, function()
    local entries = {}
    while true do
      local from, to, c
      from = read_hex(readcharfun)
      if from < 0 then
        break
      end
      if readcharfun.read() == b '-' then
        to = read_hex(readcharfun)
        if to < 0 then
          signal.error('charset map file invalid syntax: expected hex after -, got end of file')
        end
      else
        readcharfun.unread()
        to = from
      end
      c = read_hex(readcharfun)
      if c < 0 then
        signal.error('charset map file invalid syntax: expected hex, got end of file')
      end
      if from < min_code or to > max_code or from > to or c > b.MAX_CHAR then
        signal.error('charset map file invalid syntax: hex out of range')
      end
      table.insert(entries, { from, to, c })
    end
    return entries
  end, true)
  load_charset_map(charset, entries, control_flag)
end
---@param charset vim.elisp.charset
---@param control_flag number
local function load_charset(charset, control_flag)
  local map
  if charset.method == charset_method.map then
    map = lisp.aref(charset_attributes(charset), charset_idx.map)
  else
    assert(charset.unified_p)
    map = lisp.aref(charset_attributes(charset), charset_idx.unify_map)
  end
  if lisp.stringp(map) then
    load_charset_map_from_file(charset, map, control_flag)
  else
    error('TODO')
  end
end
function M.check_charset_get_id(x)
  if not lisp.symbolp(x) then
    signal.wrong_type_argument(vars.Qcharsetp, x)
  end
  local idx = fns.hash_lookup(vars.charset_hash_table --[[@as vim.elisp._hash_table]], x)
  if idx < 0 then
    signal.wrong_type_argument(vars.Qcharsetp, x)
  end
  return lisp.fixnum(
    lisp.aref(
      lisp.aref(
        (vars.charset_hash_table --[[@as vim.elisp._hash_table]]).key_and_value,
        idx * 2 + 1
      ),
      charset_idx.id
    )
  )
end
function M.check_charset_get_charset(charset)
  local cid = M.check_charset_get_id(charset)
  return vars.charset_table[cid]
end
local function cons_to_unsigned(obj)
  local val
  if lisp.fixnatp(obj) then
    val = lisp.fixnum(obj)
  elseif lisp.consp(obj) and lisp.fixnump(lisp.xcar(obj)) then
    local top = lisp.fixnum(lisp.xcar(obj))
    local rest = lisp.xcdr(obj)
    if lisp.consp(rest) then
      error('TODO')
    elseif overflow.min <= top and top <= overflow.max then
      if lisp.consp(rest) then
        error('TODO')
      end
      if lisp.fixnatp(rest) and lisp.fixnum(rest) <= 0xffff then
        val = tonumber(bit.tohex(bit.bor(bit.lshift(top, 16), lisp.fixnum(rest))), 16)
      end
    else
      error('TODO')
    end
  else
    error('TODO')
  end
  if not val or val > 0xffffffff then
    signal.error('Not an in-range integer, integral float, or cons of integers')
  end
  return val
end
F.define_charset_internal = {
  'define-charset-internal',
  charset_arg.max,
  -2,
  0,
  [[For internal use only.
usage: (define-charset-internal ...)]],
}
function F.define_charset_internal.fa(args)
  if #args ~= charset_arg.max then
    vars.F.signal(
      vars.Qwrong_number_of_arguments,
      vars.F.cons(lread.intern_c_string('define-charset-internal'), lisp.make_fixnum(#args))
    )
  end
  local hash_table = vars.charset_hash_table --[[@as vim.elisp._hash_table]]
  local charset = {}
  ---@cast charset vim.elisp.charset
  local attrs = alloc.make_vector(charset_idx.max, 'nil')

  lisp.check_symbol(args[charset_arg.name])
  lisp.aset(attrs, charset_idx.name, args[charset_arg.name])

  local val = args[charset_arg.code_space]
  local dimension = 0
  do
    local i = 0
    local nchars = 1
    charset.code_space = {}
    while true do
      local min_byte_obj = vars.F.aref(val, lisp.make_fixnum(i * 2))
      local max_byte_obj = vars.F.aref(val, lisp.make_fixnum(i * 2 + 1))
      local min_byte = lisp.check_fixnum_range(min_byte_obj, 0, 255)
      local max_byte = lisp.check_fixnum_range(max_byte_obj, min_byte, 255)
      charset.code_space[i * 4] = min_byte
      charset.code_space[i * 4 + 1] = max_byte
      charset.code_space[i * 4 + 2] = max_byte - min_byte + 1
      if max_byte > 0 then
        dimension = dimension + 1
      end
      if i == 3 then
        break
      end
      nchars = nchars * charset.code_space[i * 4 + 2]
      charset.code_space[i * 4 + 3] = nchars
      i = i + 1
    end
  end

  val = args[charset_arg.dimension]
  charset.dimension = not lisp.nilp(val) and lisp.check_fixnum_range(val, 1, 4) or dimension

  charset.code_linear_p = (
    charset.dimension == 1
    or (
      charset.code_space[2] == 256
      and (
        charset.dimension == 2
        or (
          charset.code_space[6] == 256
          and (charset.dimension == 3 or charset.code_space[10] == 256)
        )
      )
    )
  )

  if not charset.code_linear_p then
    charset.code_space_mask = {}
    for i = 0, 255 do
      charset.code_space_mask[i] = 0
    end
    for i = 0, 3 do
      for j = charset.code_space[i * 4], charset.code_space[i * 4 + 1] do
        charset.code_space_mask[j] = bit.bor(charset.code_space_mask[j], bit.lshift(1, i))
      end
    end
  end

  charset.iso_chars_96 = charset.code_space[2] == 96

  charset.min_code = tonumber(
    bit.tohex(
      bit.bor(
        charset.code_space[0],
        bit.lshift(charset.code_space[4], 8),
        bit.lshift(charset.code_space[8], 16),
        bit.lshift(charset.code_space[12], 24)
      )
    ),
    16
  )
  charset.max_code = tonumber(
    bit.tohex(
      bit.bor(
        charset.code_space[1],
        bit.lshift(charset.code_space[5], 8),
        bit.lshift(charset.code_space[9], 16),
        bit.lshift(charset.code_space[13], 24)
      )
    ),
    16
  )
  charset.char_index_offset = 0

  val = args[charset_arg.min_code]
  if not lisp.nilp(val) then
    local code = cons_to_unsigned(val)
    if code < charset.min_code or code > charset.max_code then
      signal.args_out_of_range(
        lisp.make_fixnum(charset.min_code),
        lisp.make_fixnum(charset.max_code),
        val
      )
    end
    charset.char_index_offset = code_point_to_index(charset, code)
    charset.min_code = code
  end

  val = args[charset_arg.max_code]
  if not lisp.nilp(val) then
    local code = cons_to_unsigned(val)
    if code < charset.min_code or code > charset.max_code then
      signal.args_out_of_range(
        lisp.make_fixnum(charset.min_code),
        lisp.make_fixnum(charset.max_code),
        val
      )
    end
    charset.max_code = code
  end

  charset.compact_codes_p = charset.max_code < 0x10000

  val = args[charset_arg.invalid_code]
  if lisp.nilp(val) then
    if charset.min_code > 0 then
      charset.invalid_code = 0
    else
      if charset.max_code <= 0xffffffff then
        charset.invalid_code = charset.max_code + 1
      else
        signal.error('Attribute :invalid-code must be specified')
      end
    end
  else
    charset.invalid_code = cons_to_unsigned(val)
  end

  val = args[charset_arg.iso_final]
  if lisp.nilp(val) then
    charset.iso_final = -1
  else
    lisp.check_fixnum(val)
    if lisp.fixnum(val) < b '0' or lisp.fixnum(val) > 127 then
      signal.error('Invalid iso-final-char: %d', lisp.fixnum(val))
    end
    charset.iso_final = lisp.fixnum(val)
  end

  val = args[charset_arg.iso_revision]
  charset.iso_revision = not lisp.nilp(val) and lisp.check_fixnum_range(val, -1, 63) or -1

  val = args[charset_arg.emacs_mule_id]
  if lisp.nilp(val) then
    charset.emacs_mule_id = -1
  else
    lisp.fixnatp(val)
    if (lisp.fixnum(val) > 0 and lisp.fixnum(val) <= 128) or lisp.fixnum(val) >= 256 then
      signal.error('Invalid emacs-mule-id: %d', lisp.fixnum(val))
    end
    charset.emacs_mule_id = lisp.fixnum(val)
  end

  charset.ascii_compatible_p = not lisp.nilp(args[charset_arg.ascii_compatible_p])

  charset.supplementary_p = not lisp.nilp(args[charset_arg.supplementary_p])

  charset.unified_p = false

  charset.fast_map = {}
  for i = 0, 189 do
    charset.fast_map[i] = 0
  end

  if not lisp.nilp(args[charset_arg.code_offset]) then
    val = args[charset_arg.code_offset]
    require 'elisp.chars'.check_character(val)

    charset.method = charset_method.offset
    charset.code_offset = lisp.fixnum(val)

    local i = code_point_to_index(charset, charset.max_code)
    if (b.MAX_CHAR - charset.code_offset) < i then
      signal.error('Unsupported max char: %d', charset.max_char)
      -- Hmm, `charset.max_char` is not yet set, is this a bug?
    end
    charset.max_char = i + charset.code_offset
    i = code_point_to_index(charset, charset.min_code)
    charset.min_char = i + charset.code_offset

    i = bit.lshift(bit.rshift(charset.min_char, 7), 7)
    while i < 0x10000 and i <= charset.max_char do
      charset_fast_map_set(i, charset.fast_map)
      i = i + 128
    end
    i = bit.lshift(bit.rshift(charset.min_char, 12), 12)
    while i <= charset.max_char do
      charset_fast_map_set(i, charset.fast_map)
      i = i + 0x1000
    end
    if charset.code_offset == 0 and charset.max_char >= 0x80 then
      charset.ascii_compatible_p = true
    end
  elseif not lisp.nilp(args[charset_arg.map]) then
    val = args[charset_arg.map]
    lisp.aset(attrs, charset_idx.map, val)
    charset.method = charset_method.map
  elseif not lisp.nilp(args[charset_arg.subset]) then
    val = args[charset_arg.subset]
    local parent = vars.F.car(val)
    local parent_charset = M.check_charset_get_charset(parent)
    local parent_min_code = vars.F.nth(lisp.make_fixnum(1), val)
    lisp.check_fixnat(parent_min_code)
    local parent_max_code = vars.F.nth(lisp.make_fixnum(2), val)
    lisp.check_fixnat(parent_max_code)
    local parent_code_offset = vars.F.nth(lisp.make_fixnum(3), val)
    lisp.check_fixnum(parent_code_offset)
    lisp.aset(
      attrs,
      charset_idx.subset,
      vars.F.vector({
        lisp.make_fixnum(parent_charset.id),
        parent_min_code,
        parent_max_code,
        parent_code_offset,
      })
    )
    charset.method = charset_method.subset
    for i = 0, #parent_charset.fast_map - 1 do
      charset.fast_map[i] = parent_charset.fast_map[i]
    end
    charset.min_char = parent_charset.min_char
    charset.max_char = parent_charset.max_char
  elseif not lisp.nilp(args[charset_arg.superset]) then
    val = args[charset_arg.superset]
    charset.method = charset_method.superset
    val = vars.F.copy_sequence(val)
    charset.min_char = b.MAX_CHAR
    charset.max_char = 0
    while not lisp.nilp(val) do
      local this_id, offset
      local elt = vars.F.car(val)
      if lisp.consp(elt) then
        local car_part = lisp.xcar(elt)
        local cdr_part = lisp.xcdr(elt)
        this_id = M.check_charset_get_id(car_part)
        offset = lisp.check_fixnum_range(cdr_part, overflow.min, overflow.max)
      else
        this_id = M.check_charset_get_id(elt)
        offset = 0
      end
      lisp.xsetcar(val, vars.F.cons(lisp.make_fixnum(this_id), lisp.make_fixnum(offset)))
      local this_charset = assert(vars.charset_table[this_id])
      if charset.min_char > this_charset.min_char then
        charset.min_char = this_charset.min_char
      end
      if charset.max_char < this_charset.max_char then
        charset.max_char = this_charset.max_char
      end
      for i = 0, 189 do
        charset.fast_map[i] = bit.bor(charset.fast_map[i], this_charset.fast_map[i])
      end
      val = vars.F.cdr(val)
    end
  else
    signal.error('None of :code-offset, :map, :parents are specified')
  end

  val = args[charset_arg.unify_map]
  if not lisp.nilp(val) and not lisp.stringp(val) then
    lisp.check_vector(val)
  end
  lisp.aset(attrs, charset_idx.unify_map, val)

  lisp.check_list(args[charset_arg.plist])
  lisp.aset(attrs, charset_idx.plist, args[charset_arg.plist])

  local hash_code
  charset.hash_index, hash_code = fns.hash_lookup(hash_table, args[charset_arg.name])

  local id, new_definition_p
  if charset.hash_index >= 0 then
    error('TODO')
  else
    charset.hash_index = fns.hash_put(hash_table, args[charset_arg.name], attrs, hash_code)
    id = #vars.charset_table + 1
    new_definition_p = true
  end

  lisp.aset(attrs, charset_idx.id, lisp.make_fixnum(id))
  charset.id = id
  vars.charset_table[id] = charset

  if charset.method == charset_method.map then
    load_charset(charset, 0)
    vars.charset_table[id] = charset
  end

  if charset.iso_final >= 0 then
    vars.iso_charset_table[charset.dimension - 1][charset.iso_chars_96 and 1 or 0][charset.iso_final] =
      id
    if new_definition_p then
      vars.iso_2022_charset_list =
        vars.F.nconc({ vars.iso_2022_charset_list, lisp.list(lisp.make_fixnum(id)) })
    end
    if vars.iso_charset_table[1][0][b 'J'] == id then
      vars.charset_jisx0201_roman = id
    elseif vars.iso_charset_table[2][0][b '@'] == id then
      vars.charset_jisx0208_1978 = id
    elseif vars.iso_charset_table[2][0][b 'B'] == id then
      vars.charset_jisx0208 = id
    elseif vars.iso_charset_table[2][0][b 'C'] == id then
      vars.charset_ksc5601 = id
    end
  end

  if charset.emacs_mule_id >= 0 then
    vars.emacs_mule_charset[charset.emacs_mule_id] = id
    if charset.emacs_mule_id < 0xa0 then
      vars.emacs_mule_bytes[charset.emacs_mule_id] = charset.dimension + 1
    else
      vars.emacs_mule_bytes[charset.emacs_mule_id] = charset.dimension + 2
    end
    if new_definition_p then
      vars.emacs_mule_charset_list =
        vars.F.nconc({ vars.emacs_mule_charset_list, lisp.list(lisp.make_fixnum(id)) })
    end
  end

  if new_definition_p then
    vars.V.charset_list = vars.F.cons(args[charset_arg.name], vars.V.charset_list)
    if charset.supplementary_p then
      vars.charset_ordered_list =
        vars.F.nconc({ vars.charset_ordered_list, lisp.list(lisp.make_fixnum(id)) })
    else
      local tail = vars.charset_ordered_list
      while lisp.consp(tail) do
        local cs = vars.charset_table[lisp.fixnum(lisp.xcar(tail))]
        if cs.supplementary_p then
          break
        end
        tail = lisp.xcdr(tail)
      end
      if lisp.eq(tail, vars.charset_ordered_list) then
        vars.charset_ordered_list = vars.F.cons(lisp.make_fixnum(id), vars.charset_ordered_list)
      elseif lisp.nilp(tail) then
        vars.charset_ordered_list =
          vars.F.nconc({ vars.charset_ordered_list, lisp.list(lisp.make_fixnum(id)) })
      else
        val = vars.F.cons(lisp.xcar(tail), lisp.xcdr(tail))
        lisp.xsetcdr(tail, val)
        lisp.xsetcar(tail, lisp.make_fixnum(id))
      end
    end
    vars.charset_ordered_list_tick = vars.charset_ordered_list_tick + 1
  end

  return vars.Qnil
end
local function check_charset_get_attr(x)
  if not lisp.symbolp(x) then
    signal.wrong_type_argument(vars.Qcharsetp, x)
  end
  local attr = charset_symbol_attributes(x)
  if lisp.nilp(attr) then
    signal.wrong_type_argument(vars.Qcharsetp, x)
  end
  return attr
end
F.set_charset_plist = { 'set-charset-plist', 2, 2, 0, [[Set CHARSET's property list to PLIST.]] }
function F.set_charset_plist.f(charset, plist)
  local attrs = check_charset_get_attr(charset)
  lisp.aset(attrs, charset_idx.plist, plist)
  return plist
end
F.charset_plist = { 'charset-plist', 1, 1, 0, [[Return the property list of CHARSET.]] }
function F.charset_plist.f(charset)
  local attr = check_charset_get_attr(charset)
  return lisp.aref(attr, charset_idx.plist)
end
F.define_charset_alias =
  { 'define-charset-alias', 2, 2, 0, [[Define ALIAS as an alias for charset CHARSET.]] }
function F.define_charset_alias.f(alias, charset)
  local attrs = check_charset_get_attr(charset)
  vars.F.puthash(alias, attrs, vars.charset_hash_table)
  vars.V.charset_list = vars.F.cons(alias, vars.V.charset_list)
  return vars.Qnil
end
F.unify_charset = {
  'unify-charset',
  1,
  3,
  0,
  [[Unify characters of CHARSET with Unicode.
This means reading the relevant file and installing the table defined
by CHARSET's `:unify-map' property.

Optional second arg UNIFY-MAP is a file name string or a vector.  It has
the same meaning as the `:unify-map' attribute in the function
`define-charset' (which see).

Optional third argument DEUNIFY, if non-nil, means to de-unify CHARSET.]],
}
function F.unify_charset.f(charset, unify_map, deunify)
  local id = M.check_charset_get_id(charset)
  local cs = vars.charset_table[id]
  local attrs = charset_attributes(cs)
  if not lisp.nilp(deunify) and not cs.unified_p then
    return vars.Qnil
  elseif
    lisp.nilp(deunify)
    and cs.unified_p
    and not lisp.nilp(lisp.aref(attrs, charset_idx.deunifier))
  then
    return vars.Qnil
  end
  cs.unified_p = false
  if lisp.nilp(deunify) then
    if cs.method ~= charset_method.offset or cs.code_offset < 0x110000 then
      signal.error("Can't unify charset: %s", lisp.sdata(lisp.symbol_name(charset)))
    end
    if lisp.nilp(unify_map) then
      unify_map = lisp.aref(attrs, charset_idx.unify_map)
    else
      error('TODO')
    end
    if lisp.nilp(vars.char_unify_table) then
      vars.char_unify_table = vars.F.make_char_table(vars.Qnil, vars.Qnil)
    end
    chartab.set_range(vars.char_unify_table, cs.min_code, cs.max_code, charset)
    cs.unified_p = true
  else
    error('TODO')
  end
  return vars.Qnil
end
local function charsetp(obj)
  return fns.hash_lookup(vars.charset_hash_table --[[@as vim.elisp._hash_table]], obj) >= 0
end
F.charsetp = { 'charsetp', 1, 1, 0, [[Return non-nil if and only if OBJECT is a charset.]] }
function F.charsetp.f(obj)
  return charsetp(obj) and vars.Qt or vars.Qnil
end
F.set_charset_priority = {
  'set-charset-priority',
  1,
  -2,
  0,
  [[Assign higher priority to the charsets given as arguments.
usage: (set-charset-priority &rest charsets)]],
}
function F.set_charset_priority.fa(args)
  local old_list = vars.F.copy_sequence(vars.charset_ordered_list)
  local new_list = vars.Qnil
  for i = 1, #args do
    local id = M.check_charset_get_id(args[i])
    if not lisp.nilp(vars.F.memq(lisp.make_fixnum(id), old_list)) then
      old_list = vars.F.delq(lisp.make_fixnum(id), old_list)
      new_list = vars.F.cons(lisp.make_fixnum(id), new_list)
    end
  end
  vars.charset_non_preferred_head = old_list
  vars.charset_ordered_list = vars.F.nconc({ vars.F.nreverse(new_list), old_list })
  vars.charset_ordered_list_tick = vars.charset_ordered_list_tick + 1

  vars.charset_unibyte = -1
  old_list = vars.charset_ordered_list
  local list_2022 = vars.Qnil
  local list_emacs_mule = vars.Qnil
  while lisp.consp(old_list) do
    if not lisp.nilp(vars.F.memq(lisp.xcar(old_list), vars.iso_2022_charset_list)) then
      list_2022 = vars.F.cons(lisp.xcar(old_list), list_2022)
    end
    if not lisp.nilp(vars.F.memq(lisp.xcar(old_list), vars.emacs_mule_charset_list)) then
      list_emacs_mule = vars.F.cons(lisp.xcar(old_list), list_emacs_mule)
    end
    if vars.charset_unibyte < 0 then
      local charset = vars.charset_table[lisp.fixnum(lisp.xcar(old_list))]
      if charset.dimension == 1 and charset.ascii_compatible_p and charset.max_code >= 0x80 then
        vars.charset_unibyte = charset.id
      end
    end
    old_list = lisp.xcdr(old_list)
  end
  vars.iso_2022_charset_list = vars.F.nreverse(list_2022)
  vars.emacs_mule_charset_list = vars.F.nreverse(list_emacs_mule)
  if vars.charset_unibyte < 0 then
    vars.charset_unibyte = vars.charset_iso_8859_1
  end
  return vars.Qnil
end
---@param cfunc function?
---@param func vim.elisp.obj
---@param arg vim.elisp.obj
---@param cs vim.elisp.charset
---@param from number
---@param to number
local function map_charset_chars(cfunc, func, arg, cs, from, to)
  local partial = from > cs.min_code or to < cs.max_code
  if cs.method == charset_method.offset then
    local from_idx = code_point_to_index(cs, from)
    local to_idx = code_point_to_index(cs, to)
    local from_c = from_idx + cs.code_offset
    local to_c = to_idx + cs.code_offset
    if not _G.vim_elisp_later then
    elseif cs.unified_p then
      local attr = charset_attributes(cs)
      if not lisp.chartablep(lisp.aref(attr, charset_idx.deunifier)) then
        load_charset(cs, 2)
      end
      if lisp.chartablep(lisp.aref(attr, charset_idx.deunifier)) then
        error('TODO')
      else
        error('TODO')
      end
    end
    local range = vars.F.cons(lisp.make_fixnum(from_c), lisp.make_fixnum(to_c))
    if lisp.nilp(func) then
      assert(cfunc)(arg, range)
    else
      vars.F.funcall { func, range, arg }
    end
  elseif cs.method == charset_method.map then
    if _G.vim_elisp_later then
      error('TODO')
    end
  elseif cs.method == charset_method.subset then
    local attr = charset_attributes(cs)
    local subset_info = lisp.aref(attr, charset_idx.subset)
    cs = vars.charset_table[lisp.fixnum(lisp.aref(subset_info, 0))]
    local offset = lisp.fixnum(lisp.aref(subset_info, 3))
    from = from - offset
    if from < lisp.fixnum(lisp.aref(subset_info, 1)) then
      from = lisp.fixnum(lisp.aref(subset_info, 1))
    end
    to = to - offset
    if to > lisp.fixnum(lisp.aref(subset_info, 2)) then
      to = lisp.fixnum(lisp.aref(subset_info, 2))
    end
    map_charset_chars(cfunc, func, arg, cs, from, to)
  else
    assert(cs.method == charset_method.superset)
    local attrs = charset_attributes(cs)
    local parent = lisp.aref(attrs, charset_idx.superset)
    while lisp.consp(parent) do
      cs = vars.charset_table[lisp.fixnum(lisp.xcar(lisp.xcar(parent)))]
      local offset = lisp.fixnum(lisp.xcdr(lisp.xcar(parent)))
      local this_from = from > offset and from - offset or 0
      local this_to = to > offset and to - offset or 0
      if this_from < cs.min_code then
        this_from = cs.min_code
      end
      if this_to > cs.max_code then
        this_to = cs.max_code
      end
      map_charset_chars(cfunc, func, arg, cs, this_from, this_to)
      parent = lisp.xcdr(parent)
    end
  end
end
F.map_charset_chars = {
  'map-charset-chars',
  2,
  5,
  0,
  [[Call FUNCTION for all characters in CHARSET.
Optional 3rd argument ARG is an additional argument to be passed
to FUNCTION, see below.
Optional 4th and 5th arguments FROM-CODE and TO-CODE specify the
range of code points (in CHARSET) of target characters on which to
map the FUNCTION.  Note that these are not character codes, but code
points of CHARSET; for the difference see `decode-char' and
`list-charset-chars'.  If FROM-CODE is nil or imitted, it stands for
the first code point of CHARSET; if TO-CODE is nil or omitted, it
stands for the last code point of CHARSET.

FUNCTION will be called with two arguments: RANGE and ARG.
RANGE is a cons (FROM .  TO), where FROM and TO specify a range of
characters that belong to CHARSET on which FUNCTION should do its
job.  FROM and TO are Emacs character codes, unlike FROM-CODE and
TO-CODE, which are CHARSET code points.]],
}
function F.map_charset_chars.f(func, charset, arg, from_code, to_code)
  local cs = M.check_charset_get_charset(charset)
  local from, to
  if lisp.nilp(from_code) then
    from = cs.min_code
  else
    lisp.check_fixnat(from_code)
    from = lisp.fixnum(from_code)
    if from < cs.min_code then
      from = cs.min_code
    end
  end
  if lisp.nilp(to_code) then
    to = cs.max_code
  else
    lisp.check_fixnat(to_code)
    to = lisp.fixnum(to_code)
    if to > cs.max_code then
      to = cs.max_code
    end
  end
  map_charset_chars(nil, func, arg, cs, from, to)
  return vars.Qnil
end
local function maybe_unify_char(c, val)
  if lisp.fixnump(val) then
    return lisp.fixnum(val)
  elseif lisp.nilp(val) then
    return c
  end
  error('TODO')
end
---@param charset vim.elisp.charset
---@param code number
---@return number
local function decode_char_(charset, code)
  local c
  if code < charset.min_code or code > charset.max_code then
    return -1
  end
  if charset.method == charset_method.subset then
    error('TODO')
  elseif charset.method == charset_method.superset then
    error('TODO')
  else
    local char_index = code_point_to_index(charset, code)
    if char_index < 0 then
      return -1
    end
    if charset.method == charset_method.map then
      error('TODO')
    else
      assert(charset.method == charset_method.offset)
      c = char_index + charset.code_offset
      if charset.unified_p and b.MAX_UNICODE_CHAR < c and c <= b.MAX_5_BYTE_CHAR then
        local val = chartab.ref(vars.char_unify_table, c)
        c = maybe_unify_char(c, val)
      end
    end
  end
  return c
end
---@param charset vim.elisp.charset
---@param code number
local function decode_char(charset, code)
  if chars.asciicharp(code) and charset.ascii_compatible_p then
    return code
  elseif code < charset.min_code or code > charset.max_code then
    return -1
  elseif charset.unified_p then
    return decode_char_(charset, code)
  else
    error('TODO')
  end
end
F.decode_char = {
  'decode-char',
  2,
  2,
  0,
  [[Decode the pair of CHARSET and CODE-POINT into a character.
Return nil if CODE-POINT is not valid in CHARSET.

CODE-POINT may be a cons (HIGHER-16-BIT-VALUE . LOWER-16-BIT-VALUE),
although this usage is obsolescent.]],
}
function F.decode_char.f(charset, code_point)
  local id = M.check_charset_get_id(charset)
  local code = cons_to_unsigned(code_point)
  local charsetp_ = vars.charset_table[id]
  local c = decode_char(charsetp_, code)
  return (c >= 0 and lisp.make_fixnum(c) or vars.Qnil)
end
---@return number
local function encode_char_(charset, c)
  error('TODO')
end
---@param charset vim.elisp.charset
---@param c number
local function encode_char(charset, c)
  if chars.asciicharp(c) and charset.ascii_compatible_p then
    return c
  elseif
    charset.unified_p
    or charset.method == charset_method.subset
    or charset.method == charset_method.superset
  then
    encode_char_(charset, c)
  elseif c < charset.min_code or c > charset.max_code then
    return charset.invalid_code
  elseif charset.method == charset_method.offset then
    if charset.code_linear_p then
      return c - charset.code_offset + charset.min_code
    else
      return encode_char_(charset, c)
    end
  else
    error('TODO')
  end
end
F.encode_char = {
  'encode-char',
  2,
  2,
  0,
  [[Encode the character CH into a code-point of CHARSET.
Return the encoded code-point as an integer,
or nil if CHARSET doesn't support CH.]],
}
function F.encode_char.f(ch, charset)
  local id = M.check_charset_get_id(charset)
  chars.check_character(ch)
  local c = lisp.fixnum(ch)
  local charsetp_ = vars.charset_table[id]
  local code = encode_char(charsetp_, c)
  if code == charsetp_.invalid_code then
    return vars.Qnil
  end
  return lisp.make_fixnum(code)
end
F.clear_charset_maps = {
  'clear-charset-maps',
  0,
  0,
  0,
  [[
Internal use only.
Clear temporary charset mapping tables.
It should be called only from temacs invoked for dumping.]],
}
function F.clear_charset_maps.f()
  if lisp.chartablep(vars.char_unify_table) then
    vars.F.optimize_char_table(vars.char_unify_table, vars.Qnil)
  end
  return vars.Qnil
end

function M.init()
  vars.charset_hash_table = vars.F.make_hash_table({ vars.QCtest, vars.Qeq })
  vars.charset_table = {}
  vars.iso_charset_table = {}
  vars.emacs_mule_charset = {}
  vars.emacs_mule_bytes = {}
  vars.charset_ordered_list_tick = 0
  for i = 0, 255 do
    vars.emacs_mule_charset[i] = -1
    vars.emacs_mule_bytes[i] = 1
  end
  vars.emacs_mule_bytes[0x9a] = 3
  vars.emacs_mule_bytes[0x9b] = 3
  vars.emacs_mule_bytes[0x9c] = 4
  vars.emacs_mule_bytes[0x9d] = 4
  vars.iso_2022_charset_list = vars.Qnil
  vars.emacs_mule_charset_list = vars.Qnil
  vars.charset_ordered_list = vars.Qnil
  vars.char_unify_table = vars.Qnil
  vars.charset_jisx0201_roman = -1
  vars.charset_jisx0208_1978 = -1
  vars.charset_jisx0208 = -1
  vars.charset_ksc5601 = -1
  for i = 0, 2 do
    vars.iso_charset_table[i] = { [0] = {}, [1] = {} }
  end

  vars.charset_ascii = define_charset_internal(
    vars.Qascii,
    1,
    '\x00\x7F\0\0\0\0\0',
    0,
    127,
    b 'B',
    -1,
    0,
    true,
    false,
    0
  )
  vars.charset_iso_8859_1 = define_charset_internal(
    vars.Qiso_8859_1,
    1,
    '\x00\xFF\0\0\0\0\0',
    0,
    255,
    -1,
    -1,
    -1,
    true,
    false,
    0
  )
  vars.charset_unicode = define_charset_internal(
    vars.Qunicode,
    3,
    '\x00\xFF\x00\xFF\x00\x10\0',
    0,
    b.MAX_UNICODE_CHAR,
    -1,
    0,
    -1,
    true,
    false,
    0
  )
  vars.charset_emacs = define_charset_internal(
    vars.Qemacs,
    3,
    '\x00\xFF\x00\xFF\x00\x3F\0',
    0,
    b.MAX_5_BYTE_CHAR,
    -1,
    0,
    -1,
    true,
    true,
    0
  )
  vars.charset_eight_bit = define_charset_internal(
    vars.Qeight_bit,
    1,
    '\x80\xFF\0\0\0\0\0',
    128,
    255,
    -1,
    0,
    -1,
    false,
    true,
    b.MAX_5_BYTE_CHAR + 1
  )

  vars.charset_unibyte = vars.charset_iso_8859_1

  if not _G.vim_elisp_later then
    vars.V.charset_map_path =
      lisp.list(alloc.make_string(lisp.sdata(vars.V.data_directory) .. '/charsets'))
    assert(vim.fn.isdirectory(lisp.sdata(lisp.xcar(vars.V.charset_map_path))) == 1)
  else
    error('TODO')
  end
end
function M.init_syms()
  vars.defsubr(F, 'set_charset_plist')
  vars.defsubr(F, 'charset_plist')
  vars.defsubr(F, 'define_charset_internal')
  vars.defsubr(F, 'define_charset_alias')
  vars.defsubr(F, 'unify_charset')
  vars.defsubr(F, 'charsetp')
  vars.defsubr(F, 'set_charset_priority')
  vars.defsubr(F, 'map_charset_chars')
  vars.defsubr(F, 'decode_char')
  vars.defsubr(F, 'encode_char')
  vars.defsubr(F, 'clear_charset_maps')

  vars.defsym('Qemacs', 'emacs')
  vars.defsym('Qiso_8859_1', 'iso-8859-1')
  vars.defsym('Qeight_bit', 'eight-bit')
  vars.defsym('Qunicode', 'unicode')
  vars.defsym('Qascii', 'ascii')
  vars.defsym('QCname', ':name')
  vars.defsym('QCascii_compatible_p', ':ascii-compatible-p')

  vars.defvar_lisp('charset_list', 'charset-list', [[List of all charsets ever defined.]])
  vars.V.charset_list = vars.Qnil

  vars.defvar_lisp(
    'charset_map_path',
    'charset-map-path',
    [[List of directories to search for charset map files.]]
  )
  vars.V.charset_map_path = vars.Qnil

  vars.defvar_lisp(
    'current_iso639_language',
    'current-iso639-language',
    [[ISO639 language mnemonic symbol for the current language environment.
If the current language environment is for multiple languages (e.g. "Latin-1"),
the value may be a list of mnemonics.]]
  )
  vars.V.current_iso639_language = vars.Qnil
end
return M
