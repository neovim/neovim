-- Text processing functions.

local M = {}

local alphabet = '0123456789ABCDEF'
local lookup = {} ---@type table<integer|string, integer|string>
do
  for i = 1, #alphabet do
    local char = alphabet:sub(i, i)
    lookup[i - 1] = char
    lookup[char] = i - 1
    lookup[char:lower()] = i - 1
  end
end

--- Hex encode a string.
---
--- @param str string String to encode
--- @return string : Hex encoded string
function M.hexencode(str)
  local enc = {} ---@type string[]
  for i = 1, #str do
    local byte = str:byte(i)
    enc[#enc + 1] = lookup[math.floor(byte / 16)] --[[@as string]]
    enc[#enc + 1] = lookup[byte % 16] --[[@as string]]
  end
  return table.concat(enc)
end

--- Hex decode a string.
---
--- @param enc string String to decode
--- @return string? : Decoded string
--- @return string? : Error message, if any
function M.hexdecode(enc)
  if #enc % 2 ~= 0 then
    return nil, 'string must have an even number of hex characters'
  end

  local str = {} ---@type string[]
  for i = 1, #enc, 2 do
    local u = lookup[enc:sub(i, i)] --[[@as integer]]
    local l = lookup[enc:sub(i + 1, i + 1)] --[[@as integer]]
    if not u or not l then
      return nil, 'string must contain only hex characters'
    end
    str[#str + 1] = string.char(u * 16 + l)
  end
  return table.concat(str), nil
end

return M
