local helpers = require('test.functional.helpers')(after_each)
local clear, nvim, eq = helpers.clear, helpers.nvim, helpers.eq

describe('TabClosed', function()
  before_each(clear)

  describe('au TabClosed', function()
    describe('with * as <afile>', function()
      it('matches when closing any tab', function()
        nvim('command', 'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()')
        repeat
          nvim('command', 'tabnew')
        until nvim('eval', 'tabpagenr()') == 6 -- current tab is now 6
        eq("tabclosed:6:6:5", nvim('command_output', 'tabclose')) -- close last 6, current tab is now 5
        eq("tabclosed:5:5:4", nvim('command_output', 'close')) -- close last window on tab, closes tab
        eq("tabclosed:2:2:3", nvim('command_output', '2tabclose')) -- close tab 2, current tab is now 3
        eq("tabclosed:1:1:2\ntabclosed:1:1:1", nvim('command_output', 'tabonly')) -- close tabs 1 and 2
      end)

      it('is triggered when closing a window via bdelete from another tab', function()
        nvim('command', 'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()')
        nvim('command', '1tabedit Xtestfile')
        nvim('command', '1tabedit Xtestfile')
        nvim('command', 'normal! 1gt')
        eq({1, 3}, nvim('eval', '[tabpagenr(), tabpagenr("$")]'))
        eq("tabclosed:2:2:1\ntabclosed:2:2:1", nvim('command_output', 'bdelete Xtestfile'))
        eq({1, 1}, nvim('eval', '[tabpagenr(), tabpagenr("$")]'))
      end)

      it('is triggered when closing a window via bdelete from current tab', function()
        nvim('command', 'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()')
        nvim('command', 'file Xtestfile1')
        nvim('command', '1tabedit Xtestfile2')
        nvim('command', '1tabedit Xtestfile2')

        -- Only one tab is closed, and the alternate file is used for the other.
        eq({2, 3}, nvim('eval', '[tabpagenr(), tabpagenr("$")]'))
        eq("tabclosed:2:2:2", nvim('command_output', 'bdelete Xtestfile2'))
        eq('Xtestfile1', nvim('eval', 'bufname("")'))
      end)
    end)

    describe('with NR as <afile>', function()
      it('matches when closing a tab whose index is NR', function()
        nvim('command', 'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()')
        nvim('command', 'au! TabClosed 2 echom "tabclosed:match"')
        repeat
          nvim('command',  'tabnew')
        until nvim('eval', 'tabpagenr()') == 7 -- current tab is now 7
        -- sanity check, we shouldn't match on tabs with numbers other than 2
        eq("tabclosed:7:7:6", nvim('command_output', 'tabclose'))
        -- close tab page 2, current tab is now 5
        eq("tabclosed:2:2:5\ntabclosed:match", nvim('command_output', '2tabclose'))
      end)
    end)

    describe('with close', function()
      it('is triggered', function()
        nvim('command', 'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()')
        nvim('command',  'tabedit Xtestfile')
        eq({2, 2}, nvim('eval', '[tabpagenr(), tabpagenr("$")]'))
        eq("tabclosed:2:2:1", nvim('command_output', 'close'))
        eq({1, 1}, nvim('eval', '[tabpagenr(), tabpagenr("$")]'))
      end)
    end)
  end)
end)

