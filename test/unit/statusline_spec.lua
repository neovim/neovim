local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local to_cstr = t.to_cstr
local get_str = t.ffi.string
local eq = t.eq
local NULL = t.NULL

local buffer = t.cimport('./src/nvim/buffer.h')
local globals = t.cimport('./src/nvim/globals.h')
local stl = t.cimport('./src/nvim/statusline.h')
local grid = t.cimport('./src/nvim/grid.h')

describe('build_stl_str_hl', function()
  local buffer_byte_size = 120
  local STL_INITIAL_ITEMS = 20
  local output_buffer = ''

  -- This function builds the statusline
  --
  -- @param arg Optional arguments are:
  --    .pat The statusline format string
  --    .fillchar The fill character used in the statusline
  --    .maximum_cell_count The number of cells available in the statusline
  local function build_stl_str_hl(arg)
    output_buffer = to_cstr(string.rep(' ', buffer_byte_size))

    local pat = arg.pat or ''
    local fillchar = arg.fillchar or ' '
    local maximum_cell_count = arg.maximum_cell_count or buffer_byte_size
    if type(fillchar) == type('') then
      fillchar = grid.schar_from_str(fillchar)
    end

    return stl.build_stl_str_hl(
      globals.curwin,
      output_buffer,
      buffer_byte_size,
      to_cstr(pat),
      -1,
      0,
      fillchar,
      maximum_cell_count,
      NULL,
      NULL,
      NULL,
      NULL
    )
  end

  -- Use this function to simplify testing the comparison between
  --  the format string and the resulting statusline.
  --
  -- @param description The description of what the test should be doing
  -- @param statusline_cell_count The number of cells available in the statusline
  -- @param input_stl The format string for the statusline
  -- @param expected_stl The expected result string for the statusline
  --
  -- @param arg Options can be placed in an optional dict as the last parameter
  --    .expected_cell_count The expected number of cells build_stl_str_hl will return
  --    .expected_byte_length The expected byte length of the string (defaults to byte length of expected_stl)
  --    .file_name The name of the file to be tested (useful in %f type tests)
  --    .fillchar The character that will be used to fill any 'extra' space in the stl
  local function statusline_test(description, statusline_cell_count, input_stl, expected_stl, arg)
    -- arg is the optional parameter
    -- so we either fill in option with arg or an empty dict
    local option = arg or {}

    local fillchar = option.fillchar or ' '
    local expected_cell_count = option.expected_cell_count or statusline_cell_count
    local expected_byte_length = option.expected_byte_length or #expected_stl

    itp(description, function()
      if option.file_name then
        buffer.setfname(globals.curbuf, to_cstr(option.file_name), NULL, 1)
      else
        buffer.setfname(globals.curbuf, nil, NULL, 1)
      end

      local result_cell_count = build_stl_str_hl {
        pat = input_stl,
        maximum_cell_count = statusline_cell_count,
        fillchar = fillchar,
      }

      local output_str = get_str(output_buffer, expected_byte_length + 1)
      eq(expected_stl, output_str:sub(1, -2))
      eq('\0', output_str:sub(-1), 'output string must be NUL-terminated')
      eq(expected_cell_count, result_cell_count)
    end)
  end

  -- expression testing
  statusline_test('expands expression', 2, '%!expand(20+1)', '21')
  statusline_test('expands broken expression to itself', 11, '%!expand(20+1', 'expand(20+1')

  -- file name testing
  statusline_test('prints no file name', 10, '%f', '[No Name]', { expected_cell_count = 9 })
  statusline_test(
    'prints the relative file name',
    30,
    '%f',
    'test/unit/buffer_spec.lua',
    { file_name = 'test/unit/buffer_spec.lua', expected_cell_count = 25 }
  )
  statusline_test(
    'prints the full file name',
    40,
    '%F',
    '/test/unit/buffer_spec.lua',
    { file_name = '/test/unit/buffer_spec.lua', expected_cell_count = 26 }
  )

  -- fillchar testing
  statusline_test('handles `!` as a fillchar', 10, 'abcde%=', 'abcde!!!!!', { fillchar = '!' })
  statusline_test('handles `~` as a fillchar', 10, '%=abcde', '~~~~~abcde', { fillchar = '~' })
  statusline_test(
    'puts fillchar `!` in between text',
    10,
    'abc%=def',
    'abc!!!!def',
    { fillchar = '!' }
  )
  statusline_test(
    'puts fillchar `~` in between text',
    10,
    'abc%=def',
    'abc~~~~def',
    { fillchar = '~' }
  )
  statusline_test(
    'puts fillchar `━` in between text',
    10,
    'abc%=def',
    'abc━━━━def',
    { fillchar = '━' }
  )
  statusline_test('handles zero-fillchar as a space', 10, 'abcde%=', 'abcde     ', { fillchar = 0 })
  statusline_test(
    'prints the tail file name',
    80,
    '%t',
    'buffer_spec.lua',
    { file_name = 'test/unit/buffer_spec.lua', expected_cell_count = 15 }
  )

  -- standard text testing
  statusline_test(
    'copies plain text',
    80,
    'this is a test',
    'this is a test',
    { expected_cell_count = 14 }
  )

  -- line number testing
  statusline_test('prints the buffer number', 80, '%n', '1', { expected_cell_count = 1 })
  statusline_test(
    'prints the current line number in the buffer',
    80,
    '%l',
    '0',
    { expected_cell_count = 1 }
  )
  statusline_test(
    'prints the number of lines in the buffer',
    80,
    '%L',
    '1',
    { expected_cell_count = 1 }
  )

  -- truncation testing
  statusline_test(
    'truncates when standard text pattern is too long',
    10,
    '0123456789abcde',
    '<6789abcde'
  )
  statusline_test('truncates when using =', 10, 'abcdef%=ghijkl', 'abcdef<jkl')
  statusline_test('truncates centered text when using ==', 10, 'abcde%=gone%=fghij', 'abcde<ghij')
  statusline_test('respects the `<` marker', 10, 'abc%<defghijkl', 'abc<ghijkl')
  statusline_test('truncates at `<` with one `=`, test 1', 10, 'abc%<def%=ghijklmno', 'abc<jklmno')
  statusline_test('truncates at `<` with one `=`, test 2', 10, 'abcdef%=ghijkl%<mno', 'abcdefghi>')
  statusline_test('truncates at `<` with one `=`, test 3', 10, 'abc%<def%=ghij', 'abcdefghij')
  statusline_test('truncates at `<` with one `=`, test 4', 10, 'abc%<def%=ghijk', 'abc<fghijk')
  statusline_test('truncates at `<` with many `=`, test 5', 10, 'ab%<cdef%=g%=h%=ijk', 'ab<efghijk')
  statusline_test('truncates at the first `<`', 10, 'abc%<def%<ghijklm', 'abc<hijklm')
  statusline_test('ignores trailing %', 3, 'abc%', 'abc')

  -- alignment testing with fillchar
  local function statusline_test_align(
    description,
    statusline_cell_count,
    input_stl,
    expected_stl,
    arg
  )
    arg = arg or {}
    statusline_test(
      description .. ' without fillchar',
      statusline_cell_count,
      input_stl,
      expected_stl:gsub('%~', ' '),
      arg
    )
    arg.fillchar = '!'
    statusline_test(
      description .. ' with fillchar `!`',
      statusline_cell_count,
      input_stl,
      expected_stl:gsub('%~', '!'),
      arg
    )
    arg.fillchar = '━'
    statusline_test(
      description .. ' with fillchar `━`',
      statusline_cell_count,
      input_stl,
      expected_stl:gsub('%~', '━'),
      arg
    )
  end

  statusline_test_align('right aligns when using =', 20, 'neo%=vim', 'neo~~~~~~~~~~~~~~vim')
  statusline_test_align(
    'centers text when using %=text%=',
    20,
    'abc%=neovim%=def',
    'abc~~~~neovim~~~~def'
  )
  statusline_test_align(
    'handles uneven spacing in the buffer when using %=text%=',
    20,
    'abc%=neo_vim%=def',
    'abc~~~neo_vim~~~~def'
  )
  statusline_test_align(
    'produces approximately equal spaces even with non-equal sides when using =',
    20,
    'foobar%=test%=baz',
    'foobar~~~test~~~~baz'
  )
  statusline_test_align(
    'produces approximately equal spaces even with longer right side when using =',
    20,
    'a%=test%=longtext',
    'a~~~test~~~~longtext'
  )
  statusline_test_align(
    'handles an empty left side when using ==',
    20,
    '%=test%=baz',
    '~~~~~~test~~~~~~~baz'
  )
  statusline_test_align(
    'handles an empty right side when using ==',
    20,
    'foobar%=test%=',
    'foobar~~~~~test~~~~~'
  )
  statusline_test_align('handles consecutive empty ==', 20, '%=%=test%=', '~~~~~~~~~~test~~~~~~')
  statusline_test_align('handles an = alone', 20, '%=', '~~~~~~~~~~~~~~~~~~~~')
  statusline_test_align(
    'right aligns text when it is alone with =',
    20,
    '%=foo',
    '~~~~~~~~~~~~~~~~~foo'
  )
  statusline_test_align(
    'left aligns text when it is alone with =',
    20,
    'foo%=',
    'foo~~~~~~~~~~~~~~~~~'
  )

  statusline_test_align(
    'approximately centers text when using %=text%=',
    21,
    'abc%=neovim%=def',
    'abc~~~~neovim~~~~~def'
  )
  statusline_test_align(
    'completely fills the buffer when using %=text%=',
    21,
    'abc%=neo_vim%=def',
    'abc~~~~neo_vim~~~~def'
  )
  statusline_test_align(
    'produces equal spacing even with non-equal sides when using =',
    21,
    'foobar%=test%=baz',
    'foobar~~~~test~~~~baz'
  )
  statusline_test_align(
    'produces equal spacing even with longer right side when using =',
    21,
    'a%=test%=longtext',
    'a~~~~test~~~~longtext'
  )
  statusline_test_align(
    'handles an empty left side when using ==',
    21,
    '%=test%=baz',
    '~~~~~~~test~~~~~~~baz'
  )
  statusline_test_align(
    'handles an empty right side when using ==',
    21,
    'foobar%=test%=',
    'foobar~~~~~test~~~~~~'
  )

  statusline_test_align(
    'quadrants the text when using 3 %=',
    40,
    'abcd%=n%=eovim%=ef',
    'abcd~~~~~~~~~n~~~~~~~~~eovim~~~~~~~~~~ef'
  )
  statusline_test_align(
    'works well with %t',
    40,
    '%t%=right_aligned',
    'buffer_spec.lua~~~~~~~~~~~~right_aligned',
    { file_name = 'test/unit/buffer_spec.lua' }
  )
  statusline_test_align(
    'works well with %t and regular text',
    40,
    'l%=m_l %t m_r%=r',
    'l~~~~~~~m_l buffer_spec.lua m_r~~~~~~~~r',
    { file_name = 'test/unit/buffer_spec.lua' }
  )
  statusline_test_align(
    'works well with %=, %t, %L, and %l',
    40,
    '%t %= %L %= %l',
    'buffer_spec.lua ~~~~~~~~~ 1 ~~~~~~~~~~ 0',
    { file_name = 'test/unit/buffer_spec.lua' }
  )

  statusline_test_align(
    'quadrants the text when using 3 %=',
    41,
    'abcd%=n%=eovim%=ef',
    'abcd~~~~~~~~~n~~~~~~~~~eovim~~~~~~~~~~~ef'
  )
  statusline_test_align(
    'works well with %t',
    41,
    '%t%=right_aligned',
    'buffer_spec.lua~~~~~~~~~~~~~right_aligned',
    { file_name = 'test/unit/buffer_spec.lua' }
  )
  statusline_test_align(
    'works well with %t and regular text',
    41,
    'l%=m_l %t m_r%=r',
    'l~~~~~~~~m_l buffer_spec.lua m_r~~~~~~~~r',
    { file_name = 'test/unit/buffer_spec.lua' }
  )
  statusline_test_align(
    'works well with %=, %t, %L, and %l',
    41,
    '%t %= %L %= %l',
    'buffer_spec.lua ~~~~~~~~~~ 1 ~~~~~~~~~~ 0',
    { file_name = 'test/unit/buffer_spec.lua' }
  )

  statusline_test_align(
    'works with 10 %=',
    50,
    'aaaa%=b%=c%=d%=e%=fg%=hi%=jk%=lmnop%=qrstuv%=wxyz',
    'aaaa~~b~~c~~d~~e~~fg~~hi~~jk~~lmnop~~qrstuv~~~wxyz'
  )

  -- item group testing

  statusline_test_align(
    'right aligns in right aligned groups',
    30,
    '%5(%l%), %5.(%l%), %5.5(%l%), %5.10(%l%)',
    '~~~~0, ~~~~0, ~~~~0, ~~~~0',
    { expected_cell_count = 26 }
  )

  statusline_test_align(
    'left aligns in left aligned groups',
    30,
    '%-5(%l%), %-5.(%l%), %-5.5(%l%), %-5.10(%l%)',
    '0~~~~, 0~~~~, 0~~~~, 0~~~~',
    { expected_cell_count = 26 }
  )

  statusline_test_align(
    'expands at %= in item groups according to minwid',
    60,
    '%10(neo%=vim%), %10.(neo%=vim%), %10.10(neo%=vim%), %10.20(neo%=vim%)',
    'neo~~~~vim, neo~~~~vim, neo~~~~vim, neo~~~~vim',
    { expected_cell_count = 46 }
  )

  statusline_test_align(
    'expands at %= in item groups with normal items',
    60,
    '%10(%L%=%l,%c%), %10(%=%L%=%l,%c%=%), %10(x%=%L%=%l,%c%=y%)',
    '1~~~~~~0,0, ~~1~~0,0~~, x~1~0,0~~y',
    { expected_cell_count = 34 }
  )

  statusline_test_align(
    'expands at %= in nested item groups and top-level',
    29,
    '%21(foo%=%7(x%=y%=z%)%=bar%)%=%5(a%=b%=c%)',
    'foo~~~~x~~y~~z~~~~bar~~~a~b~c'
  )

  statusline_test(
    'ignores unexpanded %= in item groups when expanding at top-level',
    20,
    '%4(%L%=neo%)vim',
    '1neovim',
    { expected_cell_count = 7 }
  )

  statusline_test(
    'ignores truncated %= in item groups when expanding at top-level',
    20,
    '%10.10(%<hidden%=%f%)TEST',
    '<_spec.luaTEST',
    { file_name = 'test/unit/buffer_spec.lua', expected_cell_count = 14 }
  )

  statusline_test(
    'ignores %= in hidden item groups when expanding at top-level',
    20,
    '%(hidden%=%h%)TEST',
    'TEST',
    { expected_cell_count = 4 }
  )

  statusline_test(
    'truncates item groups according to maxwid',
    30,
    '%.5(1234567%), %2.5(1234567%), %5.5(1234567%)',
    '<4567, <4567, <4567',
    { expected_cell_count = 19 }
  )

  statusline_test(
    'truncates at first normal item in item groups',
    30,
    '%.15(path: %f%)',
    'path: <spec.lua',
    { file_name = 'test/unit/buffer_spec.lua', expected_cell_count = 15 }
  )

  statusline_test(
    'truncates at %< in item groups',
    60,
    '%.15(%<path: %f%), %.15(path: %<%f%), %.15(path: %f%<%)',
    '<uffer_spec.lua, path: <spec.lua, path: test/uni>',
    { file_name = 'test/unit/buffer_spec.lua', expected_cell_count = 49 }
  )

  statusline_test(
    'truncates at %< in nested item groups and top-level',
    40,
    '%.24(trim both ends: %<%.17(%f%<%)%), path: %<%f',
    'trim both ends: <buffer>, path: <pec.lua',
    { file_name = 'test/unit/buffer_spec.lua' }
  )

  statusline_test(
    'ignores unused %< in item groups when truncating at top-level',
    25,
    '%.6(%L%< test%) file: %<%f',
    '1 test file: <er_spec.lua',
    { file_name = 'test/unit/buffer_spec.lua' }
  )

  statusline_test(
    'ignores second %< in item groups when truncating at top-level',
    32,
    '%.15(file: %<%f%<%), file: %<%f',
    'file: <spec.lua, file: <spec.lua',
    { file_name = 'test/unit/buffer_spec.lua' }
  )

  statusline_test(
    'ignores %< in hidden item groups when truncating at top-level',
    15,
    '%.15(hidden%<%)%f%<',
    'test/unit/buff>',
    { file_name = 'test/unit/buffer_spec.lua' }
  )

  -- stl item testing
  local tabline = ''
  for i = 1, 1000 do
    tabline = tabline .. (i % 2 == 0 and '%#TabLineSel#' or '%#TabLineFill#') .. tostring(i % 2)
  end
  statusline_test('handles a large amount of any items', 20, tabline, '<1010101010101010101') -- Should not show any error
  statusline_test(
    'handles a larger amount of = than stl initial item',
    20,
    ('%='):rep(STL_INITIAL_ITEMS * 5),
    '                    '
  ) -- Should not show any error
  statusline_test(
    'handles many extra characters',
    20,
    'a' .. ('a'):rep(STL_INITIAL_ITEMS * 5),
    '<aaaaaaaaaaaaaaaaaaa'
  ) -- Does not show any error
  statusline_test(
    'handles many extra characters and flags',
    20,
    'a' .. ('%=a'):rep(STL_INITIAL_ITEMS * 2),
    'a<aaaaaaaaaaaaaaaaaa'
  ) -- Should not show any error

  -- multi-cell character testing
  statusline_test(
    'returns reduced width after truncating top-level from the left at multicell character',
    5,
    '12🙂345',
    '<345',
    { expected_cell_count = 4 }
  )
  statusline_test(
    'returns reduced width after truncating top-level from the right at multicell character',
    5,
    '123🙂45%<',
    '123>',
    { expected_cell_count = 4 }
  )
  statusline_test_align(
    'compensates with fillchar to reach minwid after truncating item group at multicell character',
    100,
    '%.5(12🙂345%), %4.5(12🙂345%), %5.5(12🙂345%), %-5.5(12🙂345%), %50.5(12🙂345%), %.5(123🙂%L%<%), %4.5(123🙂%L%<%), %5.5(123🙂%L%<%), %-5.5(123🙂%L%<%), %50.5(123🙂%L%<%)',
    '<345, <345, <345~, <345~, <345~, 123>, 123>, 123>~, 123>~, 123>~',
    { expected_cell_count = 64 }
  )

  -- multi-byte testing
  statusline_test('handles multibyte characters', 10, 'Ĉ%=x', 'Ĉ        x')
  statusline_test(
    'handles multibyte characters and different fillchars',
    10,
    'Ą%=mid%=end',
    'Ą@mid@@end',
    { fillchar = '@' }
  )

  -- escaping % testing
  statusline_test('handles escape of %', 4, 'abc%%', 'abc%')
  statusline_test('case where escaped % does not fit', 3, 'abc%%abcabc', '<bc')
  statusline_test('escaped % is first', 1, '%%', '%')
end)
