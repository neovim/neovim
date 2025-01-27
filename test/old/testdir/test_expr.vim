" Tests for expressions.

source check.vim
source vim9.vim

func Test_equal()
  let base = {}
  func base.method()
    return 1
  endfunc
  func base.other() dict
    return 1
  endfunc
  let instance = copy(base)
  call assert_true(base.method == instance.method)
  call assert_true([base.method] == [instance.method])
  call assert_true(base.other == instance.other)
  call assert_true([base.other] == [instance.other])

  call assert_false(base.method == base.other)
  call assert_false([base.method] == [base.other])
  call assert_false(base.method == instance.other)
  call assert_false([base.method] == [instance.other])

  call assert_fails('echo base.method > instance.method')
  " Nvim doesn't have null functions
  " call assert_equal(0, test_null_function() == function('min'))
  " call assert_equal(1, test_null_function() == test_null_function())
  " Nvim doesn't have test_unknown()
  " call assert_fails('eval 10 == test_unknown()', 'E685:')
endfunc

func Test_version()
  call assert_true(has('patch-7.4.001'))
  call assert_true(has('patch-7.4.01'))
  call assert_true(has('patch-7.4.1'))
  call assert_true(has('patch-6.9.999'))
  call assert_true(has('patch-7.1.999'))
  call assert_true(has('patch-7.4.123'))

  call assert_false(has('patch-7'))
  call assert_false(has('patch-7.4'))
  call assert_false(has('patch-7.4.'))
  call assert_false(has('patch-9.1.0'))
  call assert_false(has('patch-9.9.1'))
endfunc

func Test_op_ternary()
  let lines =<< trim END
      call assert_equal('yes', 1 ? 'yes' : 'no')
      call assert_equal('no', 0 ? 'yes' : 'no')

      call assert_fails('echo [1] ? "yes" : "no"', 'E745:')
      call assert_fails('echo {} ? "yes" : "no"', 'E728:')
  END
  call CheckLegacyAndVim9Success(lines)

  call assert_equal('no', 'x' ? 'yes' : 'no')
  call CheckDefAndScriptFailure(["'x' ? 'yes' : 'no'"], 'E1135:')
  call assert_equal('yes', '1x' ? 'yes' : 'no')
  call CheckDefAndScriptFailure(["'1x' ? 'yes' : 'no'"], 'E1135:')
endfunc

func Test_op_falsy()
  let lines =<< trim END
      call assert_equal(v:true, v:true ?? 456)
      call assert_equal(123, 123 ?? 456)
      call assert_equal('yes', 'yes' ?? 456)
      call assert_equal(0z00, 0z00 ?? 456)
      call assert_equal([1], [1] ?? 456)
      call assert_equal({'one': 1}, {'one': 1} ?? 456)
      call assert_equal(0.1, 0.1 ?? 456)

      call assert_equal(456, v:false ?? 456)
      call assert_equal(456, 0 ?? 456)
      call assert_equal(456, '' ?? 456)
      call assert_equal(456, 0z ?? 456)
      call assert_equal(456, [] ?? 456)
      call assert_equal(456, {} ?? 456)
      call assert_equal(456, 0.0 ?? 456)

      call assert_equal(456, v:null ?? 456)
      #" call assert_equal(456, v:none ?? 456)
      call assert_equal(456, v:_null_string ?? 456)
      call assert_equal(456, v:_null_blob ?? 456)
      call assert_equal(456, v:_null_list ?? 456)
      call assert_equal(456, v:_null_dict ?? 456)
      #" Nvim doesn't have null functions
      #" call assert_equal(456, test_null_function() ?? 456)
      #" Nvim doesn't have null partials
      #" call assert_equal(456, test_null_partial() ?? 456)
      if has('job')
        call assert_equal(456, test_null_job() ?? 456)
      endif
      if has('channel')
        call assert_equal(456, test_null_channel() ?? 456)
      endif
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_dict()
  let lines =<< trim END
      VAR d = {'': 'empty', 'a': 'a', 0: 'zero'}
      call assert_equal('empty', d[''])
      call assert_equal('a', d['a'])
      call assert_equal('zero', d[0])
      call assert_true(has_key(d, ''))
      call assert_true(has_key(d, 'a'))

      LET d[''] = 'none'
      LET d['a'] = 'aaa'
      call assert_equal('none', d[''])
      call assert_equal('aaa', d['a'])

      LET d[ 'b' ] = 'bbb'
      call assert_equal('bbb', d[ 'b' ])
  END
  call CheckLegacyAndVim9Success(lines)

  call CheckLegacyAndVim9Failure(["VAR i = has_key([], 'a')"], ['E1206:', 'E1013:', 'E1206:'])
endfunc

func Test_strgetchar()
  let lines =<< trim END
      call assert_equal(char2nr('a'), strgetchar('axb', 0))
      call assert_equal(char2nr('x'), 'axb'->strgetchar(1))
      call assert_equal(char2nr('b'), strgetchar('axb', 2))

      call assert_equal(-1, strgetchar('axb', -1))
      call assert_equal(-1, strgetchar('axb', 3))
      call assert_equal(-1, strgetchar('', 0))
  END
  call CheckLegacyAndVim9Success(lines)

  call CheckLegacyAndVim9Failure(["VAR c = strgetchar([], 1)"], ['E730:', 'E1013:', 'E1174:'])
  call CheckLegacyAndVim9Failure(["VAR c = strgetchar('axb', [])"], ['E745:', 'E1013:', 'E1210:'])
