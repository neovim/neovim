local helpers = require('test.functional.helpers')
local clear, feed = helpers.clear, helpers.feed
local expect, insert = helpers.expect, helpers.insert

describe('increment/decrement in visual mode', function()
  before_each(function()
    clear()
  end)

  it('increments the number', function()
    insert([[foobar-10]])
    feed('gg^<c-a>')
    expect([[foobar-9]])
    clear()

    insert([[foobar-10]])
    feed('ggf-v$<c-a>')
    expect([[foobar-9]])
    clear()

    insert([[foobar-10]])
    feed('ggf1v$<c-a>')
    expect([[foobar-11]])
    clear()
  end)

  it('decrements the number', function()
    insert([[foobar-10]])
    feed('ggf-v$<c-x>')
    expect([[foobar-11]])
    clear()

    insert([[foobar-10]])
    feed('ggf1v$<c-x>')
    expect([[foobar-9]])
  end)

  it('increments numbers on visually selected lines', function()
    insert([[
      10
      20
      30
      40]])
    feed('gg<s-v>G<c-a>')
    expect([[
      11
      21
      31
      41]])
  end)

  it('decrements numbers on visually selected lines', function()
    insert([[
      10
      20
      30
      40]])
    feed('gg<s-v>G<c-x>')
    expect([[
      9
      19
      29
      39]])
  end)

  it('increments numbers of visually selected lines, with non-numbers in betwen', function()
    insert([[10

20

30

40]])
    feed('ggVG2g<c-a>')
    expect([[12

24

36

48]])
  end)

  it('decrements numbers of visually selected lines, with non-numbers in betwen', function()
    insert([[10

20

30

40]])
    feed('ggVG2g<c-x>')
    expect([[8

16

24

32]])
  end)
end)
