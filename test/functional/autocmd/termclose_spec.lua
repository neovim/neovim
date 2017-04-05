local helpers = require('test.functional.helpers')(after_each)

local clear, command, nvim, nvim_dir =
  helpers.clear, helpers.command, helpers.nvim, helpers.nvim_dir
local eval, eq, retry =
  helpers.eval, helpers.eq, helpers.retry

if helpers.pending_win32(pending) then return end

describe('TermClose event', function()
  before_each(function()
    clear()
    nvim('set_option', 'shell', nvim_dir .. '/shell-test')
    nvim('set_option', 'shellcmdflag', 'EXE')
  end)

  it('triggers when terminal job ends', function()
    command('autocmd TermClose * let g:test_termclose = 23')
    command('terminal')
    command('call jobstop(b:terminal_job_id)')
    retry(nil, nil, function() eq(23, eval('g:test_termclose')) end)
  end)

  it('reports the correct <abuf>', function()
    command('set hidden')
    command('autocmd TermClose * let g:abuf = expand("<abuf>")')
    command('edit foo')
    command('edit bar')
    eq(2, eval('bufnr("%")'))

    command('terminal')
    retry(nil, nil, function() eq(3, eval('bufnr("%")')) end)

    command('buffer 1')
    retry(nil, nil, function() eq(1, eval('bufnr("%")')) end)

    command('3bdelete!')
    retry(nil, nil, function() eq('3', eval('g:abuf')) end)
  end)
end)
