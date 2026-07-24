-- Tests for non-blocking cmdwin. #40312

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
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

  it('<CR> closes all cmdwin (split) windows #40484', function()
    feed('q:')
    feed('ilet g:cmdwin_result = 7<Esc>')
    feed('<C-w>s') -- split: two windows now show the cmdwin buffer.
    local cmdwin_buf = api.nvim_get_current_buf()
    eq(2, #fn.win_findbuf(cmdwin_buf)) -- sanity: the split happened

    feed('<CR>')
    eq(7, api.nvim_get_var('cmdwin_result')) -- the cmdline executed
    eq('', fn.getcmdwintype())
    eq(0, #fn.win_findbuf(cmdwin_buf)) -- All cmdwin windows are closed.
    eq(1, #api.nvim_list_wins()) -- Back to the single original window.
  end)

  it('<CR> executes when cmdwin was moved to another tabpage #40484', function()
    feed('q:')
    feed('ilet g:cmdwin_result = 9<Esc>')
    feed('<C-w>T') -- Move the cmdwin to its own new tabpage.
    eq(2, fn.tabpagenr('$')) -- sanity: the new tabpage exists
    local cmdwin_buf = api.nvim_get_current_buf()

    feed('<CR>')
    eq(9, api.nvim_get_var('cmdwin_result')) -- the cmdline executed.
    eq('', fn.getcmdwintype())
    eq(0, #fn.win_findbuf(cmdwin_buf)) -- cmdwin window closed.
    eq(1, fn.tabpagenr('$')) -- cmdwin's tabpage is gone.
    eq(1, #api.nvim_list_wins())
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

  it('c_CTRL-F from insert-mode expr register evaluates+inserts, resumes Insert #40407', function()
    -- The expr register (i_CTRL-R =) hosted by Insert mode supports c_CTRL-F: the cmdwin opens for
    -- the expression; on confirm it is evaluated and the result inserted at the cursor.
    feed('ifoo <C-R>=1+2')
    n.poke_eventloop()
    feed('<C-F>')
    n.poke_eventloop()
    eq('=', fn.getcmdwintype())
    eq({ '1+2' }, api.nvim_buf_get_lines(0, 0, -1, false)) -- cmdwin holds the expression
    feed('<CR>')
    n.poke_eventloop()
    eq('', fn.getcmdwintype())
    eq('foo 3', api.nvim_get_current_line())
    eq('i', api.nvim_get_mode().mode) -- Insert mode resumed after the result
    feed('X<Esc>')
    eq('foo 3X', api.nvim_get_current_line()) -- typing continues after the inserted result
  end)

  it('c_CTRL-F expr register: string result, mid-line, and <C-C> cancel #40407', function()
    -- Mid-line insertion + string result.
    feed("iabc<Left><C-R>='X'.'Y'")
    n.poke_eventloop()
    feed('<C-F>')
    n.poke_eventloop()
    eq('=', fn.getcmdwintype())
    feed('<CR>')
    n.poke_eventloop()
    eq('abXYc', api.nvim_get_current_line())
    feed('<Esc>')

    -- <C-C> cancels: nothing inserted, Insert mode resumes in the host.
    feed('o<C-R>=1+1')
    n.poke_eventloop()
    feed('<C-F>')
    n.poke_eventloop()
    eq('=', fn.getcmdwintype())
    feed('<C-C>')
    n.poke_eventloop()
    eq('', fn.getcmdwintype())
    eq('', api.nvim_get_current_line()) -- cancelled: no result inserted
    eq('i', api.nvim_get_mode().mode)
  end)

  it('<C-C> in normal mode cancels without executing', function()
    feed('q:')
    feed('ilet g:executed = 1<Esc>')
    n.poke_eventloop() -- Ensure previous input is processed before <C-C>.
    feed('<C-C>')
    eq('', fn.getcmdwintype())
    -- The cancelled line is neither executed nor added to history. It is pre-filled into the
    -- cmdline; reopening via c_CTRL-F must then not duplicate it.
    eq(0, fn.exists('g:executed'))
    eq(-1, fn.histnr('cmd'))
    eq('let g:executed = 1', fn.getcmdline())
    eq(':', fn.getcmdtype())
  end)

  it('history entry or current cmdline with control chars', function()
    local firstbuf = api.nvim_get_current_buf()
    local cmdline = 'normal! \023\022ifoo\nbar\027' -- Ctrl-W Ctrl-V ifoo\nbar Esc
    local bufline = cmdline:gsub('\n', '\0')
    fn.histadd(':', cmdline)
    feed('q:')
    eq(':', fn.getcmdwintype())
    eq({ bufline, '' }, api.nvim_buf_get_lines(0, 0, -1, false))
    api.nvim_win_set_cursor(0, { 1, 0 })
    feed('<C-C>')
    eq(cmdline, fn.getcmdline())
    eq(':', fn.getcmdtype())
    eq({ firstbuf }, fn.tabpagebuflist())
    feed('<C-F>')
    n.poke_eventloop()
    eq(':', fn.getcmdwintype())
    eq({ bufline, bufline }, api.nvim_buf_get_lines(0, 0, -1, false))
    feed('<CR>')
    eq({ firstbuf, firstbuf }, fn.tabpagebuflist())
    eq({ 'foo', 'bar' }, api.nvim_buf_get_lines(0, 0, -1, false))
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
