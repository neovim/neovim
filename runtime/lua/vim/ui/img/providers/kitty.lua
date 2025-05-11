---Kitty supports 4096 bytes per chunk when sending remote client data.
---
local MAX_DATA_CHUNK = 4096

---Mapping of neovim image id -> kitty image id.
---@type table<integer, integer>
local NVIM_IMAGE_TO_KITTY_IMAGE = {}

---Mapping of kitty placement id -> kitty image id.
---@type table<integer, integer>
local KITTY_PLACEMENT_TO_IMAGE = {}

---Indicates whether or not neovim is running within tmux.
---@type boolean
local IS_TMUX = false

---If true, indicates provider has been loaded at least once.
---@type boolean
local HAS_LOADED = false

local next_id = (function()
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
local function make_seq(control, payload)
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

  if IS_TMUX then
    seq = ('\027Ptmux;' .. string.gsub(seq, '\027', '\027\027')) .. '\027\\'
  end

  return seq
end

---Transmit an image directly via a filesystem path.
---@param image vim.ui.Image
---@return integer id unique id assigned to the image
local function transmit_image_file(image)
  local id = next_id()

  local control = {}
  control['f'] = '100' -- Assume we are working with PNG
  control['a'] = 't'   -- Transmit image data without displaying
  control['t'] = 'f'   -- Signify that this is a file transmit
  control['i'] = id    -- Specify the id of the image
  control['q'] = 2     -- Suppress all responses

  -- Payload for a file transmit is the base64-encoded file path
  local payload = vim.base64.encode(image.filename)

  io.stdout:write(make_seq(control, payload))

  return id
end

---Transmit an image directly via escape codes.
---
---This is the approach to take with remote clients (i.e. ssh) when the
---filesystem and shared memory are not accessible.
---@param image vim.ui.Image
---@return integer id unique id assigned to the image
local function transmit_image_direct(image)
  local id = next_id()

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
    io.stdout:write(make_seq(control, chunk))
  end)

  return id
end

---Display a transmitted image into the kitty terminal.
---@param id integer
---@param opts vim.ui.img.Opts|{pid?:integer}
---@return integer placement_id
local function display_image(id, opts)
  local utils = require('vim.ui.img.utils')

  -- Create a unique placement id for this new display
  local pid = opts.pid or next_id()

  -- Move cursor to position where image should be displayed
  local pos = opts:position():to_cells()
  utils.move_cursor(pos.x, pos.y)

  -- TODO: Do we use U=1 for inline placements via virtual unicode?
  local control = {}
  control['a'] = 'p' -- Display (put) a transmitted image
  control['i'] = id  -- Specify the id of the image to display
  control['p'] = pid -- Specify the id of the distinct placement
  control['C'] = 1   -- Don't move the cursor after the image
  control['q'] = 2   -- Suppress all responses

  local crop = opts.crop
  local size = opts.size

  if crop then
    local x, y, w, h = crop:to_pixels():to_bounds()
    control['x'] = x
    control['y'] = y
    control['w'] = w
    control['h'] = h
  end

  if size then
    local size_cells = size:to_cells()
    control['c'] = size_cells.width
    control['r'] = size_cells.height
  end

  control['z'] = opts.z

  io.stdout:write(make_seq(control))

  return pid
end

---Delete a displayed image that is visible within kitty terminal.
---@param image_id integer
---@param placement_id? integer
local function delete_image(image_id, placement_id)
  local control = {}
  control['a'] = 'd'          -- Perform a deletion
  control['d'] = 'i'          -- Delete either a transmitted image or placement
  control['i'] = image_id     -- Specify the id of the image to delete
  control['p'] = placement_id -- Specify the id of the image placement to delete
  control['q'] = 2            -- Suppress all responses

  io.stdout:write(make_seq(control))
end

---@param _self vim.ui.img.Provider
local function load(_self)
  if HAS_LOADED then
    return
  end

  -- Check if we are inside tmux, and if so we need to configure it to support
  -- allowing passthrough of escape codes for kitty's graphics protocol and
  -- flag that we need to transform escape codes sent to be compliant with tmux
  if vim.env['TMUX'] ~= nil then
    local res = vim.system({ "tmux", "set", "-p", "allow-passthrough", "all" }):wait()
    assert(res.code == 0, 'failed to "set -p allow-passthrough all" for tmux')
    IS_TMUX = true
  end

  HAS_LOADED = true
end

---@param _self vim.ui.img.Provider
---@param img vim.ui.Image
---@param opts? vim.ui.img.Opts|{remote?:boolean}
---@return integer
local function show(_self, img, opts)
  local is_remote = opts and opts.remote
  opts = require('vim.ui.img.opts').new(opts)

  -- Check if we need to transmit our image or if it is already available
  local image_id = NVIM_IMAGE_TO_KITTY_IMAGE[img.id]
  if not image_id then
    -- If remote, we have to use a direct transmit instead of file
    if is_remote then
      image_id = transmit_image_direct(img)
    else
      image_id = transmit_image_file(img)
    end
    NVIM_IMAGE_TO_KITTY_IMAGE[img.id] = image_id
  end

  local placement_id = display_image(image_id, opts)
  KITTY_PLACEMENT_TO_IMAGE[placement_id] = image_id

  return placement_id
end

---@param _self vim.ui.img.Provider
---@param ids integer[]
local function hide(_self, ids)
  for _, pid in ipairs(ids) do
    local id = KITTY_PLACEMENT_TO_IMAGE[pid]
    if id then
      delete_image(id, pid)
      KITTY_PLACEMENT_TO_IMAGE[pid] = nil
    end
  end

  -- TODO: When do we delete the image from kitty entirely?
  --
  -- 1. When there are no placements?
  -- 2. When neovim exits?
end

---@param _self vim.ui.img.Provider
---@param pid integer
---@param opts? vim.ui.img.Opts
---@return integer
local function update(_self, pid, opts)
  local id = assert(
    KITTY_PLACEMENT_TO_IMAGE[pid],
    string.format('kitty(update): invalid displayed image id %s', pid)
  )

  opts = require('vim.ui.img.opts').new(opts)

  ---@diagnostic disable-next-line:inject-field
  opts.pid = pid

  return display_image(id, opts)
end

return require('vim.ui.img.providers').new({
  on_load = load,
  on_show = show,
  on_hide = hide,
  on_update = update,
})
