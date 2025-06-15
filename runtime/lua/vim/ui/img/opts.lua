---@class vim.ui.img.Opts
---@field relative? 'editor'|'win'|'cursor'|'mouse'
---@field row? integer topmost row position (in character cells) of image location
---@field col? integer leftmost column position (in character cells) of image location
---@field width? integer width (in character cells) to resize the image
---@field height? integer height (in character cells) to resize the image
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

  ---@type string|nil
  local relative = opts.relative
  vim.validate('opts.relative', relative, 'string', true)

  ---@type integer|nil
  local row = opts.row
  vim.validate('opts.row', row, 'number', true)

  ---@type integer|nil
  local col = opts.col
  vim.validate('opts.col', col, 'number', true)

  ---@type integer|nil
  local width = opts.width
  vim.validate('opts.width', width, 'number', true)

  ---@type integer|nil
  local height = opts.height
  vim.validate('opts.height', height, 'number', true)

  ---@type integer|nil
  local win = opts.win
  vim.validate('opts.win', win, 'number', true)

  ---@type integer|nil
  local z = opts.z
  vim.validate('opts.z', z, 'number', true)

  instance.relative = relative
  instance.row = row
  instance.col = col
  instance.width = width
  instance.height = height
  instance.win = win
  instance.z = z

  return instance
end

---@class vim.ui.img.InternalOpts
---@field row integer topmost row position (in character cells) of image location
---@field col integer leftmost column position (in character cells) of image location
---@field width? integer width (in character cells) to resize the image
---@field height? integer height (in character cells) to resize the image
---@field z? integer z-index of the image with lower values being drawn before higher values

---Normalizes the options by determining the editor row and column position.
---@return vim.ui.img.InternalOpts
function M:into_internal_opts()
  local pos = self:__position()

  return {
    row = pos.row,
    col = pos.col,
    width = self.width,
    height = self.height,
    z = self.z,
  }
end

---@private
---Calculates and returns the position dictated by `relative`, `row`, and `col`.
---@return {row:integer, col:integer}
function M:__position()
  local row, col = 0, 0

  if self.row or self.col or self.relative then
    local row_offset, col_offset = 0, 0
    local relative = self.relative

    if self.row then
      row = self.row
    end

    if self.col then
      col = self.col
    end

    -- Adjust the position using relative indicator
    if relative == 'editor' then
      row_offset = 0
      col_offset = 0
    elseif relative == 'win' then
      ---@type {[1]:number, [2]:number}
      local pos = vim.api.nvim_win_get_position(self.win or 0)
      row_offset = pos[1] -- pos[1] is row (zero indexed)
      col_offset = pos[2] -- pos[2] is column (zero indexed)
    elseif relative == 'cursor' then
      local win = self.win or 0

      ---@type {[1]:number, [2]:number}
      local pos = vim.api.nvim_win_get_position(self.win or 0)
      local pos_row, pos_col = pos[1], pos[2]

      -- Get the screen line/column position of the cursor
      local cursor_row, cursor_col = 0, 0
      vim.api.nvim_win_call(win, function()
        cursor_row = vim.fn.winline()
        cursor_col = vim.fn.wincol()
      end)

      row_offset = pos_row + cursor_row
      col_offset = pos_col + cursor_col
    elseif relative == 'mouse' then
      -- NOTE: If mousemoveevent is not enabled, this only updates on click
      local pos = vim.fn.getmousepos()
      row_offset = pos.screenrow -- screenrow is one-indexed
      col_offset = pos.screencol -- screencol is one-indexed
    end

    row = row + row_offset
    col = col + col_offset
  end

  return { row = row, col = col }
end

return M
