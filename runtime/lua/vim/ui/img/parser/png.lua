---@class (exact) vim.ui.img.parser.png.Header: vim.ui.img.parser.Header
---@field width integer
---@field height integer
---@field bit_depth integer
---@field color_type integer
---@field compression integer
---@field filter integer
---@field interlace integer

---@class (exact) vim.ui.img.parser.png.Data: vim.ui.img.parser.Data
---@field bytes string
---@field chunks vim.ui.img.parser.png.Chunk[]

---@class (exact) vim.ui.img.parser.png.Chunk
---@field length integer total bytes contained in chunk data (range)
---@field type string 4 bytes denoting the chunk type
---@field range {[1]:integer, [2]:integer} start and ending byte offset for data
---@field crc string 4 byte CRC of the type and data (range)

---Unique signature indicating the file as a PNG.
---@type string
local PNG_SIGNATURE = '\137PNG\r\n\026\n'
local PNG_SIGNATURE_LENGTH = string.len(PNG_SIGNATURE)

---@param chunk_or_length vim.ui.img.parser.png.Chunk|integer
---@return integer
local function png_chunk_size(chunk_or_length)
  ---@type integer
  local length

  if type(chunk_or_length) == 'table' then
    length = chunk_or_length.length
  elseif type(chunk_or_length) == 'number' then
    length = chunk_or_length
  end

  return length + 12
end

---Total bytes of an IHDR chunk's data section.
---@type integer
local IHDR_CHUNK_DATA_LENGTH = 13
local IHDR_CHUNK_LENGTH = png_chunk_size(IHDR_CHUNK_DATA_LENGTH)

---Parses a 4-byte big-endian string as an unsigned 32-bit integer.
---@param s string # A 4-byte string (must be exactly 4 bytes long)
---@return integer # The parsed unsigned 32-bit integer
local function u32be(s)
  local b1, b2, b3, b4 = string.byte(s, 1, 4)
  return b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
end

---@param bytes string bytes to slice
---@param offset integer start of the slice (base index 1)
---@param len integer total bytes of the slice
---@return string
local function slice(bytes, offset, len)
  return string.sub(bytes, offset, offset + len - 1)
end

---Parses the next PNG chunk from the bytes.
---@param bytes string the full bytes of the PNG
---@param offset? integer how far past the beginning of the bytes to start parsing
---@return vim.ui.img.parser.png.Chunk
local function parse_chunk(bytes, offset)
  offset = offset or 0

  -- We use an offset to advance through the bytes instead of copying chunks around,
  -- so we need to see how much of our full bytes is remaining based on the offset
  local remaining_len = string.len(bytes) - offset
  assert(remaining_len > 4, 'invalid chunk len <= 4')

  -- Examine the length of the chunk, and make sure we still have enough bytes
  local chunk_length = u32be(slice(bytes, 1 + offset, 4))
  assert(remaining_len >= chunk_length, 'bytes len < chunk len of ' .. tostring(chunk_length))

  -- Grab the chunk's type and 32-bit CRC from the chunk
  local chunk_type = slice(bytes, 5 + offset, 4)
  local chunk_crc = slice(bytes, chunk_length - 4 + offset, 4)

  -- Instead of copying a portion of the chunk, we just return the byte range that
  -- represents the chunk for the time being since we don't always need the bytes
  local chunk_range = { 9 + offset, chunk_length - 4 + offset }

  return {
    ['length'] = chunk_length,
    ['type'] = chunk_type,
    ['range'] = chunk_range,
    ['crc'] = chunk_crc,
  }
end

---Parses the PNG header from the bytes.
---@param bytes string
---@param offset? integer
---@return vim.ui.img.parser.png.Header
local function parse_header(bytes, offset)
  local chunk = parse_chunk(bytes, offset)
  vim.print(chunk)
  assert(chunk.type == 'IHDR', 'header chunk (' .. chunk.type .. ') not IHDR type')
  assert(chunk.length == IHDR_CHUNK_DATA_LENGTH, 'invalid IHDR chunk data size')

  -- Set our offset to the start of the chunk's data
  offset = chunk.range[1]

  ---@type vim.ui.img.parser.png.Header
  return {
    width = u32be(slice(bytes, offset, 4)),
    height = u32be(slice(bytes, offset + 4, 4)),
    bit_depth = string.byte(bytes, offset + 8),
    color_type = string.byte(bytes, offset + 9),
    compression = string.byte(bytes, offset + 10),
    filter = string.byte(bytes, offset + 11),
    interlace = string.byte(bytes, offset + 12),
  }
end

---@class vim.ui.img.parser.png.Parser
local M = {}

---Parses a PNG image, loading the image into memory if not provided.
---@param opts {bytes?:string, filename:string, only_header?:boolean}
---@return vim.ui.img.parser.png.Header, vim.ui.img.parser.png.Data|nil
function M.parse(opts)
  -- If we have the bytes already loaded, grab the header from it
  local bytes = opts.bytes
  local offset = 0

  ---@param len integer
  local function advance(len)
    offset = offset + len
  end

  ---@return boolean
  local function has_more()
    local len = string.len(bytes or '')
    return offset < len
  end

  -- Otherwise, attempt to load the header bytes from the file (blocking)
  if not bytes then
    local fd = assert(vim.uv.fs_open(opts.filename, 'r', 0))

    -- Determine if we read the entire file or just enough to get the header
    local max_byte_length = 0
    if opts.only_header then
      max_byte_length = PNG_SIGNATURE_LENGTH + IHDR_CHUNK_LENGTH
    end

    -- Read either the entire file or just the header
    bytes = ''
    while max_byte_length == 0 or string.len(bytes) < max_byte_length do
      local chunk_length = 4096
      if opts.only_header then
        chunk_length = max_byte_length - string.len(bytes)
      end

      local chunk = assert(vim.uv.fs_read(fd, chunk_length))
      if chunk == '' then
        break
      end

      bytes = bytes .. chunk
    end

    assert(vim.uv.fs_close(fd))
  end

  -- Validate that this header is for a PNG
  assert(string.sub(bytes, 1, PNG_SIGNATURE_LENGTH) == PNG_SIGNATURE, 'invalid PNG signature')
  advance(PNG_SIGNATURE_LENGTH)

  -- First chunk should be our header
  local header = parse_header(bytes, offset)
  advance(IHDR_CHUNK_LENGTH)

  -- Remaining chunks should be our PNG
  ---@type vim.ui.img.parser.png.Data|nil
  local data
  if not opts.only_header then
    data = { bytes = bytes, chunks = {} }
    while has_more() do
      local ok = pcall(function()
        local chunk = parse_chunk(bytes, offset)
        advance(png_chunk_size(chunk))
        table.insert(data.chunks, chunk)
      end)

      if not ok then
        break
      end
    end
  end

  return header, data
end

return M
