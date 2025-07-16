local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, eq = n.clear, t.eq
local api = n.api
local command = n.command
local eval = n.eval
local exec = n.exec

describe('TabClosed', function()
  before_each(clear)

  describe('au TabClosed', function()
    describe('with * as <afile>', function()
      it('matches when closing any tab', function()
        command(
          'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()'
        )
        repeat
          command('tabnew')
        until api.nvim_eval('tabpagenr()') == 6 -- current tab is now 6
        eq('tabclosed:6:6:5', api.nvim_exec('tabclose', true)) -- close last 6, current tab is now 5
        eq('tabclosed:5:5:4', api.nvim_exec('close', true)) -- close last window on tab, closes tab
        eq('tabclosed:2:2:3', api.nvim_exec('2tabclose', true)) -- close tab 2, current tab is now 3
        eq('tabclosed:1:1:2\ntabclosed:1:1:1', api.nvim_exec('tabonly', true)) -- close tabs 1 and 2
      end)

      it('is triggered when closing a window via bdelete from another tab', function()
        command(
          'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()'
        )
        command('1tabedit Xtestfile')
        command('1tabedit Xtestfile')
        command('normal! 1gt')
        eq({ 1, 3 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
        eq('tabclosed:2:2:1\ntabclosed:2:2:1', api.nvim_exec('bdelete Xtestfile', true))
        eq({ 1, 1 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
      end)

      it('is triggered when closing a window via bdelete from current tab', function()
        command(
          'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()'
        )
        command('file Xtestfile1')
        command('1tabedit Xtestfile2')
        command('1tabedit Xtestfile2')

        -- Only one tab is closed, and the alternate file is used for the other.
        eq({ 2, 3 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
        eq('tabclosed:2:2:2', api.nvim_exec('bdelete Xtestfile2', true))
        eq('Xtestfile1', api.nvim_eval('bufname("")'))
      end)

      it('triggers after tab page is properly freed', function()
        exec([[
          let s:tp = nvim_get_current_tabpage()
          let g:buf = bufnr()

          setlocal bufhidden=wipe
          tabnew
          au TabClosed * ++once let g:tp_valid = nvim_tabpage_is_valid(s:tp)
                             \| let g:abuf = expand('<abuf>')

          call nvim_buf_delete(g:buf, #{force: 1})
        ]])
        eq(false, eval('g:tp_valid'))
        eq(false, eval('nvim_buf_is_valid(g:buf)'))
        eq('', eval('g:abuf'))

        exec([[
          tabnew
          let g:buf = bufnr()
          let s:win = win_getid()

          tabfirst
          au TabClosed * ++once let g:abuf = expand('<abuf>')

          call nvim_win_close(s:win, 1)
        ]])
        eq(true, eval('nvim_buf_is_valid(g:buf)'))
        eq(eval('g:buf'), tonumber(eval('g:abuf')))
      end)
    end)

    describe('with NR as <afile>', function()
      it('matches when closing a tab whose index is NR', function()
        command(
          'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()'
        )
        command('au! TabClosed 2 echom "tabclosed:match"')
        repeat
          command('tabnew')
        until api.nvim_eval('tabpagenr()') == 7 -- current tab is now 7
        -- sanity check, we shouldn't match on tabs with numbers other than 2
        eq('tabclosed:7:7:6', api.nvim_exec('tabclose', true))
        -- close tab page 2, current tab is now 5
        eq('tabclosed:2:2:5\ntabclosed:match', api.nvim_exec('2tabclose', true))
      end)
    end)

    describe('with close', function()
      it('is triggered', function()
        command(
          'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()'
        )
        command('tabedit Xtestfile')
        eq({ 2, 2 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
        eq('tabclosed:2:2:1', api.nvim_exec('close', true))
        eq({ 1, 1 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
      end)
    end)
  end)
end)
