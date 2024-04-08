-- Tests for signs

local t = require('test.functional.testutil')(after_each)
local clear, command, expect = t.clear, t.command, t.expect

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
