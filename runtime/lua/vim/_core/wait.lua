local pack_len = require('vim.F').pack_len
local uv = vim.uv

local has_editor_loop = vim._core.loop_poll ~= nil

--- Waits up to `time` milliseconds, until `callback` returns `true` (success). Executes
--- `callback` immediately, then on user events, internal events, and approximately every
--- `interval` milliseconds (default 200). Returns `true` plus any remaining callback
--- results on success.
---
--- Nvim processes other events while waiting.
--- Cannot be called during an |api-fast| event.
--- In standalone `nvim -ll` mode this polls the standalone luv loop, so `fast_only`
--- has no effect and interrupts are not reported.
---
--- Examples:
---
--- ```lua
--- -- Wait for 100 ms, allowing other events to process.
--- vim.wait(100)
---
--- -- Wait up to 1000 ms or until `vim.g.foo` is true, at intervals of ~500 ms.
--- vim.wait(1000, function() return vim.g.foo end, 500)
---
--- -- Wait indefinitely until `vim.g.foo` is true, and get the callback results.
--- local ok, rv1, rv2, rv3 = vim.wait(math.huge, function()
---   return vim.g.foo, 'a', 42, { ok = { 'yes' } }
--- end)
---
--- -- Schedule a function to set a value in 100ms. This would wait 10s if blocked, but actually
--- -- only waits 100ms because `vim.wait` processes other events while waiting.
--- vim.defer_fn(function() vim.g.timer_result = true end, 100)
--- if vim.wait(10000, function() return vim.g.timer_result end) then
---   print('Only waiting a little bit of time!')
--- end
--- ```
---
--- @param time number Number of milliseconds to wait. Must be non-negative number, any fractional
--- part is truncated.
--- @param callback? fun(): boolean, ... Optional callback. Waits until {callback} returns true
--- @param interval? integer (Approximate) number of milliseconds to wait between polls
--- @param fast_only? boolean If true, only |api-fast| events will be processed.
--- @return boolean, nil|-1|-2, ...
---     - If callback returns `true` before timeout: `true, ...` (remaining callback results).
---     - On timeout: `false, -1`
---     - On interrupt: `false, -2`
---     - On error: the error is raised.
function vim.wait(time, callback, interval, fast_only)
  if vim.in_fast_event and vim.in_fast_event() then
    error('E5560: vim.wait must not be called in a fast event context', 0)
  end

  vim.validate('time', time, 'number')
  if time < 0 then
    error('timeout must be >= 0')
  end
  local has_deadline = time == time and time ~= math.huge
  if has_deadline then
    time = math.floor(time)
  end

  vim.validate('callback', callback, 'callable', true)

  vim.validate('interval', interval, 'number', true)
  if interval then
    interval = math.floor(interval)
    if interval < 0 then
      error('interval must be >= 0')
    end
  else
    interval = 200
  end

  vim.validate('fast_only', fast_only, 'boolean', true)
  if fast_only == nil then
    fast_only = false
  end

  local start = uv.hrtime()
  local timer --- @type uv.uv_timer_t?

  local function cleanup()
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end

  if interval > 0 then
    timer = assert(uv.new_timer())

    if has_editor_loop then
      timer:start(interval, interval, function()
        -- If Nvim exits while loop_poll() is blocked, vim.wait() does not
        -- resume.
        if vim.v.exiting ~= vim.NIL then
          cleanup()
        end
      end)
    end
  end

  if has_editor_loop then
    -- Flush screen updates before blocking.
    vim._core.ui_flush()
  end

  while true do
    if has_editor_loop and vim._core.check_interrupt() then
      cleanup()
      return false, -2
    end

    if callback then
      local results = pack_len(pcall(callback))
      if not results[1] then
        cleanup()
        error(results[2], 0)
      elseif results[2] then
        cleanup()
        return true, unpack(results, 3, results.n)
      end
    end

    local remaining_timeout = -1
    if has_deadline then
      local remaining_ms = time - (uv.hrtime() - start) / 1e6
      if remaining_ms <= 0 then
        cleanup()
        return false, -1
      end

      -- loop_poll() takes an integer timeout, so cap each individual poll
      -- while still honoring larger overall waits.
      remaining_timeout = math.min(math.ceil(remaining_ms), vim._maxint)
    end

    if has_editor_loop then
      -- The dummy timer wakes `vim._core.loop_poll()` on interval boundaries.
      -- Without it, polling would only resume for unrelated events or the final timeout.
      vim._core.loop_poll(remaining_timeout, fast_only)
    else
      -- `uv.run('once')` does not provide a bounded sleep by itself. This timer is
      -- our explicit wakeup so polling still advances when no other uv handle does.
      if timer then
        local delay = has_deadline and math.min(interval, remaining_timeout) or interval
        timer:start(delay, 0, function() end)
      end
      uv.run('once')
      if timer then
        timer:stop()
      end
    end
  end
end
