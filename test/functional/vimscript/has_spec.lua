local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local connect = t.connect
local eq = t.eq
local fn = t.fn
local is_os = t.is_os
local nvim_prog = t.nvim_prog

describe('has()', function()
  before_each(clear)

  it('"nvim-x.y.z"', function()
    eq(0, fn.has('nvim-'))
    eq(0, fn.has('nvim-  '))
    eq(0, fn.has('nvim- \t '))
    eq(0, fn.has('nvim-0. 1. 1'))
    eq(0, fn.has('nvim-0. 1.1'))
    eq(0, fn.has('nvim-0.1. 1'))
    eq(0, fn.has('nvim-a'))
    eq(0, fn.has('nvim-a.b.c'))
    eq(0, fn.has('nvim-0.b.c'))
    eq(0, fn.has('nvim-0.0.c'))
    eq(0, fn.has('nvim-0.b.0'))
    eq(0, fn.has('nvim-a.b.0'))
    eq(0, fn.has('nvim-.0.0.0'))
    eq(0, fn.has('nvim-.0'))
    eq(0, fn.has('nvim-0.'))
    eq(0, fn.has('nvim-0..'))
    eq(0, fn.has('nvim-.'))
    eq(0, fn.has('nvim-..'))
    eq(0, fn.has('nvim-...'))
    eq(0, fn.has('nvim-42'))
    eq(0, fn.has('nvim-9999'))
    eq(0, fn.has('nvim-99.001.05'))

    eq(1, fn.has('nvim'))
    eq(1, fn.has('nvim-0'))
    eq(1, fn.has('nvim-0.1'))
    eq(1, fn.has('nvim-0.0.0'))
    eq(1, fn.has('nvim-0.1.1.'))
    eq(1, fn.has('nvim-0.1.1.abc'))
    eq(1, fn.has('nvim-0.1.1..'))
    eq(1, fn.has('nvim-0.1.1.. ..'))
    eq(1, fn.has('nvim-0.1.1.... '))
    eq(1, fn.has('nvim-0.0.0'))
    eq(1, fn.has('nvim-0.0.1'))
    eq(1, fn.has('nvim-0.1.0'))
    eq(1, fn.has('nvim-0.1.1'))
    eq(1, fn.has('nvim-0.1.5'))
    eq(1, fn.has('nvim-0000.001.05'))
    eq(1, fn.has('nvim-0.01.005'))
    eq(1, fn.has('nvim-00.001.05'))
  end)

  it('"unnamedplus"', function()
    if (not is_os('win')) and fn.has('clipboard') == 1 then
      eq(1, fn.has('unnamedplus'))
    else
      eq(0, fn.has('unnamedplus'))
    end
  end)

  it('"wsl"', function()
    local is_wsl = vim.uv.os_uname()['release']:lower():match('microsoft') and true or false
    if is_wsl then
      eq(1, fn.has('wsl'))
    else
      eq(0, fn.has('wsl'))
    end
  end)

  it('"gui_running"', function()
    eq(0, fn.has('gui_running'))
    local tui = Screen.new(50, 15)
    local gui_session = connect(fn.serverstart())
    local gui = Screen.new(50, 15)
    eq(0, fn.has('gui_running'))
    tui:attach({ ext_linegrid = true, rgb = true, stdin_tty = true, stdout_tty = true })
    gui:attach({ ext_multigrid = true, rgb = true }, gui_session)
    eq(1, fn.has('gui_running'))
    tui:detach()
    eq(1, fn.has('gui_running'))
    gui:detach()
    eq(0, fn.has('gui_running'))
  end)

  it('does not change v:shell_error', function()
    fn.system({ nvim_prog, '-es', '+73cquit' })
    fn.has('python3') -- use a call whose implementation shells out
    eq(73, fn.eval('v:shell_error'))
  end)
end)
