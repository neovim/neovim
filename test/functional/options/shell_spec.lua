local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local is_os = t.is_os
local skip = t.skip
local api = n.api
local clear = n.clear

describe("'shell…' option defaults based on $SHELL #28384", function()
  ---@param sh string
  ---@param shcf string
  ---@param sp string
  ---@param srr string
  ---@param sxq string
  ---@param ssl boolean
  local function expect(sh, shcf, sp, srr, sxq, ssl)
    local opt = { sh = sh, shcf = shcf, sp = sp, srr = srr, sxq = sxq, ssl = ssl }
    for k, v in pairs(opt) do
      eq(v, api.nvim_get_option_info2(k, {}).default)
    end
  end
  it('cmd.exe', function()
    skip(not is_os('win'), 'N/A: only works on Windows')
    clear()
    expect('cmd.exe', '/s /c', '2>&1| tee', '>%s 2>&1', '"', false)
  end)

  it('powershell(PowerShell 5.x)', function()
    t.skip(not is_os('win'), 'N/A: only works on Windows')
    clear {
      env = { SHELL = 'powershell' },
    }
    expect('powershell', '-Command', '2>&1| tee', '>%s 2>&1', '', true)
  end)

  it('pwsh(PowerShell 7.x)', function()
    clear {
      env = { SHELL = 'pwsh' },
    }
    expect('pwsh', '-c', '2>&1| tee', '>%s 2>&1', '', true)
  end)

  it('csh', function()
    clear {
      env = { SHELL = 'csh' },
    }
    expect('csh', '-c', '|& tee', '>&', '', true)
  end)

  it('bash', function()
    clear {
      env = { SHELL = 'bash' },
    }
    expect('bash', '-c', '2>&1| tee', '>%s 2>&1', '', true)
  end)

  it('unknown', function()
    clear {
      env = { SHELL = 'unknown' },
    }
    expect(
      'unknown',
      '-c',
      not is_os('win') and '| tee' or '2>&1| tee',
      not is_os('win') and '>' or '>%s 2>&1',
      '',
      not is_os('win') and true or false
    )
  end)

  it('if the path contains spaces', function()
    clear {
      env = { SHELL = ('%s/foo bar/bash'):format(n.nvim_dir) },
    }
    expect(('"%s/foo bar/bash"'):format(n.nvim_dir), '-c', '2>&1| tee', '>%s 2>&1', '', true)
  end)
end)
