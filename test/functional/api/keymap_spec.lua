local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq, neq = t.eq, t.neq
local exec_lua = n.exec_lua
local exec = n.exec
local feed = n.feed
local fn = n.fn
local api = n.api
local matches = t.matches
local source = n.source
local pcall_err = t.pcall_err

local shallowcopy = t.shallowcopy
local sleep = vim.uv.sleep

local sid_api_client = -9
local sid_lua = -8

local mode_bits_map = {
  ['n'] = 0x01,
  ['x'] = 0x02,
  ['o'] = 0x04,
  ['c'] = 0x08,
  ['i'] = 0x10,
  ['l'] = 0x20,
  ['s'] = 0x40,
  ['t'] = 0x80,
  [' '] = 0x47,
  ['v'] = 0x42,
  ['!'] = 0x18,
}

describe('nvim_get_keymap', function()
  before_each(clear)

  -- Basic mapping and table to be used to describe results
  local foo_bar_string = 'nnoremap foo bar'
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

  it('returns empty list when no map', function()
    eq({}, api.nvim_get_keymap('n'))
  end)

  it('returns list of all applicable mappings', function()
    command(foo_bar_string)
    -- Only one mapping available
    -- Should be the same as the dictionary we supplied earlier
    -- and the dictionary you would get from maparg
    -- since this is a global map, and not script local
    eq({ foo_bar_map_table }, api.nvim_get_keymap('n'))
    eq({ fn.maparg('foo', 'n', false, true) }, api.nvim_get_keymap('n'))

    -- Add another mapping
    command('nnoremap foo_longer bar_longer')
    local foolong_bar_map_table = shallowcopy(foo_bar_map_table)
    foolong_bar_map_table['lhs'] = 'foo_longer'
    foolong_bar_map_table['lhsraw'] = 'foo_longer'
    foolong_bar_map_table['rhs'] = 'bar_longer'

    eq({ foolong_bar_map_table, foo_bar_map_table }, api.nvim_get_keymap('n'))

    -- Remove a mapping
    command('unmap foo_longer')
    eq({ foo_bar_map_table }, api.nvim_get_keymap('n'))
  end)

  it('works for other modes', function()
    -- Add two mappings, one in insert and one normal
    -- We'll only check the insert mode one
    command('nnoremap not_going to_check')

    command('inoremap foo bar')
    -- The table will be the same except for the mode
    local insert_table = shallowcopy(foo_bar_map_table)
    insert_table['mode'] = 'i'
    insert_table['mode_bits'] = 0x10

    eq({ insert_table }, api.nvim_get_keymap('i'))
  end)

  it('considers scope', function()
    -- change the map slightly
    command('nnoremap foo_longer bar_longer')
    local foolong_bar_map_table = shallowcopy(foo_bar_map_table)
    foolong_bar_map_table['lhs'] = 'foo_longer'
    foolong_bar_map_table['lhsraw'] = 'foo_longer'
    foolong_bar_map_table['rhs'] = 'bar_longer'

    local buffer_table = shallowcopy(foo_bar_map_table)
    buffer_table['buffer'] = 1

    command('nnoremap <buffer> foo bar')

    -- The buffer mapping should not show up
    eq({ foolong_bar_map_table }, api.nvim_get_keymap('n'))
    eq({ buffer_table }, api.nvim_buf_get_keymap(0, 'n'))
  end)

  it('considers scope for overlapping maps', function()
    command('nnoremap foo bar')

    local buffer_table = shallowcopy(foo_bar_map_table)
    buffer_table['buffer'] = 1

    command('nnoremap <buffer> foo bar')

    eq({ foo_bar_map_table }, api.nvim_get_keymap('n'))
    eq({ buffer_table }, api.nvim_buf_get_keymap(0, 'n'))
  end)

  it('can retrieve mapping for different buffers', function()
    local original_buffer = api.nvim_buf_get_number(0)
    -- Place something in each of the buffers to make sure they stick around
    -- and set hidden so we can leave them
    command('set hidden')
    command('new')
    command('normal! ihello 2')
    command('new')
    command('normal! ihello 3')

    local final_buffer = api.nvim_buf_get_number(0)

    command('nnoremap <buffer> foo bar')
    -- Final buffer will have buffer mappings
    local buffer_table = shallowcopy(foo_bar_map_table)
    buffer_table['buffer'] = final_buffer
    eq({ buffer_table }, api.nvim_buf_get_keymap(final_buffer, 'n'))
    eq({ buffer_table }, api.nvim_buf_get_keymap(0, 'n'))

    command('buffer ' .. original_buffer)
    eq(original_buffer, api.nvim_buf_get_number(0))
    -- Original buffer won't have any mappings
    eq({}, api.nvim_get_keymap('n'))
    eq({}, api.nvim_buf_get_keymap(0, 'n'))
    eq({ buffer_table }, api.nvim_buf_get_keymap(final_buffer, 'n'))
  end)

  -- Test toggle switches for basic options
  -- @param  option  The key represented in the `maparg()` result dict
  local function global_and_buffer_test(
    map,
    option,
    option_token,
    global_on_result,
    buffer_on_result,
    global_off_result,
    buffer_off_result,
    new_windows
  )
    local function make_new_windows(number_of_windows)
      if new_windows == nil then
        return nil
      end

      for _ = 1, number_of_windows do
        command('new')
      end
    end

    local mode = string.sub(map, 1, 1)
    -- Don't run this for the <buffer> mapping, since it doesn't make sense
    if option_token ~= '<buffer>' then
      it(
        string.format(
          'returns %d for the key "%s" when %s is used globally with %s (%s)',
          global_on_result,
          option,
          option_token,
          map,
          mode
        ),
        function()
          make_new_windows(new_windows)
          command(map .. ' ' .. option_token .. ' foo bar')
          local result = api.nvim_get_keymap(mode)[1][option]
          eq(global_on_result, result)
        end
      )
    end

    it(
      string.format(
        'returns %d for the key "%s" when %s is used for buffers with %s (%s)',
        buffer_on_result,
        option,
        option_token,
        map,
        mode
      ),
      function()
        make_new_windows(new_windows)
        command(map .. ' <buffer> ' .. option_token .. ' foo bar')
        local result = api.nvim_buf_get_keymap(0, mode)[1][option]
        eq(buffer_on_result, result)
      end
    )

    -- Don't run these for the <buffer> mapping, since it doesn't make sense
    if option_token ~= '<buffer>' then
      it(
        string.format(
          'returns %d for the key "%s" when %s is not used globally with %s (%s)',
          global_off_result,
          option,
          option_token,
          map,
          mode
        ),
        function()
          make_new_windows(new_windows)
          command(map .. ' baz bat')
          local result = api.nvim_get_keymap(mode)[1][option]
          eq(global_off_result, result)
        end
      )

      it(
        string.format(
          'returns %d for the key "%s" when %s is not used for buffers with %s (%s)',
          buffer_off_result,
          option,
          option_token,
          map,
          mode
        ),
        function()
          make_new_windows(new_windows)
          command(map .. ' <buffer> foo bar')

          local result = api.nvim_buf_get_keymap(0, mode)[1][option]
          eq(buffer_off_result, result)
        end
      )
    end
  end

  -- Standard modes and returns the same values in the dictionary as maparg()
  local mode_list = { 'nnoremap', 'nmap', 'imap', 'inoremap', 'cnoremap' }
  for mode in pairs(mode_list) do
    global_and_buffer_test(mode_list[mode], 'silent', '<silent>', 1, 1, 0, 0)
    global_and_buffer_test(mode_list[mode], 'nowait', '<nowait>', 1, 1, 0, 0)
    global_and_buffer_test(mode_list[mode], 'expr', '<expr>', 1, 1, 0, 0)
  end

  -- noremap will now be 2 if script was used, which is not the same as maparg()
  global_and_buffer_test('nmap', 'noremap', '<script>', 2, 2, 0, 0)
  global_and_buffer_test('nnoremap', 'noremap', '<script>', 2, 2, 1, 1)

  -- buffer will return the buffer ID, which is not the same as maparg()
  -- Three of these tests won't run
  global_and_buffer_test('nnoremap', 'buffer', '<buffer>', nil, 3, nil, nil, 2)

  it('returns script numbers for global maps', function()
    source([[
      function! s:maparg_test_function() abort
        return 'testing'
      endfunction

      nnoremap fizz :call <SID>maparg_test_function()<CR>
    ]])
    local sid_result = api.nvim_get_keymap('n')[1]['sid']
    eq(1, sid_result)
    eq('testing', api.nvim_call_function('<SNR>' .. sid_result .. '_maparg_test_function', {}))
  end)

  it('returns script numbers for buffer maps', function()
    source([[
      function! s:maparg_test_function() abort
        return 'testing'
      endfunction

      nnoremap <buffer> fizz :call <SID>maparg_test_function()<CR>
    ]])
    local sid_result = api.nvim_buf_get_keymap(0, 'n')[1]['sid']
    eq(1, sid_result)
    eq('testing', api.nvim_call_function('<SNR>' .. sid_result .. '_maparg_test_function', {}))
  end)

  it('works with <F12> and others', function()
    command('nnoremap <F12> :let g:maparg_test_var = 1<CR>')
    eq('<F12>', api.nvim_get_keymap('n')[1]['lhs'])
    eq(':let g:maparg_test_var = 1<CR>', api.nvim_get_keymap('n')[1]['rhs'])
  end)

  it('works correctly despite various &cpo settings', function()
    local cpo_table = {
      script = 0,
      silent = 0,
      expr = 0,
      sid = 0,
      scriptversion = 1,
      buffer = 0,
      nowait = 0,
      abbr = 0,
      noremap = 1,
      lnum = 0,
    }
    local function cpomap(lhs, rhs, mode)
      local ret = shallowcopy(cpo_table)
      local lhsraw = api.nvim_eval(('"%s"'):format(lhs:gsub('\\', '\\\\'):gsub('<', '\\<*')))
      local lhsrawalt = api.nvim_eval(('"%s"'):format(lhs:gsub('\\', '\\\\'):gsub('<', '\\<')))
      ret.lhs = lhs
      ret.lhsraw = lhsraw
      ret.lhsrawalt = lhsrawalt ~= lhsraw and lhsrawalt or nil
      ret.rhs = rhs
      ret.mode = mode
      ret.mode_bits = mode_bits_map[mode]
      return ret
    end

    command('set cpo+=B')
    command('nnoremap \\<C-a><C-a><LT>C-a>\\  \\<C-b><C-b><LT>C-b>\\')
    command('nnoremap <special> \\<C-c><C-c><LT>C-c>\\  \\<C-d><C-d><LT>C-d>\\')

    command('set cpo+=B')
    command('xnoremap \\<C-a><C-a><LT>C-a>\\  \\<C-b><C-b><LT>C-b>\\')
    command('xnoremap <special> \\<C-c><C-c><LT>C-c>\\  \\<C-d><C-d><LT>C-d>\\')

    command('set cpo-=B')
    command('snoremap \\<C-a><C-a><LT>C-a>\\  \\<C-b><C-b><LT>C-b>\\')
    command('snoremap <special> \\<C-c><C-c><LT>C-c>\\  \\<C-d><C-d><LT>C-d>\\')

    command('set cpo-=B')
    command('onoremap \\<C-a><C-a><LT>C-a>\\  \\<C-b><C-b><LT>C-b>\\')
    command('onoremap <special> \\<C-c><C-c><LT>C-c>\\  \\<C-d><C-d><LT>C-d>\\')

    for _, cmd in ipairs({
      'set cpo-=B',
      'set cpo+=B',
    }) do
      command(cmd)
      eq({
        cpomap('\\<C-C><C-C><lt>C-c>\\', '\\<C-D><C-D><lt>C-d>\\', 'n'),
        cpomap('\\<C-A><C-A><lt>C-a>\\', '\\<C-B><C-B><lt>C-b>\\', 'n'),
      }, api.nvim_get_keymap('n'))
      eq({
        cpomap('\\<C-C><C-C><lt>C-c>\\', '\\<C-D><C-D><lt>C-d>\\', 'x'),
        cpomap('\\<C-A><C-A><lt>C-a>\\', '\\<C-B><C-B><lt>C-b>\\', 'x'),
      }, api.nvim_get_keymap('x'))
      eq({
        cpomap('<lt>C-c><C-C><lt>C-c> ', '<lt>C-d><C-D><lt>C-d>', 's'),
        cpomap('<lt>C-a><C-A><lt>C-a> ', '<lt>C-b><C-B><lt>C-b>', 's'),
      }, api.nvim_get_keymap('s'))
      eq({
        cpomap('<lt>C-c><C-C><lt>C-c> ', '<lt>C-d><C-D><lt>C-d>', 'o'),
        cpomap('<lt>C-a><C-A><lt>C-a> ', '<lt>C-b><C-B><lt>C-b>', 'o'),
      }, api.nvim_get_keymap('o'))
    end
  end)

  it('always uses space for space and bar for bar', function()
    local space_table = {
      lhs = '|   |',
      lhsraw = '|   |',
      rhs = '|    |',
      mode = 'n',
      mode_bits = 0x01,
      abbr = 0,
      script = 0,
      silent = 0,
      expr = 0,
      sid = 0,
      scriptversion = 1,
      buffer = 0,
      nowait = 0,
      noremap = 1,
      lnum = 0,
    }
    command('nnoremap \\|<Char-0x20><Char-32><Space><Bar> \\|<Char-0x20><Char-32><Space> <Bar>')
    eq({ space_table }, api.nvim_get_keymap('n'))
  end)

  it('can handle lua mappings', function()
    eq(
      0,
      exec_lua([[
      GlobalCount = 0
      vim.api.nvim_set_keymap('n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]])
    )

    feed('asdf\n')
    eq(1, exec_lua([[return GlobalCount]]))

    eq(
      2,
      exec_lua([[
      vim.api.nvim_get_keymap('n')[1].callback()
      return GlobalCount
    ]])
    )

    exec([[
      call nvim_get_keymap('n')[0].callback()
    ]])
    eq(3, exec_lua([[return GlobalCount]]))

    local mapargs = api.nvim_get_keymap('n')
    mapargs[1].callback = nil
    eq({
      lhs = 'asdf',
      lhsraw = 'asdf',
      script = 0,
      silent = 0,
      expr = 0,
      sid = sid_lua,
      scriptversion = 1,
      buffer = 0,
      nowait = 0,
      mode = 'n',
      mode_bits = 0x01,
      abbr = 0,
      noremap = 0,
      lnum = 0,
    }, mapargs[1])
  end)

  it('can handle map descriptions', function()
    api.nvim_set_keymap('n', 'lhs', 'rhs', { desc = 'map description' })
    eq({
      lhs = 'lhs',
      lhsraw = 'lhs',
      rhs = 'rhs',
      script = 0,
      silent = 0,
      expr = 0,
      sid = sid_api_client,
      scriptversion = 1,
      buffer = 0,
      nowait = 0,
      mode = 'n',
      mode_bits = 0x01,
      abbr = 0,
      noremap = 0,
      lnum = 0,
      desc = 'map description',
    }, api.nvim_get_keymap('n')[1])
  end)

  it('can get abbreviations', function()
    command('inoreabbr foo bar')
    command('cnoreabbr <buffer> foo baz')

    local mapargs_i = {
      abbr = 1,
      buffer = 0,
      expr = 0,
      lhs = 'foo',
      lhsraw = 'foo',
      lnum = 0,
      mode = 'i',
      mode_bits = 0x10,
      noremap = 1,
      nowait = 0,
      rhs = 'bar',
      script = 0,
      scriptversion = 1,
      sid = 0,
      silent = 0,
    }
    local mapargs_c = {
      abbr = 1,
      buffer = 1,
      expr = 0,
      lhs = 'foo',
      lhsraw = 'foo',
      lnum = 0,
      mode = 'c',
      mode_bits = 0x08,
      noremap = 1,
      nowait = 0,
      rhs = 'baz',
      script = 0,
      scriptversion = 1,
      sid = 0,
      silent = 0,
    }

    local curbuf = api.nvim_get_current_buf()

    eq({ mapargs_i }, api.nvim_get_keymap('ia'))
    eq({}, api.nvim_buf_get_keymap(curbuf, 'ia'))

    eq({}, api.nvim_get_keymap('ca'))
    eq({ mapargs_c }, api.nvim_buf_get_keymap(curbuf, 'ca'))

    eq({ mapargs_i }, api.nvim_get_keymap('!a'))
    eq({ mapargs_c }, api.nvim_buf_get_keymap(curbuf, '!a'))
  end)
end)

describe('nvim_set_keymap, nvim_del_keymap', function()
  before_each(clear)

  -- `generate_expected` is truthy: for generating an expected output for
  -- maparg(), which does not accept "!" (though it returns "!" in its output
  -- if getting a mapping set with |:map!|).
  local function normalize_mapmode(mode, generate_expected)
    if mode:sub(-1) == 'a' then
      mode = mode:sub(1, -2)
    end
    if not generate_expected and mode == '!' then
      -- Cannot retrieve mapmode-ic mappings with "!", but can with "i" or "c".
      mode = 'i'
    elseif mode == '' then
      mode = generate_expected and ' ' or mode
    end
    return mode
  end

  -- Generate a mapargs dict, for comparison against the mapping that was
  -- actually set
  local function generate_mapargs(mode, lhs, rhs, opts)
    if not opts then
      opts = {}
    end

    local to_return = {}
    local expected_mode = normalize_mapmode(mode, true)
    to_return.mode = expected_mode
    to_return.mode_bits = mode_bits_map[expected_mode]
    to_return.abbr = mode:sub(-1) == 'a' and 1 or 0
    to_return.noremap = not opts.noremap and 0 or 1
    to_return.lhs = lhs
    to_return.rhs = rhs
    to_return.script = 0
    to_return.silent = not opts.silent and 0 or 1
    to_return.nowait = not opts.nowait and 0 or 1
    to_return.expr = not opts.expr and 0 or 1
    to_return.sid = not opts.sid and sid_api_client or opts.sid
    to_return.scriptversion = 1
    to_return.buffer = not opts.buffer and 0 or opts.buffer
    to_return.lnum = not opts.lnum and 0 or opts.lnum
    to_return.desc = opts.desc

    return to_return
  end

  -- Gets a maparg() dict from Nvim, if one exists.
  local function get_mapargs(mode, lhs)
    local mapargs = fn.maparg(lhs, normalize_mapmode(mode), mode:sub(-1) == 'a', true)
    -- drop "lhsraw" and "lhsrawalt" which are hard to check
    mapargs.lhsraw = nil
    mapargs.lhsrawalt = nil
    return mapargs
  end

  it('error on empty LHS', function()
    -- escape parentheses in lua string, else comparison fails erroneously
    eq('Invalid (empty) LHS', pcall_err(api.nvim_set_keymap, '', '', 'rhs', {}))
    eq('Invalid (empty) LHS', pcall_err(api.nvim_set_keymap, '', '', '', {}))
    eq('Invalid (empty) LHS', pcall_err(api.nvim_del_keymap, '', ''))
  end)

  it('error if LHS longer than MAXMAPLEN', function()
    -- assume MAXMAPLEN of 50 chars, as declared in mapping_defs.h
    local MAXMAPLEN = 50
    local lhs = ''
    for i = 1, MAXMAPLEN do
      lhs = lhs .. (i % 10)
    end

    -- exactly 50 chars should be fine
    api.nvim_set_keymap('', lhs, 'rhs', {})

    -- del_keymap should unmap successfully
    api.nvim_del_keymap('', lhs)
    eq({}, get_mapargs('', lhs))

    -- 51 chars should produce an error
    lhs = lhs .. '1'
    eq(
      'LHS exceeds maximum map length: ' .. lhs,
      pcall_err(api.nvim_set_keymap, '', lhs, 'rhs', {})
    )
    eq('LHS exceeds maximum map length: ' .. lhs, pcall_err(api.nvim_del_keymap, '', lhs))
  end)

  it('does not throw errors when rhs is longer than MAXMAPLEN', function()
    local MAXMAPLEN = 50
    local rhs = ''
    for i = 1, MAXMAPLEN do
      rhs = rhs .. (i % 10)
    end
    rhs = rhs .. '1'
    api.nvim_set_keymap('', 'lhs', rhs, {})
    eq(generate_mapargs('', 'lhs', rhs), get_mapargs('', 'lhs'))
  end)

  it('error on invalid mode shortname', function()
    eq('Invalid mode shortname: " "', pcall_err(api.nvim_set_keymap, ' ', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "m"', pcall_err(api.nvim_set_keymap, 'm', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "?"', pcall_err(api.nvim_set_keymap, '?', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "y"', pcall_err(api.nvim_set_keymap, 'y', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "p"', pcall_err(api.nvim_set_keymap, 'p', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "a"', pcall_err(api.nvim_set_keymap, 'a', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "oa"', pcall_err(api.nvim_set_keymap, 'oa', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "!o"', pcall_err(api.nvim_set_keymap, '!o', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "!i"', pcall_err(api.nvim_set_keymap, '!i', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "!!"', pcall_err(api.nvim_set_keymap, '!!', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "map"', pcall_err(api.nvim_set_keymap, 'map', 'lhs', 'rhs', {}))
    eq('Invalid mode shortname: "vmap"', pcall_err(api.nvim_set_keymap, 'vmap', 'lhs', 'rhs', {}))
    eq(
      'Invalid mode shortname: "xnoremap"',
      pcall_err(api.nvim_set_keymap, 'xnoremap', 'lhs', 'rhs', {})
    )
    eq('Invalid mode shortname: " "', pcall_err(api.nvim_del_keymap, ' ', 'lhs'))
    eq('Invalid mode shortname: "m"', pcall_err(api.nvim_del_keymap, 'm', 'lhs'))
    eq('Invalid mode shortname: "?"', pcall_err(api.nvim_del_keymap, '?', 'lhs'))
    eq('Invalid mode shortname: "y"', pcall_err(api.nvim_del_keymap, 'y', 'lhs'))
    eq('Invalid mode shortname: "p"', pcall_err(api.nvim_del_keymap, 'p', 'lhs'))
    eq('Invalid mode shortname: "a"', pcall_err(api.nvim_del_keymap, 'a', 'lhs'))
    eq('Invalid mode shortname: "oa"', pcall_err(api.nvim_del_keymap, 'oa', 'lhs'))
    eq('Invalid mode shortname: "!o"', pcall_err(api.nvim_del_keymap, '!o', 'lhs'))
    eq('Invalid mode shortname: "!i"', pcall_err(api.nvim_del_keymap, '!i', 'lhs'))
    eq('Invalid mode shortname: "!!"', pcall_err(api.nvim_del_keymap, '!!', 'lhs'))
    eq('Invalid mode shortname: "map"', pcall_err(api.nvim_del_keymap, 'map', 'lhs'))
    eq('Invalid mode shortname: "vmap"', pcall_err(api.nvim_del_keymap, 'vmap', 'lhs'))
    eq('Invalid mode shortname: "xnoremap"', pcall_err(api.nvim_del_keymap, 'xnoremap', 'lhs'))
  end)

  it('error on invalid optnames', function()
    eq(
      "Invalid key: 'silentt'",
      pcall_err(api.nvim_set_keymap, 'n', 'lhs', 'rhs', { silentt = true })
    )
    eq("Invalid key: 'sidd'", pcall_err(api.nvim_set_keymap, 'n', 'lhs', 'rhs', { sidd = false }))
    eq(
      "Invalid key: 'nowaiT'",
      pcall_err(api.nvim_set_keymap, 'n', 'lhs', 'rhs', { nowaiT = false })
    )
  end)

  it('error on <buffer> option key', function()
    eq(
      "Invalid key: 'buffer'",
      pcall_err(api.nvim_set_keymap, 'n', 'lhs', 'rhs', { buffer = true })
    )
  end)

  it('error when "replace_keycodes" is used without "expr"', function()
    eq(
      '"replace_keycodes" requires "expr"',
      pcall_err(api.nvim_set_keymap, 'n', 'lhs', 'rhs', { replace_keycodes = true })
    )
  end)

  local optnames = { 'nowait', 'silent', 'script', 'expr', 'unique' }
  for _, opt in ipairs(optnames) do
    -- note: need '%' to escape hyphens, which have special meaning in lua
    it('throws an error when given non-boolean value for ' .. opt, function()
      local opts = {}
      opts[opt] = 'fooo'
      eq(opt .. ' is not a boolean', pcall_err(api.nvim_set_keymap, 'n', 'lhs', 'rhs', opts))
    end)
  end

  -- Perform tests of basic functionality
  it('sets ordinary mappings', function()
    api.nvim_set_keymap('n', 'lhs', 'rhs', {})
    eq(generate_mapargs('n', 'lhs', 'rhs'), get_mapargs('n', 'lhs'))

    api.nvim_set_keymap('v', 'lhs', 'rhs', {})
    eq(generate_mapargs('v', 'lhs', 'rhs'), get_mapargs('v', 'lhs'))
  end)

  it('does not throw when LHS or RHS have leading/trailing whitespace', function()
    api.nvim_set_keymap('n', '   lhs', 'rhs', {})
    eq(generate_mapargs('n', '<Space><Space><Space>lhs', 'rhs'), get_mapargs('n', '   lhs'))

    api.nvim_set_keymap('n', 'lhs    ', 'rhs', {})
    eq(generate_mapargs('n', 'lhs<Space><Space><Space><Space>', 'rhs'), get_mapargs('n', 'lhs    '))

    api.nvim_set_keymap('v', ' lhs  ', '\trhs\t\f', {})
    eq(generate_mapargs('v', '<Space>lhs<Space><Space>', '\trhs\t\f'), get_mapargs('v', ' lhs  '))
  end)

  it('can set noremap mappings', function()
    api.nvim_set_keymap('x', 'lhs', 'rhs', { noremap = true })
    eq(generate_mapargs('x', 'lhs', 'rhs', { noremap = true }), get_mapargs('x', 'lhs'))

    api.nvim_set_keymap('t', 'lhs', 'rhs', { noremap = true })
    eq(generate_mapargs('t', 'lhs', 'rhs', { noremap = true }), get_mapargs('t', 'lhs'))
  end)

  it('can unmap mappings', function()
    api.nvim_set_keymap('v', 'lhs', 'rhs', {})
    api.nvim_del_keymap('v', 'lhs')
    eq({}, get_mapargs('v', 'lhs'))

    api.nvim_set_keymap('t', 'lhs', 'rhs', { noremap = true })
    api.nvim_del_keymap('t', 'lhs')
    eq({}, get_mapargs('t', 'lhs'))
  end)

  -- Test some edge cases
  it('"!" and empty string are synonyms for mapmode-nvo', function()
    local nvo_shortnames = { '', '!' }
    for _, name in ipairs(nvo_shortnames) do
      api.nvim_set_keymap(name, 'lhs', 'rhs', {})
      api.nvim_del_keymap(name, 'lhs')
      eq({}, get_mapargs(name, 'lhs'))
    end
  end)

  local special_chars = { '<C-U>', '<S-Left>', '<F12><F2><Tab>', '<Space><Tab>' }
  for _, lhs in ipairs(special_chars) do
    for _, rhs in ipairs(special_chars) do
      local mapmode = '!'
      it('can set mappings with special characters, lhs: ' .. lhs .. ', rhs: ' .. rhs, function()
        api.nvim_set_keymap(mapmode, lhs, rhs, {})
        eq(generate_mapargs(mapmode, lhs, rhs), get_mapargs(mapmode, lhs))
      end)
    end
  end

  it('can set mappings containing C0 control codes', function()
    api.nvim_set_keymap('n', '\n\r\n', 'rhs', {})
    local expected = generate_mapargs('n', '<NL><CR><NL>', 'rhs')
    eq(expected, get_mapargs('n', '<NL><CR><NL>'))
  end)

  it('can set mappings whose RHS is a <Nop>', function()
    api.nvim_set_keymap('i', 'lhs', '<Nop>', {})
    command('normal ilhs')
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, 0)) -- imap to <Nop> does nothing
    eq(generate_mapargs('i', 'lhs', '<Nop>', {}), get_mapargs('i', 'lhs'))

    -- also test for case insensitivity
    api.nvim_set_keymap('i', 'lhs', '<nOp>', {})
    command('normal ilhs')
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, 0))
    -- note: RHS in returned mapargs() dict reflects the original RHS
    -- provided by the user
    eq(generate_mapargs('i', 'lhs', '<nOp>', {}), get_mapargs('i', 'lhs'))

    api.nvim_set_keymap('i', 'lhs', '<NOP>', {})
    command('normal ilhs')
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, 0))
    eq(generate_mapargs('i', 'lhs', '<NOP>', {}), get_mapargs('i', 'lhs'))

    -- a single ^V in RHS is also <Nop> (see :h map-empty-rhs)
    api.nvim_set_keymap('i', 'lhs', '\022', {})
    command('normal ilhs')
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, 0))
    eq(generate_mapargs('i', 'lhs', '\022', {}), get_mapargs('i', 'lhs'))
  end)

  it('treats an empty RHS in a mapping like a <Nop>', function()
    api.nvim_set_keymap('i', 'lhs', '', {})
    command('normal ilhs')
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, 0))
    eq(generate_mapargs('i', 'lhs', '', {}), get_mapargs('i', 'lhs'))
  end)

  it('can set and unset <M-">', function()
    -- Taken from the legacy test: test_mapping.vim. Exposes a bug in which
    -- replace_termcodes changes the length of the mapping's LHS, but
    -- do_map continues to use the *old* length of LHS.
    api.nvim_set_keymap('i', '<M-">', 'foo', {})
    api.nvim_del_keymap('i', '<M-">')
    eq({}, get_mapargs('i', '<M-">'))
  end)

  it(
    'interprets control sequences in expr-quotes correctly when called ' .. 'inside vim',
    function()
      command([[call nvim_set_keymap('i', "\<space>", "\<tab>", {})]])
      eq(generate_mapargs('i', '<Space>', '\t', { sid = 0 }), get_mapargs('i', '<Space>'))
      feed('i ')
      eq({ '\t' }, api.nvim_buf_get_lines(0, 0, -1, 0))
    end
  )

  it('throws appropriate error messages when setting <unique> maps', function()
    api.nvim_set_keymap('l', 'lhs', 'rhs', {})
    eq(
      'E227: Mapping already exists for lhs',
      pcall_err(api.nvim_set_keymap, 'l', 'lhs', 'rhs', { unique = true })
    )
    -- different mapmode, no error should be thrown
    api.nvim_set_keymap('t', 'lhs', 'rhs', { unique = true })

    api.nvim_set_keymap('n', '<tab>', 'rhs', {})
    eq(
      'E227: Mapping already exists for <tab>',
      pcall_err(api.nvim_set_keymap, 'n', '<tab>', 'rhs', { unique = true })
    )

    api.nvim_set_keymap('ia', 'lhs', 'rhs', {})
    eq(
      'E226: Abbreviation already exists for lhs',
      pcall_err(api.nvim_set_keymap, 'ia', 'lhs', 'rhs', { unique = true })
    )
  end)

  it('can set <expr> mappings whose RHS change dynamically', function()
    exec([[
        function! FlipFlop() abort
          if !exists('g:flip') | let g:flip = 0 | endif
          let g:flip = !g:flip
          return g:flip
        endfunction
        ]])
    eq(1, api.nvim_call_function('FlipFlop', {}))
    eq(0, api.nvim_call_function('FlipFlop', {}))
    eq(1, api.nvim_call_function('FlipFlop', {}))
    eq(0, api.nvim_call_function('FlipFlop', {}))

    api.nvim_set_keymap('i', 'lhs', 'FlipFlop()', { expr = true })
    command('normal ilhs')
    eq({ '1' }, api.nvim_buf_get_lines(0, 0, -1, 0))

    command('normal! ggVGd')

    command('normal ilhs')
    eq({ '0' }, api.nvim_buf_get_lines(0, 0, -1, 0))
  end)

  it('can set mappings that do trigger other mappings', function()
    api.nvim_set_keymap('i', 'mhs', 'rhs', {})
    api.nvim_set_keymap('i', 'lhs', 'mhs', {})

    command('normal imhs')
    eq({ 'rhs' }, api.nvim_buf_get_lines(0, 0, -1, 0))

    command('normal! ggVGd')

    command('normal ilhs')
    eq({ 'rhs' }, api.nvim_buf_get_lines(0, 0, -1, 0))
  end)

  it("can set noremap mappings that don't trigger other mappings", function()
    api.nvim_set_keymap('i', 'mhs', 'rhs', {})
    api.nvim_set_keymap('i', 'lhs', 'mhs', { noremap = true })

    command('normal imhs')
    eq({ 'rhs' }, api.nvim_buf_get_lines(0, 0, -1, 0))

    command('normal! ggVGd')

    command('normal ilhs') -- shouldn't trigger mhs-to-rhs mapping
    eq({ 'mhs' }, api.nvim_buf_get_lines(0, 0, -1, 0))
  end)

  it('can set nowait mappings that fire without waiting', function()
    api.nvim_set_keymap('i', '123456', 'longer', {})
    api.nvim_set_keymap('i', '123', 'shorter', { nowait = true })

    -- feed keys one at a time; if all keys arrive atomically, the longer
    -- mapping will trigger
    local keys = 'i123456'
    for c in string.gmatch(keys, '.') do
      feed(c)
      sleep(5)
    end
    eq({ 'shorter456' }, api.nvim_buf_get_lines(0, 0, -1, 0))
  end)

  -- Perform exhaustive tests of basic functionality
  local mapmodes = { 'n', 'v', 'x', 's', 'o', '!', 'i', 'l', 'c', 't', '', 'ia', 'ca', '!a' }
  for _, mapmode in ipairs(mapmodes) do
    it('can set/unset normal mappings in mapmode ' .. mapmode, function()
      api.nvim_set_keymap(mapmode, 'lhs', 'rhs', {})
      eq(generate_mapargs(mapmode, 'lhs', 'rhs'), get_mapargs(mapmode, 'lhs'))

      -- some mapmodes (like 'o') will prevent other mapmodes (like '!') from
      -- taking effect, so unmap after each mapping
      api.nvim_del_keymap(mapmode, 'lhs')
      eq({}, get_mapargs(mapmode, 'lhs'))
    end)
  end

  for _, mapmode in ipairs(mapmodes) do
    it('can set/unset noremap mappings using mapmode ' .. mapmode, function()
      api.nvim_set_keymap(mapmode, 'lhs', 'rhs', { noremap = true })
      eq(generate_mapargs(mapmode, 'lhs', 'rhs', { noremap = true }), get_mapargs(mapmode, 'lhs'))

      api.nvim_del_keymap(mapmode, 'lhs')
      eq({}, get_mapargs(mapmode, 'lhs'))
    end)
  end

  -- Test map-arguments, using optnames from above
  -- remove some map arguments that are harder to test, or were already tested
  optnames = { 'nowait', 'silent', 'expr', 'noremap' }
  for _, mapmode in ipairs(mapmodes) do
    -- Test with single mappings
    for _, maparg in ipairs(optnames) do
      it('can set/unset ' .. mapmode .. '-mappings with maparg: ' .. maparg, function()
        api.nvim_set_keymap(mapmode, 'lhs', 'rhs', { [maparg] = true })
        eq(
          generate_mapargs(mapmode, 'lhs', 'rhs', { [maparg] = true }),
          get_mapargs(mapmode, 'lhs')
        )
        api.nvim_del_keymap(mapmode, 'lhs')
        eq({}, get_mapargs(mapmode, 'lhs'))
      end)
      it(
        'can set/unset '
          .. mapmode
          .. '-mode mappings with maparg '
          .. maparg
          .. ', whose value is false',
        function()
          api.nvim_set_keymap(mapmode, 'lhs', 'rhs', { [maparg] = false })
          eq(generate_mapargs(mapmode, 'lhs', 'rhs'), get_mapargs(mapmode, 'lhs'))
          api.nvim_del_keymap(mapmode, 'lhs')
          eq({}, get_mapargs(mapmode, 'lhs'))
        end
      )
    end

    -- Test with triplets of mappings, one of which is false
    for i = 1, (#optnames - 2) do
      local opt1, opt2, opt3 = optnames[i], optnames[i + 1], optnames[i + 2]
      it(
        'can set/unset '
          .. mapmode
          .. '-mode mappings with mapargs '
          .. opt1
          .. ', '
          .. opt2
          .. ', '
          .. opt3,
        function()
          local opts = { [opt1] = true, [opt2] = false, [opt3] = true }
          api.nvim_set_keymap(mapmode, 'lhs', 'rhs', opts)
          eq(generate_mapargs(mapmode, 'lhs', 'rhs', opts), get_mapargs(mapmode, 'lhs'))
          api.nvim_del_keymap(mapmode, 'lhs')
          eq({}, get_mapargs(mapmode, 'lhs'))
        end
      )
    end
  end

  it('can make lua mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.api.nvim_set_keymap('n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])
  end)

  it(':map command shows lua mapping correctly', function()
    exec_lua [[
      vim.api.nvim_set_keymap('n', 'asdf', '', {
        callback = function() print('jkl;') end,
      })
    ]]
    matches(
      '^\nn  asdf          <Lua %d+>',
      exec_lua [[return vim.api.nvim_exec2(':nmap asdf', { output = true }).output]]
    )
  end)

  it('mapcheck() returns lua mapping correctly', function()
    exec_lua [[
      vim.api.nvim_set_keymap('n', 'asdf', '', {
        callback = function() print('jkl;') end,
      })
    ]]
    matches('^<Lua %d+>', fn.mapcheck('asdf', 'n'))
  end)

  it('maparg() and maplist() return lua mapping correctly', function()
    eq(
      0,
      exec_lua([[
      GlobalCount = 0
      vim.api.nvim_set_keymap('n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]])
    )

    matches('^<Lua %d+>', fn.maparg('asdf', 'n'))

    local mapargs = fn.maparg('asdf', 'n', false, true)
    mapargs.callback = nil
    mapargs.lhsraw = nil
    mapargs.lhsrawalt = nil
    eq(generate_mapargs('n', 'asdf', nil, { sid = sid_lua }), mapargs)

    eq(
      1,
      exec_lua([[
      vim.fn.maparg('asdf', 'n', false, true).callback()
      return GlobalCount
    ]])
    )

    exec([[
      call maparg('asdf', 'n', v:false, v:true).callback()
    ]])
    eq(2, exec_lua([[return GlobalCount]]))

    api.nvim_eval([[
      maplist()->filter({_, m -> m.lhs == 'asdf'})->foreach({_, m -> m.callback()})
    ]])
    eq(3, exec_lua([[return GlobalCount]]))
  end)

  it('can make lua expr mappings replacing keycodes', function()
    exec_lua [[
      vim.api.nvim_set_keymap('n', 'aa', '', {
        callback = function() return '<Insert>π<C-V><M-π>foo<lt><Esc>' end,
        expr = true,
        replace_keycodes = true,
      })
    ]]

    feed('aa')

    eq({ 'π<M-π>foo<' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('can make lua expr mappings without replacing keycodes', function()
    exec_lua [[
      vim.api.nvim_set_keymap('i', 'aa', '', {
        callback = function() return '<space>' end,
        expr = true,
      })
    ]]

    feed('iaa<esc>')

    eq({ '<space>' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('lua expr mapping returning nil is equivalent to returning an empty string', function()
    exec_lua [[
      vim.api.nvim_set_keymap('i', 'aa', '', {
        callback = function() return nil end,
        expr = true,
      })
    ]]

    feed('iaa<esc>')

    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('does not reset pum in lua mapping', function()
    eq(
      0,
      exec_lua [[
      VisibleCount = 0
      vim.api.nvim_set_keymap('i', '<F2>', '', {
        callback = function() VisibleCount = VisibleCount + vim.fn.pumvisible() end,
      })
      return VisibleCount
    ]]
    )
    feed('i<C-X><C-V><F2><F2><esc>')
    eq(2, exec_lua [[return VisibleCount]])
  end)

  it('redo of lua mappings in op-pending mode work', function()
    eq(
      0,
      exec_lua [[
      OpCount = 0
      vim.api.nvim_set_keymap('o', '<F2>', '', {
        callback = function() OpCount = OpCount + 1 end,
      })
      return OpCount
    ]]
    )
    feed('d<F2>')
    eq(1, exec_lua [[return OpCount]])
    feed('.')
    eq(2, exec_lua [[return OpCount]])
  end)

  it('can overwrite lua mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.api.nvim_set_keymap('n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[
      vim.api.nvim_set_keymap('n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount - 1 end,
      })
    ]]

    feed('asdf\n')

    eq(0, exec_lua [[return GlobalCount]])
  end)

  it('can unmap lua mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.api.nvim_set_keymap('n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[vim.api.nvim_del_keymap('n', 'asdf' )]]

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])
    eq('\nNo mapping found', n.exec_capture('nmap asdf'))
  end)

  it('no double-free when unmapping simplifiable lua mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.api.nvim_set_keymap('n', '<C-I>', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]]
    )

    feed('<C-I>\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[vim.api.nvim_del_keymap('n', '<C-I>')]]

    feed('<C-I>\n')

    eq(1, exec_lua [[return GlobalCount]])
    eq('\nNo mapping found', n.exec_capture('nmap <C-I>'))
  end)

  it('can set descriptions on mappings', function()
    api.nvim_set_keymap('n', 'lhs', 'rhs', { desc = 'map description' })
    eq(generate_mapargs('n', 'lhs', 'rhs', { desc = 'map description' }), get_mapargs('n', 'lhs'))
    eq('\nn  lhs           rhs\n                 map description', n.exec_capture('nmap lhs'))
  end)

  it('can define !-mode abbreviations with lua callbacks', function()
    exec_lua [[
      GlobalCount = 0
      vim.api.nvim_set_keymap('!a', 'foo', '', {
        expr = true,
        callback = function()
          GlobalCount = GlobalCount + 1
          return tostring(GlobalCount)
        end,
      })
    ]]

    feed 'iThe foo and the bar and the foo again<esc>'
    eq('The 1 and the bar and the 2 again', api.nvim_get_current_line())

    feed ':let x = "The foo is the one"<cr>'
    eq('The 3 is the one', api.nvim_eval 'x')
  end)

  it('can define insert mode abbreviations with lua callbacks', function()
    exec_lua [[
      GlobalCount = 0
      vim.api.nvim_set_keymap('ia', 'foo', '', {
        expr = true,
        callback = function()
          GlobalCount = GlobalCount + 1
          return tostring(GlobalCount)
        end,
      })
    ]]

    feed 'iThe foo and the bar and the foo again<esc>'
    eq('The 1 and the bar and the 2 again', api.nvim_get_current_line())

    feed ':let x = "The foo is the one"<cr>'
    eq('The foo is the one', api.nvim_eval 'x')
  end)

  it('can define cmdline mode abbreviations with lua callbacks', function()
    exec_lua [[
      GlobalCount = 0
      vim.api.nvim_set_keymap('ca', 'foo', '', {
        expr = true,
        callback = function()
          GlobalCount = GlobalCount + 1
          return tostring(GlobalCount)
        end,
      })
    ]]

    feed 'iThe foo and the bar and the foo again<esc>'
    eq('The foo and the bar and the foo again', api.nvim_get_current_line())

    feed ':let x = "The foo is the one"<cr>'
    eq('The 1 is the one', api.nvim_eval 'x')
  end)
end)

describe('nvim_buf_set_keymap, nvim_buf_del_keymap', function()
  before_each(clear)

  -- nvim_set_keymap is implemented as a wrapped call to nvim_buf_set_keymap,
  -- so its tests also effectively test nvim_buf_set_keymap

  -- here, we mainly test for buffer specificity and other special cases

  -- switch to the given buffer, abandoning any changes in the current buffer
  local function switch_to_buf(bufnr)
    command(bufnr .. 'buffer!')
  end

  -- `set hidden`, then create two buffers and return their bufnr's
  -- If start_from_first is truthy, the first buffer will be open when
  -- the function returns; if falsy, the second buffer will be open.
  local function make_two_buffers(start_from_first)
    command('set hidden')

    local first_buf = api.nvim_call_function('bufnr', { '%' })
    command('new')
    local second_buf = api.nvim_call_function('bufnr', { '%' })
    neq(second_buf, first_buf) -- sanity check

    if start_from_first then
      switch_to_buf(first_buf)
    end

    return first_buf, second_buf
  end

  it('rejects negative bufnr values', function()
    eq(
      'Wrong type for argument 1 when calling nvim_buf_set_keymap, expecting Buffer',
      pcall_err(api.nvim_buf_set_keymap, -1, '', 'lhs', 'rhs', {})
    )
  end)

  it('can set mappings active in the current buffer but not others', function()
    local first, second = make_two_buffers(true)

    api.nvim_buf_set_keymap(0, '', 'lhs', 'irhs<Esc>', {})
    command('normal lhs')
    eq({ 'rhs' }, api.nvim_buf_get_lines(0, 0, 1, 1))

    -- mapping should have no effect in new buffer
    switch_to_buf(second)
    command('normal lhs')
    eq({ '' }, api.nvim_buf_get_lines(0, 0, 1, 1))

    -- mapping should remain active in old buffer
    switch_to_buf(first)
    command('normal ^lhs')
    eq({ 'rhsrhs' }, api.nvim_buf_get_lines(0, 0, 1, 1))
  end)

  it('can set local mappings in buffer other than current', function()
    local first = make_two_buffers(false)
    api.nvim_buf_set_keymap(first, '', 'lhs', 'irhs<Esc>', {})

    -- shouldn't do anything
    command('normal lhs')
    eq({ '' }, api.nvim_buf_get_lines(0, 0, 1, 1))

    -- should take effect
    switch_to_buf(first)
    command('normal lhs')
    eq({ 'rhs' }, api.nvim_buf_get_lines(0, 0, 1, 1))
  end)

  it('can disable mappings made in another buffer, inside that buffer', function()
    local first = make_two_buffers(false)
    api.nvim_buf_set_keymap(first, '', 'lhs', 'irhs<Esc>', {})
    api.nvim_buf_del_keymap(first, '', 'lhs')
    switch_to_buf(first)

    -- shouldn't do anything
    command('normal lhs')
    eq({ '' }, api.nvim_buf_get_lines(0, 0, 1, 1))
  end)

  it("can't disable mappings given wrong buffer handle", function()
    local first, second = make_two_buffers(false)
    api.nvim_buf_set_keymap(first, '', 'lhs', 'irhs<Esc>', {})
    eq('E31: No such mapping', pcall_err(api.nvim_buf_del_keymap, second, '', 'lhs'))

    -- should still work
    switch_to_buf(first)
    command('normal lhs')
    eq({ 'rhs' }, api.nvim_buf_get_lines(0, 0, 1, 1))
  end)

  it('does not crash when setting mapping in a non-existing buffer #13541', function()
    pcall_err(api.nvim_buf_set_keymap, 100, '', 'lsh', 'irhs<Esc>', {})
    n.assert_alive()
  end)

  it('can make lua mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.api.nvim_buf_set_keymap(0, 'n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])
  end)

  it('can make lua expr mappings replacing keycodes', function()
    exec_lua [[
      vim.api.nvim_buf_set_keymap(0, 'n', 'aa', '', {
        callback = function() return '<Insert>π<C-V><M-π>foo<lt><Esc>' end,
        expr = true,
        replace_keycodes = true,
      })
    ]]

    feed('aa')

    eq({ 'π<M-π>foo<' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('can make lua expr mappings without replacing keycodes', function()
    exec_lua [[
      vim.api.nvim_buf_set_keymap(0, 'i', 'aa', '', {
        callback = function() return '<space>' end,
        expr = true,
      })
    ]]

    feed('iaa<esc>')

    eq({ '<space>' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('can overwrite lua mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.api.nvim_buf_set_keymap(0, 'n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[
      vim.api.nvim_buf_set_keymap(0, 'n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount - 1 end,
      })
    ]]

    feed('asdf\n')

    eq(0, exec_lua [[return GlobalCount]])
  end)

  it('can unmap lua mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.api.nvim_buf_set_keymap(0, 'n', 'asdf', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[vim.api.nvim_buf_del_keymap(0, 'n', 'asdf' )]]

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])
    eq('\nNo mapping found', n.exec_capture('nmap asdf'))
  end)

  it('no double-free when unmapping simplifiable lua mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.api.nvim_buf_set_keymap(0, 'n', '<C-I>', '', {
        callback = function() GlobalCount = GlobalCount + 1 end,
      })
      return GlobalCount
    ]]
    )

    feed('<C-I>\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[vim.api.nvim_buf_del_keymap(0, 'n', '<C-I>')]]

    feed('<C-I>\n')

    eq(1, exec_lua [[return GlobalCount]])
    eq('\nNo mapping found', n.exec_capture('nmap <C-I>'))
  end)

  it('does not overwrite in <unique> mappings', function()
    api.nvim_buf_set_keymap(0, 'i', 'lhs', 'rhs', {})
    eq(
      'E227: Mapping already exists for lhs',
      pcall_err(api.nvim_buf_set_keymap, 0, 'i', 'lhs', 'rhs', { unique = true })
    )

    api.nvim_buf_set_keymap(0, 'ia', 'lhs2', 'rhs2', {})
    eq(
      'E226: Abbreviation already exists for lhs2',
      pcall_err(api.nvim_buf_set_keymap, 0, 'ia', 'lhs2', 'rhs2', { unique = true })
    )

    api.nvim_set_keymap('n', 'lhs', 'rhs', {})
    eq(
      'E225: Global mapping already exists for lhs',
      pcall_err(api.nvim_buf_set_keymap, 0, 'n', 'lhs', 'rhs', { unique = true })
    )
  end)
end)