endfunc

func Test_strcharpart()
  let lines =<< trim END
      call assert_equal('a', strcharpart('axb', 0, 1))
      call assert_equal('x', 'axb'->strcharpart(1, 1))
      call assert_equal('b', strcharpart('axb', 2, 1))
      call assert_equal('xb', strcharpart('axb', 1))

      call assert_equal('', strcharpart('axb', 1, 0))
      call assert_equal('', strcharpart('axb', 1, -1))
      call assert_equal('', strcharpart('axb', -1, 1))
      call assert_equal('', strcharpart('axb', -2, 2))

      call assert_equal('a', strcharpart('axb', -1, 2))

      call assert_equal('edit', "editor"[-10 : 3])
  END
  call CheckLegacyAndVim9Success(lines)

  call assert_fails('call strcharpart("", 0, 0, {})', ['E728:', 'E728:'])
  call assert_fails('call strcharpart("", 0, 0, -1)', ['E1023:', 'E1023:'])
endfunc

func Test_getreg_empty_list()
  let lines =<< trim END
      call assert_equal('', getreg('x'))
      call assert_equal([], getreg('x', 1, 1))
      VAR x = getreg('x', 1, 1)
      VAR y = x
      call add(x, 'foo')
      call assert_equal(['foo'], y)
  END
  call CheckLegacyAndVim9Success(lines)

  call CheckLegacyAndVim9Failure(['call getreg([])'], ['E730:', 'E1013:', 'E1174:'])
endfunc

func Test_loop_over_null_list()
  let lines =<< trim END
      VAR null_list = v:_null_list
      for i in null_list
        call assert_report('should not get here')
      endfor
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_setreg_null_list()
  let lines =<< trim END
      call setreg('x', v:_null_list)
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_special_char()
  " The failure is only visible using valgrind.
  call CheckLegacyAndVim9Failure(['echo "\<C-">'], ['E15:', 'E1004:', 'E1004:'])
endfunc

func Test_method_with_prefix()
  let lines =<< trim END
      call assert_equal(TRUE, !range(5)->empty())
      call assert_equal(FALSE, !-3)
  END
  call CheckLegacyAndVim9Success(lines)

  call assert_equal([0, 1, 2], --3->range())
  call CheckDefAndScriptFailure(['eval --3->range()'], 'E15')

  call assert_equal(1, !+-+0)
  call CheckDefAndScriptFailure(['eval !+-+0'], 'E15')
endfunc

