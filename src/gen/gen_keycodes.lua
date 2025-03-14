local names_file = arg[1]

local hashy = require('gen.hashy')
local keycodes = require('nvim.keycodes')

local keycode_names = keycodes.names

local hashorder = {} --- @type string[]

--- @type table<string,integer[]>
--- Maps lower-case key names to their original indexes.
--- When multiple keys have the same name (e.g. TAB and K_TAB),
--- the name will have multiple original indexes.
local name_orig_idx = {}

--- @type table<string,integer>
--- Maps keys to the original indexes of their preferred names.
local key_orig_idx = {}

for i, keycode in ipairs(keycode_names) do
  local key = keycode[1]
  local name = keycode[2]
  local name_lower = name:lower()
  table.insert(hashorder, name_lower)
  if name_orig_idx[name_lower] == nil then
    name_orig_idx[name_lower] = { i }
  else
    table.insert(name_orig_idx[name_lower], i)
  end
  if key_orig_idx[key] == nil then
    key_orig_idx[key] = i
  end
end

table.sort(hashorder)
local hashfun
hashorder, hashfun = hashy.hashy_hash('get_special_key_code', hashorder, function(idx)
  return 'key_names_table[' .. idx .. '].name.data'
end, true)

--- @type table<string,integer>
--- Maps keys to the (after hash) indexes of the entries with preferred names.
local key_hash_idx = {}

local name_orig_idx_ = vim.deepcopy(name_orig_idx)
for i, lower_name in ipairs(hashorder) do
  local orig_idx = table.remove(name_orig_idx_[lower_name], 1)
  local keycode = keycode_names[orig_idx]
  local key = keycode[1]
  if key_orig_idx[key] == orig_idx then
    key_hash_idx[key] = i
  end
end
assert(vim.iter(vim.tbl_values(name_orig_idx_)):all(vim.tbl_isempty))

local names_tgt = assert(io.open(names_file, 'w'))
names_tgt:write([[
static const struct key_name_entry {
  int key;                  ///< Special key code or ascii value
  String name;              ///< Name of key
  const String *pref_name;  ///< Pointer to preferred key name
                            ///< (may be NULL or point to the name in another entry)
} key_names_table[] = {]])

name_orig_idx_ = vim.deepcopy(name_orig_idx)
for i, lower_name in ipairs(hashorder) do
  local orig_idx = table.remove(name_orig_idx_[lower_name], 1)
  local keycode = keycode_names[orig_idx]
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
assert(vim.iter(vim.tbl_values(name_orig_idx_)):all(vim.tbl_isempty))

names_tgt:write('\n};\n\n')
names_tgt:write('static ' .. hashfun)
names_tgt:close()
