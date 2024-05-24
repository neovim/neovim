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

  path = M.normalize(path)
  if not opts.depth or opts.depth == 1 then
    local fs = vim.uv.fs_scandir(path)
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
      local fs = vim.uv.fs_scandir(dir)
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

--- Find the first parent directory containing a specific "marker", relative to a file path or
--- buffer.
---
--- If the buffer is unnamed (has no backing file) or has a non-empty 'buftype' then the search
--- begins from Nvim's |current-directory|.
---
--- Example:
---
--- ```lua
--- -- Find the root of a Python project, starting from file 'main.py'
--- vim.fs.root(vim.fs.joinpath(vim.env.PWD, 'main.py'), {'pyproject.toml', 'setup.py' })
---
--- -- Find the root of a git repository
--- vim.fs.root(0, '.git')
---
--- -- Find the parent directory containing any file with a .csproj extension
--- vim.fs.root(0, function(name, path)
---   return name:match('%.csproj$') ~= nil
--- end)
--- ```
---
--- @param source integer|string Buffer number (0 for current buffer) or file path (absolute or
---               relative to the |current-directory|) to begin the search from.
--- @param marker (string|string[]|fun(name: string, path: string): boolean) A marker, or list
---               of markers, to search for. If a function, the function is called for each
---               evaluated item and should return true if {name} and {path} are a match.
--- @return string? # Directory path containing one of the given markers, or nil if no directory was
---                   found.
function M.root(source, marker)
  assert(source, 'missing required argument: source')
  assert(marker, 'missing required argument: marker')

  local path ---@type string
  if type(source) == 'string' then
    path = source
  elseif type(source) == 'number' then
    if vim.bo[source].buftype ~= '' then
      path = assert(vim.uv.cwd())
    else
      path = vim.api.nvim_buf_get_name(source)
    end
  else
    error('invalid type for argument "source": expected string or buffer number')
  end

  local paths = M.find(marker, {
    upward = true,
    path = vim.fn.fnamemodify(path, ':p:h'),
  })

  if #paths == 0 then
    return nil
  end

  return vim.fs.dirname(paths[1])
end

--- Split a Windows path into a prefix and a body, such that the body can be processed like a POSIX
--- path. The path must use forward slashes as path separator.
---
--- Does not check if the path is a valid Windows path. Invalid paths will give invalid results.
---
--- Examples:
--- - `//./C:/foo/bar` -> `//./C:`, `/foo/bar`
--- - `//?/UNC/server/share/foo/bar` -> `//?/UNC/server/share`, `/foo/bar`
--- - `//./system07/C$/foo/bar` -> `//./system07`, `/C$/foo/bar`
--- - `C:/foo/bar` -> `C:`, `/foo/bar`
--- - `C:foo/bar` -> `C:`, `foo/bar`
---
--- @param path string Path to split.
--- @return string, string, boolean : prefix, body, whether path is invalid.
local function split_windows_path(path)
  local prefix = ''

  --- Match pattern. If there is a match, move the matched pattern from the path to the prefix.
  --- Returns the matched pattern.
  ---
  --- @param pattern string Pattern to match.
  --- @return string|nil Matched pattern
  local function match_to_prefix(pattern)
    local match = path:match(pattern)

    if match then
      prefix = prefix .. match --[[ @as string ]]
      path = path:sub(#match + 1)
    end

    return match
  end

  local function process_unc_path()
    return match_to_prefix('[^/]+/+[^/]+/+')
  end

  if match_to_prefix('^//[?.]/') then
    -- Device paths
    local device = match_to_prefix('[^/]+/+')

    -- Return early if device pattern doesn't match, or if device is UNC and it's not a valid path
    if not device or (device:match('^UNC/+$') and not process_unc_path()) then
      return prefix, path, false
    end
  elseif match_to_prefix('^//') then
    -- Process UNC path, return early if it's invalid
    if not process_unc_path() then
      return prefix, path, false
    end
  elseif path:match('^%w:') then
    -- Drive paths
    prefix, path = path:sub(1, 2), path:sub(3)
  end

  -- If there are slashes at the end of the prefix, move them to the start of the body. This is to
  -- ensure that the body is treated as an absolute path. For paths like C:foo/bar, there are no
  -- slashes at the end of the prefix, so it will be treated as a relative path, as it should be.
  local trailing_slash = prefix:match('/+$')

  if trailing_slash then
    prefix = prefix:sub(1, -1 - #trailing_slash)
    path = trailing_slash .. path --[[ @as string ]]
  end

  return prefix, path, true
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
  local new_path_components = {}

  for component in vim.gsplit(path, '/') do
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

--- @class vim.fs.normalize.Opts
--- @inlinedoc
---
--- Expand environment variables.
--- (default: `true`)
--- @field expand_env? boolean
---
--- @field package _fast? boolean
---
--- Path is a Windows path.
--- (default: `true` in Windows, `false` otherwise)
--- @field win? boolean

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

  if not opts._fast then
    vim.validate({
      path = { path, { 'string' } },
      expand_env = { opts.expand_env, { 'boolean' }, true },
      win = { opts.win, { 'boolean' }, true },
    })
  end

  local win = opts.win == nil and iswin or not not opts.win
  local os_sep_local = win and '\\' or '/'

  -- Empty path is already normalized
  if path == '' then
    return ''
  end

  -- Expand ~ to users home directory
  if vim.startswith(path, '~') then
    local home = vim.uv.os_homedir() or '~'
    if home:sub(-1) == os_sep_local then
      home = home:sub(1, -2)
    end
    path = home .. path:sub(2)
  end

  -- Expand environment variables if `opts.expand_env` isn't `false`
  if opts.expand_env == nil or opts.expand_env then
    path = path:gsub('%$([%w_]+)', vim.uv.os_getenv)
  end

  if win then
    -- Convert path separator to `/`
    path = path:gsub(os_sep_local, '/')
  end

  -- Check for double slashes at the start of the path because they have special meaning
  local double_slash = false
  if not opts._fast then
    double_slash = vim.startswith(path, '//') and not vim.startswith(path, '///')
  end

  local prefix = ''

  if win then
    local is_valid --- @type boolean
    -- Split Windows paths into prefix and body to make processing easier
    prefix, path, is_valid = split_windows_path(path)

    -- If path is not valid, return it as-is
    if not is_valid then
      return prefix .. path
    end

    -- Remove extraneous slashes from the prefix
    prefix = prefix:gsub('/+', '/')
  end

  if not opts._fast then
    -- Resolve `.` and `..` components and remove extraneous slashes from path, then recombine prefix
    -- and path.
    path = path_resolve_dot(path)
  end

  -- Preserve leading double slashes as they indicate UNC paths and DOS device paths in
  -- Windows and have implementation-defined behavior in POSIX.
  path = (double_slash and '/' or '') .. prefix .. path

  -- Change empty path to `.`
  if path == '' then
    path = '.'
  end

  return path
end

return M