func Test_option_value()
  let lines =<< trim END
      #" boolean
      set bri
      call assert_equal(TRUE, &bri)
      set nobri
      call assert_equal(FALSE, &bri)

      #" number
      set ts=1
      call assert_equal(1, &ts)
      set ts=8
      call assert_equal(8, &ts)

      #" string
      exe "set cedit=\<Esc>"
      call assert_equal("\<Esc>", &cedit)
      set cpo=
      call assert_equal("", &cpo)
      set cpo=abcdefi
      call assert_equal("abcdefi", &cpo)
      set cpo&vim
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_printf_misc()
  let lines =<< trim END
      call assert_equal('123', printf('123'))

      call assert_equal('', printf('%'))
      call assert_equal('', printf('%.0d', 0))
      call assert_equal('123', printf('%d', 123))
      call assert_equal('123', printf('%i', 123))
      call assert_equal('123', printf('%D', 123))
      call assert_equal('123', printf('%U', 123))
      call assert_equal('173', printf('%o', 123))
      call assert_equal('173', printf('%O', 123))
      call assert_equal('7b', printf('%x', 123))
      call assert_equal('7B', printf('%X', 123))

      call assert_equal('123', printf('%hd', 123))
      call assert_equal('-123', printf('%hd', -123))
      call assert_equal('-1', printf('%hd', 0xFFFF))
      call assert_equal('-1', printf('%hd', 0x1FFFFF))

      call assert_equal('123', printf('%hu', 123))
      call assert_equal('65413', printf('%hu', -123))
      call assert_equal('65535', printf('%hu', 0xFFFF))
      call assert_equal('65535', printf('%hu', 0x1FFFFF))

      call assert_equal('123', printf('%ld', 123))
      call assert_equal('-123', printf('%ld', -123))
      call assert_equal('65535', printf('%ld', 0xFFFF))
      call assert_equal('131071', printf('%ld', 0x1FFFF))

      call assert_equal('{', printf('%c', 123))
      call assert_equal('abc', printf('%s', 'abc'))
      call assert_equal('abc', printf('%S', 'abc'))

      call assert_equal('+123', printf('%+d', 123))
      call assert_equal('-123', printf('%+d', -123))
      call assert_equal('+123', printf('%+ d', 123))
      call assert_equal(' 123', printf('% d', 123))
      call assert_equal(' 123', printf('%  d', 123))
      call assert_equal('-123', printf('% d', -123))

      call assert_equal('123', printf('%2d', 123))
      call assert_equal('   123', printf('%6d', 123))
      call assert_equal('000123', printf('%06d', 123))
      call assert_equal('+00123', printf('%+06d', 123))
      call assert_equal(' 00123', printf('% 06d', 123))
      call assert_equal('  +123', printf('%+6d', 123))
      call assert_equal('   123', printf('% 6d', 123))
      call assert_equal('  -123', printf('% 6d', -123))

      #" Test left adjusted.
      call assert_equal('123   ', printf('%-6d', 123))
      call assert_equal('+123  ', printf('%-+6d', 123))
      call assert_equal(' 123  ', printf('%- 6d', 123))
      call assert_equal('-123  ', printf('%- 6d', -123))

      call assert_equal('  00123', printf('%7.5d', 123))
      call assert_equal(' -00123', printf('%7.5d', -123))
      call assert_equal(' +00123', printf('%+7.5d', 123))

      #" Precision field should not be used when combined with %0
      call assert_equal('  00123', printf('%07.5d', 123))
      call assert_equal(' -00123', printf('%07.5d', -123))

      call assert_equal('  123', printf('%*d', 5, 123))
      call assert_equal('123  ', printf('%*d', -5, 123))
      call assert_equal('00123', printf('%.*d', 5, 123))
      call assert_equal('  123', printf('% *d', 5, 123))
      call assert_equal(' +123', printf('%+ *d', 5, 123))

      call assert_equal('foobar', printf('%.*s',  9, 'foobar'))
      call assert_equal('foo',    printf('%.*s',  3, 'foobar'))
      call assert_equal('',       printf('%.*s',  0, 'foobar'))
      call assert_equal('foobar', printf('%.*s', -1, 'foobar'))

      #" Simple quote (thousand grouping char) is ignored.
      call assert_equal('+00123456', printf("%+'09d", 123456))

      #" Unrecognized format specifier kept as-is.
      call assert_equal('_123', printf("%_%d", 123))

      #" Test alternate forms.
      call assert_equal('0x7b', printf('%#x', 123))
      call assert_equal('0X7B', printf('%#X', 123))
      call assert_equal('0173', printf('%#o', 123))
      call assert_equal('0173', printf('%#O', 123))
      call assert_equal('abc', printf('%#s', 'abc'))
      call assert_equal('abc', printf('%#S', 'abc'))
      call assert_equal('  0173', printf('%#6o', 123))
      call assert_equal(' 00173', printf('%#6.5o', 123))
      call assert_equal('  0173', printf('%#6.2o', 123))
      call assert_equal('  0173', printf('%#6.2o', 123))
      call assert_equal('0173', printf('%#2.2o', 123))

      call assert_equal(' 00123', printf('%6.5d', 123))
      call assert_equal(' 0007b', printf('%6.5x', 123))

      call assert_equal('123', printf('%.2d', 123))
      call assert_equal('0123', printf('%.4d', 123))
      call assert_equal('0000000123', printf('%.10d', 123))
      call assert_equal('123', printf('%.0d', 123))

      call assert_equal('abc', printf('%2s', 'abc'))
      call assert_equal('abc', printf('%2S', 'abc'))
      call assert_equal('abc', printf('%.4s', 'abc'))
      call assert_equal('abc', printf('%.4S', 'abc'))
      call assert_equal('ab', printf('%.2s', 'abc'))
      call assert_equal('ab', printf('%.2S', 'abc'))
      call assert_equal('', printf('%.0s', 'abc'))
      call assert_equal('', printf('%.s', 'abc'))
      call assert_equal(' abc', printf('%4s', 'abc'))
      call assert_equal(' abc', printf('%4S', 'abc'))
      call assert_equal('0abc', printf('%04s', 'abc'))
      call assert_equal('0abc', printf('%04S', 'abc'))
      call assert_equal('abc ', printf('%-4s', 'abc'))
      call assert_equal('abc ', printf('%-4S', 'abc'))

      call assert_equal('🐍', printf('%.2S', '🐍🐍'))
      call assert_equal('', printf('%.1S', '🐍🐍'))

      call assert_equal('[    あいう]', printf('[%10.6S]', 'あいうえお'))
      call assert_equal('[  あいうえ]', printf('[%10.8S]', 'あいうえお'))
      call assert_equal('[あいうえお]', printf('[%10.10S]', 'あいうえお'))
      call assert_equal('[あいうえお]', printf('[%10.12S]', 'あいうえお'))

      call assert_equal('あいう', printf('%S', 'あいう'))
      call assert_equal('あいう', printf('%#S', 'あいう'))

      call assert_equal('あb', printf('%2S', 'あb'))
      call assert_equal('あb', printf('%.4S', 'あb'))
      call assert_equal('あ', printf('%.2S', 'あb'))
      call assert_equal(' あb', printf('%4S', 'あb'))
      call assert_equal('0あb', printf('%04S', 'あb'))
      call assert_equal('あb ', printf('%-4S', 'あb'))
      call assert_equal('あ  ', printf('%-4.2S', 'あb'))

      call assert_equal('aい', printf('%2S', 'aい'))
      call assert_equal('aい', printf('%.4S', 'aい'))
      call assert_equal('a', printf('%.2S', 'aい'))
      call assert_equal(' aい', printf('%4S', 'aい'))
      call assert_equal('0aい', printf('%04S', 'aい'))
      call assert_equal('aい ', printf('%-4S', 'aい'))
      call assert_equal('a   ', printf('%-4.2S', 'aい'))

      call assert_equal('[あいう]', printf('[%05S]', 'あいう'))
      call assert_equal('[あいう]', printf('[%06S]', 'あいう'))
      call assert_equal('[0あいう]', printf('[%07S]', 'あいう'))

      call assert_equal('[あiう]', printf('[%05S]', 'あiう'))
      call assert_equal('[0あiう]', printf('[%06S]', 'あiう'))
      call assert_equal('[00あiう]', printf('[%07S]', 'あiう'))

      call assert_equal('[0あい]', printf('[%05.4S]', 'あいう'))
      call assert_equal('[00あい]', printf('[%06.4S]', 'あいう'))
      call assert_equal('[000あい]', printf('[%07.4S]', 'あいう'))

      call assert_equal('[00あi]', printf('[%05.4S]', 'あiう'))
      call assert_equal('[000あi]', printf('[%06.4S]', 'あiう'))
      call assert_equal('[0000あi]', printf('[%07.4S]', 'あiう'))

      call assert_equal('[0あい]', printf('[%05.5S]', 'あいう'))
      call assert_equal('[00あい]', printf('[%06.5S]', 'あいう'))
      call assert_equal('[000あい]', printf('[%07.5S]', 'あいう'))

      call assert_equal('[あiう]', printf('[%05.5S]', 'あiう'))
      call assert_equal('[0あiう]', printf('[%06.5S]', 'あiう'))
      call assert_equal('[00あiう]', printf('[%07.5S]', 'あiう'))

      call assert_equal('[0000000000]', printf('[%010.0S]', 'あいう'))
      call assert_equal('[0000000000]', printf('[%010.1S]', 'あいう'))
      call assert_equal('[00000000あ]', printf('[%010.2S]', 'あいう'))
      call assert_equal('[00000000あ]', printf('[%010.3S]', 'あいう'))
      call assert_equal('[000000あい]', printf('[%010.4S]', 'あいう'))
      call assert_equal('[000000あい]', printf('[%010.5S]', 'あいう'))
      call assert_equal('[0000あいう]', printf('[%010.6S]', 'あいう'))
      call assert_equal('[0000あいう]', printf('[%010.7S]', 'あいう'))

      call assert_equal('[0000000000]', printf('[%010.1S]', 'あiう'))
      call assert_equal('[00000000あ]', printf('[%010.2S]', 'あiう'))
      call assert_equal('[0000000あi]', printf('[%010.3S]', 'あiう'))
      call assert_equal('[0000000あi]', printf('[%010.4S]', 'あiう'))
      call assert_equal('[00000あiう]', printf('[%010.5S]', 'あiう'))
      call assert_equal('[00000あiう]', printf('[%010.6S]', 'あiう'))
      call assert_equal('[00000あiう]', printf('[%010.7S]', 'あiう'))

      call assert_equal('1%', printf('%d%%', 1))
      call assert_notequal('', printf('%p', "abc"))
  END
  call CheckLegacyAndVim9Success(lines)

  call CheckLegacyAndVim9Failure(["call printf('123', 3)"], "E767:")

  " this was using uninitialized memory
  call CheckLegacyAndVim9Failure(["eval ''->printf()"], "E119:")
