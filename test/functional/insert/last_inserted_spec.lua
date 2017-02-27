local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local expect = helpers.expect

clear()
describe('Insert mode Control Space', function()
    it('inserts last inserted text and leaves insert mode', function()
        insert('hello')
        feed('i<C-@>x')
        expect('hellhello')
    end)
    -- Ensure the same happens for both C-Space and C-@
    it('inserts last inserted text and leaves insert mode', function()
        feed('i<C-Space>x')
        expect('hellhellhello')
    end)
end)

describe('Insert mode Control-A', function()
    it('inserts last inserted text', function()
        feed('i<C-A>x')
        expect('hellhellhellhelloxo')
    end)
end)
