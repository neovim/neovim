-- Generate build tags using the runtime scanner, including with nlua0.
-- Usage: nlua0 gen_helptags.lua {out} {dir} [++t]
local scriptdir = arg[0]:match('^(.*[/\\])') or './'
local luadir = scriptdir .. '../../runtime/lua/'
package.path = luadir .. '?.lua;' .. package.path

local fs = require('vim.fs')
-- Load the source version: NVIM_HOST_PRG may embed an older help module.
local help = dofile(luadir .. 'vim/_core/help.lua')

local dir = fs.abspath(arg[2])
local files = {}
local scan = assert(vim.uv.fs_scandir(dir))
while true do
  local name, kind = vim.uv.fs_scandir_next(scan)
  if not name then
    break
  end
  if kind == 'file' and name:sub(-4) == '.txt' then
    files[#files + 1] = fs.joinpath(dir, name)
  end
end

help.gen_tagsfile(files, dir, arg[1], arg[3] == '++t' and 'tags' or nil, false)

-- nvim -l exits successfully after echo_err(), so fail the build explicitly.
if vim.v and vim.v.errmsg ~= '' then
  os.exit(1)
end
