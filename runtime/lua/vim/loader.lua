local fs = vim.fs -- "vim.fs" is a dependency, so must be loaded early.
local uv = vim.uv
local uri_encode = vim.uri_encode --- @type function

--- @type (fun(modename: string): fun()|string)[]
local loaders = package.loaders
local _loadfile = loadfile

local VERSION = 4

local M = {}

--- @alias vim.loader.CacheHash {mtime: {nsec: integer, sec: integer}, size: integer, type?: string}
--- @alias vim.loader.CacheEntry {hash:vim.loader.CacheHash, chunk:string}

--- @class vim.loader.find.Opts
--- @inlinedoc
---
--- Search for modname in the runtime path.
--- (default: `true`)
--- @field rtp? boolean
---
--- Extra paths to search for modname
--- (default: `{}`)
--- @field paths? string[]
---
--- List of patterns to use when searching for modules.
--- A pattern is a string added to the basename of the Lua module being searched.
--- (default: `{"/init.lua", ".lua"}`)
--- @field patterns? string[]
---
--- Search for all matches.
--- (default: `false`)
--- @field all? boolean

--- @class vim.loader.ModuleInfo
--- @inlinedoc
---
--- Path of the module
--- @field modpath string
---
--- Name of the module
--- @field modname string
---
--- The fs_stat of the module path. Won't be returned for `modname="*"`
--- @field stat? uv.fs_stat.result

--- @alias vim.loader.Stats table<string, {total:number, time:number, [string]:number?}?>

--- @private
M.path = vim.fn.stdpath('cache') .. '/luac'

--- @private
M.enabled = false

--- @type vim.loader.Stats
local stats = { find = { total = 0, time = 0, not_found = 0 } }

--- @type table<string, uv.fs_stat.result>?
local fs_stat_cache

--- @type table<string, table<string,vim.loader.ModuleInfo>>
local indexed = {}

--- @param path string
--- @return uv.fs_stat.result?
local function fs_stat_cached(path)
  if not fs_stat_cache then
    return uv.fs_stat(path)
  end

  if not fs_stat_cache[path] then
    -- Note we must never save a stat for a non-existent path.
    -- For non-existent paths fs_stat() will return nil.
    fs_stat_cache[path] = uv.fs_stat(path)
  end
  return fs_stat_cache[path]
end

local function normalize(path)
  return fs.normalize(path, { expand_env = false, _fast = true })
end

local rtp_cached = {} --- @type string[]
local rtp_cache_key --- @type  string?

