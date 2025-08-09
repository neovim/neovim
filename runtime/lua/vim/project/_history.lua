local M = {}

local history = {}
local history_file = vim.fn.stdpath('data') .. '/nvim_project_history.json'
local current_project = ''

--- Returns the recently edited projects
function M.get_projects()
  return history
end

--- Reads the project history from the history file
--- If the file does not exist or is empty, it initializes an empty history.
function M.read_history()
  if not vim.uv.fs_stat(history_file) then
    history = {}
    return history
  end
  local file = vim.uv.fs_open(history_file, 'r', 384) -- 384 is 0600 in octal
  if not file then
    history = {}
    return history
  end
  local data = vim.uv.fs_read(file, vim.uv.fs_fstat(file).size)
  vim.uv.fs_close(file)
  if not data or data == '' then
    history = {}
    return history
  end
  local ok, decoded = pcall(vim.json.decode, data)
  if not ok then
    vim.notify('Failed to load project history: ' .. decoded, vim.log.levels.ERROR)
    history = {}
    return history
  end

  history = decoded
  return history
end

--- Adds a project root to the history
--- If the project path is already in the history, it moves it to the front.
function M.add_project(project_path)
  vim.validate('project_path', project_path, 'string')
  if current_project == project_path then
    return
  end

  local existing_index = nil
  for i, entry in ipairs(history) do
    if entry.path == project_path then
      existing_index = i
      break
    end
  end

  if existing_index then
    table.remove(history, existing_index)
  end
  table.insert(history, 1, {
    path = project_path,
    timestamp = os.time(),
  })
  current_project = project_path
end

--- Writes the project history to the history file
--- Write operation is done while closing neovim
function M.write_history()
  local file = vim.uv.fs_open(history_file, 'w', 384) -- 384 is 0600 in octal
  if not file then
    vim.notify('Failed to open project history file for writing', vim.log.levels.ERROR)
    return false
  end
  local data = vim.json.encode(history)
  vim.uv.fs_write(file, data, -1)
  vim.uv.fs_close(file)
  return true
end
return M
