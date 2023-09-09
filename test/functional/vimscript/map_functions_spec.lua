local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local exec = helpers.exec
local exec_lua = helpers.exec_lua
local expect = helpers.expect
local feed = helpers.feed
local funcs = helpers.funcs
local meths = helpers.meths
local nvim = helpers.nvim
local source = helpers.source
local command = helpers.command
local exec_capture = helpers.exec_capture
local pcall_err = helpers.pcall_err

describe('maparg()', function()
  before_each(clear)

  local foo_bar_map_table = {
      lhs='foo',
      lhsraw='foo',
      script=0,
      silent=0,
      rhs='bar',
      expr=0,
      sid=0,
      buffer=0,
      nowait=0,
      mode='n',
      noremap=1,
      lnum=0,
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
        lhsraw = ac(lhs),
        rhs = ac(rhs),

        buffer = 0,
        expr = 0,
        mode = 'n',
        noremap = 1,
        nowait = 0,
        script=0,
        sid = 0,
        silent = 0,
        lnum = 0,
      }
    end

    eq({}, funcs.maparg(ac('c'),  'n', 0, 1))
    eq(acmap('a',  'b`'), funcs.maparg(ac('a'),  'n', 0, 1))
    eq(acmap('c`', 'd'),  funcs.maparg(ac('c`'), 'n', 0, 1))
    eq(acmap('e`', 'f`'), funcs.maparg(ac('e`'), 'n', 0, 1))
  end)
end)

describe('mapset()', function()
  before_each(clear)

  it('can restore mapping description from the dict returned by maparg()', function()
    meths.set_keymap('n', 'lhs', 'rhs', {desc = 'map description'})
    eq('\nn  lhs           rhs\n                 map description', exec_capture("nmap lhs"))
    local mapargs = funcs.maparg('lhs', 'n', false, true)
    meths.set_keymap('n', 'lhs', 'rhs', {desc = 'MAP DESCRIPTION'})
    eq('\nn  lhs           rhs\n                 MAP DESCRIPTION', exec_capture("nmap lhs"))
    funcs.mapset('n', false, mapargs)
    eq('\nn  lhs           rhs\n                 map description', exec_capture("nmap lhs"))
  end)

  it('can restore "replace_keycodes" from the dict returned by maparg()', function()
    meths.set_keymap('i', 'foo', [['<l' .. 't>']], {expr = true, replace_keycodes = true})
    feed('Afoo')
    expect('<')
    local mapargs = funcs.maparg('foo', 'i', false, true)
    meths.set_keymap('i', 'foo', [['<l' .. 't>']], {expr = true})
    feed('foo')
    expect('<<lt>')
    funcs.mapset('i', false, mapargs)
    feed('foo')
    expect('<<lt><')
  end)

  it('replaces an abbreviation of the same lhs #20320', function()
    command('inoreabbr foo bar')
    eq('\ni  foo         * bar', exec_capture('iabbr foo'))
    feed('ifoo ')
    expect('bar ')
    local mapargs = funcs.maparg('foo', 'i', true, true)
    command('inoreabbr foo BAR')
    eq('\ni  foo         * BAR', exec_capture('iabbr foo'))
    feed('foo ')
    expect('bar BAR ')
    funcs.mapset('i', true, mapargs)
    eq('\ni  foo         * bar', exec_capture('iabbr foo'))
    feed('foo<Esc>')
    expect('bar BAR bar')
  end)

  it('can restore Lua callback from the dict returned by maparg()', function()
    eq(0, exec_lua([[
      GlobalCount = 0
      vim.api.nvim_set_keymap('n', 'asdf', '', {callback = function() GlobalCount = GlobalCount + 1 end })
      return GlobalCount
    ]]))
    feed('asdf')
    eq(1, exec_lua([[return GlobalCount]]))

    exec_lua([[
      _G.saved_asdf_map = vim.fn.maparg('asdf', 'n', false, true)
      vim.api.nvim_set_keymap('n', 'asdf', '', {callback = function() GlobalCount = GlobalCount + 10 end })
    ]])
    feed('asdf')
    eq(11, exec_lua([[return GlobalCount]]))

    exec_lua([[vim.fn.mapset('n', false, _G.saved_asdf_map)]])
    feed('asdf')
    eq(12, exec_lua([[return GlobalCount]]))

    exec([[
      let g:saved_asdf_map = maparg('asdf', 'n', v:false, v:true)
      lua vim.api.nvim_set_keymap('n', 'asdf', '', {callback = function() GlobalCount = GlobalCount + 10 end })
    ]])
    feed('asdf')
    eq(22, exec_lua([[return GlobalCount]]))

    command([[call mapset('n', v:false, g:saved_asdf_map)]])
    feed('asdf')
    eq(23, exec_lua([[return GlobalCount]]))
  end)

  it('does not leak memory if lhs is missing', function()
    eq('Vim:E460: Entries missing in mapset() dict argument',
       pcall_err(exec_lua, [[vim.fn.mapset('n', false, {rhs = 'foo'})]]))
    eq('Vim:E460: Entries missing in mapset() dict argument',
       pcall_err(exec_lua, [[vim.fn.mapset('n', false, {callback = function() end})]]))
  end)
end)
