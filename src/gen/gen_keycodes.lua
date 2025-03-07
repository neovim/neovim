local names_file = arg[1]

local keycodes = require('nvim.keycodes')

local names_tgt = assert(io.open(names_file, 'w'))

--- @type [string, string, integer][]
local keycode_names = {}
for i, keycode in ipairs(keycodes.names) do
  table.insert(keycode_names, { keycode[1], keycode[2], i })
end
table.sort(keycode_names, function(keycode_a, keycode_b)
  return keycode_a[2]:lower() < keycode_b[2]:lower()
end)

--- @type table<string,integer>
local alt_name_idx = {}
for i, keycode in ipairs(keycode_names) do
  local key = keycode[1]
  local alt_idx = alt_name_idx[key]
  if alt_idx == nil or keycode_names[alt_idx][3] > keycode[3] then
    alt_name_idx[key] = i
  end
end

names_tgt:write([[
static const struct key_name_entry {
  int key;                 ///< Special key code or ascii value
  String name;             ///< Name of key
  const String *alt_name;  ///< Pointer to alternative key name
                           ///< (may be NULL or point to the name in another entry)
} key_names_table[] = {]])

for i, keycode in ipairs(keycode_names) do
  local key = keycode[1]
  local name = keycode[2]
  local alt_idx = alt_name_idx[key]
  names_tgt:write(
    ('\n  {%s, {"%s", %d}, %s},'):format(
      key,
      name,
      #name,
      alt_idx == i and 'NULL' or ('&key_names_table[%d].name'):format(alt_idx - 1)
    )
  )
end

names_tgt:write('\n};\n')
names_tgt:close()
