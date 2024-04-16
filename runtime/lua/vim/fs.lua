local M = {}

local iswin = vim.uv.os_uname().sysname == 'Windows_NT'
local os_sep = iswin and '\\' or '/'

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
---@generic T : string|nil
---@param file T Path
---@return T Parent directory of {file}
function M.dirname(file)
  if file == nil then
    return nil
  end
  vim.validate({ file = { file, 's' } })
  if iswin then
    file = file:gsub(os_sep, '/') --[[@as string]]
    if file:match('^%w:/?$') then
      return file
    end
  end
  if not file:match('/') then
    return '.'
  elseif file == '/' or file:match('^/[^/]+$') then
    return '/'
  end
  ---@type string
  local dir = file:match('/$') and file:sub(1, #file - 1) or file:match('^(/?.+)/')
  if iswin and dir:match('^%w:$') then
    return dir .. '/'
  end
  return dir
end

--- Return the basename of the given path
---
---@generic T : string|nil
---@param file T Path
---@return T Basename of {file}
function M.basename(file)
  if file == nil then
    return nil
  end
  vim.validate({ file = { file, 's' } })
  if iswin then
    file = file:gsub(os_sep, '/') --[[@as string]]
    if file:match('^%w:/?$') then
      return ''
    end
  end
  return file:match('/$') and '' or (file:match('[^/]*$'))
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
--- @field path? string
---
--- Search upward through parent directories.
--- Otherwise, search through child directories (recursively).
--- (default: `false`)
--- @field upward? boolean
---
--- Stop searching when this directory is reached.
--- The directory itself is not searched.
--- @field stop? string
---
--- Find only items of the given type.
--- If omitted, all items that match {names} are included.
--- @field type? string
---
--- Stop the search after finding this many matches.
--- Use `math.huge` to place no limit on the number of matches.
--- (default: `1`)
--- @field limit? number

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

  local path = opts.path or assert(vim.uv.cwd())
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

--- Split a Windows path into a prefix and a body, such that the body can be processed like a POSIX
--- path.
---
--- Does not check if the path is a valid Windows path. Invalid paths will give invalid results.
---
--- Examples:
--- - `\\.\C:\foo\bar` -> `\\.\C:`, `\foo\bar`
--- - `//?/UNC/server/share/foo/bar` -> `//?/UNC/server/share`, `/foo/bar`
--- - `\\.\system07\C$\foo\bar` -> `\\.\system07`, `\C$\foo\bar`
--- - `C:/foo/bar` -> `C:`, `/foo/bar`
--- - `C:foo/bar` -> `C:`, `foo/bar`
---
--- @param path string Path to split.
--- @return string, string : prefix, body
local function split_windows_path(path)
  local prefix = ''

  --- Match pattern. If there is a match, move the matched pattern from the path to the prefix.
  --- Returns the matched pattern.
  ---
  --- @param pattern string Pattern to match.
  --- @param nomatch_error string? Error message if the pattern doesn't match.
  --- @return string|nil Matched pattern
  local function match_to_prefix(pattern, nomatch_error)
    local match = path:match(pattern)

    if match then
      prefix = prefix .. match --[[ @as string ]]
      path = path:sub(#match + 1)
    elseif nomatch_error then
      error(nomatch_error)
    end

    return match
  end

  local function process_unc_path()
    match_to_prefix('[^/\\]+[/\\]+[^/\\]+[/\\]+', 'Invalid Windows UNC path')
  end

  if match_to_prefix('^//[?.]/') then
    -- Device paths
    local device = match_to_prefix('[^/\\]+[/\\]+', 'Invalid Windows device path')

    if device:match('^UNC[/\\]+$') then
      process_unc_path()
    end
  elseif match_to_prefix('^[/\\][/\\]') then
    -- UNC paths
    process_unc_path()
  elseif path:match('^%w:') then
    -- Drive paths
    prefix, path = path:sub(1, 2), path:sub(3)
  end

  -- If there are slashes at the end of the prefix, move them to the start of the body. This is to
  -- ensure that the body is treated as an absolute path. For paths like C:foo/bar, there are no
  -- slashes at the end of the prefix, so it will be treated as a relative path, as it should be.
  local trailing_slash = prefix:match('[/\\]+$')

  if trailing_slash then
    prefix = prefix:sub(1, -1 - #trailing_slash)
    path = trailing_slash .. path --[[ @as string ]]
  end

  return prefix, path
end

--- Resolve `.` and `..` components in a POSIX-style path. This also removes extraneous slashes.
--- `..` is not resolved if the path is relative and resolving it requires the path to be absolute.
--- If a relative path resolves to the current directory, an empty string is returned.
---
--- @see M.normalize()
--- @param path string Path to resolve.
--- @return string Resolved path.
local function path_resolve_dot(path)
  local is_path_absolute = vim.startswith(path, '/')
  -- Split the path into components and process them
  local path_components = vim.split(path, '/')
  local new_path_components = {}

  for _, component in ipairs(path_components) do
    if component == '.' or component == '' then -- luacheck: ignore 542
      -- Skip `.` components and empty components
    elseif component == '..' then
      if #new_path_components > 0 and new_path_components[#new_path_components] ~= '..' then
        -- For `..`, remove the last component if we're still inside the current directory, except
        -- when the last component is `..` itself
        table.remove(new_path_components)
      elseif is_path_absolute then -- luacheck: ignore 542
        -- Reached the root directory in absolute path, do nothing
      else
        -- Reached current directory in relative path, add `..` to the path
        table.insert(new_path_components, component)
      end
    else
      table.insert(new_path_components, component)
    end
  end

  return (is_path_absolute and '/' or '') .. table.concat(new_path_components, '/')
end

--- Expand tilde (~) character at the beginning of the path to the user's home directory.
---
--- @param path string Path to expand.
--- @return string Expanded path.
local function expand_home(path)
  if vim.startswith(path, '~') then
    local home = vim.uv.os_homedir() or '~'

    if home:sub(-1) == os_sep then
      home = home:sub(1, -2)
    end

    path = home .. path:sub(2)
  end

  return path
end

--- @class vim.fs.normalize.Opts
--- @inlinedoc
---
--- Expand environment variables.
--- (default: `true`)
--- @field expand_env boolean

--- Normalize a path to a standard format. A tilde (~) character at the beginning of the path is
--- expanded to the user's home directory and environment variables are also expanded. "." and ".."
--- components are also resolved, except when the path is relative and trying to resolve it would
--- result in an absolute path.
--- - "." as the only part in a relative path:
---   - "." => "."
---   - "././" => "."
--- - ".." when it leads outside the current directory
---   - "foo/../../bar" => "../bar"
---   - "../../foo" => "../../foo"
--- - ".." in the root directory returns the root directory.
---   - "/../../" => "/"
---
--- On Windows, backslash (\) characters are converted to forward slashes (/).
---
--- Examples:
--- ```lua
--- [[C:\Users\jdoe]]                         => "C:/Users/jdoe"
--- "~/src/neovim"                            => "/home/jdoe/src/neovim"
--- "$XDG_CONFIG_HOME/nvim/init.vim"          => "/Users/jdoe/.config/nvim/init.vim"
--- "~/src/nvim/api/../tui/./tui.c"           => "/home/jdoe/src/nvim/tui/tui.c"
--- "./foo/bar"                               => "foo/bar"
--- "foo/../../../bar"                        => "../../bar"
--- "/home/jdoe/../../../bar"                 => "/bar"
--- "C:foo/../../baz"                         => "C:../baz"
--- "C:/foo/../../baz"                        => "C:/baz"
--- [[\\?\UNC\server\share\foo\..\..\..\bar]] => "//?/UNC/server/share/bar"
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

  -- Empty path is already normalized
  if path == '' then
    return ''
  end

  -- Expand ~ to user's home directory
  path = expand_home(path)

  -- Expand environment variables if `opts.expand_env` isn't `false`
  if opts.expand_env == nil or opts.expand_env then
    path = path:gsub('%$([%w_]+)', vim.uv.os_getenv)
  end

  -- Convert path separator to `/`
  path = path:gsub(os_sep, '/')

  -- Check for double slashes at the start of the path because they have special meaning
  local double_slash = vim.startswith(path, '//') and not vim.startswith(path, '///')
  local prefix = ''

  if iswin then
    -- Split Windows paths into prefix and body to make processing easier
    prefix, path = split_windows_path(path)
    -- Remove extraneous slashes from the prefix
    prefix = prefix:gsub('/+', '/')
  end

  -- Resolve `.` and `..` components and remove extraneous slashes from path, then recombine prefix
  -- and path. Preserve leading double slashes as they indicate UNC paths and DOS device paths in
  -- Windows and have implementation-defined behavior in POSIX.
  path = (double_slash and '/' or '') .. prefix .. path_resolve_dot(path)

  -- Change empty path to `.`
  if path == '' then
    path = '.'
  end

  return path
end

--- @class vim.fs.abspath.Opts
--- @inlinedoc
---
--- Current working directory to use as the base for the relative path.
--- This option is ignored for C:foo\bar style paths on Windows, as those paths use the current
--- directory of the drive specified in the path.
--- (default: |current-directory|)
--- @field cwd? string

--- Convert path to an absolute path. A tilde (~) character at the beginning of the path is expanded
--- to the user's home directory. Does not check if the path exists, normalize the path, resolve
--- symlinks or hardlinks (including `.` and `..`), or expand environment variables. If the path is
--- already absolute, it is returned unchanged.
---
--- @param path string Path
--- @param opts vim.fs.abspath.Opts? Optional keyword arguments:
--- @return string Absolute path
function M.abspath(path, opts)
  opts = opts or {}

  vim.validate({
    path = { path, { 'string' } },
    cwd = { opts.cwd, { 'string' }, true },
  })

  -- Expand ~ to user's home directory
  path = expand_home(path)

  local prefix = ''

  if iswin then
    prefix, path = split_windows_path(path)
  end

  if vim.startswith(path, '/') or (iswin and vim.startswith(path, '\\')) then
    -- Path is already absolute, do nothing
    return prefix .. path
  end

  local cwd --- @type string

  -- Windows allows paths like C:foo\bar, these paths are relative to the current working directory
  -- of the drive specified in the path, we ignore `opts.cwd` for these paths.
  if iswin and prefix:match('^%w:$') then
    cwd = vim._fs_get_drive_cwd(prefix) --[[@as string]]
  else
    cwd = opts.cwd or vim.uv.cwd() --[[@as string]]
  end

  -- Prefix is not needed for relative paths
  return M.joinpath(cwd, path)
end

--- @class vim.fs.mkdir.Opts
--- @inlinedoc
---
--- Recursively create parent directories if they don't exist.
--- (default: `false`)
--- @field parents? boolean

--- Create a directory at the given path. Does nothing if the path already exists.
---
--- @param path string Path of the directory to create.
--- @param opts vim.fs.mkdir.Opts? Optional keyword arguments:
function M.mkdir(path, opts)
  opts = opts or {}

  vim.validate({
    path = { path, { 'string' } },
    parents = { opts.parents, { 'boolean' }, true },
  })

  -- Get normalized absolute path to make it easier to process
  path = M.normalize(M.abspath(path))

  local path_exists = vim.uv.fs_stat(path) ~= nil

  if path_exists then
    return
  end

  local parent = M.dirname(path)
  local parent_exists = vim.uv.fs_stat(parent) ~= nil

  if not parent_exists and not opts.parents then
    error(string.format("Failed to create directory '%s': Parent directory does not exist", path))
  elseif not parent_exists then
    -- Get a list of parent directories, then iterate in reverse to create each directory.
    local ancestors = vim.iter(M.parents(path)):totable() --- @type string[]

    for i = #ancestors, 1, -1 do
      local ancestor = ancestors[i]

      if vim.uv.fs_stat(ancestor) == nil then
        vim.uv.fs_mkdir(ancestor, 493) -- decimal equivalent of 0755
      end
    end
  end

  assert(vim.uv.fs_stat(parent) ~= nil)
  vim.uv.fs_mkdir(path, 493) -- decimal equivalent of 0755
end

return M
