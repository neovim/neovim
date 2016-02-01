-- Test for search('multi-byte char', 'bce')

local helpers = require('test.functional.helpers')
local insert = helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('search_mbyte', function()
  before_each(clear)

  it('is working', function()
    insert([=[
      Results:
      
      Test bce:
      Ａ]=])

    execute('source small.vim')
    execute('source mbyte.vim')
    execute('set encoding=utf-8')
    execute('/^Test bce:/+1')
    execute([[$put =search('Ａ', 'bce', line('.'))]])

    -- Assert buffer contents.
    expect([=[
      Results:
      
      Test bce:
      Ａ
      4]=])
  end)
end)
