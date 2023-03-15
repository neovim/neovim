local uv = vim.loop

local M = {}

---@alias CacheHash {mtime: {sec:number, nsec:number}, size:number}
---@alias CacheEntry {hash:CacheHash, chunk:string}

---@class ModuleFindOpts
---@field all? boolean Search for all matches (defaults to `false`)
---@field rtp? boolean Search for modname in the runtime path (defaults to `true`)
---@field patterns? string[] Paterns to use (defaults to `{"/init.lua", ".lua"}`)
---@field paths? string[] Extra paths to search for modname

---@class ModuleInfo
---@field modpath string Path of the module
---@field modname string Name of the module
---@field stat? uv_fs_t File stat of the module path

---@alias LoaderStats table<string, {total:number, time:number, [string]:number?}?>

M.path = vim.fn.stdpath('cache') .. '/luac'
M.enabled = false

---@class Loader
---@field _rtp string[]
---@field _rtp_pure string[]
---@field _rtp_key string
local Loader = {
  VERSION = 3,
  ---@type table<string, table<string,ModuleInfo>>
  _indexed = {},
  ---@type table<string, string[]>
  _topmods = {},
  _loadfile = loadfile,
  ---@type LoaderStats
  _stats = {
    find = { total = 0, time = 0, not_found = 0 },
  },
}

--- Tracks the time spent in a function
---@private
function Loader.track(stat, start)
  Loader._stats[stat] = Loader._stats[stat] or { total = 0, time = 0 }
  Loader._stats[stat].total = Loader._stats[stat].total + 1
  Loader._stats[stat].time = Loader._stats[stat].time + uv.hrtime() - start
end

--- slightly faster/different version than vim.fs.normalize
--- we also need to have it here, since the loader will load vim.fs
---@private
function Loader.normalize(path)
  if path:sub(1, 1) == '~' then
    local home = vim.loop.os_homedir() or '~'
    if home:sub(-1) == '\\' or home:sub(-1) == '/' then
      home = home:sub(1, -2)
    end
    path = home .. path:sub(2)
  end
  path = path:gsub('\\', '/'):gsub('/+', '/')
  return path:sub(-1) == '/' and path:sub(1, -2) or path
end

