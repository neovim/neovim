local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local curwin = helpers.curwin
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local funcs = helpers.funcs
local meths = helpers.meths
local is_os = helpers.is_os

describe('title', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
  end)

  it('has correct default title with unnamed file', function()
    local expected = '[No Name] - NVIM'
    command('set title')
    screen:expect(function()
      eq(expected, screen.title)
    end)
  end)

  it('has correct default title with named file', function()
    local expected = (is_os('win') and 'myfile (C:\\mydir) - NVIM' or 'myfile (/mydir) - NVIM')
    command('set title')
    command(is_os('win') and 'file C:\\mydir\\myfile' or 'file /mydir/myfile')
    screen:expect(function()
      eq(expected, screen.title)
    end)
  end)

  describe('is not changed by', function()
    local file1 = is_os('win') and 'C:\\mydir\\myfile1' or '/mydir/myfile1'
    local file2 = is_os('win') and 'C:\\mydir\\myfile2' or '/mydir/myfile2'
    local expected = (is_os('win') and 'myfile1 (C:\\mydir) - NVIM' or 'myfile1 (/mydir) - NVIM')
    local buf2

    before_each(function()
      command('edit '..file1)
      buf2 = funcs.bufadd(file2)
      command('set title')
    end)

    it('calling setbufvar() to set an option in a hidden buffer from i_CTRL-R', function()
      command([[inoremap <F2> <C-R>=setbufvar(]]..buf2..[[, '&autoindent', 1) ? '' : ''<CR>]])
      feed('i<F2><Esc>')
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('an RPC call to nvim_set_option_value in a hidden buffer', function()
      meths.set_option_value('autoindent', true, { buf = buf2 })
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('a Lua callback calling nvim_set_option_value in a hidden buffer', function()
      exec_lua(string.format([[
        vim.schedule(function()
          vim.api.nvim_set_option_value('autoindent', true, { buf = %d })
        end)
      ]], buf2))
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('a Lua callback calling nvim_buf_call in a hidden buffer', function()
      exec_lua(string.format([[
        vim.schedule(function()
          vim.api.nvim_buf_call(%d, function() end)
        end)
      ]], buf2))
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('setting the buffer of another window using RPC', function()
      local oldwin = curwin().id
      command('split')
      meths.win_set_buf(oldwin, buf2)
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('setting the buffer of another window using Lua callback', function()
      local oldwin = curwin().id
      command('split')
      exec_lua(string.format([[
        vim.schedule(function()
          vim.api.nvim_win_set_buf(%d, %d)
        end)
      ]], oldwin, buf2))
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('creating a floating window using RPC', function()
      meths.open_win(buf2, false, {
        relative = 'editor', width = 5, height = 5, row = 0, col = 0,
      })
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('creating a floating window using Lua callback', function()
      exec_lua(string.format([[
        vim.api.nvim_open_win(%d, false, {
          relative = 'editor', width = 5, height = 5, row = 0, col = 0,
        })
      ]], buf2))
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)
  end)
end)
