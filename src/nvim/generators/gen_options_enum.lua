-- Generates option index enum and map of option name to option index.
-- Handles option full name, short name and aliases.
-- Also generates BV_ and WV_ enum constants.

local options_enum_file = arg[1]
local options_map_file = arg[2]
local options_enum_fd = assert(io.open(options_enum_file, 'w'))
local options_map_fd = assert(io.open(options_map_file, 'w'))

--- @param s string
local function enum_w(s)
  options_enum_fd:write(s .. '\n')
end

--- @param s string
local function map_w(s)
  options_map_fd:write(s .. '\n')
end

enum_w('// IWYU pragma: private, include "nvim/option_defs.h"')
enum_w('')

--- @param s string
--- @return string
local lowercase_to_titlecase = function(s)
  return s:sub(1, 1):upper() .. s:sub(2)
end

--- @type vim.option_meta[]
local options = require('options').options

-- Generate BV_ enum constants.
enum_w('/// "indir" values for buffer-local options.')
enum_w('/// These need to be defined globally, so that the BV_COUNT can be used with')
enum_w('/// b_p_script_stx[].')
enum_w('enum {')

local bv_val = 0

for _, o in ipairs(options) do
  assert(#o.scope == 1 or #o.scope == 2)
  assert(#o.scope == 1 or o.scope[1] == 'global')
  local min_scope = o.scope[#o.scope]
  if min_scope == 'buffer' then
    local varname = o.pv_name or o.varname or ('p_' .. (o.abbreviation or o.full_name))
    local bv_name = 'BV_' .. varname:sub(3):upper()
    enum_w(('  %s = %u,'):format(bv_name, bv_val))
    bv_val = bv_val + 1
  end
end

enum_w(('  BV_COUNT = %u,  ///< must be the last one'):format(bv_val))
enum_w('};')
enum_w('')

-- Generate WV_ enum constants.
enum_w('/// "indir" values for window-local options.')
enum_w('/// These need to be defined globally, so that the WV_COUNT can be used in the')
enum_w('/// window structure.')
enum_w('enum {')

local wv_val = 0

for _, o in ipairs(options) do
  assert(#o.scope == 1 or #o.scope == 2)
  assert(#o.scope == 1 or o.scope[1] == 'global')
  local min_scope = o.scope[#o.scope]
  if min_scope == 'window' then
    local varname = o.pv_name or o.varname or ('p_' .. (o.abbreviation or o.full_name))
    local wv_name = 'WV_' .. varname:sub(3):upper()
    enum_w(('  %s = %u,'):format(wv_name, wv_val))
    wv_val = wv_val + 1
  end
end

enum_w(('  WV_COUNT = %u,  ///< must be the last one'):format(wv_val))
enum_w('};')
enum_w('')

--- @type { [string]: string }
local option_index = {}

-- Generate option index enum and populate the `option_index` dict.
enum_w('typedef enum {')
enum_w('  kOptInvalid = -1,')

for i, o in ipairs(options) do
  local enum_val_name = 'kOpt' .. lowercase_to_titlecase(o.full_name)
  enum_w(('  %s = %u,'):format(enum_val_name, i - 1))

  option_index[o.full_name] = enum_val_name

  if o.abbreviation then
    option_index[o.abbreviation] = enum_val_name
  end

  if o.alias then
    o.alias = type(o.alias) == 'string' and { o.alias } or o.alias

    for _, v in ipairs(o.alias) do
      option_index[v] = enum_val_name
    end
  end
end

enum_w('  // Option count, used when iterating through options')
enum_w('#define kOptIndexCount ' .. tostring(#options))
enum_w('} OptIndex;')
enum_w('')

options_enum_fd:close()

--- Generate option index map.
local hashy = require('generators.hashy')
local neworder, hashfun = hashy.hashy_hash('find_option', vim.tbl_keys(option_index), function(idx)
  return ('option_hash_elems[%s].name'):format(idx)
end)

map_w('static const struct { const char *name; OptIndex opt_idx; } option_hash_elems[] = {')

for _, name in ipairs(neworder) do
  assert(option_index[name] ~= nil)
  map_w(('  { .name = "%s", .opt_idx = %s },'):format(name, option_index[name]))
end

map_w('};\n')
map_w('static ' .. hashfun)

options_map_fd:close()
