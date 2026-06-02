---@brief
--- Unlike `vim.pos`, this module is used to provide utility functions
--- for unpacked `row`, `col`.
---
--- The variable names have some implications:
---
--- - `row`  is used to represent a 0-based index of a line.
--- - `lnum` is used to represent a 1-based index of a line, short for "line number".

local api = vim.api

local M = {}

---@param a_row integer
---@param a_col integer
---@param b_row integer
---@param b_col integer
---@return integer
--- 1: a > b
--- 0: a == b
--- -1: a < b
local function cmp_pos(a_row, a_col, b_row, b_col)
  if a_row == b_row then
    if a_col > b_col then
      return 1
    elseif a_col < b_col then
      return -1
    else
      return 0
    end
  elseif a_row > b_row then
    return 1
  end

  return -1
end

---@type table<'lt'|'le'|'gt'|'ge'|'eq'|'ne', fun(a_row: integer, a_col: integer, b_row: integer, b_col: integer): boolean>
M.cmp_pos = {
  lt = function(...)
    return cmp_pos(...) == -1
  end,
  le = function(...)
    return cmp_pos(...) ~= 1
  end,
  gt = function(...)
    return cmp_pos(...) == 1
  end,
  ge = function(...)
    return cmp_pos(...) ~= -1
  end,
  eq = function(...)
    return cmp_pos(...) == 0
  end,
  ne = function(...)
    return cmp_pos(...) ~= 0
  end,
}

setmetatable(M.cmp_pos, { __call = cmp_pos })

--- Gets the zero-indexed lines from the given buffer.
--- Works on unloaded buffers by reading the file and bypass buf reading events.
--- Falls back to loading the buffer and nvim_buf_get_lines for buffers with non-file URI.
---
---@param buf integer buffer handle to get the lines from
---@param rows integer[] zero-indexed line numbers
---@return table<integer, string> # a table mapping rows to lines
function M.get_lines(buf, rows)
  local function buf_lines()
    local row_line = {} --- @type table<integer,string>
    for _, row in ipairs(rows) do
      row_line[row] = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    end
    return row_line
  end

  -- Use loaded buffers if available.
  if vim.fn.bufloaded(buf) == 1 then
    return buf_lines()
  end

  -- Load the buffer if this is not a file URI.
  -- Custom language server protocol extensions can result in servers sending
  -- URIs with custom schemes. Plugins are able to load these via `BufReadCmd` autocmds.
  if not vim.startswith(vim.uri_from_bufnr(buf), 'file://') then
    vim.fn.bufload(buf)
    return buf_lines()
  end

  local row_line = {} --- @type table<integer, string>
  for _, row in pairs(rows) do
    row_line[row] = ''
  end

  -- Get the data from the file.
  local success, data = pcall(vim.fn.readblob, vim.api.nvim_buf_get_name(buf))
  if not success then
    return row_line
  end

  local need = vim.tbl_count(row_line)
  local row = 0
  for line in string.gmatch(data, '([^\n]*)\n?') do
    if row_line[row] then
      row_line[row] = line
      need = need - 1
      if need == 0 then
        break
      end
    end
    row = row + 1
  end
  return row_line
end

--- Gets the zero-indexed line from the given buffer.
--- Works on unloaded buffers by reading the file and bypass buf reading events.
--- Falls back to loading the buffer and nvim_buf_get_lines for buffers with non-file URI.
---
---@param buf integer buffer handle to get the lines from
---@param row integer zero-indexed line number
---@return string the line at row in filename
function M.get_line(buf, row)
  return M.get_lines(buf, { row })[row]
end

---@param buf integer
---@param row integer
---@param col integer
---@param position_encoding lsp.PositionEncodingKind
function M.to_lsp(buf, row, col, position_encoding)
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then
    col = vim.str_utfindex(M.get_line(buf, row), position_encoding, col, false)
  elseif col == 0 and row == api.nvim_buf_line_count(buf) and not vim.bo[buf].endofline then
    -- Some LSP servers reject ranges that end at the virtual EOF position
    -- (i.e., `[line_count, 0]`) when the buffer has no trailing newline.
    -- Normalize such positions to the end of the last real line instead.
    row = row - 1
    col = vim.str_utfindex(M.get_line(buf, row), position_encoding)
  end
  ---@type lsp.Position
  return { line = row, character = col }
end

---@param buf integer
---@param position lsp.Position
---@param position_encoding lsp.PositionEncodingKind
function M.from_lsp(buf, position, position_encoding)
  local row, col = position.line, position.character
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then
    -- `strict_indexing` is disabled, because LSP responses are asynchronous,
    -- and the buffer content may have changed, causing out-of-bounds errors.
    col = vim.str_byteindex(M.get_line(buf, row), position_encoding, col, false)
  end
  return row, col
end

---@param row integer
---@param col integer
---@return integer lnum, integer col
function M.to_mark(row, col)
  return row + 1, col
end

---@param lnum integer
---@param col integer
---@return integer row, integer col
function M.from_mark(lnum, col)
  return lnum - 1, col
end

return M
