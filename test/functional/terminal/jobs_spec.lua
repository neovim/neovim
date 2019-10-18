local helpers = require('test.functional.helpers')(after_each)

local nvim_dir = helpers.nvim_dir
local child_session = require('test.functional.terminal.helpers')

it('Job receives SIGHUP with output during exiting', function()
  helpers.clear()
  -- local screen = child_session.screen_setup(0, '["'..helpers.nvim_prog
  --   ..'", "-u", "NONE", "-i", "NONE", "--cmd", "'..helpers.nvim_set..'"]')

  -- TODO: move to helpers?
  local nvim_child_argv = {
    helpers.nvim_prog, '-u', 'NONE', '-i', 'NONE', '--cmd', helpers.nvim_set}
  local cmd = '["'..table.concat(nvim_child_argv, '", "')..'"]'
  local screen = child_session.screen_setup(0, cmd)
  -- local screen = thelpers.screen_setup(0, cmd)

  child_session.feed_data(string.format([[
    :let g:started = 0
    :let opts = {}
    :let opts.on_stdout = {-> execute('let g:started = 1')}
    :let opts.on_exit = {...-> execute('echom printf("exiting:%%d, status:%%d", v:exiting, a:2)', '')}
    :call jobstart('%s', opts)
    :while !g:started | sleep 10m | endwhile
    :qa
  ]], nvim_dir..'/sigtrap-test'))
  screen:expect{grid=[[
    exiting:0, status:141                             |
    [Process exited 0]{1: }                               |
                                                      |
                                                      |
                                                      |
                                                      |
    {3:-- TERMINAL --}                                    |
  ]]}
end)
