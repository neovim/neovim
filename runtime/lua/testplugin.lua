local nvim = vim.api
local helpers = require('helpers')

local plugin = helpers.new_plugin("testplugin")

local function stuff()
  local curbuf = nvim.nvim_get_current_buf()
  nvim.nvim_buf_set_lines(curbuf, 0, 0, true, {"Testplugin"})
end

local function stuff2()
  local curbuf = nvim.nvim_get_current_buf()
  nvim.nvim_buf_set_lines(curbuf, 0, 0, true, {"Testplugin2"})
end

local function init()
  plugin:map("<F2>", stuff)
  plugin:map{ buffer = true, keys = "<", fn = stuff2 }
end

local function maperr1()
  local err, errmsg = pcall(plugin.map, plugin,
               { buffer = true, keys = "<", fn = stuff2, x = 1 })
  return err, errmsg
end

local function maperr2()
  local err, errmsg = pcall(plugin.map, plugin,
               { buffer = true, keys = a, fn = stuff2 })
  return err, errmsg
end

local function clear_f2()
  plugin:unmap("<F2>")
end

local function clear_f3()
  return plugin:unmap("<F3>")
end

return {
  init = init,
  maperr1 = maperr1,
  maperr2 = maperr2,
  clear_f2 = clear_f2,
  clear_f3 = clear_f3,
}