endfunc

func Test_printf_float()
  if has('float')
    let lines =<< trim END
        call assert_equal('1.000000', printf('%f', 1))
        call assert_equal('1.230000', printf('%f', 1.23))
        call assert_equal('1.230000', printf('%F', 1.23))
        call assert_equal('9999999.9', printf('%g', 9999999.9))
        call assert_equal('9999999.9', printf('%G', 9999999.9))
        call assert_equal('1.00000001e7', printf('%.8g', 10000000.1))
        call assert_equal('1.00000001E7', printf('%.8G', 10000000.1))
        call assert_equal('1.230000e+00', printf('%e', 1.23))
        call assert_equal('1.230000E+00', printf('%E', 1.23))
        call assert_equal('1.200000e-02', printf('%e', 0.012))
        call assert_equal('-1.200000e-02', printf('%e', -0.012))
        call assert_equal('0.33', printf('%.2f', 1.0 / 3.0))
        call assert_equal('  0.33', printf('%6.2f', 1.0 / 3.0))
        call assert_equal(' -0.33', printf('%6.2f', -1.0 / 3.0))
        call assert_equal('000.33', printf('%06.2f', 1.0 / 3.0))
        call assert_equal('-00.33', printf('%06.2f', -1.0 / 3.0))
        call assert_equal('-00.33', printf('%+06.2f', -1.0 / 3.0))
        call assert_equal('+00.33', printf('%+06.2f', 1.0 / 3.0))
        call assert_equal(' 00.33', printf('% 06.2f', 1.0 / 3.0))
        call assert_equal('000.33', printf('%06.2g', 1.0 / 3.0))
        call assert_equal('-00.33', printf('%06.2g', -1.0 / 3.0))
        call assert_equal('0.33', printf('%3.2f', 1.0 / 3.0))
        call assert_equal('003.33e-01', printf('%010.2e', 1.0 / 3.0))
        call assert_equal(' 03.33e-01', printf('% 010.2e', 1.0 / 3.0))
        call assert_equal('+03.33e-01', printf('%+010.2e', 1.0 / 3.0))
        call assert_equal('-03.33e-01', printf('%010.2e', -1.0 / 3.0))

        #" When precision is 0, the dot should be omitted.
        call assert_equal('  2', printf('%3.f', 7.0 / 3.0))
        call assert_equal('  2', printf('%3.g', 7.0 / 3.0))
        call assert_equal('  2e+00', printf('%7.e', 7.0 / 3.0))

        #" Float zero can be signed.
        call assert_equal('+0.000000', printf('%+f', 0.0))
        call assert_equal('0.000000', printf('%f', 1.0 / (1.0 / 0.0)))
        call assert_equal('-0.000000', printf('%f', 1.0 / (-1.0 / 0.0)))
        call assert_equal('0.0', printf('%s', 1.0 / (1.0 / 0.0)))
        call assert_equal('-0.0', printf('%s', 1.0 / (-1.0 / 0.0)))
        call assert_equal('0.0', printf('%S', 1.0 / (1.0 / 0.0)))
        call assert_equal('-0.0', printf('%S', 1.0 / (-1.0 / 0.0)))

        #" Float infinity can be signed.
        call assert_equal('inf', printf('%f', 1.0 / 0.0))
        call assert_equal('-inf', printf('%f', -1.0 / 0.0))
        call assert_equal('inf', printf('%g', 1.0 / 0.0))
        call assert_equal('-inf', printf('%g', -1.0 / 0.0))
        call assert_equal('inf', printf('%e', 1.0 / 0.0))
        call assert_equal('-inf', printf('%e', -1.0 / 0.0))
        call assert_equal('INF', printf('%F', 1.0 / 0.0))
        call assert_equal('-INF', printf('%F', -1.0 / 0.0))
        call assert_equal('INF', printf('%E', 1.0 / 0.0))
        call assert_equal('-INF', printf('%E', -1.0 / 0.0))
        call assert_equal('INF', printf('%E', 1.0 / 0.0))
        call assert_equal('-INF', printf('%G', -1.0 / 0.0))
        call assert_equal('+inf', printf('%+f', 1.0 / 0.0))
        call assert_equal('-inf', printf('%+f', -1.0 / 0.0))
        call assert_equal(' inf', printf('% f',  1.0 / 0.0))
        call assert_equal('   inf', printf('%6f', 1.0 / 0.0))
        call assert_equal('  -inf', printf('%6f', -1.0 / 0.0))
        call assert_equal('   inf', printf('%6g', 1.0 / 0.0))
        call assert_equal('  -inf', printf('%6g', -1.0 / 0.0))
        call assert_equal('  +inf', printf('%+6f', 1.0 / 0.0))
        call assert_equal('   inf', printf('% 6f', 1.0 / 0.0))
        call assert_equal('  +inf', printf('%+06f', 1.0 / 0.0))
        call assert_equal('inf   ', printf('%-6f', 1.0 / 0.0))
        call assert_equal('-inf  ', printf('%-6f', -1.0 / 0.0))
        call assert_equal('+inf  ', printf('%-+6f', 1.0 / 0.0))
        call assert_equal(' inf  ', printf('%- 6f', 1.0 / 0.0))
        call assert_equal('-INF  ', printf('%-6F', -1.0 / 0.0))
        call assert_equal('+INF  ', printf('%-+6F', 1.0 / 0.0))
        call assert_equal(' INF  ', printf('%- 6F', 1.0 / 0.0))
        call assert_equal('INF   ', printf('%-6G', 1.0 / 0.0))
        call assert_equal('-INF  ', printf('%-6G', -1.0 / 0.0))
        call assert_equal('INF   ', printf('%-6E', 1.0 / 0.0))
        call assert_equal('-INF  ', printf('%-6E', -1.0 / 0.0))
        call assert_equal("str2float('inf')", printf('%s', 1.0 / 0.0))
        call assert_equal("-str2float('inf')", printf('%s', -1.0 / 0.0))

        #" Test special case where max precision is truncated at 340.
        call assert_equal('1.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%.330f', 1.0))
        call assert_equal('1.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%.340f', 1.0))
        call assert_equal('1.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%.350f', 1.0))

        #" Float nan (not a number) has no sign.
        call assert_equal('nan', printf('%f', sqrt(-1.0)))
        call assert_equal('nan', printf('%f', 0.0 / 0.0))
        call assert_equal('nan', printf('%f', -0.0 / 0.0))
        call assert_equal('nan', printf('%g', 0.0 / 0.0))
        call assert_equal('nan', printf('%e', 0.0 / 0.0))
        call assert_equal('NAN', printf('%F', 0.0 / 0.0))
        call assert_equal('NAN', printf('%G', 0.0 / 0.0))
        call assert_equal('NAN', printf('%E', 0.0 / 0.0))
        call assert_equal('NAN', printf('%F', -0.0 / 0.0))
        call assert_equal('NAN', printf('%G', -0.0 / 0.0))
        call assert_equal('NAN', printf('%E', -0.0 / 0.0))
        call assert_equal('   nan', printf('%6f', 0.0 / 0.0))
        call assert_equal('   nan', printf('%06f', 0.0 / 0.0))
        call assert_equal('nan   ', printf('%-6f', 0.0 / 0.0))
        call assert_equal('nan   ', printf('%- 6f', 0.0 / 0.0))
        call assert_equal("str2float('nan')", printf('%s', 0.0 / 0.0))
        call assert_equal("str2float('nan')", printf('%s', -0.0 / 0.0))
        call assert_equal("str2float('nan')", printf('%S', 0.0 / 0.0))
        call assert_equal("str2float('nan')", printf('%S', -0.0 / 0.0))
    END
    call CheckLegacyAndVim9Success(lines)

    call CheckLegacyAndVim9Failure(['echo printf("%f", "a")'], 'E807:')
  endif
