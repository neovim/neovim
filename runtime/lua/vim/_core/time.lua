local N_ = vim.fn.gettext

local M = {}

--- @param seconds_in_unit integer How many seconds make up the unit.
--- @param singular string The singular name of the unit. ("1 second")
--- @param fplural string The plural name of the unit, to format. ("%s seconds")
--- @param times string[] Working list of uptime strings.
--- @param remaining integer Remaining time, in seconds.
--- @return integer remaining Remaining time.
local function time_part(seconds_in_unit, singular, fplural, times, remaining)
  local unit = math.floor(remaining / seconds_in_unit)
  if unit ~= 0 or #times ~= 0 or seconds_in_unit == 1 then
    local display = unit == 1 and singular or fplural:format(unit)
    times[#times + 1] = display
  end
  return remaining % seconds_in_unit
end

--- Display seconds in a pretty form (e.g. "1 hour, 24 minutes, 13 seconds").
---
--- @param seconds integer Time in seconds.
--- @return string time Pretty representation of the time.
function M.fmt_rtime(seconds)
  local times = {}
  seconds = time_part(86400, N_('1 day'), N_('%s days'), times, seconds)
  seconds = time_part(3600, N_('1 hour'), N_('%s hours'), times, seconds)
  seconds = time_part(60, N_('1 minute'), N_('%s minutes'), times, seconds)
  seconds = time_part(1, N_('1 second'), N_('%s seconds'), times, seconds)
  assert(seconds == 0)

  return table.concat(times, ', ')
end

return M
