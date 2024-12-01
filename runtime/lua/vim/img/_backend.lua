---@class vim.img.Backend
---@field render fun(image:vim.img.Image, opts?:vim.img.Backend.RenderOpts)

---@class vim.img.Backend.RenderOpts
---@field crop? {x:integer, y:integer, width:integer, height:integer} units are pixels
---@field pos? {row:integer, col:integer} units are cells
---@field size? {width:integer, height:integer} units are cells

return vim._defer_require('vim.img._backend', {
  iterm2 = ..., --- @module 'vim.img._backend.iterm2'
  kitty = ..., --- @module 'vim.img._backend.kitty'
})
