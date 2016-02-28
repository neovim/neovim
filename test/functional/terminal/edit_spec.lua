local helpers = require('test.functional.helpers')

local nvim_dir = helpers.nvim_dir
local command = helpers.command
local meths = helpers.meths
local clear = helpers.clear
local eq = helpers.eq

describe(':edit term://*', function()
  before_each(function()
    clear()
    meths.set_option('shell', nvim_dir .. '/shell-test')
  end)

  it('runs TermOpen event', function()
    meths.set_var('termopen_runs', {})
    command('autocmd TermOpen * :call add(g:termopen_runs, expand("<amatch>"))')
    command('edit term://')
    termopen_runs = meths.get_var('termopen_runs')
    eq(1, #termopen_runs)
    eq(termopen_runs[1], termopen_runs[1]:match('^term://.//%d+:$'))
  end)
end)