endfunc

func Test_printf_errors()
  call CheckLegacyAndVim9Failure(['echo printf("%d", {})'], 'E728:')
  call CheckLegacyAndVim9Failure(['echo printf("%d", [])'], 'E745:')
  call CheckLegacyAndVim9Failure(['echo printf("%d", 1, 2)'], 'E767:')
  call CheckLegacyAndVim9Failure(['echo printf("%*d", 1)'], 'E766:')
  call CheckLegacyAndVim9Failure(['echo printf("%s")'], 'E766:')
  if has('float')
    call CheckLegacyAndVim9Failure(['echo printf("%d", 1.2)'], 'E805:')
    call CheckLegacyAndVim9Failure(['echo printf("%f")'], 'E766:')
  endif
endfunc

func Test_printf_64bit()
  let lines =<< trim END
      call assert_equal("123456789012345", printf('%d', 123456789012345))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_printf_spec_s()
  let lines =<< trim END
      #" number
      call assert_equal("1234567890", printf('%s', 1234567890))

      #" string
      call assert_equal("abcdefgi", printf('%s', "abcdefgi"))

      #" float
      if has('float')
        call assert_equal("1.23", printf('%s', 1.23))
      endif

      #" list
      VAR lvalue = [1, 'two', ['three', 4]]
      call assert_equal(string(lvalue), printf('%s', lvalue))

      #" dict
      VAR dvalue = {'key1': 'value1', 'key2': ['list', 'lvalue'], 'key3': {'dict': 'lvalue'}}
      call assert_equal(string(dvalue), printf('%s', dvalue))

      #" funcref
      call assert_equal('printf', printf('%s', 'printf'->function()))

      #" partial
      call assert_equal(string(function('printf', ['%s'])), printf('%s', function('printf', ['%s'])))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_printf_spec_b()
  let lines =<< trim END
      call assert_equal("0", printf('%b', 0))
      call assert_equal("00001100", printf('%08b', 12))
      call assert_equal("11111111", printf('%08b', 0xff))
      call assert_equal("   1111011", printf('%10b', 123))
      call assert_equal("0001111011", printf('%010b', 123))
      call assert_equal(" 0b1111011", printf('%#10b', 123))
      call assert_equal("0B01111011", printf('%#010B', 123))
      call assert_equal("1001001100101100000001011010010", printf('%b', 1234567890))
      call assert_equal("11100000100100010000110000011011101111101111001", printf('%b', 123456789012345))
      call assert_equal("1111111111111111111111111111111111111111111111111111111111111111", printf('%b', -1))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_max_min_errors()
  call CheckLegacyAndVim9Failure(['call max(v:true)'], ['E712:', 'E1013:', 'E1227:'])
  call CheckLegacyAndVim9Failure(['call max(v:true)'], ['max()', 'E1013:', 'E1227:'])
  call CheckLegacyAndVim9Failure(['call min(v:true)'], ['E712:', 'E1013:', 'E1227:'])
  call CheckLegacyAndVim9Failure(['call min(v:true)'], ['min()', 'E1013:', 'E1227:'])
