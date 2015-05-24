local helpers = require('test.functional.helpers')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute
local eval, eq, neq = helpers.eval, helpers.eq, helpers.neq
local execute, source = helpers.execute, helpers.source

describe("completion", function()
  before_each(function()
    clear()
  end)

  describe("v:completed_item", function()
    it('returns expected dict in normal completion', function()
      feed('ifoo<ESC>o<C-x><C-n><ESC>')
      eq('foo', eval('getline(2)'))
      eq({word = 'foo', abbr = '', menu = '', info = '', kind = ''},
        eval('v:completed_item'))
    end)
    it('is readonly', function()
      feed('ifoo<ESC>o<C-x><C-n><ESC>')

      execute('let v:completed_item.word = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      execute('let v:errmsg = ""')

      execute('let v:completed_item.abbr = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      execute('let v:errmsg = ""')

      execute('let v:completed_item.menu = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      execute('let v:errmsg = ""')

      execute('let v:completed_item.info = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      execute('let v:errmsg = ""')

      execute('let v:completed_item.kind = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      execute('let v:errmsg = ""')
    end)
    it('returns expected dict in omni completion', function()
      source([[
      function! TestOmni(findstart, base) abort
        return a:findstart ? 0 : [{'word': 'foo', 'abbr': 'bar',
        \ 'menu': 'baz', 'info': 'foobar', 'kind': 'foobaz'}]
      endfunction
      setlocal omnifunc=TestOmni
      ]])
      feed('i<C-x><C-o><ESC>')
      eq('foo', eval('getline(1)'))
      eq({word = 'foo', abbr = 'bar', menu = 'baz',
          info = 'foobar', kind = 'foobaz'},
        eval('v:completed_item'))
    end)
  end)
end)
