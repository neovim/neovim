local M = {}

--- Returns the project context file path
--- The context file is stored in the project's `.nvim/data/project-kvstore.json` file.
local function get_context_file()
  return vim.fs.joinpath(vim.project.get_data_dir(0, 'data'), 'project-kvstore.json')
end

--- Writes the context data to the project context file in json format
local function write_context_file(data)
  vim.validate('data', data, 'table')
  local context_file = get_context_file()
  local file = vim.uv.fs_open(context_file, 'w', 384) -- 384 is 0600 in octal
  if not file then
    vim.notify('Failed to open project context file for writing', vim.log.levels.ERROR)
    return nil
  end
  vim.uv.fs_write(file, vim.json.encode(data))
  vim.uv.fs_close(file)
end

--- Gets the project context data from the project context file
--- If the file does not exist or is empty, it returns an empty table.
--- If a key is provided, it returns the value for that key, or nil if the key does not exist.
--- If no key is provided, it returns the entire context data as a table.
--- @param key string|nil The key to retrieve from the context data. If nil, returns the entire context data.
--- @return table|nil The context data as a table, or nil if the key does not exist.
function M.get_context(key)
  vim.validate('key', key, function(v)
    return v == nil or (type(v) == 'string' and v ~= '')
  end)

  local context_file = get_context_file()
  if not vim.uv.fs_stat(context_file) then
    return key == nil and {} or nil
  end

  local file = vim.uv.fs_open(context_file, 'r', 384) -- 384 is 0600 in octal
  if not file then
    vim.notify('Failed to open project context file for reading', vim.log.levels.ERROR)
    return key == nil and {} or nil
  end

  local data = vim.uv.fs_read(file, vim.uv.fs_fstat(file).size)
  vim.uv.fs_close(file)
  if not data or data == '' then
    vim.notify('Failed to read from project context file', vim.log.levels.ERROR)
    return key == nil and {} or nil
  end
  local ok, context_data = pcall(vim.json.decode, data)
  if not ok then
    vim.notify('Failed to decode json from project context file', vim.log.levels.ERROR)
    return key == nil and {} or nil
  end

  if key then
    return context_data[key]
  end
  return context_data
end

--- Sets the project context data for a given key or the entire context data.
--- If the key is provided, it updates the value for that key.
--- If the key is nil, it replaces the entire context data with the provided value.
--- @param key string|nil The key to set in the context data. If nil, it sets the entire context data.
--- @param value any The value to set for the key.
--- @return table The updated context data as a table.
function M.set_context(key, value)
  vim.validate('key', key, function(v)
    return v == nil or (type(v) == 'string' and v ~= '')
  end)
  local context_data = M.get_context()
  if key then
    context_data[key] = value
  else
    context_data = value
  end

  write_context_file(context_data)
  return context_data
end

--- Deletes a key from the project context data or clears the entire context data if no key is provided.
--- @param key string|nil The key to delete from the context data. If nil, it clears the entire context data.
--- @return nil
function M.del_context(key)
  vim.validate('key', key, function(v)
    return v == nil or (type(v) == 'string' and v ~= '')
  end)

  local context_data = M.get_context()
  if key then
    if context_data and context_data[key] then
      context_data[key] = nil
    end
  else
    context_data = {}
  end

  write_context_file(context_data)
end

--- Checks if a file or directory is excluded based on the provided exclude patterns.
local function is_excluded(exclude_patterns, path)
  --- TODO: implement file/folder exclusion
  return false
end

--- Traverses the directory recursively and collects files and directories based on the provided options.
--- @param opts table Options for traversal
--- @param dir string The directory to start traversing from
--- @param depth number The current depth in the directory tree
--- @param files table The table to collect files and directories
--- @return table A table containing the collected files and directories
local function traverse_directory(opts, dir, depth, files)
  -- TODO: upstream directory traversal from planery.scandir to core as part of vim.fs ?
  if not files then
    files = {}
  end
  if depth > opts.max_depth then
    return {}
  end
  local fd = vim.uv.fs_scandir(dir)
  if fd then
    local name, typ = vim.uv.fs_scandir_next(fd)
    while name do
      local path = vim.fs.joinpath(dir, name)
      if not is_excluded(opts.exclude, path) then
        if typ == 'file' and vim.tbl_contains(opts.include, 'files') then
          table.insert(files, path)
        elseif typ == 'directory' then
          if vim.tbl_contains(opts.include, 'dirs') then
            table.insert(files, path)
          end
          traverse_directory(opts, path, depth + 1, files)
        end
      end
      name, typ = vim.uv.fs_scandir_next(fd)
    end
  end
  return files
end

--- Get list of files and directories in the project root
--- @param opts table|nil Optional configuration table to override default settings
---   @field root string The project root directory
---   @field include table A list of types to include in the result, e.g., {'files', 'dirs'}
---   @field exclude table A list of patterns to exclude from the result, e.g., {'.git', '.hg', '.svn', '.cache', 'node_modules', 'build'}
---   @field max_depth number The maximum depth to traverse the directory tree (default: 5)
---   @field follow_links boolean Whether to follow symbolic links (default: false)
---   @field follow_gitignore boolean Whether to respect the `.gitignore` file (default: true)
--- @return table A table containing the list of files and directories in the project root
function M.get_project_files(opts)
  local defaults = {
    root = vim.project.get_root(0),
    include = { 'files', 'dirs' },
    exclude = { '.git', '.hg', '.svn', '.cache', 'node_modules', 'build' },
    max_depth = 5,
    follow_links = false,
    follow_gitignore = true,
  }
  opts = vim.tbl_deep_extend('force', defaults, opts or {})

  if not opts.root or not vim.uv.fs_stat(opts.root) then
    vim.notify('Project root does not exist', vim.log.levels.ERROR)
    return files
  end
  local uv = vim.uv
  if opts.follow_gitignore then
    local gitignore = vim.fs.joinpath(opts.root, '.gitignore')
    if uv.fs_stat(gitignore) then
      local gitignore_patterns = {}
      for line in io.lines(gitignore) do
        line = line:match('^%s*(.-)%s*$') -- trim whitespace
        if line and line ~= '' and not line:match('^#') then
          table.insert(gitignore_patterns, line)
        end
      end
      opts.exclude = vim.list_extend(opts.exclude, gitignore_patterns)
    end
  end

  local files = traverse_directory(opts, opts.root, 0)
  return files
end

---  Gets symbols for a file in the project
function M.get_project_symbols(file)
  vim.validate('file', file, 'string')
  -- TODO: collect symbol for file from lsp/treesitter
  vim.notify('get_project_symbols is not implemented yet', vim.log.levels.WARN)
  return {}
end

return M
