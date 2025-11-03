-- Test for buffer name completion when 'wildoptions' contains "fuzzy"
-- (Confirm that Vim does not crash)
local n = require('test.functional.testnvim')()

local clear = n.clear
local insert = n.insert
local expect = n.expect
local feed_command = n.feed_command
local command = n.command

describe('set wildoptions=fuzzy', function()
  before_each(clear)

  it('works', function()
    insert([[I'm alive!]])
    command('set wildoptions=fuzzy')
    command('new buf_a')
    feed_command('b buf_a')
    command('q!')
    expect([[I'm alive!]])
  end)
end)
