local helpers = require('test.functional.helpers')
local screen = require('test.functional.ui.screen')

local curbufmeths = helpers.curbufmeths
local curwinmeths = helpers.curwinmeths
local nvim_dir = helpers.nvim_dir
local command = helpers.command
local meths = helpers.meths
local clear = helpers.clear
local eq = helpers.eq

describe(':edit term://*', function()
  before_each(function()
    clear()
    meths.set_option('shell', nvim_dir .. '/shell-test')
    meths.set_option('shellcmdflag', 'EXE')
  end)

  it('runs TermOpen event', function()
    meths.set_var('termopen_runs', {})
    command('autocmd TermOpen * :call add(g:termopen_runs, expand("<amatch>"))')
    command('edit term://')
    termopen_runs = meths.get_var('termopen_runs')
    eq(1, #termopen_runs)
    eq(termopen_runs[1], termopen_runs[1]:match('^term://.//%d+:$'))
  end)

  it('runs TermOpen early enough to respect terminal_scrollback_buffer_size', function()
    local rep = 'a'
    meths.set_option('shellcmdflag', 'REP ' .. rep)
    local rep_size = rep:byte()
    local sb = 10
    local gsb = 20
    meths.set_var('terminal_scrollback_buffer_size', gsb)
    command('autocmd TermOpen * :let b:terminal_scrollback_buffer_size = '
            .. tostring(sb))
    command('edit term://foobar')
    local bufcontents = {}
    local winheight = curwinmeths.get_height()
    -- I have no idea why there is + 4 needed. But otherwise it works fine with 
    -- different scrollbacks.
    local shift = -4
    for i = (rep_size - 1 - sb - winheight - shift),(rep_size - 1) do
      bufcontents[#bufcontents + 1] = ('%d: foobar'):format(i)
    end
    bufcontents[#bufcontents + 1] = ''
    bufcontents[#bufcontents + 1] = '[Process exited 0]'
    command('sleep 500m')
    eq(bufcontents, curbufmeths.get_line_slice(1, -1, true, true))
  end)
end)
