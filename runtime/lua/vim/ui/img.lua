local M = {}

---@brief
---
---EXPERIMENTAL: This API may change in the future. Its semantics are not yet finalized.
---
---This provides a functional API for loading and displaying images in Nvim.
---Currently supports PNG images via the Kitty graphics protocol.
---
---The image provider can be changed by setting `vim.ui.img.provider` to a
---builtin name (e.g. `kitty`) or a module path string implementing
---|vim.ui.img.Provider|.
---
---Examples:
---
---```lua
----- Load an image from disk
---local image_id = vim.ui.img.load("/path/to/img.png")
---
----- Place the image at row 5, column 10
---local placement_id = vim.ui.img.place(image_id, { row = 5, col = 10 })
---
----- Update the placement position
---vim.ui.img.place(placement_id, { row = 8, col = 12 })
---
----- Remove the placement
---vim.ui.img.hide(placement_id)
---
----- Remove the entire image (and all its placements)
---vim.ui.img.hide(image_id)
---```

--- An image provider implements the terminal-specific protocol for loading,
--- placing, and hiding images.
---
--- Nvim includes a built-in provider for the Kitty graphics protocol.
--- To use a custom provider, set `vim.ui.img.provider` to a module path:
---
--- ```lua
--- vim.ui.img.provider = 'my.custom.provider'
--- ```
---@class vim.ui.img.Provider
---@field load fun(opts: vim.ui.img.ImgOpts): integer
---@field place fun(id: integer, opts?: vim.ui.img.PlacementOpts): integer
---@field hide fun(id: integer, placement_id?: integer)

---The name of the image provider. Builtin: `kitty`. Can also be set to
---a module path (e.g. `my.custom.provider`) that returns a table
---implementing |vim.ui.img.Provider|.
---@type 'kitty'|string
M.provider = 'kitty'

---@return vim.ui.img.Provider
local function get_provider()
  local builtin = {
    kitty = 'vim.ui.img._kitty',
  }

  local mod_path = builtin[M.provider] or M.provider
  return require(mod_path)
end

---@nodoc
---@class vim.ui.img.State
---@field images table<integer, vim.ui.img.ImgOpts>
---@field placements table<integer, {img_id:integer}|vim.ui.img.PlacementOpts>
local state = {
  images = {},
  placements = {},
}

---Retrieves a copy of the image or placement opts based on the id.
---@param id integer
---@return vim.ui.img.ImgOpts|vim.ui.img.PlacementOpts|nil opts, 'image'|'placement' kind
function M.get(id)
  if type(state.images[id]) == 'table' then
    return vim.deepcopy(state.images[id]), 'image'
  end

  if type(state.placements[id]) == 'table' then
    return vim.deepcopy(state.placements[id]), 'placement'
  end

  return nil, 'image'
end

---Returns an iterator over the loaded images, mapped by id.
---@return Iter
function M.images()
  return vim.iter(pairs(state.images))
end

---Returns an iterator over the active placements, mapped by id.
---@return Iter
function M.placements()
  return vim.iter(pairs(state.placements))
end

---Optional image arguments:
---@class vim.ui.img.ImgOpts
---@field data? string data of a loaded file
---@field filename? string path to the file (e.g. path/to/img.png)

---Load an image from filename or data.
---@param opts string|vim.ui.img.ImgOpts
---@return integer id
function M.load(opts)
  vim.validate('opts', opts, { 'string', 'table' })

  -- If passed a string, we assume it is the filename
  if type(opts) == 'string' then
    opts = { filename = opts }
  end

  local provider = get_provider()
  local id = provider.load(opts)
  state.images[id] = opts

  return id
end

---Optional placment arguments:
---@class vim.ui.img.PlacementOpts
---@field row? integer starting row where image will appear
---@field col? integer starting column where image will appear
---@field width? integer width (in cells) to resize the image
---@field height? integer height (in cells) to resize the image
---@field z? integer z-index of the placement relative to other placements with a higher number being placed over lower-indexed placements

---Places a loaded image within Nvim, visually displaying it.
---@param id integer id of image to place, or id of placement to overwrite
---@param opts? vim.ui.img.PlacementOpts
---@return integer placement_id id of the created/updated placement
function M.place(id, opts)
  opts = opts or {}

  vim.validate('id', id, 'number')
  vim.validate('opts', opts, 'table')

  -- Ensure that the id belongs to an image or placement
  local _opts, kind = M.get(id)
  assert(_opts, 'invalid id: ' .. tostring(id))

  local provider = get_provider()
  local placement_id = provider.place(id, opts)
  local img_id = id

  -- If id supplied was for an existing placement, we need
  -- to instead look up the associated image's id
  if kind == 'placement' then
    ---Casting opts to placement with internally-only img_id mapping
    ---@cast _opts {img_id:integer}
    img_id = _opts.img_id
  end

  -- Update the cached placement information
  state.placements[placement_id] = vim.tbl_extend('keep', { img_id = img_id }, opts)
  return placement_id
end

---Hide an image (or placement) within Nvim.
---@param id integer id of image or placement
---@return boolean true if an image or placement was hidden
function M.hide(id)
  vim.validate('id', id, 'number')

  -- If this is an image's id
  if state.images[id] then
    state.images[id] = nil

    for placement_id, placement in pairs(state.placements) do
      if placement.img_id == id then
        state.placements[placement_id] = nil
      end
    end

    local provider = get_provider()
    provider.hide(id)

    return true

  -- If this is a placement's id
  elseif state.placements[id] then
    local placement = state.placements[id]
    state.placements[id] = nil

    local provider = get_provider()
    provider.hide(placement.img_id, id)

    return true

  -- Otherwise, nothing to do here
  else
    return false
  end
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    -- Delete all images and associated placements on exit
    -- to ensure that they are unloaded from the terminal
    for id, _ in pairs(state.images) do
      M.hide(id)
    end
  end,
})

return M
