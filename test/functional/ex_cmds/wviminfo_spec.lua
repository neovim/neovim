local t = require('test.functional.testutil')()
local clear = t.clear
local command, eq, neq, write_file = t.command, t.eq, t.neq, t.write_file
local read_file = t.read_file
local is_os = t.is_os

describe(':wshada', function()
  local shada_file = 'wshada_test'

  before_each(function()
    clear {
      args = {
        '-i',
        is_os('win') and 'nul' or '/dev/null',
        -- Need 'swapfile' for these tests.
        '--cmd',
        'set swapfile undodir=. directory=. viewdir=. backupdir=. belloff= noshowcmd noruler',
      },
      args_rm = { '-n', '-i', '--cmd' },
    }
  end)
  after_each(function()
    os.remove(shada_file)
  end)

  it('creates a shada file', function()
    -- file should _not_ exist
    eq(nil, vim.uv.fs_stat(shada_file))
    command('wsh! ' .. shada_file)
    -- file _should_ exist
    neq(nil, vim.uv.fs_stat(shada_file))
  end)

  it('overwrites existing files', function()
    local text = 'wshada test'

    -- Create a dummy file
    write_file(shada_file, text)

    -- sanity check
    eq(text, read_file(shada_file))
    neq(nil, vim.uv.fs_stat(shada_file))

    command('wsh! ' .. shada_file)

    -- File should have been overwritten with a shada file.
    local fp = io.open(shada_file, 'r')
    local char1 = fp:read(1)
    fp:close()
    -- ShaDa file starts with a “header” entry
    assert(char1:byte() == 0x01, shada_file .. ' should be a shada file')
  end)
end)
