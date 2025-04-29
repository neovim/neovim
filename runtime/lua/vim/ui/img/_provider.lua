---@class vim.ui.img.Provider
---@field render fun(image:vim.ui.Image, opts?:vim.ui.img.Provider.RenderOpts)

---@class vim.ui.img.Provider.RenderOpts
---@field crop? vim.ui.img.Region portion of image to display
---@field pos? vim.ui.img.Position upper-left position of image within editor
---@field size? vim.ui.img.Size explicit size to scale the image

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
