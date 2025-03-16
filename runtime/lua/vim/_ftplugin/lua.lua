local M = {}

--- @param module string
---@return string
function M.includeexpr(module)
  ---@param fname string
  ---@return boolean
  local function filereadable(fname)
    return vim.fn.filereadable(fname) == 1
  end

  local fname = module:gsub('%.', '/')

  local root = vim.fs.root(vim.api.nvim_buf_get_name(0), 'lua') or vim.fn.getcwd()
  for _, suf in ipairs { '.lua', '/init.lua' } do
    local path = vim.fs.joinpath(root, 'lua', fname .. suf)
    if filereadable(path) then
      return path
    end
  end

  local modInfo = vim.loader.find(module)[1]
  return modInfo and modInfo.modpath or module
end

return M
