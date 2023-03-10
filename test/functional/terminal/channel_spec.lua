local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local command = helpers.command
local pcall_err = helpers.pcall_err
local feed = helpers.feed
local poke_eventloop = helpers.poke_eventloop
local is_os = helpers.is_os

describe('terminal channel is closed and later released if', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
  end)

  it('opened by nvim_open_term() and deleted by :bdelete!', function()
    command([[let id = nvim_open_term(0, {})]])
    local chans = eval('len(nvim_list_chans())')
    -- channel hasn't been released yet
    eq("Vim(call):Can't send data to closed stream",
       pcall_err(command, [[bdelete! | call chansend(id, 'test')]]))
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by nvim_open_term(), closed by chanclose(), and deleted by pressing a key', function()
    command('let id = nvim_open_term(0, {})')
    local chans = eval('len(nvim_list_chans())')
    -- channel has been closed but not released
    eq("Vim(call):Can't send data to closed stream",
       pcall_err(command, [[call chanclose(id) | call chansend(id, 'test')]]))
    screen:expect({any='%[Terminal closed%]'})
    eq(chans, eval('len(nvim_list_chans())'))
    -- delete terminal
    feed('i<CR>')
    -- need to first process input
    poke_eventloop()
    -- channel has been released after another main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by nvim_open_term(), closed by chanclose(), and deleted by :bdelete', function()
    command('let id = nvim_open_term(0, {})')
    local chans = eval('len(nvim_list_chans())')
    -- channel has been closed but not released
    eq("Vim(call):Can't send data to closed stream",
       pcall_err(command, [[call chanclose(id) | call chansend(id, 'test')]]))
    screen:expect({any='%[Terminal closed%]'})
    eq(chans, eval('len(nvim_list_chans())'))
    -- channel still hasn't been released yet
    eq("Vim(call):Can't send data to closed stream",
       pcall_err(command, [[bdelete | call chansend(id, 'test')]]))
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  it('opened by termopen(), exited, and deleted by pressing a key', function()
    command([[let id = termopen('echo')]])
    local chans = eval('len(nvim_list_chans())')
    -- wait for process to exit
    screen:expect({any='%[Process exited 0%]'})
    -- process has exited but channel has't been released
    eq("Vim(call):Can't send data to closed stream",
       pcall_err(command, [[call chansend(id, 'test')]]))
    eq(chans, eval('len(nvim_list_chans())'))
    -- delete terminal
    feed('i<CR>')
    -- need to first process input
    poke_eventloop()
    -- channel has been released after another main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)

  -- This indirectly covers #16264
  it('opened by termopen(), exited, and deleted by :bdelete', function()
    command([[let id = termopen('echo')]])
    local chans = eval('len(nvim_list_chans())')
    -- wait for process to exit
    screen:expect({any='%[Process exited 0%]'})
    -- process has exited but channel hasn't been released
    eq("Vim(call):Can't send data to closed stream",
       pcall_err(command, [[call chansend(id, 'test')]]))
    eq(chans, eval('len(nvim_list_chans())'))
    -- channel still hasn't been released yet
    eq("Vim(call):Can't send data to closed stream",
       pcall_err(command, [[bdelete | call chansend(id, 'test')]]))
    -- channel has been released after one main loop iteration
    eq(chans - 1, eval('len(nvim_list_chans())'))
  end)
end)

it('chansend sends lines to terminal channel in proper order', function()
  clear()
  local screen = Screen.new(100, 20)
  screen:attach()
  local shells = is_os('win') and {'cmd.exe', 'pwsh.exe -nop', 'powershell.exe -nop'} or {'sh'}
  for _, sh in ipairs(shells) do
    command([[bdelete! | let id = termopen(']] .. sh .. [[')]])
    command([[call chansend(id, ['echo "hello"', 'echo "world"', ''])]])
    screen:expect{
      any=[[echo "hello".*echo "world"]]
    }
  end
end)
