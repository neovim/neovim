---Kitty graphics protocol implementation for vim.ui.img.
local M = {}

---@type vim.ui.img._util
local util = require('vim.ui.img._util')

---@alias vim.ui.img._kitty.State
---|{ ui: true }                      -- ui mode: terminal-native kitty placement
---|{ win: integer, buf: integer }    -- editor mode: floating window + scratch buffer
---|{ mark: integer, buf: integer }   -- buffer mode: extmark ID + user buffer handle

---Internal state: maps img_id → placement state.
---@type table<integer, vim.ui.img._kitty.State>
local state = {}

local ns_id = vim.api.nvim_create_namespace('vim.ui.img.kitty')

---@return string
local function img_hl(img_id)
  return 'NvimImgPlaceholder_' .. img_id
end

---Parse pixel dimensions from a PNG IHDR chunk.
---@param data string raw image bytes
---@return integer? width_px
---@return integer? height_px
local function png_dimensions(data)
  if #data < 24 then
    return nil, nil
  end
  local w = data:byte(17) * 0x1000000
    + data:byte(18) * 0x10000
    + data:byte(19) * 0x100
    + data:byte(20)
  local h = data:byte(21) * 0x1000000
    + data:byte(22) * 0x10000
    + data:byte(23) * 0x100
    + data:byte(24)
  return w, h
end

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

---Create an invisible Kitty virtual placement for unicode placeholder mode.
---@param img_id integer
---@param placement_id integer
---@param width integer columns
---@param height integer rows
local function create_virtual_placement(img_id, placement_id, width, height)
  vim.api.nvim_ui_send(seq({
    a = 'p',
    U = '1',
    i = img_id,
    p = placement_id,
    c = width,
    r = height,
    q = '2',
  }))
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

