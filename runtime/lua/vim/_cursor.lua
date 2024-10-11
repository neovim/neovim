--- All function(s) that can be called externally by other Lua modules.
---
--- If a function's signature here changes in some incompatible way, this
--- package must get a new **major** version.
---
---@module 'vim._cursor'
---

local M = {}

local _Direction = { down = 'down', up = 'up' }

---@class vim._cursor.Options
---    Describe which way to adjust the cursor and how.
---@field count number
---    The number of times to call the command. Usually is just `1`.
---@field direction "down" | "up"
---    Which way to crop the text object. "up" means "operate from the cursor's
---    position to the up/left-most position" and "down" means "operate from
---    the cursor's position (including the cursor's current line, if
---    applicable) to the down/right-most position".

local _CURSOR
---@type string
local _DIRECTION
---@type string
local _OPERATOR
---@type string
local _OPERATOR_FUNCTION

--- Check if the operatorfunc that is running will run on a whole-line.
---
--- See Also:
---     :help g@
---
---@param mode "block" | "char" | "line"
---@return boolean # If `mode` is meant to run on the full-line (ignores column data).
---
local function _is_line_mode(mode)
  return mode == 'line'
end

--- Execute the original operatorfunc but crop it based on the cursor position.
---
--- Important:
---     You must call `prepare()` once before this function can be called.
---
---@param mode "block" | "char" | "line"
---    The caller context. See `:help :map-operator` for details.
---
function M.operatorfunc(mode)
  vim.fn.setpos('.', _CURSOR)
  vim.o.operatorfunc = _OPERATOR_FUNCTION
  ---@type string
  local mode_character
  local is_line = _is_line_mode(mode)

  if is_line then
    mode_character = "'" -- Includes only line information
  else
    mode_character = '`' -- Includes column information
  end

  ---@type string
  local direction
  local inclusive_toggle = ''

  if _DIRECTION == _Direction.up then
    direction = '['

    if not is_line then
      local buffer, row, column, offset = unpack(vim.fn.getpos("'" .. direction))
      ---@cast row number

      if column > #vim.fn.getline(row) then
        row = row + 1
        column = 0
      end

      vim.fn.setpos("'" .. direction, { buffer, row, column, offset })
    end
  else
    direction = ']'

    local buffer, row, column, offset = unpack(vim.fn.getpos("'" .. direction))
    ---@cast row number

    if not is_line and column == #vim.fn.getline(row) then
      -- NOTE: Move the mark past the current cursor column
      inclusive_toggle = 'v'
    else
      vim.fn.setpos("'" .. direction, { buffer, row, column + 1, offset })
    end
  end

  vim.fn.feedkeys(_OPERATOR .. inclusive_toggle .. mode_character .. direction)
end

--- Remember anything that we will need to recall once we execute `operatorfunc`.
---
---@param options vim._cursor.Options
---    Mapping data that must be remembered before `operatorfunc` is called.
---
function M.prepare(options)
  _DIRECTION = options.direction
  _OPERATOR = vim.v.operator
  _CURSOR = vim.fn.getpos('.')
  _OPERATOR_FUNCTION = vim.o.operatorfunc
end

return M
