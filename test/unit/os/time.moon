{time: lua_time} = require 'os'
{:cimport, :eq} = require 'test.unit.helpers'

time = cimport './src/os/time.h'

describe 'time function', ->
  setup ->
    time.time_init!

  describe 'os_delay', ->
    os_delay = (ms) ->
      time.os_delay ms, false

    it 'sleeps at least the number of requested milliseconds', ->
      curtime = lua_time!
      os_delay 1000
      ellapsed = lua_time! - curtime
      eq true, ellapsed >= 1 and ellapsed <=2
