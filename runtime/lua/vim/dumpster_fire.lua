local mpack = require'mpack'

local M = {}
_G.d = M

M.cache = {}

function vim._load_hooky(mod, path, f)
  local dump = string.dump(f)
  M.cache[mod] = {path, dump}
  M.dirty = true
end

function M.dump_cache(path)
  local f = io.open(path, 'wb')
  f:write(mpack.pack(M.cache))
end

function M.load_cache(path)
  local f = io.open(path, 'rb')
  M.cache = mpack.unpack(f:read'*a')
  M.dirty = false
end

M.tried, M.did = {}, {}

function M.preloader(name)
  table.insert(M.tried, name)
  if M.cache[name] == nil then
    return
  end
  local f,codes = unpack(M.cache[name])
  -- TODO: compare a hashish or a timestamp of the file, or something stupid
  if vim.fn.filereadable(f) == 0 then
    return "cached file was joinked"
  end
  table.insert(M.did, name)
  return vim.startup_profile("require'"..name.."' [cached] execute", function() return loadstring(codes)() end)
end

function M.megapreload()
  for k,v in pairs(M.cache) do
    if package.loaded[k] == nil then
      package.preload[k] = M.preloader
    end
  end
end

function M.dumpster_test(name)
  if vim.fn.filereadable(name) == 1 then
    M.load_cache(name)
    M.megapreload()
  end
  function _G.__dumpster_enter()
    _G.__dumpster_enter = nil
    if M.dirty then
      M.dump_cache(name)
      M.dirty = false
    end
  end
  vim.cmd [[autocmd VimEnter * lua _G.__dumpster_enter()]]
end

return M
