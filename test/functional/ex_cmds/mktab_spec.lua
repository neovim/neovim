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

local file_prefix = 'Xtest-functional-ex_cmds-mktab_spec'

describe(":mktab", function()
  local tabpage_file = file_prefix .. '.vim'
  local temp_file, buf_file = nil

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
      command("%bwipeout!")
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

end)



