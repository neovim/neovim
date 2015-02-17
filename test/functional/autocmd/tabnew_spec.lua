local helpers = require('test.functional.helpers')
local clear, nvim, buffer, curbuf, curwin, eq, neq, ok =
  helpers.clear, helpers.nvim, helpers.buffer, helpers.curbuf, helpers.curwin,
  helpers.eq, helpers.neq, helpers.ok

describe('TabNew', function()
    describe('au TabNew', function()
        clear()
        describe('with * as <afile>', function()
            it('matches when opening any new tab', function()
                nvim('command', 'au! TabNew * echom "tabnew:".tabpagenr().":".bufnr("")')
                eq("\ntabnew:2:1", nvim('command_output', 'tabnew'))
                eq("\ntabnew:3:2\n\"test.x\" [New File]", nvim('command_output', 'tabnew test.x'))
            end)
        end)
        describe('with FILE as <afile>', function()
            it('matches when opening a new tab for FILE', function()
                tmp_path = nvim('eval', 'tempname()')
                nvim('command', 'au! TabNew '..tmp_path..' echom "tabnew:match"')
                eq("\ntabnew:4:3\ntabnew:match\n\""..tmp_path.."\" [New File]", nvim('command_output', 'tabnew '..tmp_path))
           end)
        end)
    end)
end)