--- Gets the rtp excluding after directories.
--- The result is cached, and will be updated if the runtime path changes.
--- When called from a fast event, the cached value will be returned.
--- @return string[] rtp, boolean updated
---@private
function Loader.get_rtp()
  local start = uv.hrtime()
  if vim.in_fast_event() then
    Loader.track('get_rtp', start)
    return (Loader._rtp or {}), false
  end
  local updated = false
  local key = vim.go.rtp
  if key ~= Loader._rtp_key then
    Loader._rtp = {}
    for _, path in ipairs(vim.api.nvim_get_runtime_file('', true)) do
      path = Loader.normalize(path)
      -- skip after directories
      if
        path:sub(-6, -1) ~= '/after'
        and not (Loader._indexed[path] and vim.tbl_isempty(Loader._indexed[path]))
      then
        Loader._rtp[#Loader._rtp + 1] = path
      end
    end
    updated = true
    Loader._rtp_key = key
  end
  Loader.track('get_rtp', start)
  return Loader._rtp, updated
end

--- Returns the cache file name
---@param name string can be a module name, or a file name
---@return string file_name
---@private
function Loader.cache_file(name)
  local ret = M.path .. '/' .. name:gsub('[/\\:]', '%%')
  return ret:sub(-4) == '.lua' and (ret .. 'c') or (ret .. '.luac')
end

--- Saves the cache entry for a given module or file
---@param name string module name or filename
---@param entry CacheEntry
---@private
function Loader.write(name, entry)
  local cname = Loader.cache_file(name)
  local f = assert(uv.fs_open(cname, 'w', 438))
  local header = {
    Loader.VERSION,
    entry.hash.size,
    entry.hash.mtime.sec,
    entry.hash.mtime.nsec,
  }
  uv.fs_write(f, table.concat(header, ',') .. '\0')
  uv.fs_write(f, entry.chunk)
  uv.fs_close(f)
end

--- Loads the cache entry for a given module or file
---@param name string module name or filename
---@return CacheEntry?
---@private
function Loader.read(name)
  local start = uv.hrtime()
  local cname = Loader.cache_file(name)
  local f = uv.fs_open(cname, 'r', 438)
  if f then
    local hash = uv.fs_fstat(f) --[[@as CacheHash]]
    local data = uv.fs_read(f, hash.size, 0) --[[@as string]]
    uv.fs_close(f)

    local zero = data:find('\0', 1, true)
    if not zero then
      return
    end

    ---@type integer[]|{[0]:integer}
    local header = vim.split(data:sub(1, zero - 1), ',')
    if tonumber(header[1]) ~= Loader.VERSION then
      return
    end
    Loader.track('read', start)
    return {
      hash = {
        size = tonumber(header[2]),
        mtime = { sec = tonumber(header[3]), nsec = tonumber(header[4]) },
      },
      chunk = data:sub(zero + 1),
    }
  end
  Loader.track('read', start)
end

--- The `package.loaders` loader for lua files using the cache.
---@param modname string module name
---@return string|function
---@private
function Loader.loader(modname)
  local start = uv.hrtime()
  local ret = M.find(modname)[1]
  if ret then
    local chunk, err = Loader.load(ret.modpath, { hash = ret.stat })
    Loader.track('loader', start)
    return chunk or error(err)
  end
  Loader.track('loader', start)
  return '\ncache_loader: module ' .. modname .. ' not found'
end

--- The `package.loaders` loader for libs
---@param modname string module name
---@return string|function
---@private
function Loader.loader_lib(modname)
  local start = uv.hrtime()
  local sysname = uv.os_uname().sysname:lower() or ''
  local is_win = sysname:find('win', 1, true) and not sysname:find('darwin', 1, true)
  local ret = M.find(modname, { patterns = is_win and { '.dll' } or { '.so' } })[1]
  ---@type function?, string?
  if ret then
    -- Making function name in Lua 5.1 (see src/loadlib.c:mkfuncname) is
    -- a) strip prefix up to and including the first dash, if any
    -- b) replace all dots by underscores
    -- c) prepend "luaopen_"
    -- So "foo-bar.baz" should result in "luaopen_bar_baz"
    local dash = modname:find('-', 1, true)
    local funcname = dash and modname:sub(dash + 1) or modname
    local chunk, err = package.loadlib(ret.modpath, 'luaopen_' .. funcname:gsub('%.', '_'))
    Loader.track('loader_lib', start)
    return chunk or error(err)
  end
  Loader.track('loader_lib', start)
  return '\ncache_loader_lib: module ' .. modname .. ' not found'
end

--- `loadfile` using the cache
---@param filename? string
---@param mode? "b"|"t"|"bt"
---@param env? table
---@param hash? CacheHash
---@return function?, string?  error_message
---@private
-- luacheck: ignore 312
function Loader.loadfile(filename, mode, env, hash)
  local start = uv.hrtime()
  filename = Loader.normalize(filename)
  mode = nil -- ignore mode, since we byte-compile the lua source files
  local chunk, err = Loader.load(filename, { mode = mode, env = env, hash = hash })
  Loader.track('loadfile', start)
  return chunk, err
end

--- Checks whether two cache hashes are the same based on:
--- * file size
--- * mtime in seconds
--- * mtime in nanoseconds
---@param h1 CacheHash
---@param h2 CacheHash
---@private
function Loader.eq(h1, h2)
  return h1
    and h2
    and h1.size == h2.size
    and h1.mtime.sec == h2.mtime.sec
    and h1.mtime.nsec == h2.mtime.nsec
end

