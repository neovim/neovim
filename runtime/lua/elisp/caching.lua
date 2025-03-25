local M = {}
---@generic T
---@param path string
---@param read_cache fun(content:string): T?
---@param generate_cache fun(arg:T):string
---@param fn fun(): T
---@param is_lua boolean
function M.cache(path, read_cache, generate_cache, fn, is_lua)
  local root = _G.vim_elisp_compile_lisp_to_lua_path
  if not root then
    return fn()
  end
  vim.fn.mkdir(root, 'p')
  local fname = path:gsub('/', '%%') .. (is_lua and '.lua' or '')

  local fcache = root .. '/' .. fname
  local fr = io.open(fcache, 'r')
  if fr then
    local cache_content = fr:read('*a')
    fr:close()
    local info = assert(vim.uv.fs_stat(path))
    local mtime = info.mtime.sec * 1000 + info.mtime.nsec / 1000000
    local info_cache = assert(vim.uv.fs_stat(fcache))
    local mtime_cache = info_cache.mtime.sec * 1000 + info_cache.mtime.nsec / 1000000
    if mtime <= mtime_cache then
      return read_cache(cache_content)
    end
  end
  local ret = fn()
  local content = generate_cache(ret)
  local fw = io.open(fcache, 'w')
  if fw then
    fw:write(content)
    fw:close()
  end
  return ret
end
return M
