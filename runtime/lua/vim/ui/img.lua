local M = {}

---Loads an image into memory, returning a wrapper around the image.
---
---Accepts `data` as base64-encoded bytes, or a `filename` that will be loaded.
---@param opts {data?:string, filename?:string}
---@return vim.ui.img.Image
function M.load(opts)
  local Img = require('vim.ui.img._image')
  return Img:new(opts)
end

M.protocol = (function()
  ---@class vim.ui.img.Protocol 'iterm2'|'kitty'|'sixel'

  ---@type vim.ui.img.Protocol|nil
  local protocol = nil

  local loaded = false

  ---Determines the preferred graphics protocol to use by default.
  ---
  ---@return vim.ui.img.Protocol|nil
  return function()
    if not loaded then
      local detect = require('vim.ui.img._detect')
      local graphics = detect().graphics

      ---@diagnostic disable-next-line:cast-type-mismatch
      ---@cast graphics vim.ui.img.Protocol|nil
      protocol = graphics

      loaded = true
    end

    return protocol
  end
end)()

---@class vim.ui.img.Opts: vim.ui.img.Provider.RenderOpts
---@field provider? vim.ui.img.Protocol|vim.ui.img.Provider

---Displays an image. Currently only supports the |TUI|.
---@param image vim.ui.img.Image
---@param opts? vim.ui.img.Opts
function M.show(image, opts)
  opts = opts or {}

  local provider = opts.provider

  -- If no graphics are explicitly defined, attempt to detect the
  -- preferred graphics. If we still cannot figure out a provider,
  -- throw an error early versus silently trying a protocol.
  if not provider then
    provider = M.protocol()
    assert(provider, 'no graphics provider available')
  end

  -- For named protocols, grab the appropriate provider, failing
  -- if there is not a default provider for the specified protocol.
  if type(provider) == 'string' then
    local protocol = provider
    provider = require('vim.ui.img._provider')[protocol]
    assert(provider, 'unsupported provider: ' .. protocol)
  end

  ---@cast provider vim.ui.img.Provider
  provider.render(image, {
    pos = opts.pos,
    size = opts.size,
    crop = opts.crop,
  })
end

return M
