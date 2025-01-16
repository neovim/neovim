local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local exec_capture = n.exec_capture
local mkdir = t.mkdir
local rmdir = n.rmdir


describe("'writetimestamp'", function()
  local tmpdir = 'Xtest_options_writetimestamp'

  setup(function()
    rmdir(tmpdir)
    mkdir(tmpdir)
  end)

  teardown(function()
    rmdir(tmpdir)
  end)

  before_each(function()
    clear()
  end)

  it('setting writetimestamp', function()
    local fname = tmpdir .. 'file.txt'
    local write_output = '"' .. fname .. '"' .. ' [New] 0L, 0B written'
    local format_string = ''

    os.remove(fname)
    command('write ' .. fname)
    eq(exec_capture('messages'), write_output)
    clear()
    os.remove(fname)

    format_string = '%H:%M:%S'                      -- 9: " HH:MM:SS"
    command('set writetimestamp=' .. format_string)
    command('write ' .. fname)
    eq(string.len(exec_capture('messages')), string.len(write_output) + 9)
    clear()
    os.remove(fname)

    format_string = '%a\\ %b\\ %d\\ %H:%M:%S\\ %Y'  -- 25: " WKD MON DD HH:MM:SS YYYY"
    command('set writetimestamp=' .. format_string)
    command('write ' .. fname)
    eq(string.len(exec_capture('messages')), string.len(write_output) + 25)
    clear()
    os.remove(fname)

    format_string = 'at\\ %r\\ %Z'                  -- 19: " at HH:MM:SS XM TMZ"
    command('set writetimestamp=' .. format_string)
    command('write ' .. fname)
    eq(string.len(exec_capture('messages')), string.len(write_output) + 19)
    clear()
    os.remove(fname)

    format_string = ''                              -- 0: ""
    command('set writetimestamp=' .. format_string)
    command('write ' .. fname)
    eq(exec_capture('messages'), write_output)
    clear()
    os.remove(fname)
  end)
end)

