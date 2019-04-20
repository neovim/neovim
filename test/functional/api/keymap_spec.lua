local helpers = require('test.functional.helpers')(after_each)
local global_helpers = require('test.helpers')

local clear = helpers.clear
local command = helpers.command
local curbufmeths = helpers.curbufmeths
local eq = helpers.eq
local expect_err = helpers.expect_err
local funcs = helpers.funcs
local meths = helpers.meths
local source = helpers.source

local shallowcopy = global_helpers.shallowcopy

describe('nvim_get_keymap', function()
  before_each(clear)

  -- Basic mapping and table to be used to describe results
  local foo_bar_string = 'nnoremap foo bar'
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

  it('returns empty list when no map', function()
    eq({}, meths.get_keymap('n'))
  end)

  it('returns list of all applicable mappings', function()
    command(foo_bar_string)
    -- Only one mapping available
    -- Should be the same as the dictionary we supplied earlier
    -- and the dictionary you would get from maparg
    -- since this is a global map, and not script local
    eq({foo_bar_map_table}, meths.get_keymap('n'))
    eq({funcs.maparg('foo', 'n', false, true)},
      meths.get_keymap('n')
    )

    -- Add another mapping
    command('nnoremap foo_longer bar_longer')
    local foolong_bar_map_table = shallowcopy(foo_bar_map_table)
    foolong_bar_map_table['lhs'] = 'foo_longer'
    foolong_bar_map_table['rhs'] = 'bar_longer'

    eq({foolong_bar_map_table, foo_bar_map_table},
      meths.get_keymap('n')
    )

    -- Remove a mapping
    command('unmap foo_longer')
    eq({foo_bar_map_table},
      meths.get_keymap('n')
    )
  end)

  it('works for other modes', function()
    -- Add two mappings, one in insert and one normal
    -- We'll only check the insert mode one
    command('nnoremap not_going to_check')

    command('inoremap foo bar')
    -- The table will be the same except for the mode
    local insert_table = shallowcopy(foo_bar_map_table)
    insert_table['mode'] = 'i'

    eq({insert_table}, meths.get_keymap('i'))
  end)

  it('considers scope', function()
    -- change the map slightly
    command('nnoremap foo_longer bar_longer')
    local foolong_bar_map_table = shallowcopy(foo_bar_map_table)
    foolong_bar_map_table['lhs'] = 'foo_longer'
    foolong_bar_map_table['rhs'] = 'bar_longer'

    local buffer_table = shallowcopy(foo_bar_map_table)
    buffer_table['buffer'] = 1

    command('nnoremap <buffer> foo bar')

    -- The buffer mapping should not show up
    eq({foolong_bar_map_table}, meths.get_keymap('n'))
    eq({buffer_table}, curbufmeths.get_keymap('n'))
  end)

  it('considers scope for overlapping maps', function()
    command('nnoremap foo bar')

    local buffer_table = shallowcopy(foo_bar_map_table)
    buffer_table['buffer'] = 1

    command('nnoremap <buffer> foo bar')

    eq({foo_bar_map_table}, meths.get_keymap('n'))
    eq({buffer_table}, curbufmeths.get_keymap('n'))
  end)

  it('can retrieve mapping for different buffers', function()
    local original_buffer = curbufmeths.get_number()
    -- Place something in each of the buffers to make sure they stick around
    -- and set hidden so we can leave them
    command('set hidden')
    command('new')
    command('normal! ihello 2')
    command('new')
    command('normal! ihello 3')

    local final_buffer = curbufmeths.get_number()

    command('nnoremap <buffer> foo bar')
    -- Final buffer will have buffer mappings
    local buffer_table = shallowcopy(foo_bar_map_table)
    buffer_table['buffer'] = final_buffer
    eq({buffer_table}, meths.buf_get_keymap(final_buffer, 'n'))
    eq({buffer_table}, meths.buf_get_keymap(0, 'n'))

    command('buffer ' .. original_buffer)
    eq(original_buffer, curbufmeths.get_number())
    -- Original buffer won't have any mappings
    eq({}, meths.get_keymap('n'))
    eq({}, curbufmeths.get_keymap('n'))
    eq({buffer_table}, meths.buf_get_keymap(final_buffer, 'n'))
  end)

  -- Test toggle switches for basic options
  -- @param  option  The key represented in the `maparg()` result dict
  local function global_and_buffer_test(map,
                                        option,
                                        option_token,
                                        global_on_result,
                                        buffer_on_result,
                                        global_off_result,
                                        buffer_off_result,
                                        new_windows)

    local function make_new_windows(number_of_windows)
      if new_windows == nil then
        return nil
      end

      for _=1,number_of_windows do
        command('new')
      end
    end

    local mode = string.sub(map, 1,1)
    -- Don't run this for the <buffer> mapping, since it doesn't make sense
    if option_token ~= '<buffer>' then
      it(string.format( 'returns %d for the key "%s" when %s is used globally with %s (%s)',
          global_on_result, option, option_token, map, mode), function()
        make_new_windows(new_windows)
        command(map .. ' ' .. option_token .. ' foo bar')
        local result = meths.get_keymap(mode)[1][option]
        eq(global_on_result, result)
      end)
    end

    it(string.format('returns %d for the key "%s" when %s is used for buffers with %s (%s)',
        buffer_on_result, option, option_token, map, mode), function()
      make_new_windows(new_windows)
      command(map .. ' <buffer> ' .. option_token .. ' foo bar')
      local result = curbufmeths.get_keymap(mode)[1][option]
      eq(buffer_on_result, result)
    end)

    -- Don't run these for the <buffer> mapping, since it doesn't make sense
    if option_token ~= '<buffer>' then
      it(string.format('returns %d for the key "%s" when %s is not used globally with %s (%s)',
          global_off_result, option, option_token, map, mode), function()
        make_new_windows(new_windows)
        command(map .. ' baz bat')
        local result = meths.get_keymap(mode)[1][option]
        eq(global_off_result, result)
      end)

      it(string.format('returns %d for the key "%s" when %s is not used for buffers with %s (%s)',
          buffer_off_result, option, option_token, map, mode), function()
        make_new_windows(new_windows)
        command(map .. ' <buffer> foo bar')

        local result = curbufmeths.get_keymap(mode)[1][option]
        eq(buffer_off_result, result)
      end)
    end
  end

  -- Standard modes and returns the same values in the dictionary as maparg()
  local mode_list = {'nnoremap', 'nmap', 'imap', 'inoremap', 'cnoremap'}
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
    local sid_result = meths.get_keymap('n')[1]['sid']
    eq(1, sid_result)
    eq('testing', meths.call_function('<SNR>' .. sid_result .. '_maparg_test_function', {}))
  end)

  it('returns script numbers for buffer maps', function()
    source([[
      function! s:maparg_test_function() abort
        return 'testing'
      endfunction

      nnoremap <buffer> fizz :call <SID>maparg_test_function()<CR>
    ]])
    local sid_result = curbufmeths.get_keymap('n')[1]['sid']
    eq(1, sid_result)
    eq('testing', meths.call_function('<SNR>' .. sid_result .. '_maparg_test_function', {}))
  end)

  it('works with <F12> and others', function()
    command('nnoremap <F12> :let g:maparg_test_var = 1<CR>')
    eq('<F12>', meths.get_keymap('n')[1]['lhs'])
    eq(':let g:maparg_test_var = 1<CR>', meths.get_keymap('n')[1]['rhs'])
  end)

  it('works correctly despite various &cpo settings', function()
    local cpo_table = {
      silent=0,
      expr=0,
      sid=0,
      buffer=0,
      nowait=0,
      noremap=1,
    }
    local function cpomap(lhs, rhs, mode)
      local ret = shallowcopy(cpo_table)
      ret.lhs = lhs
      ret.rhs = rhs
      ret.mode = mode
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
      eq({cpomap('\\<C-C><C-C><lt>C-c>\\', '\\<C-D><C-D><lt>C-d>\\', 'n'),
          cpomap('\\<C-A><C-A><lt>C-a>\\', '\\<C-B><C-B><lt>C-b>\\', 'n')},
         meths.get_keymap('n'))
      eq({cpomap('\\<C-C><C-C><lt>C-c>\\', '\\<C-D><C-D><lt>C-d>\\', 'x'),
          cpomap('\\<C-A><C-A><lt>C-a>\\', '\\<C-B><C-B><lt>C-b>\\', 'x')},
         meths.get_keymap('x'))
      eq({cpomap('<lt>C-c><C-C><lt>C-c> ', '<lt>C-d><C-D><lt>C-d>', 's'),
          cpomap('<lt>C-a><C-A><lt>C-a> ', '<lt>C-b><C-B><lt>C-b>', 's')},
         meths.get_keymap('s'))
      eq({cpomap('<lt>C-c><C-C><lt>C-c> ', '<lt>C-d><C-D><lt>C-d>', 'o'),
          cpomap('<lt>C-a><C-A><lt>C-a> ', '<lt>C-b><C-B><lt>C-b>', 'o')},
         meths.get_keymap('o'))
    end
  end)

  it('always uses space for space and bar for bar', function()
    local space_table = {
      lhs='|   |',
      rhs='|    |',
      mode='n',
      silent=0,
      expr=0,
      sid=0,
      buffer=0,
      nowait=0,
      noremap=1,
    }
    command('nnoremap \\|<Char-0x20><Char-32><Space><Bar> \\|<Char-0x20><Char-32><Space> <Bar>')
    eq({space_table}, meths.get_keymap('n'))
  end)
