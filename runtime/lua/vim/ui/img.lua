local M = {}

---@brief
---
---EXPERIMENTAL: This API may change in the future. Its semantics are not yet finalized.
---
---This provides a functional API for displaying images in Nvim.
---Currently supports PNG images via the Kitty graphics protocol.
---
---To override the image backend, replace `vim.ui.img` with your own
---implementation providing set/get/del.
---
---Examples:
---
---```lua
----- Load image bytes from disk and display at row 5, column 10
---local id = vim.ui.img.set(
---  vim.fn.readblob('/path/to/img.png'),
---  { row = 5, col = 10, width = 40, height = 20, zindex = 50 }
---)
---
----- Update the image position
---vim.ui.img.set(id, { row = 8, col = 12 })
---
----- Retrieve the current image opts
---local opts = vim.ui.img.get(id)
---
----- Remove the image
---vim.ui.img.del(id)
---```

---@class vim.ui.img.Opts
---@inlinedoc
---@field row? integer starting row (1-indexed)
---@field col? integer starting column (1-indexed)
---@field width? integer width in cells
---@field height? integer height in cells
---@field zindex? integer stacking order (higher = on top)

--- Maps user-facing ID to internal tracking info.
---@type table<integer, { img_id: integer, opts: vim.ui.img.Opts }>
local state = {}

---Display an image or update an existing one.
---
---When {data_or_id} is a string, displays the image bytes at the position
---given by {opts}. Returns an integer id for later use.
---
---When {data_or_id} is an integer (a previously returned id), updates
---the image with new {opts}.
---
---@param data_or_id string|integer image bytes (string) or existing id (integer)
---@param opts? vim.ui.img.Opts
---@return integer id
function M.set(data_or_id, opts)
  opts = opts or {}
  vim.validate('data_or_id', data_or_id, { 'string', 'number' })
  vim.validate('opts', opts, 'table')

  local kitty = require('vim.ui.img._kitty')

  -- If given a string, this should be the bytes of a new image to display
  if type(data_or_id) == 'string' then
    local img_id, placement_id = kitty.set(data_or_id, opts)
    state[placement_id] = { img_id = img_id, opts = vim.deepcopy(opts) }
    return placement_id
  end

  -- Otherwise, we update an existing image that is actively displayed
  local id = data_or_id
  local entry = state[id]
  assert(entry, 'invalid image id: ' .. tostring(id))

  -- We always want to have a full set of options when passing to kitty
  local merged = vim.tbl_extend('force', entry.opts, opts)
  kitty.update(entry.img_id, id, merged)
  entry.opts = merged
  return id
end

---Get the opts for an image.
---
---@param id integer
---@return vim.ui.img.Opts? opts copy of image opts, or nil if not found
function M.get(id)
  vim.validate('id', id, 'number')

  -- Grab a copy of the most recent opts used for the image
  local entry = state[id]
  if not entry then
    return nil
  end

  return vim.deepcopy(entry.opts)
end

---Delete an image, removing it from display.
---
---@param id integer
---@return boolean found true if the image existed
function M.del(id)
  vim.validate('id', id, 'number')

  -- Skip performing the deletion if we don't have an active image with the id
  local entry = state[id]
  if not entry then
    return false
  end

  local kitty = require('vim.ui.img._kitty')
  kitty.delete(entry.img_id)
  state[id] = nil
  return true
end

---@private
--- Query whether the host terminal supports displaying images.
--- Blocks until the terminal responds or times out.
---
---@param opts? {timeout?: integer} timeout in milliseconds (default: 1000)
---@return boolean supported true if the terminal supports image display
---@return string? msg error detail if the terminal responded but not with OK
function M._supported(opts)
  return require('vim.ui.img._kitty').supported(opts)
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    ---@type integer[]
    local ids = vim.tbl_keys(state)

    for _, id in ipairs(ids) do
      M.del(id)
    end
  end,
})

return M
