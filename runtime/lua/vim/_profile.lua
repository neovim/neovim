---
--- To profile everything:
---
--- ```lua
--- local orig_require = require
--- _G.require = function(m, ...)
---   local r = {orig_require(m, ...)}
---   profile(m, package.loaded)
---   return unpack(r, 1, table.maxn(r))
--- end
--- ```

local elapsed = {} --- @type table<string, number>
local calls = {} --- @type table<string, integer>
local enabled = true

local hrtime = vim.uv.hrtime

--- @type table<function, true>
local excludes = {}

for _, m in pairs({
  _G,
  lpeg, --- @diagnostic disable-line
  os,
  table,
  string,
  debug,
  io,
  math,
  bit,
  vim.uv,
  coroutine,
}) do
  for _, v in
    pairs(m --[[@as table<string,any>]])
  do
    if type(v) == 'function' then
      excludes[v] = true
    end
  end
end

--- @generic F: function
--- @param abs_n string
--- @param f F
--- @return F
local function instrument(abs_n, f)
  return function(...)
    local s = hrtime()
    local r = { f(...) }
    if enabled then
      elapsed[abs_n] = elapsed[abs_n] + hrtime() - s
      calls[abs_n] = calls[abs_n] + 1
    end
    return unpack(r, 1, table.maxn(r))
  end
end

local done = {} --- @type table<table,true>

local M = {}

--- Instrument profiling for all function reachable from a module.
---
--- If a module has _submodules field which is a table, it will
--- profile all keys in that table as submodules. This is useful for modules
--- which have deferred loading.
--- @param n string Module name to profile
--- @param mod? table<string, any> Parent module (default: _G)
--- @param m_nm? string Display name of module
function M.profile(n, mod, m_nm)
  local n_nm = (m_nm and m_nm .. '.' or '') .. n

  mod = mod or _G

  local x = mod[n]

  if type(x) == 'function' then
    if not excludes[x] then
      elapsed[n_nm] = 0
      calls[n_nm] = 0
      mod[n] = instrument(n_nm, x)
    end
    return
  end

  if type(x) ~= 'table' or done[x] then
    return
  end

  --- @cast x table<string,any>

  done[x] = true

  if n == '_submodules' then
    for k in pairs(x) do
      for n2 in pairs(mod) do
        if type(mod[k]) == 'table' then
          M.profile(n2, mod[k], m_nm .. '.' .. k)
        end
      end
    end
    return
  end

  for n2 in pairs(x) do
    M.profile(n2, x, n_nm)
  end
end

vim.api.nvim_create_user_command('ProfileReport', function(cargs)
  local args = cargs.args
  local elapsed1 = elapsed
  if args and #args > 0 then
    elapsed1 = { [args] = elapsed[args] }
    for n, t in pairs(elapsed) do
      if n:match(args) then
        elapsed1[n] = t
      end
    end
  end

  local r = {} --- @type [string,number][]
  local total = 0

  local pad = 0
  for n, t in pairs(elapsed1) do
    if calls[n] > 0 then
      r[#r + 1] = { n, t }
      pad = math.max(pad, #n)
      total = total + t
    end
  end

  table.sort(r, function(a, b)
    return a[2] > b[2]
  end)

  local br = ('─'):rep(pad + 30)

  print(br)
  print(('%%-%ds %%9s %%8s %%10s'):format(pad):format('name', 'total', 'count', 'avg'))
  print(br)
  print(('%%-%ds %%7.2fms'):format(pad):format('total', total / 1e6))
  print(br)

  for _, x in ipairs(r) do
    local n, t = x[1], x[2]
    local avg = (t / 1e3) / calls[n]
    print(('%%-%ds %%7.2fms %%8d %%8.2fus'):format(pad):format(n, t / 1e6, calls[n], avg))
  end
end, { nargs = '*' })

function M.start()
  enabled = true
end

function M.stop()
  enabled = false
end

return M