--- Loads the given module path using the cache
---@param modpath string
---@param opts? {hash?: CacheHash, mode?: "b"|"t"|"bt", env?:table} (table|nil) Options for loading the module:
---    - hash: (table) the hash of the file to load if it is already known. (defaults to `vim.loop.fs_stat({modpath})`)
---    - mode: (string) the mode to load the module with. "b"|"t"|"bt" (defaults to `nil`)
---    - env: (table) the environment to load the module in. (defaults to `nil`)
---@see |luaL_loadfile()|
---@return function?, string? error_message
---@private
function Loader.load(modpath, opts)
  local start = uv.hrtime()

  opts = opts or {}
  local hash = opts.hash or uv.fs_stat(modpath)
  ---@type function?, string?
  local chunk, err

  if not hash then
    -- trigger correct error
    chunk, err = Loader._loadfile(modpath, opts.mode, opts.env)
    Loader.track('load', start)
    return chunk, err
  end

  local entry = Loader.read(modpath)
  if entry and Loader.eq(entry.hash, hash) then
    -- found in cache and up to date
    chunk, err = load(entry.chunk --[[@as string]], '@' .. modpath, opts.mode, opts.env)
    if not (err and err:find('cannot load incompatible bytecode', 1, true)) then
      Loader.track('load', start)
      return chunk, err
    end
  end
  entry = { hash = hash, modpath = modpath }

  chunk, err = Loader._loadfile(modpath, opts.mode, opts.env)
  if chunk then
    entry.chunk = string.dump(chunk)
    Loader.write(modpath, entry)
  end
  Loader.track('load', start)
  return chunk, err
end

--- Finds lua modules for the given module name.
---@param modname string Module name, or `"*"` to find the top-level modules instead
---@param opts? ModuleFindOpts (table|nil) Options for finding a module:
---    - rtp: (boolean) Search for modname in the runtime path (defaults to `true`)
---    - paths: (string[]) Extra paths to search for modname (defaults to `{}`)
---    - patterns: (string[]) List of patterns to use when searching for modules.
---                A pattern is a string added to the basename of the Lua module being searched.
---                (defaults to `{"/init.lua", ".lua"}`)
---    - all: (boolean) Return all matches instead of just the first one (defaults to `false`)
---@return ModuleInfo[] (list) A list of results with the following properties:
---    - modpath: (string) the path to the module
---    - modname: (string) the name of the module
---    - stat: (table|nil) the fs_stat of the module path. Won't be returned for `modname="*"`
function M.find(modname, opts)
  local start = uv.hrtime()
  opts = opts or {}

  modname = modname:gsub('/', '.')
  local basename = modname:gsub('%.', '/')
  local idx = modname:find('.', 1, true)

  -- HACK: fix incorrect require statements. Really not a fan of keeping this,
  -- but apparently the regular lua loader also allows this
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

  ---@type ModuleInfo[]
  local results = {}

  -- Only continue if we haven't found anything yet or we want to find all
  ---@private
  local function continue()
    return #results == 0 or opts.all
  end

  -- Checks if the given paths contain the top-level module.
  -- If so, it tries to find the module path for the given module name.
  ---@param paths string[]
  ---@private
  local function _find(paths)
    for _, path in ipairs(paths) do
      if topmod == '*' then
        for _, r in pairs(Loader.lsmod(path)) do
          results[#results + 1] = r
          if not continue() then
            return
          end
        end
      elseif Loader.lsmod(path)[topmod] then
        for _, pattern in ipairs(patterns) do
          local modpath = path .. pattern
          Loader._stats.find.stat = (Loader._stats.find.stat or 0) + 1
          local hash = uv.fs_stat(modpath)
          if hash then
            results[#results + 1] = { modpath = modpath, stat = hash, modname = modname }
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
    _find(Loader._rtp or {})
    if continue() then
      local rtp, updated = Loader.get_rtp()
      if updated then
        _find(rtp)
      end
    end
  end

  -- check any additional paths
  if continue() and opts.paths then
    _find(opts.paths)
  end

  Loader.track('find', start)
  if #results == 0 then
    -- module not found
    Loader._stats.find.not_found = Loader._stats.find.not_found + 1
  end

  return results
end

--- Resets the topmods cache for the path, or all the paths
--- if path is nil.
---@param path string? path to reset
function M.reset(path)
  if path then
    Loader._indexed[Loader.normalize(path)] = nil
  else
    Loader._indexed = {}
  end
end

--- Enables the experimental Lua module loader:
--- * overrides loadfile
--- * adds the lua loader using the byte-compilation cache
--- * adds the libs loader
--- * removes the default Neovim loader
function M.enable()
  if M.enabled then
    return
  end
  M.enabled = true
  vim.fn.mkdir(vim.fn.fnamemodify(M.path, ':p'), 'p')
  _G.loadfile = Loader.loadfile
  -- add lua loader
  table.insert(package.loaders, 2, Loader.loader)
  -- add libs loader
  table.insert(package.loaders, 3, Loader.loader_lib)
  -- remove Neovim loader
  for l, loader in ipairs(package.loaders) do
    if loader == vim._load_package then
      table.remove(package.loaders, l)
      break
    end
  end

  -- this will reset the top-mods in case someone adds a new
  -- top-level lua module to a path already on the rtp
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = vim.api.nvim_create_augroup('cache_topmods_reset', { clear = true }),
    callback = function(event)
      local bufname = event.match ---@type string
      local idx = bufname:find('/lua/', 1, true)
      if idx then
        M.reset(bufname:sub(1, idx - 1))
      end
    end,
  })
