local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local get_pathsep = helpers.get_pathsep
local eq = helpers.eq
local funcs = helpers.funcs
local matches = helpers.matches
local pesc = helpers.pesc
local rmdir = helpers.rmdir

local file_prefix = 'Xtest-functional-ex_cmds-mksession_spec'

describe(':mksession', function()
  local session_file = file_prefix .. '.vim'
  local tab_dir = file_prefix .. '.d'

  before_each(function()
    clear()
    lfs.mkdir(tab_dir)
  end)

  after_each(function()
    os.remove(session_file)
    rmdir(tab_dir)
  end)

  it('restores same :terminal buf in splits', function()
    -- If the same :terminal is displayed in multiple windows, :mksession
    -- should restore it as such.

    -- Create two windows showing the same :terminal buffer.
    command('terminal')
    command('split')
    command('terminal')
    command('split')
    command('mksession '..session_file)

    -- Create a new test instance of Nvim.
    command('qall!')
    clear()
    -- Restore session.
    command('source '..session_file)

    eq({2,2,4},
      {funcs.winbufnr(1), funcs.winbufnr(2), funcs.winbufnr(3)})
  end)

  it('restores tab-local working directories', function()
    local tmpfile_base = file_prefix .. '-tmpfile'
    local cwd_dir = funcs.getcwd()

    -- :mksession does not save empty tabs, so create some buffers.
    command('edit ' .. tmpfile_base .. '1')
    command('tabnew')
    command('edit ' .. tmpfile_base .. '2')
    command('tcd ' .. tab_dir)
    command('tabfirst')
    command('mksession ' .. session_file)

    -- Create a new test instance of Nvim.
    clear()

    command('source ' .. session_file)
    -- First tab should have the original working directory.
    command('tabnext 1')
    eq(cwd_dir, funcs.getcwd())
    -- Second tab should have the tab-local working directory.
    command('tabnext 2')
    eq(cwd_dir .. get_pathsep() .. tab_dir, funcs.getcwd())
  end)

  it('restores buffers with tab-local CWD', function()
    local tmpfile_base = file_prefix .. '-tmpfile'
    local cwd_dir = funcs.getcwd()
    local session_path = cwd_dir .. get_pathsep() .. session_file

    command('edit ' .. tmpfile_base .. '1')
    command('tcd ' .. tab_dir)
    command('tabnew')
    command('edit ' .. cwd_dir .. get_pathsep() .. tmpfile_base .. '2')
    command('tabfirst')
    command('mksession ' .. session_path)

    -- Create a new test instance of Nvim.
    clear()

    -- Use :silent to avoid press-enter prompt due to long path
    command('silent source ' .. session_path)
    command('tabnext 1')
    eq(cwd_dir .. get_pathsep() .. tmpfile_base .. '1', funcs.expand('%:p'))
    command('tabnext 2')
    -- :mksession stores paths using unix slashes, but Nvim doesn't adjust these
    -- for absolute paths in all cases yet. Absolute paths are used in the
    -- session file after :tcd, so we need to expect unix slashes here for now
    -- eq(cwd_dir .. get_pathsep() .. tmpfile_base .. '2', funcs.expand('%:p'))
    eq(cwd_dir:gsub([[\]], '/') .. '/' .. tmpfile_base .. '2',
      funcs.expand('%:p'))
  end)

  it('restores CWD for :terminal buffers #11288', function()
    local cwd_dir = funcs.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    cwd_dir = cwd_dir:gsub([[\]], '/')  -- :mksession always uses unix slashes.
    local session_path = cwd_dir..'/'..session_file

    command('cd '..tab_dir)
    command('terminal echo $PWD')
    command('cd '..cwd_dir)
    command('mksession '..session_path)
    command('qall!')

    -- Create a new test instance of Nvim.
    clear()
    command('silent source '..session_path)

    local expected_cwd = cwd_dir..'/'..tab_dir
    matches('^term://'..pesc(expected_cwd)..'//%d+:', funcs.expand('%'))
    command('qall!')
  end)
end)
