local srcdir = table.remove(arg, 1)

package.path = (srcdir .. '/src/?.lua;') .. (srcdir .. '/runtime/lua/?.lua;') .. package.path

arg[0] = table.remove(arg, 1)
return loadfile(arg[0])()
