-- Text processing functions.

local M = {}

local alphabet = '0123456789ABCDEF'
local atoi = {} ---@type table<string, integer>
local itoa = {} ---@type table<integer, string>
do
  for i = 1, #alphabet do
    local char = alphabet:sub(i, i)
    itoa[i - 1] = char
    atoi[char] = i - 1
    atoi[char:lower()] = i - 1
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
    enc[2 * i - 1] = itoa[math.floor(byte / 16)]
    enc[2 * i] = itoa[byte % 16]
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
    local u = atoi[enc:sub(i, i)]
    local l = atoi[enc:sub(i + 1, i + 1)]
    if not u or not l then
      return nil, 'string must contain only hex characters'
    end
    str[(i + 1) / 2] = string.char(u * 16 + l)
  end
  return table.concat(str), nil
end

return M
