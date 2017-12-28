local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
-- local source = helpers.source
-- local dedent = helpers.dedent
local funcs = helpers.funcs

before_each(clear)
describe('autocmd registration', function()
  it('should register autocmds', function()
    funcs.luaeval([[require('lsp.autocmds').export_autocmds()]])

    local BufWritePost_autocmd = funcs.execute([[autocmd BufWritePost *]])
    print('TODO: BUFWRITEPOST', BufWritePost_autocmd)
  end)
end)
