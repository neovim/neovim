local M = {}

---@param module string
---@return string
function M.includeexpr(module)
  vim.validate('module', module, 'string')
  local fname = module:gsub('%.', '/')
  local root = vim.fs.root(vim.api.nvim_buf_get_name(0), 'lua') or vim.fn.getcwd()
  for _, suf in ipairs { '.lua', '/init.lua' } do
    local path = vim.fs.joinpath(root, 'lua', fname .. suf)
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end

  local modInfo = vim.loader.find(module)[1]
  return modInfo and modInfo.modpath or module
end

return M
