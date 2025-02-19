local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local get_pathsep = n.get_pathsep
local eq = t.eq
local neq = t.neq
local fn = n.fn
local matches = t.matches
local pesc = vim.pesc
local rmdir = n.rmdir
local sleep = vim.uv.sleep
local api = n.api
local skip = t.skip
local is_os = t.is_os
local mkdir = t.mkdir

local file_prefix = 'Xtest-functional-ex_cmds-mksession_spec'

describe(':mksession', function()
  local session_file = file_prefix .. '.vim'
  local tab_dir = file_prefix .. '.d'

  before_each(function()
    clear()
    mkdir(tab_dir)
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
    command('mksession ' .. session_file)
    command('%bwipeout!')

    -- Create a new test instance of Nvim.
    clear()
    -- Restore session.
    command('source ' .. session_file)

    eq(fn.winbufnr(1), fn.winbufnr(2))
    neq(fn.winbufnr(1), fn.winbufnr(3))
  end)

  -- common testing procedure for testing "sessionoptions-=terminal"
  local function test_terminal_session_disabled(expected_buf_count)
    command('set sessionoptions-=terminal')

    command('mksession ' .. session_file)

    -- Create a new test instance of Nvim.
    clear()

    -- Restore session.
    command('source ' .. session_file)

    eq(expected_buf_count, #api.nvim_list_bufs())
  end

  it('do not restore :terminal if not set in sessionoptions, terminal in curwin #13078', function()
    local tmpfile_base = file_prefix .. '-tmpfile'
    command('edit ' .. tmpfile_base)
    command('terminal')

    local buf_count = #api.nvim_list_bufs()
    eq(2, buf_count)

    eq('terminal', api.nvim_get_option_value('buftype', {}))

    test_terminal_session_disabled(2)

    -- no terminal should be set. As a side effect we end up with a blank buffer
    eq('', api.nvim_get_option_value('buftype', { buf = api.nvim_list_bufs()[1] }))
    eq('', api.nvim_get_option_value('buftype', { buf = api.nvim_list_bufs()[2] }))
  end)

  it('do not restore :terminal if not set in sessionoptions, terminal hidden #13078', function()
    command('terminal')
    local terminal_bufnr = api.nvim_get_current_buf()

    local tmpfile_base = file_prefix .. '-tmpfile'
    -- make terminal hidden by opening a new file
    command('edit ' .. tmpfile_base .. '1')

    local buf_count = #api.nvim_list_bufs()
    eq(2, buf_count)

    eq(1, fn.getbufinfo(terminal_bufnr)[1].hidden)

    test_terminal_session_disabled(1)

    -- no terminal should exist here
    neq('', api.nvim_buf_get_name(api.nvim_list_bufs()[1]))
  end)

  it('do not restore :terminal if not set in sessionoptions, only buffer #13078', function()
    command('terminal')
    eq('terminal', api.nvim_get_option_value('buftype', {}))

    local buf_count = #api.nvim_list_bufs()
    eq(1, buf_count)

    test_terminal_session_disabled(1)

    -- no terminal should be set
    eq('', api.nvim_get_option_value('buftype', {}))
  end)

  it('restores tab-local working directories', function()
    local tmpfile_base = file_prefix .. '-tmpfile'
    local cwd_dir = fn.getcwd()

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
    eq(cwd_dir, fn.getcwd())
    -- Second tab should have the tab-local working directory.
    command('tabnext 2')
    eq(cwd_dir .. get_pathsep() .. tab_dir, fn.getcwd())
  end)

  it('restores buffers with tab-local CWD', function()
    local tmpfile_base = file_prefix .. '-tmpfile'
    local cwd_dir = fn.getcwd()
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
    eq(cwd_dir .. get_pathsep() .. tmpfile_base .. '1', fn.expand('%:p'))
    command('tabnext 2')
    eq(cwd_dir .. get_pathsep() .. tmpfile_base .. '2', fn.expand('%:p'))
  end)

  it('restores CWD for :terminal buffers #11288', function()
    skip(is_os('win'), 'causes rmdir() to fail')

    local cwd_dir = fn.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    cwd_dir = t.fix_slashes(cwd_dir) -- :mksession always uses unix slashes.
    local session_path = cwd_dir .. '/' .. session_file

    command('cd ' .. tab_dir)
    command('terminal')
    command('cd ' .. cwd_dir)
    command('mksession ' .. session_path)
    command('%bwipeout!')
    if is_os('win') then
      sleep(100) -- Make sure all child processes have exited.
    end

    -- Create a new test instance of Nvim.
    clear()
    command('silent source ' .. session_path)

    local expected_cwd = cwd_dir .. '/' .. tab_dir
    matches('^term://' .. pesc(expected_cwd) .. '//%d+:', fn.expand('%'))
    command('%bwipeout!')
    if is_os('win') then
      sleep(100) -- Make sure all child processes have exited.
    end
  end)

  it('restores CWD for :terminal buffer at root directory #16988', function()
    skip(is_os('win'), 'N/A for Windows')

    local screen
    local cwd_dir = fn.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    local session_path = cwd_dir .. '/' .. session_file

    screen = Screen.new(50, 6, { rgb = false })
    local expected_screen = [[
      ^/                                                 |
                                                        |
      [Process exited 0]                                |
                                                        |*3
    ]]

    command('cd /')
    command('terminal echo $PWD')

    -- Verify that the terminal's working directory is "/".
    screen:expect(expected_screen)

    command('cd ' .. cwd_dir)
    command('mksession ' .. session_path)
    command('%bwipeout!')

    -- Create a new test instance of Nvim.
    clear()
    screen = Screen.new(50, 6, { rgb = false })
    command('silent source ' .. session_path)

    -- Verify that the terminal's working directory is "/".
    screen:expect(expected_screen)
  end)

  it('restores a session when there is a float #18432', function()
    local tmpfile = file_prefix .. '-tmpfile-float'

    command('edit ' .. tmpfile)
    local buf = api.nvim_create_buf(false, true)
    local config = {
      relative = 'editor',
      focusable = false,
      width = 10,
      height = 3,
      row = 0,
      col = 1,
      style = 'minimal',
    }
    api.nvim_open_win(buf, false, config)
    local cmdheight = api.nvim_get_option_value('cmdheight', {})
    command('mksession ' .. session_file)

    -- Create a new test instance of Nvim.
    clear()

    command('source ' .. session_file)

    eq(tmpfile, fn.expand('%'))
    -- Check that there is only a single window, which indicates the floating
    -- window was not restored.
    eq(1, fn.winnr('$'))
    -- The command-line height should remain the same as it was.
    eq(cmdheight, api.nvim_get_option_value('cmdheight', {}))

    os.remove(tmpfile)
  end)
end)
