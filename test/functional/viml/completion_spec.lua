
local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local eval, eq, neq = helpers.eval, helpers.eq, helpers.neq
local execute, source, expect = helpers.execute, helpers.source, helpers.expect

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
    it('does not change modified state if noinsert', function()
      execute('set completeopt+=menuone,noinsert')
      execute('setlocal nomodified')
      feed('i<C-r>=TestComplete()<CR><ESC>')
      eq(0, eval('&l:modified'))
    end)
    it('does not change modified state if noselect', function()
      execute('set completeopt+=menuone,noselect')
      execute('setlocal nomodified')
      feed('i<C-r>=TestComplete()<CR><ESC>')
      eq(0, eval('&l:modified'))
    end)
  end)

  describe("refresh:always", function()
    before_each(function()
      source([[
        function! TestCompletion(findstart, base) abort
          if a:findstart
            let line = getline('.')
            let start = col('.') - 1
            while start > 0 && line[start - 1] =~ '\a'
              let start -= 1
            endwhile
            return start
          else
            let ret = []
            for m in split("January February March April May June July August September October November December")
              if m =~ a:base  " match by regex
                call add(ret, m)
              endif
            endfor
            return {'words':ret, 'refresh':'always'}
          endif
        endfunction

        set completeopt=menuone,noselect
        set completefunc=TestCompletion
      ]])
    end )

    it('completes on each input char', function ()
      feed('i<C-x><C-u>gu<Down><C-y>')
      expect('August')
    end)
    it("repeats correctly after backspace #2674", function ()
      feed('o<C-x><C-u>Ja<BS><C-n><C-n><Esc>')
      feed('.')
      expect([[
        
        June
        June]])
    end)
  end)

  it('disables folding during completion', function ()
    execute("set foldmethod=indent")
    feed('i<Tab>foo<CR><Tab>bar<Esc>ggA<C-x><C-l>')
    eq(-1, eval('foldclosed(1)'))
  end)

  it('popupmenu is not interrupted by events', function ()
    local screen = Screen.new(40, 8)
    screen:attach()
    screen:set_default_attr_ignore({{bold=true, foreground=Screen.colors.Blue}})
    screen:set_default_attr_ids({
      [1] = {background = Screen.colors.LightMagenta},
      [2] = {background = Screen.colors.Grey},
      [3] = {bold = true},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen},
    })

    execute("set complete=.")
    feed('ifoobar fooegg<cr>f<c-p>')
    screen:expect([[
      foobar fooegg                           |
      fooegg^                                  |
      {1:foobar         }                         |
      {2:fooegg         }                         |
      ~                                       |
      ~                                       |
      ~                                       |
      {3:-- }{4:match 1 of 2}                         |
    ]])

    eval('1 + 1')
    -- popupmenu still visible
    screen:expect([[
      foobar fooegg                           |
      fooegg^                                  |
      {1:foobar         }                         |
      {2:fooegg         }                         |
      ~                                       |
      ~                                       |
      ~                                       |
      {3:-- }{4:match 1 of 2}                         |
    ]])

    feed('<c-p>')
    -- Didn't restart completion: old matches still used
    screen:expect([[
      foobar fooegg                           |
      foobar^                                  |
      {2:foobar         }                         |
      {1:fooegg         }                         |
      ~                                       |
      ~                                       |
      ~                                       |
      {3:-- }{4:match 2 of 2}                         |
    ]])
  end)

end)