---Build virt_lines of placeholder chars for nvim_buf_set_extmark (buffer mode).
---Each cell: U+10EEEE + row diacritic + col diacritic, colored with img_id highlight.
---@param img_id integer
---@param width integer
---@param height integer
---@param pad integer leading blank cells per row
---@return {[1]:string, [2]:string}[][] virt_lines
local function build_placeholder_lines(img_id, width, height, pad)
  local hl = img_hl(img_id)

  ---@type {[1]:string, [2]:string}[][]
  local lines = {}
  for r = 0, height - 1 do
    -- Build our row of placeholders representing the positions of the image to display
    local row_str = ''
    for c = 0, width - 1 do
      row_str = row_str .. util.cell_unicode(r, c)
    end

    -- Build our line, optionally including padding
    ---@type {[1]:string, [2]:string}[]
    local line = {}
    if pad > 0 then
      line[#line + 1] = { string.rep(' ', pad), 'Normal' }
    end
    line[#line + 1] = { row_str, hl }

    lines[#lines + 1] = line
  end

  return lines
end

---Build buffer lines of placeholder chars for a scratch buffer (editor mode).
---Returns plain strings suitable for nvim_buf_set_lines.
---@param width integer
---@param height integer
---@return string[] lines
local function build_scratch_lines(width, height)
  ---@type string[]
  local lines = {}

  for r = 0, height - 1 do
    local row_str = ''
    for c = 0, width - 1 do
      row_str = row_str .. util.cell_unicode(r, c)
    end
    lines[r + 1] = row_str
  end

  return lines
end

---Transmit image bytes and set up display (floating window or extmark).
---Returns img_id and placement_id.
---@param data string raw image bytes
---@param opts vim.ui.img.Opts
---@return integer img_id
---@return integer placement_id
function M.set(data, opts)
  local relative = opts.relative or (opts.buf ~= nil and 'buffer' or 'ui')

  -- editor/buffer modes require explicit cell dimensions for the unicode placeholder grid;
  -- ui mode delegates sizing to kitty so width/height are optional.
  if relative ~= 'ui' and (not opts.width or not opts.height) then
    local px_w, px_h = png_dimensions(data)
    if px_w then
      local width_px, height_px = util.cell_size_px()
      opts.width = opts.width or math.ceil(px_w / width_px)
      opts.height = opts.height or math.ceil(px_h / height_px)
    end
  end
  assert(
    relative == 'ui' or (opts.width and opts.height),
    'width and height required (could not derive from image data)'
  )
  if relative ~= 'ui' then
    util.assert_unicode_range(opts.width, opts.height)
  end

  -- Upload our image data, which we'll use for future placements
  local img_id = util.generate_id()
  local placement_id = util.generate_id()
  transmit(img_id, data)

  -- Placement method depends on relative:
  --
  -- 1. 'ui': terminal-native kitty placement via cursor save/move/restore
  -- 2. 'editor': frameless floating window filled with unicode placeholder chars
  -- 3. 'buffer': extmark virt_lines filled with unicode placeholder chars
  --
  -- editor/buffer modes use an invisible virtual placement (U=1) so kitty maps
  -- each placeholder cell to the correct image region via the image ID in fg color.
  if relative == 'ui' then
    place(img_id, placement_id, opts)
    state[img_id] = { ui = true }
  elseif relative == 'editor' then
    create_virtual_placement(img_id, placement_id, opts.width, opts.height)

    -- The image ID is encoded in the foreground color
    vim.api.nvim_set_hl(0, img_hl(img_id), { fg = img_id })
    local scratch_buf = vim.api.nvim_create_buf(false, true)
    local lines = build_scratch_lines(opts.width, opts.height)
    vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_extmark(scratch_buf, ns_id, 0, 0, {
      end_row = opts.height,
      hl_group = img_hl(img_id),
    })

    local win = vim.api.nvim_open_win(scratch_buf, false, {
      relative = 'editor',
      row = (opts.row or 1) - 1,
      col = (opts.col or 1) - 1,
      width = opts.width,
      height = opts.height,
      style = 'minimal',
      border = 'none',
      focusable = false,
      noautocmd = true,
      zindex = opts.zindex,
    })

    state[img_id] = { win = win, buf = scratch_buf }
  elseif relative == 'buffer' then
    create_virtual_placement(img_id, placement_id, opts.width, opts.height)

    -- The image ID is encoded in the foreground color
    vim.api.nvim_set_hl(0, img_hl(img_id), { fg = img_id })
    local buf = opts.buf
    if buf == nil or buf == 0 then
      buf = vim.api.nvim_get_current_buf()
    end
    local row = (opts.row or 1) - 1
    local col = (opts.col or 1) - 1
    local pad = opts.pad or 0
    local lines = build_placeholder_lines(img_id, opts.width, opts.height, pad)
    local mark = vim.api.nvim_buf_set_extmark(buf, ns_id, row, col, {
      virt_lines = lines,
      invalidate = true,
    })

    state[img_id] = { mark = mark, buf = buf }
  end

  return img_id, placement_id
end

---Update an existing placement (flicker-free, reuses same IDs).
---@param img_id integer
---@param placement_id integer
---@param opts vim.ui.img.Opts merged opts
function M.update(img_id, placement_id, opts)
  local entry = state[img_id]
  if not entry then
    return
  end

  if not entry.ui then
    util.assert_unicode_range(opts.width or 0, opts.height or 0)
  end

  -- We check the type of placement method based on the state's information:
  --
  -- 1. ui = true: we need to update a kitty image, which is relative to the terminal ui
  -- 2. win exists: the image is using a floating window with unicode placeholders
  -- 3. otherwise: the image is within a buffer with unicode placeholders
  local is_relative_ui = entry.ui
  local is_relative_editor = entry.win

  if is_relative_ui then
    place(img_id, placement_id, opts)
  elseif is_relative_editor then
    create_virtual_placement(img_id, placement_id, opts.width, opts.height)

    vim.api.nvim_win_set_config(entry.win, {
      relative = 'editor',
      row = (opts.row or 1) - 1,
      col = (opts.col or 1) - 1,
      width = opts.width,
      height = opts.height,
      zindex = opts.zindex,
    })
    local lines = build_scratch_lines(opts.width, opts.height)
    vim.api.nvim_buf_set_lines(entry.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_extmark(entry.buf, ns_id, 0, 0, {
      end_row = opts.height,
      hl_group = img_hl(img_id),
    })
  else
    create_virtual_placement(img_id, placement_id, opts.width, opts.height)

    local pad = opts.pad or 0
    local lines = build_placeholder_lines(img_id, opts.width, opts.height, pad)
    local row = (opts.row or 1) - 1
    local col = (opts.col or 1) - 1
    vim.api.nvim_buf_set_extmark(entry.buf, ns_id, row, col, {
      id = entry.mark,
      virt_lines = lines,
      invalidate = true,
    })
  end
end

---Delete an image and all its placements from the terminal.
---When {img_id} is `math.huge`, deletes all images.
---@param img_id integer
function M.delete(img_id)
  if img_id == math.huge then
    for id, entry in pairs(state) do
      if entry.win then
        if vim.api.nvim_win_is_valid(entry.win) then
          vim.api.nvim_win_close(entry.win, true)
        end
        if vim.api.nvim_buf_is_valid(entry.buf) then
          vim.api.nvim_buf_delete(entry.buf, { force = true })
        end
        vim.api.nvim_set_hl(0, img_hl(id), {})
      elseif entry.mark then
        vim.api.nvim_buf_del_extmark(entry.buf, ns_id, entry.mark)
        vim.api.nvim_set_hl(0, img_hl(id), {})
      end
    end
    state = {}

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
      q = '2',
    }))

    local entry = state[img_id]
    if entry and entry.win then
      if vim.api.nvim_win_is_valid(entry.win) then
        vim.api.nvim_win_close(entry.win, true)
      end
      if vim.api.nvim_buf_is_valid(entry.buf) then
        vim.api.nvim_buf_delete(entry.buf, { force = true })
      end
      vim.api.nvim_set_hl(0, img_hl(img_id), {})
    elseif entry and entry.mark then
      vim.api.nvim_buf_del_extmark(entry.buf, ns_id, entry.mark)
      vim.api.nvim_set_hl(0, img_hl(img_id), {})
    end

    state[img_id] = nil
  end
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
