local t = require('test.functional.testutil')(after_each)

local eq = t.eq
local eval = t.eval
local command = t.command
local clear = t.clear
local fn = t.fn
local pcall_err = t.pcall_err

before_each(clear)
for _, func in ipairs({ 'min', 'max' }) do
  describe(func .. '()', function()
    it('gives a single error message when multiple values failed conversions', function()
      eq(
        'Vim(echo):E745: Using a List as a Number',
        pcall_err(command, 'echo ' .. func .. '([-5, [], [], [], 5])')
      )
      eq(
        'Vim(echo):E745: Using a List as a Number',
        pcall_err(command, 'echo ' .. func .. '({1:-5, 2:[], 3:[], 4:[], 5:5})')
      )
      for errmsg, errinput in pairs({
        ['Vim(echo):E745: Using a List as a Number'] = '[]',
        ['Vim(echo):E805: Using a Float as a Number'] = '0.0',
        ['Vim(echo):E703: Using a Funcref as a Number'] = 'function("tr")',
        ['Vim(echo):E728: Using a Dictionary as a Number'] = '{}',
      }) do
        eq(errmsg, pcall_err(command, 'echo ' .. func .. '([' .. errinput .. '])'))
        eq(errmsg, pcall_err(command, 'echo ' .. func .. '({1:' .. errinput .. '})'))
      end
    end)
    it('works with arrays/dictionaries with zero items', function()
      eq(0, fn[func]({}))
      eq(0, eval(func .. '({})'))
    end)
    it('works with arrays/dictionaries with one item', function()
      eq(5, fn[func]({ 5 }))
      eq(5, fn[func]({ test = 5 }))
    end)
    it('works with NULL arrays/dictionaries', function()
      eq(0, eval(func .. '(v:_null_list)'))
      eq(0, eval(func .. '(v:_null_dict)'))
    end)
    it('errors out for invalid types', function()
      for _, errinput in ipairs({
        '1',
        'v:true',
        'v:false',
        'v:null',
        'function("tr")',
        '""',
      }) do
        eq(
          ('Vim(echo):E712: Argument of %s() must be a List or Dictionary'):format(func),
          pcall_err(command, 'echo ' .. func .. '(' .. errinput .. ')')
        )
      end
    end)
  end)
end
