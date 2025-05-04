---@class vim.ui.img.Providers
---@field [string] vim.ui.img.Provider
local M = {}

---@class (exact) vim.ui.img.provider.Opts
---@field show fun(img:vim.ui.Image, opts?:vim.ui.img.Opts):integer
---@field hide fun(ids:integer[])

---Creates a new image provider instance.
---@param opts vim.ui.img.provider.Opts
---@return vim.ui.img.Provider
function M.new(opts)
  ---@class vim.ui.img.Provider
  ---@field displayed table<integer, vim.ui.Image> mapping of displayed image id -> image
  ---@field private _opts vim.ui.img.provider.Opts
  local provider = {
    displayed = {},
    _opts = opts,
  }

  ---Displays the image using the provider.
  ---@param img vim.ui.Image
  ---@param opts? vim.ui.img.Opts
  ---@return integer id unique id representing a reference to the displayed image
  function provider.show(img, opts)
    local id = provider._opts.show(img, opts)

    provider.displayed[id] = img

    return id
  end

  ---Hides one or more displayed images using the provider.
  ---@param ids integer|integer[]
  function provider.hide(ids)
    if type(ids) == 'number' then
      ids = { ids }
    end

    ---@cast ids -integer
    provider._opts.hide(ids)

    for _, id in ipairs(ids) do
      provider.displayed[id] = nil
    end
  end

  return provider
end

---Loads a provider from its name, searching within known providers.
---If not found, will throw an error.
---@param name string
---@return vim.ui.img.Provider
function M.load(name)
  local provider = M[name]

  -- Provider not found in our cache, so instead see if it's one of the
  -- default available providers that may not be loaded yet
  if not provider then
    local modname = string.format('vim.ui.img.providers.%s', name)

    ---@type boolean, string|vim.ui.img.Provider
    local ok, err_or_provider = pcall(require, modname)

    -- If we successfully loaded the provider, register it
    if ok and type(err_or_provider) == 'table' then
      provider = err_or_provider
      M[name] = provider
    end
  end

  return assert(provider, string.format('provider %s not found', name))
end

return M
