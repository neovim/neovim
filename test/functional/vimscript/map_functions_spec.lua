local t = require('test.functional.testutil')()

local clear = t.clear
local eq = t.eq
local eval = t.eval
local exec = t.exec
local exec_lua = t.exec_lua
local expect = t.expect
local feed = t.feed
local fn = t.fn
local api = t.api
local source = t.source
local command = t.command
local exec_capture = t.exec_capture
local pcall_err = t.pcall_err

describe('maparg()', function()
  before_each(clear)

  local foo_bar_map_table = {
    lhs = 'foo',
    lhsraw = 'foo',
    script = 0,
    silent = 0,
    rhs = 'bar',
    expr = 0,
    sid = 0,
    scriptversion = 1,
    buffer = 0,
    nowait = 0,
    mode = 'n',
    mode_bits = 0x01,
    abbr = 0,
    noremap = 1,
    lnum = 0,
  }

  it('returns a dictionary', function()
    command('nnoremap foo bar')
    eq('bar', fn.maparg('foo'))
    eq(foo_bar_map_table, fn.maparg('foo', 'n', false, true))
  end)

  it('returns 1 for silent when <silent> is used', function()
    command('nnoremap <silent> foo bar')
    eq(1, fn.maparg('foo', 'n', false, true)['silent'])

    command('nnoremap baz bat')
    eq(0, fn.maparg('baz', 'n', false, true)['silent'])
  end)

  it('returns an empty string when no map is present', function()
    eq('', fn.maparg('not a mapping'))
  end)

  it('returns an empty dictionary when no map is present and dict is requested', function()
    eq({}, fn.maparg('not a mapping', 'n', false, true))
  end)

  it('returns the same value for noremap and <script>', function()
    command('inoremap <script> hello world')
    command('inoremap this that')
    eq(
      fn.maparg('hello', 'i', false, true)['noremap'],
      fn.maparg('this', 'i', false, true)['noremap']
    )
  end)

  it('returns a boolean for buffer', function()
    -- Open enough windows to know we aren't on buffer number 1
    command('new')
    command('new')
    command('new')
    command('cnoremap <buffer> this that')
    eq(1, fn.maparg('this', 'c', false, true)['buffer'])

    -- Global will return 0 always
    command('nnoremap other another')
    eq(0, fn.maparg('other', 'n', false, true)['buffer'])
  end)

  it('returns script numbers', function()
    source([[
      function! s:maparg_test_function() abort
        return 'testing'
      endfunction

      nnoremap fizz :call <SID>maparg_test_function()<CR>
    ]])
    eq(1, fn.maparg('fizz', 'n', false, true)['sid'])
    eq('testing', api.nvim_call_function('<SNR>1_maparg_test_function', {}))
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

    eq(':let g:maparg_test_var = 1<CR>', fn.maparg('<F12>', 'n', false, true)['rhs'])
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

    local map_dict = fn.maparg('<C-L>', 'i', false, true)
    eq(1, map_dict['expr'])
    eq('i', map_dict['mode'])
  end)

  it('works with combining characters', function()
    -- Using addacutes to make combining character better visible
    local function ac(s)
      local acute = '\204\129' -- U+0301 COMBINING ACUTE ACCENT
      local ret = s:gsub('`', acute)
      return ret
    end
    command(ac([[
      nnoremap a  b`
      nnoremap c` d
      nnoremap e` f`
    ]]))
    eq(ac('b`'), fn.maparg(ac('a')))
    eq(ac(''), fn.maparg(ac('c')))
    eq(ac('d'), fn.maparg(ac('c`')))
    eq(ac('f`'), fn.maparg(ac('e`')))

    local function acmap(lhs, rhs)
      return {
        lhs = ac(lhs),
        lhsraw = ac(lhs),
        rhs = ac(rhs),

        buffer = 0,
        expr = 0,
        mode = 'n',
        mode_bits = 0x01,
        abbr = 0,
        noremap = 1,
        nowait = 0,
        script = 0,
        sid = 0,
        scriptversion = 1,
        silent = 0,
        lnum = 0,
      }
    end

    eq({}, fn.maparg(ac('c'), 'n', 0, 1))
    eq(acmap('a', 'b`'), fn.maparg(ac('a'), 'n', 0, 1))
    eq(acmap('c`', 'd'), fn.maparg(ac('c`'), 'n', 0, 1))
    eq(acmap('e`', 'f`'), fn.maparg(ac('e`'), 'n', 0, 1))
  end)
end)

describe('mapset()', function()
  before_each(clear)

  it('can restore mapping with backslash in lhs', function()
    api.nvim_set_keymap('n', '\\ab', 'a', {})
    eq('\nn  \\ab           a', exec_capture('nmap \\ab'))
    local mapargs = fn.maparg('\\ab', 'n', false, true)
    api.nvim_set_keymap('n', '\\ab', 'b', {})
    eq('\nn  \\ab           b', exec_capture('nmap \\ab'))
    fn.mapset('n', false, mapargs)
    eq('\nn  \\ab           a', exec_capture('nmap \\ab'))
  end)

  it('can restore mapping description from the dict returned by maparg()', function()
    api.nvim_set_keymap('n', 'lhs', 'rhs', { desc = 'map description' })
    eq('\nn  lhs           rhs\n                 map description', exec_capture('nmap lhs'))
    local mapargs = fn.maparg('lhs', 'n', false, true)
    api.nvim_set_keymap('n', 'lhs', 'rhs', { desc = 'MAP DESCRIPTION' })
    eq('\nn  lhs           rhs\n                 MAP DESCRIPTION', exec_capture('nmap lhs'))
    fn.mapset('n', false, mapargs)
    eq('\nn  lhs           rhs\n                 map description', exec_capture('nmap lhs'))
  end)

  it('can restore "replace_keycodes" from the dict returned by maparg()', function()
    api.nvim_set_keymap('i', 'foo', [['<l' .. 't>']], { expr = true, replace_keycodes = true })
    feed('Afoo')
    expect('<')
    local mapargs = fn.maparg('foo', 'i', false, true)
    api.nvim_set_keymap('i', 'foo', [['<l' .. 't>']], { expr = true })
    feed('foo')
    expect('<<lt>')
    fn.mapset('i', false, mapargs)
    feed('foo')
    expect('<<lt><')
  end)

  it('replaces an abbreviation of the same lhs #20320', function()
    command('inoreabbr foo bar')
    eq('\ni  foo         * bar', exec_capture('iabbr foo'))
    feed('ifoo ')
    expect('bar ')
    local mapargs = fn.maparg('foo', 'i', true, true)
    command('inoreabbr foo BAR')
    eq('\ni  foo         * BAR', exec_capture('iabbr foo'))
    feed('foo ')
    expect('bar BAR ')
    fn.mapset('i', true, mapargs)
    eq('\ni  foo         * bar', exec_capture('iabbr foo'))
    feed('foo<Esc>')
    expect('bar BAR bar')
  end)

  it('can restore Lua callback from the dict returned by maparg()', function()
    eq(
      0,
      exec_lua([[
      GlobalCount = 0
      vim.api.nvim_set_keymap('n', 'asdf', '', {callback = function() GlobalCount = GlobalCount + 1 end })
      return GlobalCount
    ]])
    )
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
    eq(
      'Vim:E460: Entries missing in mapset() dict argument',
      pcall_err(exec_lua, [[vim.fn.mapset('n', false, {rhs = 'foo'})]])
    )
    eq(
      'Vim:E460: Entries missing in mapset() dict argument',
      pcall_err(exec_lua, [[vim.fn.mapset('n', false, {callback = function() end})]])
    )
  end)
end)
