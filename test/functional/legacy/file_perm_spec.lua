-- Test getting and setting file permissions.
require('os')

local helpers = require('test.functional.helpers')(after_each)
local clear, call, eq = helpers.clear, helpers.call, helpers.eq
local neq, exc_exec = helpers.neq, helpers.exc_exec

describe('Test getting and setting file permissions', function()
  local tempfile = helpers.tmpname()

  before_each(function()
    os.remove(tempfile)
    clear()
  end)

  it('file permissions', function()
    eq('', call('getfperm', tempfile))
    eq(0, call('setfperm', tempfile, 'r--------'))

    call('writefile', {'one'}, tempfile)
    eq(9, call('len', call('getfperm', tempfile)))

    eq(1, call('setfperm', tempfile, 'rwx------'))
    if helpers.os_name() == 'windows' then
      eq('rw-rw-rw-', call('getfperm', tempfile))
    else
      eq('rwx------', call('getfperm', tempfile))
    end

    eq(1, call('setfperm', tempfile, 'r--r--r--'))
    eq('r--r--r--', call('getfperm', tempfile))

    local err = exc_exec(('call setfperm("%s", "---")'):format(tempfile))
    neq(err:find('E475:'), nil)

    eq(1, call('setfperm', tempfile, 'rwx------'))
  end)

  after_each(function()
    os.remove(tempfile)
  end)
end)
