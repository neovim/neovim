local helpers = require('test.functional.helpers')(after_each)
local clear, nvim, eq, neq, command, execute, eval
  = helpers.clear, helpers.nvim, helpers.eq, helpers.neq, helpers.command, helpers.execute, helpers.eval

describe('sign', function()
  before_each(clear)
  describe('unplace {id}', function()
    describe('without specifying buffer', function()
      it('deletes the sign from all buffers', function()
        -- place a sign with id 34 to first buffer
        nvim('command', 'sign define Foo text=+ texthl=Delimiter linehl=Comment')
        local buf1 = nvim('eval', 'bufnr("%")')
        nvim('command', 'sign place 34 line=3 name=Foo buffer='..buf1)
        -- create a second buffer and place the sign on it as well
        nvim('command', 'new')
        local buf2 = nvim('eval', 'bufnr("%")')
        nvim('command', 'sign place 34 line=3 name=Foo buffer='..buf2)
        -- now unplace without specifying a buffer
        nvim('command', 'sign unplace 34')
        eq("\n--- Signs ---\n", nvim('command_output', 'sign place buffer='..buf1))
        eq("\n--- Signs ---\n", nvim('command_output', 'sign place buffer='..buf2))
      end)
    end)
  end)
end)

describe('signs jump', function()
  setup(clear)

  describe('when given a missing buffer', function()
    it('should return an error', function()
      command('new')
      command('sign define Sign text=x')
      local buf1 = eval('bufnr("%")')
      command('new')
      command('bd '..buf1)
      command('sign place 34 line=3 name=Sign buffer='..buf1)
      execute('sign jump 34 buffer='..buf1)

      neq(nil, string.find(eval('v:errmsg'), '^E934'))
    end)
  end)
end)
