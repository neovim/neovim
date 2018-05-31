local helpers = require('test.functional.helpers')(after_each)
local global_helpers = require('test.helpers')

local clear = helpers.clear
local command = helpers.command
local curbufmeths = helpers.curbufmeths
local eq = helpers.eq
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
