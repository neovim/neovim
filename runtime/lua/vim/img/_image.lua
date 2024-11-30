---@class vim.img.Image
---@field name string|nil name of the image if loaded from disk
---@field data string|nil base64 encoded data
local M = {}
M.__index = M

---Creates a new image instance.
---@param opts? {data?:string, filename?:string}
---@return vim.img.Image
function M:new(opts)
  opts = opts or {}

  local instance = {}
  setmetatable(instance, M)

  instance.data = opts.data
  if not instance.data and opts.filename then
    instance:load_from_file(opts.filename)
  end

  return instance
end

---Returns true if the image is loaded into memory.
---@return boolean
function M:is_loaded()
  return self.data ~= nil
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

---Displays the image within the terminal used by neovim.
---@param opts? vim.img.Opts
function M:show(opts)
  vim.img.show(self, opts)
end

---Loads data for an image from a file, replacing any existing data.
---If a callback provided, will load asynchronously; otherwise, is blocking.
---@param filename string
---@param cb fun(err:string|nil, image:vim.img.Image|nil)
---@overload fun(filename:string):vim.img.Image
function M:load_from_file(filename, cb)
  local name = vim.fn.fnamemodify(filename, ':t:r')

  if not cb then
    local stat = vim.uv.fs_stat(filename)
    assert(stat, 'unable to stat ' .. filename)

    local fd = vim.uv.fs_open(filename, 'r', 644) --[[ @type integer|nil ]]
    assert(fd, 'unable to open ' .. filename)

    local data = vim.uv.fs_read(fd, stat.size, -1) --[[ @type string|nil ]]
    assert(data, 'unable to read ' .. filename)

    self.name = name
    self.data = vim.base64.encode(data)
    return self
  end

  ---@param err string|nil
  ---@return boolean
  local function report_err(err)
    if err then
      vim.schedule(function()
        cb(err)
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

        self.name = name
        self.data = vim.base64.encode(data or '')

        vim.schedule(function()
          cb(nil, self)
        end)
      end)
    end)
  end)
end

return M
