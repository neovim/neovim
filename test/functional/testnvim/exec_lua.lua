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

--- This is run in the context of the remote Nvim instance.
--- @param bytecode string
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
  local stat, rv = session:request(
    'nvim_exec_lua',
    [[return { require('test.functional.testnvim.exec_lua').handler(...) }]],
    { string.dump(code), get_upvalues(code), ... }
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
