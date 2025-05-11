---Id of the last image created.
---@type integer
local LAST_IMAGE_ID = 0

---@class vim.ui.Image
---@field id integer unique id associated with the image
---@field bytes string|nil bytes of the image loaded into memory
---@field filename string path to the image on disk
---@field private __header vim.ui.img.parser.Header|nil image's header information if loaded
local M = {}
M.__index = M

---Collection of all images loaded into neovim, each with a unique id.
---@type table<integer, vim.ui.Image>
M.images = {}

---Collection of names to associated providers used to display and manipulate images.
---@type vim.ui.img.Providers
M.providers = require('vim.ui.img.providers')

---Creates a new image instance, optionally taking pre-loaded bytes.
---@param opts {bytes?:string, filename:string}
---@return vim.ui.Image
function M.new(opts)
  opts = opts or {}

  local instance = {}
  setmetatable(instance, M)

  instance.id = LAST_IMAGE_ID + 1
  instance.bytes = opts.bytes
  instance.filename = opts.filename

  -- Update our running copy of all created images
  -- and bump the counter for image ids
  M.images[instance.id] = instance
  LAST_IMAGE_ID = instance.id

  return instance
end

---Loads bytes for an image from a local file.
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

---Reloads the bytes for an image from its filename.
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

    local bytes = vim.uv.fs_read(fd, stat.size, -1) --[[ @type string|nil ]]
    assert(bytes, 'unable to read ' .. filename)

    self.bytes = bytes
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

      vim.uv.fs_read(fd, stat.size, -1, function(read_err, bytes)
        if report_err(read_err) then
          return
        end

        vim.uv.fs_close(fd, function() end)

        self.bytes = bytes or ''
        self.filename = filename

        vim.schedule(on_load)
      end)
    end)
  end)
end

---Returns the byte length of the image's bytes, or 0 if not loaded.
---@return integer
function M:len()
  return string.len(self.bytes or '')
end

---Returns a hash (sha256) of the image.
---@return string
function M:hash()
  return vim.fn.sha256(self.bytes or '')
end

---Returns the size of the image. If it is not loaded, will load the necessary bytes
---to retrieve and parse the header into memory.
---@return vim.ui.img.Size
function M:size()
  local header = self:__parse_header()
  return M.new_size(header.width, header.height, 'pixel')
end

---@private
---Parses the header into memory, loading it from disk if needed.
---@param opts? {force?:boolean}
---@return vim.ui.img.parser.Header
function M:__parse_header(opts)
  opts = opts or {}

  if self.__header and not opts.force then
    return self.__header
  end

  self.__header = require('vim.ui.img.parser').parse({
    bytes = self.bytes,
    filename = self.filename,
    only_header = true,
  })

  return self.__header
end

