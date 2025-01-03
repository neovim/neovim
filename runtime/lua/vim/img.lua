local img = vim._defer_require('vim.img', {
  _backend = ..., --- @module 'vim.img._backend'
  _detect = ..., --- @module 'vim.img._detect'
  _image = ..., --- @module 'vim.img._image'
  _terminal = ..., --- @module 'vim.img._terminal'
})

---Loads an image into memory, returning a wrapper around the image.
---
---Accepts `data` as base64-encoded bytes, or a `filename` that will be loaded.
---@param opts {data?:string, filename?:string}
---@return vim.img.Image
function img.load(opts)
  return img._image:new(opts)
end

img.protocol = (function()
  ---@class vim.img.Protocol 'iterm2'|'kitty'|'sixel'

  ---@type vim.img.Protocol|nil
  local protocol = nil

  local loaded = false

  ---Determines the preferred graphics protocol to use by default.
  ---
  ---@return vim.img.Protocol|nil
  return function()
    if not loaded then
      local graphics = img._detect().graphics

      ---@diagnostic disable-next-line:cast-type-mismatch
      ---@cast graphics vim.img.Protocol|nil
      protocol = graphics

      loaded = true
    end

    return protocol
  end
end)()

---@class vim.img.Opts: vim.img.Backend.RenderOpts
---@field backend? vim.img.Protocol|vim.img.Backend

---Displays the image within the terminal used by neovim.
---@param image vim.img.Image
---@param opts? vim.img.Opts
function img.show(image, opts)
  opts = opts or {}

  local backend = opts.backend

  -- If no graphics are explicitly defined, attempt to detect the
  -- preferred graphics. If we still cannot figure out a backend,
  -- throw an error early versus silently trying a protocol.
  if not backend then
    backend = img.protocol()
    assert(backend, 'no graphics backend available')
  end

  -- For named protocols, grab the appropriate backend, failing
  -- if there is not a default backend for the specified protocol.
  if type(backend) == 'string' then
    local protocol = backend
    backend = img._backend[protocol]
    assert(backend, 'unsupported backend: ' .. protocol)
  end

  ---@cast backend vim.img.Backend
  backend.render(image, {
    pos = opts.pos,
    size = opts.size,
    crop = opts.crop,
  })
end

return img
