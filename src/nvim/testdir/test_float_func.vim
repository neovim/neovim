" test float functions

if !has('float')
  finish
end

func Test_abs()
  call assert_equal('1.23', string(abs(1.23)))
  call assert_equal('1.23', string(abs(-1.23)))
  call assert_equal('0.0', string(abs(0.0)))
  call assert_equal('0.0', string(abs(1.0/(1.0/0.0))))
  call assert_equal('0.0', string(abs(-1.0/(1.0/0.0))))
  call assert_equal("str2float('inf')", string(abs(1.0/0.0)))
  call assert_equal("str2float('inf')", string(abs(-1.0/0.0)))
  call assert_equal("str2float('nan')", string(abs(0.0/0.0)))
  call assert_equal('12', string(abs('-12abc')))
  call assert_fails("call abs([])", 'E745:')
  call assert_fails("call abs({})", 'E728:')
  call assert_fails("call abs(function('string'))", 'E703:')
endfunc

func Test_sqrt()
  call assert_equal('0.0', string(sqrt(0.0)))
  call assert_equal('1.414214', string(sqrt(2.0)))
  call assert_equal("str2float('inf')", string(sqrt(1.0/0.0)))
  call assert_equal("str2float('nan')", string(sqrt(-1.0)))
  call assert_equal("str2float('nan')", string(sqrt(0.0/0.0)))
  call assert_fails('call sqrt("")', 'E808:')
endfunc

func Test_log()
  call assert_equal('0.0', string(log(1.0)))
  call assert_equal('-0.693147', string(log(0.5)))
  call assert_equal("-str2float('inf')", string(log(0.0)))
  call assert_equal("str2float('nan')", string(log(-1.0)))
  call assert_equal("str2float('inf')", string(log(1.0/0.0)))
  call assert_equal("str2float('nan')", string(log(0.0/0.0)))
  call assert_fails('call log("")', 'E808:')
endfunc

func Test_log10()
  call assert_equal('0.0', string(log10(1.0)))
  call assert_equal('2.0', string(log10(100.0)))
  call assert_equal('2.079181', string(log10(120.0)))
  call assert_equal("-str2float('inf')", string(log10(0.0)))
  call assert_equal("str2float('nan')", string(log10(-1.0)))
  call assert_equal("str2float('inf')", string(log10(1.0/0.0)))
  call assert_equal("str2float('nan')", string(log10(0.0/0.0)))
  call assert_fails('call log10("")', 'E808:')
endfunc

func Test_exp()
  call assert_equal('1.0', string(exp(0.0)))
  call assert_equal('7.389056', string(exp(2.0)))
  call assert_equal('0.367879', string(exp(-1.0)))
  call assert_equal("str2float('inf')", string(exp(1.0/0.0)))
  call assert_equal('0.0', string(exp(-1.0/0.0)))
  call assert_equal("str2float('nan')", string(exp(0.0/0.0)))
  call assert_fails('call exp("")', 'E808:')
endfunc

func Test_sin()
  call assert_equal('0.0', string(sin(0.0)))
  call assert_equal('0.841471', string(sin(1.0)))
  call assert_equal('-0.479426', string(sin(-0.5)))
  call assert_equal("str2float('nan')", string(sin(0.0/0.0)))
  call assert_equal("str2float('nan')", string(sin(1.0/0.0)))
  call assert_equal('0.0', string(sin(1.0/(1.0/0.0))))
  call assert_equal('-0.0', string(sin(-1.0/(1.0/0.0))))
  call assert_fails('call sin("")', 'E808:')
endfunc

func Test_asin()
  call assert_equal('0.0', string(asin(0.0)))
  call assert_equal('1.570796', string(asin(1.0)))
  call assert_equal('-0.523599', string(asin(-0.5)))
  call assert_equal("str2float('nan')", string(asin(1.1)))
  call assert_equal("str2float('nan')", string(asin(1.0/0.0)))
  call assert_equal("str2float('nan')", string(asin(0.0/0.0)))
  call assert_fails('call asin("")', 'E808:')
endfunc

