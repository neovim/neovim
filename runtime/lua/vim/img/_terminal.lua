---@class vim.img.terminal
---@field private __tty_name string
local M = {}

local TERM_CODE = {
  BEL = "\x07", -- aka ^G
  ESC = "\x1B", -- aka ^[ aka \033
}

---Retrieve the tty name used by the editor.
---
---E.g. /dev/ttys008
---@return string|nil
local function get_tty_name()
  -- Leverage tty, which reads the terminal name
  local handle = io.popen("tty 2>/dev/null")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  result = vim.fn.trim(result)
  if result == "" then return nil end
  return result
end

---Returns the name of the tty associated with the terminal.
---@return string
function M.tty_name()
  if not M.__tty_name then
    M.__tty_name = assert(get_tty_name(), "failed to read editor tty name")
  end

  return M.__tty_name
end

---Writes data to the editor tty.
---@param ... string|number
function M.write(...)
  local handle = io.open(M.tty_name(), "w")
  if not handle then
    error("failed to open " .. M.tty_name())
  end
  handle:write(...)
  handle:close()
end

---@class vim.img.terminal.cursor
M.cursor = {}

---@param x integer
---@param y integer
---@param save? boolean
function M.cursor.move(x, y, save)
  if save then M.cursor.save() end
  M.write(TERM_CODE.ESC .. "[" .. y .. ";" .. x .. "H")
  vim.uv.sleep(1)
end

function M.cursor.save()
  M.write(TERM_CODE.ESC .. "[s")
end

function M.cursor.restore()
  M.write(TERM_CODE.ESC .. "[u")
end

---Terminal escape codes.
M.code = TERM_CODE

return M
