local M = {}

--- Iterate over all the parents of the given file or directory.
---
--- Example:
--- <pre>
--- local root_dir
--- for dir in vim.fs.parents(vim.api.nvim_buf_get_name(0)) do
---   if vim.fn.isdirectory(dir .. "/.git") == 1 then
---     root_dir = dir
---     break
---   end
--- end
---
--- if root_dir then
---   print("Found git repository at", root_dir)
--- end
--- </pre>
---
---@param start (string) Initial file or directory.
---@return (function) Iterator
function M.parents(start)
  return function(_, dir)
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      return nil
    end

    return parent
  end,
    nil,
    start
end

return M
