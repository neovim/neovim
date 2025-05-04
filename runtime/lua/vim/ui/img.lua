---Id of the last image created.
---@type integer
local LAST_IMAGE_ID = 0

---@class vim.ui.Image
---@field id integer unique id associated with the image
---@field data string|nil base64 encoded data of the image loaded into memory
---@field filename string path to the image on disk
local M = {}
M.__index = M

---Collection of all images loaded into neovim, each with a unique id.
---@type table<integer, vim.ui.Image>
M.images = {}

---Collection of names to associated providers used to display and manipulate images.
---@type vim.ui.img.Providers
M.providers = require('vim.ui.img.providers')

---Creates a new image instance, optionally taking pre-loaded data.
---@param opts {data?:string, filename:string}
---@return vim.ui.Image
function M.new(opts)
  opts = opts or {}

  local instance = {}
  setmetatable(instance, M)

  instance.id = LAST_IMAGE_ID + 1
  instance.data = opts.data
  instance.filename = opts.filename

  -- Update our running copy of all created images
  -- and bump the counter for image ids
  M.images[instance.id] = instance
  LAST_IMAGE_ID = instance.id

  return instance
end

---Loads data for an image from a local file.
---
---If a callback provided, will load asynchronously; otherwise, is blocking.
---@param filename string
---@param on_load fun(err:string|nil, image:vim.ui.Image|nil)
---@overload fun(filename:string):vim.ui.Image
function M.load(filename, on_load)
  local img = M.new({ filename = filename })

  if not on_load then
    img:reload()
    return img
  end

  img:reload(on_load)
end

---Reloads the data for an image from its filename.
---
---If a callback provided, will load asynchronously; otherwise, is blocking.
---@param on_load fun(err:string|nil)
---@overload fun()
function M:reload(on_load)
  local filename = self.filename

  if not on_load then
    local stat = vim.uv.fs_stat(filename)
    assert(stat, 'unable to stat ' .. filename)

    local fd = vim.uv.fs_open(filename, 'r', 644) --[[ @type integer|nil ]]
    assert(fd, 'unable to open ' .. filename)

    local data = vim.uv.fs_read(fd, stat.size, -1) --[[ @type string|nil ]]
    assert(data, 'unable to read ' .. filename)

    self.data = vim.base64.encode(data)
    self.filename = filename

    return
  end

  ---@param err string|nil
  ---@return boolean
  local function report_err(err)
    if err then
      vim.schedule(function()
        on_load(err)
      end)
    end

    return err ~= nil
  end

  vim.uv.fs_stat(filename, function(stat_err, stat)
    if report_err(stat_err) then
      return
    end
    if not stat then
      report_err('missing stat')
      return
    end

    vim.uv.fs_open(filename, 'r', 644, function(open_err, fd)
      if report_err(open_err) then
        return
      end
      if not fd then
        report_err('missing fd')
        return
      end

      vim.uv.fs_read(fd, stat.size, -1, function(read_err, data)
        if report_err(read_err) then
          return
        end

        vim.uv.fs_close(fd, function() end)

        self.data = vim.base64.encode(data or '')
        self.filename = filename

        vim.schedule(on_load)
      end)
    end)
  end)
end

---Returns the size of the base64 encoded image, or 0 if not loaded.
---@return integer
function M:size()
  return string.len(self.data or '')
end

---Returns a hash (sha256) of the base64 encoded image.
---@return string
function M:hash()
  return vim.fn.sha256(self.data or '')
end

