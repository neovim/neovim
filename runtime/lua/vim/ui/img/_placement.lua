---@class vim.ui.img._Placement
---@field relative vim.ui.img.Relative
---@field row integer starting row in cells (1-indexed)
---@field col integer starting column in cells (1-indexed)
---@field width? integer width to display in cells (required unless relative to the ui)
---@field height? integer height to display in cells (required unless relative to the ui)
---@field zindex? integer position in stack (rendered lower to higher)
---@field pad integer blank cells before image (default 0)
---@field buf? integer buffer anchoring the image (buffer mode, never 0)
---@field private _win? integer window where image "placement" is located
---@field private _scratch? integer scratch buffer backing the float
---@field private _mark? integer virtual lines extmark id
---@field private _hlmark? integer highlight extmark id
local M = {}
M.__index = M

local ns = vim.api.nvim_create_namespace('vim.ui.img._placement')

---Prefix each line with pad blank cells.
---@param lines string[]
---@param pad integer
---@return string[]
local function pad_lines(lines, pad)
  if pad <= 0 then
    return lines
  end

  local prefix = string.rep(' ', pad)

  ---@type string[]
  local out = {}
  for i, line in ipairs(lines) do
    out[i] = prefix .. line
  end

  return out
end

---Wrap lines as virt_lines chunks.
---@param lines string[]
---@param hl string
---@param pad integer
---@return {[1]:string, [2]:string}[][]
local function virt_lines(lines, hl, pad)
  local pad_chunk = pad > 0 and { string.rep(' ', pad), 'Normal' } or nil

  ---@type {[1]:string, [2]:string}[][]
  local vlines = {}
  for i, line in ipairs(lines) do
    ---@type {[1]:string, [2]:string}[]
    local vline = {}

    if pad_chunk then
      vline[#vline + 1] = pad_chunk
    end

    vline[#vline + 1] = { line, hl }
    vlines[i] = vline
  end

  return vlines
end

---Returns the relative positioning for the given image {opts}.
---@param opts vim.ui.img.Opts
---@param fallback? vim.ui.img.Relative used when {opts} implies nothing (default 'ui')
---@return vim.ui.img.Relative
function M.relative_of(opts, fallback)
  -- If relative isn't specified, we'll default to the fallback unless a buffer is provided
  return opts.relative or (opts.buf ~= nil and 'buffer' or fallback or 'ui')
end

---Creates a new placement for the given image {opts}.
---@param opts vim.ui.img.Opts
---@return vim.ui.img._Placement
function M.new(opts)
  local self = setmetatable({}, M)

  self.relative = M.relative_of(opts)

  self.row = opts.row or 1
  self.col = opts.col or 1
  self.width = opts.width
  self.height = opts.height
  self.zindex = opts.zindex
  self.pad = opts.pad or 0

  -- If relative to a buffer, we want to calculate the buffer immediately
  if self.relative == 'buffer' then
    local buf = opts.buf
    self.buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  end

  -- When relative to the editor or a buffer, we require the width and height
  -- of the image to be specified as we need to build a grid of unicode chars
  assert(self.relative == 'ui' or (self.width and self.height), 'width and height required')

  return self
end

---Creates a copy of this placement, merging in {opts}.
---@param opts vim.ui.img.Opts
---@return vim.ui.img._Placement placement
---@return boolean reused true if the copy reuses this placement's window, scratch buffer, and extmarks
function M:with(opts)
  local placement = M.new(vim.tbl_extend('force', self:opts(), opts, {
    relative = M.relative_of(opts, self.relative),
  }))

  local reused = self.relative == placement.relative
    and (self.relative ~= 'buffer' or self.buf == placement.buf)

  -- When the relative position is the same, we also can copy over the
  -- internal data about windows, scratch buffers, etc. otherwise we
  -- need to leave it empty
  if reused then
    placement._win = self._win
    placement._scratch = self._scratch
    placement._mark = self._mark
    placement._hlmark = self._hlmark
  end

  return placement, reused
end

---Displays this placement, creating or updating any associated windows,
---buffers, and extmarks with content from {render}.
---
---NOTE: This does nothing when the placement is relative to the ui.
---@param render fun(width: integer, height: integer): string[], string #returns text lines and highlight group
function M:set(render)
  if self.relative == 'editor' then
    local lines, hl = render(self.width, self.height)
    self:_set_window(pad_lines(lines, self.pad), hl)
  elseif self.relative == 'buffer' then
    local lines, hl = render(self.width, self.height)
    self:_set_buffer(virt_lines(lines, hl, self.pad))
  end
end

---Returns a copy of the image options associated with this placement.
---@return vim.ui.img.Opts opts
function M:opts()
  return {
    relative = self.relative,
    row = self.row,
    col = self.col,
    width = self.width,
    height = self.height,
    zindex = self.zindex,
    pad = self.pad,
    buf = self.buf,
  }
end

---Deletes this placement, clearing out any associated windows, buffers, and extmarks.
function M:del()
  local win = self._win
  local scratch = self._scratch
  local mark = self._mark

  self._win = nil
  self._scratch = nil
  self._mark = nil
  self._hlmark = nil

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end

  if scratch and vim.api.nvim_buf_is_valid(scratch) then
    vim.api.nvim_buf_delete(scratch, { force = true })
  end

  if mark and self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_del_extmark(self.buf, ns, mark)
  end
end

---Returns true if this placement owns the window {win}.
---@param win integer
---@return boolean
function M:owns_win(win)
  return self._win == win
end

---Returns true if this placement owns the buffer {buf}.
---@param buf integer
---@return boolean
function M:owns_buf(buf)
  return self.relative == 'buffer' and self.buf == buf
end

---@private
---Sets the lines of the placement's internal buffer tied to the floating window.
---
---NOTE: If the window does not exist, it will be created; otherwise, it is updated
---based on the current configuration of the placement such as position, size, and zindex.
---@param lines string[] raw lines of text to set within the scratch buffer of the window
---@param hl string highlight group to apply to all lines
function M:_set_window(lines, hl)
  local scratch = self._scratch

  -- If we don't have a scratch buffer for our window, create
  -- one now so we can populate it with our lines
  if not (scratch and vim.api.nvim_buf_is_valid(scratch)) then
    scratch = vim.api.nvim_create_buf(false, true)
    self._scratch = scratch
  end

  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)

  -- Apply our highlight across all of the lines within the scratch buffer
  self._hlmark = vim.api.nvim_buf_set_extmark(scratch, ns, 0, 0, {
    id = self._hlmark,
    end_row = self.height,
    hl_group = hl,
  })

  local config = {
    relative = 'editor',
    row = self.row - 1,
    col = self.col - 1,
    width = self.width + self.pad,
    height = self.height,
    zindex = self.zindex,

    -- Keep the image anchored at its requested position when it extends past the screen edge
    fixed = true,
  }

  -- If we already have a window created, we just need to update it with the
  -- new dimensions and other details; otherwise, we need to create it
  if self._win and vim.api.nvim_win_is_valid(self._win) then
    vim.api.nvim_win_set_config(self._win, config)
  else
    config.style = 'minimal'
    config.border = 'none'
    config.focusable = false
    config.noautocmd = true
    self._win = vim.api.nvim_open_win(scratch, false, config)
  end
end

---@private
---Sets the virtual lines of the placement's internal buffer.
---@param vlines {[1]:string, [2]:string}[][] each line is a list of `[text_chunk, hl]` tuples
function M:_set_buffer(vlines)
  self._mark = vim.api.nvim_buf_set_extmark(self.buf, ns, self.row - 1, self.col - 1, {
    id = self._mark,
    virt_lines = vlines,
    invalidate = true,
  })
end

return M
