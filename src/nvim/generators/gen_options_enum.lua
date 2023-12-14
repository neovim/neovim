-- Generates option index enum and map of option name to option index.
-- Handles option full name, short name and aliases.

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

--- @param s string
--- @return string
local lowercase_to_titlecase = function(s)
  return s:sub(1, 1):upper() .. s:sub(2)
end

--- @type vim.option_meta[]
local options = require('options').options
--- @type { [string]: string }
local option_index = {}

-- Generate option index enum and populate the `option_index` dictionary.
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