endfunc

func Test_function_with_funcref()
  let lines =<< trim END
      let s:F = function('type')
      let s:Fref = function(s:F)
      call assert_equal(v:t_string, s:Fref('x'))
      call assert_fails("call function('s:F')", 'E700:')

      call assert_fails("call function('foo()')", 'E475:')
      call assert_fails("call function('foo()')", 'foo()')
      call assert_fails("function('')", 'E129:')

      let s:Len = {s -> strlen(s)}
      call assert_equal(6, s:Len('foobar'))
      let name = string(s:Len)
      " can evaluate "function('<lambda>99')"
      call execute('let Ref = ' .. name)
      call assert_equal(4, Ref('text'))
  END
  call CheckScriptSuccess(lines)

  let lines =<< trim END
      vim9script
      var F = function('type')
      var Fref = function(F)
      call assert_equal(v:t_string, Fref('x'))
      call assert_fails("call function('F')", 'E700:')

      call assert_fails("call function('foo()')", 'E475:')
      call assert_fails("call function('foo()')", 'foo()')
      call assert_fails("function('')", 'E129:')

      var Len = (s) => strlen(s)
      call assert_equal(6, Len('foobar'))
      var name = string(Len)
      # can evaluate "function('<lambda>99')"
      call execute('var Ref = ' .. name)
      call assert_equal(4, Ref('text'))
  END
  call CheckScriptSuccess(lines)
endfunc

func Test_funcref()
  func! One()
    return 1
  endfunc
  let OneByName = function('One')
  let OneByRef = funcref('One')
  func! One()
    return 2
  endfunc
  call assert_equal(2, OneByName())
  call assert_equal(1, OneByRef())
  let OneByRef = 'One'->funcref()
  call assert_equal(2, OneByRef())
  call assert_fails('echo funcref("{")', 'E475:')
  let OneByRef = funcref("One", repeat(["foo"], 20))
  call assert_fails('let OneByRef = funcref("One", repeat(["foo"], 21))', 'E118:')
  call assert_fails('echo function("min") =~ function("min")', 'E694:')
endfunc

