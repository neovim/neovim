describe('Operator priority', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  describe('Arithmetic operators priority', function()
    ito('Division and multiplication', [[
      echo 16 / 17 * 2
      echo 16 * 2 / 17
    ]], {0, 1})
    ito('Addition and subtraction', [[
      echo 2 + 2 - 1
    ]], {3})
    ito('Addition, subtraction, division and multiplication', [[
      echo 2 + 2 * 2
      echo 2 * 2 + 2
      echo 2 + 2 / 2
      echo 2 - 2 / 2
      echo 2 / 2 + 2
      echo 2 / 2 - 2
    ]], {6, 6, 3, 1, 3, -1})
    ito('Addition and modulo', [[
      echo 3 + 2 % 2
      echo 2 + 2 % 3
      echo 2 % 2 + 3
      echo 2 % 3 + 2
    ]], {3, 4, 3, 4})
    ito('Multiplication and modulo', [[
      echo 2 * 3 % 4
      echo 3 % 4 * 2
    ]], {2, 6})
  end)
  describe('Arithmetic operators and concatenation', function()
    ito('Addition and concatenation', [[
      echo 2 + 2 . 2
      echo 2 . 2 + 2
      echo 2 + 2 . 2 + 2
      echo 2 . 2 + 2 . 2
    ]], {'42', 24, 44, '242'})
    ito('Concatenation and multiplication', [[
      echo 2 . 2 * 3
      echo 3 * 2 . 2
    ]], {'26', '62'})
  end)
end)

