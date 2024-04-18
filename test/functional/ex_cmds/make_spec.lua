local t = require('test.functional.testutil')()
local clear = t.clear
local eval = t.eval
local has_powershell = t.has_powershell
local matches = t.matches
local api = t.api
local testprg = t.testprg

describe(':make', function()
  clear()
  before_each(function()
    clear()
  end)

  describe('with powershell', function()
    if not has_powershell() then
      pending('not tested; powershell was not found', function() end)
      return
    end
    before_each(function()
      t.set_shell_powershell()
    end)

    it('captures stderr & non zero exit code #14349', function()
      api.nvim_set_option_value('makeprg', testprg('shell-test') .. ' foo', {})
      local out = eval('execute("make")')
      -- Error message is captured in the file and printed in the footer
      matches(
        '[\r\n]+.*[\r\n]+Unknown first argument%: foo[\r\n]+%(1 of 1%)%: Unknown first argument%: foo',
        out
      )
    end)

    it('captures stderr & zero exit code #14349', function()
      api.nvim_set_option_value('makeprg', testprg('shell-test'), {})
      local out = eval('execute("make")')
      -- Ensure there are no "shell returned X" messages between
      -- command and last line (indicating zero exit)
      matches('LastExitCode%s+ready [$]%s+[(]', out)
      matches('\n.*%: ready [$]', out)
    end)
  end)
end)
