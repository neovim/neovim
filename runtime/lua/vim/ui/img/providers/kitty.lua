---Kitty supports 4096 bytes per chunk when sending remote client data.
---
local MAX_DATA_CHUNK = 4096

---@class vim.ui.img._providers.Kitty
---@field private __autocmds integer[]
---@field private __has_loaded boolean loaded at least once
---@field private __images table<integer, integer> neovim image id -> kitty image id
---@field private __is_tmux boolean
---@field private __placements table<integer, integer> kitty placement id -> kitty image id
---@field private __writer vim.ui.img._Writer
local M = {
  __autocmds = {},
  __has_loaded = false,
  __images = {},
  __is_tmux = false,
  __placements = {},
  __writer = nil, -- To be filled in during load()
}

---@param opts? {write?:fun(...:string)}
function M:load(opts)
  opts = opts or {}

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

  self.__writer = require('vim.ui.img._writer').new({
    use_chan_send = true,
    map = function(s)
      if self.__is_tmux then
        local codes = require('vim.ui.img._codes')
        s = codes.escape_tmux_passthrough(s)
      end
      return s
    end,
    write = opts.write,
  })

  -- For kitty, we want to make sure that we properly unload when exiting
  -- neovim, especially if we're in tmux
  table.insert(
    self.__autocmds,
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        self:unload()
      end,
    })
  )

  self.__has_loaded = true
end

function M:unload()
  self:__delete_all()

  for _, id in ipairs(self.__autocmds) do
    pcall(vim.api.nvim_del_autocmd, id)
  end

  self.__autocmds = {}
  self.__images = {}
  self.__is_tmux = false
  self.__placements = {}
  self.__writer = nil
end

---@param img vim.ui.Image
---@param opts vim.ui.img.InternalOpts
---@param on_shown fun(err:string|nil, id:integer|nil)
function M:show(img, opts, on_shown)
  on_shown = vim.schedule_wrap(on_shown)

  if not img:is_png() then
    on_shown('image is not a PNG')
    return
  end

  -- Check if we need to transmit our image or if it is already available
  -- TODO: This should really query to see if the image is still loaded
  --       otherwise re-transmit the image. This is especially apparent
  --       when switching between providers as something happens to clear
  --       the images (I think) and they don't show up anymore
  local image_id = self.__images[img.id]
  if not image_id then
    -- If remote, we have to use a direct transmit instead of file
    if self:__is_remote() then
      image_id = self:__transmit_image_direct(img)
    else
      image_id = self:__transmit_image_file(img)
    end
    self.__images[img.id] = image_id
  end

  local placement_id = self:__display_image(image_id, opts)
  self.__placements[placement_id] = image_id

  -- Since we're writing the image display and ignoring the response,
  -- we will just assume that no Lua error at this point means success
  on_shown(nil, placement_id)
end

---@param ids integer[]
---@param on_hidden fun(err:string|nil, ids:integer[]|nil)
function M:hide(ids, on_hidden)
  for _, pid in ipairs(ids) do
    local id = self.__placements[pid]
    if id then
      self:__delete_image_or_placement(id, pid)
      self.__placements[pid] = nil
    end
  end

  -- Since we're writing the image deletion and ignoring the response,
  -- we will just assume that no Lua error at this point means success
  vim.schedule(function()
    on_hidden(nil, ids)
  end)
end

---@param pid integer
---@param opts vim.ui.img.InternalOpts
---@param on_updated fun(err:string|nil, id:integer|nil)
function M:update(pid, opts, on_updated)
  local id = assert(self.__placements[pid], string.format('kitty(update): invalid id %s', pid))

  ---@diagnostic disable-next-line:inject-field
  opts.pid = pid

  local new_id = self:__display_image(id, opts)

  -- Since we're writing the image display and ignoring the response,
  -- we will just assume that no Lua error at this point means success
  vim.schedule(function()
    on_updated(nil, new_id)
  end)
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

  return table.concat(data)
end