end)

describe('nvim_set_keymap', function()
  before_each(clear)

  -- Test error handling
  it('throws errors when given empty lhs or rhs', function()
    expect_err('Must give nonempty LHS!',
               meths.set_keymap, '', '', '', 'rhs', {})
    expect_err('Must give an RHS when setting keymap!',
               meths.set_keymap, '', '', 'lhs', '', {})
    expect_err('Must give nonempty LHS!',
               meths.set_keymap, '', '', '', '', {})
  end)

  it('throws errors when unmapping and given nonempty rhs', function()
    expect_err('RHS must be empty when unmapping! Gave: rhs',
               meths.set_keymap, '', 'u', 'lhs', 'rhs', {})
    expect_err('RHS must be empty when unmapping! Gave:  ',
               meths.set_keymap, '', 'u', 'lhs', ' ', {})
  end)

  it('throws errors when given too-long mode shortnames', function()
    expect_err('Given shortname is too long: map',
               meths.set_keymap, 'map', '', 'lhs', 'rhs', {})

    expect_err('Given shortname is too long: vmap',
               meths.set_keymap, 'vmap', '', 'lhs', 'rhs', {})

    expect_err('Given shortname is too long: xnoremap',
               meths.set_keymap, 'xnoremap', '', 'lhs', 'rhs', {})
  end)

  it('throws errors when given unrecognized mode shortnames', function()
    expect_err('Unrecognized mode shortname: ?',
               meths.set_keymap, '?', '', 'lhs', 'rhs', {})

    expect_err('Unrecognized mode shortname: y',
               meths.set_keymap, 'y', '', 'lhs', 'rhs', {})

    expect_err('Unrecognized mode shortname: p',
               meths.set_keymap, 'p', '', 'lhs', 'rhs', {})
  end)

  it('throws errors when optnames are almost right', function()
    expect_err('Unrecognized option in nvim_set_keymap: bufferr',
               meths.set_keymap, 'n', '', 'lhs', 'rhs', {bufferr = true})
    expect_err('Unrecognized option in nvim_set_keymap: sidd',
               meths.set_keymap, 'n', '', 'lhs', 'rhs', {sidd = false})
    expect_err('Unrecognized option in nvim_set_keymap: nowaiT',
               meths.set_keymap, 'n', '', 'lhs', 'rhs', {nowaiT = false})
  end)

  local optnames = {'buffer', 'nowait', 'silent', 'script', 'expr', 'unique'}
  for _, opt in ipairs(optnames) do
    -- note: need '%' to escape hyphens, which have special meaning in lua
    it('throws an error when given non-boolean value for '..opt, function()
      local opts = {}
      opts[opt] = 2
      expect_err('Gave non%-boolean value for an opt: '..opt,
                 meths.set_keymap, 'n', '', 'lhs', 'rhs', opts)
    end)
  end

  -- generate_expected is truthy when we want to generate an expected output for
  -- maparg(); mapargs() won't take '!' as an input, though it will return '!'
  -- in its output if getting a mapping set with |:map!|
  local function normalize_mapmode(mode, generate_expected)
    if not generate_expected and mode == '!' then
      -- can't retrieve mapmode-ic mappings with '!', but can with 'i' or 'c'.
      mode = 'i'
    elseif mode == '' or mode == 'm' then
      mode = ' '
    end
    return mode
  end

  -- Generate a mapargs dict, for comparison against the mapping that was
  -- actually set
  local function generate_mapargs(mode, noremap, lhs, rhs, silent, nowait,
                                  expr, sid, buffer)
    local to_return = {}
    to_return.mode = normalize_mapmode(mode, true)
    to_return.noremap = noremap
    to_return.lhs = lhs
    to_return.rhs = rhs
    to_return.silent = not silent and 0 or 1
    to_return.nowait = not nowait and 0 or 1
    to_return.expr = not expr and 0 or 1
    to_return.sid = not sid and 0 or sid
    to_return.buffer = not buffer and 0 or buffer

    -- mode 't' doesn't print when calling maparg
    if mode == 't' then
      to_return.mode = ''
    end

    return to_return
  end

  -- Retrieve a mapargs dict from neovim, if one exists
  local function get_mapargs(mode, lhs)
    return funcs.maparg(lhs, normalize_mapmode(mode), false, true)
  end

  -- Perform tests of basic functionality
  it('can set ordinary mappings', function()
    eq(0, meths.set_keymap('n', '', 'lhs', 'rhs', {}))
    eq(generate_mapargs('n', 0, 'lhs', 'rhs'), get_mapargs('n', 'lhs'))

    eq(0, meths.set_keymap('v', '', 'lhs', 'rhs', {}))
    eq(generate_mapargs('v', 0, 'lhs', 'rhs'), get_mapargs('v', 'lhs'))
  end)

  it('can set noremap mappings', function()
    eq(0, meths.set_keymap('x', 'n', 'lhs', 'rhs', {}))
    eq(generate_mapargs('x', 1, 'lhs', 'rhs'), get_mapargs('x', 'lhs'))

    eq(0, meths.set_keymap('t', 'n', 'lhs', 'rhs', {}))
    eq(generate_mapargs('t', 1, 'lhs', 'rhs'), get_mapargs('t', 'lhs'))
  end)

  it('can unmap mappings', function()
    meths.set_keymap('v', '', 'lhs', 'rhs', {})
    eq(0, meths.set_keymap('v', 'u', 'lhs', '', {}))
    eq({}, get_mapargs('v', 'lhs'))

    meths.set_keymap('t', 'n', 'lhs', 'rhs', {})
    eq(0, meths.set_keymap('t', 'u', 'lhs', '', {}))
    eq({}, get_mapargs('t', 'lhs'))
  end)

  -- Test some edge cases
  it('accepts "!" and " " and "" as synonyms for mapmode-nvo', function()
    local nvo_shortnames = {'', ' ', '!'}
    for _, name in ipairs(nvo_shortnames) do
      meths.set_keymap(name, '', 'lhs', 'rhs', {})
      eq(0, meths.set_keymap(name, 'u', 'lhs', '', {}))
      eq({}, get_mapargs(name, 'lhs'))
    end
  end)

  it('can set mappings with special characters', function()
    eq(0, meths.set_keymap('!', '', '<C-u>', 'rhs', {}))
    eq(generate_mapargs('!', 0, '<C-U>', 'rhs'), get_mapargs('!', '<C-u>'))
  end)

  it('throws appropriate error messages when setting <unique> maps', function()
    meths.set_keymap('l', '', 'lhs', 'rhs', {})
    expect_err('E227: mapping already exists for lhs',
               meths.set_keymap, 'l', '', 'lhs', 'rhs', {unique = true})
    -- different mapmode, no error should be thrown
    eq(0, meths.set_keymap('t', '', 'lhs', 'rhs', {}))
  end)

  -- Perform exhaustive tests of basic functionality
  local mapmodes = {'n', 'v', 'x', 's', 'o', '!', 'i', 'l', 'c', 't', ' ', ''}
  for _, mapmode in ipairs(mapmodes) do
    it('can set/unset normal mappings in mapmode '..mapmode, function()
      eq(0, meths.set_keymap(mapmode, '', 'lhs', 'rhs', {}))
      eq(generate_mapargs(mapmode, 0, 'lhs', 'rhs'),
         get_mapargs(mapmode, 'lhs'))

      -- some mapmodes (like 'o') will prevent other mapmodes (like '!') from
      -- taking effect, so unmap after each mapping
      eq(0, meths.set_keymap(mapmode, 'u', 'lhs', '', {}))
      eq({}, get_mapargs(mapmode, 'lhs'))
    end)
  end

  for _, mapmode in ipairs(mapmodes) do
    it('can set/unset noremap mappings using mapmode '..mapmode, function()
      eq(0, meths.set_keymap(mapmode, 'n', 'lhs', 'rhs', {}))
      eq(generate_mapargs(mapmode, 1, 'lhs', 'rhs'),
         get_mapargs(mapmode, 'lhs'))

      eq(0, meths.set_keymap(mapmode, 'u', 'lhs', '', {}))
      eq({}, get_mapargs(mapmode, 'lhs'))
    end)
  end

end)
