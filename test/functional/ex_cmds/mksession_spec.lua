-- Test generation of session files

local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local get_pathsep = helpers.get_pathsep
local eq = helpers.eq
local funcs = helpers.funcs

local file_prefix = 'Xtest-functional-ex_cmds-mksession_spec'


describe('A session file', function()
  -- The file name used for each session
  local session_file = file_prefix .. '.vim'
  local tab_dir = file_prefix .. '.d'

  before_each(function()
    clear()
    lfs.mkdir(tab_dir)
  end)

  after_each(function()
    os.remove(session_file)
    lfs.rmdir(tab_dir)
  end)

  it('restores tab-local working directories', function()
    local tmpfile_base = file_prefix .. '-tmpfile'
    local cwd_dir = funcs.getcwd()

    -- There need to be some files being edited, so we will use dummy files
    command('edit ' .. tmpfile_base .. '1')
    command('tabnew')
    command('edit ' .. tmpfile_base .. '2')
    command('tcd ' .. tab_dir)
    command('tabfirst')
    command('mksession ' .. session_file)

    -- Create a new test instance of Nvim, and henceforth all test
    -- utilities operate on this new instance.
    clear()

    command('source ' .. session_file)
    -- The first tab should have the original working directory
    command('tabnext 1')
    eq(cwd_dir, funcs.getcwd())
    -- The second tab should have the local working directory
    command('tabnext 2')
    eq(cwd_dir .. get_pathsep() .. tab_dir, funcs.getcwd())
  end)
end)
