{time: lua_time} = require 'os'
{:cimport, :eq} = require 'test.unit.helpers'

time = cimport './src/os/time.h'

describe 'time function', ->
  describe 'mch_delay', ->
    mch_delay = (ms) ->
      time.mch_delay ms, false

    it 'sleeps at least the number of requested milliseconds', ->
      curtime = lua_time!
      mch_delay 1000
      ellapsed = lua_time! - curtime
      eq true, ellapsed >= 1 and ellapsed <=2
