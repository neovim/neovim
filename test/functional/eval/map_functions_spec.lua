local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local funcs = helpers.funcs
local nvim = helpers.nvim
local source = helpers.source
local command = helpers.command

describe('maparg()', function()
  before_each(clear)

  local foo_bar_map_table = {
      lhs='foo',
      silent=0,
      rhs='bar',
      expr=0,
      sid=0,
      buffer=0,
      nowait=0,
      mode='n',
      noremap=1,
    }

  it('returns a dictionary', function()
    nvim('command', 'nnoremap foo bar')
    eq('bar', funcs.maparg('foo'))
    eq(foo_bar_map_table, funcs.maparg('foo', 'n', false, true))
  end)

  it('returns 1 for silent when <silent> is used', function()
    nvim('command', 'nnoremap <silent> foo bar')
    eq(1, funcs.maparg('foo', 'n', false, true)['silent'])

    nvim('command', 'nnoremap baz bat')
    eq(0, funcs.maparg('baz', 'n', false, true)['silent'])
  end)

  it('returns an empty string when no map is present', function()
    eq('', funcs.maparg('not a mapping'))
  end)

  it('returns an empty dictionary when no map is present and dict is requested', function()
    eq({}, funcs.maparg('not a mapping', 'n', false, true))
  end)

  it('returns the same value for noremap and <script>', function()
    nvim('command', 'inoremap <script> hello world')
    nvim('command', 'inoremap this that')
    eq(
      funcs.maparg('hello', 'i', false, true)['noremap'],
      funcs.maparg('this', 'i', false, true)['noremap']
      )
  end)

  it('returns a boolean for buffer', function()
    -- Open enough windows to know we aren't on buffer number 1
    nvim('command', 'new')
    nvim('command', 'new')
    nvim('command', 'new')
    nvim('command', 'cnoremap <buffer> this that')
    eq(1, funcs.maparg('this', 'c', false, true)['buffer'])

    -- Global will return 0 always
    nvim('command', 'nnoremap other another')
    eq(0, funcs.maparg('other', 'n', false, true)['buffer'])
  end)

  it('returns script numbers', function()
    source([[
      function! s:maparg_test_function() abort
        return 'testing'
      endfunction

      nnoremap fizz :call <SID>maparg_test_function()<CR>
    ]])
    eq(1, funcs.maparg('fizz', 'n', false, true)['sid'])
    eq('testing', nvim('call_function', '<SNR>1_maparg_test_function', {}))
  end)

  it('works with <F12> and others', function()
    source([[
      let g:maparg_test_var = 0

      nnoremap <F12> :let g:maparg_test_var = 1<CR>
    ]])
    eq(0, eval('g:maparg_test_var'))
    source([[
      call feedkeys("\<F12>")
    ]])
    eq(1, eval('g:maparg_test_var'))

    eq(':let g:maparg_test_var = 1<CR>', funcs.maparg('<F12>', 'n', false, true)['rhs'])
  end)

  it('works with <expr>', function()
    source([[
      let counter = 0
      inoremap <expr> <C-L> ListItem()
      inoremap <expr> <C-R> ListReset()

      func ListItem()
        let g:counter += 1
        return g:counter . '. '
      endfunc

      func ListReset()
        let g:counter = 0
        return ''
      endfunc

      call feedkeys("i\<C-L>")
    ]])
    eq(1, eval('g:counter'))

    local map_dict = funcs.maparg('<C-L>', 'i', false, true)
    eq(1, map_dict['expr'])
    eq('i', map_dict['mode'])
  end)

  it('works with combining characters', function()
    -- Using addacutes to make combining character better visible
    local function ac(s)
      local acute = '\204\129'  -- U+0301 COMBINING ACUTE ACCENT
      local ret = s:gsub('`', acute)
      return ret
    end
    command(ac([[
      nnoremap a  b`
      nnoremap c` d
      nnoremap e` f`
    ]]))
    eq(ac('b`'), funcs.maparg(ac('a')))
    eq(ac(''),   funcs.maparg(ac('c')))
    eq(ac('d'),  funcs.maparg(ac('c`')))
    eq(ac('f`'), funcs.maparg(ac('e`')))

    local function acmap(lhs, rhs)
      return {
        lhs = ac(lhs),
        rhs = ac(rhs),

        buffer = 0,
        expr = 0,
        mode = 'n',
        noremap = 1,
        nowait = 0,
        sid = 0,
        silent = 0,
      }
    end

    eq({}, funcs.maparg(ac('c'),  'n', 0, 1))
    eq(acmap('a',  'b`'), funcs.maparg(ac('a'),  'n', 0, 1))
    eq(acmap('c`', 'd'),  funcs.maparg(ac('c`'), 'n', 0, 1))
    eq(acmap('e`', 'f`'), funcs.maparg(ac('e`'), 'n', 0, 1))
  end)
end)
