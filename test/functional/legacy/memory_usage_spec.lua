local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eval = helpers.eval
local eq = helpers.eq
local feed_command = helpers.feed_command
local iswin = helpers.iswin
local retry = helpers.retry
local ok = helpers.ok
local source = helpers.source
local poke_eventloop = helpers.poke_eventloop
local uname = helpers.uname
local load_adjust = helpers.load_adjust
local isCI = helpers.isCI

local function isasan()
  local version = eval('execute("version")')
  return version:match('-fsanitize=[a-z,]*address')
end

clear()
if isasan() then
  pending('ASAN build is difficult to estimate memory usage', function() end)
  return
elseif iswin() then
  if isCI('github') then
    pending('Windows runners in Github Actions do not have a stable environment to estimate memory usage', function() end)
    return
  elseif eval("executable('wmic')") == 0 then
    pending('missing "wmic" command', function() end)
    return
  end
elseif eval("executable('ps')") == 0 then
  pending('missing "ps" command', function() end)
  return
end

local monitor_memory_usage = {
  memory_usage = function(self)
    local handle
    if iswin() then
      handle = io.popen('wmic process where processid=' ..self.pid..' get WorkingSetSize')
    else
      handle = io.popen('ps -o rss= -p '..self.pid)
    end
    return tonumber(handle:read('*a'):match('%d+'))
  end,
  op = function(self)
    retry(nil, 10000, function()
      local val = self.memory_usage(self)
      if self.max < val then
        self.max = val
      end
      table.insert(self.hist, val)
      ok(#self.hist > 20)
      local result = {}
      for key,value in ipairs(self.hist) do
        if value ~= self.hist[key + 1] then
          table.insert(result, value)
        end
      end
      table.remove(self.hist, 1)
      self.last = self.hist[#self.hist]
      eq(#result, 1)
    end)
  end,
  dump = function(self)
    return 'max: '..self.max ..', last: '..self.last
  end,
  monitor_memory_usage = function(self, pid)
    local obj = {
      pid = pid,
      max = 0,
      last = 0,
      hist = {},
    }
    setmetatable(obj, { __index = self })
    obj:op()
    return obj
  end
}
setmetatable(monitor_memory_usage,
{__call = function(self, pid)
  return monitor_memory_usage.monitor_memory_usage(self, pid)
end})

describe('memory usage', function()
  local function check_result(tbl, status, result)
    if not status then
      print('')
      for key, val in pairs(tbl) do
        print(key, val:dump())
      end
      error(result)
    end
  end

  before_each(clear)

  --[[
  Case: if a local variable captures a:000, funccall object will be free
  just after it finishes.
  ]]--
  it('function capture vargs', function()
    local pid = eval('getpid()')
    local before = monitor_memory_usage(pid)
    source([[
      func s:f(...)
        let x = a:000
      endfunc
      for _ in range(10000)
        call s:f(0)
      endfor
    ]])
    poke_eventloop()
    local after = monitor_memory_usage(pid)
    -- Estimate the limit of max usage as 2x initial usage.
    -- The lower limit can fluctuate a bit, use 97%.
    check_result({before=before, after=after},
                 pcall(ok, before.last * 97 / 100 < after.max))
    check_result({before=before, after=after},
                 pcall(ok, before.last * 2 > after.max))
    -- In this case, garbage collecting is not needed.
    -- The value might fluctuate a bit, allow for 3% tolerance below and 5% above.
    -- Based on various test runs.
    local lower = after.last * 97 / 100
    local upper = after.last * 105 / 100
    check_result({before=before, after=after}, pcall(ok, lower < after.max))
    check_result({before=before, after=after}, pcall(ok, after.max < upper))
  end)

  --[[
  Case: if a local variable captures l: dict, funccall object will not be
  free until garbage collector runs, but after that memory usage doesn't
  increase so much even when rerun Xtest.vim since system memory caches.
  ]]--
  it('function capture lvars', function()
    local pid = eval('getpid()')
    local before = monitor_memory_usage(pid)
    local fname = source([[
      if !exists('s:defined_func')
        func s:f()
          let x = l:
        endfunc
      endif
      let s:defined_func = 1
      for _ in range(10000)
        call s:f()
      endfor
    ]])
    poke_eventloop()
    local after = monitor_memory_usage(pid)
    for _ = 1, 3 do
      feed_command('so '..fname)
      poke_eventloop()
    end
    local last = monitor_memory_usage(pid)
    -- The usage may be a bit less than the last value, use 80%.
    -- Allow for 20% tolerance at the upper limit. That's very permissive, but
    -- otherwise the test fails sometimes.  On Sourcehut CI with FreeBSD we need to
    -- be even much more permissive.
    local upper_multiplier = uname() == 'freebsd' and 19 or 12
    local lower = before.last * 8 / 10
    local upper = load_adjust((after.max + (after.last - before.last)) * upper_multiplier / 10)
    check_result({before=before, after=after, last=last},
                 pcall(ok, lower < last.last))
    check_result({before=before, after=after, last=last},
                 pcall(ok, last.last < upper))
  end)
end)
