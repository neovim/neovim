---Id of the last image created.
---@type integer
local LAST_IMAGE_ID = 0

---@class vim.ui.Image
---@field id integer unique id associated with the image
---@field data string|nil data of the image loaded into memory
---@field file string path to the image on disk
---@field private __format string|nil
---@field private __id integer|nil when loaded, id is populated by provider
---@field private __provider string
---@field private __next {action:(fun():vim.ui.img._Promise<true>), promise:vim.ui.img._Promise<true>}|nil
---@field private __opts vim.ui.img.Opts|nil last opts of image when displayed
---@field private __redrawing boolean if true, image is actively redrawing itself
local M = {}
M.__index = M

---Collection of names to associated providers used to display and manipulate images.
---@type vim.ui.img.Providers
M.providers = require('vim.ui.img.providers')

---Creates a new image instance, optionally taking pre-loaded data.
---@param opts string|{data?:string, file:string}
---@return vim.ui.Image
function M.new(opts)
  vim.validate('opts', opts, { 'string', 'table' })
  if type(opts) == 'table' then
    vim.validate('opts.data', opts.data, 'string', true)
    vim.validate('opts.file', opts.file, 'string')
  end

  local instance = {}
  setmetatable(instance, M)

  instance.id = LAST_IMAGE_ID + 1
  instance.__provider = 'kitty'
  instance.__redrawing = false

  if type(opts) == 'table' then
    instance.data = opts.data
    instance.file = opts.file
  elseif type(opts) == 'string' then
    instance.file = opts
  end

  -- Bump our counter for future image ids
  LAST_IMAGE_ID = instance.id

  return instance
end

---Loads data for an image from a local file.
---@param file string
---@return vim.ui.img._Promise<vim.ui.Image>
function M.load(file)
  local promise = require('vim.ui.img._promise').new({
    context = 'image.load',
  })

  local img = M.new({ file = file })
  img
    :reload()
    :on_ok(function()
      promise:ok(img)
    end)
    :on_fail(function(err)
      promise:fail(err)
    end)

  return promise
end

---Reloads the data for an image from its file.
---@return vim.ui.img._Promise<true>
function M:reload()
  local file = self.file
  local promise = require('vim.ui.img._promise').new({
    context = 'image.reload',
  })

  ---@param err string|nil
  ---@return boolean
  local function report_err(err)
    if err then
      promise:fail(err)
    end

    return err ~= nil
  end

  vim.uv.fs_stat(file, function(stat_err, stat)
    if report_err(stat_err) then
      return
    end
    if not stat then
      report_err('missing stat')
      return
    end

    vim.uv.fs_open(file, 'r', 644, function(open_err, fd)
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

        self.data = data or ''
        self.file = file

        vim.uv.fs_close(fd, function()
          promise:ok(true)
        end)
      end)
    end)
  end)

  return promise
end

---Returns the byte length of the image's data, or 0 if not loaded.
---@return integer
function M:len()
  return string.len(self.data or '')
end

---Returns a hash (sha256) of the image's data.
---@return string
function M:hash()
  return vim.fn.sha256(self.data or '')
end

---Whether or not the image is actively shown.
---@return boolean
function M:is_visible()
  return self.__id ~= nil
end

---Returns true if the image is actively redrawing itself in any situation:
---showing, hiding, or updating.
---@return boolean
function M:is_redrawing()
  return self.__redrawing
end

