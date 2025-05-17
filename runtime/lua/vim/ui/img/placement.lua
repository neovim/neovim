---@class vim.ui.img.Placement
---@field image vim.ui.Image
---@field private __id integer|nil when loaded, id is populated by provider
---@field private __provider string
local M = {}
M.__index = M

---Creates a new image placement.
---@param img vim.ui.Image
---@param opts? {provider?:string}
---@return vim.ui.img.Placement
function M.new(img, opts)
  opts = opts or {}

  local instance = {}
  setmetatable(instance, M)

  instance.image = img
  instance.__provider = opts.provider or vim.o.imgprovider

  return instance
end

---Whether or not the placement is actively shown.
---@return boolean
function M:is_visible()
  return self.__id ~= nil
end

---Retrieves the provider managing this placement.
---@return vim.ui.img.Provider|nil provider, string|nil err
function M:provider()
  local name = self.__provider
  local provider = require('vim.ui.img.providers').load(name)
  if provider then
    return provider
  else
    return nil, string.format('provider "%s" not found', name)
  end
end

---Displays the placement.
---```lua
---local placement = ...
---
-----Can be invoked synchronously
---assert(placement:show({ ... }):wait())
---
-----Can also be invoked asynchronously
---placement:show({ ... }):on_done(function(err)
---  -- Do something
---end)
---```
---@param opts? vim.ui.img.Opts
---@return vim.ui.img.utils.Promise<vim.NIL>
function M:show(opts)
  local promise = require('vim.ui.img.utils.promise').new({
    context = 'placement.show',
  })

  local provider, err = self:provider()
  if err or not provider then
    err = err or 'unable to retrieve provider'
    promise:fail(err)
  else
    provider.show(self.image, opts)
        :on_ok(function(id)
          self.__id = id
          promise:ok(vim.NIL)
        end)
        :on_fail(function(err)
          promise:fail(err)
        end)
  end

  return promise
end

---Hides the placement.
---```lua
---local placement = ...
---
-----Can be invoked synchronously
---assert(placement:hide():wait())
---
-----Can also be invoked asynchronously
---placement:hide():on_done(function(err)
---  -- Do something
---end)
---```
---@return vim.ui.img.utils.Promise<vim.NIL>
function M:hide()
  local promise = require('vim.ui.img.utils.promise').new({
    context = 'placement.hide',
  })

  local provider, err = self:provider()
  if err or not provider then
    err = err or 'unable to retrieve provider'
    promise:fail(err)
  else
    provider.hide(self.__id)
        :on_ok(function()
          self.__id = nil
          promise:ok(vim.NIL)
        end)
        :on_fail(function(err)
          promise:fail(err)
        end)
  end

  return promise
end

---Updates the placement.
---```lua
---local placement = ...
---
-----Can be invoked synchronously
---assert(placement:update({ ... }):wait())
---
-----Can also be invoked asynchronously
---placement:update({ ... }):on_done(function(err)
---  -- Do something
---end)
---```
---@param opts? vim.ui.img.Opts
---@return vim.ui.img.utils.Promise<vim.NIL>
function M:update(opts)
  local promise = require('vim.ui.img.utils.promise').new({
    context = 'placement.update',
  })

  local provider, err = self:provider()
  if err or not provider then
    err = err or 'unable to retrieve provider'
    promise:fail(err)
  else
    provider.update(self.__id, opts)
        :on_ok(function(id)
          self.__id = id
          promise:ok(vim.NIL)
        end)
        :on_fail(function(err)
          promise:fail(err)
        end)
  end

  return promise
end

return M
