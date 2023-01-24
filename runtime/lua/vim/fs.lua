local M = {}

local iswin = vim.loop.os_uname().sysname == 'Windows_NT'

--- Iterate over all the parents of the given file or directory.
---
--- Example:
--- <pre>lua
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
  vim.validate({ file = { file, 's' } })
  if iswin and file:match('^%w:[\\/]?$') then
    return (file:gsub('\\', '/'))
  elseif not file:match('[\\/]') then
    return '.'
  elseif file == '/' or file:match('^/[^/]+$') then
    return '/'
  end
  local dir = file:match('[/\\]$') and file:sub(1, #file - 1) or file:match('^([/\\]?.+)[/\\]')
  if iswin and dir:match('^%w:$') then
    return dir .. '/'
  end
  return (dir:gsub('\\', '/'))
end

--- Return the basename of the given file or directory
---
---@param file (string) File or directory
---@return (string) Basename of {file}
function M.basename(file)
  if file == nil then
    return nil
  end
  vim.validate({ file = { file, 's' } })
  if iswin and file:match('^%w:[\\/]?$') then
    return ''
  end
  return file:match('[/\\]$') and '' or (file:match('[^\\/]*$'):gsub('\\', '/'))
end

---@private
local function join_paths(...)
  return (table.concat({ ... }, '/'):gsub('//+', '/'))
end

--- Return an iterator over the files and directories located in {path}
---
---@param path (string) An absolute or relative path to the directory to iterate
---            over. The path is first normalized |vim.fs.normalize()|.
--- @param opts table|nil Optional keyword arguments:
---             - depth: integer|nil How deep the traverse (default 1)
---             - skip: (fun(dir_name: string): boolean)|nil Predicate
---               to control traversal. Return false to stop searching the current directory.
---               Only useful when depth > 1
---
---@return Iterator over files and directories in {path}. Each iteration yields
---        two values: name and type. Each "name" is the basename of the file or
---        directory relative to {path}. Type is one of "file" or "directory".
function M.dir(path, opts)
  opts = opts or {}

  vim.validate({
    path = { path, { 'string' } },
    depth = { opts.depth, { 'number' }, true },
    skip = { opts.skip, { 'function' }, true },
  })

  if not opts.depth or opts.depth == 1 then
    return function(fs)
      return vim.loop.fs_scandir_next(fs)
    end,
      vim.loop.fs_scandir(M.normalize(path))
  end

  --- @async
  return coroutine.wrap(function()
    local dirs = { { path, 1 } }
    while #dirs > 0 do
      local dir0, level = unpack(table.remove(dirs, 1))
      local dir = level == 1 and dir0 or join_paths(path, dir0)
      local fs = vim.loop.fs_scandir(M.normalize(dir))
      while fs do
        local name, t = vim.loop.fs_scandir_next(fs)
        if not name then
          break
        end
        local f = level == 1 and name or join_paths(dir0, name)
        coroutine.yield(f, t)
        if
          opts.depth
          and level < opts.depth
          and t == 'directory'
          and (not opts.skip or opts.skip(f) ~= false)
        then
          dirs[#dirs + 1] = { f, level + 1 }
        end
      end
    end
  end)
end

--- Find files or directories in the given path.
---
--- Finds any files or directories given in {names} starting from {path}. If
--- {upward} is "true" then the search traverses upward through parent
--- directories; otherwise, the search traverses downward. Note that downward
--- searches are recursive and may search through many directories! If {stop}
--- is non-nil, then the search stops when the directory given in {stop} is
--- reached. The search terminates when {limit} (default 1) matches are found.
--- The search can be narrowed to find only files or only directories by
--- specifying {type} to be "file" or "directory", respectively.
---
---@param names (string|table|fun(name: string): boolean) Names of the files
---             and directories to find.
---             Must be base names, paths and globs are not supported.
---             The function is called per file and directory within the
---             traversed directories to test if they match {names}.
---
---@param opts (table) Optional keyword arguments:
---                       - path (string): Path to begin searching from. If
---                              omitted, the |current-directory| is used.
---                       - upward (boolean, default false): If true, search
---                                upward through parent directories. Otherwise,
---                                search through child directories
---                                (recursively).
---                       - stop (string): Stop searching when this directory is
---                              reached. The directory itself is not searched.
---                       - type (string): Find only files ("file") or
---                              directories ("directory"). If omitted, both
---                              files and directories that match {names} are
---                              included.
---                       - limit (number, default 1): Stop the search after
---                               finding this many matches. Use `math.huge` to
---                               place no limit on the number of matches.
---@return (table) Normalized paths |vim.fs.normalize()| of all matching files or directories
function M.find(names, opts)
  opts = opts or {}
  vim.validate({
    names = { names, { 's', 't', 'f' } },
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
    local test

    if type(names) == 'function' then
      test = function(p)
        local t = {}
        for name, type in M.dir(p) do
          if names(name) and (not opts.type or opts.type == type) then
            table.insert(t, join_paths(p, name))
          end
        end
        return t
      end
    else
      test = function(p)
        local t = {}
        for _, name in ipairs(names) do
          local f = join_paths(p, name)
          local stat = vim.loop.fs_stat(f)
          if stat and (not opts.type or opts.type == stat.type) then
            t[#t + 1] = f
          end
        end

        return t
      end
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

      for other, type_ in M.dir(dir) do
        local f = join_paths(dir, other)
        if type(names) == 'function' then
          if names(other) and (not opts.type or opts.type == type_) then
            if add(f) then
              return matches
            end
          end
        else
          for _, name in ipairs(names) do
            if name == other and (not opts.type or opts.type == type_) then
              if add(f) then
                return matches
              end
            end
          end
        end

        if type_ == 'directory' then
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
--- Examples:
--- <pre>lua
---   vim.fs.normalize('C:\\\\Users\\\\jdoe')
---   --> 'C:/Users/jdoe'
---
---   vim.fs.normalize('~/src/neovim')
---   --> '/home/jdoe/src/neovim'
---
---   vim.fs.normalize('$XDG_CONFIG_HOME/nvim/init.vim')
---   --> '/Users/jdoe/.config/nvim/init.vim'
--- </pre>
---
---@param path (string) Path to normalize
---@return (string) Normalized path
function M.normalize(path)
  vim.validate({ path = { path, 's' } })
  return (
    path
      :gsub('^~$', vim.loop.os_homedir())
      :gsub('^~/', vim.loop.os_homedir() .. '/')
      :gsub('%$([%w_]+)', vim.loop.os_getenv)
      :gsub('\\', '/')
  )
end

return M
