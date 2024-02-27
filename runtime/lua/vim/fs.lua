local M = {}

local iswin = vim.uv.os_uname().sysname == 'Windows_NT'

--- Iterate over all the parents of the given path.
---
--- Example:
---
--- ```lua
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
--- ```
---
---@param start (string) Initial path.
---@return fun(_, dir: string): string? # Iterator
---@return nil
---@return string|nil
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

--- Return the parent directory of the given path
---
---@param file (string) Path
---@return string|nil Parent directory of {file}
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

--- Return the basename of the given path
---
---@param file string Path
---@return string|nil Basename of {file}
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

--- Concatenate directories and/or file paths into a single path with normalization
--- (e.g., `"foo/"` and `"bar"` get joined to `"foo/bar"`)
---
---@param ... string
---@return string
function M.joinpath(...)
  return (table.concat({ ... }, '/'):gsub('//+', '/'))
end

---@alias Iterator fun(): string?, string?

--- Return an iterator over the items located in {path}
---
---@param path (string) An absolute or relative path to the directory to iterate
---            over. The path is first normalized |vim.fs.normalize()|.
--- @param opts table|nil Optional keyword arguments:
---             - depth: integer|nil How deep the traverse (default 1)
---             - skip: (fun(dir_name: string): boolean)|nil Predicate
---               to control traversal. Return false to stop searching the current directory.
---               Only useful when depth > 1
---
---@return Iterator over items in {path}. Each iteration yields two values: "name" and "type".
---        "name" is the basename of the item relative to {path}.
---        "type" is one of the following:
---        "file", "directory", "link", "fifo", "socket", "char", "block", "unknown".
function M.dir(path, opts)
  opts = opts or {}

  vim.validate({
    path = { path, { 'string' } },
    depth = { opts.depth, { 'number' }, true },
    skip = { opts.skip, { 'function' }, true },
  })

  if not opts.depth or opts.depth == 1 then
    local fs = vim.uv.fs_scandir(M.normalize(path))
    return function()
      if not fs then
        return
      end
      return vim.uv.fs_scandir_next(fs)
    end
  end

  --- @async
  return coroutine.wrap(function()
    local dirs = { { path, 1 } }
    while #dirs > 0 do
      --- @type string, integer
      local dir0, level = unpack(table.remove(dirs, 1))
      local dir = level == 1 and dir0 or M.joinpath(path, dir0)
      local fs = vim.uv.fs_scandir(M.normalize(dir))
      while fs do
        local name, t = vim.uv.fs_scandir_next(fs)
        if not name then
          break
        end
        local f = level == 1 and name or M.joinpath(dir0, name)
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

--- @class vim.fs.find.Opts
--- @inlinedoc
---
--- Path to begin searching from. If
--- omitted, the |current-directory| is used.
--- @field path string
---
--- Search upward through parent directories.
--- Otherwise, search through child directories (recursively).
--- (default: `false`)
--- @field upward boolean
---
--- Stop searching when this directory is reached.
--- The directory itself is not searched.
--- @field stop string
---
--- Find only items of the given type.
--- If omitted, all items that match {names} are included.
--- @field type string
---
--- Stop the search after finding this many matches.
--- Use `math.huge` to place no limit on the number of matches.
--- (default: `1`)
--- @field limit number

--- Find files or directories (or other items as specified by `opts.type`) in the given path.
---
--- Finds items given in {names} starting from {path}. If {upward} is "true"
--- then the search traverses upward through parent directories; otherwise,
--- the search traverses downward. Note that downward searches are recursive
--- and may search through many directories! If {stop} is non-nil, then the
--- search stops when the directory given in {stop} is reached. The search
--- terminates when {limit} (default 1) matches are found. You can set {type}
--- to "file", "directory", "link", "socket", "char", "block", or "fifo"
--- to narrow the search to find only that type.
---
--- Examples:
---
--- ```lua
--- -- location of Cargo.toml from the current buffer's path
--- local cargo = vim.fs.find('Cargo.toml', {
---   upward = true,
---   stop = vim.uv.os_homedir(),
---   path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
--- })
---
--- -- list all test directories under the runtime directory
--- local test_dirs = vim.fs.find(
---   {'test', 'tst', 'testdir'},
---   {limit = math.huge, type = 'directory', path = './runtime/'}
--- )
---
--- -- get all files ending with .cpp or .hpp inside lib/
--- local cpp_hpp = vim.fs.find(function(name, path)
---   return name:match('.*%.[ch]pp$') and path:match('[/\\\\]lib$')
--- end, {limit = math.huge, type = 'file'})
--- ```
---
---@param names (string|string[]|fun(name: string, path: string): boolean) Names of the items to find.
---             Must be base names, paths and globs are not supported when {names} is a string or a table.
---             If {names} is a function, it is called for each traversed item with args:
---             - name: base name of the current item
---             - path: full path of the current item
---             The function should return `true` if the given item is considered a match.
---
---@param opts vim.fs.find.Opts Optional keyword arguments:
---@return (string[]) # Normalized paths |vim.fs.normalize()| of all matching items
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

  if type(names) == 'string' then
    names = { names }
  end

  local path = opts.path or vim.uv.cwd()
  local stop = opts.stop
  local limit = opts.limit or 1

  local matches = {} --- @type string[]

  local function add(match)
    matches[#matches + 1] = M.normalize(match)
    if #matches == limit then
      return true
    end
  end

  if opts.upward then
    local test --- @type fun(p: string): string[]

    if type(names) == 'function' then
      test = function(p)
        local t = {}
        for name, type in M.dir(p) do
          if (not opts.type or opts.type == type) and names(name, p) then
            table.insert(t, M.joinpath(p, name))
          end
        end
        return t
      end
    else
      test = function(p)
        local t = {} --- @type string[]
        for _, name in ipairs(names) do
          local f = M.joinpath(p, name)
          local stat = vim.uv.fs_stat(f)
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
        local f = M.joinpath(dir, other)
        if type(names) == 'function' then
          if (not opts.type or opts.type == type_) and names(other, dir) then
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

--- @class vim.fs.normalize.Opts
--- @inlinedoc
---
--- Expand environment variables.
--- (default: `true`)
--- @field expand_env boolean

--- Normalize a path to a standard format. A tilde (~) character at the
--- beginning of the path is expanded to the user's home directory and any
--- backslash (\) characters are converted to forward slashes (/). Environment
--- variables are also expanded.
---
--- Examples:
---
--- ```lua
--- vim.fs.normalize('C:\\\\Users\\\\jdoe')
--- -- 'C:/Users/jdoe'
---
--- vim.fs.normalize('~/src/neovim')
--- -- '/home/jdoe/src/neovim'
---
--- vim.fs.normalize('$XDG_CONFIG_HOME/nvim/init.vim')
--- -- '/Users/jdoe/.config/nvim/init.vim'
--- ```
---
---@param path (string) Path to normalize
---@param opts? vim.fs.normalize.Opts
---@return (string) : Normalized path
function M.normalize(path, opts)
  opts = opts or {}

  vim.validate({
    path = { path, { 'string' } },
    expand_env = { opts.expand_env, { 'boolean' }, true },
  })

  if path:sub(1, 1) == '~' then
    local home = vim.uv.os_homedir() or '~'
    if home:sub(-1) == '\\' or home:sub(-1) == '/' then
      home = home:sub(1, -2)
    end
    path = home .. path:sub(2)
  end

  if opts.expand_env == nil or opts.expand_env then
    path = path:gsub('%$([%w_]+)', vim.uv.os_getenv)
  end

  path = path:gsub('\\', '/'):gsub('/+', '/')
  if iswin and path:match('^%w:/$') then
    return path
  end
  return (path:gsub('(.)/$', '%1'))
end

return M
