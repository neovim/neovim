local N_ = vim.fn.gettext

local M = {}

--- @param seconds integer Time in seconds.
--- @param seconds_in_unit integer How many seconds make up the unit.
--- @param singular string The singular name of the unit. ("1 second")
--- @param fplural string The plural name of the unit, to format. ("%s seconds")
--- @return string
local function fmt_unit(seconds, seconds_in_unit, singular, fplural)
  local count = math.floor(seconds / seconds_in_unit)
  return count == 1 and singular or fplural:format(count)
end

--- Display seconds in a pretty form, in the largest unit: 3978 => "1 hour".
---
--- @param seconds integer Time in seconds.
--- @return string time Pretty representation of the time.
function M.fmt_rtime(seconds)
  if seconds >= 86400 then
    return fmt_unit(seconds, 86400, N_('1 day'), N_('%s days'))
  elseif seconds >= 3600 then
    return fmt_unit(seconds, 3600, N_('1 hour'), N_('%s hours'))
  elseif seconds >= 60 then
    return fmt_unit(seconds, 60, N_('1 minute'), N_('%s minutes'))
  end
  return fmt_unit(seconds, 1, N_('1 second'), N_('%s seconds'))
end

--- Display a timestamp relative to now (e.g. "3 minutes ago", or "just now" within a minute).
---
--- @param ns integer Nanoseconds since epoch, e.g. |v:useractive|.
--- @return string time Human-readable representation of the relative time.
function M.fmt_ago(ns)
  local seconds = os.time() - math.floor(ns / 1e9)
  return seconds < 60 and N_('just now') or N_('%s ago'):format(M.fmt_rtime(seconds))
end

return M
