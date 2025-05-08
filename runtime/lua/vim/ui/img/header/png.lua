---@class vim.ui.img.header.PNG: vim.ui.img.Header
---@field width integer
---@field height integer
---@field bit_depth integer
---@field color_type integer
---@field compression integer
---@field filter integer
---@field interlace integer

---Parses the image's header bytes. If not loaded, will load the first 24 bytes.
---Header is cached within the image and reused unless `force=true`.
---@param opts {data?:string, filename:string}
---@return vim.ui.img.header.PNG
local function parse(opts)
  -- Bytes 30-33 (last four bytes of header) are CRC which we can ignore
  local HEADER_SIZE = 29 -- 8 (sig) + 4 (len) + 4 (type) + 13 (IHDR data) + 4 (CRC, unused)

  -- If we have the data already loaded, grab the header from it
  local header = opts.data
  header = header and string.sub(header, 1, HEADER_SIZE)

  -- Otherwise, attempt to load the header bytes from the file (blocking)
  if not header or string.len(header) < HEADER_SIZE then
    local fd = assert(vim.uv.fs_open(opts.filename, 'r', 0))

    header = ''
    while string.len(header) < HEADER_SIZE do
      local chunk = assert(vim.uv.fs_read(fd, HEADER_SIZE - string.len(header)))
      header = header .. chunk
    end

    assert(vim.uv.fs_close(fd))
  end

  -- Validate that this header is for a PNG and that we have the IDHR chunk
  -- containing header information.
  --
  -- 1. First 8 bytes are the PNG "magic number"
  -- 2. Next 4 bytes are IDHR chunk length, which we can skip
  -- 3. Next 4 bytes are IDHR type marker
  assert(string.sub(header, 1, 8) == '\137PNG\r\n\026\n', 'invalid PNG signature')
  assert(string.sub(header, 13, 16) == 'IHDR', 'missing IHDR chunk')

  ---Parses a 4-byte big-endian string as an unsigned 32-bit integer.
  ---@param s string # A 4-byte string (must be exactly 4 bytes long)
  ---@return integer # The parsed unsigned 32-bit integer
  local function u32be(s)
    local b1, b2, b3, b4 = string.byte(s, 1, 4)
    return b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
  end

  -- Data we care about is contained between bytes 17-29
  local width = u32be(string.sub(header, 17, 20))
  local height = u32be(string.sub(header, 21, 24))
  local bit_depth = string.byte(header, 25)
  local color_type = string.byte(header, 26)
  local compression = string.byte(header, 27)
  local filter = string.byte(header, 28)
  local interlace = string.byte(header, 29)

  return {
    width = width,
    height = height,
    bit_depth = bit_depth,
    color_type = color_type,
    compression = compression,
    filter = filter,
    interlace = interlace,
  }
end

return {
  parse = parse,
}