---Returns an iterator over the chunks of the image, returning the chunk, byte position, and
---an indicator of whether the current chunk is the last chunk.
---
---If `base64=true`, will encode the bytes using base64 before iterating chunks.
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
---  vim.print("Chunk bytes", chunk)
---  vim.print("Chunk starts at", pos)
---  vim.print("Is last chunk", last)
---end)
---```
---
---@param opts? {base64?:boolean, size?:integer}
---@return Iter
function M:chunks(opts)
  opts = opts or {}

  -- Chunk size, defaulting to 4k
  local chunk_size = opts.size or 4096

  local bytes = self.bytes
  if not bytes or bytes == '' then
    return vim.iter(function()
      return nil, nil, nil
    end)
  end

  if opts.base64 then
    bytes = vim.base64.encode(bytes)
  end

  local pos = 1
  local len = string.len(bytes)

  return vim.iter(function()
    -- If we are past the last chunk, this iterator should terminate
    if pos > len then
      return nil, nil, nil
    end

    -- Get our next chunk from [pos, pos + chunk_size)
    local end_pos = pos + chunk_size - 1
    local chunk = bytes:sub(pos, end_pos)

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

---@class vim.ui.img.Opts
---@field relative? 'editor'|'win'|'cursor'|'mouse'
---@field crop? vim.ui.img.Region portion of image to display
---@field pos? vim.ui.img.Position upper-left position of image within editor
---@field size? vim.ui.img.Size explicit size to scale the image
---@field win? integer window to use when `relative` is `win`
---@field z? integer z-index of the image with lower values being drawn before higher values

---Retrieves the provider to use to manipulate images.
---@param opts? {provider?:vim.ui.img.Provider|string}
---@return vim.ui.img.Provider
local function get_provider(opts)
  -- TODO: Re-introduce support for detecting a provider dynamically
  local provider = (opts and opts.provider) or 'sixel' --or 'kitty'

  -- If just a name of a provider is specified, grab it from our internal implementations
  if type(provider) == 'string' then
    provider = M.providers.load(provider)
  end

  return provider
end

---Ensure image opts have typed fields instead of tables where appropriate.
---@param opts vim.ui.img.Opts
---@return vim.ui.img.Opts
local function clean_img_opts(opts)
  if opts and opts.crop then
    opts.crop = M.new_region(opts.crop.pos1, opts.crop.pos2)
  end

  if opts and opts.pos then
    opts.pos = M.new_position(opts.pos.x, opts.pos.y, opts.pos.unit or 'cell')
  end

  if opts and opts.size then
    opts.size = M.new_size(opts.size.width, opts.size.height, opts.size.unit or 'cell')
  end

  return opts
end

---Displays an image, returning a reference to the displayed instance.
---Currently only supports the |TUI|.
---@param opts? vim.ui.img.Opts|{provider?:vim.ui.img.Provider|string}
---@return integer #unique id reprensting a reference to the displayed image
function M:show(opts)
  opts = clean_img_opts(opts or {})
  local provider = get_provider(opts)
  return provider.show(self, opts)
end

---Hides a displayed image. If no id provided, will hide all displayed images.
---Currently only supports the |TUI|.
---@param ids integer|integer[] the ids of the displayed images to hide
---@param opts? {provider?:vim.ui.img.Provider|string}
function M:hide(ids, opts)
  opts = opts or {}

  local provider = get_provider(opts)

  if type(ids) == 'number' then
    ids = { ids }
  end

  return provider.hide(ids)
end

---Updates the displayed image using the provided options.
---Currently only supports the |TUI|.
---@param id integer id of the displayed image
---@param opts? vim.ui.img.Opts|{provider?:vim.ui.img.Provider|string} changes to apply to the displayed image
---@return integer id new id representing updated, displayed image
function M:update(id, opts)
  opts = clean_img_opts(opts or {})
  local provider = get_provider(opts)
  return provider.update(id, opts)
end

---@alias vim.ui.img.Unit 'cell'|'pixel'

---Convert an integer representing absolute pixels to a cell.
---@param x integer
---@param y integer
---@return integer x, integer y
local function pixels_to_cells(x, y)
  local size = require('vim.ui.img.screen').size()
  return math.floor(x / size.cell_width), math.floor(y / size.cell_height)
end

---Convert an integer representing a cell to absolute pixels.
---@param x integer
---@param y integer
---@return integer x, integer y
local function cells_to_pixels(x, y)
  local size = require('vim.ui.img.screen').size()
  return math.floor(x * size.cell_width), math.floor(y * size.cell_height)
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

  ---Returns a hash based on the position parameters.
  ---@return string
  function position:hash()
    ---@type string[]
    local items = {
      tostring(self.x),
      tostring(self.y),
      tostring(self.unit),
    }
    return vim.fn.sha256(table.concat(items))
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

  ---Returns a hash based on the region parameters.
  ---@return string
  function region:hash()
    ---@type string[]
    local items = {
      self.pos1:hash(),
      self.pos2:hash(),
    }
    return vim.fn.sha256(table.concat(items))
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

  ---Returns a hash based on the size parameters.
  ---@return string
  function size:hash()
    ---@type string[]
    local items = {
      tostring(self.width),
      tostring(self.height),
      tostring(self.unit),
    }
    return vim.fn.sha256(table.concat(items))
  end

  return size
end

return M
