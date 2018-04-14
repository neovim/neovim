local helpers = require('test.functional.helpers')(after_each)

local command = helpers.command
local meths = helpers.meths
local clear = helpers.clear
local sleep = helpers.sleep
local wait = helpers.wait
local feed = helpers.feed
local eq = helpers.eq

local dur
local min_dur = 8
local len = 131072

describe('List support code', function()
  if not pending('does not actually allows interrupting with just got_int', function() end) then return end
  -- The following tests are confirmed to work with os_breakcheck() just before
  -- `if (got_int) {break;}` in tv_list_copy and list_join_inner() and not to
  -- work without.
  setup(function()
    clear()
    dur = 0
    while true do
      command(([[
        let rt = reltime()
        let bl = range(%u)
        let dur = reltimestr(reltime(rt))
      ]]):format(len))
      dur = tonumber(meths.get_var('dur'))
      if dur >= min_dur then
        -- print(('Using len %u, dur %g'):format(len, dur))
        break
      else
        len = len * 2
      end
    end
  end)
  it('allows interrupting copy', function()
    feed(':let t_rt = reltime()<CR>:let t_bl = copy(bl)<CR>')
    sleep(min_dur / 16 * 1000)
    feed('<C-c>')
    wait()
    command('let t_dur = reltimestr(reltime(t_rt))')
    local t_dur = tonumber(meths.get_var('t_dur'))
    if t_dur >= dur / 8 then
      eq(nil, ('Took too long to cancel: %g >= %g'):format(t_dur, dur / 8))
    end
  end)
  it('allows interrupting join', function()
    feed(':let t_rt = reltime()<CR>:let t_j = join(bl)<CR>')
    sleep(min_dur / 16 * 1000)
    feed('<C-c>')
    wait()
    command('let t_dur = reltimestr(reltime(t_rt))')
    local t_dur = tonumber(meths.get_var('t_dur'))
    print(('t_dur: %g'):format(t_dur))
    if t_dur >= dur / 8 then
      eq(nil, ('Took too long to cancel: %g >= %g'):format(t_dur, dur / 8))
    end
  end)
end)
