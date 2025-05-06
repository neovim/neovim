local M = {}

--- @param module string
---@return string
function M.includeexpr(module)
  module = module:gsub('%.', '/')

  local root = vim.fs.root(vim.api.nvim_buf_get_name(0), 'lua') or vim.fn.getcwd()
  for _, fname in ipairs { module, vim.fs.joinpath(root, 'lua', module) } do
    for _, suf in ipairs { '.lua', '/init.lua' } do
      local path = fname .. suf
      if vim.uv.fs_stat(path) then
        return path
      end
    end
  end

  local modInfo = vim.loader.find(module)[1]
  return modInfo and modInfo.modpath or module
end

return M
