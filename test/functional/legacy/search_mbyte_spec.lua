local helpers = require('test.functional.helpers')(after_each)
local insert = helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('search_mbyte', function()
  before_each(clear)

  it("search('multi-byte char', 'bce')", function()
    insert([=[
      Results:
      
      Test bce:
      Ａ]=])

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
