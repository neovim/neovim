-- Tests for :sort command.

local helpers = require('test.functional.helpers')
local insert, source, clear, expect, eq, eval = helpers.insert,
  helpers.source, helpers.clear, helpers.expect, helpers.eq, helpers.eval

describe('sort command', function()
  setup(clear)

  it('is working', function()
    insert([[
      t01: alphebetical
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t02: numeric
      abc
      ab
      a321
      a123
      a122
      a
      x-22
      b321
      b123
      
      c123d
      -24
       123b
      c321d
      0
      b322b
      b321
      b321b
      
      
      t03: hexadecimal
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t04: alpha, unique
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t05: alpha, reverse
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t06: numeric, reverse
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t07: unique, reverse
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t08: octal
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t09: reverse, hexadecimal
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t10: alpha, skip first character
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t11: alpha, skip first 2 characters
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t12: alpha, unique, skip first 2 characters
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t13: numeric, skip first character
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t14: alpha, sort on first character
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t15: alpha, sort on first 2 characters
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t16: numeric, sort on first character
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t17: alpha, skip past first digit
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t18: alpha, sort on first digit
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t19: numeric, skip past first digit
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t20: numeric, sort on first digit
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t21: alpha, skip past first 2 digits
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t22: numeric, skip past first 2 digits
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t23: hexadecimal, skip past first 2 digits
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t24: alpha, sort on first 2 digits
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t25: numeric, sort on first 2 digits
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t26: hexadecimal, sort on first 2 digits
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t27: wrong arguments
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t28: done
      ]])

    source([[
      /^t01:/+1,/^t02/-1sort
      /^t02:/+1,/^t03/-1sort n
      /^t03:/+1,/^t04/-1sort x
      /^t04:/+1,/^t05/-1sort u
      /^t05:/+1,/^t06/-1sort!
      /^t06:/+1,/^t07/-1sort! n        
      /^t07:/+1,/^t08/-1sort! u
      /^t08:/+1,/^t09/-1sort o         
      /^t09:/+1,/^t10/-1sort! x        
      /^t10:/+1,/^t11/-1sort/./        
      /^t11:/+1,/^t12/-1sort/../       
      /^t12:/+1,/^t13/-1sort/../u
      /^t13:/+1,/^t14/-1sort/./n
      /^t14:/+1,/^t15/-1sort/./r
      /^t15:/+1,/^t16/-1sort/../r
      /^t16:/+1,/^t17/-1sort/./rn
      /^t17:/+1,/^t18/-1sort/\d/
      /^t18:/+1,/^t19/-1sort/\d/r
      /^t19:/+1,/^t20/-1sort/\d/n
      /^t20:/+1,/^t21/-1sort/\d/rn
      /^t21:/+1,/^t22/-1sort/\d\d/
      /^t22:/+1,/^t23/-1sort/\d\d/n
      /^t23:/+1,/^t24/-1sort/\d\d/x
      /^t24:/+1,/^t25/-1sort/\d\d/r
      /^t25:/+1,/^t26/-1sort/\d\d/rn
      /^t26:/+1,/^t27/-1sort/\d\d/rx
    ]])
    -- This should fail with "E474: Invalid argument".
    source([[
      try
	/^t27:/+1,/^t28/-1sort no
      catch
	let tmpvar = v:exception
      endtry]])
    eq('Vim(sort):E474: Invalid argument', eval('tmpvar'))

    -- Assert buffer contents.
    expect([[
      t01: alphebetical
      
      
       123b
      a
      a122
      a123
      a321
      ab
      abc
      b123
      b321
      b321
      b321b
      b322b
      c123d
      c321d
      t02: numeric
      abc
      ab
      a
      
      
      
      -24
      x-22
      0
      a122
      a123
      b123
      c123d
       123b
      a321
      b321
      c321d
      b321
      b321b
      b322b
      t03: hexadecimal
      
      
      a
      ab
      abc
       123b
      a122
      a123
      a321
      b123
      b321
      b321
      b321b
      b322b
      c123d
      c321d
      t04: alpha, unique
      
       123b
      a
      a122
      a123
      a321
      ab
      abc
      b123
      b321
      b321b
      b322b
      c123d
      c321d
      t05: alpha, reverse
      c321d
      c123d
      b322b
      b321b
      b321
      b321
      b123
      abc
      ab
      a321
      a123
      a122
      a
       123b
      
      
      t06: numeric, reverse
      b322b
      b321b
      b321
      c321d
      b321
      a321
       123b
      c123d
      b123
      a123
      a122
      
      
      a
      ab
      abc
      t07: unique, reverse
      c321d
      c123d
      b322b
      b321b
      b321
      b123
      abc
      ab
      a321
      a123
      a122
      a
       123b
      
      t08: octal
      abc
      ab
      a
      
      
      a122
      a123
      b123
      c123d
       123b
      a321
      b321
      c321d
      b321
      b321b
      b322b
      t09: reverse, hexadecimal
      c321d
      c123d
      b322b
      b321b
      b321
      b321
      b123
      a321
      a123
      a122
       123b
      abc
      ab
      a
      
      
      t10: alpha, skip first character
      a
      
      
      a122
      a123
      b123
       123b
      c123d
      a321
      b321
      b321
      b321b
      c321d
      b322b
      ab
      abc
      t11: alpha, skip first 2 characters
      ab
      a
      
      
      a321
      b321
      b321
      b321b
      c321d
      a122
      b322b
      a123
      b123
       123b
      c123d
      abc
      t12: alpha, unique, skip first 2 characters
      ab
      a
      
      a321
      b321
      b321b
      c321d
      a122
      b322b
      a123
      b123
       123b
      c123d
      abc
      t13: numeric, skip first character
      abc
      ab
      a
      
      
      a122
      a123
      b123
      c123d
       123b
      a321
      b321
      c321d
      b321
      b321b
      b322b
      t14: alpha, sort on first character
      
      
       123b
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      b322b
      b321
      b321b
      c123d
      c321d
      t15: alpha, sort on first 2 characters
      a
      
      
       123b
      a123
      a122
      a321
      abc
      ab
      b123
      b321
      b322b
      b321
      b321b
      c123d
      c321d
      t16: numeric, sort on first character
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t17: alpha, skip past first digit
      abc
      ab
      a
      
      
      a321
      b321
      b321
      b321b
      c321d
      a122
      b322b
      a123
      b123
       123b
      c123d
      t18: alpha, sort on first digit
      abc
      ab
      a
      
      
      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b
      t19: numeric, skip past first digit
      abc
      ab
      a
      
      
      a321
      b321
      c321d
      b321
      b321b
      a122
      b322b
      a123
      b123
      c123d
       123b
      t20: numeric, sort on first digit
      abc
      ab
      a
      
      
      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b
      t21: alpha, skip past first 2 digits
      abc
      ab
      a
      
      
      a321
      b321
      b321
      b321b
      c321d
      a122
      b322b
      a123
      b123
       123b
      c123d
      t22: numeric, skip past first 2 digits
      abc
      ab
      a
      
      
      a321
      b321
      c321d
      b321
      b321b
      a122
      b322b
      a123
      b123
      c123d
       123b
      t23: hexadecimal, skip past first 2 digits
      abc
      ab
      a
      
      
      a321
      b321
      b321
      a122
      a123
      b123
      b321b
      c321d
      b322b
       123b
      c123d
      t24: alpha, sort on first 2 digits
      abc
      ab
      a
      
      
      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b
      t25: numeric, sort on first 2 digits
      abc
      ab
      a
      
      
      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b
      t26: hexadecimal, sort on first 2 digits
      abc
      ab
      a
      
      
      a123
      a122
      b123
      c123d
       123b
      a321
      b321
      c321d
      b322b
      b321
      b321b
      t27: wrong arguments
      abc
      ab
      a
      a321
      a123
      a122
      b321
      b123
      c123d
       123b
      c321d
      b322b
      b321
      b321b
      
      
      t28: done
      ]])
  end)
end)
