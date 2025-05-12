---@type table<string, vim.ui.img.Provider>
local PROVIDERS = {}

---@class vim.ui.img.Providers
---@field [string] vim.ui.img.Provider
local M = {}

---@class (exact) vim.ui.img.provider.Opts
---@field on_unload? fun(self:vim.ui.img.Provider) called to cleanup this provider
---@field on_load? fun(self:vim.ui.img.Provider) called to initialize this provider
---@field on_show fun(self:vim.ui.img.Provider, img:vim.ui.Image, opts?:vim.ui.img.Opts):integer
---@field on_hide fun(self:vim.ui.img.Provider, ids:integer[])
---@field on_update? fun(self:vim.ui.img.Provider, id:integer, opts?:vim.ui.img.Opts):integer

---Creates a new image provider instance.
---@param opts vim.ui.img.provider.Opts
---@return vim.ui.img.Provider
function M.new(opts)
  ---@class vim.ui.img.Provider
  ---@field displayed table<integer, vim.ui.Image> mapping of displayed image id -> image
  ---@field private _loaded boolean
  ---@field private _opts vim.ui.img.provider.Opts
  local provider = {
    displayed = {},
    _loaded = false,
    _opts = opts,
  }

  ---Displays the image using the provider.
  ---@param img vim.ui.Image
  ---@param opts? vim.ui.img.Opts
  ---@return integer id unique id representing a reference to the displayed image
  function provider.show(img, opts)
    local id = provider._opts.on_show(provider, img, opts)

    provider.displayed[id] = img

    return id
  end

  ---Hides one or more displayed images using the provider.
  ---
  ---If no id provided, will hide all displayed images.
  ---@param ... integer|integer[] ids of the displayed images
  function provider.hide(...)
    ---@type integer[]
    local ids = {}

    for _, id in ipairs({ ... }) do
      if type(id) == 'number' then
        table.insert(ids, id)
      elseif type(id) == 'table' then
        vim.list_extend(ids, id)
      end
    end

    -- If no ids provided, assume hiding them all
    if #ids == 0 then
      ids = vim.tbl_keys(provider.displayed)
    end

    provider._opts.on_hide(provider, ids)

    for _, id in ipairs(ids) do
      provider.displayed[id] = nil
    end
  end

  ---Updates the displayed image using the provided options.
  ---@param id integer id of the displayed image
  ---@param opts? vim.ui.img.Opts changes to apply to the displayed image
  ---@return integer id new id representing updated, displayed image
  function provider.update(id, opts)
    local img = assert(
      provider.displayed[id],
      string.format('display image %s does not exist', id)
    )

    -- If we have an explicitly-defined update method, use it as this is
    -- most likely more performant than the bruteforce approach
    if provider._opts.on_update then
      local new_id = provider._opts.on_update(provider, id, opts)

      provider.displayed[id] = nil
      provider.displayed[new_id] = img

      return new_id
    end

    -- Without a custom update function, we merely hide the old displayed
    -- image and then show the image again
    provider.hide(id)
    return provider.show(img, opts)
  end

  ---Returns true if the provider is currently loaded.
  ---@return boolean
  function provider.is_loaded()
    return provider._loaded
  end

  ---Loads the provider by performing any setup logic needed.
  ---This is invoked when switching to this provider.
  function provider.load()
    if provider._loaded then
      return
    end

    if provider._opts.on_load then
      provider._opts.on_load(provider)
    end

    provider._loaded = true
  end

  ---Unloads the provider by performing any cleanup logic needed.
  ---This is invoked when switching away from this provider.
  function provider.unload()
    if not provider._loaded then
      return
    end

    if provider._opts.on_unload then
      provider._opts.on_unload(provider)
    else
      -- Hide all images if nothing else done
      provider.hide()
    end

    provider._loaded = false
  end

  return provider
end

---Checks whether a provider with the given name is available.
---Involves scanning and loading internal providers.
---@param name string
---@return boolean
function M.has(name)
  return M.get(name) ~= nil
end

---Retrieves a provider by its name, searching within known providers.
---@param name string
---@return vim.ui.img.Provider|nil
function M.get(name)
  ---@type vim.ui.img.Provider|nil
  local provider = PROVIDERS[name]

  -- Provider not found in our cache, so instead see if it's one of the
  -- default available providers that may not be loaded yet
  if not provider then
    local modname = string.format('vim.ui.img.providers.%s', name)

    ---@type boolean, string|vim.ui.img.Provider
    local ok, err_or_provider = pcall(require, modname)

    -- If we successfully loaded the provider, register it
    if ok and type(err_or_provider) == 'table' then
      provider = err_or_provider
      PROVIDERS[name] = provider
    end
  end

  return provider
end

---Like getting a provider, but also loads it upon success.
---@param name string
---@return vim.ui.img.Provider|nil
function M.load(name)
  local provider = M.get(name)
  if provider then
    provider.load()
  end
  return provider
end

---@private
---Invoked when imgprovider option changes, unloading old provider.
---@param name string
---@return boolean
function M.__unload(name)
  local ok = true
  local provider = M.get(name)
  if provider then
    ok = pcall(provider.unload)
  end
  return ok
end

---@type vim.ui.img.Providers
M = setmetatable(PROVIDERS, {
  __index = M,
})

return M
