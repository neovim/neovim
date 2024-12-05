local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local assert_alive = n.assert_alive
local clear, feed = n.clear, n.feed
local eval, eq, neq, ok = n.eval, t.eq, t.neq, t.ok
local feed_command, source, expect = n.feed_command, n.source, n.expect
local fn = n.fn
local command = n.command
local api = n.api
local poke_eventloop = n.poke_eventloop

describe('completion', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(60, 8)
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Gray0, background = Screen.colors.Yellow },
      [101] = { background = Screen.colors.Gray0 },
    }
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
        {1:~                                                           }|*5
        {5:-- Keyword Local completion (^N^P) The only match}           |
      ]])
      feed('<C-e>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {1:~                                                           }|*5
        {5:-- INSERT --}                                                |
      ]])
      feed('<ESC>')
      eq({}, eval('v:completed_item'))
    end)
    it('returns expected dict in normal completion', function()
      feed('ifoo<ESC>o<C-x><C-n>')
      eq('foo', eval('getline(2)'))
      eq(
        { word = 'foo', abbr = '', menu = '', info = '', kind = '', user_data = '' },
        eval('v:completed_item')
      )
    end)
    it('is readonly', function()
      screen:try_resize(80, 8)
      feed('ifoo<ESC>o<C-x><C-n><ESC>')
      feed_command('let v:completed_item.word = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      feed_command('let v:errmsg = ""')

      feed_command('let v:completed_item.abbr = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      feed_command('let v:errmsg = ""')

      feed_command('let v:completed_item.menu = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      feed_command('let v:errmsg = ""')

      feed_command('let v:completed_item.info = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      feed_command('let v:errmsg = ""')

      feed_command('let v:completed_item.kind = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      feed_command('let v:errmsg = ""')

      feed_command('let v:completed_item.user_data = "bar"')
      neq(nil, string.find(eval('v:errmsg'), '^E46: '))
      feed_command('let v:errmsg = ""')
    end)
    it('returns expected dict in omni completion', function()
      source([[
      function! TestOmni(findstart, base) abort
        return a:findstart ? 0 : [{'word': 'foo', 'abbr': 'bar',
        \ 'menu': 'baz', 'info': 'foobar', 'kind': 'foobaz'},
        \ {'word': 'word', 'abbr': 'abbr', 'menu': 'menu',
        \  'info': 'info', 'kind': 'kind'}]
      endfunction
      setlocal omnifunc=TestOmni
      ]])
      feed('i<C-x><C-o>')
      eq('foo', eval('getline(1)'))
      screen:expect([[
        foo^                                                         |
        {12:bar  foobaz baz  }{1:                                           }|
        {4:abbr kind   menu }{1:                                           }|
        {1:~                                                           }|*4
        {5:-- Omni completion (^O^N^P) }{6:match 1 of 2}                    |
      ]])
      eq({
        word = 'foo',
        abbr = 'bar',
        menu = 'baz',
        info = 'foobar',
        kind = 'foobaz',
        user_data = '',
      }, eval('v:completed_item'))
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
      feed_command('set completeopt+=menuone')
      feed('ifoo<ESC>o')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {1:~                                                           }|*5
        {5:-- INSERT --}                                                |
      ]])
      feed('<C-x>')
      -- the ^X prompt, only test this once
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {1:~                                                           }|*5
        {5:-- ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)}                    |
      ]])
      feed('<C-n>')
      screen:expect([[
        foo                                                         |
        foo^                                                         |
        {12:foo            }{1:                                             }|
        {1:~                                                           }|*4
        {5:-- Keyword Local completion (^N^P) The only match}           |
      ]])
      feed('bar<ESC>')
      eq('foobar', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>')
      screen:expect([[
        foo                                                         |
        foobar                                                      |
        foo^                                                         |
        {12:foo            }{1:                                             }|
        {1:~                                                           }|*3
        {5:-- INSERT --}                                                |
      ]])
      eq('foo', eval('getline(3)'))
    end)
    it('selects the first candidate if noinsert', function()
      feed_command('set completeopt+=menuone,noinsert')
      feed('ifoo<ESC>o<C-x><C-n>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {12:foo            }{1:                                             }|
        {1:~                                                           }|*4
        {5:-- Keyword Local completion (^N^P) The only match}           |
      ]])
      feed('<C-y>')
      screen:expect([[
        foo                                                         |
        foo^                                                         |
        {1:~                                                           }|*5
        {5:-- INSERT --}                                                |
      ]])
      feed('<ESC>')
      eq('foo', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>')
      screen:expect([[
        foo                                                         |*2
        ^                                                            |
        {12:foo            }{1:                                             }|
        {1:~                                                           }|*3
        {5:-- INSERT --}                                                |
      ]])
      feed('<C-y><ESC>')
      eq('foo', eval('getline(3)'))
    end)
    it('does not insert the first candidate if noselect', function()
      feed_command('set completeopt+=menuone,noselect')
      feed('ifoo<ESC>o<C-x><C-n>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {4:foo            }{1:                                             }|
        {1:~                                                           }|*4
        {5:-- Keyword Local completion (^N^P) }{19:Back at original}         |
      ]])
      feed('b')
      screen:expect([[
        foo                                                         |
        b^                                                           |
        {1:~                                                           }|*5
        {5:-- Keyword Local completion (^N^P) }{19:Back at original}         |
      ]])
      feed('ar<ESC>')
      eq('bar', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>')
      screen:expect([[
        foo                                                         |
        bar                                                         |
        ^                                                            |
        {4:foo            }{1:                                             }|
        {1:~                                                           }|*3
        {5:-- INSERT --}                                                |
      ]])
      feed('bar<ESC>')
      eq('bar', eval('getline(3)'))
    end)
    it('does not select/insert the first candidate if noselect and noinsert', function()
      feed_command('set completeopt+=menuone,noselect,noinsert')
      feed('ifoo<ESC>o<C-x><C-n>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {4:foo            }{1:                                             }|
        {1:~                                                           }|*4
        {5:-- Keyword Local completion (^N^P) }{19:Back at original}         |
      ]])
      feed('<ESC>')
      screen:expect([[
        foo                                                         |
        ^                                                            |
        {1:~                                                           }|*5
                                                                    |
      ]])
      eq('', eval('getline(2)'))
      feed('o<C-r>=TestComplete()<CR>')
      screen:expect([[
        foo                                                         |
                                                                    |
        ^                                                            |
        {4:foo            }{1:                                             }|
        {1:~                                                           }|*3
        {5:-- INSERT --}                                                |
      ]])
      feed('<ESC>')
      screen:expect([[
        foo                                                         |
                                                                    |
        ^                                                            |
        {1:~                                                           }|*4
                                                                    |
      ]])
      eq('', eval('getline(3)'))
    end)
    it('does not change modified state if noinsert', function()
      feed_command('set completeopt+=menuone,noinsert')
      feed_command('setlocal nomodified')
      feed('i<C-r>=TestComplete()<CR><ESC>')
      eq(0, eval('&l:modified'))
    end)
    it('does not change modified state if noselect', function()
      feed_command('set completeopt+=menuone,noselect')
      feed_command('setlocal nomodified')
      feed('i<C-r>=TestComplete()<CR><ESC>')
      eq(0, eval('&l:modified'))
    end)
  end)

  describe('completeopt+=noinsert does not add blank undo items', function()
    before_each(function()
      source([[
      function! TestComplete() abort
        call complete(1, ['foo', 'bar'])
        return ''
      endfunction
      ]])
      feed_command('set completeopt+=noselect,noinsert')
      feed_command('inoremap <right> <c-r>=TestComplete()<cr>')
    end)

    local tests = {
      ['<up>, <down>, <cr>'] = { '<down><cr>', '<up><cr>' },
      ['<c-n>, <c-p>, <c-y>'] = { '<c-n><c-y>', '<c-p><c-y>' },
    }

    for name, seq in pairs(tests) do
      it('using ' .. name, function()
        feed('iaaa<esc>')
        feed('A<right>' .. seq[1] .. '<esc>')
        feed('A<right><esc>A<right><esc>')
        feed('A<cr>bbb<esc>')
        feed('A<right>' .. seq[2] .. '<esc>')
        feed('A<right><esc>A<right><esc>')
        feed('A<cr>ccc<esc>')
        feed('A<right>' .. seq[1] .. '<esc>')
        feed('A<right><esc>A<right><esc>')

        local expected = {
          { 'foo', 'bar', 'foo' },
          { 'foo', 'bar', 'ccc' },
          { 'foo', 'bar' },
          { 'foo', 'bbb' },
          { 'foo' },
          { 'aaa' },
          { '' },
        }

        for i = 1, #expected do
          if i > 1 then
            feed('u')
          end
          eq(expected[i], eval('getline(1, "$")'))
        end

        for i = #expected, 1, -1 do
          if i < #expected then
            feed('<c-r>')
          end
          eq(expected[i], eval('getline(1, "$")'))
        end
      end)
    end
  end)

  describe('with refresh:always and noselect', function()
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
    end)

    it('completes on each input char', function()
      feed('i<C-x><C-u>')
      screen:expect([[
        ^                                                            |
        {4:January        }{101: }{1:                                            }|
        {4:February       }{101: }{1:                                            }|
        {4:March          }{101: }{1:                                            }|
        {4:April          }{12: }{1:                                            }|
        {4:May            }{12: }{1:                                            }|
        {4:June           }{12: }{1:                                            }|
        {5:-- User defined completion (^U^N^P) }{19:Back at original}        |
      ]])
      feed('u')
      screen:expect([[
        u^                                                           |
        {4:January        }{1:                                             }|
        {4:February       }{1:                                             }|
        {4:June           }{1:                                             }|
        {4:July           }{1:                                             }|
        {4:August         }{1:                                             }|
        {1:~                                                           }|
        {5:-- User defined completion (^U^N^P) }{19:Back at original}        |
      ]])
      feed('g')
      screen:expect([[
        ug^                                                          |
        {4:August         }{1:                                             }|
        {1:~                                                           }|*5
        {5:-- User defined completion (^U^N^P) }{19:Back at original}        |
      ]])
      feed('<Down>')
      screen:expect([[
        ug^                                                          |
        {12:August         }{1:                                             }|
        {1:~                                                           }|*5
        {5:-- User defined completion (^U^N^P) The only match}          |
      ]])
      feed('<C-y>')
      screen:expect([[
        August^                                                      |
        {1:~                                                           }|*6
        {5:-- INSERT --}                                                |
      ]])
      expect('August')
    end)

    it('repeats correctly after backspace #2674', function()
      feed('o<C-x><C-u>Ja')
      screen:expect([[
                                                                    |
        Ja^                                                          |
        {4:January        }{1:                                             }|
        {1:~                                                           }|*4
        {5:-- User defined completion (^U^N^P) }{19:Back at original}        |
      ]])
      feed('<BS>')
      screen:expect([[
                                                                    |
        J^                                                           |
        {4:January        }{1:                                             }|
        {4:June           }{1:                                             }|
        {4:July           }{1:                                             }|
        {1:~                                                           }|*2
        {5:-- User defined completion (^U^N^P) }{19:Back at original}        |
      ]])
      feed('<C-n>')
      screen:expect([[
                                                                    |
        January^                                                     |
        {12:January        }{1:                                             }|
        {4:June           }{1:                                             }|
        {4:July           }{1:                                             }|
        {1:~                                                           }|*2
        {5:-- User defined completion (^U^N^P) }{6:match 1 of 3}            |
      ]])
      feed('<C-n>')
      screen:expect([[
                                                                    |
        June^                                                        |
        {4:January        }{1:                                             }|
        {12:June           }{1:                                             }|
        {4:July           }{1:                                             }|
        {1:~                                                           }|*2
        {5:-- User defined completion (^U^N^P) }{6:match 2 of 3}            |
      ]])
      feed('<Esc>')
      screen:expect([[
                                                                    |
        Jun^e                                                        |
        {1:~                                                           }|*5
                                                                    |
      ]])
      feed('.')
      screen:expect([[
                                                                    |
        June                                                        |
        Jun^e                                                        |
        {1:~                                                           }|*4
                                                                    |
      ]])
      expect([[

        June
        June]])
    end)

    it('Enter does not select original text', function()
      feed('iJ<C-x><C-u>')
      poke_eventloop()
      feed('u')
      poke_eventloop()
      feed('<CR>')
      expect([[
        Ju
        ]])
      feed('J<C-x><C-u>')
      poke_eventloop()
      feed('<CR>')
      expect([[
        Ju
        J
        ]])
    end)
  end)

  describe('with noselect but not refresh:always', function()
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
            return {'words':ret}
          endif
        endfunction

        set completeopt=menuone,noselect
        set completefunc=TestCompletion
      ]])
    end)

    it('Enter selects original text after adding leader', function()
      feed('iJ<C-x><C-u>')
      poke_eventloop()
      feed('u')
      poke_eventloop()
      feed('<CR>')
      expect('Ju')
      feed('<Esc>')
      poke_eventloop()
      -- The behavior should be the same when completion has been interrupted,
      -- which can happen interactively if the completion function is slow.
      feed('SJ<C-x><C-u>u<CR>')
      expect('Ju')
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
      feed_command('set completeopt=menuone,noselect')
    end)

    it('works', function()
      feed('i<C-r>=TestComplete()<CR>')
      screen:expect([[
        ^                                                            |
        {4:0              }{101: }{1:                                            }|
        {4:1              }{12: }{1:                                            }|
        {4:2              }{12: }{1:                                            }|
        {4:3              }{12: }{1:                                            }|
        {4:4              }{12: }{1:                                            }|
        {4:5              }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('7')
      screen:expect([[
        7^                                                           |
        {4:7              }{101: }{1:                                            }|
        {4:70             }{101: }{1:                                            }|
        {4:71             }{101: }{1:                                            }|
        {4:72             }{12: }{1:                                            }|
        {4:73             }{12: }{1:                                            }|
        {4:74             }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<c-n>')
      screen:expect([[
        7^                                                           |
        {12:7              }{101: }{1:                                            }|
        {4:70             }{101: }{1:                                            }|
        {4:71             }{101: }{1:                                            }|
        {4:72             }{12: }{1:                                            }|
        {4:73             }{12: }{1:                                            }|
        {4:74             }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<c-n>')
      screen:expect([[
        70^                                                          |
        {4:7              }{101: }{1:                                            }|
        {12:70             }{101: }{1:                                            }|
        {4:71             }{101: }{1:                                            }|
        {4:72             }{12: }{1:                                            }|
        {4:73             }{12: }{1:                                            }|
        {4:74             }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
    end)

    it('can be navigated with <PageDown>, <PageUp>', function()
      feed('i<C-r>=TestComplete()<CR>')
      screen:expect([[
        ^                                                            |
        {4:0              }{101: }{1:                                            }|
        {4:1              }{12: }{1:                                            }|
        {4:2              }{12: }{1:                                            }|
        {4:3              }{12: }{1:                                            }|
        {4:4              }{12: }{1:                                            }|
        {4:5              }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<PageDown>')
      screen:expect([[
        ^                                                            |
        {4:0              }{101: }{1:                                            }|
        {4:1              }{12: }{1:                                            }|
        {4:2              }{12: }{1:                                            }|
        {12:3               }{1:                                            }|
        {4:4              }{12: }{1:                                            }|
        {4:5              }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<PageDown>')
      screen:expect([[
        ^                                                            |
        {4:5              }{101: }{1:                                            }|
        {4:6              }{12: }{1:                                            }|
        {12:7               }{1:                                            }|
        {4:8              }{12: }{1:                                            }|
        {4:9              }{12: }{1:                                            }|
        {4:10             }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<Down>')
      screen:expect([[
        ^                                                            |
        {4:5              }{101: }{1:                                            }|
        {4:6              }{12: }{1:                                            }|
        {4:7              }{12: }{1:                                            }|
        {12:8               }{1:                                            }|
        {4:9              }{12: }{1:                                            }|
        {4:10             }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<PageUp>')
      screen:expect([[
        ^                                                            |
        {4:2              }{101: }{1:                                            }|
        {4:3              }{12: }{1:                                            }|
        {12:4               }{1:                                            }|
        {4:5              }{12: }{1:                                            }|
        {4:6              }{12: }{1:                                            }|
        {4:7              }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<PageUp>') -- stop on first item
      screen:expect([[
        ^                                                            |
        {12:0              }{101: }{1:                                            }|
        {4:1              }{12: }{1:                                            }|
        {4:2              }{12: }{1:                                            }|
        {4:3              }{12: }{1:                                            }|
        {4:4              }{12: }{1:                                            }|
        {4:5              }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<PageUp>') -- when on first item, unselect
      screen:expect([[
        ^                                                            |
        {4:0              }{101: }{1:                                            }|
        {4:1              }{12: }{1:                                            }|
        {4:2              }{12: }{1:                                            }|
        {4:3              }{12: }{1:                                            }|
        {4:4              }{12: }{1:                                            }|
        {4:5              }{12: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<PageUp>') -- when unselected, select last item
      screen:expect([[
        ^                                                            |
        {4:95             }{12: }{1:                                            }|
        {4:96             }{12: }{1:                                            }|
        {4:97             }{12: }{1:                                            }|
        {4:98             }{12: }{1:                                            }|
        {4:99             }{12: }{1:                                            }|
        {12:100            }{101: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<PageUp>')
      screen:expect([[
        ^                                                            |
        {4:94             }{12: }{1:                                            }|
        {4:95             }{12: }{1:                                            }|
        {12:96              }{1:                                            }|
        {4:97             }{12: }{1:                                            }|
        {4:98             }{12: }{1:                                            }|
        {4:99             }{101: }{1:                                            }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<cr>')
      screen:expect([[
        96^                                                          |
        {1:~                                                           }|*6
        {5:-- INSERT --}                                                |
      ]])
    end)
  end)

  it('does not indent until an item is selected #8345', function()
    -- Indents on "ind", unindents on "unind".
    source([[
      function! TestIndent()
        let line = getline(v:lnum)
        if (line =~ '^\s*ind')
          return indent(v:lnum-1) + shiftwidth()
        elseif (line =~ '^\s*unind')
          return indent(v:lnum-1) - shiftwidth()
        else
          return indent(v:lnum-1)
        endif
      endfunction
      set indentexpr=TestIndent()
      set indentkeys=o,O,!^F,=ind,=unind
      set completeopt+=menuone
    ]])

    -- Give some words to complete.
    feed('iinc uninc indent unindent<CR>')

    -- Does not indent when "ind" is typed.
    feed('in<C-X><C-N>')
    -- Completion list is generated incorrectly if we send everything at once
    -- via nvim_input().  So poke_eventloop() before sending <BS>. #8480
    poke_eventloop()
    feed('<BS>d')

    screen:expect([[
      inc uninc indent unindent                                   |
      ind^                                                         |
      {12:indent         }{1:                                             }|
      {1:~                                                           }|*4
      {5:-- Keyword Local completion (^N^P) }{6:match 1 of 2}             |
    ]])

    -- Indents when the item is selected
    feed('<C-Y>')
    screen:expect([[
      inc uninc indent unindent                                   |
              indent^                                              |
      {1:~                                                           }|*5
      {5:-- INSERT --}                                                |
    ]])
    -- Indents when completion is exited using ESC.
    feed('<CR>in<C-N><BS>d<Esc>')
    screen:expect([[
      inc uninc indent unindent                                   |
              indent                                              |
                      in^d                                         |
      {1:~                                                           }|*4
                                                                  |
    ]])
    -- Works for unindenting too.
    feed('ounin<C-X><C-N>')
    poke_eventloop()
    feed('<BS>d')
    screen:expect([[
      inc uninc indent unindent                                   |
              indent                                              |
                      ind                                         |
                      unind^                                       |
      {1:~              }{12: unindent       }{1:                             }|
      {1:~                                                           }|*2
      {5:-- Keyword Local completion (^N^P) }{6:match 1 of 2}             |
    ]])
    -- Works when going back and forth.
    feed('<BS>c')
    screen:expect([[
      inc uninc indent unindent                                   |
              indent                                              |
                      ind                                         |
                      uninc^                                       |
      {1:~              }{12: uninc          }{1:                             }|
      {1:~                                                           }|*2
      {5:-- Keyword Local completion (^N^P) }{6:match 1 of 2}             |
    ]])
    feed('<BS>d')
    screen:expect([[
      inc uninc indent unindent                                   |
              indent                                              |
                      ind                                         |
                      unind^                                       |
      {1:~              }{12: unindent       }{1:                             }|
      {1:~                                                           }|*2
      {5:-- Keyword Local completion (^N^P) }{6:match 1 of 2}             |
    ]])
    feed('<C-N><C-N><C-Y><Esc>')
    screen:expect([[
      inc uninc indent unindent                                   |
              indent                                              |
                      ind                                         |
              uninden^t                                            |
      {1:~                                                           }|*3
                                                                  |
    ]])
  end)

  it('disables folding during completion', function()
    feed_command('set foldmethod=indent')
    feed('i<Tab>foo<CR><Tab>bar<Esc>gg')
    screen:expect([[
              ^foo                                                 |
              bar                                                 |
      {1:~                                                           }|*5
                                                                  |
    ]])
    feed('A<C-x><C-l>')
    screen:expect([[
              foo^                                                 |
              bar                                                 |
      {1:~                                                           }|*5
      {5:-- Whole line completion (^L^N^P) }{9:Pattern not found}         |
    ]])
    eq(-1, eval('foldclosed(1)'))
  end)

  it('popupmenu is not interrupted by events', function()
    feed_command('set complete=.')

    feed('ifoobar fooegg<cr>f<c-p>')
    screen:expect([[
      foobar fooegg                                               |
      fooegg^                                                      |
      {4:foobar         }{1:                                             }|
      {12:fooegg         }{1:                                             }|
      {1:~                                                           }|*3
      {5:-- Keyword completion (^N^P) }{6:match 1 of 2}                   |
    ]])

    assert_alive()
    -- popupmenu still visible
    screen:expect {
      grid = [[
      foobar fooegg                                               |
      fooegg^                                                      |
      {4:foobar         }{1:                                             }|
      {12:fooegg         }{1:                                             }|
      {1:~                                                           }|*3
      {5:-- Keyword completion (^N^P) }{6:match 1 of 2}                   |
    ]],
      unchanged = true,
    }

    feed('<c-p>')
    -- Didn't restart completion: old matches still used
    screen:expect([[
      foobar fooegg                                               |
      foobar^                                                      |
      {12:foobar         }{1:                                             }|
      {4:fooegg         }{1:                                             }|
      {1:~                                                           }|*3
      {5:-- Keyword completion (^N^P) }{6:match 2 of 2}                   |
    ]])
  end)

  describe('lua completion', function()
    it('expands when there is only one match', function()
      feed(':lua CURRENT_TESTING_VAR = 1<CR>')
      feed(':lua CURRENT_TESTING_<TAB>')
      screen:expect {
        grid = [[
                                                                    |
        {1:~                                                           }|*6
        :lua CURRENT_TESTING_VAR^                                    |
      ]],
      }
    end)

    it('expands when there is only one match', function()
      feed(':lua CURRENT_TESTING_FOO = 1<CR>')
      feed(':lua CURRENT_TESTING_BAR = 1<CR>')
      feed(':lua CURRENT_TESTING_<TAB>')
      screen:expect {
        grid = [[
                                                                    |
        {1:~                                                           }|*5
        {100:CURRENT_TESTING_BAR}{3:  CURRENT_TESTING_FOO                    }|
        :lua CURRENT_TESTING_BAR^                                    |
      ]],
        unchanged = true,
      }
    end)

    it('prefix is not included in completion for cmdline mode', function()
      feed(':lua math.a<Tab>')
      screen:expect([[
                                                                    |
        {1:~                                                           }|*5
        {100:abs}{3:  acos  asin  atan  atan2                                }|
        :lua math.abs^                                               |
      ]])
      feed('<Tab>')
      screen:expect([[
                                                                    |
        {1:~                                                           }|*5
        {3:abs  }{100:acos}{3:  asin  atan  atan2                                }|
        :lua math.acos^                                              |
      ]])
    end)

    it('prefix is not included in completion for i_CTRL-X_CTRL-V #19623', function()
      feed('ilua math.a<C-X><C-V>')
      screen:expect([[
        lua math.abs^                                                |
        {1:~       }{12: abs            }{1:                                    }|
        {1:~       }{4: acos           }{1:                                    }|
        {1:~       }{4: asin           }{1:                                    }|
        {1:~       }{4: atan           }{1:                                    }|
        {1:~       }{4: atan2          }{1:                                    }|
        {1:~                                                           }|
        {5:-- Command-line completion (^V^N^P) }{6:match 1 of 5}            |
      ]])
      feed('<C-V>')
      screen:expect([[
        lua math.acos^                                               |
        {1:~       }{4: abs            }{1:                                    }|
        {1:~       }{12: acos           }{1:                                    }|
        {1:~       }{4: asin           }{1:                                    }|
        {1:~       }{4: atan           }{1:                                    }|
        {1:~       }{4: atan2          }{1:                                    }|
        {1:~                                                           }|
        {5:-- Command-line completion (^V^N^P) }{6:match 2 of 5}            |
      ]])
    end)

    it('works when cursor is in the middle of cmdline #29586', function()
      feed(':lua math.a(); 1<Left><Left><Left><Left><Left><Tab>')
      screen:expect([[
                                                                    |
        {1:~                                                           }|*5
        {100:abs}{3:  acos  asin  atan  atan2                                }|
        :lua math.abs^(); 1                                          |
      ]])
    end)

    it('provides completion from `getcompletion()`', function()
      eq({ 'vim' }, fn.getcompletion('vi', 'lua'))
      eq({ 'api' }, fn.getcompletion('vim.ap', 'lua'))
      eq({ 'tbl_filter' }, fn.getcompletion('vim.tbl_fil', 'lua'))
      eq({ 'vim' }, fn.getcompletion('print(vi', 'lua'))
      eq({ 'abs', 'acos', 'asin', 'atan', 'atan2' }, fn.getcompletion('math.a', 'lua'))
      eq({ 'abs', 'acos', 'asin', 'atan', 'atan2' }, fn.getcompletion('lua math.a', 'cmdline'))
      -- fuzzy completion is not supported, so the result should be the same
      command('set wildoptions+=fuzzy')
      eq({ 'vim' }, fn.getcompletion('vi', 'lua'))
    end)
  end)

  it('cmdline completion supports various string options', function()
    eq('auto', fn.getcompletion('set foldcolumn=', 'cmdline')[2])
    eq({ 'nosplit', 'split' }, fn.getcompletion('set inccommand=', 'cmdline'))
    eq({ 'ver:3,hor:6', 'hor:', 'ver:' }, fn.getcompletion('set mousescroll=', 'cmdline'))
    eq('BS', fn.getcompletion('set termpastefilter=', 'cmdline')[2])
    eq('SpecialKey', fn.getcompletion('set winhighlight=', 'cmdline')[1])
    eq('SpecialKey', fn.getcompletion('set winhighlight=NonText:', 'cmdline')[1])
  end)

  it('cmdline completion for -complete does not contain spaces', function()
    for _, str in ipairs(fn.getcompletion('command -complete=', 'cmdline')) do
      ok(not str:find(' '), 'string without spaces', str)
    end
  end)

  describe('from the commandline window', function()
    it('is cleared after CTRL-C', function()
      feed('q:')
      feed('ifoo faa fee f')
      screen:expect([[
                                                                    |
        {2:[No Name]                                                   }|
        {1::}foo faa fee f^                                              |
        {1:~                                                           }|*3
        {3:[Command Line]                                              }|
        {5:-- INSERT --}                                                |
      ]])
      feed('<c-x><c-n>')
      screen:expect([[
                                                                    |
        {2:[No Name]                                                   }|
        {1::}foo faa fee foo^                                            |
        {1:~           }{12: foo            }{1:                                }|
        {1:~           }{4: faa            }{1:                                }|
        {1:~           }{4: fee            }{1:                                }|
        {3:[Command Line]                                              }|
        {5:-- Keyword Local completion (^N^P) }{6:match 1 of 3}             |
      ]])
      feed('<c-c>')
      screen:expect([[
                                                                    |
        {2:[No Name]                                                   }|
        {1::}foo faa fee foo                                            |
        {1:~                                                           }|*3
        {3:[Command Line]                                              }|
        :foo faa fee foo^                                            |
      ]])
    end)
  end)

  describe('with numeric items', function()
    before_each(function()
      source([[
        function! TestComplete() abort
          call complete(1, g:_complist)
          return ''
        endfunction
      ]])
      api.nvim_set_option_value('completeopt', 'menuone,noselect', {})
      api.nvim_set_var('_complist', {
        {
          word = 0,
          abbr = 1,
          menu = 2,
          kind = 3,
          info = 4,
          icase = 5,
          dup = 6,
          empty = 7,
        },
      })
    end)

    it('shows correct variant as word', function()
      feed('i<C-r>=TestComplete()<CR>')
      screen:expect([[
        ^                                                            |
        {4:1 3 2          }{1:                                             }|
        {1:~                                                           }|*5
        {5:-- INSERT --}                                                |
      ]])
    end)
  end)

  it("'ignorecase' 'infercase' CTRL-X CTRL-N #6451", function()
    feed_command('set ignorecase infercase')
    feed_command('edit runtime/doc/credits.txt')
    feed('oX<C-X><C-N>')
    screen:expect {
      grid = [[
      *credits.txt*          Nvim                                 |
      Xvi^                                                         |
      {12:Xvi            }{101: }                                            |
      {4:Xvim           }{101: }                                            |
      {4:X11            }{12: }     NVIM REFERENCE MANUAL                  |
      {4:Xnull          }{12: }                                            |
      {4:Xoxomoon       }{12: }                                            |
      {5:-- Keyword Local completion (^N^P) }{6:match 1 of 10}            |
    ]],
    }
  end)

  it('CompleteChanged autocommand', function()
    api.nvim_buf_set_lines(0, 0, 1, false, { 'foo', 'bar', 'foobar', '' })
    source([[
      set complete=. completeopt=noinsert,noselect,menuone
      function! OnPumChange()
        let g:event = copy(v:event)
        let g:item = get(v:event, 'completed_item', {})
        let g:word = get(g:item, 'word', v:null)
      endfunction
      autocmd! CompleteChanged * :call OnPumChange()
      call cursor(4, 1)
    ]])

    -- v:event.size should be set with ext_popupmenu #20646
    screen:set_option('ext_popupmenu', true)
    feed('Sf<C-N>')
    screen:expect({
      grid = [[
      foo                                                         |
      bar                                                         |
      foobar                                                      |
      f^                                                           |
      {1:~                                                           }|*3
      {5:-- Keyword completion (^N^P) }{19:Back at original}               |
    ]],
      popupmenu = {
        anchor = { 1, 3, 0 },
        items = { { 'foo', '', '', '' }, { 'foobar', '', '', '' } },
        pos = -1,
      },
    })
    eq(
      { completed_item = {}, width = 0, height = 2, size = 2, col = 0, row = 4, scrollbar = false },
      eval('g:event')
    )
    feed('oob')
    screen:expect({
      grid = [[
      foo                                                         |
      bar                                                         |
      foobar                                                      |
      foob^                                                        |
      {1:~                                                           }|*3
      {5:-- Keyword completion (^N^P) }{19:Back at original}               |
    ]],
      popupmenu = {
        anchor = { 1, 3, 0 },
        items = { { 'foobar', '', '', '' } },
        pos = -1,
      },
    })
    eq(
      { completed_item = {}, width = 0, height = 1, size = 1, col = 0, row = 4, scrollbar = false },
      eval('g:event')
    )
    feed('<Esc>')
    screen:set_option('ext_popupmenu', false)

    feed('Sf<C-N>')
    screen:expect([[
      foo                                                         |
      bar                                                         |
      foobar                                                      |
      f^                                                           |
      {4:foo            }{1:                                             }|
      {4:foobar         }{1:                                             }|
      {1:~                                                           }|
      {5:-- Keyword completion (^N^P) }{19:Back at original}               |
    ]])
    eq(
      { completed_item = {}, width = 15, height = 2, size = 2, col = 0, row = 4, scrollbar = false },
      eval('g:event')
    )
    feed('<C-N>')
    screen:expect([[
      foo                                                         |
      bar                                                         |
      foobar                                                      |
      foo^                                                         |
      {12:foo            }{1:                                             }|
      {4:foobar         }{1:                                             }|
      {1:~                                                           }|
      {5:-- Keyword completion (^N^P) }{6:match 1 of 2}                   |
    ]])
    eq('foo', eval('g:word'))
    feed('<C-N>')
    screen:expect([[
      foo                                                         |
      bar                                                         |
      foobar                                                      |
      foobar^                                                      |
      {4:foo            }{1:                                             }|
      {12:foobar         }{1:                                             }|
      {1:~                                                           }|
      {5:-- Keyword completion (^N^P) }{6:match 2 of 2}                   |
    ]])
    eq('foobar', eval('g:word'))
    feed('<up>')
    screen:expect([[
      foo                                                         |
      bar                                                         |
      foobar                                                      |
      foobar^                                                      |
      {12:foo            }{1:                                             }|
      {4:foobar         }{1:                                             }|
      {1:~                                                           }|
      {5:-- Keyword completion (^N^P) }{6:match 1 of 2}                   |
    ]])
    eq('foo', eval('g:word'))
    feed('<down>')
    screen:expect([[
      foo                                                         |
      bar                                                         |
      foobar                                                      |
      foobar^                                                      |
      {4:foo            }{1:                                             }|
      {12:foobar         }{1:                                             }|
      {1:~                                                           }|
      {5:-- Keyword completion (^N^P) }{6:match 2 of 2}                   |
    ]])
    eq('foobar', eval('g:word'))
    feed('<esc>')
  end)

  it('is stopped by :stopinsert from timer #12976', function()
    screen:try_resize(32, 14)
    command([[call setline(1, ['hello', 'hullo', 'heeee', ''])]])
    feed('Gah<c-x><c-n>')
    screen:expect([[
      hello                           |
      hullo                           |
      heeee                           |
      hello^                           |
      {12:hello          }{1:                 }|
      {4:hullo          }{1:                 }|
      {4:heeee          }{1:                 }|
      {1:~                               }|*6
      {5:-- }{6:match 1 of 3}                 |
    ]])
    command([[call timer_start(100, { -> execute('stopinsert') })]])
    vim.uv.sleep(200)
    feed('k') -- cursor should move up in Normal mode
    screen:expect([[
      hello                           |
      hullo                           |
      heee^e                           |
      hello                           |
      {1:~                               }|*9
                                      |
    ]])
  end)

  -- oldtest: Test_complete_changed_complete_info()
  it('no crash calling complete_info() in CompleteChanged', function()
    source([[
      set completeopt=menuone
      autocmd CompleteChanged * call complete_info(['items'])
      call feedkeys("iii\<cr>\<c-p>")
    ]])
    screen:expect([[
      ii                                                          |
      ii^                                                          |
      {12:ii             }{1:                                             }|
      {1:~                                                           }|*4
      {5:-- Keyword completion (^N^P) The only match}                 |
    ]])
    assert_alive()
  end)

  it('no crash if text changed by first call to complete function #17489', function()
    source([[
      func Complete(findstart, base) abort
        if a:findstart
          let col = col('.')
          call complete_add('#')
          return col - 1
        else
          return []
        endif
      endfunc

      set completeopt=longest
      set completefunc=Complete
    ]])
    feed('ifoo#<C-X><C-U>')
    assert_alive()
  end)

  it('no crash using i_CTRL-X_CTRL-V to complete non-existent colorscheme', function()
    feed('icolorscheme NOSUCHCOLORSCHEME<C-X><C-V>')
    expect('colorscheme NOSUCHCOLORSCHEME')
    assert_alive()
  end)

  it('complete with f flag #25598', function()
    screen:try_resize(20, 9)
    command('set complete+=f | edit foo | edit bar |edit foa |edit .hidden')
    feed('i<C-n>')
    screen:expect {
      grid = [[
      foo^                 |
      {12:foo            }{1:     }|
      {4:bar            }{1:     }|
      {4:foa            }{1:     }|
      {4:.hidden        }{1:     }|
      {1:~                   }|*3
      {5:-- }{6:match 1 of 4}     |
    ]],
    }
    feed('<Esc>ccf<C-n>')
    screen:expect {
      grid = [[
      foo^                 |
      {12:foo            }{1:     }|
      {4:foa            }{1:     }|
      {1:~                   }|*5
      {5:-- }{6:match 1 of 2}     |
    ]],
    }
  end)

  it('restores extmarks if original text is restored #23653', function()
    screen:try_resize(screen._width, 4)
    command([[
      call setline(1, ['aaaa'])
      let ns_id = nvim_create_namespace('extmark')
      let mark_id = nvim_buf_set_extmark(0, ns_id, 0, 0, { 'end_col':2, 'hl_group':'Error'})
      let mark = nvim_buf_get_extmark_by_id(0, ns_id, mark_id, { 'details':1 })
      inoremap <C-x> <C-r>=Complete()<CR>
      function Complete() abort
        call complete(1, [{ 'word': 'aaaaa' }])
        return ''
      endfunction
    ]])
    feed('A<C-X><C-E><Esc>')
    eq(eval('mark'), eval("nvim_buf_get_extmark_by_id(0, ns_id, mark_id, { 'details':1 })"))
    feed('A<C-N>')
    eq(eval('mark'), eval("nvim_buf_get_extmark_by_id(0, ns_id, mark_id, { 'details':1 })"))
    feed('<Esc>0Yppia<Esc>ggI<C-N>')
    screen:expect([[
      aaaa{9:^aa}aa                                                    |
      {12:aaaa           }                                             |
      {4:aaaaa          }                                             |
      {5:-- Keyword completion (^N^P) }{6:match 1 of 2}                   |
    ]])
    feed('<C-N><C-N><Esc>')
    eq(eval('mark'), eval("nvim_buf_get_extmark_by_id(0, ns_id, mark_id, { 'details':1 })"))
    feed('A<C-N>')
    eq(eval('mark'), eval("nvim_buf_get_extmark_by_id(0, ns_id, mark_id, { 'details':1 })"))
    feed('<C-N>')
    screen:expect([[
      aaaaa^                                                       |
      {4:aaaa           }                                             |
      {12:aaaaa          }                                             |
      {5:-- Keyword completion (^N^P) }{6:match 2 of 2}                   |
    ]])
    feed('<C-E>')
    screen:expect([[
      {9:aa}aa^                                                        |
      aaaa                                                        |
      aaaaa                                                       |
      {5:-- INSERT --}                                                |
    ]])
    -- Also when completion leader is changed #31384
    feed('<Esc>hi<C-N><C-P>a')
    screen:expect({
      grid = [[
        {9:aa}a^aa                                                       |
        {4:aaaa           }                                             |
        {4:aaaaa          }                                             |
        {5:-- Keyword completion (^N^P) }{19:Back at original}               |
      ]],
    })
  end)
end)
