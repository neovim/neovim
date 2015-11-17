
local helpers = require('test.functional.helpers')
local clear, feed = helpers.clear, helpers.feed
local eval, eq, neq = helpers.eval, helpers.eq, helpers.neq
local execute, source = helpers.execute, helpers.source

describe('completion', function()
  before_each(function()
    clear()
  end)

  describe('v:completed_item', function()
    it('is empty dict until completion', function()
      eq({}, eval('v:completed_item'))
    end)
    it('is empty dict if the candidate is not inserted', function()
      feed('ifoo<ESC>o<C-x><C-n><C-e><ESC>')
      eq({}, eval('v:completed_item'))
    end)
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
  describe('completeopt', function()
    before_each(function()
      source([[
      function! TestComplete() abort
        call complete(1, ['foo'])
        return ''
      endfunction
      ]])
    end)

    it('inserts the first candidate if default', function()
      execute('set completeopt+=menuone')
      feed('ifoo<ESC>o<C-x><C-n>bar<ESC>')
      eq('foobar', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR><ESC>')
      eq('foo', eval('getline(3)'))
    end)
    it('selects the first candidate if noinsert', function()
      execute('set completeopt+=menuone,noinsert')
      feed('ifoo<ESC>o<C-x><C-n><C-y><ESC>')
      eq('foo', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR><C-y><ESC>')
      eq('foo', eval('getline(3)'))
    end)
    it('does not insert the first candidate if noselect', function()
      execute('set completeopt+=menuone,noselect')
      feed('ifoo<ESC>o<C-x><C-n>bar<ESC>')
      eq('bar', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>bar<ESC>')
      eq('bar', eval('getline(3)'))
    end)
    it('does not select/insert the first candidate if noselect and noinsert', function()
      execute('set completeopt+=menuone,noselect,noinsert')
      feed('ifoo<ESC>o<C-x><C-n><ESC>')
      eq('', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR><ESC>')
      eq('', eval('getline(3)'))
    end)
  end)
end)
