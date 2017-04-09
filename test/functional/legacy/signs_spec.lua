-- Tests for signs

local helpers = require('test.functional.helpers')(after_each)
local clear, command, expect = helpers.clear, helpers.command, helpers.expect

describe('signs', function()
  setup(clear)

  it('is working', function()
    command('sign define JumpSign text=x')
    command([[exe 'sign place 42 line=2 name=JumpSign buffer=' . bufnr('')]])
    -- Split the window to the bottom to verify :sign-jump will stay in the current
    -- window if the buffer is displayed there.
    command('bot split')
    command([[exe 'sign jump 42 buffer=' . bufnr('')]])
    command([[call append(line('$'), winnr())]])

    -- Assert buffer contents.
    expect([[

      2]])
  end)
end)
