-- Test for mappings and abbreviations

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('mapping', function()
  setup(clear)

  it('is working', function()
    insert([[
      test starts here:
      ]])

    -- Abbreviations with р (0x80) should work.
    execute('inoreab чкпр   vim')
    feed('GAчкпр <esc>')

    -- langmap should not get remapped in insert mode.
    execute('inoremap { FAIL_ilangmap')
    execute('set langmap=+{ langnoremap')
    feed('o+<esc>')

    -- Insert mode expr mapping with langmap.
    execute('inoremap <expr> { "FAIL_iexplangmap"')
    feed('o+<esc>')

    -- langmap should not get remapped in cmdline mode.
    execute('cnoremap { FAIL_clangmap')
    feed('o+<esc>')
    execute('cunmap {')

    -- cmdline mode expr mapping with langmap.
    execute('cnoremap <expr> { "FAIL_cexplangmap"')
    feed('o+<esc>')
    execute('cunmap {')

    -- Assert buffer contents.
    expect([[
      test starts here:
      vim 
      +
      +
      +
      +]])
  end)
end)
