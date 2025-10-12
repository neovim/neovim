local M = {}

--- Edit a file in a specific window
--- @param winnr number
--- @param file string
--- @return number buffer number of the edited buffer
M.edit_in = function(winnr, file)
  local function resolved_path(path)
    if not path or path == '' then
      return ''
    end
    return vim.fn.resolve(vim.fs.abspath(path))
  end

  return vim.api.nvim_win_call(winnr, function()
    local current_buf = vim.api.nvim_win_get_buf(winnr)
    local current = resolved_path(vim.api.nvim_buf_get_name(current_buf))

    -- Check if the current buffer is already the target file
    if current == resolved_path(file) then
      return current_buf
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
