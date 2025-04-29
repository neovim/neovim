---@class vim.ui.Image
---@field data string|nil base64 encoded data if loaded into memory
---@field filename string|nil filename of the image if loaded from disk
local M = {}
M.__index = M

---Creates a new image instance.
---If a filename is provided without any data,
---the file will be loaded synchronously into memory.
---@param opts? {data?:string, filename?:string}
---@return vim.ui.Image
function M.new(opts)
  opts = opts or {}

  local instance = {}
  setmetatable(instance, M)

  instance.data = opts.data
  if not instance.data and opts.filename then
    instance:load_from_file(opts.filename)
  end

  return instance
end

M.protocol = (function()
  ---@class vim.ui.img.Protocol 'iterm2'|'kitty'|'sixel'

  ---@type vim.ui.img.Protocol|nil
  local protocol = nil

  local loaded = false

  ---Determines the preferred graphics protocol to use by default.
  ---
  ---@return vim.ui.img.Protocol|nil
  return function()
    if not loaded then
      local detect = require('vim.ui.img._detect')
      local graphics = detect().graphics

      ---@diagnostic disable-next-line:cast-type-mismatch
      ---@cast graphics vim.ui.img.Protocol|nil
      protocol = graphics

      loaded = true
    end

    return protocol
  end
end)()

---Returns true if the image is loaded into memory.
---@return boolean
function M:is_loaded()
  return self.data ~= nil
end

---Returns true if the image is from a known filename.
---@return boolean
function M:is_from_file()
  return self.filename ~= nil
end

---Returns the size of the base64 encoded image.
---@return integer
function M:size()
  return string.len(self.data or '')
end

---Iterates over the chunks of the image, invoking `f` per chunk.
---@param f fun(chunk:string, pos:integer, has_more:boolean)
---@param opts? {size?:integer}
function M:for_each_chunk(f, opts)
  opts = opts or {}

  -- Chunk size, defaulting to 4k
  local chunk_size = opts.size or 4096

  local data = self.data
  if not data then
    return
  end

  local pos = 1
  local len = string.len(data)
  while pos <= len do
    -- Get our next chunk from [pos, pos + chunk_size)
    local end_pos = pos + chunk_size - 1
    local chunk = data:sub(pos, end_pos)

    -- If we have a chunk available, invoke our callback
    if string.len(chunk) > 0 then
      local has_more = end_pos + 1 <= len
      pcall(f, chunk, pos, has_more)
    end

    pos = end_pos + 1
  end
end

---Loads data for an image from a file, replacing any existing data.
---If a callback provided, will load asynchronously; otherwise, is blocking.
---@param filename string
---@param on_load fun(err:string|nil, image:vim.ui.Image|nil)
---@overload fun(filename:string):vim.ui.Image
function M:load_from_file(filename, on_load)
  local name = vim.fn.fnamemodify(filename, ':t:r')

  if not on_load then
    local stat = vim.uv.fs_stat(filename)
    assert(stat, 'unable to stat ' .. filename)

    local fd = vim.uv.fs_open(filename, 'r', 644) --[[ @type integer|nil ]]
    assert(fd, 'unable to open ' .. filename)

    local data = vim.uv.fs_read(fd, stat.size, -1) --[[ @type string|nil ]]
    assert(data, 'unable to read ' .. filename)

    self.data = vim.base64.encode(data)
    self.filename = name
    return self
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
        self.filename = name

        vim.schedule(function()
          on_load(nil, self)
        end)
      end)
    end)
  end)
end

---@class vim.ui.img.Opts: vim.ui.img.Provider.RenderOpts
---@field provider? vim.ui.img.Protocol|vim.ui.img.Provider

---Displays an image. Currently only supports the |TUI|.
---@param opts? vim.ui.img.Opts
function M:show(opts)
  opts = opts or {}

  local provider = opts.provider

  -- If no graphics are explicitly defined, attempt to detect the
  -- preferred graphics. If we still cannot figure out a provider,
  -- throw an error early versus silently trying a protocol.
  if not provider then
    provider = M.protocol()
    assert(provider, 'no graphics provider available')
  end

  -- For named protocols, grab the appropriate provider, failing
  -- if there is not a default provider for the specified protocol.
  if type(provider) == 'string' then
    provider = require('vim.ui.img._provider').load(provider)
  end

  ---@cast provider vim.ui.img.Provider
  provider.render(self, {
    pos = opts.pos,
    size = opts.size,
    crop = opts.crop,
  })
end

---@alias vim.ui.img.Unit 'cell'|'pixel'

---Calculates the width and height of each cell within the currently-attached
---user interface. If no interface is found, will throw an error.
---@return number cell_width, number cell_height
local function cell_size()
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
  local w, h = cell_size()
  return math.floor(x / w), math.floor(y / h)
end

---Convert an integer representing a cell to absolute pixels.
---@param x integer
---@param y integer
---@return integer x, integer y
local function cells_to_pixels(x, y)
  local w, h = cell_size()
  return math.floor(x * w), math.floor(y * h)
end

---Creates a new instance of a position corresponding to an image.
---@param x integer
---@param y integer
---@param unit vim.ui.img.Unit
---@return vim.ui.img.Position
function M.new_position(x, y, unit)
  ---@class vim.ui.img.Position
  ---@field x integer
  ---@field y integer
  ---@field unit vim.ui.img.Unit
  local position = { x = x, y = y, unit = unit }

  ---Convert unit of position to cells, returning a copy of the position.
  ---@return vim.ui.img.Position
  function position:to_cells()
    if self.unit == 'pixel' then
      local x, y = pixels_to_cells(self.x, self.y)
      return M.new_position(x, y, 'cell')
    end

    return self
  end

  ---Convert unit of position to pixels, returning a copy of the position.
  ---@return vim.ui.img.Position
  function position:to_pixels()
    if self.unit == 'cell' then
      local x, y = cells_to_pixels(self.x, self.y)
      return M.new_position(x, y, 'pixel')
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
  ---@class vim.ui.img.Region
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

  return region
end

---Creates a new instance of an size corresponding to an image.
---@param width integer
---@param height integer
---@param unit vim.ui.img.Unit
---@return vim.ui.img.Size
function M.new_size(width, height, unit)
  ---@class vim.ui.img.Size
  ---@field width integer
  ---@field height integer
  ---@field unit vim.ui.img.Unit
  local size = { width = width, height = height, unit = unit }

  ---Convert unit of size to cells, returning a copy of the size.
  ---@return vim.ui.img.Size
  function size:to_cells()
    if self.unit == 'pixel' then
      local width, height = pixels_to_cells(self.width, self.height)
      return M.new_size(width, height, 'cell')
    end

    return self
  end

  ---Convert unit of size to pixels, returning a copy of the size.
  ---@return vim.ui.img.Size
  function size:to_pixels()
    if self.unit == 'cell' then
      local width, height = cells_to_pixels(self.width, self.height)
      return M.new_size(width, height, 'pixel')
    end

    return self
  end

  return size
end

return M
