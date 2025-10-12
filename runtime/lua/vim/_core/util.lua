local M = {}

--- Edit a file in a specific window
--- @param winnr number
--- @param file string
--- @return number buffer number of the edited buffer
M.edit_in = function(winnr, file)
  return vim.api.nvim_win_call(winnr, function()
    local current = vim.fs.abspath(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winnr)))

    -- Check if the current buffer is already the target file
    if current == (file and vim.fs.abspath(file) or '') then
      return vim.api.nvim_get_current_buf()
    end

    -- Read the file into the buffer
    vim.cmd.edit(vim.fn.fnameescape(file))
    return vim.api.nvim_get_current_buf()
  end)
end

--- Read a chunk of data from a file
--- @param file string
--- @param size number
--- @return string? chunk or nil on error
function M.read_chunk(file, size)
  local fd = io.open(file, 'rb')
  if not fd then
    return nil
  end
  local chunk = fd:read(size)
  fd:close()
  return tostring(chunk)
end

return M