---Check if the image is PNG format, optionally loading the magic number of the image.
---Will throw an error if unable to load the data of the file.
---Works without ImageMagick.
---@return boolean|nil
function M:is_png()
  if self.__format == 'PNG' then
    return true
  end

  ---Magic number of a PNG file.
  ---@type string
  local PNG_SIGNATURE = '\137PNG\r\n\26\n'

  -- Use loaded data, or synchronously load the file magic number
  local data = self.data
  if not data then
    local fd = vim.uv.fs_open(self.file, 'r', 0)
    if fd then
      data = vim.uv.fs_read(fd, 8, nil)
      vim.uv.fs_close(fd, function() end)
    end
  end

  -- If unable to load data, we return an explicitly nil
  -- value to differentiate from a false value
  if not data then
    return
  end

  local is_png = string.sub(data, 1, #PNG_SIGNATURE) == PNG_SIGNATURE
  if is_png then
    self.__format = 'PNG'
  end
  return is_png
end

---Returns an iterator over the chunks of the image, returning the chunk, byte position, and
---an indicator of whether the current chunk is the last chunk.
---
---If `base64=true`, will encode the data using base64 before iterating chunks.
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
---@param opts? {base64?:boolean, size?:integer}
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

  if opts.base64 then
    data = vim.base64.encode(data)
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

---@private
---Loads the provider used to display and manage the image.
---@param opts? {write?:fun(...:string)}
---@return vim.ui.img.Provider|nil
function M:__load_provider(opts)
  return require('vim.ui.img.providers').load(self.__provider, opts)
end

---Displays the image.
---```lua
----- Some predefined image
---local img = vim.ui.img.new({ ... })
---
-----Can be invoked synchronously
---assert(img:show({ ... }):wait())
---
-----Can also be invoked asynchronously
---img:show({ ... }):on_done(function(err)
---  -- Do something
---end)
---```
---@param opts? vim.ui.img.Opts
---@return vim.ui.img._Promise<true>
function M:show(opts)
  -- Update the opts to reflect what we should be showing next
  -- such that future updates can work properly in batch
  self.__opts = require('vim.ui.img.opts').new(opts)

  return self:__schedule(self.__show, self, self.__opts:into_internal_opts())
end

---@private
---@param opts vim.ui.img.InternalOpts
---@return vim.ui.img._Promise<true>
function M:__show(opts)
  local promise = require('vim.ui.img._promise').new({
    context = 'image.show',
  })

  local provider = self:__load_provider()
  if not provider then
    promise:fail('unable to retrieve provider')
  else
    provider
      .show(self, opts)
      :on_ok(function(id)
        self.__id = id
        promise:ok(true)
      end)
      :on_fail(function(show_err)
        promise:fail(show_err)
      end)
  end

  return promise
end

---Hides the image.
---```lua
----- Some predefined image
---local img = vim.ui.img.new({ ... })
---
-----Can be invoked synchronously
---assert(img:hide():wait())
---
-----Can also be invoked asynchronously
---img:hide():on_done(function(err)
---  -- Do something
---end)
---```
---@return vim.ui.img._Promise<true>
function M:hide()
  -- Update the opts to reflect that we are showing nothing next
  -- such that future updates can work properly in batch
  self.__opts = nil

  return self:__schedule(self.__hide, self)
end

---@private
---@return vim.ui.img._Promise<true>
function M:__hide()
  local promise = require('vim.ui.img._promise').new({
    context = 'image.hide',
  })

  local provider = self:__load_provider()
  if not provider then
    promise:fail('unable to retrieve provider')
  else
    provider
      .hide(self.__id)
      :on_ok(function()
        self.__id = nil
        promise:ok(true)
      end)
      :on_fail(function(hide_err)
        promise:fail(hide_err)
      end)
  end

  return promise
end

---Updates the image by altering any of the specified `opts`.
---```lua
----- Some predefined image
---local img = vim.ui.img.new({ ... })
---
-----Can be invoked synchronously
---assert(img:update({ ... }):wait())
---
-----Can also be invoked asynchronously
---img:update({ ... }):on_done(function(err)
---  -- Do something
---end)
---```
---@param opts? vim.ui.img.Opts
---@return vim.ui.img._Promise<true>
function M:update(opts)
  -- Merge existing opts we used to render the image last time
  -- with any changes we want to apply now
  local tbl = vim.tbl_extend('keep', opts or {}, self.__opts or {})

  -- Update the opts to reflect what we should be showing next
  -- such that future updates can work properly in batch
  self.__opts = require('vim.ui.img.opts').new(tbl)

  return self:__schedule(self.__update, self, self.__opts:into_internal_opts())
end

---@private
---@param opts vim.ui.img.InternalOpts
---@return vim.ui.img._Promise<true>
function M:__update(opts)
  local promise = require('vim.ui.img._promise').new({
    context = 'image.update',
  })

  if not self.__id then
    return promise:fail('image is not visible')
  end

  local provider = self:__load_provider()
  if not provider then
    promise:fail('unable to retrieve provider')
  else
    provider
      .update(self.__id, opts)
      :on_ok(function(id)
        self.__id = id
        promise:ok(true)
      end)
      :on_fail(function(update_err)
        promise:fail(update_err)
      end)
  end

  return promise
end

---@param f fun(...:any):vim.ui.img._Promise<true>
---@param ... any
---@return vim.ui.img._Promise<true>
function M:__schedule(f, ...)
  -- If we are redrawing already, we need to queue this up,
  -- which involves storing the function to be invoked with its args
  -- and adding a new promise to the queue
  if self.__redrawing then
    local promise = require('vim.ui.img._promise').new({
      context = 'image.schedule',
    })

    -- If we already have something queued, we want to skip the action
    -- but still process the promise at the same time as this new item.
    --
    -- The logic is that if we did something like update(), and then
    -- before the operation took place we did hide(), the second
    -- operation would obviously overwrite the first, and we can just
    -- report that both succeeded once the second has finished.
    local next = self.__next
    if next then
      promise
        :on_ok(function(value)
          next.promise:ok(value)
        end)
        :on_fail(function(err)
          next.promise:fail(err)
        end)
    end

    -- Queue up our new scheduled action, considered the most recent
    -- to be run while waiting for redrawing to finish from the
    -- last action. All other queued up actions should be chained
    -- together at this point such that they are triggered when
    -- this queued promise completes.
    local args = { ... }
    self.__next = {
      action = function()
        return f(unpack(args))
      end,
      promise = promise,
    }

    return promise
  end

  -- Otherwise, start the operation immediately
  self.__redrawing = true
  return f(...):on_done(function()
    self.__redrawing = false

    -- If we have something queued, schedule it now
    local next = self.__next
    self.__next = nil
    if next then
      self
        :__schedule(next.action)
        :on_ok(function(value)
          next.promise:ok(value)
        end)
        :on_fail(function(err)
          next.promise:fail(err)
        end)
    end
  end)
end

return M
