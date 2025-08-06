local config = require('vim.project._config')
local history = require('vim.project._history')
local context = require('vim.project._context')

local M = {}

---Gets the LSP (Language Server Protocol) root directory for a given buffer
---@param buf number The buffer number to get the root directory for.
---@return string|nil The LSP root directory path if found, nil otherwise
local function get_lsp_root(buf)
  vim.validate('buf', buf, 'number')
  if not config.lsp_root_detect then
    return nil
  end

  local clients = vim.lsp.get_clients({bufnr = buf})
  if #clients == 0 then
    return nil
  end
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end
  return nil
end

---Gets the project root directory for a given buffer
---This function first checks if a project root is already set in the buffer's variable.
---If not, it attempts to find the LSP root directory. If that fails, it
---falls back to using the filetype-specific root markers defined in the configuration.
---@param buf number The buffer number to get the project root for.
---@return string The project root directory path
---@return string|nil The LSP root directory path if found, nil otherwise
function M.get_root(buf)
  vim.validate('buf', buf, 'number')
  local ok, project_root = pcall(vim.api.nvim_buf_get_var, buf, 'project_root')
  if ok and project_root and project_root ~= '' then
    return project_root
  end

  local lsp_root = get_lsp_root(buf)
  if lsp_root and lsp_root ~= '' then
    vim.api.nvim_buf_set_var(buf, 'project_root', lsp_root)
    return lsp_root
  end

  local ft = vim.api.nvim_get_option_value('filetype', {buf = buf})
  local ft_root_patterns = config.root_markers[ft] or {}
  local root = vim.fs.root(buf, vim.list_extend(config.root_markers.global, ft_root_patterns))
  vim.api.nvim_buf_set_var(buf, 'project_root', root)
  return root
end

--- Gets the data directory for a given buffer and kind
--- The data directory is a subdirectory of the project's `.nvim` directory.
--- If the `.nvim` directory does not exist, it will be created.
--- If the specified kind is not provided, it defaults to the root `.nvim` directory.
--- Valid kinds are 'data' and 'config', which correspond to subdirectories within the `.nvim` directory.
--- If the kind is invalid or not specified, it returns the root `.nvim` directory.
---@param buf number The buffer number to get the data directory for.
---@param kind 'data'|'config' The kind of data directory to get ('.nvim/data' or '.nvim/config').
function M.get_data_dir(buf, kind)
  local valid_kind_dirs = {'data', 'config'}
  vim.validate('buf', buf, 'number')
  vim.validate('kind', kind, function(v)
    return v == nil or (type(v) == 'string' and vim.list_contains(valid_kind_dirs, v))
  end)

  local root = M.get_root(buf)
  if not root or root == '' then
    return nil
  end

  local nvim_dir = vim.fs.joinpath(root, '.nvim')
  if not vim.uv.fs_stat(nvim_dir) then
    vim.uv.fs_mkdir(nvim_dir, 493) -- 493 is 755 in octal
  end

  if kind == nil then
    return nvim_dir
  end

  local data_dir = vim.fs.joinpath(nvim_dir, kind)
  if not vim.uv.fs_stat(data_dir) then
    vim.uv.fs_mkdir(data_dir, 493) -- 493 is 755 in octal
  end
  return data_dir
end

--- Sets the project root for a given buffer
local function on_buf_enter(ev)
  local root = M.get_root(ev.buf)
  if root and root ~= '' and config.autochdir then
    vim.api.nvim_set_current_dir(root)
  end
  history.add_project(root)
end

--- Enables the Nvim-Project with optional configuration
---@param opts table|nil Optional configuration table to override default settings
--- @field lsp_root_detect boolean Whether to detect LSP root directories (default: true)
--- @field autochdir boolean Whether to automatically change the working directory to the project root (default: true)
--- @field root_markers table A table of filetype-specific root markers, where each key is a filetype and the value is a list of root marker patterns.
--- @field root_markers.global table A list of global root marker patterns that apply to all filetypes.
function M.enable(opts)
  if opts then
    config = vim.tbl_deep_extend('force', config, opts)
  end

  history.read_history()

  local agroup = vim.api.nvim_create_augroup('Nvim-Project', {clear = true})
  vim.api.nvim_create_autocmd({'BufEnter'}, {
    group = agroup,
    desc = "Setup project on BufEnter",
    callback = on_buf_enter,
  })

  vim.api.nvim_create_autocmd({'VimLeavePre'}, {
    group = agroup,
    desc = "Write project history on VimLeavePre",
    callback = history.write_history,
  })
end

--- Disables the Nvim-Project
function M.disable()
  local agroup = vim.api.nvim_create_augroup('Nvim-Project', {clear = true})
  vim.api.nvim_del_augroup_by_id(agroup)
end

M.get_recent = history.get_projects
M.ctx = context

return M
