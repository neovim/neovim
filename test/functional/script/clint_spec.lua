local t = require('test.testutil')
local n = require('test.functional.testnvim')()

describe('clint.lua', function()
  local clint_path = 'src/clint.lua'
  local test_file = 'test/functional/fixtures/clint_test.c'

  local function run_clint(filepath)
    local proc = n.spawn_wait('-l', clint_path, filepath)
    local output = proc:output()
    local lines = vim.split(output, '\n', { plain = true, trimempty = true })
    return lines
  end

  it('a linter lints', function()
    local output_lines = run_clint(test_file)
    local expected = {
      'test/functional/fixtures/clint_test.c:11:  Uncommented text after #endif is non-standard.  Use a comment.  [build/endif_comment] [5]',
      'test/functional/fixtures/clint_test.c:18:  "%q" in format strings is deprecated.  Use "%" PRId64 instead.  [runtime/printf_format] [3]',
      'test/functional/fixtures/clint_test.c:22:  Storage class (static, extern, typedef, etc) should be first.  [build/storage_class] [5]',
      'test/functional/fixtures/clint_test.c:25:  Use true instead of TRUE.  [readability/bool] [4]',
      'test/functional/fixtures/clint_test.c:26:  Use false instead of FALSE.  [readability/bool] [4]',
      'test/functional/fixtures/clint_test.c:27:  Use kNone from TriState instead of MAYBE.  [readability/bool] [4]',
      'test/functional/fixtures/clint_test.c:31:  Use true instead of TRUE.  [readability/bool] [4]',
      'test/functional/fixtures/clint_test.c:32:  Use false instead of FALSE.  [readability/bool] [4]',
      'test/functional/fixtures/clint_test.c:35:  Use kNone from TriState instead of MAYBE.  [readability/bool] [4]',
      'test/functional/fixtures/clint_test.c:41:  /*-style comment found, it should be replaced with //-style.  /*-style comments are only allowed inside macros.  Note that you should not use /*-style comments to document macros itself, use doxygen-style comments for this.  [readability/old_style_comment] [5]',
      'test/functional/fixtures/clint_test.c:54:  Do not use preincrement in statements, use postincrement instead  [readability/increment] [5]',
      'test/functional/fixtures/clint_test.c:55:  Do not use preincrement in statements, including for(;; action)  [readability/increment] [4]',
      "test/functional/fixtures/clint_test.c:63:  Do not use variable-length arrays.  Use an appropriately named ('k' followed by CamelCase) compile-time constant for the size.  [runtime/arrays] [1]",
      'test/functional/fixtures/clint_test.c:69:  Use int16_t/int64_t/etc, rather than the C type short  [runtime/int] [4]',
      'test/functional/fixtures/clint_test.c:70:  Use int16_t/int64_t/etc, rather than the C type long long  [runtime/int] [4]',
      'test/functional/fixtures/clint_test.c:77:  Did you mean "memset(buf, 0, sizeof(buf))"?  [runtime/memset] [4]',
      'test/functional/fixtures/clint_test.c:84:  Use snprintf instead of sprintf.  [runtime/printf] [5]',
      'test/functional/fixtures/clint_test.c:90:  %N$ formats are unconventional.  Try rewriting to avoid them.  [runtime/printf_format] [2]',
      'test/functional/fixtures/clint_test.c:97:  Use os_ctime_r(...) instead of ctime(...). If it is missing, consider implementing it; see os_localtime_r for an example.  [runtime/threadsafe_fn] [2]',
      'test/functional/fixtures/clint_test.c:98:  Use os_asctime_r(...) instead of asctime(...). If it is missing, consider implementing it; see os_localtime_r for an example.  [runtime/threadsafe_fn] [2]',
      'test/functional/fixtures/clint_test.c:98:  Use os_localtime_r(...) instead of localtime(...). If it is missing, consider implementing it; see os_localtime_r for an example.  [runtime/threadsafe_fn] [2]',
      'test/functional/fixtures/clint_test.c:124:  /*-style comment found, it should be replaced with //-style.  /*-style comments are only allowed inside macros.  Note that you should not use /*-style comments to document macros itself, use doxygen-style comments for this.  [readability/old_style_comment] [5]',
      'test/functional/fixtures/clint_test.c:133:  Use xstrlcpy, xmemcpyz or snprintf instead of strcpy  [runtime/printf] [4]',
      'test/functional/fixtures/clint_test.c:134:  Use xstrlcpy, xmemcpyz or snprintf instead of strncpy (unless this is from Vim)  [runtime/printf] [4]',
      'test/functional/fixtures/clint_test.c:137:  Use xmalloc(...) instead of malloc(...).  [runtime/memory_fn] [2]',
      'test/functional/fixtures/clint_test.c:138:  Use xfree(...) instead of free(...).  [runtime/memory_fn] [2]',
      'test/functional/fixtures/clint_test.c:141:  Use os_getenv(...) instead of getenv(...).  [runtime/os_fn] [2]',
      'test/functional/fixtures/clint_test.c:142:  Use os_setenv(...) instead of setenv(...).  [runtime/os_fn] [2]',
      'Total errors found: 28',
    }
    t.eq(expected, output_lines)
  end)
end)
