---@class vim.img.Backend
local M = {}

---@class vim.img.Backend.RenderOpts
---@field crop? {x:integer, y:integer, width:integer, height:integer} units are pixels
---@field pos? {row:integer, col:integer} units are cells
---@field size? {width:integer, height:integer} units are cells

---@param image vim.img.Image
---@param opts? vim.img.Backend.RenderOpts
---@diagnostic disable-next-line
function M.render(image, opts) end

return {
}
