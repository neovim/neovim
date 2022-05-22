local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local get_pathsep = helpers.get_pathsep
local iswin = helpers.iswin
local eq = helpers.eq
local neq = helpers.neq
local funcs = helpers.funcs
local matches = helpers.matches
local pesc = helpers.pesc
local rmdir = helpers.rmdir
local sleep = helpers.sleep
local meths = helpers.meths

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

    -- Create three windows: first two from top show same terminal, third -
    -- another one (created earlier).
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

    eq(funcs.winbufnr(1), funcs.winbufnr(2))
    neq(funcs.winbufnr(1), funcs.winbufnr(3))
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
    eq(cwd_dir .. get_pathsep() .. tmpfile_base .. '2', funcs.expand('%:p'))
  end)

  it('restores CWD for :terminal buffers #11288', function()
    local cwd_dir = funcs.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    cwd_dir = cwd_dir:gsub([[\]], '/')  -- :mksession always uses unix slashes.
    local session_path = cwd_dir..'/'..session_file

    command('cd '..tab_dir)
    command('terminal')
    command('cd '..cwd_dir)
    command('mksession '..session_path)
    command('bdelete!')
    if iswin() then
      sleep(100)  -- Make sure all child processes have exited.
    end
    command('qall!')

    -- Create a new test instance of Nvim.
    clear()
    command('silent source '..session_path)

    local expected_cwd = cwd_dir..'/'..tab_dir
    matches('^term://'..pesc(expected_cwd)..'//%d+:', funcs.expand('%'))
    command('bdelete!')
    if iswin() then
      sleep(100)  -- Make sure all child processes have exited.
    end
  end)

  it('restores CWD for :terminal buffer at root directory #16988', function()
    if iswin() then
      pending('N/A for Windows')
      return
    end

    local screen
    local cwd_dir = funcs.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    local session_path = cwd_dir..'/'..session_file

    screen = Screen.new(50, 6)
    screen:attach({rgb=false})
    local expected_screen = [[
      ^/                                                 |
                                                        |
      [Process exited 0]                                |
                                                        |
                                                        |
                                                        |
    ]]

    command('cd /')
    command('terminal echo $PWD')

    -- Verify that the terminal's working directory is "/".
    screen:expect(expected_screen)

    command('cd '..cwd_dir)
    command('mksession '..session_path)
    command('qall!')

    -- Create a new test instance of Nvim.
    clear()
    screen = Screen.new(50, 6)
    screen:attach({rgb=false})
    command('silent source '..session_path)

    -- Verify that the terminal's working directory is "/".
    screen:expect(expected_screen)
  end)

  it('restores a session when there is a float #18432', function()
    local tmpfile = file_prefix .. '-tmpfile-float'

    command('edit ' .. tmpfile)
    local buf = meths.create_buf(false, true)
    local config = {
      relative = 'editor',
      focusable = false,
      width = 10,
      height = 3,
      row = 0,
      col = 1,
      style = 'minimal'
    }
    meths.open_win(buf, false, config)
    local cmdheight = meths.get_option('cmdheight')
    command('mksession ' .. session_file)

    -- Create a new test instance of Nvim.
    clear()

    command('source ' .. session_file)

    eq(tmpfile, funcs.expand('%'))
    -- Check that there is only a single window, which indicates the floating
    -- window was not restored.
    eq(1, funcs.winnr('$'))
    -- The command-line height should remain the same as it was.
    eq(cmdheight, meths.get_option('cmdheight'))

    os.remove(tmpfile)
  end)
end)