---@private
---Transmit an image directly via a filesystem path.
---@param image vim.ui.Image
---@return integer id unique id assigned to the image
function M:__transmit_image_file(image)
  local id = self:__next_id()

  local control = {}
  control['f'] = '100' -- Assume we are working with PNG
  control['a'] = 't' -- Transmit image data without displaying
  control['t'] = 'f' -- Signify that this is a file transmit
  control['i'] = id -- Specify the id of the image
  control['q'] = 2 -- Suppress all responses

  -- Payload for a file transmit is the base64-encoded file path
  local payload = vim.base64.encode(image.file)

  self.__writer.write_fast(self:__make_seq(control, payload))

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
  if image:len() == 0 then
    assert(image:reload():wait())
  end

  ---@param chunk string data of chunk
  ---@param pos integer starting byte position of chunk
  ---@param last boolean true if final chunk
  image:chunks({ base64 = true, size = MAX_DATA_CHUNK }):each(function(chunk, pos, last)
    local control = {}

    -- If at the beginning of our image, supply common control info
    if pos == 1 then
      control['f'] = '100' -- Assume we are working with PNG
      control['a'] = 't' -- Transmit image data without displaying
      control['t'] = 'd' -- Signify that this is a direct transmit
      control['i'] = id -- Specify the id of the image
      control['q'] = 2 -- Suppress all responses
    end

    -- Mark whether we have more data to send
    control['m'] = last and 0 or 1

    -- NOTE: This may need direct tty device access to function!
    self.__writer.write_fast(self:__make_seq(control, chunk))
  end)

  return id
end

---@private
---Display a transmitted image into the kitty terminal.
---@param id integer
---@param opts vim.ui.img.InternalOpts|{pid?:integer}
---@return integer placement_id
function M:__display_image(id, opts)
  local codes = require('vim.ui.img._codes')

  -- Create a unique placement id for this new display
  local pid = opts.pid or self:__next_id()

  -- Ensure the queue is empty before we start a sequence
  self.__writer.flush()

  -- Capture old cursor position, hide the cursor, and move to the
  -- position where the image should be displayed
  self.__writer.write(
    codes.cursor_save,
    codes.cursor_hide,
    codes.move_cursor({ col = opts.col, row = opts.row })
  )

  -- TODO: Do we use U=1 for inline placements via virtual unicode?
  local control = {}
  control['a'] = 'p' -- Display (put) a transmitted image
  control['i'] = id -- Specify the id of the image to display
  control['p'] = pid -- Specify the id of the distinct placement
  control['C'] = 1 -- Don't move the cursor after the image
  control['q'] = 2 -- Suppress all responses

  if opts.width then
    control['c'] = opts.width
  end

  if opts.height then
    control['r'] = opts.height
  end

  control['z'] = opts.z

  self.__writer.write(self:__make_seq(control), codes.cursor_restore, codes.cursor_show)

  -- Submit the image display request including cursor movement
  self.__writer.flush()

  return pid
end

---@private
---Delete a displayed image that is visible within kitty terminal.
---@param image_id integer
---@param placement_id? integer
function M:__delete_image_or_placement(image_id, placement_id)
  local control = {}
  control['a'] = 'd' -- Perform a deletion
  control['d'] = 'i' -- Delete either a transmitted image or placement
  control['i'] = image_id -- Specify the id of the image to delete
  control['p'] = placement_id -- Specify the id of the image placement to delete
  control['q'] = 2 -- Suppress all responses

  self.__writer.write_fast(self:__make_seq(control))
end

---@private
---Delete all placements and associated images within kitty terminal.
function M:__delete_all()
  local control = {}
  control['a'] = 'd' -- Perform a deletion
  control['d'] = 'A' -- Delete all visible placements and images
  control['q'] = 2 -- Suppress all responses

  self.__writer.write_fast(self:__make_seq(control))
end

---@private
---@return boolean
function M:__is_remote()
  return vim.env.SSH_CLIENT ~= nil or vim.env.SSH_CONNECTION ~= nil
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
  load = function(...)
    return M:load(...)
  end,
  unload = function()
    return M:unload()
  end,
  show = function(img, opts, on_shown)
    return M:show(img, opts, on_shown)
  end,
  hide = function(ids, on_hidden)
    return M:hide(ids, on_hidden)
  end,
  update = function(id, opts, on_updated)
    return M:update(id, opts, on_updated)
  end,
})
