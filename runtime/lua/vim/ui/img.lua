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
---
----- Remove all images
---vim.ui.img.del(math.huge)
---```

---@class vim.ui.img.Opts
---@inlinedoc
---@field row? integer starting row (1-indexed); buffer row if {buf} set
---@field col? integer starting column (1-indexed); buffer col if {buf} set
---@field width? integer width in cells
---@field height? integer height in cells
---@field zindex? integer stacking order (higher = on top)
---@field buf? integer buffer to anchor image inline (0 = current buffer)
---@field pad? integer blank cells before image in inline mode
---@field relative? vim.ui.img.Relative

---@alias vim.ui.img.Relative
---| 'ui' # terminal-native absolute positioning
---| 'editor' # editor-relative floating window
---| 'buffer' # inline extmark within a buffer

---@nodoc
---@class vim.ui.img._Backend
---@field set fun(data_or_id:string|integer, opts?:vim.ui.img.Opts):integer
---@field del fun(id:integer)
---@field supported fun(opts?:{timeout?:integer, chan?:integer}):boolean,string?

---@nodoc
---@class vim.ui.img._Entry
---@field handle integer backend image id
---@field placement vim.ui.img._Placement

---Maps user-facing ID to internal tracking info.
---@type table<integer, vim.ui.img._Entry>
local state = {}

---Retrieve the active backend, which is currently always kitty.
---@return vim.ui.img._Backend
local function backend()
  return require('vim.ui.img._kitty')
end

---Retrieve a function used to render the placeholder grid for image tied to {handle}.
---@param handle integer
---@return fun(width: integer, height: integer): string[], string
local function render_for(handle)
  return function(width, height)
    local diacritic = require('vim.ui.img._diacritic')
    local hl = diacritic.hl_name(handle)
    vim.api.nvim_set_hl(0, hl, { fg = handle })
    return diacritic.grid(width, height), hl
  end
end

---Update the displayed image within {entry}.
---@param entry vim.ui.img._Entry
local function apply(entry)
  local handle, placement = entry.handle, entry.placement
  placement:set(render_for(handle))
  backend().set(handle, placement:opts())
end

---@param handle integer
local function clear_hl(handle)
  local diacritic = require('vim.ui.img._diacritic')
  local hl = diacritic.hl_name(handle)
  if vim.fn.hlexists(hl) == 1 then
    vim.api.nvim_set_hl(0, hl, {})
  end
end

---Fully delete image {id} across our placement and backend.
---@param id integer
---@return boolean found
local function delete(id)
  local entry = state[id]
  state[id] = nil

  -- No matching entry, so exit now
  if not entry then
    return false
  end

  clear_hl(entry.handle)
  backend().del(entry.handle)
  entry.placement:del()
  return true
end

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

  local Placement = require('vim.ui.img._placement')

  -- If given a string, this should be the bytes of a new image to display,
  -- and we process it and transfer it to our backend immediately
  if type(data_or_id) == 'string' then
    -- Make a copy of the opts so we don't mutate the caller's copy later on
    opts = vim.deepcopy(opts)

    -- When relative to editor/buffer, we need explicit cell dimensions for the cell grid
    -- whereas the ui positioning delegates sizing to the terminal so it's optional
    local relative = Placement.relative_of(opts)
    if relative ~= 'ui' and (not opts.width or not opts.height) then
      local size = require('vim.ui.img._util').png_to_cell_size(data_or_id)
      if size then
        opts.width = opts.width or size.width
        opts.height = opts.height or size.height
      end
    end

    -- Construct our entry, which involves creating the placement and transferring
    -- our image data to the backend immediately
    local entry = {
      placement = Placement.new(opts),
      handle = backend().set(data_or_id),
    }

    -- The backend id doubles as the user-facing image id
    local id = entry.handle
    state[id] = entry

    -- Set the image for the first time within our editor
    local ok, err = pcall(apply, entry)
    if not ok then
      -- Something has gone wrong, so we should clear our image now to avoid a leak
      delete(id)
      error(err, 0)
    end

    return id
  end

  -- Otherwise, we update an existing image that is actively displayed
  local id = data_or_id
  local entry = state[id]
  assert(entry, 'invalid image id: ' .. tostring(id))
  local placement = entry.placement

  local next_placement, reused = placement:with(opts)
  local ok, err = pcall(apply, { handle = entry.handle, placement = next_placement })
  if not ok then
    -- A reused placement shares its artifacts with the old one, which stays on display
    if not reused then
      next_placement:del()
    end
    error(err, 0)
  end

  entry.placement = next_placement
  if not reused then
    placement:del()
  end

  return id
end

---Get the opts for an image.
---
---@param id integer
---@return vim.ui.img.Opts? opts copy of image opts, or nil if not found
function M.get(id)
  vim.validate('id', id, 'number')

  local entry = state[id]
  if not entry then
    return nil
  end

  local placement = entry.placement
  return placement:opts()
end

---Delete an image, or all images if `math.huge` is given as the id.
---
---@param id integer image id, or `math.huge` to delete all images
---@return boolean found true if any image existed
function M.del(id)
  vim.validate('id', id, 'number')

  if id == math.huge then
    local found = next(state) ~= nil

    -- Delete each image individually so we only touch our own images and
    -- not those of other instances sharing the same terminal
    ---@type integer[]
    local img_ids = vim.tbl_keys(state)
    for _, img_id in ipairs(img_ids) do
      delete(img_id)
    end

    return found
  end

  return delete(id)
end

---@private
---Query whether the host terminal supports displaying images.
---Blocks until the terminal responds or times out.
---
---@param opts? {timeout?: integer, chan?: integer} timeout in milliseconds (default: 1000)
---@return boolean supported true if the terminal supports image display
---@return string? msg error detail if the terminal responded but not with OK
function M._supported(opts)
  return backend().supported(opts)
end

local augroup = vim.api.nvim_create_augroup('vim.ui.img', {})

vim.api.nvim_create_autocmd('WinClosed', {
  group = augroup,
  callback = function(args)
    local winid = tonumber(args.match)
    if not winid then
      return
    end

    -- With the window closed, we check if a placement owned that window,
    -- which would indicate it was a floating window, and delete that placement
    for id, entry in pairs(state) do
      local placement = entry.placement
      if placement:owns_win(winid) then
        delete(id)
        return
      end
    end
  end,
})

vim.api.nvim_create_autocmd('BufWipeout', {
  group = augroup,
  callback = function(args)
    -- When the buffer is going to be completely deleted, we check if a placement
    -- owned that buffer, and delete that placement
    for id, entry in pairs(state) do
      local placement = entry.placement
      if placement:owns_buf(args.buf) then
        delete(id)
      end
    end
  end,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = augroup,
  callback = function()
    -- Delete all images when Nvim exits to ensure that we don't have artifacts remaining
    M.del(math.huge)
  end,
})

return M
