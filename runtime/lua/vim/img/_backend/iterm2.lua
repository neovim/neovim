---@class vim.img.Iterm2Backend: vim.img.Backend
local M = {}

---@param data string
local function write_seq(data)
  local terminal = require('vim.img._terminal')

  terminal.write(terminal.code.ESC) -- Begin sequence
  terminal.write(']1337;')

  terminal.write(data)              -- Write primary message

  terminal.write(terminal.code.BEL) -- End sequence
end

---@param image vim.img.Image
---@param args table<string, string>
local function write_multipart_image(image, args)
  -- Begin the transfer of the image file
  write_seq('MultipartFile=' .. table.concat(args, ';'))

  -- Begin sending parts as chunks
  image:for_each_chunk(function(chunk)
    write_seq('FilePart=' .. chunk)
  end)

  -- Conclude the image display
  write_seq('FileEnd')
end

---@param image vim.img.Image
---@param args table<string, string>
local function write_image(image, args)
  local data = image.data
  if not data then
    return
  end

  write_seq('File=' .. table.concat(args, ';') .. ':' .. data)
end

---@param image vim.img.Image
---@param opts? vim.img.Backend.RenderOpts
function M.render(image, opts)
  local terminal = require('vim.img._terminal')

  if not image:is_loaded() then
    return
  end

  opts = opts or {}
  if opts.pos then
    terminal.cursor.move(opts.pos.col, opts.pos.row, true)
  end

  local args = {
    -- NOTE: We MUST mark as inline otherwise not rendered and put in a downloads folder
    'inline=1',

    -- This will show a progress indicator for a multipart image
    'size=' .. tostring(image:size()),
  }

  -- Specify the name of the image, which iterm2 requires to be base64 encoded
  if image.name then
    table.insert(args, 'name=' .. vim.base64.encode(image.name))
  end

  -- If a size is provided (in cells), we add it as arguments
  if opts.size then
    table.insert(args, 'width=' .. tostring(opts.size.width))
    table.insert(args, 'height=' .. tostring(opts.size.height))

    -- We need to disable aspect ratio preservation, otherwise
    -- the desired width/height won't be respected
    table.insert(args, 'preserveAspectRatio=0')
  end

  -- Only iTerm2 3.5+ supports multipart images
  --
  -- WezTerm and others are assumed to NOT support multipart images
  --
  -- iTerm2 should have set TERM_PROGRAM and TERM_PROGRAM_VERSION,
  -- otherwise we assume a different terminal!
  ---@type string|nil
  local prog = vim.env.TERM_PROGRAM
  ---@type vim.Version|nil
  local version = vim.version.parse(vim.env.TERM_PROGRAM_VERSION or '')
  if prog == 'iTerm.app' and version and vim.version.ge(version, { 3, 5, 0 }) then
    write_multipart_image(image, args)
  else
    write_image(image, args)
  end

  if opts.pos then
    terminal.cursor.restore()
  end
end

return M
