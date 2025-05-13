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

  local Position = require('vim.ui.img.utils.position')
  local Region = require('vim.ui.img.utils.region')
  local Size = require('vim.ui.img.utils.size')

  ---@type vim.ui.img.opts.Relative|nil
  local relative = opts.relative
  vim.validate('opts.relative', relative, 'string', true)

  ---@type vim.ui.img.utils.Region|nil
  local crop = opts.crop
  vim.validate('opts.crop', crop, 'table', true)
  if type(crop) == 'table' then
    crop = Region.new(crop)
  end

  ---@type vim.ui.img.utils.Position|nil
  local pos = opts.pos
  vim.validate('opts.pos', pos, 'table', true)
  if type(pos) == 'table' then
    pos = Position.new(pos)
  end

  ---@type vim.ui.img.utils.Size|nil
  local size = opts.size
  vim.validate('opts.size', size, 'table', true)
  if type(size) == 'table' then
    size = Size.new(size)
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

---Calculates and returns the position dictated by `relative` and `pos`.
---@return vim.ui.img.utils.Position
function M:position()
  local Position = require('vim.ui.img.utils.position')
  local x, y = 0, 0

  if self.pos or self.relative then
    local xoffset, yoffset = 0, 0
    local relative = self.relative

    if self.pos then
      local pos_cells = self.pos:to_cells()
      x, y = pos_cells.x, pos_cells.y
    end

    -- Adjust the x,y position using relative indicator
    if relative == 'editor' then
      xoffset = 0
      yoffset = 0
    elseif relative == 'win' then
      ---@type {[1]:number, [2]:number}
      local pos = vim.api.nvim_win_get_position(self.win or 0)
      xoffset = pos[2] -- pos[2] is column (zero indexed)
      yoffset = pos[1] -- pos[1] is row (zero indexed)
    elseif relative == 'cursor' then
      local win = self.win or 0

      ---@type {[1]:number, [2]:number}
      local pos = vim.api.nvim_win_get_position(self.win or 0)
      local px, py = pos[2], pos[1]

      -- Get the screen line/column position of the cursor
      local cx, cy = 0, 0
      vim.api.nvim_win_call(win, function()
        cy = vim.fn.winline()
        cx = vim.fn.wincol()
      end)

      xoffset = px + cx
      yoffset = py + cy
    elseif relative == 'mouse' then
      -- NOTE: If mousemoveevent is not enabled, this only updates on click
      local pos = vim.fn.getmousepos()
      xoffset = pos.screencol -- screencol is one-indexed
      yoffset = pos.screenrow -- screenrow is one-indexed
    end

    x = x + xoffset
    y = y + yoffset
  end

  return Position.new(x, y, 'cell')
end

return M
