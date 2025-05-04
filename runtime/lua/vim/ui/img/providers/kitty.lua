---Kitty supports 4096 bytes per chunk when sending remote client data.
local MAX_DATA_CHUNK = 4096

---Mapping of neovim image id -> kitty image id.
---@type table<integer, integer>
local NVIM_IMAGE_TO_KITTY_IMAGE = {}

---Mapping of kitty placement id -> kitty image id.
---@type table<integer, integer>
local KITTY_PLACEMENT_TO_IMAGE = {}

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

---Move the terminal cursor to cell x, y.
---@param x integer
---@param y integer
local function move_cursor(x, y)
  io.stdout:write(string.format('\027[%s;%sH', math.floor(y), math.floor(x)))
end

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

  return table.concat(data)
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

  ---@param chunk string data of chunk
  ---@param pos integer starting byte position of chunk
  ---@param last boolean true if final chunk
  image:chunks({ size = MAX_DATA_CHUNK }):each(function(chunk, pos, last)
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
---@param opts vim.ui.img.Opts
---@return integer placement_id
local function display_image(id, opts)
  -- Create a unique placement id for this new display
  local pid = next_id()

  if opts.pos then
    local pos_cells = opts.pos:to_cells()
    move_cursor(pos_cells.x, pos_cells.y)
  end

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
    control['x'] = tostring(x)
    control['y'] = tostring(y)
    control['w'] = tostring(w)
    control['h'] = tostring(h)
  end

  if size then
    local size_cells = size:to_cells()
    control['c'] = tostring(size_cells.width)
    control['r'] = tostring(size_cells.height)
  end

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

---@param image vim.ui.Image
---@param opts? vim.ui.img.Opts|{remote?:boolean}
---@return integer
local function show(image, opts)
  opts = opts or {}

  -- Check if we need to transmit our image or if it is already available
  local image_id = NVIM_IMAGE_TO_KITTY_IMAGE[image.id]
  if not image_id then
    -- If remote, we have to use a direct transmit instead of file
    if opts.remote then
      image_id = transmit_image_direct(image)
    else
      image_id = transmit_image_file(image)
    end
    NVIM_IMAGE_TO_KITTY_IMAGE[image.id] = image_id
  end

  local placement_id = display_image(image_id, opts)
  KITTY_PLACEMENT_TO_IMAGE[placement_id] = image_id

  return placement_id
end

---@param ids integer[]
local function hide(ids)
  for _, pid in ipairs(ids) do
    local id = KITTY_PLACEMENT_TO_IMAGE[pid]
    if id then
      delete_image(id, pid)
    end
  end

  -- TODO: When do we delete the image from kitty entirely?
  --
  -- 1. When there are no placements?
  -- 2. When neovim exits?
end

return require('vim.ui.img.providers').new({
  show = show,
  hide = hide,
})
