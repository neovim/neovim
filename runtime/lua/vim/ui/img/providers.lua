---@type table<string, vim.ui.img.Provider>
local PROVIDERS = {}

---@class vim.ui.img.Providers
---@field [string] vim.ui.img.Provider
local M = {}

---@class (exact) vim.ui.img._ProviderOpts
---@field load? fun(...:any) called to initialize this provider
---@field unload? fun() called to cleanup this provider
---@field supported? fun(on_supported:fun(supported:boolean))
---@field show fun(img:vim.ui.Image, opts:vim.ui.img.InternalOpts, on_shown:fun(err:string|nil, id:integer|nil))
---@field hide fun(ids:integer[], on_hidden:fun(err:string|nil, ids:integer[]|nil))
---@field update? fun(id:integer, opts:vim.ui.img.InternalOpts, on_updated:fun(err:string|nil, id:integer|nil))

---Creates a new image provider instance.
---@param opts vim.ui.img._ProviderOpts
---@return vim.ui.img.Provider
function M.new(opts)
  ---@class vim.ui.img.Provider
  ---@field images table<integer, vim.ui.Image> mapping of provider created image id -> image
  ---@field private __loaded boolean
  ---@field private __supported boolean|nil
  local provider = {
    images = {},
    __loaded = false,
    __supported = nil,
  }

  local inner = opts

  ---Displays the image using the provider.
  ---@param img vim.ui.Image
  ---@param show_opts vim.ui.img.InternalOpts
  ---@return vim.ui.img._Promise<integer>
  function provider.show(img, show_opts)
    local promise = require('vim.ui.img._promise').new({
      context = 'provider.show',
    })

    ---@type boolean, string|nil
    local ok, err = pcall(inner.show, img, show_opts, function(err, id)
      if id then
        provider.images[id] = img
        promise:ok(id)
      else
        promise:fail(err)
      end
    end)

    if not ok then
      promise:fail(err)
    end

    return promise
  end

  ---Hides one or more images using the provider.
  ---
  ---If no id provided, will hide all displayed images.
  ---@param ids integer|integer[]
  ---@return vim.ui.img._Promise<integer[]>
  function provider.hide(ids)
    local promise = require('vim.ui.img._promise').new({
      context = 'provider.hide',
    })

    if type(ids) == 'number' then
      ids = { ids }
    end

    -- If no ids provided, assume hiding them all
    ---@cast ids -integer
    if #ids == 0 then
      ids = vim.tbl_keys(provider.images)
    end

    ---@type boolean, string|nil
    local ok, err = pcall(inner.hide, ids, function(err, hidden)
      if hidden then
        for _, id in ipairs(hidden) do
          provider.images[id] = nil
        end
        promise:ok(ids)
      else
        promise:fail(err)
      end
    end)

    if not ok then
      promise:fail(err)
    end

    return promise
  end

  ---Updates the displayed image using the provided options.
  ---@param id integer id of the image
  ---@param update_opts vim.ui.img.InternalOpts changes to apply to the displayed image
  ---@return vim.ui.img._Promise<integer>
  function provider.update(id, update_opts)
    local promise = require('vim.ui.img._promise').new({
      context = 'provider.update',
    })

    local img = provider.images[id]
    if not img then
      promise:fail(string.format('image %s does not exist', id))
      return promise
    end

    ---@param err string|nil
    ---@param new_id integer|nil
    local function on_done(err, new_id)
      if new_id then
        provider.images[id] = nil
        provider.images[new_id] = img
        promise:ok(new_id)
      else
        promise:fail(err)
      end
    end

    -- If we have an explicitly-defined update method, use it as this is
    -- most likely more performant than the bruteforce approach
    if inner.update then
      ---@type boolean, string|nil
      local ok, err = pcall(inner.update, id, update_opts, on_done)
      if not ok then
        promise:fail(err)
      end
    else
      -- Without a custom update function, we merely hide the old displayed
      -- image and then show the image again
      --
      -- NOTE: This may introduce flicker as it waits until hide has completely
      --       finished before starting the process of showing the image again!
      provider
        .hide(id)
        :on_ok(function()
          provider.show(img, update_opts):on_done(on_done)
        end)
        :on_fail(function(err)
          promise:fail(err)
        end)
    end

    return promise
  end

  ---Returns true if the provider is currently loaded.
  ---@return boolean
  function provider.is_loaded()
    return provider.__loaded
  end

  ---Loads the provider by performing any setup logic needed.
  ---This is invoked when switching to this provider.
  ---@param ... any optional additional parameters specific to a provider
  function provider.load(...)
    if provider.__loaded then
      return
    end

    if inner.load then
      inner.load(...)
    end

    provider.__loaded = true
  end

  ---Unloads the provider by performing any cleanup logic needed.
  ---This is invoked when switching away from this provider.
  function provider.unload()
    if not provider.__loaded then
      return
    end

    if inner.unload then
      inner.unload()
    end

    provider.__loaded = false
  end

  ---Whether or not the provider is supported in the current environment.
  ---@return vim.ui.img._Promise<boolean>
  function provider.supported()
    local promise = require('vim.ui.img._promise').new({
      context = 'provider.supported',
    })

    -- If we've already calculated the support status
    local is_supported = provider.__supported
    if type(is_supported) == 'boolean' then
      promise:ok(is_supported)
      return promise
    end

    if inner.supported then
      ---@type boolean, string|nil
      local ok, err = pcall(inner.supported, function(supported)
        provider.__supported = supported
        promise:ok(supported)
      end)

      if not ok then
        promise:fail(err)
      end
    else
      promise:fail('unknown')
    end

    return promise
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
---@param ... any
---@return vim.ui.img.Provider|nil
function M.load(name, ...)
  local provider = M.get(name)
  if provider then
    provider.load(...)
  end
  return provider
end

---Unloads a loaded provider by name, returning
---whether or not successfully unloaded.
---@param name string
---@return boolean
function M.unload(name)
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
