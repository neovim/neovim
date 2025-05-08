---@class vim.ui.img.Header
---@field width integer
---@field height integer
---@field [string] any

---Parses an image's header, optionally loading from disk, to retrieve information.
---@param opts {data?:string, filename:string}
---@return vim.ui.img.Header
local function parse(opts)
  -- This is just a quick check by file extension, but obviously files
  -- can have whatever name (and extension) they want and the extension
  -- isn't even a guarantee that the file is that type.
  --
  -- TODO: Should we just try all of the formats by checking the signatures?
  local ext = vim.fn.fnamemodify(opts.filename, ':t:e'):lower()
  assert(ext ~= '', 'filename has no extension')
  if ext == 'png' then
    return require('vim.ui.img.header.png').parse(opts)
  end

  error(string.format('unsupported image format: %s', ext))
end

return {
  parse = parse,
}
