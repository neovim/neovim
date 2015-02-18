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

    execute('set encoding=utf-8')

    -- Abbreviations with р (0x80) should work.
    execute('inoreab чкпр   vim')
    feed('GAчкпр <esc>')

    -- langmap should not get remapped in insert mode.
    execute('inoremap { FAIL_ilangmap')
    execute('set langmap=+{ langnoremap')
    feed('o+<esc>')

    -- expr mapping with langmap.
    execute('inoremap <expr> { "FAIL_iexplangmap"')
    feed('o+<esc>')


    -- Assert buffer contents.
    expect([[
      test starts here:
      vim 
      +
      +]])
  end)
end)
