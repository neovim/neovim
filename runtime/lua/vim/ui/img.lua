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

---Collection of images displayed in neovim.
---@type table<integer, vim.ui.img.Placement>
M.placements = {}

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

  img:reload(vim.schedule_wrap(function(err)
    on_load(err, not err and img or nil)
  end))
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

---Returns a hash (sha256) of the image's bytes.
---@return string
function M:hash()
  return vim.fn.sha256(self.bytes or '')
end

---Returns the size of the image. If it is not loaded, will load the necessary bytes
---to retrieve and parse the header into memory.
---@return vim.ui.img.utils.Size
function M:size()
  local utils = require('vim.ui.img.utils')
  local header = self:__parse_header()
  return utils.new_size(header.width, header.height, 'pixel')
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

---@class (exact) vim.ui.img.ConvertOpts
---@field background? string hex string representing background color
---@field crop? vim.ui.img.utils.Region
---@field format? string such as 'png', 'rgb', or 'sixel' (default 'png')
---@field size? vim.ui.img.utils.Size
---@field timeout? integer maximum time (in milliseconds) to wait for conversion

---Converts an image using ImageMagick, returning the bytes of the new image.
---
---If `background` is specified, will convert alpha pixels to the background color (e.g. #ABCDEF).
---If `crop` is specified, will crop the image to the specified pixel dimensions.
---If `format` is specified, will convert to the image format, defaulting to png.
---If `size` is specified, will resize the image to the desired size.
---@param opts? vim.ui.img.ConvertOpts
---@param on_convert? fun(err:string|nil, data:string|nil)
---@return string|nil data, string|nil err
function M:convert(opts, on_convert)
  ---@param out vim.SystemCompleted
  ---@return string|nil data, string|nil err
  local function process_result(out)
    if out.code ~= 0 then
      return nil, out.stderr and out.stderr or 'failed to convert image'
    end

    local data = out.stdout
    if not data or data == '' then
      return nil, 'converted image output missing'
    end

    return data
  end
  opts = opts or {}

  -- Fail fast if we cannot find the binary
  if vim.fn.executable('magick') == 0 then
    local err = 'ImageMagick binary not found'
    if on_convert then
      vim.schedule(function() on_convert(err) end)
    else
      error(err)
    end
    return
  end

  local cmd = { 'magick', 'convert', self.filename }
  if opts.background then
    table.insert(cmd, '-background')
    table.insert(cmd, opts.background)
    table.insert(cmd, '-flatten')
  end
  if opts.crop then
    local region = opts.crop:to_pixels()
    table.insert(cmd, '-crop')
    table.insert(
      cmd,
      string.format('%sx%s+%s+%s', region.width, region.height, region.x, region.y)
    )
  end
  if opts.size then
    local size_px = opts.size:to_pixels()
    table.insert(cmd, '-resize')
    table.insert(cmd, string.format('%sx%s', size_px.width, size_px.height))
  end

  local format = opts.format or 'png'
  table.insert(cmd, format .. ':-')

  local obj = vim.system(cmd, nil, on_convert and vim.schedule_wrap(function(out)
    local data, err = process_result(out)
    on_convert(err, data)
  end))
  if obj then
    return process_result(obj:wait(opts.timeout))
  end
end

---Displays an image, returning a reference to its visual representation (placement).
---```lua
---local img = ...
---
-----Can be invoked synchronously
---local placement = assert(img:show({ ... }):wait())
---
-----Can also be invoked asynchronously
---img:show({ ... }):on_done(function(err, placement)
---  -- Do something
---end)
---```
---@param opts? vim.ui.img.Opts|{provider?:string}
---@return vim.ui.img.utils.Promise<vim.ui.img.Placement>
function M:show(opts)
  local promise = require('vim.ui.img.utils.promise').new({
    context = 'image.show',
  })

  local placement = self:new_placement(opts)
  placement:show(opts)
      :on_ok(function() promise:ok(placement) end)
      :on_fail(function(err) promise:fail(err) end)

  return promise
end

---Creates a placement of this image that is not yet visible.
---@param opts? {provider?:string}
---@return vim.ui.img.Placement
function M:new_placement(opts)
  return require('vim.ui.img.placement').new(self, opts)
end

return M
