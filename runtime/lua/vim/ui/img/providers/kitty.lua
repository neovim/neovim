---Kitty supports 4096 bytes per chunk when sending remote client data.
---
local MAX_DATA_CHUNK = 4096

---@class vim.ui.img.providers.Kitty
---@field private __debug_write? fun(...:string)
---@field private __has_loaded boolean loaded at least once
---@field private __images table<integer, integer> neovim image id -> kitty image id
---@field private __is_tmux boolean
---@field private __placements table<integer, integer> kitty placement id -> kitty image id
---@field private __writer vim.ui.img.utils.BatchWriter
local M = {
  __has_loaded = false,
  __images = {},
  __is_tmux = false,
  __placements = {},
  __writer = nil, -- To be filled in during load()
}

---@param ... any
function M:load(...)
  if self.__has_loaded then
    return
  end

  -- Check if we are inside tmux, and if so we need to configure it to support
  -- allowing passthrough of escape codes for kitty's graphics protocol and
  -- flag that we need to transform escape codes sent to be compliant with tmux
  if vim.env['TMUX'] ~= nil then
    local res = vim.system({ 'tmux', 'set', '-p', 'allow-passthrough', 'all' }):wait()
    assert(res.code == 0, 'failed to "set -p allow-passthrough all" for tmux')
    self.__is_tmux = true
  end

  -- If debug write function provided, we set it to use globally
  ---@type function|nil
  local debug_write
  for _, arg in ipairs({ ... }) do
    if type(arg) == 'table' then
      ---@type function
      local f = arg.debug_write

      if type(f) == 'function' then
        debug_write = f
      end
    end
  end

  local utils = require('vim.ui.img.utils')
  self.__writer = utils.new_batch_writer({
    use_chan_send = true,
    write = debug_write
  })

  self.__has_loaded = true
end

function M:unload()
  self:__delete_all()
  self.__images = {}
  self.__is_tmux = false
  self.__placements = {}
  self.__writer = nil
end

---@param img vim.ui.Image
---@param opts? vim.ui.img.Opts|{remote?:boolean}
---@return integer
function M:show(img, opts)
  local is_remote = opts and opts.remote
  opts = require('vim.ui.img.opts').new(opts)

  -- Check if we need to transmit our image or if it is already available
  -- TODO: This should really query to see if the image is still loaded
  --       otherwise re-transmit the image. This is especially apparent
  --       when switching between providers as something happens to clear
  --       the images (I think) and they don't show up anymore
  local image_id = self.__images[img.id]
  if not image_id then
    -- If remote, we have to use a direct transmit instead of file
    if is_remote then
      image_id = self:__transmit_image_direct(img)
    else
      image_id = self:__transmit_image_file(img)
    end
    self.__images[img.id] = image_id
  end

  local placement_id = self:__display_image(image_id, opts)
  self.__placements[placement_id] = image_id

  return placement_id
end

---@param ids integer[]
function M:hide(ids)
  for _, pid in ipairs(ids) do
    local id = self.__placements[pid]
    if id then
      self:__delete_image_or_placement(id, pid)
      self.__placements[pid] = nil
    end
  end

  -- TODO: When do we delete the image from kitty entirely?
  --
  -- 1. When there are no placements?
  -- 2. When neovim exits?
end

---@param pid integer
---@param opts? vim.ui.img.Opts
---@return integer
function M:update(pid, opts)
  local id = assert(
    self.__placements[pid],
    string.format('kitty(update): invalid id %s', pid)
  )

  opts = require('vim.ui.img.opts').new(opts)

  ---@diagnostic disable-next-line:inject-field
  opts.pid = pid

  return self:__display_image(id, opts)
end

---@private
---@param content string
function M:__write(content)
  self.__writer.write_fast(content)
end

---@private
---Kitty operates via graphics codes in the form:
---
---    <ESC>_G<control data>;<payload><ESC>\
---
---This function converts the provided information into
---a graphics code sequence to be sent to the terminal.
---
---@param control table<string, string|number>
---@param payload? string
---@return string
function M:__make_seq(control, payload)
  ---Tokenized graphics code data
  ---@type string[]
  local data = {}

  -- Begin the graphics code sequence
  table.insert(data, '\027_G')

  -- Build up our control data if we have any
  if control then
    local tmp = {}
    for k, v in pairs(control) do
      table.insert(tmp, k .. '=' .. v)
    end

    -- Convert our series of k=v into k1=v1,k2=v2,...
    if #tmp > 0 then
      table.insert(data, table.concat(tmp, ','))
    end
  end

  if payload and string.len(payload) > 0 then
    table.insert(data, ';')
    table.insert(data, payload)
  end

  -- Finalize the graphics code sequence
  table.insert(data, '\027\\')

  -- Build our graphics control sequence, transforming it based on the
  -- environment in which neovim is running
  local seq = table.concat(data)

  -- Tmux requires special handling to work properly with tmux
  if self.__is_tmux then
    seq = ('\027Ptmux;' .. string.gsub(seq, '\027', '\027\027')) .. '\027\\'
  end

  return seq
end

