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
    local parent = M.dirname(dir)
    if parent == dir then
      return nil
    end

    return parent
  end,
    nil,
    start
end

--- Return the parent directory of the given file or directory
---
---@param file (string) File or directory
---@return (string) Parent directory of {file}
function M.dirname(file)
  return vim.fn.fnamemodify(file, ':h')
end

--- Return the basename of the given file or directory
---
---@param file (string) File or directory
---@return (string) Basename of {file}
function M.basename(file)
  return vim.fn.fnamemodify(file, ':t')
end

--- Return an iterator over the files and directories located in {path}
---
---@param path (string) An absolute or relative path to the directory to iterate
---            over
---@return Iterator over files and directories in {path}. Each iteration yields
---        two values: name and type. Each "name" is the basename of the file or
---        directory relative to {path}. Type is one of "file" or "directory".
function M.dir(path)
  return function(fs)
    return vim.loop.fs_scandir_next(fs)
  end, vim.loop.fs_scandir(path)
end

return M
