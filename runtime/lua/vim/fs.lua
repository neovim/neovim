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
  if file == nil then
    return nil
  end
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
---            over. The path is first normalized |vim.fs.normalize()|.
---@return Iterator over files and directories in {path}. Each iteration yields
---        two values: name and type. Each "name" is the basename of the file or
---        directory relative to {path}. Type is one of "file" or "directory".
function M.dir(path)
  return function(fs)
    return vim.loop.fs_scandir_next(fs)
  end,
    vim.loop.fs_scandir(M.normalize(path))
end

--- Find files or directories in the given path.
---
--- Finds any files or directories given in {names} starting from {path}. If
--- {upward} is "true" then the search traverses upward through parent
--- directories; otherwise, the search traverses downward. Note that downward
--- searches are recursive and may search through many directories! If {stop}
--- is non-nil, then the search stops when the directory given in {stop} is
--- reached. The search terminates when {limit} (default 1) matches are found.
--- The search can be narrowed to find only files or or only directories by
--- specifying {type} to be "file" or "directory", respectively.
---
---@param names (string|table) Names of the files and directories to find. Must
---             be base names, paths and globs are not supported.
---@param opts (table) Optional keyword arguments:
---                       - path (string): Path to begin searching from. If
---                              omitted, the current working directory is used.
---                       - upward (boolean, default false): If true, search
---                                upward through parent directories. Otherwise,
---                                search through child directories
---                                (recursively).
---                       - stop (string): Stop searching when this directory is
---                              reached. The directory itself is not searched.
---                       - type (string): Find only files ("file") or
---                              directories ("directory"). If omitted, both
---                              files and directories that match {name} are
---                              included.
---                       - limit (number, default 1): Stop the search after
---                               finding this many matches. Use `math.huge` to
---                               place no limit on the number of matches.
---@return (table) The paths of all matching files or directories
function M.find(names, opts)
  opts = opts or {}
  vim.validate({
    names = { names, { 's', 't' } },
    path = { opts.path, 's', true },
    upward = { opts.upward, 'b', true },
    stop = { opts.stop, 's', true },
    type = { opts.type, 's', true },
    limit = { opts.limit, 'n', true },
  })

  names = type(names) == 'string' and { names } or names

  local path = opts.path or vim.loop.cwd()
  local stop = opts.stop
  local limit = opts.limit or 1

  local matches = {}

  ---@private
  local function add(match)
    matches[#matches + 1] = match
    if #matches == limit then
      return true
    end
  end

  if opts.upward then
    ---@private
    local function test(p)
      local t = {}
      for _, name in ipairs(names) do
        local f = p .. '/' .. name
        local stat = vim.loop.fs_stat(f)
        if stat and (not opts.type or opts.type == stat.type) then
          t[#t + 1] = f
        end
      end

      return t
    end

    for _, match in ipairs(test(path)) do
      if add(match) then
        return matches
      end
    end

    for parent in M.parents(path) do
      if stop and parent == stop then
        break
      end

      for _, match in ipairs(test(parent)) do
        if add(match) then
          return matches
        end
      end
    end
  else
    local dirs = { path }
    while #dirs > 0 do
      local dir = table.remove(dirs, 1)
      if stop and dir == stop then
        break
      end

      for other, type in M.dir(dir) do
        local f = dir .. '/' .. other
        for _, name in ipairs(names) do
          if name == other and (not opts.type or opts.type == type) then
            if add(f) then
              return matches
            end
          end
        end

        if type == 'directory' then
          dirs[#dirs + 1] = f
        end
      end
    end
  end

  return matches
end

--- Normalize a path to a standard format. A tilde (~) character at the
--- beginning of the path is expanded to the user's home directory and any
--- backslash (\\) characters are converted to forward slashes (/). Environment
--- variables are also expanded.
---
--- Example:
--- <pre>
--- vim.fs.normalize('C:\\Users\\jdoe')
--- => 'C:/Users/jdoe'
---
--- vim.fs.normalize('~/src/neovim')
--- => '/home/jdoe/src/neovim'
---
--- vim.fs.normalize('$XDG_CONFIG_HOME/nvim/init.vim')
--- => '/Users/jdoe/.config/nvim/init.vim'
--- </pre>
---
---@param path (string) Path to normalize
---@return (string) Normalized path
function M.normalize(path)
  vim.validate({ path = { path, 's' } })
  return (path:gsub('^~/', vim.env.HOME .. '/'):gsub('%$([%w_]+)', vim.env):gsub('\\', '/'))
end

return M