describe('Number computations', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  describe('Arithmetic operators', function()
    ito('Numeric addition', [[
      echo 1 + 1
      echo 1 + 10
      echo 0x10 + 0x100
      echo 010 + 020
    ]], {2, 11, 272, 24})
    ito('Numeric subtraction', [[
      echo 1 - 1
      echo 1 - 10
      echo 0x10 - 0x100
      echo 010 - 020
    ]], {0, -9, -240, -8})
    ito('Unary minus', [[
      echo -0
      echo -1
      echo -000
      echo -010
      echo -0x0
      echo -0x10
      echo -(0)
      echo -(1)
      echo -(000)
      echo -(010)
      echo -(0x0)
      echo -(0x10)
    ]], {0, -1, 0, -8, 0, -16, 0, -1, 0, -8, 0, -16})
    ito('Unary plus', [[
      echo +0
      echo +1
      echo +000
      echo +010
      echo +0x0
      echo +0x10
      echo +(0)
      echo +(1)
      echo +(000)
      echo +(010)
      echo +(0x0)
      echo +(0x10)
    ]], {0, 1, 0, 8, 0, 16, 0, 1, 0, 8, 0, 16})
    ito('Numeric multiplication', [[
      echo  0 *  7
      echo  1 *  7
      echo  2 *  7
      echo -0 *  7
      echo -1 *  7
      echo -2 *  7
      echo  0 * -7
      echo  1 * -7
      echo  2 * -7
      echo -0 * -7
      echo -1 * -7
      echo -2 * -7
    ]], {0, 7, 14, 0, -7, -14, 0, -7, -14, 0, 7, 14})
    ito('Numeric division', [[
      echo ''.(  0 /  7)
      echo ''.( 15 /  7)
      echo ''.(-15 /  7)
      echo ''.( 17 / -7)
      echo ''.(-17 / -7)
      echo ''.(  0 /  0)
      echo ''.(  1 /  0)
      echo ''.( -1 /  0)
    ]], {'0', '2', '-2', '-2', '2', '-2147483648', '2147483647', '-2147483647'})
    ito('Modulo', [[
      echo  1 %  0
      echo  2 %  1
      echo  3 %  2
      echo  4 %  2
      echo  1 %  2
      echo -1 %  2
      echo  1 % -2
      echo -1 % -2
    ]], {0, 0, 1, 0, 1, -1, 1, -1})
  end)
  describe('Concatenation', function()
    ito('Numeric concatenation', [[
      echo  1 .  1
      echo -1 .  1
      echo  1 . -1
      echo -1 . -1
      echo 010 . 010
      echo 0x10 . 0x10
    ]], {'11', '-11', '1-1', '-1-1', '88', '1616'})
  end)
  describe('Comparison operators', function()
    describe('Less/greater (or equal to)', function()
      ito('Less/greater operators', [[
        echo  1 >  1
        echo  1 <  1
        echo  1 >  2
        echo  1 <  2
        echo -1 >  2
        echo -1 <  2
        echo -1 > -2
        echo -1 < -2
        echo  1 > -2
        echo  1 < -2
      ]], {0, 0, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('LE/GE operators', [[
        echo  1 >=  1
        echo  1 <=  1
        echo  1 >=  2
        echo  1 <=  2
        echo -1 >=  2
        echo -1 <=  2
        echo -1 >= -2
        echo -1 <= -2
        echo  1 >= -2
        echo  1 <= -2
      ]], {1, 1, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('Less/greater operators (ic)', [[
        echo  1 >?  1
        echo  1 <?  1
        echo  1 >?  2
        echo  1 <?  2
        echo -1 >?  2
        echo -1 <?  2
        echo -1 >? -2
        echo -1 <? -2
        echo  1 >? -2
        echo  1 <? -2
      ]], {0, 0, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('LE/GE operators (ic)', [[
        echo  1 >=?  1
        echo  1 <=?  1
        echo  1 >=?  2
        echo  1 <=?  2
        echo -1 >=?  2
        echo -1 <=?  2
        echo -1 >=? -2
        echo -1 <=? -2
        echo  1 >=? -2
        echo  1 <=? -2
      ]], {1, 1, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('Less/greater operators (noic)', [[
        echo  1 >#  1
        echo  1 <#  1
        echo  1 >#  2
        echo  1 <#  2
        echo -1 >#  2
        echo -1 <#  2
        echo -1 ># -2
        echo -1 <# -2
        echo  1 ># -2
        echo  1 <# -2
      ]], {0, 0, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('LE/GE operators (noic)', [[
        echo  1 >=#  1
        echo  1 <=#  1
        echo  1 >=#  2
        echo  1 <=#  2
        echo -1 >=#  2
        echo -1 <=#  2
        echo -1 >=# -2
        echo -1 <=# -2
        echo  1 >=# -2
        echo  1 <=# -2
      ]], {1, 1, 0, 1, 0, 1, 1, 0, 1, 0})
    end)
    describe('Equality and identity', function()
      ito('EQ/NE operators', [[
        echo  1 ==  1
        echo  1 !=  1
        echo -1 ==  1
        echo -1 !=  1
        echo  1 == -1
        echo  1 != -1
        echo -1 == -1
        echo -1 != -1
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('EQ/NE operators (ic)', [[
        echo  1 ==?  1
        echo  1 !=?  1
        echo -1 ==?  1
        echo -1 !=?  1
        echo  1 ==? -1
        echo  1 !=? -1
        echo -1 ==? -1
        echo -1 !=? -1
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('EQ/NE operators (noic)', [[
        echo  1 ==#  1
        echo  1 !=#  1
        echo -1 ==#  1
        echo -1 !=#  1
        echo  1 ==# -1
        echo  1 !=# -1
        echo -1 ==# -1
        echo -1 !=# -1
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot operators', [[
        echo  1 ==  1
        echo  1 !=  1
        echo -1 ==  1
        echo -1 !=  1
        echo  1 == -1
        echo  1 != -1
        echo -1 == -1
        echo -1 != -1
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot operators (ic)', [[
        echo  1 is?     1
        echo  1 isnot?  1
        echo -1 is?     1
        echo -1 isnot?  1
        echo  1 is?    -1
        echo  1 isnot? -1
        echo -1 is?    -1
        echo -1 isnot? -1
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot operators (noic)', [[
        echo  1 is#     1
        echo  1 isnot#  1
        echo -1 is#     1
        echo -1 isnot#  1
        echo  1 is#    -1
        echo  1 isnot# -1
        echo -1 is#    -1
        echo -1 isnot# -1
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
    end)
  end)
end)

describe('Floating-point computations', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  local f = function(v)
    return {_t='float', _v=v}
  end
  describe('Arithmetic operators', function()
    ito('Floating-point addition', [[
      echo 1.0 + 1.5
      echo 0.0 + 1.5
      echo 1.5 + 0.0
      echo 1.0e5 + 1.0e6
    ]], {f(2.5), f(1.5), f(1.5), f(11e5)})
    ito('Floating-point subtraction', [[
      echo 1.0 - 1.5
      echo 1.1 - 0.0
      echo 0.0 - 1.2
      echo 1.0e5 - 1.0e6
    ]], {f(-0.5), f(1.1), f(-1.2), f(-9e5)})
    ito('Floating-point multiplication', [[
      echo 1.0 * 1.1
      echo 0.0 * 1.1
      echo 1.1 * 1.0
      echo 1.1 * 0.0
      echo 1.0e5 * 1.0e6
      echo 1.0e5 * 1.0e-6
    ]], {f(1.1), f(0.0), f(1.1), f(0.0), f(1e11), f(0.1)})
    -- Am not testing 0.0/0.0 behavior since I cannot find references to it in 
    -- documentation
    ito('Floating-point division', [[
      echo 1.0 / 1.0
      echo 2.0 / 1.0
      echo 0.0 / 1.0
      echo 1.0 / 2.0
      echo 1.0e5 / 1.0e6
      echo 1.0e5 / 1.0e-6
    ]], {f(1), f(2), f(0), f(0.5), f(0.1), f(1e11)})
    ito('Unary minus', [[
      echo -1.0
      echo --1.0
      echo -(1.0)
      echo --(1.0)
      echo -0.0
      echo -1.0e5
      echo -(0.0)
      echo -(1.0e5)
    ]], {f(-1), f(1), f(-1), f(1), f(-0), f(-1e5), f(-0), f(-1e5)})
    ito('Unary plus', [[
      echo +1.0
      echo +-1.0
      echo +(1.0)
      echo +-(1.0)
      echo +0.0
      echo +1.0e5
      echo +(0.0)
      echo +(1.0e5)
    ]], {f(1), f(-1), f(1), f(-1), f(0), f(1e5), f(0), f(1e5)})
    ito('Modulo', [[
      try
        echo 1.0 % 1.0
      catch
        echo v:exception
      endtry
    ]], {'Vim(echo):E804: Cannot use \'%\' with Float'})
  end)
  describe('Concatenation', function()
    ito('Floating-point concatenation', [[
      try
        echo 1.0 . 1.0
      catch
        echo v:exception
      endtry
    ]], {'Vim(echo):E806: Using Float as a String'})
  end)
  describe('Comparison operators', function()
    describe('Less/greater (or equal to)', function()
      ito('Less/greater operators', [[
        echo  1.0 >  1.0
        echo  1.0 <  1.0
        echo  1.0 >  2.0
        echo  1.0 <  2.0
        echo -1.0 >  2.0
        echo -1.0 <  2.0
        echo -1.0 > -2.0
        echo -1.0 < -2.0
        echo  1.0 > -2.0
        echo  1.0 < -2.0
      ]], {0, 0, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('LE/GE operators', [[
        echo  1.0 >=  1.0
        echo  1.0 <=  1.0
        echo  1.0 >=  2.0
        echo  1.0 <=  2.0
        echo -1.0 >=  2.0
        echo -1.0 <=  2.0
        echo -1.0 >= -2.0
        echo -1.0 <= -2.0
        echo  1.0 >= -2.0
        echo  1.0 <= -2.0
      ]], {1, 1, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('Less/greater operators (ic)', [[
        echo  1.0 >?  1.0
        echo  1.0 <?  1.0
        echo  1.0 >?  2.0
        echo  1.0 <?  2.0
        echo -1.0 >?  2.0
        echo -1.0 <?  2.0
        echo -1.0 >? -2.0
        echo -1.0 <? -2.0
        echo  1.0 >? -2.0
        echo  1.0 <? -2.0
      ]], {0, 0, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('LE/GE operators (ic)', [[
        echo  1.0 >=?  1.0
        echo  1.0 <=?  1.0
        echo  1.0 >=?  2.0
        echo  1.0 <=?  2.0
        echo -1.0 >=?  2.0
        echo -1.0 <=?  2.0
        echo -1.0 >=? -2.0
        echo -1.0 <=? -2.0
        echo  1.0 >=? -2.0
        echo  1.0 <=? -2.0
      ]], {1, 1, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('Less/greater operators (noic)', [[
        echo  1.0 >#  1.0
        echo  1.0 <#  1.0
        echo  1.0 >#  2.0
        echo  1.0 <#  2.0
        echo -1.0 >#  2.0
        echo -1.0 <#  2.0
        echo -1.0 ># -2.0
        echo -1.0 <# -2.0
        echo  1.0 ># -2.0
        echo  1.0 <# -2.0
      ]], {0, 0, 0, 1, 0, 1, 1, 0, 1, 0})
      ito('LE/GE operators (noic)', [[
        echo  1.0 >=#  1.0
        echo  1.0 <=#  1.0
        echo  1.0 >=#  2.0
        echo  1.0 <=#  2.0
        echo -1.0 >=#  2.0
        echo -1.0 <=#  2.0
        echo -1.0 >=# -2.0
        echo -1.0 <=# -2.0
        echo  1.0 >=# -2.0
        echo  1.0 <=# -2.0
      ]], {1, 1, 0, 1, 0, 1, 1, 0, 1, 0})
    end)
    describe('Equality and identity', function()
      ito('EQ/NE operators', [[
        echo  1.0 ==  1.0
        echo  1.0 !=  1.0
        echo -1.0 ==  1.0
        echo -1.0 !=  1.0
        echo  1.0 == -1.0
        echo  1.0 != -1.0
        echo -1.0 == -1.0
        echo -1.0 != -1.0
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('EQ/NE operators (ic)', [[
        echo  1.0 ==?  1.0
        echo  1.0 !=?  1.0
        echo -1.0 ==?  1.0
        echo -1.0 !=?  1.0
        echo  1.0 ==? -1.0
        echo  1.0 !=? -1.0
        echo -1.0 ==? -1.0
        echo -1.0 !=? -1.0
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('EQ/NE operators (noic)', [[
        echo  1.0 ==#  1.0
        echo  1.0 !=#  1.0
        echo -1.0 ==#  1.0
        echo -1.0 !=#  1.0
        echo  1.0 ==# -1.0
        echo  1.0 !=# -1.0
        echo -1.0 ==# -1.0
        echo -1.0 !=# -1.0
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot operators', [[
        echo  1.0 ==  1.0
        echo  1.0 !=  1.0
        echo -1.0 ==  1.0
        echo -1.0 !=  1.0
        echo  1.0 == -1.0
        echo  1.0 != -1.0
        echo -1.0 == -1.0
        echo -1.0 != -1.0
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot operators (ic)', [[
        echo  1.0 is?     1.0
        echo  1.0 isnot?  1.0
        echo -1.0 is?     1.0
        echo -1.0 isnot?  1.0
        echo  1.0 is?    -1.0
        echo  1.0 isnot? -1.0
        echo -1.0 is?    -1.0
        echo -1.0 isnot? -1.0
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot operators (noic)', [[
        echo  1.0 is#     1.0
        echo  1.0 isnot#  1.0
        echo -1.0 is#     1.0
        echo -1.0 isnot#  1.0
        echo  1.0 is#    -1.0
        echo  1.0 isnot# -1.0
        echo -1.0 is#    -1.0
        echo -1.0 isnot# -1.0
      ]], {1, 0, 0, 1, 0, 1, 1, 0})
    end)
  end)
end)

describe('String computations', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  describe('Arithmetic operators', function()
    ito('String addition', [[
      echo 'abc' + 'def'
      echo '1abc' + 'def'
      echo 'abc' + '1def'
      echo '1abc' + '1def'
      echo 'abc1' + 'def'
      echo '1.1abc' + 'def'
      echo ' 1abc' + 'def'
      echo '1' + '2'
      echo '10' + 'abc'
    ]], {0, 1, 1, 2, 0, 1, 0, 3, 10})
    ito('String subtraction', [[
      echo 'abc' - 'def'
      echo '1abc' - 'def'
      echo 'abc' - '1def'
      echo 'abc1' - 'def'
      echo 'abc' - 'def1'
      echo 'abc1' - 'def1'
      echo '1' - '2'
      echo '0' - '10'
    ]], {0, 1, -1, 0, 0, 0, -1, -10})
    ito('String multiplication', [[
      echo 'abc' * 'def'
      echo '1abc' * 'def'
      echo '1abc' * '1def'
      echo 'abc' * '1def'
      echo 'abc1' * 'def'
      echo 'abc' * 'def1'
      echo 'abc1' * 'def1'
      echo '1' * '2'
      echo '10' * '10'
    ]], {0, 0, 1, 0, 0, 0, 0, 2, 100})
    ito('String division', [[
      echo 'abc' / 'def'
      echo '1abc' / 'def'
      echo '-1abc' / 'def'
      echo '1' / '2'
      echo '-2' / '2'
    ]], {-2147483648, 2147483647, -2147483647, 0, -1})
    ito('String modulo', [[
      echo 'abc' % 'def'
      echo '1abc' % 'def'
      echo '1abc' % '2def'
      echo '-1abc' % '2def'
    ]], {0, 0, 1, -1})
    ito('Unary minus', [[
      echo -'-1abc'
      echo --'-1abc'
      echo -'abc'
      echo -'10'
    ]], {1, -1, 0, -10})
    ito('Unary plus', [[
      echo +'abc'
      echo +'-1abc'
      echo +'1abc'
      echo +'abc1'
      echo +'- 1abc'
      echo +'-abc1'
      echo +'080'
      echo +'0x20'
      echo +'0X20'
      echo +'0XAB'
      echo +'0xAB'
      echo +'0xab'
      echo +'0Xab'
      echo +'-0xAB'
    ]], {0, -1, 1, 0, 0, 0, 80, 32, 32, 171, 171, 171, 171, -171})
  end)
  describe('Concatenation', function()
    ito('String concatenation', [[
      echo 'abc' . 'def'
    ]], {'abcdef'})
  end)
  describe('Comparison operators', function()
    describe('Less/greater (or equal to)', function()
      ito('EQ/NE (noic)', [[
        echo 'b'  ==# 'c'
        echo 'b'  !=# 'c'
        echo 'b'  ==# 'a'
        echo 'b'  !=# 'a'
        echo 'bb' ==# 'b'
        echo 'bb' !=# 'b'
        echo 'bb' ==# 'bb'
        echo 'bb' !=# 'bb'
        echo 'b'  ==# 'bb'
        echo 'b'  !=# 'bb'
        echo 'ba' ==# 'bb'
        echo 'ba' !=# 'bb'
        echo 'b'  ==# 'b'
        echo 'b'  !=# 'b'
      ]], {0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot (noic)', [[
        echo 'b'  is#    'c'
        echo 'b'  isnot# 'c'
        echo 'b'  is#    'a'
        echo 'b'  isnot# 'a'
        echo 'bb' is#    'b'
        echo 'bb' isnot# 'b'
        echo 'bb' is#    'bb'
        echo 'bb' isnot# 'bb'
        echo 'b'  is#    'bb'
        echo 'b'  isnot# 'bb'
        echo 'ba' is#    'bb'
        echo 'ba' isnot# 'bb'
        echo 'b'  is#    'b'
        echo 'b'  isnot# 'b'
      ]], {0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0})
      ito('EQ/NE/is/isnot (noic), with different case', [[
        echo 'b'  ==#    'B'
        echo 'b'  !=#    'B'
        echo 'b'  is#    'B'
        echo 'b'  isnot# 'B'
        echo 'ab' ==#    'aB'
        echo 'ab' !=#    'aB'
        echo 'ab' is#    'aB'
        echo 'ab' isnot# 'aB'
        echo 'ba' ==#    'Ba'
        echo 'ba' !=#    'Ba'
        echo 'ba' is#    'Ba'
        echo 'ba' isnot# 'Ba'
      ]], {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1})
      ito('LT/GT (noic)', [[
        echo 'b'  ># 'c'
        echo 'b'  <# 'c'
        echo 'b'  ># 'a'
        echo 'b'  <# 'a'
        echo 'bb' ># 'b'
        echo 'bb' <# 'b'
        echo 'bb' ># 'bb'
        echo 'bb' <# 'bb'
        echo 'b'  ># 'bb'
        echo 'b'  <# 'bb'
        echo 'ba' ># 'bb'
        echo 'ba' <# 'bb'
        echo 'b'  ># 'b'
        echo 'b'  <# 'b'
      ]], {0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0})
      ito('LE/GE (noic)', [[
        echo 'b'  >=# 'c'
        echo 'b'  <=# 'c'
        echo 'b'  >=# 'a'
        echo 'b'  <=# 'a'
        echo 'bb' >=# 'b'
        echo 'bb' <=# 'b'
        echo 'bb' >=# 'bb'
        echo 'bb' <=# 'bb'
        echo 'b'  >=# 'bb'
        echo 'b'  <=# 'bb'
        echo 'ba' >=# 'bb'
        echo 'ba' <=# 'bb'
        echo 'b'  >=# 'b'
        echo 'b'  <=# 'b'
      ]], {0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1})
      ito('LT/GT/LE/GE (noic), with different case', [[
        echo 'b'  >#  'B'
        echo 'b'  <#  'B'
        echo 'b'  >=# 'B'
        echo 'b'  <=# 'B'
        echo 'ab' >#  'aB'
        echo 'ab' <#  'aB'
        echo 'ab' >=# 'aB'
        echo 'ab' <=# 'aB'
        echo 'ba' >#  'Ba'
        echo 'ba' <#  'Ba'
        echo 'ba' >=# 'Ba'
        echo 'ba' <=# 'Ba'
      ]], {1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0})
      ito('LT/GT (ic)', [[
        echo 'b'  >? 'c'
        echo 'b'  <? 'c'
        echo 'b'  >? 'a'
        echo 'b'  <? 'a'
        echo 'bb' >? 'b'
        echo 'bb' <? 'b'
        echo 'bb' >? 'bb'
        echo 'bb' <? 'bb'
        echo 'b'  >? 'bb'
        echo 'b'  <? 'bb'
        echo 'ba' >? 'bb'
        echo 'ba' <? 'bb'
        echo 'b'  >? 'b'
        echo 'b'  <? 'b'
      ]], {0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0})
      ito('LE/GE (ic)', [[
        echo 'b'  >=? 'c'
        echo 'b'  <=? 'c'
        echo 'b'  >=? 'a'
        echo 'b'  <=? 'a'
        echo 'bb' >=? 'b'
        echo 'bb' <=? 'b'
        echo 'bb' >=? 'bb'
        echo 'bb' <=? 'bb'
        echo 'b'  >=? 'bb'
        echo 'b'  <=? 'bb'
        echo 'ba' >=? 'bb'
        echo 'ba' <=? 'bb'
        echo 'b'  >=? 'b'
        echo 'b'  <=? 'b'
      ]], {0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1})
      ito('LT/GT/LE/GE (ic), with different case', [[
        echo 'b'  >?  'B'
        echo 'b'  <?  'B'
        echo 'b'  >=? 'B'
        echo 'b'  <=? 'B'
        echo 'ab' >?  'aB'
        echo 'ab' <?  'aB'
        echo 'ab' >=? 'aB'
        echo 'ab' <=? 'aB'
        echo 'ba' >?  'Ba'
        echo 'ba' <?  'Ba'
        echo 'ba' >=? 'Ba'
        echo 'ba' <=? 'Ba'
      ]], {0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1})
    end)
    describe('Equality and identity', function()
      ito('EQ/NE (noic)', [[
        echo 'b'  ==# 'c'
        echo 'b'  !=# 'c'
        echo 'b'  ==# 'a'
        echo 'b'  !=# 'a'
        echo 'bb' ==# 'b'
        echo 'bb' !=# 'b'
        echo 'bb' ==# 'bb'
        echo 'bb' !=# 'bb'
        echo 'b'  ==# 'bb'
        echo 'b'  !=# 'bb'
        echo 'ba' ==# 'bb'
        echo 'ba' !=# 'bb'
        echo 'b'  ==# 'b'
        echo 'b'  !=# 'b'
      ]], {0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot (noic)', [[
        echo 'b'  is#    'c'
        echo 'b'  isnot# 'c'
        echo 'b'  is#    'a'
        echo 'b'  isnot# 'a'
        echo 'bb' is#    'b'
        echo 'bb' isnot# 'b'
        echo 'bb' is#    'bb'
        echo 'bb' isnot# 'bb'
        echo 'b'  is#    'bb'
        echo 'b'  isnot# 'bb'
        echo 'ba' is#    'bb'
        echo 'ba' isnot# 'bb'
        echo 'b'  is#    'b'
        echo 'b'  isnot# 'b'
      ]], {0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0})
      ito('EQ/NE/is/isnot (noic), with different case', [[
        echo 'b'  ==#    'B'
        echo 'b'  !=#    'B'
        echo 'b'  is#    'B'
        echo 'b'  isnot# 'B'
        echo 'ab' ==#    'aB'
        echo 'ab' !=#    'aB'
        echo 'ab' is#    'aB'
        echo 'ab' isnot# 'aB'
        echo 'ba' ==#    'Ba'
        echo 'ba' !=#    'Ba'
        echo 'ba' is#    'Ba'
        echo 'ba' isnot# 'Ba'
      ]], {0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1})
      ito('EQ/NE (ic)', [[
        echo 'b'  ==? 'c'
        echo 'b'  !=? 'c'
        echo 'b'  ==? 'a'
        echo 'b'  !=? 'a'
        echo 'bb' ==? 'b'
        echo 'bb' !=? 'b'
        echo 'bb' ==? 'bb'
        echo 'bb' !=? 'bb'
        echo 'b'  ==? 'bb'
        echo 'b'  !=? 'bb'
        echo 'ba' ==? 'bb'
        echo 'ba' !=? 'bb'
        echo 'b'  ==? 'b'
        echo 'b'  !=? 'b'
      ]], {0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0})
      ito('is/isnot (ic)', [[
        echo 'b'  is?    'c'
        echo 'b'  isnot? 'c'
        echo 'b'  is?    'a'
        echo 'b'  isnot? 'a'
        echo 'bb' is?    'b'
        echo 'bb' isnot? 'b'
        echo 'bb' is?    'bb'
        echo 'bb' isnot? 'bb'
        echo 'b'  is?    'bb'
        echo 'b'  isnot? 'bb'
        echo 'ba' is?    'bb'
        echo 'ba' isnot? 'bb'
        echo 'b'  is?    'b'
        echo 'b'  isnot? 'b'
      ]], {0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0})
      ito('EQ/NE/is/isnot (ic), with different case', [[
        echo 'b'  ==?    'B'
        echo 'b'  !=?    'B'
        echo 'b'  is?    'B'
        echo 'b'  isnot? 'B'
        echo 'ab' ==?    'aB'
        echo 'ab' !=?    'aB'
        echo 'ab' is?    'aB'
        echo 'ab' isnot? 'aB'
        echo 'ba' ==?    'Ba'
        echo 'ba' !=?    'Ba'
        echo 'ba' is?    'Ba'
        echo 'ba' isnot? 'Ba'
      ]], {1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0})
    end)
  end)
end)

describe('List tests', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  describe('Arithmetic operators', function()
    ito('List addition', [[
      echo [1] + [2]
      echo [] + []
      echo [1] + []
      echo [] + [2]
      echo [1, 2] + [1]
      echo [1] + [2, 3]
      echo [1, 2] + [2, 3]
    ]], {{1, 2}, {_t='list'}, {1}, {2}, {1, 2, 1}, {1, 2, 3}, {1, 2, 2, 3}})
    ito('Other list numeric operations', [[
      try
        echo [] - []
      catch
        echo v:exception
      endtry
      try
        echo [] * []
      catch
        echo v:exception
      endtry
      try
        echo [] / []
      catch
        echo v:exception
      endtry
      try
        echo [] % []
      catch
        echo v:exception
      endtry
    ]], {
      'Vim(echo):E745: Using List as a Number',
      'Vim(echo):E745: Using List as a Number',
      'Vim(echo):E745: Using List as a Number',
      'Vim(echo):E745: Using List as a Number',
    })
  end)
  describe('Concatenation', function()
    ito('List concatenation', [[
      try
        echo [] . []
      catch
        echo v:exception
      endtry
    ]], {'Vim(echo):E730: Using List as a String'})
  end)
  describe('List comparison', function()
    describe('Less/greater (or equal to)', function()
      ito('LT/GT/LE/GE', [[
        try
          echo [] >  []
        catch
          echo v:exception
        endtry
        try
          echo [] <  []
        catch
          echo v:exception
        endtry
        try
          echo [] >= []
        catch
          echo v:exception
        endtry
        try
          echo [] <= []
        catch
          echo v:exception
        endtry
      ]], {
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
      })
      ito('LT/GT/LE/GE (ic)', [[
        try
          echo [] >?  []
        catch
          echo v:exception
        endtry
        try
          echo [] <?  []
        catch
          echo v:exception
        endtry
        try
          echo [] >=? []
        catch
          echo v:exception
        endtry
        try
          echo [] <=? []
        catch
          echo v:exception
        endtry
      ]], {
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
      })
      ito('LT/GT/LE/GE (noic)', [[
        try
          echo [] >#  []
        catch
          echo v:exception
        endtry
        try
          echo [] <#  []
        catch
          echo v:exception
        endtry
        try
          echo [] >=# []
        catch
          echo v:exception
        endtry
        try
          echo [] <=# []
        catch
          echo v:exception
        endtry
      ]], {
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
        'Vim(echo):E692: Invalid operation for Lists',
      })
      ito('EQ/NE, different nested types', [[
        try
          echo [1] == ['1']
          echo [1] == [1.0]
          echo [1] == [ [] ]
          echo [1] == [{}]
          echo [1] == [function('function')]

          echo ['1'] == [1.0]
          echo ['1'] == [ [] ]
          echo ['1'] == [{}]
          echo ['1'] == [function('function')]

          echo [1.0] == [ [] ]
          echo [1.0] == [{}]
          echo [1.0] == [function('function')]

          echo [ [] ] == [{}]
          echo [ [] ] == [function('function')]

          echo [{}] == [function('function')]
        catch
          echo v:exception
        endtry
      ]], {0, 0, 0, 0, 0,
           0, 0, 0, 0,
           0, 0, 0,
           0, 0,
           0})
      ito('EQ/NE, self-referencing lists', [[
        let l = [0, 0]
        let l[0] = l
        let l2 = [0, 0]
        let l2[0] = l2
        let l3 = [ [0, 0], 0]
        let l3[0][0] = l3

        echo l == l2
        echo l == l3
        echo l2 == l3

        let l3[0][1] = 1
        echo l == l3
        echo l2 == l3

        unlet l l2 l3
      ]], {1, 1, 1, 0, 0})
      ito('EQ/NE, self-referencing lists with dictionaries', [[
        let l = [{}, 0]
        let l[0].d = l[0]
        let l2 = [{}, 0]
        let l2[0].d = l2[0]
        let l3 = [{'d': {}}, 0]
        let l3[0].d.d = l3[0]

        echo l == l2
        echo l == l3
        echo l2 == l3

        unlet l l2 l3
      ]], {1, 1, 1})
    end)
    describe('Equality and identity', function()
      ito('EQ/NE (noic)', [[
        echo ['a', 2] ==# ['a', 2]
        echo ['a', 2] !=# ['a', 2]
        echo ['a', 2] ==# ['a', 3]
        echo ['a', 2] !=# ['a', 3]
        echo ['a', 2] ==# ['A', 3]
        echo ['a', 2] !=# ['A', 3]
        echo ['a', 2] ==# ['A', 2]
        echo ['a', 2] !=# ['A', 2]
        echo [] ==# []
        echo [] !=# []
        echo [1] ==# []
        echo [1] !=# []
        echo [] ==# [1]
        echo [] !=# [1]
      ]], {1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1})
      ito('EQ/NE (ic)', [[
        echo ['a', 2] ==? ['a', 2]
        echo ['a', 2] !=? ['a', 2]
        echo ['a', 2] ==? ['a', 3]
        echo ['a', 2] !=? ['a', 3]
        echo ['a', 2] ==? ['A', 3]
        echo ['a', 2] !=? ['A', 3]
        echo ['a', 2] ==? ['A', 2]
        echo ['a', 2] !=? ['A', 2]
        echo [] ==? []
        echo [] !=? []
        echo [1] ==? []
        echo [1] !=? []
        echo [] ==? [1]
        echo [] !=? [1]
      ]], {1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1})
      ito('is/isnot', [[
        let l = ['a']
        let g = l
        let h = ['a']
        echo [] is []
        echo [] isnot []
        echo l is l
        echo l isnot l
        echo l is g
        echo l isnot g
        echo l is h
        echo l isnot h
        unlet l g h
      ]], {0, 1, 1, 0, 1, 0, 0, 1})
      ito('is/isnot (ic)', [[
        let l = ['a']
        let g = l
        let h = ['a']
        echo [] is? []
        echo [] isnot? []
        echo l is? l
        echo l isnot? l
        echo l is? g
        echo l isnot? g
        echo l is? h
        echo l isnot? h
        unlet l g h
      ]], {0, 1, 1, 0, 1, 0, 0, 1})
      ito('is/isnot (noic)', [[
        let l = ['a']
        let g = l
        let h = ['a']
        echo [] is# []
        echo [] isnot# []
        echo l is# l
        echo l isnot# l
        echo l is# g
        echo l isnot# g
        echo l is# h
        echo l isnot# h
        unlet l g h
      ]], {0, 1, 1, 0, 1, 0, 0, 1})
    end)
  end)
end)

describe('Dictionary tests', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  describe('Arithmetic operators', function()
    ito('Arithmetic operators', [[
      try
        echo {} + {}
      catch
        echo v:exception
      endtry
      try
        echo {} - {}
      catch
        echo v:exception
      endtry
      try
        echo {} * {}
      catch
        echo v:exception
      endtry
      try
        echo {} / {}
      catch
        echo v:exception
      endtry
      try
        echo {} % {}
      catch
        echo v:exception
      endtry
    ]], {
      'Vim(echo):E728: Using Dictionary as a Number',
      'Vim(echo):E728: Using Dictionary as a Number',
      'Vim(echo):E728: Using Dictionary as a Number',
      'Vim(echo):E728: Using Dictionary as a Number',
      'Vim(echo):E728: Using Dictionary as a Number',
    })
  end)
  describe('Concatenation', function()
    ito('Dictionary concatenation', [[
      try
        echo {} . {}
      catch
        echo v:exception
      endtry
    ]], {'Vim(echo):E731: Using Dictionary as a String'})
  end)
  describe('Dictionary comparison', function()
    describe('Less/greater (or equal to)', function()
      ito('LT/GT/LE/GE', [[
        try
          echo {} >  {}
        catch
          echo v:exception
        endtry
        try
          echo {} <  {}
        catch
          echo v:exception
        endtry
        try
          echo {} >= {}
        catch
          echo v:exception
        endtry
        try
          echo {} <= {}
        catch
          echo v:exception
        endtry
      ]], {
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
      })
      ito('LT/GT/LE/GE (ic)', [[
        try
          echo {} >?  {}
        catch
          echo v:exception
        endtry
        try
          echo {} <?  {}
        catch
          echo v:exception
        endtry
        try
          echo {} >=? {}
        catch
          echo v:exception
        endtry
        try
          echo {} <=? {}
        catch
          echo v:exception
        endtry
      ]], {
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
      })
      ito('LT/GT/LE/GE (noic)', [[
        try
          echo {} >#  {}
        catch
          echo v:exception
        endtry
        try
          echo {} <#  {}
        catch
          echo v:exception
        endtry
        try
          echo {} >=# {}
        catch
          echo v:exception
        endtry
        try
          echo {} <=# {}
        catch
          echo v:exception
        endtry
      ]], {
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
        'Vim(echo):E736: Invalid operation for Dictionaries',
      })
    end)
    describe('Equality and identity', function()
      ito('EQ (noic)', [[
        echo {1 : 'v'} ==# {'1' : 'v'}
        echo {'a': 2} ==# {'a': 2}
        echo {'a': 2, 'b': 3} ==# {'a': 2, 'b': 3}
        echo {'a': 2} ==# {'A': 2}
        echo {} ==# {'a': 2}
        echo {'a': 1} ==# {}
        echo {'a': 1, 'b': 2} ==# {'b': 2}
        echo {'a': 1, 'b': 2} ==# {'a': 1}
        echo {'a': 'A'} ==# {'a': 'a'}
        echo {'A': 'a'} ==# {'a': 'a'}
      ]], {1, 1, 1, 0, 0, 0, 0, 0, 0, 0})
      ito('NE (noic)', [[
        echo {1 : 'v'} !=# {'1' : 'v'}
        echo {'a': 2} !=# {'a': 2}
        echo {'a': 2, 'b': 3} !=# {'a': 2, 'b': 3}
        echo {'a': 2} !=# {'A': 2}
        echo {} !=# {'a': 2}
        echo {'a': 1} !=# {}
        echo {'a': 1, 'b': 2} !=# {'b': 2}
        echo {'a': 1, 'b': 2} !=# {'a': 1}
        echo {'a': 'A'} !=# {'a': 'a'}
        echo {'A': 'a'} !=# {'a': 'a'}
      ]], {0, 0, 0, 1, 1, 1, 1, 1, 1, 1})
      ito('EQ (ic)', [[
        echo {1 : 'v'} ==? {'1' : 'v'}
        echo {'a': 2} ==? {'a': 2}
        echo {'a': 2, 'b': 3} ==? {'a': 2, 'b': 3}
        echo {'a': 2} ==? {'A': 2}
        echo {} ==? {'a': 2}
        echo {'a': 1} ==? {}
        echo {'a': 1, 'b': 2} ==? {'b': 2}
        echo {'a': 1, 'b': 2} ==? {'a': 1}
        echo {'a': 'A'} ==? {'a': 'a'}
        echo {'A': 'a'} ==? {'a': 'a'}
      ]], {1, 1, 1, 0, 0, 0, 0, 0, 1, 0})
      ito('NE (ic)', [[
        echo {1 : 'v'} !=? {'1' : 'v'}
        echo {'a': 2} !=? {'a': 2}
        echo {'a': 2, 'b': 3} !=? {'a': 2, 'b': 3}
        echo {'a': 2} !=? {'A': 2}
        echo {} !=? {'a': 2}
        echo {'a': 1} !=? {}
        echo {'a': 1, 'b': 2} !=? {'b': 2}
        echo {'a': 1, 'b': 2} !=? {'a': 1}
        echo {'a': 'A'} !=? {'a': 'a'}
        echo {'A': 'a'} !=? {'a': 'a'}
      ]], {0, 0, 0, 1, 1, 1, 1, 1, 0, 1})
      ito('is/isnot', [[
        let l = {'1': 'a'}
        let g = l
        let h = {'1': 'a'}
        echo {} is {}
        echo {} isnot {}
        echo l is l
        echo l isnot l
        echo l is g
        echo l isnot g
        echo l is h
        echo l isnot h
        unlet l g h
      ]], {0, 1, 1, 0, 1, 0, 0, 1})
      ito('is/isnot (ic)', [[
        let l = {'1': 'a'}
        let g = l
        let h = {'1': 'a'}
        echo {} is? {}
        echo {} isnot? {}
        echo l is? l
        echo l isnot? l
        echo l is? g
        echo l isnot? g
        echo l is? h
        echo l isnot? h
        unlet l g h
      ]], {0, 1, 1, 0, 1, 0, 0, 1})
      ito('is?/isnot', [[
        let l = {'1': 'a'}
        let g = l
        let h = {'1': 'a'}
        echo {} is# {}
        echo {} isnot# {}
        echo l is# l
        echo l isnot# l
        echo l is# g
        echo l isnot# g
        echo l is# h
        echo l isnot# h
        unlet l g h
      ]], {0, 1, 1, 0, 1, 0, 0, 1})
      ito('EQ/NE, different nested types', [[
        try
          echo {'v': 1} == {'v': '1'}
          echo {'v': 1} == {'v': 1.0}
          echo {'v': 1} == {'v':  [] }
          echo {'v': 1} == {'v': {}}
          echo {'v': 1} == {'v': function('function')}

          echo {'v': '1'} == {'v': 1.0}
          echo {'v': '1'} == {'v':  [] }
          echo {'v': '1'} == {'v': {}}
          echo {'v': '1'} == {'v': function('function')}

          echo {'v': 1.0} == {'v':  [] }
          echo {'v': 1.0} == {'v': {}}
          echo {'v': 1.0} == {'v': function('function')}

          echo {'v': [] } == {'v': {}}
          echo {'v': [] } == {'v': function('function')}

          echo {'v': {}} == {'v': function('function')}
        catch
          echo v:exception
        endtry
      ]], {0, 0, 0, 0, 0,
           0, 0, 0, 0,
           0, 0, 0,
           0, 0,
           0})
      ito('EQ/NE, self-referencing dictionaries', [[
        let d = {'v': 0}
        let d.d = d
        let d2 = {'v': 0}
        let d2.d = d2
        let d3 = {'d': {'v': 0}, 'v': 0}
        let d3.d.d = d3

        echo d == d2
        echo d == d3
        echo d2 == d3

        let d3.d.v = 1
        echo d == d3
        echo d2 == d3

        unlet d d2 d3
      ]], {1, 1, 1, 0, 0})
      ito('EQ/NE, self-referencing dictionaries with lists', [[
        let d = {'l': [0, 0], 'v': 0}
        let d.l[0] = d.l
        let d.l[1] = d
        let d.d = d
        let d2 = {'l': [0, 0], 'v': 0}
        let d2.l[0] = d2.l
        let d2.l[1] = d2
        let d2.d = d2
        let d3 = {'l': [ [0, 1], {'l': [ [0, 0], 0], 'd': {'v': 0}, 'v':0}],'v':0}
        let d3.l[1].l[0][0] = d3.l
        let d3.l[0][0] = d3.l
        let d3.l[0][1] = d3.l[1]
        let d3.l[1].d.d = d3.l[1]
        let d3.l[1].l[0][0] = d3.l[1].l
        let d3.l[1].l[1] = d3.l[1]
        let d3.d = d3.l[1].d.d
        let d3.d.d.l = d3.l
        let d3.d.l[0][1] = d3.d.d.d

        echo d == d2
        echo d == d3
        echo d2 == d3

        unlet d d2 d3
      ]], {1, 1, 1})
    end)
  end)
end)

describe('Funcref computations', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  describe('Arithmetic operators', function()
    for _, op in ipairs({'+', '-', '*', '/', '%'}) do
      itoe(string.format('%s operator', op), {
        'let F = function("string")',
        string.format('echo F %s F', op),
        'unlet F'
      }, {
        'Vim(echo):E703: Using Funcref as a Number',
      })
    end
  end)
  describe('Concatenation', function()
    itoe('Concatenation', {
      'let F = function("string")',
      'echo F . F',
      'unlet F'
    }, {
      'Vim(echo):E729: Using Funcref as a String',
    })
  end)
  describe('Comparison operators', function()
    describe('Less/greater (or equal to)', function()
      for _, ic in ipairs({'', '#', '?'}) do
        for _, eq in ipairs({'', '='}) do
          for _, op in ipairs({'<', '>'}) do
            local real_op = op .. eq .. ic
            itoe(string.format('%s operator', real_op), {
              'let F = function("string")',
              string.format('echo F %s F', real_op),
              'unlet F'
            }, {
              'Vim(echo):E694: Invalid operation for Funcrefs',
            })
          end
        end
      end
    end)
    describe('Equality and identity', function()
      for _, op in ipairs({{eq='==', ne='!='}, {eq='is', ne='isnot'}}) do
        for _, ic in ipairs({'', '#', '?'}) do
          ito('EQ/NE', string.gsub(string.gsub([[
            let F1 = function("string")
            let F2 = function("function")
            let F3 = function("string")
            echo F1 {eq} F1
            echo F1 {ne} F1
            echo F1 {eq} F2
            echo F1 {ne} F2
            echo F1 {eq} F3
            echo F1 {ne} F3
            unlet F1 F2 F3
          ]], '{eq}', op.eq .. ic), '{ne}', op.ne .. ic),
          {1, 0, 0, 1, 1, 0})
        end
      end
    end)
  end)
end)

describe('Type conversions', function()
  local ito, itoe, f
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
    f = _obj_0.f
  end
  describe('Arithmetic operators', function()
    ito('+ operator, numbers', [[
      echo 1 + '1'
      echo '1' + 1
      echo 1 + 1.0
      echo 1.0 + 1
      echo '1' + 1.0
      echo 1.0 + '1'
    ]], {2, 2, f(2.0), f(2.0), f(2.0), f(2.0)})
    for _, op in ipairs({'+', '-', '*', '/', '%'}) do
      itoe(string.format('%s operator, containers', op), {
        string.format('echo 0 %s []', op),
        string.format('echo 0.0 %s []', op),
        string.format('echo "0" %s []', op),
        string.format('echo 0 %s {}', op),
        string.format('echo 0.0 %s {}', op),
        string.format('echo "0" %s {}', op),
        string.format('echo [] %s 0', op),
        string.format('echo [] %s 0.0', op),
        string.format('echo [] %s "0"', op),
        string.format('echo {} %s 0', op),
        string.format('echo {} %s 0.0', op),
        string.format('echo {} %s "0"', op),
        string.format('echo [] %s {}', op),
        string.format('echo {} %s []', op),
      }, {
        'Vim(echo):E745: Using List as a Number',
        'Vim(echo):E745: Using List as a Number',
        'Vim(echo):E745: Using List as a Number',
        'Vim(echo):E728: Using Dictionary as a Number',
        'Vim(echo):E728: Using Dictionary as a Number',
        'Vim(echo):E728: Using Dictionary as a Number',
        'Vim(echo):E745: Using List as a Number',
        'Vim(echo):E745: Using List as a Number',
        'Vim(echo):E745: Using List as a Number',
        'Vim(echo):E728: Using Dictionary as a Number',
        'Vim(echo):E728: Using Dictionary as a Number',
        'Vim(echo):E728: Using Dictionary as a Number',
        'Vim(echo):E745: Using List as a Number',
        'Vim(echo):E728: Using Dictionary as a Number',
      })
      itoe(string.format('%s operator, funcrefs', op), {
        'let F = function("string")',
        string.format('echo 0 %s F', op),
        string.format('echo 0.0 %s F', op),
        string.format('echo "0" %s F', op),
        string.format('echo [] %s F', op),
        string.format('echo {} %s F', op),
        string.format('echo F %s 0', op),
        string.format('echo F %s 0.0', op),
        string.format('echo F %s "0"', op),
        string.format('echo F %s []', op),
        string.format('echo F %s {}', op),
        'unlet F'
      }, {
        'Vim(echo):E703: Using Funcref as a Number',
        op == '%' and 'Vim(echo):E804: Cannot use \'%\' with Float'
                   or 'Vim(echo):E703: Using Funcref as a Number',
        'Vim(echo):E703: Using Funcref as a Number',
        'Vim(echo):E745: Using List as a Number',
        'Vim(echo):E728: Using Dictionary as a Number',
        'Vim(echo):E703: Using Funcref as a Number',
        op == '%' and 'Vim(echo):E804: Cannot use \'%\' with Float'
                   or 'Vim(echo):E703: Using Funcref as a Number',
        'Vim(echo):E703: Using Funcref as a Number',
        op == '+' and 'Vim(echo):E745: Using List as a Number'
                   or 'Vim(echo):E703: Using Funcref as a Number',
        'Vim(echo):E703: Using Funcref as a Number',
      })
    end
  end)
  describe('Concatenation', function()
    itoe('. operator, containers', {
      'echo 0 . []',
      'echo 0.0 . []',
      'echo "0" . []',
      'echo 0 . {}',
      'echo 0.0 . {}',
      'echo "0" . {}',
      'echo [] . 0',
      'echo [] . 0.0',
      'echo [] . "0"',
      'echo {} . 0',
      'echo {} . 0.0',
      'echo {} . "0"',
      'echo [] . {}',
      'echo {} . []',
    }, {
      'Vim(echo):E730: Using List as a String',
      'Vim(echo):E806: Using Float as a String',
      'Vim(echo):E730: Using List as a String',
      'Vim(echo):E731: Using Dictionary as a String',
      'Vim(echo):E806: Using Float as a String',
      'Vim(echo):E731: Using Dictionary as a String',
      'Vim(echo):E730: Using List as a String',
      'Vim(echo):E730: Using List as a String',
      'Vim(echo):E730: Using List as a String',
      'Vim(echo):E731: Using Dictionary as a String',
      'Vim(echo):E731: Using Dictionary as a String',
      'Vim(echo):E731: Using Dictionary as a String',
      'Vim(echo):E730: Using List as a String',
      'Vim(echo):E731: Using Dictionary as a String',
    })
    itoe(string.format('. operator, funcrefs', op), {
      'let F = function("string")',
      'echo 0 . F',
      'echo 0.0 . F',
      'echo "0" . F',
      'echo [] . F',
      'echo {} . F',
      'echo F . 0',
      'echo F . 0.0',
      'echo F . "0"',
      'echo F . []',
      'echo F . {}',
      'unlet F'
    }, {
      'Vim(echo):E729: Using Funcref as a String',
      'Vim(echo):E806: Using Float as a String',
      'Vim(echo):E729: Using Funcref as a String',
      'Vim(echo):E730: Using List as a String',
      'Vim(echo):E731: Using Dictionary as a String',
      'Vim(echo):E729: Using Funcref as a String',
      'Vim(echo):E729: Using Funcref as a String',
      'Vim(echo):E729: Using Funcref as a String',
      'Vim(echo):E729: Using Funcref as a String',
      'Vim(echo):E729: Using Funcref as a String',
    })
  end)
end)
