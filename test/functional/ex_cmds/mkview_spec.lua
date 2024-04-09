local t = require('test.functional.testutil')()

local clear = t.clear
local command = t.command
local get_pathsep = t.get_pathsep
local eq = t.eq
local fn = t.fn
local rmdir = t.rmdir
local mkdir = t.mkdir

local file_prefix = 'Xtest-functional-ex_cmds-mkview_spec'

describe(':mkview', function()
  local tmp_file_base = file_prefix .. '-tmpfile'
  local local_dir = file_prefix .. '.d'
  local view_dir = file_prefix .. '.view.d'

  before_each(function()
    clear()
    mkdir(view_dir)
    mkdir(local_dir)
  end)

  after_each(function()
    -- Remove any views created in the view directory
    rmdir(view_dir)
    rmdir(local_dir)
  end)

  it('viewoption curdir restores local current directory', function()
    local cwd_dir = fn.getcwd()
    local set_view_dir_command = 'set viewdir=' .. cwd_dir .. get_pathsep() .. view_dir

    -- By default the local current directory should save
    command(set_view_dir_command)
    command('edit ' .. tmp_file_base .. '1')
    command('lcd ' .. local_dir)
    command('mkview')

    -- Create a new instance of Nvim to remove the 'lcd'
    clear()

    -- Disable saving the local current directory for the second view
    command(set_view_dir_command)
    command('set viewoptions-=curdir')
    command('edit ' .. tmp_file_base .. '2')
    command('lcd ' .. local_dir)
    command('mkview')

    -- Create a new instance of Nvim to test saved 'lcd' option
    clear()
    command(set_view_dir_command)

    -- Load the view without a saved local current directory
    command('edit ' .. tmp_file_base .. '2')
    command('loadview')
    -- The view's current directory should not have changed
    eq(cwd_dir, fn.getcwd())
    -- Load the view with a saved local current directory
    command('edit ' .. tmp_file_base .. '1')
    command('loadview')
    -- The view's local directory should have been saved
    eq(cwd_dir .. get_pathsep() .. local_dir, fn.getcwd())
  end)
end)