func Test_sinh()
  call assert_equal('0.0', string(sinh(0.0)))
  call assert_equal('0.521095', string(sinh(0.5)))
  call assert_equal('-1.026517', string(sinh(-0.9)))
  call assert_equal("str2float('inf')", string(sinh(1.0/0.0)))
  call assert_equal("-str2float('inf')", string(sinh(-1.0/0.0)))
  call assert_equal("str2float('nan')", string(sinh(0.0/0.0)))
  call assert_fails('call sinh("")', 'E808:')
endfunc

func Test_cos()
  call assert_equal('1.0', string(cos(0.0)))
  call assert_equal('0.540302', string(cos(1.0)))
  call assert_equal('0.877583', string(cos(-0.5)))
  call assert_equal("str2float('nan')", string(cos(0.0/0.0)))
  call assert_equal("str2float('nan')", string(cos(1.0/0.0)))
  call assert_fails('call cos("")', 'E808:')
endfunc

func Test_acos()
  call assert_equal('1.570796', string(acos(0.0)))
  call assert_equal('0.0', string(acos(1.0)))
  call assert_equal('3.141593', string(acos(-1.0)))
  call assert_equal('2.094395', string(acos(-0.5)))
  call assert_equal("str2float('nan')", string(acos(1.1)))
  call assert_equal("str2float('nan')", string(acos(1.0/0.0)))
  call assert_equal("str2float('nan')", string(acos(0.0/0.0)))
  call assert_fails('call acos("")', 'E808:')
endfunc

func Test_cosh()
  call assert_equal('1.0', string(cosh(0.0)))
  call assert_equal('1.127626', string(cosh(0.5)))
  call assert_equal("str2float('inf')", string(cosh(1.0/0.0)))
  call assert_equal("str2float('inf')", string(cosh(-1.0/0.0)))
  call assert_equal("str2float('nan')", string(cosh(0.0/0.0)))
  call assert_fails('call cosh("")', 'E808:')
endfunc

func Test_tan()
  call assert_equal('0.0', string(tan(0.0)))
  call assert_equal('0.546302', string(tan(0.5)))
  call assert_equal('-0.546302', string(tan(-0.5)))
  call assert_equal("str2float('nan')", string(tan(1.0/0.0)))
  call assert_equal("str2float('nan')", string(cos(0.0/0.0)))
  call assert_equal('0.0', string(tan(1.0/(1.0/0.0))))
  call assert_equal('-0.0', string(tan(-1.0/(1.0/0.0))))
  call assert_fails('call tan("")', 'E808:')
endfunc

func Test_atan()
  call assert_equal('0.0', string(atan(0.0)))
  call assert_equal('0.463648', string(atan(0.5)))
  call assert_equal('-0.785398', string(atan(-1.0)))
  call assert_equal('1.570796', string(atan(1.0/0.0)))
  call assert_equal('-1.570796', string(atan(-1.0/0.0)))
  call assert_equal("str2float('nan')", string(atan(0.0/0.0)))
  call assert_fails('call atan("")', 'E808:')
endfunc

func Test_atan2()
  call assert_equal('-2.356194', string(atan2(-1, -1)))
  call assert_equal('2.356194', string(atan2(1, -1)))
  call assert_equal('0.0', string(atan2(1.0, 1.0/0.0)))
  call assert_equal('1.570796', string(atan2(1.0/0.0, 1.0)))
  call assert_equal("str2float('nan')", string(atan2(0.0/0.0, 1.0)))
  call assert_fails('call atan2("", -1)', 'E808:')
  call assert_fails('call atan2(-1, "")', 'E808:')
endfunc

func Test_tanh()
  call assert_equal('0.0', string(tanh(0.0)))
  call assert_equal('0.462117', string(tanh(0.5)))
  call assert_equal('-0.761594', string(tanh(-1.0)))
  call assert_equal('1.0', string(tanh(1.0/0.0)))
  call assert_equal('-1.0', string(tanh(-1.0/0.0)))
  call assert_equal("str2float('nan')", string(tanh(0.0/0.0)))
  call assert_fails('call tanh("")', 'E808:')
endfunc

