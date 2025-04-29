---@class vim.ui.img.Backend
---@field render fun(image:vim.ui.img.Image, opts?:vim.ui.img.Backend.RenderOpts)

---@class vim.ui.img.Backend.RenderOpts
---@field crop? {x:integer, y:integer, width:integer, height:integer} units are pixels
---@field pos? {row:integer, col:integer} units are cells
---@field size? {width:integer, height:integer} units are cells

return {
  iterm2 = require('vim.ui.img._backend.iterm2'),
  kitty = require('vim.ui.img._backend.kitty'),
}
