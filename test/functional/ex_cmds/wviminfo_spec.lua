local helpers, lfs = require('test.functional.helpers'), require('lfs')
local execute, eq, neq, spawn, nvim_prog, set_session, wait, write_file
  = helpers.execute, helpers.eq, helpers.neq, helpers.spawn,
  helpers.nvim_prog, helpers.set_session, helpers.wait, helpers.write_file

describe(':wshada', function()
  local shada_file = 'wshada_test'
  local session

  before_each(function()
    if session then
      session:exit(0)
    end

    -- Override the default session because we need 'swapfile' for these tests.
    session = spawn({nvim_prog, '-u', 'NONE', '-i', '/dev/null', '--embed',
                           '--cmd', 'set swapfile'})
    set_session(session)

    os.remove(shada_file)
  end)

  it('creates a shada file', function()
    -- file should _not_ exist
    eq(nil, lfs.attributes(shada_file))
    execute('wsh! '..shada_file)
    wait()
    -- file _should_ exist
    neq(nil, lfs.attributes(shada_file))
  end)

  it('overwrites existing files', function()
    local text = 'wshada test'

    -- Create a dummy file
    write_file(shada_file, text)

    -- sanity check
    eq(text, io.open(shada_file):read())
    neq(nil, lfs.attributes(shada_file))

    execute('wsh! '..shada_file)
    wait()

    -- File should have been overwritten with a shada file.
    local fp = io.open(shada_file, 'r')
    local char1 = fp:read(1)
    fp:close()
    -- ShaDa file starts with a “header” entry
    assert(char1:byte() == 0x01,
      shada_file..' should be a shada file')
  end)

  teardown(function()
    os.remove(shada_file)
  end)
end)
