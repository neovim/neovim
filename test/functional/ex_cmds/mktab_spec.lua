local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local get_pathsep = n.get_pathsep
local eq = t.eq
local neq = t.neq
local fn = n.fn
local rmdir = n.rmdir
local api = n.api
local skip = t.skip
local is_os = t.is_os
local mkdir = t.mkdir

local file_prefix = 'Xtest-functional-ex_cmds-mktab_spec'

describe(':mktab', function()
  local tabpage_file = file_prefix .. '.vim'
  local tab_dir = file_prefix .. '.d'

  before_each(function()
    clear()
  end)

  after_each(function()
    os.remove(tabpage_file)
  end)

  local function test_terminal_disabled(expected_buf_count)
    command('set taboptions-=terminal')

    command('mktab ' .. tabpage_file)

    -- Create a new test instance of Nvim.
    command('%bwipeout!')
    clear()

    -- Restore session.
    command('source ' .. tabpage_file)

    eq(expected_buf_count, #api.nvim_list_bufs())
  end

  it('restore same :terminal buf in splits', function()
    command('terminal')
    command('split')
    command('terminal')
    command('split')
    command('mktab ' .. tabpage_file)
    command('%bwipeout!')

    clear()

    command('source ' .. tabpage_file)

    eq(fn.winbufnr(1), fn.winbufnr(2))
    neq(fn.winbufnr(1), fn.winbufnr(3))
  end)

  it('restore a single tabpage without overriding others', function()
    command('terminal')
    command('tabnew')
    command('terminal')
    command('split')
    command('mktab ' .. tabpage_file)

    command('%bwipeout!')
    clear()

    command('source ' .. tabpage_file)
    command('source ' .. tabpage_file)

    eq(fn.tabpagenr('$'), 3)
    neq(fn.tabpagebuflist(1), fn.tabpagebuflist(2))
    eq(fn.tabpagebuflist(2), fn.tabpagebuflist(3))
    eq(fn.tabpagewinnr(1, '$'), 1)
    eq(fn.tabpagewinnr(2, '$'), 2)

    command('terminal')
  end)

  it('do not restore :terminal if not set in taboptions, terminal in curwin #13078', function()
    local tmpfile_base = file_prefix .. '-tmpfile'
    command('edit ' .. tmpfile_base)
    command('terminal')

    local buf_count = #api.nvim_list_bufs()
    eq(2, buf_count)

    eq('terminal', api.nvim_get_option_value('buftype', {}))

    test_terminal_disabled(3)

    -- no terminal should be set. As a side effect we end up with a blank buffer
    eq('', api.nvim_get_option_value('buftype', { buf = api.nvim_list_bufs()[2] }))
    eq('', api.nvim_get_option_value('buftype', { buf = api.nvim_list_bufs()[3] }))
  end)

  it('do not restore :terminal if not set in taboptions, terminal hidden #13078', function()
    command('terminal')
    local terminal_bufnr = api.nvim_get_current_buf()

    local tmpfile_base = file_prefix .. '-tmpfile'
    -- make terminal hidden by opening a new file
    command('edit ' .. tmpfile_base .. '1')

    local buf_count = #api.nvim_list_bufs()
    eq(2, buf_count)

    eq(1, fn.getbufinfo(terminal_bufnr)[1].hidden)

    test_terminal_disabled(2)

    -- no terminal should exist here
    neq('', api.nvim_buf_get_name(api.nvim_list_bufs()[2]))
  end)

  it('do not restore :terminal if not set in sessionoptions, only buffer #13078', function()
    command('terminal')
    eq('terminal', api.nvim_get_option_value('buftype', {}))

    local buf_count = #api.nvim_list_bufs()
    eq(1, buf_count)

    test_terminal_disabled(2)

    -- no terminal should be set
    eq('', api.nvim_get_option_value('buftype', {}))
  end)

  it('restores tab-local working directories', function()
    local tmpfile_base = file_prefix .. '-tmpfile'
    local cwd_dir = fn.getcwd()
    mkdir(tab_dir)

    -- :mksession does not save empty tabs, so create some buffers.
    command('edit ' .. tmpfile_base .. '1')
    command('tabnew')
    command('edit ' .. tmpfile_base .. '2')
    command('tcd ' .. tab_dir)
    command('mktab ' .. tabpage_file)

    -- Create a new test instance of Nvim.
    clear()

    command('source ' .. vim.fs.joinpath(tab_dir, tabpage_file))

    neq(cwd_dir, fn.getcwd())
    eq(cwd_dir .. get_pathsep() .. tab_dir, fn.getcwd())

    rmdir(tab_dir)
  end)

  it('restores CWD for :terminal buffer at root directory #16988', function()
    skip(is_os('win'), 'N/A for Windows')

    local screen
    local cwd_dir = fn.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    local tab_path = vim.fs.joinpath(cwd_dir, tabpage_file)

    screen = Screen.new(50, 6, {})
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
    command('mktab ' .. tab_path)
    command('%bwipeout!')

    -- Create a new test instance of Nvim.
    clear()
    screen = Screen.new(50, 6, { rgb = true })
    command('silent source ' .. tab_path)
    command('silent tabfirst')
    command('silent tabclose')

    -- Verify that the terminal's working directory is "/".
    -- Undeterministic error with expected_screen here, might be a racing condition with redraw ?
    screen:expect({ any = '^%^/' })
  end)

  it('restores a session when there is a float #18432', function()
    local tmpfile = file_prefix .. '-tmpfile-float'

    command('edit ' .. tmpfile)
    eq(80, fn.winwidth(1))
    command('30vsplit')
    eq(2, #api.nvim_list_wins())
    eq(30, fn.winwidth(1))
    eq(49, fn.winwidth(2))
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
    eq(3, #api.nvim_list_wins())
    local cmdheight = api.nvim_get_option_value('cmdheight', {})
    command('mktab ' .. tabpage_file)

    -- Create a new test instance of Nvim.
    clear()

    command('source ' .. tabpage_file)

    eq(tmpfile, fn.expand('%'))
    -- Check that there are only two windows, which indicates the floating
    -- window was not restored.
    -- Don't use winnr('$') as that doesn't count unfocusable floating windows.
    command('tabfirst')
    command('tabclose')
    eq(2, #api.nvim_list_wins())
    eq(30, fn.winwidth(1))
    eq(49, fn.winwidth(2))
    -- The command-line height should remain the same as it was.
    eq(cmdheight, api.nvim_get_option_value('cmdheight', {}))

    os.remove(tmpfile)
  end)
end)
