local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq

local grammar = require('src/nvim/generators/c_grammar').grammar

describe('C grammar', function()
  --- @param text string
  --- @param exp table<string,string>
  local function test(text, exp)
    exp.attrs = exp.attrs or {}
    exp.attrs1 = exp.attrs1 or {}
    it(string.format('can parse %q', text), function()
      eq({ exp }, grammar:match(text))
    end)
  end

  test('char foo(int hello);', {
    'proto',
    name = 'foo',
    parameters = {
      { 'int', 'hello' },
    },
    return_type = 'char',
  })

  test('char bar(void *value);', {
    'proto',
    name = 'bar',
    parameters = {
      { 'void *', 'value' },
    },
    return_type = 'char',
  })

  test(
    [[int32_t utf_ptr2CharInfo_impl(uint8_t const *p, uintptr_t const len)
  FUNC_ATTR_PURE FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT;]],
    {
      'proto',
      attrs1 = {
        nonnull_all = true,
        pure = true,
        warn_unused_result = true,
      },
      name = 'utf_ptr2CharInfo_impl',
      parameters = {
        { 'uint8_t const *', 'p' },
        { 'uintptr_t const', 'len' },
      },
      return_type = 'int32_t',
    }
  )

  test('bool semsg(const char *const fmt, ...);', {
    'proto',
    name = 'semsg',
    parameters = {
      { 'const char *const', 'fmt' },
      { '...' },
    },
    return_type = 'bool',
  })

  test(
    [[
  void *xrealloc(void *ptr, size_t size)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALLOC_SIZE(2) FUNC_ATTR_NONNULL_RET;]],
    {
      'proto',
      name = 'xrealloc',
      return_type = 'void *',
      parameters = {
        { 'void *', 'ptr' },
        { 'size_t', 'size' },
      },
      attrs1 = {
        alloc_size = 2,
        nonnull_ret = true,
        warn_unused_result = true,
      },
    }
  )
end)
