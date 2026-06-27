-- Tests for non-blocking cmdwin. #40312

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local feed = n.feed
local api = n.api
local fn = n.fn
local exec_lua = n.exec_lua
local eq = t.eq

describe('cmdwin', function()
  before_each(n.clear)

  it('q: opens cmdwin', function()
    feed('q:')
    eq(':', fn.getcmdwintype())
    eq('[Command Line]', vim.fs.basename(api.nvim_buf_get_name(0)))
    -- cmdwin-char is shown in window-local 'statuscolumn'.
    eq('%#NonText#:', api.nvim_get_option_value('statuscolumn', { win = 0 }))

    eq('nofile', api.nvim_get_option_value('buftype', { buf = 0 }))
    eq('wipe', api.nvim_get_option_value('bufhidden', { buf = 0 }))
    eq(false, api.nvim_get_option_value('swapfile', { buf = 0 }))
    eq(true, api.nvim_get_option_value('buflisted', { buf = 0 })) -- #40431
    eq(true, api.nvim_get_option_value('winfixbuf', { win = 0 }))

    -- <CR> executes the cmdline
    feed('ilet g:cmdwin_result = 42<Esc>')
    feed('<CR>')
    eq(42, api.nvim_get_var('cmdwin_result'))
    eq('', fn.getcmdwintype())
  end)

  it('q/ opens cmdwin with search history', function()
    fn.histadd('/', 'foo')
    fn.histadd('/', 'bar')
    feed('q/')
    eq('/', fn.getcmdwintype())
    -- The "/" history is presented, plus an empty editable last line.
    eq({ 'foo', 'bar', '' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('c_CTRL-F opens cmdwin pre-filled with current cmdline', function()
    fn.histadd(':', 'let g:x = 1')
    fn.histadd(':', 'let g:y = 2')
    feed(':echo "hi"<C-F>')
    n.poke_eventloop()
    eq(':', fn.getcmdwintype())
    -- The ":" history is presented. The in-flight cmdline must not be added to history (else it shows up twice).
    eq({ 'let g:x = 1', 'let g:y = 2', 'echo "hi"' }, api.nvim_buf_get_lines(0, 0, -1, false))
    eq(2, fn.histnr('cmd')) -- History unchanged (the in-flight cmdline was not added).
  end)

  it('history entry with literal newline char', function()
    fn.histadd(':', 'echo \n x')
    feed('q:')
    eq(':', fn.getcmdwintype())
    eq('echo \0 x', api.nvim_buf_get_lines(0, 0, 1, false)[1])
  end)

  it('<C-C> in normal mode cancels without executing', function()
    feed('q:')
    feed('ilet g:executed = 1<Esc>')
    feed('<C-C>')
    eq('', fn.getcmdwintype())
    -- The cancelled line is neither executed nor added to history. It is pre-filled into the
    -- cmdline; reopening via c_CTRL-F must then not duplicate it.
    eq(0, fn.exists('g:executed'))
    eq(-1, fn.histnr('cmd'))
  end)

  it('async API calls work while cmdwin is open #40312', function()
    feed('q:')
    eq(':', fn.getcmdwintype())
    local ok, err = pcall(function()
      local b = api.nvim_create_buf(true, false)
      api.nvim_buf_delete(b, { force = true })
    end)
    eq(true, ok, 'buf_delete unexpectedly failed: ' .. tostring(err))
  end)

  it('textlock does not include cmdwin #40312', function()
    feed('q:')
    -- Setting an option from API used to fail with E11 in cmdwin.
    api.nvim_set_option_value('wildignore', '*.tmp', {})
  end)

  it('E1292 cannot nest cmdwin', function()
    feed('q:')
    eq(':', fn.getcmdwintype())
    feed('q:')
    -- Still just one cmdwin.
    eq(':', fn.getcmdwintype())
    local nwin = 0
    for _, w in ipairs(api.nvim_list_wins()) do
      if api.nvim_get_option_value('winfixbuf', { win = w }) then
        nwin = nwin + 1
      end
    end
    eq(1, nwin)
  end)

  it(':quit closes cmdwin', function()
    feed('q:')
    eq(':', fn.getcmdwintype())
    exec_lua([[
      _G.events = {}
      vim.api.nvim_create_autocmd('WinEnter', {
        callback = function() table.insert(_G.events, vim.api.nvim_get_current_win()) end,
      })
    ]])
    feed(':q<CR>')
    eq('', fn.getcmdwintype())
    eq({ api.nvim_get_current_win() }, exec_lua('return _G.events'))
  end)

  it(':messages from inside cmdwin works #40312', function()
    -- Before #40312, this raised E11 because text_locked() returned true for cmdwin.
    exec_lua([[vim.api.nvim_echo({{'hello from history'}}, true, {})]])
    feed('q:')
    eq(':', fn.getcmdwintype())
    n.command('messages') -- Previously E11; now actually runs.
  end)

  it('CmdwinEnter/CmdwinLeave events', function()
    exec_lua([[
      _G.events = {}
      vim.api.nvim_create_autocmd('CmdwinEnter', {
        callback = function(a) table.insert(_G.events, 'enter:'..a.match) end,
      })
      vim.api.nvim_create_autocmd('CmdwinLeave', {
        callback = function(a) table.insert(_G.events, 'leave:'..a.match) end,
      })
    ]])
    feed('q:')
    n.poke_eventloop() -- Ensure q: is processed before <C-C>.
    feed('<C-C>')
    eq({ 'enter::', 'leave::' }, exec_lua('return _G.events'))
  end)
end)