--- Gets the rtp excluding after directories.
--- The result is cached, and will be updated if the runtime path changes.
--- When called from a fast event, the cached value will be returned.
--- @return string[] rtp, boolean updated
local function get_rtp()
  if vim.in_fast_event() then
    return (rtp_cached or {}), false
  end
  local updated = false
  local key = vim.go.rtp
  if key ~= rtp_cache_key then
    rtp_cached = {}
    for _, path in ipairs(vim.api.nvim_get_runtime_file('', true)) do
      path = normalize(path)
      -- skip after directories
      if
        path:sub(-6, -1) ~= '/after'
        and not (indexed[path] and vim.tbl_isempty(indexed[path]))
      then
        rtp_cached[#rtp_cached + 1] = path
      end
    end
    updated = true
    rtp_cache_key = key
  end
  return rtp_cached, updated
end

--- Returns the cache file name
--- @param name string can be a module name, or a file name
--- @return string file_name
local function cache_filename(name)
  local ret = ('%s/%s'):format(M.path, uri_encode(name, 'rfc2396'))
  return ret:sub(-4) == '.lua' and (ret .. 'c') or (ret .. '.luac')
end

--- Saves the cache entry for a given module or file
--- @param cname string cache filename
--- @param hash vim.loader.CacheHash
--- @param chunk function
local function write_cachefile(cname, hash, chunk)
  local f = assert(uv.fs_open(cname, 'w', 438))
  local header = {
    VERSION,
    hash.size,
    hash.mtime.sec,
    hash.mtime.nsec,
  }
  uv.fs_write(f, table.concat(header, ',') .. '\0')
  uv.fs_write(f, string.dump(chunk))
  uv.fs_close(f)
end

--- @param path string
--- @param mode integer
--- @return string? data
local function readfile(path, mode)
  local f = uv.fs_open(path, 'r', mode)
  if f then
    local size = assert(uv.fs_fstat(f)).size
    local data = uv.fs_read(f, size, 0)
    uv.fs_close(f)
    return data
  end
end

--- Loads the cache entry for a given module or file
--- @param cname string cache filename
--- @return vim.loader.CacheHash? hash
--- @return string? chunk
local function read_cachefile(cname)
  local data = readfile(cname, 438)
  if not data then
    return
  end

  local zero = data:find('\0', 1, true)
  if not zero then
    return
  end

  --- @type integer[]|{[0]:integer}
  local header = vim.split(data:sub(1, zero - 1), ',')
  if tonumber(header[1]) ~= VERSION then
    return
  end

  local hash = {
    size = tonumber(header[2]),
    mtime = { sec = tonumber(header[3]), nsec = tonumber(header[4]) },
  }

  local chunk = data:sub(zero + 1)

  return hash, chunk
end

--- The `package.loaders` loader for Lua files using the cache.
--- @param modname string module name
--- @return string|function
local function loader_cached(modname)
  fs_stat_cache = {}
  local ret = M.find(modname)[1]
  if ret then
    -- Make sure to call the global loadfile so we respect any augmentations done elsewhere.
    -- E.g. profiling
    local chunk, err = loadfile(ret.modpath)
    fs_stat_cache = nil
    return chunk or error(err)
  end
  fs_stat_cache = nil
  return ("\n\tcache_loader: module '%s' not found"):format(modname)
end

local is_win = vim.fn.has('win32') == 1

--- The `package.loaders` loader for libs
--- @param modname string module name
--- @return string|function
local function loader_lib_cached(modname)
  local ret = M.find(modname, { patterns = { is_win and '.dll' or '.so' } })[1]
  if not ret then
    return ("\n\tcache_loader_lib: module '%s' not found"):format(modname)
  end

  -- Making function name in Lua 5.1 (see src/loadlib.c:mkfuncname) is
  -- a) strip prefix up to and including the first dash, if any
  -- b) replace all dots by underscores
  -- c) prepend "luaopen_"
  -- So "foo-bar.baz" should result in "luaopen_bar_baz"
  local dash = modname:find('-', 1, true)
  local funcname = dash and modname:sub(dash + 1) or modname
  local chunk, err = package.loadlib(ret.modpath, 'luaopen_' .. funcname:gsub('%.', '_'))
  return chunk or error(err)
end

--- Checks whether two cache hashes are the same based on:
--- * file size
--- * mtime in seconds
--- * mtime in nanoseconds
--- @param a? vim.loader.CacheHash
--- @param b? vim.loader.CacheHash
local function hash_eq(a, b)
  return a
    and b
    and a.size == b.size
    and a.mtime.sec == b.mtime.sec
    and a.mtime.nsec == b.mtime.nsec
end

--- `loadfile` using the cache
--- Note this has the mode and env arguments which is supported by LuaJIT and is 5.1 compatible.
--- @param filename? string
--- @param mode? "b"|"t"|"bt"
--- @param env? table
--- @return function?, string?  error_message
local function loadfile_cached(filename, mode, env)
  local modpath = normalize(filename)
  local stat = fs_stat_cached(modpath)
  local cname = cache_filename(modpath)
  if stat then
    local e_hash, e_chunk = read_cachefile(cname)
    if hash_eq(e_hash, stat) and e_chunk then
      -- found in cache and up to date
      local chunk, err = load(e_chunk, '@' .. modpath, mode, env)
      if not (err and err:find('cannot load incompatible bytecode', 1, true)) then
        return chunk, err
      end
    end
  end

  local chunk, err = _loadfile(modpath, mode, env)
  if chunk and stat then
    write_cachefile(cname, stat, chunk)
  end
  return chunk, err
