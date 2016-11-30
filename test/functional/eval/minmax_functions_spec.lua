local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local clear = helpers.clear
local funcs = helpers.funcs
local redir_exec = helpers.redir_exec

before_each(clear)
for _, func in ipairs({'min', 'max'}) do
  describe(func .. '()', function()
    it('gives a single error message when multiple values failed conversions',
    function()
      eq('\nE745: Using a List as a Number\n0',
         redir_exec('echo ' .. func .. '([-5, [], [], [], 5])'))
      eq('\nE745: Using a List as a Number\n0',
         redir_exec('echo ' .. func .. '({1:-5, 2:[], 3:[], 4:[], 5:5})'))
      for errmsg, errinput in pairs({
        ['E745: Using a List as a Number'] = '[]',
        ['E805: Using a Float as a Number'] = '0.0',
        ['E703: Using a Funcref as a Number'] = 'function("tr")',
        ['E728: Using a Dictionary as a Number'] = '{}',
      }) do
        eq('\n' .. errmsg .. '\n0',
           redir_exec('echo ' .. func .. '([' .. errinput .. '])'))
        eq('\n' .. errmsg .. '\n0',
           redir_exec('echo ' .. func .. '({1:' .. errinput .. '})'))
      end
    end)
    it('works with arrays/dictionaries with zero items', function()
      eq(0, funcs[func]({}))
      eq(0, eval(func .. '({})'))
    end)
    it('works with arrays/dictionaries with one item', function()
      eq(5, funcs[func]({5}))
      eq(5, funcs[func]({test=5}))
    end)
    it('works with NULL arrays/dictionaries', function()
      eq(0, eval(func .. '(v:_null_list)'))
      eq(0, eval(func .. '(v:_null_dict)'))
    end)
    it('errors out for invalid types', function()
      for _, errinput in ipairs({'1', 'v:true', 'v:false', 'v:null',
                                 'function("tr")', '""'}) do
        eq(('\nE712: Argument of %s() must be a List or Dictionary\n0'):format(
            func),
           redir_exec('echo ' .. func .. '(' .. errinput .. ')'))
      end
    end)
  end)
end
