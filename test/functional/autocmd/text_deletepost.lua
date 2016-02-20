local helpers = require('test.functional.helpers')
local clear, eval, eq = helpers.clear, helpers.eval, helpers.eq
local feed, execute = helpers.feed, helpers.execute


describe('TextDeletePost', function()
    before_each(function()
        clear()
    end)

    describe('au TextDeletePost', function()
        it('is executed after delete', function()
            feed('ifoo<ESC>')
            execute('let g:foo = 0')
            execute('autocmd! TextDeletePost * let g:foo = 1')
            feed('dd')
            eq(1, eval('g:foo'))
        end)
        it('is not executed after yank', function()
            feed('ifoo<ESC>')
            execute('let g:foo = 0')
            execute('autocmd! TextDeletePost * let g:foo = 1')
            feed('yy')
            eq(0, eval('g:foo'))
        end)
    end)
end)
