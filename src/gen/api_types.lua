local API_TYPES = {
  Window = 'integer',
  Tabpage = 'integer',
  Buffer = 'integer',
  Boolean = 'boolean',
  Object = 'any',
  Integer = 'integer',
  String = 'string',
  Array = 'any[]',
  LuaRef = 'function',
  Dict = 'table<string,any>',
  Float = 'number',
  HLGroupID = 'integer|string',
  void = 'nil',
}

local typed_container = require('gen.c_grammar').typed_container

--- Convert an API type to Lua
--- @param t string
--- @return string
local function api_type(t)
  if vim.startswith(t, '*') then
    return api_type(t:sub(2)) .. '?'
  end

  --- @type nvim.c_grammar.Container?
  local t0 = typed_container:match(t)

  if t0 then
    local container = t0[1]

    if container == 'ArrayOf' then
      --- @cast t0 nvim.c_grammar.Container.ArrayOf
      local ty = api_type(t0[2])
      local count = tonumber(t0[3])
      if count then
        return ('[%s]'):format(ty:rep(count, ', '))
      else
        return ty .. '[]'
      end
    elseif container == 'Dict' or container == 'DictAs' then
      --- @cast t0 nvim.c_grammar.Container.Dict
      return 'vim.api.keyset.' .. t0[2]:gsub('__', '.')
    elseif container == 'DictOf' then
      --- @cast t0 nvim.c_grammar.Container.DictOf
      local ty = api_type(t0[2])
      return ('table<string,%s>'):format(ty)
    elseif container == 'Tuple' then
      --- @cast t0 nvim.c_grammar.Container.Tuple
      return ('[%s]'):format(table.concat(vim.tbl_map(api_type, t0[2]), ', '))
    elseif container == 'Enum' or container == 'Union' then
      --- @cast t0 nvim.c_grammar.Container.Enum|nvim.c_grammar.Container.Union
      return table.concat(vim.tbl_map(api_type, t0[2]), '|')
    elseif container == 'LuaRefOf' then
      --- @cast t0 nvim.c_grammar.Container.LuaRefOf
      local _, as, r = unpack(t0)

      local as1 = {} --- @type string[]
      for _, a in ipairs(as) do
        local ty, nm = unpack(a)
        nm = nm:gsub('%*(.*)$', '%1?')
        as1[#as1 + 1] = ('%s: %s'):format(nm, api_type(ty))
      end

      return ('fun(%s)%s'):format(table.concat(as1, ', '), r and ': ' .. api_type(r) or '')
    end
    error('Unknown container type: ' .. container)
  end

  return API_TYPES[t] or t
end

return api_type
