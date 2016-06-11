-- Tests for signs

local helpers = require('test.functional.helpers')(after_each)
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('signs', function()
  setup(clear)

  it('is working', function()
    execute('sign define JumpSign text=x')
    execute([[exe 'sign place 42 line=2 name=JumpSign buffer=' . bufnr('')]])
    -- Split the window to the bottom to verify :sign-jump will stay in the current
    -- window if the buffer is displayed there.
    execute('bot split')
    execute([[exe 'sign jump 42 buffer=' . bufnr('')]])
    execute([[call append(line('$'), winnr())]])

    -- Assert buffer contents.
    expect([[
      
      2]])
  end)
end)
