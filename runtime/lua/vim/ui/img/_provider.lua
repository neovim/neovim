---@class vim.ui.img.Provider
---@field render fun(image:vim.ui.img.Image, opts?:vim.ui.img.Provider.RenderOpts)

---@class vim.ui.img.Provider.RenderOpts
---@field crop? {x:integer, y:integer, width:integer, height:integer} units are pixels
---@field pos? {row:integer, col:integer} units are cells
---@field size? {width:integer, height:integer} units are cells

return {
  iterm2 = require('vim.ui.img._provider.iterm2'),
  kitty = require('vim.ui.img._provider.kitty'),
}