---Returns an iterator over the chunks of the image, returning the chunk, byte position, and
---an indicator of whether the current chunk is the last chunk.
---
---Takes an optional size to indicate how big each chunk should be, defaulting to 4096.
---
---Examples:
---
---```lua
----- Some predefined image
---local img = vim.ui.img.new({ ... })
---
------@param chunk string
------@param pos integer
------@param last boolean
---img:chunks():each(function(chunk, pos, last)
---  vim.print("Chunk data", chunk)
---  vim.print("Chunk starts at", pos)
---  vim.print("Is last chunk", last)
---end)
---```
---
---@param opts? {size?:integer}
---@return Iter
function M:chunks(opts)
  opts = opts or {}

  -- Chunk size, defaulting to 4k
  local chunk_size = opts.size or 4096

  local data = self.data
  if not data or data == '' then
    return vim.iter(function()
      return nil, nil, nil
    end)
  end

  local pos = 1
  local len = string.len(data)

  return vim.iter(function()
    -- If we are past the last chunk, this iterator should terminate
    if pos > len then
      return nil, nil, nil
    end

    -- Get our next chunk from [pos, pos + chunk_size)
    local end_pos = pos + chunk_size - 1
    local chunk = data:sub(pos, end_pos)

    -- If we have a chunk available, mark as such
    local last = true
    if string.len(chunk) > 0 then
      last = not (end_pos + 1 <= len)
    end

    -- Mark where our current chunk is positioned
    local chunk_pos = pos

    -- Update our global position
    pos = end_pos + 1

    return chunk, chunk_pos, last
  end)
end

---@class vim.ui.img.ShowOpts: vim.ui.img.Opts
---@field provider? vim.ui.img.Provider|string

---@class vim.ui.img.Opts
---@field relative? 'editor'|'win'|'cursor'|'mouse'
---@field crop? vim.ui.img.Region portion of image to display
---@field pos? vim.ui.img.Position upper-left position of image within editor
---@field size? vim.ui.img.Size explicit size to scale the image
---@field win? integer window to use when `relative` is `win`

---Displays an image, returning a reference to the displayed instance.
---Currently only supports the |TUI|.
---@param opts? vim.ui.img.ShowOpts
---@return integer #unique id reprensting a reference to the displayed image
function M:show(opts)
  opts = opts or {}

  -- TODO: Re-introduce support for detecting a provider dynamically
  local provider = opts.provider or 'kitty'

  -- If just a name of a provider is specified, grab it from our internal implementations
  if type(provider) == 'string' then
    provider = M.providers.load(provider)
  end

  -- Ensure that our render opts are the actual types
  local crop = opts.crop
  if crop then
    crop = M.new_region(crop.pos1, crop.pos2)
  end

  local pos = opts.pos
  if pos then
    pos = M.new_position(pos.x, pos.y, pos.unit)
  end

  local size = opts.size
  if size then
    size = M.new_size(size.width, size.height, size.unit)
  end

  return provider.show(self, {
    crop = crop,
    pos = pos,
    relative = opts.relative,
    size = size,
  })
end

---Hides a displayed image.
---Currently only supports the |TUI|.
---@param ids integer|integer[] the ids of the displayed images to hide
---@param opts? {provider?:vim.ui.img.Provider|string}
function M:hide(ids, opts)
  opts = opts or {}

  -- TODO: Re-introduce support for detecting a provider dynamically
  local provider = opts.provider or 'kitty'

  -- If just a name of a provider is specified, grab it from our internal implementations
  if type(provider) == 'string' then
    provider = M.providers.load(provider)
  end

  if type(ids) == 'number' then
    ids = { ids }
  end

  return provider.hide(ids)
end

---@alias vim.ui.img.Unit 'cell'|'pixel'

---Calculates the width and height of each cell within the currently-attached
---user interface. If no interface is found, will throw an error.
---@return number cell_width, number cell_height
local function cell_size_in_pixels()
  ---@type {width:integer, height:integer}[]
  local uis = vim.api.nvim_list_uis()
  local ui = assert(uis[1], 'no attached ui found')

  local width_px = ui.width
  local height_px = ui.height
  local columns = vim.o.columns
  local lines = vim.o.lines

  local cell_width = width_px / columns
  local cell_height = height_px / lines

  return cell_width, cell_height
end

