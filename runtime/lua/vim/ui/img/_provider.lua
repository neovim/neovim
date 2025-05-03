---Loads a provider from its name, searching within known providers.
---If not found, will throw an error.
---@param name string
---@return vim.ui.img.Provider
local function load_provider_from_name(name)
  local modname = 'vim.ui.img._provider.' .. name
  return require(modname)
end

return {
  load = load_provider_from_name,
}
