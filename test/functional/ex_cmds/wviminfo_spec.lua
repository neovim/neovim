local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local command, eq, neq, spawn, nvim_prog, set_session, write_file =
  helpers.command, helpers.eq, helpers.neq, helpers.spawn,
  helpers.nvim_prog, helpers.set_session, helpers.write_file

describe(':wshada', function()
  local shada_file = 'wshada_test'
  local session

  before_each(function()
    if session then
      session:close()
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
    command('wsh! '..shada_file)
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

    command('wsh! '..shada_file)

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
