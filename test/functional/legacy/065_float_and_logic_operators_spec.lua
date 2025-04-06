-- Test for floating point and logical operators.

local n = require('test.functional.testnvim')()

local insert, source = n.insert, n.source
local clear, expect = n.clear, n.expect

describe('floating point and logical operators', function()
  setup(clear)

  it('is working', function()
    insert([=[
      Results of test65:]=])

    source([[
      $put =printf('%f', 123.456)
      $put =printf('%e', 123.456)
      $put =printf('%g', 123.456)
      " Check we don't crash on division by zero.
      echo 1.0 / 0.0
      $put ='+='
      let v = 1.234
      let v += 6.543
      $put =printf('%g', v)
      let v = 1.234
      let v += 5
      $put =printf('%g', v)
      let a = 5
      let a += 3.333
      $put =string(a)
      $put ='=='
      let v = 1.234
      $put =v == 1.234
      $put =v == 1.2341
      $put ='add-subtract'
      $put =printf('%g', 4 + 1.234)
      $put =printf('%g', 1.234 - 8)
      $put ='mult-div'
      $put =printf('%g', 4 * 1.234)
      $put =printf('%g', 4.0 / 1234)
      $put ='dict'
      $put =string({'x': 1.234, 'y': -2.0e20})
      $put ='list'
      $put =string([-123.4, 2.0e-20])
      $put ='abs'
      $put =printf('%d', abs(1456))
      $put =printf('%d', abs(-4))
      silent! $put =printf('%d', abs([1, 2, 3]))
      $put =printf('%g', abs(14.56))
      $put =printf('%g', abs(-54.32))
      $put ='ceil'
      $put =printf('%g', ceil(1.456))
      $put =printf('%g', ceil(-5.456))
      $put =printf('%g', ceil(-4.000))
      $put ='floor'
      $put =printf('%g', floor(1.856))
      $put =printf('%g', floor(-5.456))
      $put =printf('%g', floor(4.0))
      $put ='log10'
      $put =printf('%g', log10(1000))
      $put =printf('%g', log10(0.01000))
      $put ='pow'
      $put =printf('%g', pow(3, 3.0))
      $put =printf('%g', pow(2, 16))
      $put ='round'
      $put =printf('%g', round(0.456))
      $put =printf('%g', round(4.5))
      $put =printf('%g', round(-4.50))
      $put ='sqrt'
      $put =printf('%g', sqrt(100))
      echo sqrt(-4.01)
      $put ='str2float'
      $put =printf('%g', str2float('1e40'))
      $put ='trunc'
      $put =printf('%g', trunc(1.456))
      $put =printf('%g', trunc(-5.456))
      $put =printf('%g', trunc(4.000))
      $put ='float2nr'
      $put =float2nr(123.456)
      $put =float2nr(-123.456)
      $put ='AND'
      $put =and(127, 127)
      $put =and(127, 16)
      $put =and(127, 128)
      $put ='OR'
      $put =or(16, 7)
      $put =or(8, 7)
      $put =or(0, 123)
      $put ='XOR'
      $put =xor(127, 127)
      $put =xor(127, 16)
      $put =xor(127, 128)
      $put ='invert'
      $put =and(invert(127), 65535)
      $put =and(invert(16), 65535)
      $put =and(invert(128), 65535)
      silent! $put =invert(1.0)
    ]])

    -- Assert buffer contents.
    expect([=[
      Results of test65:
      123.456000
      1.234560e+02
      123.456
      +=
      7.777
      6.234
      8.333
      ==
      1
      0
      add-subtract
      5.234
      -6.766
      mult-div
      4.936
      0.003241
      dict
      {'x': 1.234, 'y': -2.0e20}
      list
      [-123.4, 2.0e-20]
      abs
      1456
      4
      -1
      14.56
      54.32
      ceil
      2.0
      -5.0
      -4.0
      floor
      1.0
      -6.0
      4.0
      log10
      3.0
      -2.0
      pow
      27.0
      65536.0
      round
      0.0
      5.0
      -5.0
      sqrt
      10.0
      str2float
      1.0e40
      trunc
      1.0
      -5.0
      4.0
      float2nr
      123
      -123
      AND
      127
      16
      0
      OR
      23
      15
      123
      XOR
      0
      111
      255
      invert
      65408
      65519
      65407
      0]=])
  end)
end)
