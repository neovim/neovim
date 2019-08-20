local helpers = require('test.functional.helpers')(after_each)

local eval = helpers.eval
local clear = helpers.clear
local command = helpers.command

describe('autocmd FileType', function()
    before_each(clear)

    it("is triggered by :help only once", function()
        -- Add runtime from build dir for doc/tags (used with :help).
        command(string.format([[set rtp+=%s/runtime]], helpers.test_build_dir))
        command("let g:foo = 0")
        command("autocmd FileType help let g:foo = g:foo + 1")
        command("help help")
        assert.same(1, eval('g:foo'))
    end)
end)
