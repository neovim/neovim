
local helpers = require("test.unit.helpers")(after_each)
local itp = helpers.gen_itp(it)

local to_cstr = helpers.to_cstr
local get_str = helpers.ffi.string
local eq      = helpers.eq
local NULL    = helpers.NULL

local globals = helpers.cimport("./src/nvim/globals.h")
local buffer = helpers.cimport("./src/nvim/buffer.h")

describe('buffer functions', function()

  local buflist_new = function(file, flags)
    local c_file = to_cstr(file)
    return buffer.buflist_new(c_file, c_file, 1, flags)
  end

  local close_buffer = function(win, buf, action, abort_if_last)
    return buffer.close_buffer(win, buf, action, abort_if_last)
  end

  local path1 = 'test_file_path'
  local path2 = 'file_path_test'
  local path3 = 'path_test_file'

  before_each(function()
    -- create the files
    io.open(path1, 'w').close()
    io.open(path2, 'w').close()
    io.open(path3, 'w').close()
  end)

  after_each(function()
    os.remove(path1)
    os.remove(path2)
    os.remove(path3)
  end)

  describe('buf_valid', function()

    itp('should view NULL as an invalid buffer', function()
      eq(false, buffer.buf_valid(NULL))
    end)

    itp('should view an open buffer as valid', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      eq(true, buffer.buf_valid(buf))
    end)

    itp('should view a closed and hidden buffer as valid', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      close_buffer(NULL, buf, 0, 0)

      eq(true, buffer.buf_valid(buf))
    end)

    itp('should view a closed and unloaded buffer as valid', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      close_buffer(NULL, buf, buffer.DOBUF_UNLOAD, 0)

      eq(true, buffer.buf_valid(buf))
    end)

    itp('should view a closed and wiped buffer as invalid', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      close_buffer(NULL, buf, buffer.DOBUF_WIPE, 0)

      eq(false, buffer.buf_valid(buf))
    end)
  end)


  describe('buflist_findpat', function()

    local ALLOW_UNLISTED = 1
    local ONLY_LISTED    = 0

    local buflist_findpat = function(pat, allow_unlisted)
      return buffer.buflist_findpat(to_cstr(pat), NULL, allow_unlisted, 0, 0)
    end

    itp('should find exact matches', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      eq(buf.handle, buflist_findpat(path1, ONLY_LISTED))

      close_buffer(NULL, buf, buffer.DOBUF_WIPE, 0)
    end)

    itp('should prefer to match the start of a file path', function()
      local buf1 = buflist_new(path1, buffer.BLN_LISTED)
      local buf2 = buflist_new(path2, buffer.BLN_LISTED)
      local buf3 = buflist_new(path3, buffer.BLN_LISTED)

      eq(buf1.handle, buflist_findpat("test", ONLY_LISTED))
      eq(buf2.handle, buflist_findpat("file", ONLY_LISTED))
      eq(buf3.handle, buflist_findpat("path", ONLY_LISTED))

      close_buffer(NULL, buf1, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf2, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf3, buffer.DOBUF_WIPE, 0)
    end)

    itp('should prefer to match the end of a file over the middle', function()
      --{ Given: Two buffers, where 'test' appears in both
      --  And: 'test' appears at the end of buf3 but in the middle of buf2
      local buf2 = buflist_new(path2, buffer.BLN_LISTED)
      local buf3 = buflist_new(path3, buffer.BLN_LISTED)

      -- Then: buf2 is the buffer that is found
      eq(buf2.handle, buflist_findpat("test", ONLY_LISTED))
      --}

      --{ When: We close buf2
      close_buffer(NULL, buf2, buffer.DOBUF_WIPE, 0)

      -- And: Open buf1, which has 'file' in the middle of its name
      local buf1 = buflist_new(path1, buffer.BLN_LISTED)

      -- Then: buf3 is found since 'file' appears at the end of the name
      eq(buf3.handle, buflist_findpat("file", ONLY_LISTED))
      --}

      close_buffer(NULL, buf1, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf3, buffer.DOBUF_WIPE, 0)
    end)

    itp('should match a unique fragment of a file path', function()
      local buf1 = buflist_new(path1, buffer.BLN_LISTED)
      local buf2 = buflist_new(path2, buffer.BLN_LISTED)
      local buf3 = buflist_new(path3, buffer.BLN_LISTED)

      eq(buf3.handle, buflist_findpat("_test_", ONLY_LISTED))

      close_buffer(NULL, buf1, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf2, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf3, buffer.DOBUF_WIPE, 0)
    end)

    itp('should include / ignore unlisted buffers based on the flag.', function()
      --{ Given: A buffer
      local buf3 = buflist_new(path3, buffer.BLN_LISTED)

      -- Then: We should find the buffer when it is given a unique pattern
      eq(buf3.handle, buflist_findpat("_test_", ONLY_LISTED))
      --}

      --{ When: We unlist the buffer
      close_buffer(NULL, buf3, buffer.DOBUF_DEL, 0)

      -- Then: It should not find the buffer when searching only listed buffers
      eq(-1, buflist_findpat("_test_", ONLY_LISTED))

      -- And: It should find the buffer when including unlisted buffers
      eq(buf3.handle, buflist_findpat("_test_", ALLOW_UNLISTED))
      --}

      --{ When: We wipe the buffer
      close_buffer(NULL, buf3, buffer.DOBUF_WIPE, 0)

      -- Then: It should not find the buffer at all
      eq(-1, buflist_findpat("_test_", ONLY_LISTED))
      eq(-1, buflist_findpat("_test_", ALLOW_UNLISTED))
      --}
    end)

    itp('should prefer listed buffers to unlisted buffers.', function()
      --{ Given: Two buffers that match a pattern
      local buf1 = buflist_new(path1, buffer.BLN_LISTED)
      local buf2 = buflist_new(path2, buffer.BLN_LISTED)

      -- Then: The first buffer is preferred when both are listed
      eq(buf1.handle, buflist_findpat("test", ONLY_LISTED))
      --}

      --{ When: The first buffer is unlisted
      close_buffer(NULL, buf1, buffer.DOBUF_DEL, 0)

      -- Then: The second buffer is preferred because
      --       unlisted buffers are not allowed
      eq(buf2.handle, buflist_findpat("test", ONLY_LISTED))
      --}

      --{ When: We allow unlisted buffers
      -- Then: The second buffer is still preferred
      --       because listed buffers are preferred to unlisted
      eq(buf2.handle, buflist_findpat("test", ALLOW_UNLISTED))
      --}

      --{ When: We unlist the second buffer
      close_buffer(NULL, buf2, buffer.DOBUF_DEL, 0)

      -- Then: The first buffer is preferred again
      --       because buf1 matches better which takes precedence
      --       when both buffers have the same listing status.
      eq(buf1.handle, buflist_findpat("test", ALLOW_UNLISTED))

      -- And: Neither buffer is returned when ignoring unlisted
      eq(-1, buflist_findpat("test", ONLY_LISTED))
      --}

      close_buffer(NULL, buf1, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf2, buffer.DOBUF_WIPE, 0)
    end)
  end)

  describe('build_stl_str_hl', function()
    local buffer_byte_size = 100
    local STL_MAX_ITEM = 80
    local output_buffer = ''

    -- This function builds the statusline
    --
    -- @param arg Optional arguments are:
    --    .pat The statusline format string
    --    .fillchar The fill character used in the statusline
    --    .maximum_cell_count The number of cells available in the statusline
    local function build_stl_str_hl(arg)
      output_buffer = to_cstr(string.rep(" ", buffer_byte_size))

      local pat = arg.pat or ''
      local fillchar = arg.fillchar or (' '):byte()
      local maximum_cell_count = arg.maximum_cell_count or buffer_byte_size

      return buffer.build_stl_str_hl(globals.curwin,
                                     output_buffer,
                                     buffer_byte_size,
                                     to_cstr(pat),
                                     false,
                                     fillchar,
                                     maximum_cell_count,
                                     NULL,
                                     NULL)
    end

    -- Use this function to simplify testing the comparison between
    --  the format string and the resulting statusline.
    --
    -- @param description The description of what the test should be doing
    -- @param statusline_cell_count The number of cells available in the statusline
    -- @param input_stl The format string for the statusline
    -- @param expected_stl The expected result string for the statusline
    --
    -- @param arg Options can be placed in an optional dictionary as the last parameter
    --    .expected_cell_count The expected number of cells build_stl_str_hl will return
    --    .expected_byte_length The expected byte length of the string
    --    .file_name The name of the file to be tested (useful in %f type tests)
    --    .fillchar The character that will be used to fill any 'extra' space in the stl
    local function statusline_test (description,
                                    statusline_cell_count,
                                    input_stl,
                                    expected_stl,
                                    arg)

      -- arg is the optional parameter
      -- so we either fill in option with arg or an empty dictionary
      local option = arg or {}

      local fillchar = option.fillchar or (' '):byte()
      local expected_cell_count = option.expected_cell_count or statusline_cell_count
      local expected_byte_length = option.expected_byte_length or expected_cell_count

      itp(description, function()
        if option.file_name then
          buffer.setfname(globals.curbuf, to_cstr(option.file_name), NULL, 1)
        else
          buffer.setfname(globals.curbuf, nil, NULL, 1)
        end

        local result_cell_count = build_stl_str_hl{pat=input_stl,
                                                   maximum_cell_count=statusline_cell_count,
                                                   fillchar=fillchar}

        eq(expected_stl, get_str(output_buffer, expected_byte_length))
        eq(expected_cell_count, result_cell_count)
      end)
    end

    -- expression testing
    statusline_test('Should expand expression', 2,
     '%!expand(20+1)',       '21')
    statusline_test('Should expand broken expression to itself', 11,
     '%!expand(20+1',       'expand(20+1')

    -- file name testing
    statusline_test('should print no file name', 10,
      '%f',                  '[No Name]',
      {expected_cell_count=9})
    statusline_test('should print the relative file name', 30,
      '%f',                  'test/unit/buffer_spec.lua',
      {file_name='test/unit/buffer_spec.lua', expected_cell_count=25})
    statusline_test('should print the full file name', 40,
      '%F',                  '/test/unit/buffer_spec.lua',
      {file_name='/test/unit/buffer_spec.lua', expected_cell_count=26})

    -- fillchar testing
    statusline_test('should handle `!` as a fillchar', 10,
      'abcde%=',             'abcde!!!!!',
      {fillchar=('!'):byte()})
    statusline_test('should handle `~` as a fillchar', 10,
      '%=abcde',             '~~~~~abcde',
      {fillchar=('~'):byte()})
    statusline_test('should put fillchar `!` in between text', 10,
      'abc%=def',            'abc!!!!def',
      {fillchar=('!'):byte()})
    statusline_test('should put fillchar `~` in between text', 10,
      'abc%=def',            'abc~~~~def',
      {fillchar=('~'):byte()})
    statusline_test('should handle zero-fillchar as a space', 10,
      'abcde%=',             'abcde     ',
      {fillchar=0})
    statusline_test('should handle multibyte-fillchar as a dash', 10,
      'abcde%=',             'abcde-----',
      {fillchar=0x80})
    statusline_test('should print the tail file name', 80,
      '%t',                  'buffer_spec.lua',
      {file_name='test/unit/buffer_spec.lua', expected_cell_count=15})

    -- standard text testing
    statusline_test('should copy plain text', 80,
      'this is a test',      'this is a test',
      {expected_cell_count=14})

    -- line number testing
    statusline_test('should print the buffer number', 80,
      '%n',                  '1',
      {expected_cell_count=1})
    statusline_test('should print the current line number in the buffer', 80,
      '%l',                  '0',
      {expected_cell_count=1})
    statusline_test('should print the number of lines in the buffer', 80,
      '%L',                  '1',
      {expected_cell_count=1})

    -- truncation testing
    statusline_test('should truncate when standard text pattern is too long', 10,
      '0123456789abcde',     '<6789abcde')
    statusline_test('should truncate when using =', 10,
      'abcdef%=ghijkl',      'abcdef<jkl')
    statusline_test('should truncate centered text when using ==', 10,
      'abcde%=gone%=fghij',  'abcde<ghij')
    statusline_test('should respect the `<` marker', 10,
      'abc%<defghijkl',      'abc<ghijkl')
    statusline_test('should truncate at `<` with one `=`, test 1', 10,
      'abc%<def%=ghijklmno', 'abc<jklmno')
    statusline_test('should truncate at `<` with one `=`, test 2', 10,
      'abcdef%=ghijkl%<mno', 'abcdefghi>')
    statusline_test('should truncate at `<` with one `=`, test 3', 10,
      'abc%<def%=ghijklmno', 'abc<jklmno')
    statusline_test('should truncate at `<` with one `=`, test 4', 10,
      'abc%<def%=ghij',     'abcdefghij')
    statusline_test('should truncate at `<` with one `=`, test 4', 10,
      'abc%<def%=ghijk',     'abc<fghijk')

    statusline_test('should truncate at `<` with many `=`, test 4', 10,
      'ab%<cdef%=g%=h%=ijk', 'ab<efghijk')

    statusline_test('should truncate at the first `<`', 10,
      'abc%<def%<ghijklm',   'abc<hijklm')

    statusline_test('should ignore trailing %', 3, 'abc%', 'abc')

    -- alignment testing
    statusline_test('should right align when using =', 20,
      'neo%=vim',            'neo              vim')
    statusline_test('should, when possible, center text when using %=text%=', 20,
      'abc%=neovim%=def',    'abc    neovim    def')
    statusline_test('should handle uneven spacing in the buffer when using %=text%=', 20,
      'abc%=neo_vim%=def',   'abc   neo_vim    def')
    statusline_test('should have equal spaces even with non-equal sides when using =', 20,
      'foobar%=test%=baz',   'foobar   test    baz')
    statusline_test('should have equal spaces even with longer right side when using =', 20,
      'a%=test%=longtext',   'a   test    longtext')
    statusline_test('should handle an empty left side when using ==', 20,
      '%=test%=baz',         '      test       baz')
    statusline_test('should handle an empty right side when using ==', 20,
      'foobar%=test%=',      'foobar     test     ')
    statusline_test('should handle consecutive empty ==', 20,
      '%=%=test%=',          '          test      ')
    statusline_test('should handle an = alone', 20,
      '%=',                  '                    ')
    statusline_test('should right align text when it is alone with =', 20,
      '%=foo',               '                 foo')
    statusline_test('should left align text when it is alone with =', 20,
      'foo%=',               'foo                 ')

    statusline_test('should approximately center text when using %=text%=', 21,
      'abc%=neovim%=def',    'abc    neovim     def')
    statusline_test('should completely fill the buffer when using %=text%=', 21,
      'abc%=neo_vim%=def',   'abc    neo_vim    def')
    statusline_test('should have equal spaces even with non-equal sides when using =', 21,
      'foobar%=test%=baz',   'foobar    test    baz')
    statusline_test('should have equal spaces even with longer right side when using =', 21,
      'a%=test%=longtext',   'a    test    longtext')
    statusline_test('should handle an empty left side when using ==', 21,
      '%=test%=baz',         '       test       baz')
    statusline_test('should handle an empty right side when using ==', 21,
      'foobar%=test%=',      'foobar     test      ')

    statusline_test('should quadrant the text when using 3 %=', 40,
      'abcd%=n%=eovim%=ef',  'abcd         n         eovim          ef')
    statusline_test('should work well with %t', 40,
      '%t%=right_aligned',   'buffer_spec.lua            right_aligned',
      {file_name='test/unit/buffer_spec.lua'})
    statusline_test('should work well with %t and regular text', 40,
      'l%=m_l %t m_r%=r',    'l       m_l buffer_spec.lua m_r        r',
      {file_name='test/unit/buffer_spec.lua'})
    statusline_test('should work well with %=, %t, %L, and %l', 40,
      '%t %= %L %= %l',      'buffer_spec.lua           1            0',
      {file_name='test/unit/buffer_spec.lua'})

    statusline_test('should quadrant the text when using 3 %=', 41,
      'abcd%=n%=eovim%=ef',  'abcd         n         eovim           ef')
    statusline_test('should work well with %t', 41,
      '%t%=right_aligned',   'buffer_spec.lua             right_aligned',
      {file_name='test/unit/buffer_spec.lua'})
    statusline_test('should work well with %t and regular text', 41,
      'l%=m_l %t m_r%=r',    'l        m_l buffer_spec.lua m_r        r',
      {file_name='test/unit/buffer_spec.lua'})
    statusline_test('should work well with %=, %t, %L, and %l', 41,
      '%t %= %L %= %l',      'buffer_spec.lua            1            0',
      {file_name='test/unit/buffer_spec.lua'})

    statusline_test('should work with 10 %=', 50,
      'aaaa%=b%=c%=d%=e%=fg%=hi%=jk%=lmnop%=qrstuv%=wxyz',
      'aaaa  b  c  d  e  fg  hi  jk  lmnop  qrstuv   wxyz')

    -- maximum stl item testing
    statusline_test('should handle a much larger amount of = than buffer locations', 20,
      ('%='):rep(STL_MAX_ITEM - 1),
      '                    ') -- Should be fine, because within limit
    statusline_test('should handle a much larger amount of = than stl max item', 20,
      ('%='):rep(STL_MAX_ITEM + 1),
      '                E541') -- Should show the VIM error
    statusline_test('should handle many extra characters', 20,
      'a' .. ('a'):rep(STL_MAX_ITEM * 4),
      '<aaaaaaaaaaaaaaaaaaa') -- Does not show the error because there are no items
    statusline_test('should handle almost maximum of characters and flags', 20,
      'a' .. ('%=a'):rep(STL_MAX_ITEM - 1),
      'a<aaaaaaaaaaaaaaaaaa') -- Should not show the VIM error
    statusline_test('should handle many extra characters and flags', 20,
      'a' .. ('%=a'):rep(STL_MAX_ITEM),
      'a<aaaaaaaaaaaaa E541') -- Should show the VIM error
    statusline_test('should handle many extra characters and flags', 20,
      'a' .. ('%=a'):rep(STL_MAX_ITEM * 2),
      'a<aaaaaaaaaaaaa E541') -- Should show the VIM error
    statusline_test('should handle many extra characters and flags with truncation', 20,
      'aaa%<' .. ('%=a'):rep(STL_MAX_ITEM),
      'aaa<aaaaaaaaaaa E541') -- Should show the VIM error
    statusline_test('should handle many characters and flags before and after truncation', 20,
      'a%=a%=a%<' .. ('%=a'):rep(STL_MAX_ITEM),
      'aaa<aaaaaaaaaaa E541') -- Should show the VIM error


    -- multi-byte testing
    statusline_test('should handle multibyte characters', 10,
      'Ĉ%=x',                'Ĉ        x',
      {expected_byte_length=11})
    statusline_test('should handle multibyte characters and different fillchars', 10,
      'Ą%=mid%=end',         'Ą@mid@@end',
      {fillchar=('@'):byte(), expected_byte_length=11})

    -- escaping % testing
    statusline_test('should handle escape of %', 4, 'abc%%', 'abc%')
    statusline_test('case where escaped % does not fit', 3, 'abc%%abcabc', '<bc')
    statusline_test('escaped % is first', 1, '%%', '%')

  end)
end)
