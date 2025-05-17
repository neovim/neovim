---@class vim.ui.img.parser.Header
---@field width integer
---@field height integer
---@field [string] any

---@class vim.ui.img.parser.Data
---@field bytes string

---Generic parser for images that is able to extract header information (i.e. size) and data.
---@class vim.ui.img.Parser
local M = {}

---Parses an image, optionally loading from disk, to retrieve information.
---@param opts {bytes?:string, filename:string, only_header?:boolean}
---@return vim.ui.img.parser.Header, vim.ui.img.parser.Data|nil
function M.parse(opts)
  -- This is just a quick check by file extension, but obviously files
  -- can have whatever name (and extension) they want and the extension
  -- isn't even a guarantee that the file is that type.
  --
  -- TODO: Should we just try all of the formats by checking the signatures?
  local ext = vim.fn.fnamemodify(opts.filename, ':t:e'):lower()
  assert(ext ~= '', 'filename has no extension')
  if ext == 'png' then
    return require('vim.ui.img.parser.png').parse(opts)
  end

  error(string.format('unsupported image format: %s', ext))
end

return M
