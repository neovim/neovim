---Utility functions tied to neovim's image api.
---@class vim.ui._img._util
---@field private _tmux_initialized boolean
local M = {
  _tmux_initialized = false,
}

---Check if image data is PNG format.
---@param data string
---@return boolean
function M.is_png_data(data)
  ---PNG magic number for format validation
  local PNG_SIGNATURE = '\137PNG\r\n\26\n'

  return data and data:sub(1, #PNG_SIGNATURE) == PNG_SIGNATURE
end

---Check if running in remote environment (SSH).
---@return boolean
function M.is_remote()
  return vim.env.SSH_CLIENT ~= nil or vim.env.SSH_CONNECTION ~= nil
end

---Send data to terminal using nvim_ui_send, potentially wrapping to support tmux.
---@param data string
function M.term_send(data)
  -- If we are running inside tmux, we need to escape the terminal sequence
  -- to have it properly pass through
  if vim.env.TMUX ~= nil then
    -- If tmux hasn't been configured to allow passthrough, we need to
    -- manually do so. Only required once
    if not M._tmux_initialized then
      local res = vim.system({ 'tmux', 'set', '-p', 'allow-passthrough', 'all' }):wait()
      if res.code ~= 0 then
        error('failed to "set -p allow-passthrough all" for tmux')
      end
      M._tmux_initialized = true
    end

    -- Wrap our sequence with the tmux DCS passthrough code
    data = '\027Ptmux;\027' .. string.gsub(data, '\027', '\027\027') .. '\027\\'
  end

  vim.api.nvim_ui_send(data)
end

---Load image data from file synchronously
---@return string data
function M.load_image_data(file)
  local fd, stat_err = vim.uv.fs_open(file, 'r', 0)
  if not fd then
    error('failed to open file: ' .. (stat_err or 'unknown error'))
  end

  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    error('failed to get file stats')
  end

  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)

  if not data then
    error('failed to read file data')
  end

  return data
end

M.generate_id = (function()
  local bit = require('bit')
  local NVIM_PID_BITS = 10

  local nvim_pid = 0
  local cnt = 30

  ---Generate unique ID for this Neovim instance
  ---@return integer id
  return function()
    -- Generate a unique ID for this nvim instance (10 bits)
    if nvim_pid == 0 then
      local pid = vim.fn.getpid()
      nvim_pid = bit.band(bit.bxor(pid, bit.rshift(pid, 5), bit.rshift(pid, NVIM_PID_BITS)), 0x3FF)
    end

    cnt = cnt + 1
    return bit.bor(bit.lshift(nvim_pid, 24 - NVIM_PID_BITS), cnt)
  end
end)()

return M