func Test_fmod()
  call assert_equal('0.13', string(fmod(12.33, 1.22)))
  call assert_equal('-0.13', string(fmod(-12.33, 1.22)))
  call assert_equal("str2float('nan')", string(fmod(1.0/0.0, 1.0)))
  " On Windows we get "nan" instead of 1.0, accept both.
  let res = string(fmod(1.0, 1.0/0.0))
  if res != "str2float('nan')"
    call assert_equal('1.0', res)
  endif
  call assert_equal("str2float('nan')", string(fmod(1.0, 0.0)))
  call assert_fails("call fmod('', 1.22)", 'E808:')
  call assert_fails("call fmod(12.33, '')", 'E808:')
endfunc

func Test_pow()
  call assert_equal('1.0', string(pow(0.0, 0.0)))
  call assert_equal('8.0', string(pow(2.0, 3.0)))
  call assert_equal("str2float('nan')", string(pow(2.0, 0.0/0.0)))
  call assert_equal("str2float('nan')", string(pow(0.0/0.0, 3.0)))
  call assert_equal("str2float('nan')", string(pow(0.0/0.0, 3.0)))
  call assert_equal("str2float('inf')", string(pow(2.0, 1.0/0.0)))
  call assert_equal("str2float('inf')", string(pow(1.0/0.0, 3.0)))
  call assert_fails("call pow('', 2.0)", 'E808:')
  call assert_fails("call pow(2.0, '')", 'E808:')
endfunc

func Test_str2float()
  call assert_equal('1.0', string(str2float('1')))
  call assert_equal('1.0', string(str2float(' 1 ')))
  call assert_equal('1.0', string(str2float(' 1.0 ')))
  call assert_equal('1.23', string(str2float('1.23')))
  call assert_equal('1.23', string(str2float('1.23abc')))
  call assert_equal('1.0e40', string(str2float('1e40')))
  call assert_equal('-1.23', string(str2float('-1.23')))
  call assert_equal('1.23', string(str2float(' + 1.23 ')))

  call assert_equal('1.0', string(str2float('+1')))
  call assert_equal('1.0', string(str2float('+1')))
  call assert_equal('1.0', string(str2float(' +1 ')))
  call assert_equal('1.0', string(str2float(' + 1 ')))

  call assert_equal('-1.0', string(str2float('-1')))
  call assert_equal('-1.0', string(str2float('-1')))
  call assert_equal('-1.0', string(str2float(' -1 ')))
  call assert_equal('-1.0', string(str2float(' - 1 ')))

  call assert_equal('0.0', string(str2float('+0.0')))
  call assert_equal('-0.0', string(str2float('-0.0')))
  call assert_equal("str2float('inf')", string(str2float('1e1000')))
  call assert_equal("str2float('inf')", string(str2float('inf')))
  call assert_equal("-str2float('inf')", string(str2float('-inf')))
  call assert_equal("str2float('inf')", string(str2float('+inf')))
  call assert_equal("str2float('inf')", string(str2float('Inf')))
  call assert_equal("str2float('inf')", string(str2float('  +inf  ')))
  call assert_equal("str2float('nan')", string(str2float('nan')))
  call assert_equal("str2float('nan')", string(str2float('NaN')))
  call assert_equal("str2float('nan')", string(str2float('  nan  ')))

  call assert_fails("call str2float(1.2)", 'E806:')
  call assert_fails("call str2float([])", 'E730:')
  call assert_fails("call str2float({})", 'E731:')
  call assert_fails("call str2float(function('string'))", 'E729:')
endfunc

func Test_float2nr()
  call assert_equal(1, float2nr(1.234))
  call assert_equal(123, float2nr(1.234e2))
  call assert_equal(12, float2nr(123.4e-1))
  let max_number = 1/0
  let min_number = -max_number
  call assert_equal(max_number/2+1, float2nr(pow(2, 62)))
  call assert_equal(max_number, float2nr(pow(2, 63)))
  call assert_equal(max_number, float2nr(pow(2, 64)))
  call assert_equal(min_number/2-1, float2nr(-pow(2, 62)))
  call assert_equal(min_number, float2nr(-pow(2, 63)))
  call assert_equal(min_number, float2nr(-pow(2, 64)))
endfunc

