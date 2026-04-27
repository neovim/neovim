---Kitty graphics protocol implementation for vim.ui.img.
local M = {}

local generate_id = (function()
  local bit = require('bit')
  local NVIM_PID_BITS = 10

  local nvim_pid = 0
  local cnt = 30

  ---@return integer
  return function()
    if nvim_pid == 0 then
      local pid = vim.fn.getpid()
      nvim_pid = bit.band(bit.bxor(pid, bit.rshift(pid, 5), bit.rshift(pid, NVIM_PID_BITS)), 0x3FF)
    end
    cnt = cnt + 1
    return bit.bor(bit.lshift(nvim_pid, 24 - NVIM_PID_BITS), cnt)
  end
end)()

---Build a Kitty graphics protocol escape sequence.
---@param control table<string, string|number>
---@param payload? string
---@return string
local function seq(control, payload)
  local parts = { '\027_G' }

  local tmp = {}
  for k, v in pairs(control) do
    table.insert(tmp, k .. '=' .. v)
  end
  if #tmp > 0 then
    table.insert(parts, table.concat(tmp, ','))
  end

  if payload and payload ~= '' then
    table.insert(parts, ';')
    table.insert(parts, payload)
  end

  table.insert(parts, '\027\\')
  return table.concat(parts)
end

---Transmit image bytes to kitty in base64 chunks using direct transmission.
---
---Large images may cause the terminal to hang or the escape sequence to get
---interrupted mid-write. A future filepath option (t=f) could let the
---terminal read the file directly, avoiding this issue for local sessions.
---@param id integer kitty image id
---@param data string raw image bytes
local function transmit(id, data)
  local chunk_size = 4096
  local base64_data = vim.base64.encode(data)
  local pos = 1
  local len = #base64_data

  while pos <= len do
    local end_pos = math.min(pos + chunk_size - 1, len)
    local chunk = base64_data:sub(pos, end_pos)
    local is_last = end_pos >= len

    local control = {}

    if pos == 1 then
      control.f = '100' -- PNG format
      control.a = 't' -- Transmit without displaying
      control.t = 'd' -- Direct transmission
      control.i = id
      control.q = '2' -- Suppress responses
    end

    control.m = is_last and '0' or '1'

    vim.api.nvim_ui_send(seq(control, chunk))
    pos = end_pos + 1
  end
end

---Send a kitty place/display command with cursor management.
---@param img_id integer kitty image id
---@param placement_id integer kitty placement id
---@param opts vim.ui.img.Opts
local function place(img_id, placement_id, opts)
  local cursor_save = '\0277'
  local cursor_hide = '\027[?25l'
  local cursor_move = string.format('\027[%d;%dH', opts.row or 1, opts.col or 1)
  local cursor_restore = '\0278'
  local cursor_show = '\027[?25h'

  ---@type table<string, string|number>
  local control = {
    a = 'p',
    i = img_id,
    p = placement_id,
    C = '1', -- Don't move the cursor at all
    q = '2', -- Suppress responses
  }

  if opts.width then
    control.c = opts.width
  end
  if opts.height then
    control.r = opts.height
  end
  if opts.zindex then
    control.z = opts.zindex
  end

  vim.api.nvim_ui_send(
    cursor_save .. cursor_hide .. cursor_move .. seq(control) .. cursor_restore .. cursor_show
  )
end

---Transmit image bytes and place the image. Returns both IDs.
---@param data string raw image bytes
---@param opts vim.ui.img.Opts
---@return integer img_id
---@return integer placement_id
function M.set(data, opts)
  local img_id = generate_id()
  local placement_id = generate_id()

  transmit(img_id, data)
  place(img_id, placement_id, opts)

  return img_id, placement_id
end

---Update an existing placement (flicker-free, reuses same IDs).
---@param img_id integer
---@param placement_id integer
---@param opts vim.ui.img.Opts
function M.update(img_id, placement_id, opts)
  place(img_id, placement_id, opts)
end

---Delete an image and all its placements from the terminal.
---When {img_id} is `math.huge`, deletes all images.
---@param img_id integer
function M.delete(img_id)
  if img_id == math.huge then
    -- delete all placements and free stored image data (if not referenced elsewhere, e.g. scrollback)
    vim.api.nvim_ui_send(seq({
      a = 'd',
      d = 'A',
      q = '2',
    }))
  else
    vim.api.nvim_ui_send(seq({
      a = 'd',
      d = 'i',
      i = img_id,
      q = '2', -- Suppress responses
    }))
  end
end

--- Query whether this terminal supports the kitty graphics protocol.
--- Blocks until the terminal responds or times out.
---
---@param opts? {timeout?: integer} timeout in milliseconds (default: 1000)
---@return boolean supported
---@return string? msg error detail if terminal responded but not with OK
function M.supported(opts)
  local timeout = opts and opts.timeout or 1000

  -- Do not use APC on terminals that echo unknown sequences
  if vim.env.TERM_PROGRAM == 'Apple_Terminal' then
    return false
  end

  local query_id = generate_id()

  ---@type boolean?
  local result
  ---@type string?
  local msg

  require('vim.tty').query_apc(
    seq({ a = 'q', i = query_id, s = 1, v = 1 }),
    { timeout = timeout },
    function(resp)
      -- kitty APC response: \027_G[<fields>,]i=<id>[,<fields>];<status>
      -- status is "OK" or an error code+message like "ENODATA:Missing image data"
      local id = resp:match('^\027_G[^;]*i=(%d+)')
      local status = resp:match(';(.-)%s*$')
      if id and tonumber(id) == query_id and status then
        result = true
        msg = status ~= 'OK' and status or nil
        return true
      end
    end
  )

  -- Wait in a blocking fashion for the response, checking
  -- at least every 200ms, or faster if the timeout is small
  vim.wait(timeout + 100, function()
    return result ~= nil
  end, math.max(math.min(math.ceil(timeout / 10), 200), 1))

  return result == true, msg
end

return M
