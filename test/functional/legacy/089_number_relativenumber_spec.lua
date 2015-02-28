-- - Some tests for setting 'number' and 'relativenumber'
--   This is not all that useful now that the options are no longer reset when
--   setting the other.

local helpers = require('test.functional.helpers')
local feed = helpers.feed
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('setting \'number\' and \'relativenumber\'', function()
  setup(clear)

  it('is working', function()
    execute('set hidden nu rnu')
    execute('redir @a | set nu? rnu? | redir END')
    execute('e! xx')
    execute('redir @b | set nu? rnu? | redir END')
    execute('e! #')
    execute([[$put ='results:']])
    execute('$put a')
    execute('$put b')

    execute('set nonu nornu')
    execute('setglobal nu')
    execute('setlocal rnu')
    execute('redir @c | setglobal nu? | redir END')
    execute('set nonu nornu')
    execute('setglobal rnu')
    execute('setlocal nu')
    execute('redir @d | setglobal rnu? | redir END')
    execute([[$put =':setlocal must NOT reset the other global value']])
    execute('$put c')
    execute('$put d')

    execute('set nonu nornu')
    execute('setglobal nu')
    execute('setglobal rnu')
    execute('redir @e | setglobal nu? | redir END')
    execute('set nonu nornu')
    execute('setglobal rnu')
    execute('setglobal nu')
    execute('redir @f | setglobal rnu? | redir END')
    execute([[$put =':setglobal MUST reset the other global value']])
    execute('$put e')
    execute('$put f')

    execute('set nonu nornu')
    execute('set nu')
    execute('set rnu')
    execute('redir @g | setglobal nu? | redir END')
    execute('set nonu nornu')
    execute('set rnu')
    execute('set nu')
    execute('redir @h | setglobal rnu? | redir END')
    execute([[$put =':set MUST reset the other global value']])
    execute('$put g')
    execute('$put h')

    -- Remove empty line
    feed('ggdd')

    -- Assert buffer contents.
    expect([[
      results:
      
        number
        relativenumber
      
        number
        relativenumber
      :setlocal must NOT reset the other global value
      
        number
      
        relativenumber
      :setglobal MUST reset the other global value
      
        number
      
        relativenumber
      :set MUST reset the other global value
      
        number
      
        relativenumber]])
  end)
end)
