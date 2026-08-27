-- Shared codegen for a `KeySetLink` perfect-hash table and its `get_field()` lookup.
local hashy = require('gen.hashy')

local M = {}

--- Perfect-hash `keys`, using the shared `<name>_table[idx].str` probe convention.
--- @param name string
--- @param keys string[]
--- @return string[] order  keys in perfect-hash order
--- @return string hashfun  source of the `<name>_hash()` function
function M.hash(name, keys)
  return hashy.hashy_hash(name, keys, function(idx)
    return name .. '_table[' .. idx .. '].str'
  end)
end

--- @class gen.keyset.entry
--- @field field string       C struct field name, for offsetof()
--- @field type string        ObjectType/UnpackType enum, e.g. 'kObjectTypeInteger'
--- @field opt_index integer  index used by HAS_KEY (or -1 when the keyset has no optional keys)
--- @field is_hlgroup boolean

--- Emit `<name>_table[]` (a `KeySetLink[]` in perfect-hash `order`) followed by `<get_field>()`.
--- @param write fun(s: string)  writer that appends a newline
--- @param p { name: string, get_field: string, struct: string, order: string[], hashfun: string, entry: table<string, gen.keyset.entry>, static: boolean }
--- `static` emits a `static const` table + `static inline` funcs (a self-contained header, e.g. the
--- option keysets); otherwise external linkage (the API keydicts, declared in a separate header).
function M.emit(write, p)
  write(('%sKeySetLink %s_table[] = {'):format(p.static and 'static const ' or '', p.name))
  for _, key in ipairs(p.order) do
    local e = p.entry[key]
    write(
      ('  { "%s", offsetof(%s, %s), %s, %d, %s },'):format(
        key,
        p.struct,
        e.field,
        e.type,
        e.opt_index,
        e.is_hlgroup and 'true' or 'false'
      )
    )
  end
  write('  { NULL, 0, kObjectTypeNil, -1, false },')
  write('};')
  write('')
  local inl = p.static and 'static inline ' or ''
  write(inl .. p.hashfun)
  write(inl .. ('KeySetLink *%s(const char *str, size_t len)'):format(p.get_field))
  write('{')
  write(('  int hash = %s_hash(str, len);'):format(p.name))
  write(('  return hash == -1 ? NULL : (KeySetLink *)&%s_table[hash];'):format(p.name))
  write('}')
end

return M
