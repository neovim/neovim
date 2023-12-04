local srcdir = table.remove(arg, 1)
local nlualib = table.remove(arg, 1)
package.path = srcdir .. '/src/nvim/?.lua;' .. srcdir .. '/runtime/lua/?.lua;' .. package.path
_G.vim = require 'vim.shared'
_G.vim.inspect = require 'vim.inspect'
package.cpath = package.cpath .. ';' .. nlualib
require 'nlua0'

arg[0] = table.remove(arg, 1)
return loadfile(arg[0])()
