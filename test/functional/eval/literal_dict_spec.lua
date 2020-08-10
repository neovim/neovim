local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval

describe('literal dictionary', function()
  before_each(clear)

  it('should allow empty literal dicts', function()
    eq({}, eval[[#{}]])
  end)

  it('should allow simple letters', function()
    local result = eval [[#{hi: 1}]]
    eq({hi = 1}, result)
  end)

  it('should allow nested dicts', function()
    local result = eval [[#{foo: {"bar": v:true}}]]
    eq({foo = {bar = true}}, result)
  end)

  it('should allow nested literal dicts', function()
    local result = eval [[#{foo: #{bar: v:true}}]]
    eq({foo = {bar = true}}, result)
  end)

  it('should allow trailing commas', function()
    eq({foo = true}, eval [[#{foo: v:true,}]])
  end)

  it('converts numbers to string (compat)', function()
    eq({["1"] = true}, eval [[#{1: v:true}]])
  end)

  it('can handle whitespace oddities around keys', function()
    eq({foo = true, bar = false}, eval [[#{foo    : v:true, bar :v:false}]])
  end)
end)
