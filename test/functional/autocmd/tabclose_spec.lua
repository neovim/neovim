local helpers = require('test.functional.helpers')(after_each)
local clear, nvim, eq = helpers.clear, helpers.nvim, helpers.eq

describe('TabClosed', function()
    describe('au TabClosed', function()
        describe('with * as <afile>', function()
            it('matches when  closing any tab', function()
                clear()
                nvim('command', 'au! TabClosed * echom "tabclosed:".expand("<afile>").":".expand("<amatch>").":".tabpagenr()')
                repeat 
                    nvim('command',  'tabnew')
                until nvim('eval', 'tabpagenr()') == 6 -- current tab is now 6
                eq("\ntabclosed:6:6:5", nvim('command_output', 'tabclose')) -- close last 6, current tab is now 5
                eq("\ntabclosed:5:5:4", nvim('command_output', 'close')) -- close last window on tab, closes tab
                eq("\ntabclosed:2:2:3", nvim('command_output', '2tabclose')) -- close tab 2, current tab is now 3
                eq("\ntabclosed:1:1:2\ntabclosed:1:1:1", nvim('command_output', 'tabonly')) -- close tabs 1 and 2
            end)
        end)
        describe('with NR as <afile>', function()
            it('matches when  closing a tab whose index is NR', function()
                nvim('command', 'au! TabClosed 2 echom "tabclosed:match"')
                repeat 
                    nvim('command',  'tabnew')
                until nvim('eval', 'tabpagenr()') == 5 -- current tab is now 5
                -- sanity check, we shouldn't match on tabs with numbers other than 2
                eq("\ntabclosed:5:5:4", nvim('command_output', 'tabclose'))
                -- close tab page 2, current tab is now 3
                eq("\ntabclosed:2:2:3\ntabclosed:match", nvim('command_output', '2tabclose'))
            end)
        end)
    end)
end)

