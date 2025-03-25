---TODO: profile if this is needed
local bytes = { no_break_space = 160 }
bytes.CHAR_ALT = 0x0400000
bytes.CHAR_SUPER = 0x0800000
bytes.CHAR_HYPER = 0x1000000
bytes.CHAR_SHIFT = 0x2000000
bytes.CHAR_CTL = 0x4000000
bytes.CHAR_META = 0x8000000
bytes.CHAR_MODIFIER_MASK = bit.bor(
  bytes.CHAR_ALT,
  bytes.CHAR_SUPER,
  bytes.CHAR_HYPER,
  bytes.CHAR_SHIFT,
  bytes.CHAR_CTL,
  bytes.CHAR_META
)

bytes.MAX_1_BYTE_CHAR = 0x7F
bytes.MAX_2_BYTE_CHAR = 0x7FF
bytes.MAX_3_BYTE_CHAR = 0xFFFF
bytes.MAX_4_BYTE_CHAR = 0x1FFFFF
bytes.MAX_5_BYTE_CHAR = 0x3FFF7F
bytes.MAX_CHAR = 0x3FFFFF
bytes.MAX_UNICODE_CHAR = 0x10FFFF

for i = 0, 255 do
  bytes[string.char(i)] = i
end
return setmetatable(bytes, { __call = rawget })