" Test for calling function() and funcref() outside of a Vim script context.
func Test_function_outside_script()
  let cleanup =<< trim END
    call writefile([execute('messages')], 'Xtest.out')
    qall
  END
  call writefile(cleanup, 'Xverify.vim')
  call RunVim([], [], "-c \"echo function('s:abc')\" -S Xverify.vim")
  call assert_match('E81: Using <SID> not in a', readfile('Xtest.out')[0])
  call RunVim([], [], "-c \"echo funcref('s:abc')\" -S Xverify.vim")
  call assert_match('E81: Using <SID> not in a', readfile('Xtest.out')[0])
  call delete('Xtest.out')
  call delete('Xverify.vim')
endfunc

func Test_setmatches()
  let lines =<< trim END
      hi def link 1 Comment
      hi def link 2 PreProc
      VAR set = [{"group": 1, "pattern": 2, "id": 3, "priority": 4}]
      VAR exp = [{"group": '1', "pattern": '2', "id": 3, "priority": 4}]
      if has('conceal')
        LET set[0]['conceal'] = 5
        LET exp[0]['conceal'] = '5'
      endif
      eval set->setmatches()
      call assert_equal(exp, getmatches())
  END
  call CheckLegacyAndVim9Success(lines)

  call CheckLegacyAndVim9Failure(['VAR m = setmatches([], [])'], ['E745:', 'E1013:', 'E1210:'])
endfunc

func Test_empty_concatenate()
  let lines =<< trim END
      call assert_equal('b', 'a'[4 : 0] .. 'b')
      call assert_equal('b', 'b' .. 'a'[4 : 0])
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_broken_number()
  call CheckLegacyAndVim9Failure(['VAR X = "bad"', 'echo 1X'], 'E15:')
  call CheckLegacyAndVim9Failure(['VAR X = "bad"', 'echo 0b1X'], 'E15:')
  call CheckLegacyAndVim9Failure(['echo 0b12'], 'E15:')
  call CheckLegacyAndVim9Failure(['VAR X = "bad"', 'echo 0x1X'], 'E15:')
  call CheckLegacyAndVim9Failure(['VAR X = "bad"', 'echo 011X'], 'E15:')

  call CheckLegacyAndVim9Success(['call assert_equal(2, str2nr("2a"))'])

  call CheckLegacyAndVim9Failure(['inoremap <Char-0b1z> b'], 'E474:')
endfunc

func Test_eval_after_if()
  let s:val = ''
  func SetVal(x)
    let s:val ..= a:x
  endfunc
  if 0 | eval SetVal('a') | endif | call SetVal('b')
  call assert_equal('b', s:val)
endfunc

func Test_divide_by_zero()
  " only tests that this doesn't crash, the result is not important
  echo 0 / 0
  echo 0 / 0 / -1
endfunc

