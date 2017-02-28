local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local insert = helpers.insert
local feed = helpers.feed
local expect = helpers.expect
local execute = helpers.execute

describe('Folds', function()
  clear()
  it('manual folding adjusts with filter', function()
    insert([[
    1
    2
    3
    4
    5
    6
    7
    8
    9
    10
    11
    12
    13
    14
    15
    16
    17
    18
    19
    20]])
    execute('4,$fold', '%foldopen', '10,$fold', '%foldopen')
    execute('1,8! cat')
    feed('5ggzdzMGdd')
    expect([[
    1
    2
    3
    4
    5
    6
    7
    8
    9]])
  end)
end)
