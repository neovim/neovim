---Kitty graphics protocol implementation for vim.ui.img.
---@class vim.ui.img._kitty: vim.ui.img._Backend
local M = {}

---@type vim.ui.img._util
local util = require('vim.ui.img._util')

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
---
---Chunks are sent back-to-back: the protocol forbids interleaving other
---graphics escapes into a chunked transmission, and all chunks except the
---last must have a size that is a multiple of 4.
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

---Constant since we keep a single placement per image; re-placing with the
---same (i, p) replaces the previous placement.
local placement_id = 1

---Transmit an image, or (re-)place a transmitted image.
---
---When {data_or_id} is a string, transmits the bytes without displaying and
---returns the new image id. When it is an id, places the image per
---{opts.relative}: absolute terminal coordinates for 'ui', an invisible
---virtual placement (unicode placeholder mode) otherwise.
---@param data_or_id string|integer image bytes (string) or image id (integer)
---@param opts? vim.ui.img.Opts required when placing an image id
---@return integer id
function M.set(data_or_id, opts)
  -- If given data, we just transmit it without rendering it, and return the id
  if type(data_or_id) == 'string' then
    local id = util.generate_id()
    transmit(id, data_or_id)
    return id
  end

  -- Otherwise, when given an id, we assume it has been transmitted already,
  -- and figure out how we plan to render it (placeholder unicode or directly)
  local id = data_or_id
  assert(opts, 'opts required when placing an image id')

  if opts.relative == nil or opts.relative == 'ui' then
    local cursor_save = '\0277'
    local cursor_hide = '\027[?25l'
    local cursor_move = string.format('\027[%d;%dH', opts.row or 1, opts.col or 1)
    local cursor_restore = '\0278'
    local cursor_show = '\027[?25h'

    ---@type table<string, string|number>
    local control = {
      a = 'p',
      i = id,
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
  else
    vim.api.nvim_ui_send(seq({
      a = 'p',
      U = '1',
      i = id,
      p = placement_id,
      c = opts.width,
      r = opts.height,
      q = '2',
    }))
  end

  return id
end

---Delete image {id}, both its placements and transmitted data.
---@param id integer
function M.del(id)
  vim.api.nvim_ui_send(seq({ a = 'd', d = 'I', i = id, q = '2' }))
end

--- Query whether this terminal supports the kitty graphics protocol.
--- Blocks until the terminal responds or times out.
---
---@param opts? {timeout?: integer, chan?: integer} timeout in milliseconds (default: 1000)
---@return boolean supported
---@return string? msg error detail if terminal responded but not with OK
function M.supported(opts)
  opts = opts or {}
  local timeout = opts.timeout or 1000

  -- Do not use APC on terminals that echo unknown sequences
  if vim.env.TERM_PROGRAM == 'Apple_Terminal' then
    return false
  end

  local query_id = util.generate_id()

  ---@type boolean?
  local result
  ---@type string?
  local msg

  vim.tty.query_apc(
    seq({ a = 'q', i = query_id, s = 1, v = 1 }),
    { timeout = timeout, chan = opts.chan },
    function(resp)
      -- kitty APC response: \027_G[<fields>,]i=<id>[,<fields>];<status>
      -- status is "OK" or an error code+message like "ENODATA:Missing image data"
      ---@type string?
      local id = resp:match('^\027_G[^;]*i=(%d+)')

      ---@type string?
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
