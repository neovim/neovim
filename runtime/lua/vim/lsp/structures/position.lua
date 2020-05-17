local api = vim.api

local Position = {}

--- Get {row, col} from a position, accounting for multi-byte characters on the line.
Position.to_pos = function(position, bufnr)
  local row = position.line
  local col = position.character

  if col > 0 and bufnr then
    local line = api.nvim_buf_get_lines(bufnr, row, row+1, false)[1]

    if line then
      local ok, result = pcall(function()
        return vim.str_byteindex(line, col)
      end)
      if ok then
        col = result
      end
    end
  end

  return {row, col}
end

return Position
