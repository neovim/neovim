---@class vim.ui.img._util
local M = {}

---Parse a PNG IHDR chunk into pixel dimensions (width & height).
---@param data string raw image bytes
---@return {width:integer, height:integer}|nil pixel_size
function M.png_to_pixel_size(data)
  -- Not enough data for a PNG IDHR chunk
  if #data < 24 then
    return nil
  end

  local w = data:byte(17) * 0x1000000
    + data:byte(18) * 0x10000
    + data:byte(19) * 0x100
    + data:byte(20)
  local h = data:byte(21) * 0x1000000
    + data:byte(22) * 0x10000
    + data:byte(23) * 0x100
    + data:byte(24)

  return { width = w, height = h }
end

---Parse a PNG IHDR chunk into cell dimensions (width & height).
---@param data string raw image bytes
---@return {width:integer, height:integer}|nil cell_size
function M.png_to_cell_size(data)
  local pixel_size = M.png_to_pixel_size(data)
  if pixel_size then
    local cell_size = M.cell_as_pixel_size()
    return {
      width = math.ceil(pixel_size.width / cell_size.width),
      height = math.ceil(pixel_size.height / cell_size.height),
    }
  end
end

---Maximum length in milliseconds to wait for a terminal query to get cell size.
local CELL_SIZE_QUERY_TIMEOUT = 500

---Default size of a cell in pixels when we don't know.
---@type {width:integer, height:integer}
local DEFAULT_CELL_SIZE = { width = 10, height = 20 }

---Cache of our calculated terminal cell size as pixels.
---@type {width:integer, height:integer}|nil
local cached_cell_size = nil

vim.api.nvim_create_autocmd({ 'VimResized', 'UIEnter' }, {
  callback = function()
    cached_cell_size = nil
  end,
})

---Returns the size of a cell in the terminal in pixels.
---
---This is performed by querying the terminal via CSI 16t.
---Result is cached; cache is cleared on VimResized.
---@return {width:integer, height:integer} pixel_size
function M.cell_as_pixel_size()
  if cached_cell_size then
    return vim.deepcopy(cached_cell_size)
  end

  -- We cache our result with default values in the case that
  -- this terminal doesn't support retrieving the size via
  -- terminal queries
  local result = vim.deepcopy(DEFAULT_CELL_SIZE)
  local done = false

  require('vim.tty').request('\027[16t', {
    timeout = CELL_SIZE_QUERY_TIMEOUT,
  }, function(resp)
    ---@type string|nil, string|nil
    local h, w = resp:match('^\027%[6;(%d+);(%d+)t')

    local width = tonumber(w)
    local height = tonumber(h)

    if width and height then
      result = { width = width, height = height }
      done = true
      return true
    end
  end)

  -- Wait for the query to finish, and make sure to wait a little longer than our max timeout
  -- in case we get a response close to the end of the timeout range itself
  vim.wait(CELL_SIZE_QUERY_TIMEOUT + 100, function()
    return done
  end)

  -- Cache our latest value from the query (or our defaults)
  cached_cell_size = vim.deepcopy(result)

  return result
end

M.generate_id = (function()
  local bit = require('bit')
  local nvim_pid_bits = 10
  local cnt_mask = bit.lshift(1, 24 - nvim_pid_bits) - 1

  local nvim_pid = 0
  local cnt = 30

  ---Generates a unique id tied to this process.
  ---@return integer
  return function()
    if nvim_pid == 0 then
      local pid = vim.fn.getpid()
      nvim_pid = bit.band(bit.bxor(pid, bit.rshift(pid, 5), bit.rshift(pid, nvim_pid_bits)), 0x3FF)
    end
    -- Wrap within the counter's bits so ids never bleed into the pid hash
    cnt = bit.band(cnt + 1, cnt_mask)
    return bit.bor(bit.lshift(nvim_pid, 24 - nvim_pid_bits), cnt)
  end
end)()

return M
