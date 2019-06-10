-- luacheck: globals unpack vim.api
local nvim = vim.api
local map = require('helpers.plugin.map').map
local unmap = require('helpers.plugin.map').unmap
local functions = require('helpers.plugin.map').functions

local function new_plugin(name)
  -- TODO(KillTheMule): Check assumptions about subsequent calls of this
  local ns = nvim.nvim_create_namespace(name)

  -- Should be redundant after the comment above has ben ascertained
  assert(functions[ns] == nil, "Namspace "..tostring(ns).." already exists")

  functions[ns] = {}
  return { ns = ns, name = name, map = map, unmap = unmap }
end

return {
  new_plugin = new_plugin,
}