end

--- Disables the experimental Lua module loader:
--- * removes the loaders
--- * adds the default Neovim loader
function M.disable()
  if not M.enabled then
    return
  end
  M.enabled = false
  _G.loadfile = Loader._loadfile
  ---@diagnostic disable-next-line: no-unknown
  for l, loader in ipairs(package.loaders) do
    if loader == Loader.loader or loader == Loader.loader_lib then
      table.remove(package.loaders, l)
    end
  end
  table.insert(package.loaders, 2, vim._load_package)
  vim.api.nvim_del_augroup_by_name('cache_topmods_reset')
end

--- Return the top-level `/lua/*` modules for this path
---@param path string path to check for top-level lua modules
---@private
function Loader.lsmod(path)
  if not Loader._indexed[path] then
    local start = uv.hrtime()
    Loader._indexed[path] = {}
    local handle = vim.loop.fs_scandir(path .. '/lua')
    while handle do
      local name, t = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end
      local modpath = path .. '/lua/' .. name
      -- HACK: type is not always returned due to a bug in luv
      t = t or uv.fs_stat(modpath).type
      ---@type string
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
        Loader._indexed[path][topname] = { modpath = modpath, modname = topname }
        Loader._topmods[topname] = Loader._topmods[topname] or {}
        if not vim.tbl_contains(Loader._topmods[topname], path) then
          table.insert(Loader._topmods[topname], path)
        end
      end
    end
    Loader.track('lsmod', start)
  end
  return Loader._indexed[path]
end

--- Debug function that wrapps all loaders and tracks stats
---@private
function M._profile_loaders()
  for l, loader in pairs(package.loaders) do
    local loc = debug.getinfo(loader, 'Sn').source:sub(2)
    package.loaders[l] = function(modname)
      local start = vim.loop.hrtime()
      local ret = loader(modname)
      Loader.track('loader ' .. l .. ': ' .. loc, start)
      Loader.track('loader_all', start)
      return ret
    end
  end
end

--- Prints all cache stats
---@param opts? {print?:boolean}
---@return LoaderStats
---@private
function M._inspect(opts)
  if opts and opts.print then
    ---@private
    local function ms(nsec)
      return math.floor(nsec / 1e6 * 1000 + 0.5) / 1000 .. 'ms'
    end
    local chunks = {} ---@type string[][]
    ---@type string[]
    local stats = vim.tbl_keys(Loader._stats)
    table.sort(stats)
    for _, stat in ipairs(stats) do
      vim.list_extend(chunks, {
        { '\n' .. stat .. '\n', 'Title' },
        { '* total:    ' },
        { tostring(Loader._stats[stat].total) .. '\n', 'Number' },
        { '* time:     ' },
        { ms(Loader._stats[stat].time) .. '\n', 'Bold' },
        { '* avg time: ' },
        { ms(Loader._stats[stat].time / Loader._stats[stat].total) .. '\n', 'Bold' },
      })
      for k, v in pairs(Loader._stats[stat]) do
        if not vim.tbl_contains({ 'time', 'total' }, k) then
          chunks[#chunks + 1] = { '* ' .. k .. ':' .. string.rep(' ', 9 - #k) }
          chunks[#chunks + 1] = { tostring(v) .. '\n', 'Number' }
        end
      end
    end
    vim.api.nvim_echo(chunks, true, {})
  end
  return Loader._stats
end

return M
