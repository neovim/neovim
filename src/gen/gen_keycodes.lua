local names_file = arg[1]

local hashy = require('gen.hashy')
local keycodes = require('nvim.keycodes')

local keycode_names = keycodes.names

--- @type table<string,integer>
--- Maps lower-case key names to their original indexes.
local name_orig_idx = {}

--- @type table<string,integer>
--- Maps keys to the original indexes of their preferred names.
local key_orig_idx = {}

--- @type [string, string][]
--- When multiple keys have the same name (e.g. TAB and K_TAB), only the first one
--- is added to the two tables above, and the other keys are added here.
local extra_keys = {}

for i, keycode in ipairs(keycode_names) do
  local key = keycode[1]
  local name = keycode[2]
  local name_lower = name:lower()
  if name_orig_idx[name_lower] == nil then
    name_orig_idx[name_lower] = i
    if key_orig_idx[key] == nil then
      key_orig_idx[key] = i
    end
  else
    table.insert(extra_keys, keycode)
  end
end

local hashorder = vim.tbl_keys(name_orig_idx)
table.sort(hashorder)
local hashfun
hashorder, hashfun = hashy.hashy_hash('get_special_key_code', hashorder, function(idx)
  return 'key_names_table[' .. idx .. '].name.data'
end, true)

--- @type table<string,integer>
--- Maps keys to the (after hash) indexes of the entries with preferred names.
local key_hash_idx = {}

for i, lower_name in ipairs(hashorder) do
  local orig_idx = name_orig_idx[lower_name]
  local key = keycode_names[orig_idx][1]
  if key_orig_idx[key] == orig_idx then
    key_hash_idx[key] = i
  end
end

local names_tgt = assert(io.open(names_file, 'w'))
names_tgt:write([[
static const struct key_name_entry {
  int key;                  ///< Special key code or ascii value
  String name;              ///< Name of key
  const String *pref_name;  ///< Pointer to preferred key name
                            ///< (may be NULL or point to the name in another entry)
} key_names_table[] = {]])

for i, lower_name in ipairs(hashorder) do
  local keycode = keycode_names[name_orig_idx[lower_name]]
  local key = keycode[1]
  local name = keycode[2]
  local pref_idx = key_hash_idx[key]
  names_tgt:write(
    ('\n  {%s, {"%s", %u}, %s},'):format(
      key,
      name,
      #name,
      pref_idx == i and 'NULL' or ('&key_names_table[%u].name'):format(pref_idx - 1)
    )
  )
end

for _, keycode in ipairs(extra_keys) do
  local key = keycode[1]
  local name = keycode[2]
  names_tgt:write(('\n  {%s, {"%s", %u}, NULL},'):format(key, name, #name))
end

names_tgt:write('\n};\n\n')
names_tgt:write('static ' .. hashfun)
names_tgt:close()
