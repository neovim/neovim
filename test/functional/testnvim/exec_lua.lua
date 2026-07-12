--- @param f function
--- @return table<string,any>
local function get_upvalues(f)
  local i = 1
  local upvalues = {} --- @type table<string,any>
  while true do
    local n, v = debug.getupvalue(f, i)
    if not n then
      break
    end
    upvalues[n] = v
    i = i + 1
  end
  return upvalues
end

--- @param f function
--- @param upvalues table<string,any>
local function set_upvalues(f, upvalues)
  local i = 1
  while true do
    local n = debug.getupvalue(f, i)
    if not n then
      break
    end
    if upvalues[n] then
      debug.setupvalue(f, i, upvalues[n])
    end
    i = i + 1
  end
end

--- @param messages string[]
--- @param ... ...
local function add_print(messages, ...)
  local msg = {} --- @type string[]
  for i = 1, select('#', ...) do
    msg[#msg + 1] = tostring(select(i, ...))
  end
  table.insert(messages, table.concat(msg, '\t'))
end

local invalid_types = {
  ['thread'] = true,
  ['function'] = true,
  ['userdata'] = true,
}

--- @param r any[]
local function check_returns(r)
  for k, v in pairs(r) do
    if invalid_types[type(v)] then
      error(
        string.format(
          "Return index %d with value '%s' of type '%s' cannot be serialized over RPC",
          k,
          tostring(v),
          type(v)
        ),
        2
      )
    end
  end
end

local M = {}

--- Recovers the source text of an inline function, for targets whose Lua VM
--- cannot load this process's bytecode (the wasm build runs PUC Lua 5.1 in a
--- 32-bit VM; neither LuaJIT bytecode nor a 64-bit PUC dump loads there).
--- Returns a chunk that, when run, yields a function equivalent to `f`: the
--- function's upvalue names are declared as locals wrapping the recompiled
--- function so debug.setupvalue() in the handler still finds them by name.
--- Returns nil if the source cannot be recovered (caller falls back to
--- string.dump).
--- @param f function
--- @return string?
local function func_source(f)
  local info = debug.getinfo(f, 'S')
  if not info or info.source:sub(1, 1) ~= '@' or info.linedefined <= 0 then
    return nil
  end
  local fd = io.open(info.source:sub(2), 'r')
  if not fd then
    return nil
  end
  local lines = {} --- @type string[]
  local lnum = 0
  for line in fd:lines() do
    lnum = lnum + 1
    if lnum >= info.linedefined then
      lines[#lines + 1] = line
    end
    if lnum >= info.lastlinedefined then
      break
    end
  end
  fd:close()
  if #lines == 0 or lnum < info.lastlinedefined then
    return nil
  end
  -- Drop whatever precedes the `function` keyword on the first line
  -- (e.g. `exec_lua(function()` -> `function()`).
  local fpos = lines[1]:find('function', 1, true)
  if not fpos then
    return nil
  end
  lines[1] = lines[1]:sub(fpos)
  -- A named definition (`local function foo(...)`) is not valid as an
  -- expression: anonymize it. Colon methods get their implicit self back.
  local name, rest = lines[1]:match('^function%s+([%w_%.:]+)(%s*%(.*)$')
  if name then
    if name:find(':', 1, true) then
      local after = rest:match('^%s*%((.*)$')
      if after:match('^%s*%)') then
        lines[1] = 'function(self' .. after
      else
        lines[1] = 'function(self,' .. after
      end
    else
      lines[1] = 'function' .. rest
    end
  end
  -- Declare the upvalue names as locals so the recompiled function closes
  -- over real upvalue slots instead of falling back to global lookups.
  local upnames = {} --- @type string[]
  local i = 1
  while true do
    local n = debug.getupvalue(f, i)
    if not n then
      break
    end
    upnames[#upnames + 1] = n
    i = i + 1
  end
  local prefix = #upnames > 0 and ('local ' .. table.concat(upnames, ', ') .. '; ') or ''
  -- The last line usually carries trailing call-site text (`end)`, `end, 42)`).
  -- Chop from the end until the text compiles as an expression AND ends on the
  -- function's own `end` keyword. Compiling alone is not enough: a tail like
  -- `end, (cond() and 'a') or 'b')` chops to a valid multi-value return whose
  -- extra expressions would be EVALUATED remotely (where the call-site's
  -- locals don't exist).
  local text = table.concat(lines, '\n')
  while #text > 0 do
    if text:match('%f[%w_]end%s*$') and loadstring(prefix .. 'return ' .. text) then
      return prefix .. 'return ' .. text
    end
    text = text:sub(1, -2)
  end
  return nil
end

--- This is run in the context of the remote Nvim instance.
--- @param bytecode string bytecode of the function itself, or (source mode) a
--- chunk that returns the function when called
--- @param upvalues table<string,any>
--- @param ... any[]
--- @return any[] result
--- @return table<string,any> upvalues
--- @return string[] messages
function M.handler(bytecode, upvalues, ...)
  local messages = {} --- @type string[]
  local orig_print = _G.print

  function _G.print(...)
    add_print(messages, ...)
    return orig_print(...)
  end

  local f = assert(loadstring(bytecode))
  if bytecode:sub(1, 1) ~= '\27' then
    -- Source mode: the chunk returns the actual function.
    f = f()
  end

  set_upvalues(f, upvalues)

  -- Run in pcall so we can return any print messages
  local ret = { pcall(f, ...) } --- @type any[]

  _G.print = orig_print

  local new_upvalues = get_upvalues(f)

  -- Check return value types for better error messages
  check_returns(ret)

  return ret, new_upvalues, messages
end

--- @param session test.Session
--- @param lvl integer
--- @param code function
--- @param ... ...
local function run(session, lvl, code, ...)
  -- The wasm target's Lua VM (PUC 5.1, 32-bit) cannot load this process's
  -- bytecode; ship recovered source text instead (see func_source).
  local payload --- @type string?
  if os.getenv('NVIM_TEST_WASM') then
    payload = func_source(code)
  end
  payload = payload or string.dump(code)

  local stat, rv = session:request(
    'nvim_exec_lua',
    [[return { require('test.functional.testnvim.exec_lua').handler(...) }]],
    { payload, get_upvalues(code), ... }
  )

  if not stat then
    error(rv[2], 2)
  end

  --- @type any[], table<string,any>, string[]
  local ret, upvalues, messages = unpack(rv)

  for _, m in ipairs(messages) do
    print(m)
  end

  if not ret[1] then
    error(ret[2], 2)
  end

  -- Update upvalues
  if next(upvalues) then
    local caller = debug.getinfo(lvl)
    local i = 0

    -- On PUC-Lua, if the function is a tail call, then func will be nil.
    -- In this case we need to use the caller.
    while not caller.func do
      i = i + 1
      caller = debug.getinfo(lvl + i)
    end
    set_upvalues(caller.func, upvalues)
  end

  return unpack(ret, 2, table.maxn(ret))
end

return setmetatable(M, {
  __call = function(_, ...)
    return run(...)
  end,
})
