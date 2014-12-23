local helpers = require('test.functional.helpers')
local clear, nvim, buffer, curbuf, curwin, eq, neq, ok =
  helpers.clear, helpers.nvim, helpers.buffer, helpers.curbuf, helpers.curwin,
  helpers.eq, helpers.neq, helpers.ok

describe('TabNewEntered', function()
    describe('au TabNewEntered', function()
        describe('with * as <afile>', function()
            it('matches when entering any new tab', function()
                clear()
                nvim('command', 'au! TabNewEntered * echom "tabnewentered:".tabpagenr().":".bufnr("")')
                eq("\ntabnewentered:2:2", nvim('command_output', 'tabnew'))
                eq("\n\"test.x2\" [New File]\ntabnewentered:3:3", nvim('command_output', 'tabnew test.x2'))
           end)
        end)
        describe('with FILE as <afile>', function()
            it('matches when opening a new tab for FILE', function()
                tmp_path = nvim('eval', 'tempname()')
                nvim('command', 'au! TabNewEntered '..tmp_path..' echom "tabnewentered:match"')
                eq("\n\""..tmp_path.."\" [New File]\ntabnewentered:4:4\ntabnewentered:match", nvim('command_output', 'tabnew '..tmp_path))
           end)
        end)
    end)
end)
