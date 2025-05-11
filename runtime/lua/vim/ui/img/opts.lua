---@alias vim.ui.img.opts.Relative 'editor'|'win'|'cursor'|'mouse'

---@class vim.ui.img.Opts
---@field relative? vim.ui.img.opts.Relative
---@field crop? vim.ui.img.utils.Region portion of image to display
---@field pos? vim.ui.img.utils.Position upper-left position of image within editor
---@field size? vim.ui.img.utils.Size explicit size to scale the image
---@field win? integer window to use when `relative` is `win`
---@field z? integer z-index of the image with lower values being drawn before higher values
local M = {}
M.__index = M

---Creates a new image opts instance, copying from `opts` any fields.
---Performs type checks and transformations into typed objects.
---@param opts? table
---@return vim.ui.img.Opts
function M.new(opts)
  opts = opts or {}

  -- NOTE: We copy the opts to ensure that other fields carry forward
  --       alongside the fields that we type check.
  local instance = vim.deepcopy(opts)
  setmetatable(instance, M)

  local utils = require('vim.ui.img.utils')

  ---@type vim.ui.img.opts.Relative|nil
  local relative = opts.relative
  vim.validate('opts.relative', relative, 'string', true)

  ---@type vim.ui.img.utils.Region|nil
  local crop = opts.crop
  vim.validate('opts.crop', crop, 'table', true)
  if type(crop) == 'table' then
    crop = utils.new_region(crop)
  end

  ---@type vim.ui.img.utils.Position|nil
  local pos = opts.pos
  vim.validate('opts.pos', pos, 'table', true)
  if type(pos) == 'table' then
    pos = utils.new_position(pos)
  end

  ---@type vim.ui.img.utils.Size|nil
  local size = opts.size
  vim.validate('opts.size', size, 'table', true)
  if type(size) == 'table' then
    size = utils.new_size(size)
  end

  ---@type integer|nil
  local win = opts.win
  vim.validate('opts.win', win, 'number', true)

  ---@type integer|nil
  local z = opts.z
  vim.validate('opts.z', z, 'number', true)

  instance.relative = relative
  instance.crop = crop
  instance.pos = pos
  instance.size = size
  instance.win = win
  instance.z = z

  return instance
end

return M