end

--- Return the top-level \`/lua/*` modules for this path
--- @param path string path to check for top-level Lua modules
local function lsmod(path)
  if not indexed[path] then
    indexed[path] = {}
    for name, t in fs.dir(path .. '/lua') do
      local modpath = path .. '/lua/' .. name
      -- HACK: type is not always returned due to a bug in luv
      t = t or fs_stat_cached(modpath).type
      --- @type string
      local topname
      local ext = name:sub(-4)
      if ext == '.lua' or ext == '.dll' then
        topname = name:sub(1, -5)
      elseif name:sub(-3) == '.so' then
        topname = name:sub(1, -4)
      elseif t == 'link' or t == 'directory' then
        topname = name
      end
      if topname then
        indexed[path][topname] = { modpath = modpath, modname = topname }
      end
    end
  end
  return indexed[path]
end

--- Finds Lua modules for the given module name.
---
--- @since 0
---
--- @param modname string Module name, or `"*"` to find the top-level modules instead
--- @param opts? vim.loader.find.Opts Options for finding a module:
--- @return vim.loader.ModuleInfo[]
function M.find(modname, opts)
  opts = opts or {}

  modname = modname:gsub('/', '.')
  local basename = modname:gsub('%.', '/')
  local idx = modname:find('.', 1, true)

  -- HACK: fix incorrect require statements. Really not a fan of keeping this,
  -- but apparently the regular Lua loader also allows this
  if idx == 1 then
    modname = modname:gsub('^%.+', '')
    basename = modname:gsub('%.', '/')
    idx = modname:find('.', 1, true)
  end

  -- get the top-level module name
  local topmod = idx and modname:sub(1, idx - 1) or modname

  -- OPTIM: search for a directory first when topmod == modname
  local patterns = opts.patterns
    or (topmod == modname and { '/init.lua', '.lua' } or { '.lua', '/init.lua' })
  for p, pattern in ipairs(patterns) do
    patterns[p] = '/lua/' .. basename .. pattern
  end

  --- @type vim.loader.ModuleInfo[]
  local results = {}

  -- Only continue if we haven't found anything yet or we want to find all
  local function continue()
    return #results == 0 or opts.all
  end

  -- Checks if the given paths contain the top-level module.
  -- If so, it tries to find the module path for the given module name.
  --- @param paths string[]
  local function _find(paths)
    for _, path in ipairs(paths) do
      if topmod == '*' then
        for _, r in pairs(lsmod(path)) do
          results[#results + 1] = r
          if not continue() then
            return
          end
        end
      elseif lsmod(path)[topmod] then
        for _, pattern in ipairs(patterns) do
          local modpath = path .. pattern
          stats.find.stat = (stats.find.stat or 0) + 1
          local stat = fs_stat_cached(modpath)
          if stat then
            results[#results + 1] = { modpath = modpath, stat = stat, modname = modname }
            if not continue() then
              return
            end
          end
        end
      end
    end
  end

  -- always check the rtp first
  if opts.rtp ~= false then
    _find(rtp_cached or {})
    if continue() then
      local rtp, updated = get_rtp()
      if updated then
        _find(rtp)
      end
    end
  end

  -- check any additional paths
  if continue() and opts.paths then
    _find(opts.paths)
  end

  if #results == 0 then
    -- module not found
    stats.find.not_found = stats.find.not_found + 1
  end

  return results
end

--- Resets the cache for the path, or all the paths if path is nil.
---
--- @since 0
---
--- @param path string? path to reset
function M.reset(path)
  if path then
    indexed[normalize(path)] = nil
  else
    indexed = {}
  end

  -- Path could be a directory so just clear all the hashes.
  if fs_stat_cache then
    fs_stat_cache = {}
  end
end

--- Enables the experimental Lua module loader:
--- * overrides loadfile
--- * adds the Lua loader using the byte-compilation cache
--- * adds the libs loader
--- * removes the default Nvim loader
---
--- @since 0
function M.enable()
  if M.enabled then
    return
  end
  M.enabled = true
  vim.fn.mkdir(vim.fn.fnamemodify(M.path, ':p'), 'p')
  _G.loadfile = loadfile_cached
  -- add Lua loader
  table.insert(loaders, 2, loader_cached)
  -- add libs loader
  table.insert(loaders, 3, loader_lib_cached)
  -- remove Nvim loader
  for l, loader in ipairs(loaders) do
    if loader == vim._load_package then
      table.remove(loaders, l)
      break
    end
  end
end

--- Disables the experimental Lua module loader:
--- * removes the loaders
--- * adds the default Nvim loader
---
--- @since 0
function M.disable()
  if not M.enabled then
    return
  end
  M.enabled = false
  _G.loadfile = _loadfile
  for l, loader in ipairs(loaders) do
    if loader == loader_cached or loader == loader_lib_cached then
      table.remove(loaders, l)
    end
  end
  table.insert(loaders, 2, vim._load_package)
end

--- Tracks the time spent in a function
--- @generic F: function
--- @param f F
--- @return F
local function track(stat, f)
  return function(...)
    local start = vim.uv.hrtime()
    local r = { f(...) }
    stats[stat] = stats[stat] or { total = 0, time = 0 }
    stats[stat].total = stats[stat].total + 1
    stats[stat].time = stats[stat].time + uv.hrtime() - start
    return unpack(r, 1, table.maxn(r))
  end
end

--- @class (private) vim.loader._profile.Opts
--- @field loaders? boolean Add profiling to the loaders

--- Debug function that wraps all loaders and tracks stats
--- Must be called before vim.loader.enable()
--- @private
--- @param opts vim.loader._profile.Opts?
function M._profile(opts)
  get_rtp = track('get_rtp', get_rtp)
  read_cachefile = track('read', read_cachefile)
  loader_cached = track('loader', loader_cached)
  loader_lib_cached = track('loader_lib', loader_lib_cached)
  loadfile_cached = track('loadfile', loadfile_cached)
  M.find = track('find', M.find)
  lsmod = track('lsmod', lsmod)

  if opts and opts.loaders then
    for l, loader in pairs(loaders) do
      local loc = debug.getinfo(loader, 'Sn').source:sub(2)
      loaders[l] = track('loader ' .. l .. ': ' .. loc, loader)
    end
  end
end

--- Prints all cache stats
--- @param opts? {print?:boolean}
--- @return vim.loader.Stats
--- @private
function M._inspect(opts)
  if opts and opts.print then
    local function ms(nsec)
      return math.floor(nsec / 1e6 * 1000 + 0.5) / 1000 .. 'ms'
    end
    local chunks = {} --- @type string[][]
    for _, stat in vim.spairs(stats) do
      vim.list_extend(chunks, {
        { '\n' .. stat .. '\n', 'Title' },
        { '* total:    ' },
        { tostring(stat.total) .. '\n', 'Number' },
        { '* time:     ' },
        { ms(stat.time) .. '\n', 'Bold' },
        { '* avg time: ' },
        { ms(stat.time / stat.total) .. '\n', 'Bold' },
      })
      for k, v in pairs(stat) do
        if not vim.list_contains({ 'time', 'total' }, k) then
          chunks[#chunks + 1] = { '* ' .. k .. ':' .. string.rep(' ', 9 - #k) }
          chunks[#chunks + 1] = { tostring(v) .. '\n', 'Number' }
        end
      end
    end
    vim.api.nvim_echo(chunks, true, {})
  end
  return stats
end

return M
