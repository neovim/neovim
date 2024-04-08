local t = require('test.functional.testutil')(after_each)
local clear, eq, assert_alive = t.clear, t.eq, t.assert_alive
local command = t.command
local api = t.api

describe('sign', function()
  before_each(clear)
  describe('unplace {id}', function()
    describe('without specifying buffer', function()
      it('deletes the sign from all buffers', function()
        -- place a sign with id 34 to first buffer
        command('sign define Foo text=+ texthl=Delimiter linehl=Comment numhl=Number')
        local buf1 = api.nvim_eval('bufnr("%")')
        command('sign place 34 line=3 name=Foo buffer=' .. buf1)
        -- create a second buffer and place the sign on it as well
        command('new')
        local buf2 = api.nvim_eval('bufnr("%")')
        command('sign place 34 line=3 name=Foo buffer=' .. buf2)
        -- now unplace without specifying a buffer
        command('sign unplace 34')
        eq('--- Signs ---\n', api.nvim_exec('sign place buffer=' .. buf1, true))
        eq('--- Signs ---\n', api.nvim_exec('sign place buffer=' .. buf2, true))
      end)
    end)
  end)

  describe('define {id}', function()
    it('does not leak memory when specifying multiple times the same argument', function()
      command('sign define Foo culhl=Normal culhl=Normal')
      assert_alive()
    end)
  end)
end)