" Test for command-line completion of expressions
func Test_expr_completion()
  CheckFeature cmdline_compl
  for cmd in [
	\ 'let a = ',
	\ 'const a = ',
	\ 'if',
	\ 'elseif',
	\ 'while',
	\ 'for',
	\ 'echo',
	\ 'echon',
	\ 'execute',
	\ 'echomsg',
	\ 'echoerr',
	\ 'call',
	\ 'return',
	\ 'cexpr',
	\ 'caddexpr',
	\ 'cgetexpr',
	\ 'lexpr',
	\ 'laddexpr',
	\ 'lgetexpr']
    call feedkeys(":" . cmd . " getl\<Tab>\<Home>\"\<CR>", 'xt')
    call assert_equal('"' . cmd . ' getline(', getreg(':'))
  endfor

  " completion for the expression register
  call feedkeys(":\"\<C-R>=float2\t\"\<C-B>\"\<CR>", 'xt')
  call assert_equal('"float2nr("', @=)

  " completion for window local variables
  let w:wvar1 = 10
  let w:wvar2 = 10
  call feedkeys(":echo w:wvar\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"echo w:wvar1 w:wvar2', @:)
  unlet w:wvar1 w:wvar2

  " completion for tab local variables
  let t:tvar1 = 10
  let t:tvar2 = 10
  call feedkeys(":echo t:tvar\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"echo t:tvar1 t:tvar2', @:)
  unlet t:tvar1 t:tvar2

  " completion for variables
  let g:tvar1 = 1
  let g:tvar2 = 2
  call feedkeys(":let g:tv\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"let g:tvar1 g:tvar2', @:)
  " completion for variables after a ||
  call feedkeys(":echo 1 || g:tv\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"echo 1 || g:tvar1 g:tvar2', @:)

  " completion for options
  "call feedkeys(":echo &compat\<C-A>\<C-B>\"\<CR>", 'xt')
  "call assert_equal('"echo &compatible', @:)
  "call feedkeys(":echo 1 && &compat\<C-A>\<C-B>\"\<CR>", 'xt')
  "call assert_equal('"echo 1 && &compatible', @:)
  call feedkeys(":echo &g:equala\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"echo &g:equalalways', @:)

  " completion for string
  call feedkeys(":echo \"Hello\\ World\"\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"echo \"Hello\\ World\"\<C-A>", @:)
  call feedkeys(":echo 'Hello World'\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"echo 'Hello World'\<C-A>", @:)

  " completion for command after a |
  call feedkeys(":echo 'Hello' | cwin\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal("\"echo 'Hello' | cwindow", @:)

  " completion for environment variable
  let $X_VIM_TEST_COMPLETE_ENV = 'foo'
  call feedkeys(":let $X_VIM_TEST_COMPLETE_E\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('"let $X_VIM_TEST_COMPLETE_ENV', @:)
  unlet $X_VIM_TEST_COMPLETE_ENV
endfunc

" Test for errors in expression evaluation
func Test_expr_eval_error()
  call CheckLegacyAndVim9Failure(["VAR i = 'abc' .. []"], ['E730:', 'E1105:', 'E730:'])
  call CheckLegacyAndVim9Failure(["VAR l = [] + 10"], ['E745:', 'E1051:', 'E745'])
  call CheckLegacyAndVim9Failure(["VAR v = 10 + []"], ['E745:', 'E1051:', 'E745:'])
  call CheckLegacyAndVim9Failure(["VAR v = 10 / []"], ['E745:', 'E1036:', 'E745:'])
  call CheckLegacyAndVim9Failure(["VAR v = -{}"], ['E728:', 'E1012:', 'E728:'])
endfunc

func Test_white_in_function_call()
  let lines =<< trim END
      VAR text = substitute ( 'some text' , 't' , 'T' , 'g' )
      call assert_equal('some TexT', text)
  END
  call CheckTransLegacySuccess(lines)

  let lines =<< trim END
      var text = substitute ( 'some text' , 't' , 'T' , 'g' )
      call assert_equal('some TexT', text)
  END
  call CheckDefAndScriptFailure(lines, ['E1001:', 'E121:'])
endfunc

" Test for float value comparison
func Test_float_compare()
  CheckFeature float

  let lines =<< trim END
      call assert_true(1.2 == 1.2)
      call assert_true(1.0 != 1.2)
      call assert_true(1.2 > 1.0)
      call assert_true(1.2 >= 1.2)
      call assert_true(1.0 < 1.2)
      call assert_true(1.2 <= 1.2)
      call assert_true(+0.0 == -0.0)
      #" two NaNs (not a number) are not equal
      call assert_true(sqrt(-4.01) != (0.0 / 0.0))
      #" two inf (infinity) are equal
      call assert_true((1.0 / 0) == (2.0 / 0))
      #" two -inf (infinity) are equal
      call assert_true(-(1.0 / 0) == -(2.0 / 0))
      #" +infinity != -infinity
      call assert_true((1.0 / 0) != -(2.0 / 0))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_string_interp()
  let lines =<< trim END
    call assert_equal('', $"")
    call assert_equal('foobar', $"foobar")
    #" Escaping rules.
    call assert_equal('"foo"{bar}', $"\"foo\"{{bar}}")
    call assert_equal('"foo"{bar}', $'"foo"{{bar}}')
    call assert_equal('foobar', $"{"foo"}" .. $'{'bar'}')
    #" Whitespace before/after the expression.
    call assert_equal('3', $"{ 1 + 2 }")
    #" String conversion.
    call assert_equal('hello from ' .. v:version, $"hello from {v:version}")
    call assert_equal('hello from ' .. v:version, $'hello from {v:version}')
    #" Paper over a small difference between Vim script behaviour.
    call assert_equal(string(v:true), $"{v:true}")
    call assert_equal('(1+1=2)', $"(1+1={1 + 1})")
    #" Hex-escaped opening brace: char2nr('{') == 0x7b
    call assert_equal('esc123ape', $"esc{123}ape")
    call assert_equal('me{}me', $"me{"\x7b"}\x7dme")
    VAR var1 = "sun"
    VAR var2 = "shine"
    call assert_equal('sunshine', $"{var1}{var2}")
    call assert_equal('sunsunsun', $"{var1->repeat(3)}")
    #" Multibyte strings.
    call assert_equal('say ハロー・ワールド', $"say {'ハロー・ワールド'}")
    #" Nested.
    call assert_equal('foobarbaz', $"foo{$"{'bar'}"}baz")
    #" Do not evaluate blocks when the expr is skipped.
    VAR tmp = 0
    if v:false
      echo "${ LET tmp += 1 }"
    endif
    call assert_equal(0, tmp)

    #" Dict interpolation
    VAR d = {'a': 10, 'b': [1, 2]}
    call assert_equal("{'a': 10, 'b': [1, 2]}", $'{d}')
    VAR emptydict = {}
    call assert_equal("a{}b", $'a{emptydict}b')
    VAR nulldict = v:_null_dict
    call assert_equal("a{}b", $'a{nulldict}b')

    #" List interpolation
    VAR l = ['a', 'b', 'c']
    call assert_equal("['a', 'b', 'c']", $'{l}')
    VAR emptylist = []
    call assert_equal("a[]b", $'a{emptylist}b')
    VAR nulllist = v:_null_list
    call assert_equal("a[]b", $'a{nulllist}b')

    #" Stray closing brace.
    call assert_fails('echo $"moo}"', 'E1278:')
    #" Undefined variable in expansion.
    call assert_fails('echo $"{moo}"', 'E121:')
    #" Empty blocks are rejected.
    call assert_fails('echo $"{}"', 'E15:')
    call assert_fails('echo $"{   }"', 'E15:')
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
    call assert_equal('5', $"{({x -> x + 1})(4)}")
  END
  call CheckLegacySuccess(lines)

  let lines =<< trim END
    call assert_equal('5', $"{((x) => x + 1)(4)}")
    call assert_fails('echo $"{ # foo }"', 'E1279:')
  END
  call CheckDefAndScriptSuccess(lines)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
