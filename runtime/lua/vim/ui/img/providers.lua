---@type table<string, vim.ui.img.Provider>
local PROVIDERS = {}

---@class vim.ui.img.Providers
---@field [string] vim.ui.img.Provider
local M = {}

---@class (exact) vim.ui.img.provider.Opts
---@field setup? fun(self:vim.ui.img.Provider)
---@field show fun(self:vim.ui.img.Provider, img:vim.ui.Image, opts?:vim.ui.img.Opts):integer
---@field hide fun(self:vim.ui.img.Provider, ids:integer[])
---@field update? fun(self:vim.ui.img.Provider, id:integer, opts?:vim.ui.img.Opts):integer

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
    local id = provider._opts.show(provider, img, opts)

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

    provider._opts.hide(provider, ids)

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
    if provider._opts.update then
      local new_id = provider._opts.update(provider, id, opts)

      provider.displayed[id] = nil
      provider.displayed[new_id] = img

      return new_id
    end

    -- Without a custom update function, we merely hide the old displayed
    -- image and then show the image again
    provider.hide(id)
    return provider.show(img, opts)
  end

  -- Invoke the setup function if it is provided
  if type(provider._opts.setup) == 'function' then
    ---@type boolean, string
    local ok, err = pcall(provider._opts.setup, provider)

    if not ok then
      vim.notify(
        string.format('setup failed for provider: %s', vim.inspect(err)),
        vim.log.levels.WARN
      )
    end
  end

  return provider
end

---Loads a provider from its name, searching within known providers.
---If not found, will throw an error.
---@param name string
---@return vim.ui.img.Provider
function M.load(name)
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

  return assert(provider, string.format('provider %s not found', name))
end

---@type vim.ui.img.Providers
M = setmetatable(PROVIDERS, {
  __index = M,
})

return M