---@private
---Transmit an image directly via a filesystem path.
---@param image vim.ui.Image
---@return integer id unique id assigned to the image
function M:__transmit_image_file(image)
  local id = self:__next_id()

  local control = {}
  control['f'] = '100' -- Assume we are working with PNG
  control['a'] = 't'   -- Transmit image data without displaying
  control['t'] = 'f'   -- Signify that this is a file transmit
  control['i'] = id    -- Specify the id of the image
  control['q'] = 2     -- Suppress all responses

  -- Payload for a file transmit is the base64-encoded file path
  local payload = vim.base64.encode(image.filename)

  self:__write(self:__make_seq(control, payload))

  return id
end

---@private
---Transmit an image directly via escape codes.
---
---This is the approach to take with remote clients (i.e. ssh) when the
---filesystem and shared memory are not accessible.
---@param image vim.ui.Image
---@return integer id unique id assigned to the image
function M:__transmit_image_direct(image)
  local id = self:__next_id()

  -- If the image is not loaded yet, do so before directly transmitting it
  if image:size() == 0 then
    image:reload()
  end

  ---@param chunk string data of chunk
  ---@param pos integer starting byte position of chunk
  ---@param last boolean true if final chunk
  image:chunks({ base64 = true, size = MAX_DATA_CHUNK }):each(function(chunk, pos, last)
    local control = {}

    -- If at the beginning of our image, supply common control info
    if pos == 1 then
      control['f'] = '100' -- Assume we are working with PNG
      control['a'] = 't'   -- Transmit image data without displaying
      control['t'] = 'd'   -- Signify that this is a direct transmit
      control['i'] = id    -- Specify the id of the image
      control['q'] = 2     -- Suppress all responses
    end

    -- Mark whether we have more data to send
    control['m'] = last and 0 or 1

    -- NOTE: This may need direct tty device access to function!
    self:__write(self:__make_seq(control, chunk))
  end)

  return id
end

---@private
---Display a transmitted image into the kitty terminal.
---@param id integer
---@param opts vim.ui.img.Opts|{pid?:integer}
---@return integer placement_id
function M:__display_image(id, opts)
  local utils = require('vim.ui.img.utils')

  -- Create a unique placement id for this new display
  local pid = opts.pid or self:__next_id()

  -- Capture old cursor position
  utils.save_cursor(self.__writer.write_fast)

  -- Hide the cursor and move it to position where image should be displayed
  local pos = opts:position():to_cells()
  utils.show_cursor(false, self.__writer.write_fast)
  utils.move_cursor(pos.x, pos.y, self.__writer.write_fast)

  -- TODO: Do we use U=1 for inline placements via virtual unicode?
  local control = {}
  control['a'] = 'p' -- Display (put) a transmitted image
  control['i'] = id  -- Specify the id of the image to display
  control['p'] = pid -- Specify the id of the distinct placement
  control['C'] = 1   -- Don't move the cursor after the image
  control['q'] = 2   -- Suppress all responses

  if opts.crop then
    local crop = opts.crop:to_pixels()
    control['x'] = crop.x
    control['y'] = crop.y
    control['w'] = crop.width
    control['h'] = crop.height
  end

  if opts.size then
    local size = opts.size:to_cells()
    control['c'] = size.width
    control['r'] = size.height
  end

  control['z'] = opts.z

  self:__write(self:__make_seq(control))

  -- Restore old cursor position and make it visible again
  utils.restore_cursor(self.__writer.write_fast)
  utils.show_cursor(true, self.__writer.write_fast)

  return pid
end

---@private
---Delete a displayed image that is visible within kitty terminal.
---@param image_id integer
---@param placement_id? integer
function M:__delete_image_or_placement(image_id, placement_id)
  local control = {}
  control['a'] = 'd'          -- Perform a deletion
  control['d'] = 'i'          -- Delete either a transmitted image or placement
  control['i'] = image_id     -- Specify the id of the image to delete
  control['p'] = placement_id -- Specify the id of the image placement to delete
  control['q'] = 2            -- Suppress all responses

  self:__write(self:__make_seq(control))
end

---@private
---Delete all placements and associated images within kitty terminal.
function M:__delete_all()
  local control = {}
  control['a'] = 'd' -- Perform a deletion
  control['d'] = 'A' -- Delete all visible placements and images
  control['q'] = 2   -- Suppress all responses

  self:__write(self:__make_seq(control))
end

---@private
M.__next_id = (function()
  local bit = require('bit')

  local NVIM_PID_BITS = 10

  local nvim_pid = 0
  local cnt = 30

  ---Generates the next id that should be unique to this neovim instance.
  ---
  ---Note that for kitty, this needs to be between 0 and 4294967295.
  ---
  ---From folke/snacks.nvim plugin implementation (Apache 2.0 license).
  ---@return integer
  return function()
    -- Generate a unique id for this nvim instance (10 bits)
    if nvim_pid == 0 then
      local pid = vim.fn.getpid()
      nvim_pid = bit.band(bit.bxor(pid, bit.rshift(pid, 5), bit.rshift(pid, NVIM_PID_BITS)), 0x3FF)
    end

    cnt = cnt + 1
    return bit.bor(bit.lshift(nvim_pid, 24 - NVIM_PID_BITS), cnt)
  end
end)()

return require('vim.ui.img.providers').new({
  on_load = function(_, ...)
    return M:load(...)
  end,
  on_show = function(_, img, opts)
    return M:show(img, opts)
  end,
  on_hide = function(_, ids)
    return M:hide(ids)
  end,
  on_unload = function()
    return M:unload()
  end,
  on_update = function(_, id, opts)
    return M:update(id, opts)
  end,
})
