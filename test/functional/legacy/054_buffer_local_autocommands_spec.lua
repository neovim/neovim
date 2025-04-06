-- Some tests for buffer-local autocommands

local n = require('test.functional.testnvim')()

local clear = n.clear
local expect = n.expect
local command = n.command

local fname = 'Xtest-functional-legacy-054'

describe('BufLeave <buffer>', function()
  setup(clear)

  it('is working', function()
    command('write! ' .. fname)
    command('autocmd BufLeave <buffer> normal! Ibuffer-local autocommand')
    command('autocmd BufLeave <buffer> update')

    -- Here, autocommand for xx shall append a line
    -- But autocommand shall not apply to buffer named <buffer>
    command('edit somefile')

    -- Here, autocommand shall be auto-deleted
    command('bwipeout ' .. fname)

    -- Nothing shall be written
    command('edit ' .. fname)
    command('edit somefile')
    command('edit ' .. fname)

    expect('buffer-local autocommand')
  end)

  teardown(function()
    os.remove(fname)
  end)
end)
