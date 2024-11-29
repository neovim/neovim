local img = vim._defer_require('vim.img', {
  _backend = ...,  --- @module 'vim.img._backend'
  _image = ...,    --- @module 'vim.img._image'
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
  ---@class vim.img.Protocol "iterm2"|"kitty"|"sixel"

---@class vim.img.Opts: vim.img.Backend.RenderOpts
---@field backend? vim.img.Protocol|vim.img.Backend

---Displays the image within the terminal used by neovim.
---@param image vim.img.Image
---@param opts? vim.img.Opts
function img.show(image, opts)
  opts = opts or {}

  local backend = opts.backend

  -- For named protocols, grab the appropriate backend, failing
  -- if there is not a default backend for the specified protocol.
  if type(backend) == "string" then
    local protocol = backend
    backend = img._backend[protocol]
    assert(backend, "unsupported backend: " .. protocol)
  end

  ---@cast backend vim.img.Backend
  backend.render(image, {
    pos = opts.pos,
    size = opts.size,
    crop = opts.crop,
  })
end

return img
