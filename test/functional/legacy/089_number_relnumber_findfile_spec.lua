-- - Some tests for setting 'number' and 'relativenumber'
--   This is not all that useful now that the options are no longer reset when
--   setting the other.

local helpers = require('test.functional.helpers')(after_each)
local feed = helpers.feed
local clear, expect, source = helpers.clear, helpers.expect, helpers.source

describe("setting 'number' and 'relativenumber'", function()
  setup(clear)

  it('is working', function()
    source([[
        set hidden nu rnu
        redir @a | set nu? | set rnu? | redir END
        e! xx
        redir @b | set nu? | set rnu? | redir END
        e! #
        $put ='results:'
        $put a
        $put b

        set nonu nornu
        setglobal nu
        setlocal rnu
        redir @c | setglobal nu? | redir END
        set nonu nornu
        setglobal rnu
        setlocal nu
        redir @d | setglobal rnu? | redir END
        $put =':setlocal must NOT reset the other global value'
        $put c
        $put d

        set nonu nornu
        setglobal nu
        setglobal rnu
        redir @e | setglobal nu? | redir END
        set nonu nornu
        setglobal rnu
        setglobal nu
        redir @f | setglobal rnu? | redir END
        $put =':setglobal MUST reset the other global value'
        $put e
        $put f

        set nonu nornu
        set nu
        set rnu
        redir @g | setglobal nu? | redir END
        set nonu nornu
        set rnu
        set nu
        redir @h | setglobal rnu? | redir END
        $put =':set MUST reset the other global value'
        $put g
        $put h
    ]])

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

-- - Some tests for findfile() function
describe('findfile', function()
  setup(clear)

  it('is working', function()
    -- Assume test is being run from project root
    source([[
        $put ='Testing findfile'
        $put =''
        set ssl
        $put =findfile('vim.c','src/nvim/ap*')
        cd src/nvim
        $put =findfile('vim.c','ap*')
        $put =findfile('vim.c','api')
    ]])

    -- Remove empty line
    feed('ggdd')

    expect([[
      Testing findfile
      
      src/nvim/api/vim.c
      api/vim.c
      api/vim.c]])
  end)
end)
