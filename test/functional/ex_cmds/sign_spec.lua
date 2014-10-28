local helpers = require('test.functional.helpers')
local clear, nvim, buffer, curbuf, curwin, eq, ok =
  helpers.clear, helpers.nvim, helpers.buffer, helpers.curbuf, helpers.curwin,
  helpers.eq, helpers.ok

describe('sign', function()
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
