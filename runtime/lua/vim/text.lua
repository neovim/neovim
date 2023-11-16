--- Text processing functions.

local M = {}

--- Hex encode a string.
---
--- @param str string String to encode
--- @return string Hex encoded string
function M.hexencode(str)
  local bytes = { str:byte(1, #str) }
  local enc = {} ---@type string[]
  for i = 1, #bytes do
    enc[i] = string.format('%02X', bytes[i])
  end
  return table.concat(enc)
end

--- Hex decode a string.
---
--- @param enc string String to decode
--- @return string Decoded string
function M.hexdecode(enc)
  assert(#enc % 2 == 0, 'string must have an even number of hex characters')
  local str = {} ---@type string[]
  for i = 1, #enc, 2 do
    local n = assert(tonumber(enc:sub(i, i + 1), 16))
    str[#str + 1] = string.char(n)
  end
  return table.concat(str)
end

return M
