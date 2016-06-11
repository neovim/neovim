-- Some tests for buffer-local autocommands

local helpers = require('test.functional.helpers')(after_each)
local clear, execute, eq = helpers.clear, helpers.execute, helpers.eq
local curbuf_contents = helpers.curbuf_contents

describe('BufLeave <buffer>', function()
  setup(clear)

  it('is working', function()
    execute('w! xx')
    execute('au BufLeave <buffer> norm Ibuffer-local autocommand')
    execute('au BufLeave <buffer> update')
    
    -- Here, autocommand for xx shall append a line
    -- But autocommand shall not apply to buffer named <buffer> 
    execute('e somefile')

    -- Here, autocommand shall be auto-deleted
    execute('bwipe xx')
    
    -- Nothing shall be written
    execute('e xx')
    execute('e somefile')
    execute('e xx')

    eq('buffer-local autocommand', curbuf_contents())
  end)

  teardown(function()
    os.remove('xx')
  end)
end)