---Convert an integer representing absolute pixels to a cell.
---@param x integer
---@param y integer
---@return integer x, integer y
local function pixels_to_cells(x, y)
  local w, h = cell_size_in_pixels()
  return math.floor(x / w), math.floor(y / h)
end

---Convert an integer representing a cell to absolute pixels.
---@param x integer
---@param y integer
---@return integer x, integer y
local function cells_to_pixels(x, y)
  local w, h = cell_size_in_pixels()
  return math.floor(x * w), math.floor(y * h)
end

---Creates a new instance of a position corresponding to an image.
---@param x integer
---@param y integer
---@param unit vim.ui.img.Unit
---@return vim.ui.img.Position
function M.new_position(x, y, unit)
  ---@class (exact) vim.ui.img.Position
  ---@field x integer
  ---@field y integer
  ---@field unit vim.ui.img.Unit
  local position = { x = x, y = y, unit = unit }

  ---Convert unit of position to cells, returning a copy of the position.
  ---@return vim.ui.img.Position
  function position:to_cells()
    if self.unit == 'pixel' then
      local cell_x, cell_y = pixels_to_cells(self.x, self.y)
      return M.new_position(cell_x, cell_y, 'cell')
    end

    return self
  end

  ---Convert unit of position to pixels, returning a copy of the position.
  ---@return vim.ui.img.Position
  function position:to_pixels()
    if self.unit == 'cell' then
      local px_x, px_y = cells_to_pixels(self.x, self.y)
      return M.new_position(px_x, px_y, 'pixel')
    end

    return self
  end

  return position
end

---Creates a new instance of a region corresponding to an image.
---@param pos1 vim.ui.img.Position
---@param pos2 vim.ui.img.Position
---@return vim.ui.img.Region
function M.new_region(pos1, pos2)
  ---@class (exact) vim.ui.img.Region
  ---@field pos1 vim.ui.img.Position
  ---@field pos2 vim.ui.img.Position
  local region = { pos1 = pos1, pos2 = pos2 }

  ---Convert unit of region to cells, returning a copy of the region.
  ---@return vim.ui.img.Region
  function region:to_cells()
    return M.new_region(
      self.pos1:to_cells(),
      self.pos2:to_cells()
    )
  end

  ---Convert unit of region to pixels, returning a copy of the region.
  ---@return vim.ui.img.Region
  function region:to_pixels()
    return M.new_region(
      self.pos1:to_pixels(),
      self.pos2:to_pixels()
    )
  end

  ---Returns the x, y, width, height of the region.
  ---@return integer x, integer y, integer width, integer height
  function region:to_bounds()
    local p1 = self.pos1
    local p2 = self.pos2

    assert(p1.unit == p2.unit, 'units of pos1 and pos2 do not match')

    local x = math.min(p1.x, p2.x)
    local y = math.min(p1.y, p2.y)
    local width = math.abs(p1.x - p2.x)
    local height = math.abs(p1.y - p2.y)

    return x, y, width, height
  end

  return region
end

---Creates a new instance of an size corresponding to an image.
---@param width integer
---@param height integer
---@param unit vim.ui.img.Unit
---@return vim.ui.img.Size
function M.new_size(width, height, unit)
  ---@class (exact) vim.ui.img.Size
  ---@field width integer
  ---@field height integer
  ---@field unit vim.ui.img.Unit
  local size = { width = width, height = height, unit = unit }

  ---Convert unit of size to cells, returning a copy of the size.
  ---@return vim.ui.img.Size
  function size:to_cells()
    if self.unit == 'pixel' then
      local cell_width, cell_height = pixels_to_cells(self.width, self.height)
      return M.new_size(cell_width, cell_height, 'cell')
    end

    return self
  end

  ---Convert unit of size to pixels, returning a copy of the size.
  ---@return vim.ui.img.Size
  function size:to_pixels()
    if self.unit == 'cell' then
      local px_width, px_height = cells_to_pixels(self.width, self.height)
      return M.new_size(px_width, px_height, 'pixel')
    end

    return self
  end

  return size
end

return M