func Test_floor()
  call assert_equal('2.0', string(floor(2.0)))
  call assert_equal('2.0', string(floor(2.11)))
  call assert_equal('2.0', string(floor(2.99)))
  call assert_equal('-3.0', string(floor(-2.11)))
  call assert_equal('-3.0', string(floor(-2.99)))
  call assert_equal("str2float('nan')", string(floor(0.0/0.0)))
  call assert_equal("str2float('inf')", string(floor(1.0/0.0)))
  call assert_equal("-str2float('inf')", string(floor(-1.0/0.0)))
  call assert_fails("call floor('')", 'E808:')
endfunc

func Test_ceil()
  call assert_equal('2.0', string(ceil(2.0)))
  call assert_equal('3.0', string(ceil(2.11)))
  call assert_equal('3.0', string(ceil(2.99)))
  call assert_equal('-2.0', string(ceil(-2.11)))
  call assert_equal('-2.0', string(ceil(-2.99)))
  call assert_equal("str2float('nan')", string(ceil(0.0/0.0)))
  call assert_equal("str2float('inf')", string(ceil(1.0/0.0)))
  call assert_equal("-str2float('inf')", string(ceil(-1.0/0.0)))
  call assert_fails("call ceil('')", 'E808:')
endfunc

func Test_round()
  call assert_equal('2.0', string(round(2.1)))
  call assert_equal('3.0', string(round(2.5)))
  call assert_equal('3.0', string(round(2.9)))
  call assert_equal('-2.0', string(round(-2.1)))
  call assert_equal('-3.0', string(round(-2.5)))
  call assert_equal('-3.0', string(round(-2.9)))
  call assert_equal("str2float('nan')", string(round(0.0/0.0)))
  call assert_equal("str2float('inf')", string(round(1.0/0.0)))
  call assert_equal("-str2float('inf')", string(round(-1.0/0.0)))
  call assert_fails("call round('')", 'E808:')
endfunc

func Test_trunc()
  call assert_equal('2.0', string(trunc(2.1)))
  call assert_equal('2.0', string(trunc(2.5)))
  call assert_equal('2.0', string(trunc(2.9)))
  call assert_equal('-2.0', string(trunc(-2.1)))
  call assert_equal('-2.0', string(trunc(-2.5)))
  call assert_equal('-2.0', string(trunc(-2.9)))
  call assert_equal("str2float('nan')", string(trunc(0.0/0.0)))
  call assert_equal("str2float('inf')", string(trunc(1.0/0.0)))
  call assert_equal("-str2float('inf')", string(trunc(-1.0/0.0)))
  call assert_fails("call trunc('')", 'E808:')
endfunc

func Test_isnan()
  throw 'skipped: Nvim does not support isnan()'
  call assert_equal(0, isnan(1.0))
  call assert_equal(1, isnan(0.0/0.0))
  call assert_equal(0, isnan(1.0/0.0))
  call assert_equal(0, isnan('a'))
  call assert_equal(0, isnan([]))
  call assert_equal(0, isnan({}))
endfunc

" This was converted from test65
func Test_float_misc()
  call assert_equal('123.456000', printf('%f', 123.456))
  call assert_equal('1.234560e+02', printf('%e', 123.456))
  call assert_equal('123.456', printf('%g', 123.456))
  " +=
  let v = 1.234
  let v += 6.543
  call assert_equal('7.777', printf('%g', v))
  let v = 1.234
  let v += 5
  call assert_equal('6.234', printf('%g', v))
  let v = 5
  let v += 3.333
  call assert_equal('8.333', string(v))
  " ==
  let v = 1.234
  call assert_true(v == 1.234)
  call assert_false(v == 1.2341)
  " add-subtract
  call assert_equal('5.234', printf('%g', 4 + 1.234))
  call assert_equal('-6.766', printf('%g', 1.234 - 8))
  " mult-div
  call assert_equal('4.936', printf('%g', 4 * 1.234))
  call assert_equal('0.003241', printf('%g', 4.0 / 1234))
  " dict
  call assert_equal("{'x': 1.234, 'y': -2.0e20}", string({'x': 1.234, 'y': -2.0e20}))
  " list
  call assert_equal('[-123.4, 2.0e-20]', string([-123.4, 2.0e-20]))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
