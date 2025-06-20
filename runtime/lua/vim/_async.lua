local M = {}

local max_timeout = 30000

--- @param thread thread
--- @param on_finish fun(err: string?, ...:any)
--- @param ... any
local function resume(thread, on_finish, ...)
  --- @type {n: integer, [1]:boolean, [2]:string|function}
  local ret = vim.F.pack_len(coroutine.resume(thread, ...))
  local stat = ret[1]

  if not stat then
    -- Coroutine had error
    on_finish(ret[2] --[[@as string]])
  elseif coroutine.status(thread) == 'dead' then
    -- Coroutine finished
    on_finish(nil, unpack(ret, 2, ret.n))
  else
    local fn = ret[2]
    --- @cast fn -string

    --- @type boolean, string?
    local ok, err = pcall(fn, function(...)
      resume(thread, on_finish, ...)
    end)

    if not ok then
      on_finish(err)
    end
  end
end

--- @param func async fun(): ...:any
--- @param on_finish? fun(err: string?, ...:any)
function M.run(func, on_finish)
  local res --- @type {n:integer, [integer]:any}?
  resume(coroutine.create(func), function(err, ...)
    res = vim.F.pack_len(err, ...)
    if on_finish then
      on_finish(err, ...)
    end
  end)

  return {
    --- @param timeout? integer
    --- @return any ... return values of `func`
    wait = function(_self, timeout)
      vim.wait(timeout or max_timeout, function()
        return res ~= nil
      end)
      assert(res, 'timeout')
      if res[1] then
        error(res[1])
      end
      return unpack(res, 2, res.n)
    end,
  }
end

--- Asynchronous blocking wait
--- @async
--- @param argc integer
--- @param fun function
--- @param ... any func arguments
--- @return any ...
function M.await(argc, fun, ...)
  assert(coroutine.running(), 'Async.await() must be called from an async function')
  local args = vim.F.pack_len(...) --- @type {n:integer, [integer]:any}

  --- @param callback fun(...:any)
  return coroutine.yield(function(callback)
    args[argc] = assert(callback)
    fun(unpack(args, 1, math.max(argc, args.n)))
  end)
end

--- @async
--- @param max_jobs integer
--- @param funs (async fun())[]
function M.join(max_jobs, funs)
  if #funs == 0 then
    return
  end

  max_jobs = math.min(max_jobs, #funs)

  --- @type (async fun())[]
  local remaining = { select(max_jobs + 1, unpack(funs)) }
  local to_go = #funs

  M.await(1, function(on_finish)
    local function run_next()
      to_go = to_go - 1
      if to_go == 0 then
        on_finish()
      elseif #remaining > 0 then
        local next_fun = table.remove(remaining)
        M.run(next_fun, run_next)
      end
    end

    for i = 1, max_jobs do
      M.run(funs[i], run_next)
    end
  end)
end

return M
