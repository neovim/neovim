---UI protocol implementation for vim.ui.img.
---
---Emits img_data/img_set/img_del UI events to attached UIs that activated
---the "ext_images" capability, instead of writing terminal escape codes.
---See :help ui-images for the protocol contract.
---@class vim.ui.img._events: vim.ui.img._Backend
local M = {}

---@type vim.ui.img._util
local util = require('vim.ui.img._util')

---Returns true if any attached UI activated the "ext_images" capability.
---@return boolean
function M.available()
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.ext_images then
      return true
    end
  end
  return false
end

---Transmit an image, or (re-)place a transmitted image.
---
---When {data_or_id} is a string, transmits the bytes without displaying and
---returns the new image id. When it is an id, places the image per
---{opts.relative}: absolute editor cells for 'ui', a virtual placement
---rendered from placeholder grid cells otherwise.
---@param data_or_id string|integer image bytes (string) or image id (integer)
---@param opts? vim.ui.img.Opts required when placing an image id
---@return integer id
function M.set(data_or_id, opts)
  -- If given data, we just transmit it without rendering it, and return the id
  if type(data_or_id) == 'string' then
    local id = util.generate_id()
    vim.api.nvim__ui_img_data(id, data_or_id, {})
    return id
  end

  -- Otherwise, when given an id, we assume it has been transmitted already,
  -- and place it either at absolute cells or as a virtual placement
  local id = data_or_id
  assert(opts, 'opts required when placing an image id')

  if opts.relative == nil or opts.relative == 'ui' then
    vim.api.nvim__ui_img_set(id, {
      -- The UI protocol is 0-indexed, unlike this Lua interface
      row = (opts.row or 1) - 1,
      col = (opts.col or 1) - 1,
      width = opts.width,
      height = opts.height,
      zindex = opts.zindex,
    })
  else
    vim.api.nvim__ui_img_set(id, {
      virtual = true,
      width = opts.width,
      height = opts.height,
    })
  end

  return id
end

---Delete image {id}, both its placements and transmitted data.
---@param id integer
function M.del(id)
  vim.api.nvim__ui_img_del(id)
end

---Query whether images can be displayed via UI events, which requires an
---attached UI that activated the "ext_images" capability.
---@param opts? {timeout?: integer, chan?: integer} unused by this backend
---@return boolean supported
---@return string? msg
function M.supported(opts) -- luacheck: no unused args
  return M.available()
end

return M
