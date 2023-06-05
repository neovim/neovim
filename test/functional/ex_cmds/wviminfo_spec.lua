local helpers = require('test.functional.helpers')(after_each)
local luv = require('luv')
local clear = helpers.clear
local command, eq, neq, write_file =
  helpers.command, helpers.eq, helpers.neq, helpers.write_file
local read_file = helpers.read_file
local is_os = helpers.is_os

describe(':wshada', function()
  local shada_file = 'wshada_test'

  before_each(function()
    clear{args={'-i', is_os('win') and 'nul' or '/dev/null',
                -- Need 'swapfile' for these tests.
                '--cmd', 'set swapfile undodir=. directory=. viewdir=. backupdir=. belloff= noshowcmd noruler'},
          args_rm={'-n', '-i', '--cmd'}}
  end)
  after_each(function ()
    os.remove(shada_file)
  end)

  it('creates a shada file', function()
    -- file should _not_ exist
    eq(nil, luv.fs_stat(shada_file))
    command('wsh! '..shada_file)
    -- file _should_ exist
    neq(nil, luv.fs_stat(shada_file))
  end)

  it('overwrites existing files', function()
    local text = 'wshada test'

    -- Create a dummy file
    write_file(shada_file, text)

    -- sanity check
    eq(text, read_file(shada_file))
    neq(nil, luv.fs_stat(shada_file))

    command('wsh! '..shada_file)

    -- File should have been overwritten with a shada file.
    local fp = io.open(shada_file, 'r')
    local char1 = fp:read(1)
    fp:close()
    -- ShaDa file starts with a “header” entry
    assert(char1:byte() == 0x01,
      shada_file..' should be a shada file')
  end)
end)
