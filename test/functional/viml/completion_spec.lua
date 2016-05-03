
local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local eval, eq, neq = helpers.eval, helpers.eq, helpers.neq
local execute, source, expect = helpers.execute, helpers.source, helpers.expect

describe('completion', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(60, 8)
    screen:attach()
    screen:set_default_attr_ignore({{bold=true, foreground=Screen.colors.Blue}})
    screen:set_default_attr_ids({
      [1] = {background = Screen.colors.LightMagenta},
      [2] = {background = Screen.colors.Grey},
      [3] = {bold = true},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen},
      [5] = {foreground = Screen.colors.Red},
      [6] = {background = Screen.colors.Black},
      [7] = {foreground = Screen.colors.White, background = Screen.colors.Red},
    })
  end)

  describe('v:completed_item', function()
    it('is empty dict until completion', function()
      eq({}, eval('v:completed_item'))
    end)
    it('is empty dict if the candidate is not inserted', function()
      feed('ifoo<ESC>o<C-x><C-n>')
      screen:expect([[
        foo                                                         |
        foo^                                                         |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) The only match}           |
      ]])
      feed('<C-e>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
      feed('<ESC>')
      eq({}, eval('v:completed_item'))
    end)
    it('returns expected dict in normal completion', function()
      feed('ifoo<ESC>o<C-x><C-n>')
      eq('foo', eval('getline(2)'))
      eq({word = 'foo', abbr = '', menu = '', info = '', kind = ''},
        eval('v:completed_item'))
    end)
    it('is readonly', function()
      screen:try_resize(80, 8)
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
        \ 'menu': 'baz', 'info': 'foobar', 'kind': 'foobaz'},
        \ {'word': 'word', 'abbr': 'abbr', 'menu': 'menu', 'info': 'info', 'kind': 'kind'}]
      endfunction
      setlocal omnifunc=TestOmni
      ]])
      feed('i<C-x><C-o>')
      eq('foo', eval('getline(1)'))
      screen:expect([[
        foo^                                                         |
        {2:bar  foobaz baz  }                                           |
        {1:abbr kind   menu }                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Omni completion (^O^N^P) }{4:match 1 of 2}                    |
      ]])
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
      feed('ifoo<ESC>o')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
      feed('<C-x>')
      -- the ^X prompt, only test this once
      screen:expect([[
        foo                                                         |
        ^                                                            |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)}                    |
      ]])
      feed('<C-n>')
      screen:expect([[
        foo                                                         |
        foo^                                                         |
        {2:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) The only match}           |
      ]])
      feed('bar<ESC>')
      eq('foobar', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>')
      screen:expect([[
        foo                                                         |
        foobar                                                      |
        foo^                                                         |
        {2:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
      eq('foo', eval('getline(3)'))
    end)
    it('selects the first candidate if noinsert', function()
      execute('set completeopt+=menuone,noinsert')
      feed('ifoo<ESC>o<C-x><C-n>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {2:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) The only match}           |
      ]])
      feed('<C-y>')
      screen:expect([[
        foo                                                         |
        foo^                                                         |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
      feed('<ESC>')
      eq('foo', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>')
      screen:expect([[
        foo                                                         |
        foo                                                         |
        ^                                                            |
        {2:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
      feed('<C-y><ESC>')
      eq('foo', eval('getline(3)'))
    end)
    it('does not insert the first candidate if noselect', function()
      execute('set completeopt+=menuone,noselect')
      feed('ifoo<ESC>o<C-x><C-n>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {1:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) }{5:Back at original}         |
      ]])
      feed('b')
      screen:expect([[
        foo                                                         |
        b^                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) }{5:Back at original}         |
      ]])
      feed('ar<ESC>')
      eq('bar', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>')
      screen:expect([[
        foo                                                         |
        bar                                                         |
        ^                                                            |
        {1:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
      feed('bar<ESC>')
      eq('bar', eval('getline(3)'))
    end)
    it('does not select/insert the first candidate if noselect and noinsert', function()
      execute('set completeopt+=menuone,noselect,noinsert')
      feed('ifoo<ESC>o<C-x><C-n>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {1:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) }{5:Back at original}         |
      ]])
      feed('<ESC>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
                                                                    |
      ]])
      eq('', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>')
      screen:expect([[
        foo                                                         |
                                                                    |
        ^                                                            |
        {1:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
      feed('<ESC>')
      screen:expect([[
        foo                                                         |
                                                                    |
        ^                                                            |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
                                                                    |
      ]])
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
    it('does not ignores the generated candidates if iequal', function()
      execute('set completeopt+=menuone,iequal')
      execute('set ignorecase')
      feed('ifoo<ESC>ofoo<C-x><C-n>')
      screen:expect([[
        foo                                                         |
        foo^                                                         |
        {2:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) The only match}           |
      ]])
    end)
    it('ignores the same candidate if iequal', function()
      execute('set completeopt+=menuone,iequal')
      execute('set ignorecase')
      feed('ifoo<ESC>of<C-x><C-n><C-p>oo')
      screen:expect([[
        foo                                                         |
        foo^                                                         |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) }{5:Back at original}         |
      ]])
    end)
    it('does not ignore the case if iequal', function()
      execute('set completeopt+=menuone,iequal')
      execute('set ignorecase')
      feed('ifoo<ESC>oF<C-x><C-n><C-p>oo')
      screen:expect([[
        foo                                                         |
        Foo^                                                         |
        {1:foo            }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- Keyword Local completion (^N^P) }{5:Back at original}         |
      ]])
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
      feed('i<C-x><C-u>')
      screen:expect([[
        ^                                                            |
        {1:January        }{6: }                                            |
        {1:February       }{6: }                                            |
        {1:March          }{6: }                                            |
        {1:April          }{2: }                                            |
        {1:May            }{2: }                                            |
        {1:June           }{2: }                                            |
        {3:-- User defined completion (^U^N^P) }{5:Back at original}        |
      ]])
      feed('u')
      screen:expect([[
        u^                                                           |
        {1:January        }                                             |
        {1:February       }                                             |
        {1:June           }                                             |
        {1:July           }                                             |
        {1:August         }                                             |
        ~                                                           |
        {3:-- User defined completion (^U^N^P) }{5:Back at original}        |
      ]])
      feed('g')
      screen:expect([[
        ug^                                                          |
        {1:August         }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- User defined completion (^U^N^P) }{5:Back at original}        |
      ]])
      feed('<Down>')
      screen:expect([[
        ug^                                                          |
        {2:August         }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- User defined completion (^U^N^P) The only match}          |
      ]])
      feed('<C-y>')
      screen:expect([[
        August^                                                      |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
      expect('August')
    end)
    it("repeats correctly after backspace #2674", function ()
      feed('o<C-x><C-u>Ja')
      screen:expect([[
                                                                    |
        Ja^                                                          |
        {1:January        }                                             |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- User defined completion (^U^N^P) }{5:Back at original}        |
      ]])
      feed('<BS>')
      screen:expect([[
                                                                    |
        J^                                                           |
        {1:January        }                                             |
        {1:June           }                                             |
        {1:July           }                                             |
        ~                                                           |
        ~                                                           |
        {3:-- User defined completion (^U^N^P) }{5:Back at original}        |
      ]])
      feed('<C-n>')
      screen:expect([[
                                                                    |
        January^                                                     |
        {2:January        }                                             |
        {1:June           }                                             |
        {1:July           }                                             |
        ~                                                           |
        ~                                                           |
        {3:-- User defined completion (^U^N^P) }{4:match 1 of 3}            |
      ]])
      feed('<C-n>')
      screen:expect([[
                                                                    |
        June^                                                        |
        {1:January        }                                             |
        {2:June           }                                             |
        {1:July           }                                             |
        ~                                                           |
        ~                                                           |
        {3:-- User defined completion (^U^N^P) }{4:match 2 of 3}            |
      ]])
      feed('<Esc>')
      screen:expect([[
                                                                    |
        Jun^e                                                        |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
                                                                    |
      ]])
      feed('.')
      screen:expect([[
                                                                    |
        June                                                        |
        Jun^e                                                        |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
                                                                    |
      ]])
      expect([[
        
        June
        June]])
    end)
  end)

  describe('with a lot of items', function()
    before_each(function()
      source([[
      function! TestComplete() abort
        call complete(1, map(range(0,100), "string(v:val)"))
        return ''
      endfunction
      ]])
      execute("set completeopt=menuone,noselect")
    end)

    it("works", function()
      feed('i<C-r>=TestComplete()<CR>')
      screen:expect([[
        ^                                                            |
        {1:0              }{6: }                                            |
        {1:1              }{2: }                                            |
        {1:2              }{2: }                                            |
        {1:3              }{2: }                                            |
        {1:4              }{2: }                                            |
        {1:5              }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('7')
      screen:expect([[
        7^                                                           |
        {1:7              }{6: }                                            |
        {1:70             }{6: }                                            |
        {1:71             }{6: }                                            |
        {1:72             }{2: }                                            |
        {1:73             }{2: }                                            |
        {1:74             }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<c-n>')
      screen:expect([[
        7^                                                           |
        {2:7              }{6: }                                            |
        {1:70             }{6: }                                            |
        {1:71             }{6: }                                            |
        {1:72             }{2: }                                            |
        {1:73             }{2: }                                            |
        {1:74             }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<c-n>')
      screen:expect([[
        70^                                                          |
        {1:7              }{6: }                                            |
        {2:70             }{6: }                                            |
        {1:71             }{6: }                                            |
        {1:72             }{2: }                                            |
        {1:73             }{2: }                                            |
        {1:74             }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
    end)

    it('can be navigated with <PageDown>, <PageUp>', function()
      feed('i<C-r>=TestComplete()<CR>')
      screen:expect([[
        ^                                                            |
        {1:0              }{6: }                                            |
        {1:1              }{2: }                                            |
        {1:2              }{2: }                                            |
        {1:3              }{2: }                                            |
        {1:4              }{2: }                                            |
        {1:5              }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<PageDown>')
      screen:expect([[
        ^                                                            |
        {1:0              }{6: }                                            |
        {1:1              }{2: }                                            |
        {1:2              }{2: }                                            |
        {2:3               }                                            |
        {1:4              }{2: }                                            |
        {1:5              }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<PageDown>')
      screen:expect([[
        ^                                                            |
        {1:5              }{6: }                                            |
        {1:6              }{2: }                                            |
        {2:7               }                                            |
        {1:8              }{2: }                                            |
        {1:9              }{2: }                                            |
        {1:10             }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<Down>')
      screen:expect([[
        ^                                                            |
        {1:5              }{6: }                                            |
        {1:6              }{2: }                                            |
        {1:7              }{2: }                                            |
        {2:8               }                                            |
        {1:9              }{2: }                                            |
        {1:10             }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<PageUp>')
      screen:expect([[
        ^                                                            |
        {1:2              }{6: }                                            |
        {1:3              }{2: }                                            |
        {2:4               }                                            |
        {1:5              }{2: }                                            |
        {1:6              }{2: }                                            |
        {1:7              }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<PageUp>') -- stop on first item
      screen:expect([[
        ^                                                            |
        {2:0              }{6: }                                            |
        {1:1              }{2: }                                            |
        {1:2              }{2: }                                            |
        {1:3              }{2: }                                            |
        {1:4              }{2: }                                            |
        {1:5              }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<PageUp>') -- when on first item, unselect
      screen:expect([[
        ^                                                            |
        {1:0              }{6: }                                            |
        {1:1              }{2: }                                            |
        {1:2              }{2: }                                            |
        {1:3              }{2: }                                            |
        {1:4              }{2: }                                            |
        {1:5              }{2: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<PageUp>') -- when unselected, select last item
      screen:expect([[
        ^                                                            |
        {1:95             }{2: }                                            |
        {1:96             }{2: }                                            |
        {1:97             }{2: }                                            |
        {1:98             }{2: }                                            |
        {1:99             }{2: }                                            |
        {2:100            }{6: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<PageUp>')
      screen:expect([[
        ^                                                            |
        {1:94             }{2: }                                            |
        {1:95             }{2: }                                            |
        {2:96              }                                            |
        {1:97             }{2: }                                            |
        {1:98             }{2: }                                            |
        {1:99             }{6: }                                            |
        {3:-- INSERT --}                                                |
      ]])
      feed('<cr>')
      screen:expect([[
        96^                                                          |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        ~                                                           |
        {3:-- INSERT --}                                                |
      ]])
    end)
  end)

  it('disables folding during completion', function ()
    execute("set foldmethod=indent")
    feed('i<Tab>foo<CR><Tab>bar<Esc>gg')
    screen:expect([[
              ^foo                                                 |
              bar                                                 |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      ~                                                           |
                                                                  |
    ]])
    feed('A<C-x><C-l>')
    screen:expect([[
              foo^                                                 |
              bar                                                 |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      {3:-- Whole line completion (^L^N^P) }{7:Pattern not found}         |
    ]])
    eq(-1, eval('foldclosed(1)'))
  end)

  it('popupmenu is not interrupted by events', function ()
    execute("set complete=.")

    feed('ifoobar fooegg<cr>f<c-p>')
    screen:expect([[
      foobar fooegg                                               |
      fooegg^                                                      |
      {1:foobar         }                                             |
      {2:fooegg         }                                             |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      {3:-- Keyword completion (^N^P) }{4:match 1 of 2}                   |
    ]])

    eval('1 + 1')
    -- popupmenu still visible
    screen:expect([[
      foobar fooegg                                               |
      fooegg^                                                      |
      {1:foobar         }                                             |
      {2:fooegg         }                                             |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      {3:-- Keyword completion (^N^P) }{4:match 1 of 2}                   |
    ]])

    feed('<c-p>')
    -- Didn't restart completion: old matches still used
    screen:expect([[
      foobar fooegg                                               |
      foobar^                                                      |
      {2:foobar         }                                             |
      {1:fooegg         }                                             |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      {3:-- Keyword completion (^N^P) }{4:match 2 of 2}                   |
    ]])
  end)

end)

