" test float functions

if !has('float')
  finish
end

func Test_abs()
  call assert_equal(string(abs(1.23)), '1.23')
  call assert_equal(string(abs(-1.23)), '1.23')
  call assert_equal(string(abs(0.0)), '0.0')
  call assert_equal(string(abs(1.0/(1.0/0.0))), '0.0')
  call assert_equal(string(abs(-1.0/(1.0/0.0))), '0.0')
  call assert_equal(string(abs(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(abs(-1.0/0.0)), "str2float('inf')")
  call assert_equal(string(abs(0.0/0.0)), "str2float('nan')")
endfunc

func Test_sqrt()
  call assert_equal(string(sqrt(0.0)), '0.0')
  call assert_equal(string(sqrt(2.0)), '1.414214')
  call assert_equal(string(sqrt(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(sqrt(-1.0)), "str2float('nan')")
  call assert_equal(string(sqrt(0.0/0.0)), "str2float('nan')")
endfunc

func Test_log()
  call assert_equal(string(log(1.0)), '0.0')
  call assert_equal(string(log(0.5)), '-0.693147')
  call assert_equal(string(log(0.0)), "-str2float('inf')")
  call assert_equal(string(log(-1.0)), "str2float('nan')")
  call assert_equal(string(log(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(log(0.0/0.0)), "str2float('nan')")
endfunc

func Test_log10()
  call assert_equal(string(log10(1.0)), '0.0')
  call assert_equal(string(log10(100.0)), '2.0')
  call assert_equal(string(log10(120.0)), '2.079181')
  call assert_equal(string(log10(0.0)), "-str2float('inf')")
  call assert_equal(string(log10(-1.0)), "str2float('nan')")
  call assert_equal(string(log10(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(log10(0.0/0.0)), "str2float('nan')")
endfunc

func Test_exp()
  call assert_equal(string(exp(0.0)), '1.0')
  call assert_equal(string(exp(2.0)), '7.389056')
  call assert_equal(string(exp(-1.0)),'0.367879')
  call assert_equal(string(exp(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(exp(-1.0/0.0)), '0.0')
  call assert_equal(string(exp(0.0/0.0)), "str2float('nan')")
endfunc

func Test_sin()
  call assert_equal(string(sin(0.0)), '0.0')
  call assert_equal(string(sin(1.0)), '0.841471')
  call assert_equal(string(sin(-0.5)), '-0.479426')
  call assert_equal(string(sin(0.0/0.0)), "str2float('nan')")
  call assert_equal(string(sin(1.0/0.0)), "str2float('nan')")
  call assert_equal(string(sin(1.0/(1.0/0.0))), '0.0')
  call assert_equal(string(sin(-1.0/(1.0/0.0))), '-0.0')
endfunc

func Test_asin()
  call assert_equal(string(asin(0.0)), '0.0')
  call assert_equal(string(asin(1.0)), '1.570796')
  call assert_equal(string(asin(-0.5)), '-0.523599')
  call assert_equal(string(asin(1.1)), "str2float('nan')")
  call assert_equal(string(asin(1.0/0.0)), "str2float('nan')")
  call assert_equal(string(asin(0.0/0.0)), "str2float('nan')")
endfunc

func Test_sinh()
  call assert_equal(string(sinh(0.0)), '0.0')
  call assert_equal(string(sinh(0.5)), '0.521095')
  call assert_equal(string(sinh(-0.9)), '-1.026517')
  call assert_equal(string(sinh(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(sinh(-1.0/0.0)), "-str2float('inf')")
  call assert_equal(string(sinh(0.0/0.0)), "str2float('nan')")
endfunc

func Test_cos()
  call assert_equal(string(cos(0.0)), '1.0')
  call assert_equal(string(cos(1.0)), '0.540302')
  call assert_equal(string(cos(-0.5)), '0.877583')
  call assert_equal(string(cos(0.0/0.0)), "str2float('nan')")
  call assert_equal(string(cos(1.0/0.0)), "str2float('nan')")
endfunc

func Test_acos()
  call assert_equal(string(acos(0.0)), '1.570796')
  call assert_equal(string(acos(1.0)), '0.0')
  call assert_equal(string(acos(-1.0)), '3.141593')
  call assert_equal(string(acos(-0.5)), '2.094395')
  call assert_equal(string(acos(1.1)), "str2float('nan')")
  call assert_equal(string(acos(1.0/0.0)), "str2float('nan')")
  call assert_equal(string(acos(0.0/0.0)), "str2float('nan')")
endfunc

func Test_cosh()
  call assert_equal(string(cosh(0.0)), '1.0')
  call assert_equal(string(cosh(0.5)), '1.127626')
  call assert_equal(string(cosh(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(cosh(-1.0/0.0)), "str2float('inf')")
  call assert_equal(string(cosh(0.0/0.0)), "str2float('nan')")
endfunc

func Test_tan()
  call assert_equal(string(tan(0.0)), '0.0')
  call assert_equal(string(tan(0.5)), '0.546302')
  call assert_equal(string(tan(-0.5)), '-0.546302')
  call assert_equal(string(tan(1.0/0.0)), "str2float('nan')")
  call assert_equal(string(cos(0.0/0.0)), "str2float('nan')")
  call assert_equal(string(tan(1.0/(1.0/0.0))), '0.0')
  call assert_equal(string(tan(-1.0/(1.0/0.0))), '-0.0')
endfunc

func Test_atan()
  call assert_equal(string(atan(0.0)), '0.0')
  call assert_equal(string(atan(0.5)), '0.463648')
  call assert_equal(string(atan(-1.0)), '-0.785398')
  call assert_equal(string(atan(1.0/0.0)), '1.570796')
  call assert_equal(string(atan(-1.0/0.0)), '-1.570796')
  call assert_equal(string(atan(0.0/0.0)), "str2float('nan')")
endfunc

func Test_atan2()
  call assert_equal(string(atan2(-1, -1)), '-2.356194')
  call assert_equal(string(atan2(1, -1)), '2.356194')
  call assert_equal(string(atan2(1.0, 1.0/0.0)), '0.0')
  call assert_equal(string(atan2(1.0/0.0, 1.0)), '1.570796')
  call assert_equal(string(atan2(0.0/0.0, 1.0)), "str2float('nan')")
endfunc

func Test_tanh()
  call assert_equal(string(tanh(0.0)), '0.0')
  call assert_equal(string(tanh(0.5)), '0.462117')
  call assert_equal(string(tanh(-1.0)), '-0.761594')
  call assert_equal(string(tanh(1.0/0.0)), '1.0')
  call assert_equal(string(tanh(-1.0/0.0)), '-1.0')
  call assert_equal(string(tanh(0.0/0.0)), "str2float('nan')")
endfunc

func Test_fmod()
  call assert_equal(string(fmod(12.33, 1.22)), '0.13')
  call assert_equal(string(fmod(-12.33, 1.22)), '-0.13')
  call assert_equal(string(fmod(1.0/0.0, 1.0)), "str2float('nan')")
  call assert_equal(string(fmod(1.0, 1.0/0.0)), '1.0')
  call assert_equal(string(fmod(1.0, 0.0)), "str2float('nan')")
endfunc

func Test_pow()
  call assert_equal(string(pow(0.0, 0.0)), '1.0')
  call assert_equal(string(pow(2.0, 3.0)), '8.0')
  call assert_equal(string(pow(2.0, 0.0/0.0)), "str2float('nan')")
  call assert_equal(string(pow(0.0/0.0, 3.0)), "str2float('nan')")
  call assert_equal(string(pow(0.0/0.0, 3.0)), "str2float('nan')")
  call assert_equal(string(pow(2.0, 1.0/0.0)), "str2float('inf')")
  call assert_equal(string(pow(1.0/0.0, 3.0)), "str2float('inf')")
endfunc

func Test_str2float()
  call assert_equal(string(str2float('1')), '1.0')
  call assert_equal(string(str2float('1.23')), '1.23')
  call assert_equal(string(str2float('1.23abc')), '1.23')
  call assert_equal(string(str2float('1e40')), '1.0e40')
  call assert_equal(string(str2float('1e1000')), "str2float('inf')")
  call assert_equal(string(str2float('inf')), "str2float('inf')")
  call assert_equal(string(str2float('-inf')), "-str2float('inf')")
  call assert_equal(string(str2float('Inf')), "str2float('inf')")
  call assert_equal(string(str2float('nan')), "str2float('nan')")
  call assert_equal(string(str2float('NaN')), "str2float('nan')")
endfunc

func Test_floor()
  call assert_equal(string(floor(2.0)), '2.0')
  call assert_equal(string(floor(2.11)), '2.0')
  call assert_equal(string(floor(2.99)), '2.0')
  call assert_equal(string(floor(-2.11)), '-3.0')
  call assert_equal(string(floor(-2.99)), '-3.0')
  call assert_equal(string(floor(0.0/0.0)), "str2float('nan')")
  call assert_equal(string(floor(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(floor(-1.0/0.0)), "-str2float('inf')")
endfunc

func Test_ceil()
  call assert_equal(string(ceil(2.0)), '2.0')
  call assert_equal(string(ceil(2.11)), '3.0')
  call assert_equal(string(ceil(2.99)), '3.0')
  call assert_equal(string(ceil(-2.11)), '-2.0')
  call assert_equal(string(ceil(-2.99)), '-2.0')
  call assert_equal(string(ceil(0.0/0.0)), "str2float('nan')")
  call assert_equal(string(ceil(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(ceil(-1.0/0.0)), "-str2float('inf')")
endfunc

func Test_round()
  call assert_equal(string(round(2.1)), '2.0')
  call assert_equal(string(round(2.5)), '3.0')
  call assert_equal(string(round(2.9)), '3.0')
  call assert_equal(string(round(-2.1)), '-2.0')
  call assert_equal(string(round(-2.5)), '-3.0')
  call assert_equal(string(round(-2.9)), '-3.0')
  call assert_equal(string(round(0.0/0.0)), "str2float('nan')")
  call assert_equal(string(round(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(round(-1.0/0.0)), "-str2float('inf')")
endfunc

func Test_trunc()
  call assert_equal(string(trunc(2.1)), '2.0')
  call assert_equal(string(trunc(2.5)), '2.0')
  call assert_equal(string(trunc(2.9)), '2.0')
  call assert_equal(string(trunc(-2.1)), '-2.0')
  call assert_equal(string(trunc(-2.5)), '-2.0')
  call assert_equal(string(trunc(-2.9)), '-2.0')
  call assert_equal(string(trunc(0.0/0.0)), "str2float('nan')")
  call assert_equal(string(trunc(1.0/0.0)), "str2float('inf')")
  call assert_equal(string(trunc(-1.0/0.0)), "-str2float('inf')")
endfunc

func Test_isnan()
  throw 'skipped: Nvim does not support isnan()'
  call assert_equal(isnan(1.0), 0)
  call assert_equal(isnan(0.0/0.0), 1)
  call assert_equal(isnan(1.0/0.0), 0)
  call assert_equal(isnan('a'), 0)
  call assert_equal(isnan([]), 0)
endfunc
