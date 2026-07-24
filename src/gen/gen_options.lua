---@diagnostic disable: no-unknown
local options_input_file = arg[7]

--- @module 'nvim.options'
local options = loadfile(options_input_file)()
local options_meta = options.options
local cstr = options.cstr
local valid_scopes = options.valid_scopes
local schema_values = options.schema_values
-- Limit for a free-string (`str`) dict value; opt_strings_check() rejects anything longer.
local keyset_str_max = 256

-- Object type of a `dict` key's value, for the generated KeySetLink table. String-ish kinds
-- (enum/str) are stored inline as fixed `char[]` (keyset_charsize); opt_fill() copies to them.
local keyset_ctype = {
  num = 'kObjectTypeInteger',
  snum = 'kObjectTypeInteger',
  enum = 'kObjectTypeString',
  str = 'kObjectTypeString',
}
-- C field type for `dict` key kinds (except enum/str, which use a fixed-size `char[]`).
local keyset_ftype = {
  num = 'Integer',
  snum = 'Integer',
}

--- Fixed `char[]` size for a string-ish dict key, to avoid allocations. An `enum` fits its longest
--- value, a `str` is limited to `keyset_str_max`. Returns nil for non-string kinds (num/snum/flag).
--- @param item vim.option_schema.dictkey
--- @return integer?
local function keyset_charsize(item)
  local kind = type(item) == 'string' and 'flag' or item[2]
  if kind == 'enum' then
    local n = 0
    for _, val in ipairs(item[3].values) do
      n = math.max(n, #val)
    end
    return n + 1
  elseif kind == 'str' then
    return keyset_str_max
  end
  return nil
end

--- @param o vim.option_meta
--- @return string
local function get_values_var(o)
  return ('opt_%s_values'):format(o.abbreviation or o.full_name)
end

--- True if an option is a dict option: a `dict` schema (typed key:value map, e.g. 'diffopt'), as
--- opposed to a flag/enum/char category. Dict options are stored as their (canonical) ":set"
--- string; the `dict` schema generates the keyset machinery used to validate and reify it on demand.
--- @param o vim.option_meta
--- @return boolean
local function is_dict_option(o)
  return o.schema ~= nil and o.schema.dict ~= nil
end

--- @param s string
--- @return string
local function lowercase_to_titlecase(s)
  return table.concat(vim.tbl_map(function(word) --- @param word string
    return word:sub(1, 1):upper() .. word:sub(2)
  end, vim.split(s, '[-_]')))
end

--- @param scope string
--- @param option_name string
--- @return string
local function get_scope_option(scope, option_name)
  return ('k%sOpt%s'):format(lowercase_to_titlecase(scope), lowercase_to_titlecase(option_name))
end

local redraw_flags = {
  ui_option = 'kOptFlagUIOption',
  tabline = 'kOptFlagRedrTabl',
  statuslines = 'kOptFlagRedrStat',
  current_window = 'kOptFlagRedrWin',
  current_buffer = 'kOptFlagRedrBuf',
  all_windows = 'kOptFlagRedrAll',
  curswant = 'kOptFlagCurswant',
  highlight_only = 'kOptFlagHLOnly',
}

local list_flags = {
  comma = 'kOptFlagComma',
  onecomma = 'kOptFlagOneComma',
  commacolon = 'kOptFlagComma|kOptFlagColon',
  onecommacolon = 'kOptFlagOneComma|kOptFlagColon',
  flags = 'kOptFlagFlagList',
  flagscomma = 'kOptFlagComma|kOptFlagFlagList',
}

--- @param o vim.option_meta
--- @return string
local function get_flags(o)
  --- @type string[]
  local flags = { '0' }

  --- @param f string
  local function add_flag(f)
    table.insert(flags, f)
  end

  if o.list then
    add_flag(list_flags[o.list])
  end

  for _, r_flag in ipairs(o.redraw or {}) do
    add_flag(redraw_flags[r_flag])
  end

  if o.expand then
    add_flag('kOptFlagExpand')
    if o.expand == 'nodefault' then
      add_flag('kOptFlagNoDefExp')
    end
  end

  for _, flag_desc in ipairs({
    { 'nodefault', 'NoDefault' },
    { 'no_mkrc', 'NoMkrc' },
    { 'secure' },
    { 'gettext' },
    { 'noglob', 'NoGlob' },
    { 'normal_fname_chars', 'NFname' },
    { 'normal_dname_chars', 'NDname' },
    { 'pri_mkrc', 'PriMkrc' },
    { 'deny_duplicates', 'NoDup' },
    { 'modelineexpr', 'MLE' },
    { 'func' },
  }) do
    local key_name, flag_suffix = flag_desc[1], flag_desc[2]
    if o[key_name] then
      local def_name = 'kOptFlag' .. (flag_suffix or lowercase_to_titlecase(key_name))
      add_flag(def_name)
    end
  end

  return table.concat(flags, '|')
end

--- @param opt_type vim.option_type
--- @return string
local function opt_type_enum(opt_type)
  return ('kOptValType%s'):format(lowercase_to_titlecase(opt_type))
end

--- @param scope vim.option_scope
--- @return string
local function opt_scope_enum(scope)
  return ('kOptScope%s'):format(lowercase_to_titlecase(scope))
end

--- @param o vim.option_meta
--- @return string
local function get_scope_flags(o)
  local scope_flags = '0'

  for _, scope in ipairs(o.scope) do
    scope_flags = ('%s | (1 << %s)'):format(scope_flags, opt_scope_enum(scope))
  end

  return scope_flags
end

--- @param o vim.option_meta
--- @return string
local function get_scope_idx(o)
  --- @type string[]
  local strs = {}

  for _, scope in pairs(valid_scopes) do
    local has_scope = vim.tbl_contains(o.scope, scope)
    strs[#strs + 1] = ('      [%s] = %s'):format(
      opt_scope_enum(scope),
      get_scope_option(scope, has_scope and o.full_name or 'Invalid')
    )
  end

  return ('{\n%s\n    }'):format(table.concat(strs, ',\n'))
end

--- @param s string
--- @return string
local function static_cstr_as_string(s)
  return ('{ .data = %s, .size = sizeof(%s) - 1 }'):format(s, s)
end

--- @param v vim.option_value|function
--- @return string
local function get_opt_val(v)
  --- @type vim.option_type
  local v_type

  if type(v) == 'function' then
    v, v_type = v() --[[ @as string, vim.option_type ]]

    if v_type == 'string' then
      v = static_cstr_as_string(v)
    end
  else
    v_type = type(v) --[[ @as vim.option_type ]]

    if v_type == 'boolean' then
      v = v and 'true' or 'false'
    elseif v_type == 'number' then
      v = ('%iL'):format(v)
    elseif v_type == 'string' then
      --- @cast v string
      v = static_cstr_as_string(cstr(v))
    end
  end

  return ('{ .type = %s, .data.%s = %s }'):format(opt_type_enum(v_type), v_type, v)
end

--- @param d vim.option_value|function
--- @param n string
--- @return string
local function get_defaults(d, n)
  if d == nil then
    error("option '" .. n .. "' should have a default value")
  end
  return get_opt_val(d)
end

--- @param i integer
--- @param o vim.option_meta
--- @param write fun(...: string)
local function dump_option(i, o, write)
  write('  [', ('%u'):format(i - 1) .. ']={')
  write('    .fullname=', cstr(o.full_name))
  if o.abbreviation then
    write('    .shortname=', cstr(o.abbreviation))
  end
  write('    .type=', opt_type_enum(o.type))
  write('    .flags=', get_flags(o))
  write('    .scope_flags=', get_scope_flags(o))
  write('    .scope_idx=', get_scope_idx(o))
  -- `chars` (dispatch tables) and `flagchars` don't generate completion values (they self-expand).
  local values = o.schema and schema_values(o.schema) or {}
  write('    .values=', (#values > 0 and get_values_var(o) or 'NULL'))
  write('    .values_len=', (#values > 0 and #values or '0'))
  -- A `dict` schema also emits an OptSchemaItem[]; expose it so the structured value conversion can
  -- read typed sub-values.
  write(
    '    .schema=',
    (is_dict_option(o) and ('opt_%s_schema'):format(o.abbreviation or o.full_name) or 'NULL')
  )
  write('    .flags_var=', (o.flags_varname and ('&%s'):format(o.flags_varname) or 'NULL'))
  if o.enable_if then
    write(('#if defined(%s)'):format(o.enable_if))
  end

  local is_window_local = #o.scope == 1 and o.scope[1] == 'win'

  if is_window_local then
    write('    .var=NULL')
  elseif o.varname then
    write('    .var=&', o.varname)
  elseif o.immutable then
    -- Immutable options can directly point to the default value.
    write(('    .var=&options[%u].def_val.data'):format(i - 1))
  else
    error('Option must be immutable or have a variable.')
  end

  write('    .immutable=', (o.immutable and 'true' or 'false'))
  write('    .opt_did_set_cb=', o.cb or 'NULL')
  write('    .opt_expand_cb=', o.expand_cb or 'NULL')

  if o.enable_if then
    write('#else')
    -- Hidden option directly points to default value.
    write(('    .var=&options[%u].def_val.data'):format(i - 1))
    -- Option is always immutable on the false branch of `enable_if`.
    write('    .immutable=true')
    write('#endif')
  end

  if not o.defaults then
    write('    .def_val=NIL_OPTVAL')
  elseif o.defaults.condition then
    write(('#if defined(%s)'):format(o.defaults.condition))
    write('    .def_val=', get_defaults(o.defaults.if_true, o.full_name))
    if o.defaults.if_false then
      write('#else')
      write('    .def_val=', get_defaults(o.defaults.if_false, o.full_name))
    end
    write('#endif')
  else
    write('    .def_val=', get_defaults(o.defaults.if_true, o.full_name))
  end

  write('  },')
end

--- Emit an option's flag-set enum from its `flagchars` or `flags` schema:
---   * `flagchars` (e.g. 'formatoptions'): a name->char map -> `enum { kFoWrap = 't', … }`
---   * `flags` (e.g. 'foldopen', 'virtualedit'): an ordered list of names (bit = 2^i) or of
---     {name, bit} pairs -> `typedef enum { kOptFdoFlagHor = 0x…, … } OptFdoFlags;`. A pair's
---     optional 3rd element overrides the C constant's token (e.g. 'NONE' -> `NoneU`).
--- @param o vim.option_meta
--- @return string
local function gen_token_enum(o)
  local out = {} --- @type string[]
  local function add(s)
    table.insert(out, s)
  end
  local opt_name = lowercase_to_titlecase(o.abbreviation or o.full_name)

  if o.schema.flagchars then
    -- Char flags complete as raw chars, so order is irrelevant; sort by name for a stable enum.
    local names = vim.tbl_keys(o.schema.flagchars) --[[ @as string[] ]]
    table.sort(names)
    add('')
    add('enum {')
    for _, name in ipairs(names) do
      add(
        ("  k%s%s = '%s',"):format(
          opt_name,
          lowercase_to_titlecase(name),
          (o.schema.flagchars[name]:gsub("[\\']", '\\%0'))
        )
      )
    end
    add('};')
    return table.concat(out, '\n')
  end

  -- Bitmask flags: collect (C-token, bit) and emit in bit order.
  local flags = {} --- @type {name:string,bit:integer}[]
  for i, entry in ipairs(o.schema.flags) do
    if type(entry) == 'string' then
      flags[#flags + 1] = { name = entry, bit = math.pow(2, i - 1) }
    else
      local e = entry --[[ @as {[1]:string, [2]:integer, [3]:string?} ]]
      flags[#flags + 1] = { name = e[3] or e[1], bit = e[2] }
    end
  end
  table.sort(flags, function(a, b)
    return a.bit < b.bit
  end)

  add('')
  add('typedef enum {')
  for _, f in ipairs(flags) do
    -- A "key:" token (e.g. 'messagesopt' "wait:") names its flag without the trailing colon.
    add(
      ('  kOpt%sFlag%s = 0x%02x,'):format(
        opt_name,
        lowercase_to_titlecase((f.name:gsub(':$', ''))),
        f.bit
      )
    )
  end
  add(('} Opt%sFlags;'):format(opt_name))
  return table.concat(out, '\n')
end

--- @param output_file string
--- @return table<string,string> options_index Map of option name to option index
local function gen_enums(output_file)
  --- Options for each scope.
  --- @type table<string, vim.option_meta[]>
  local scope_options = {}
  for _, scope in ipairs(valid_scopes) do
    scope_options[scope] = {}
  end

  local fd = assert(io.open(output_file, 'w'))

  --- @param s string
  local function write(s)
    fd:write(s)
    fd:write('\n')
  end

  -- Generate options enum file
  write('// IWYU pragma: private, include "nvim/option_defs.h"')
  write('')

  --- Map of option name to option index
  --- @type table<string, string>
  local option_index = {}

  -- Generate option index enum and populate the `option_index` and `scope_option` dicts.
  write('typedef enum {')
  write('  kOptInvalid = -1,')

  for i, o in ipairs(options_meta) do
    local enum_val_name = 'kOpt' .. lowercase_to_titlecase(o.full_name)
    write(('  %s = %u,'):format(enum_val_name, i - 1))

    option_index[o.full_name] = enum_val_name

    if o.abbreviation then
      option_index[o.abbreviation] = enum_val_name
    end

    local alias = o.alias or {} --[[@as string[] ]]
    for _, v in ipairs(alias) do
      option_index[v] = enum_val_name
    end

    for _, scope in ipairs(o.scope) do
      table.insert(scope_options[scope], o)
    end
  end

  write('  // Option count')
  write('#define kOptCount ' .. tostring(#options_meta))
  write('} OptIndex;')

  -- Generate option index enum for each scope
  for _, scope in ipairs(valid_scopes) do
    write('')

    local scope_name = lowercase_to_titlecase(scope)
    write('typedef enum {')
    write(('  %s = -1,'):format(get_scope_option(scope, 'Invalid')))

    for idx, option in ipairs(scope_options[scope]) do
      write(('  %s = %u,'):format(get_scope_option(scope, option.full_name), idx - 1))
    end

    write(('  // %s option count'):format(scope_name))
    write(('#define %s %d'):format(get_scope_option(scope, 'Count'), #scope_options[scope]))
    write(('} %sOptIndex;'):format(scope_name))
  end

  -- Generate reverse lookup from option scope index to option index for each scope.
  for _, scope in ipairs(valid_scopes) do
    write('')
    write(('EXTERN const OptIndex %s_opt_idx[] INIT( = {'):format(scope))
    for _, option in ipairs(scope_options[scope]) do
      local idx = option_index[option.full_name]
      write(('  [%s] = %s,'):format(get_scope_option(scope, option.full_name), idx))
    end
    write('});')
  end

  fd:close()

  return option_index
end

--- @param output_file string
--- @param option_index table<string,string>
local function gen_map(output_file, option_index)
  -- Generate option index map.
  local hashy = require('gen.hashy')

  local neworder, hashfun = hashy.hashy_hash(
    'find_option',
    vim.tbl_keys(option_index),
    function(idx)
      return ('option_hash_elems[%s].name'):format(idx)
    end
  )

  local fd = assert(io.open(output_file, 'w'))

  --- @param s string
  local function write(s)
    fd:write(s)
    fd:write('\n')
  end

  write('static const struct { const char *name; OptIndex opt_idx; } option_hash_elems[] = {')

  for _, name in ipairs(neworder) do
    assert(option_index[name] ~= nil)
    write(('  { .name = "%s", .opt_idx = %s },'):format(name, option_index[name]))
  end

  write('};')
  write('')
  write('static ' .. hashfun)

  fd:close()
end

-- Maps a `dict` key's value-kind to its OptSchemaKind enum. Enum keys carry a values array instead.
local schema_kinds = {
  num = 'kOptSchemaNum',
  snum = 'kOptSchemaSNum',
  str = 'kOptSchemaStr',
}

--- Emit the OptSchemaItem[] that opt_strings_check() validates against, from a `dict` schema.
--- @param prefix string  e.g. "opt_dip"
--- @param schema vim.option_schema
--- @return string
local function gen_opt_schema(prefix, schema)
  local out = {} --- @type string[]
  local function add(s)
    table.insert(out, s)
  end

  add('')
  add(('EXTERN const OptSchemaItem %s_schema[] INIT( = {'):format(prefix))
  for _, item in ipairs(schema.dict) do
    if type(item) == 'string' then
      add(('  { "%s", kOptSchemaFlag, NULL },'):format(item))
    elseif item[2] == 'enum' then
      add(('  { "%s", kOptSchemaEnum, %s_%s_values },'):format(item[1], prefix, item[1]))
    else
      local kind = schema_kinds[item[2]] or error(('%s: bad kind %q'):format(prefix, item[2]))
      add(('  { "%s", %s, NULL },'):format(item[1], kind))
    end
  end
  add('  { NULL, kOptSchemaFlag, NULL },')
  add('});')

  return table.concat(out, '\n')
end

--- Emit the completion values arrays (`opt_<name>_values`, plus `opt_<name>_<key>_values` for each
--- `dict` enum key). Enum/set/flag tokens complete as-is; `dict` keys complete as "key:".
--- @param prefix string  e.g. "opt_dip"
--- @param schema vim.option_schema
--- @return string
local function gen_schema_values(prefix, schema)
  local out = {} --- @type string[]
  local function add(s)
    table.insert(out, s)
  end

  local values = schema_values(schema)
  add('')
  add(('EXTERN const char *(%s_values[%s]) INIT( = {'):format(prefix, #values + 1))
  for _, v in ipairs(values) do
    add(('  "%s",'):format(v))
  end
  add('  NULL')
  add('});')

  for _, item in ipairs(schema.dict or {}) do
    if type(item) == 'table' and item[2] == 'enum' then
      local vals = item[3].values --[[ @as string[] ]]
      add('')
      add(('EXTERN const char *(%s_%s_values[%s]) INIT( = {'):format(prefix, item[1], #vals + 1))
      for _, v in ipairs(vals) do
        add(('  "%s",'):format(v))
      end
      add('  NULL')
      add('});')
    end
  end

  return table.concat(out, '\n')
end

local c_keywords = { inline = true, default = true, auto = true, register = true }

--- Sanitize a schema key into a C struct field name. C keywords get a trailing '_'.
--- @param name string
--- @return string
local function c_field_name(name)
  local f = (name:gsub('%-', '_'))
  return c_keywords[f] and (f .. '_') or f
end

--- @param output_file string
local function gen_vars(output_file)
  local fd = assert(io.open(output_file, 'w'))

  --- @param s string
  local function write(s)
    fd:write(s)
    fd:write('\n')
  end

  write('// IWYU pragma: private, include "nvim/option_vars.h"')

  -- Generate enums for option flags.
  for _, o in ipairs(options_meta) do
    if o.schema and (o.schema.flags or o.schema.flagchars) then
      write(gen_token_enum(o))
    end
  end

  -- Generate valid values (for completion) and, for `dict` schemas, the validation schema.
  for _, option in ipairs(options_meta) do
    local values_var = ('opt_%s'):format(option.abbreviation or option.full_name)
    -- `chars` dispatch tables (gen_chartab) and `flagchars` (gen_token_enum) have no completion
    -- values; every other schema does.
    if option.schema and #schema_values(option.schema) > 0 then
      write(gen_schema_values(values_var, option.schema))
      if is_dict_option(option) then
        write(gen_opt_schema(values_var, option.schema))
      end
    end
  end

  fd:close()
end

--- Emit the chars_tab[] dispatch tables (fcs_tab/lcs_tab) from options with a `char`/`chars`
--- schema.
---
---     #include "options_chartab.generated.h"
---
--- @param output_file string
local function gen_chartab(output_file)
  local fd = assert(io.open(output_file, 'w'))
  --- @param s string
  local function write(s)
    fd:write(s)
    fd:write('\n')
  end

  write('// IWYU pragma: private, include "nvim/optionstr.c"')
  for _, o in ipairs(options_meta) do
    if o.schema and o.schema.chars then
      local abbr = o.abbreviation or o.full_name
      write('')
      write(('static const struct chars_tab %s_tab[] = {'):format(abbr))
      for _, item in ipairs(o.schema.chars) do
        --- @cast item vim.option_schema.char
        local name = item[1]
        local opts = item[3] or {}
        -- opts.field == false means no storage (NULL cp), e.g. 'multispace'; nil defaults to name.
        local cp = 'NULL'
        if opts.field ~= false then
          cp = ('&%s_chars.%s'):format(abbr, opts.field or name)
        end
        local def = opts.def and ('"%s"'):format(opts.def) or 'NULL'
        local fallback = opts.fallback and ('"%s"'):format(opts.fallback) or 'NULL'
        write(('  CHARSTAB_ENTRY(%s, "%s", %s, %s),'):format(cp, name, def, fallback))
      end
      write('};')
    end
  end

  fd:close()
end

--- Emit an option keyset: a `KeyDict_…` struct + `KeySetLink` + perfect-hash get_field, generated
--- from a `dict` schema. Consumed by `api_dict_to_keydict()`.
--- @param output_file string
local function gen_keysets(output_file)
  local keyset = require('gen.keyset')
  local fd = assert(io.open(output_file, 'w'))
  local function write(s)
    fd:write(s)
    fd:write('\n')
  end

  write('#pragma once')
  write('')
  write('#include <stddef.h>')
  write('#include "nvim/api/private/defs.h"')
  write('#include "nvim/option_defs.h"')

  local struct_opts = {} --- @type {enum:string,abbr:string,kd:string}[]

  for _, o in ipairs(options_meta) do
    -- A `dict` schema reifies to a keyset; generate it here.
    if is_dict_option(o) then
      -- Mirrors the API's KeyDict codegen with an "Opt" prefix: struct OptKeyDict_<abbr>, and
      -- <abbr> as the keyset name for the table/hash/HAS_KEY (e.g. HAS_KEY(v, dip, filler)).
      local abbr = o.abbreviation or o.full_name
      local kd = 'OptKeyDict_' .. abbr
      struct_opts[#struct_opts + 1] =
        { enum = 'kOpt' .. lowercase_to_titlecase(o.full_name), abbr = abbr, kd = kd }
      local keys = {} --- @type string[]
      local info = {} --- @type table<string,{field:string,ctype:string}>
      for _, item in ipairs(o.schema.dict) do
        local key = type(item) == 'string' and item or item[1]
        local kind = type(item) == 'string' and 'flag' or item[2]
        keys[#keys + 1] = key
        info[key] = {
          field = c_field_name(key),
          ctype = keyset_ctype[kind] or 'kObjectTypeBoolean',
        }
      end

      -- The schema array (validation grammar) lives in option_vars.generated.h; forward-declare it
      -- so this header stays self-contained.
      write('')
      write(('extern const OptSchemaItem opt_%s_schema[];'):format(abbr))
      write('')
      write(('/// %s'):format(o.full_name))
      write(('typedef struct %s {'):format(kd))
      write(('  OptionalKeys is_set__%s_;'):format(abbr))
      for _, item in ipairs(o.schema.dict) do
        local key = type(item) == 'string' and item or item[1]
        local kind = type(item) == 'string' and 'flag' or item[2]
        local charsize = keyset_charsize(item)
        if charsize then
          write(('  char %s[%d];'):format(c_field_name(key), charsize))
        else
          write(('  %s %s;'):format(keyset_ftype[kind] or 'Boolean', c_field_name(key)))
        end
      end
      write(('} %s;'):format(kd))
      write('')

      local order, hashfun = keyset.hash(abbr, keys)
      local entry = {} --- @type table<string, gen.keyset.entry>
      for i, key in ipairs(order) do
        write(('#define KEYSET_OPTIDX_%s__%s %d'):format(abbr, c_field_name(key), i))
        entry[key] =
          { field = info[key].field, type = info[key].ctype, opt_index = i, is_hlgroup = false }
      end
      -- `static` (inline): diff.c includes this header for the struct type alone, so a plain `static`
      -- table/hash/get_field would warn as unused.
      keyset.emit(write, {
        name = abbr,
        get_field = kd .. '_get_field',
        struct = kd,
        order = order,
        hashfun = hashfun,
        entry = entry,
        static = true,
      })
    end
  end

  -- Union of all keyset types, for `opt_keyset(NULL, …)`.
  write('')
  write('typedef union {')
  for _, s in ipairs(struct_opts) do
    write(('  %s %s;'):format(s.kd, s.abbr))
  end
  write('} OptKeyDict;')

  -- Dispatch from option index to its keyset handle (opt_dict_info); NULL for non-dict options.
  write('')
  write('static inline const OptDictInfo *opt_dict_info(OptIndex opt_idx)')
  write('{')
  write('  switch (opt_idx) {')
  for _, s in ipairs(struct_opts) do
    write(('  case %s: {'):format(s.enum))
    write(
      ('    static const OptDictInfo info = { %s_get_field, %s_table, opt_%s_schema,'):format(
        s.kd,
        s.abbr,
        s.abbr
      )
    )
    write(('                                        sizeof(%s) };'):format(s.kd))
    write('    return &info;')
    write('  }')
  end
  write('  default:')
  write('    return NULL;')
  write('  }')
  write('}')

  fd:close()
end

--- @param output_file string
local function gen_options(output_file)
  local fd = assert(io.open(output_file, 'w'))

  --- @param ... string
  local function write(...)
    local s = table.concat({ ... }, '')
    fd:write(s)
    if s:match('^    %.') then
      fd:write(',')
    end
    fd:write('\n')
  end

  -- Generate options[] array.
  write([[
  #include "nvim/ex_docmd.h"
  #include "nvim/ex_getln.h"
  #include "nvim/insexpand.h"
  #include "nvim/mapping.h"
  #include "nvim/ops.h"
  #include "nvim/option.h"
  #include "nvim/optionstr.h"
  #include "nvim/quickfix.h"
  #include "nvim/runtime.h"
  #include "nvim/tag.h"
  #include "nvim/window.h"

  static vimoption_T options[] = {]])

  for i, o in ipairs(options_meta) do
    dump_option(i, o, write)
  end

  write('};')

  fd:close()
end

local function main()
  local options_file = arg[1]
  local options_enum_file = arg[2]
  local options_map_file = arg[3]
  local option_vars_file = arg[4]
  local options_chartab_file = arg[5]
  local options_keysets_file = arg[6]

  local option_index = gen_enums(options_enum_file)
  gen_map(options_map_file, option_index)
  gen_vars(option_vars_file)
  gen_chartab(options_chartab_file)
  gen_keysets(options_keysets_file)
  gen_options(options_file)
end

main()
