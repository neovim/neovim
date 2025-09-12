" Tests for expressions.

source check.vim
source vim9.vim

func Test_printf_pos_misc()
  let lines =<< trim END
      call assert_equal('123', printf('%1$d', 123))
      call assert_equal('', printf('%1$.0d', 0))
      call assert_equal('00005', printf('%1$5.5d', 5))
      call assert_equal('00005', printf('%1$*1$.5d', 5))
      call assert_equal('00005', printf('%1$5.*1$d', 5))
      call assert_equal('00005', printf('%1$*1$.*1$d', 5))
      call assert_equal('00005', printf('%1$*10$.5d%2$.0d%3$.0d%4$.0d%5$.0d%6$.0d%7$.0d%8$.0d%9$.0d', 5, 0, 0, 0, 0, 0, 0, 0, 0, 5))
      call assert_equal('00005', printf('%1$5.*10$d%2$.0d%3$.0d%4$.0d%5$.0d%6$.0d%7$.0d%8$.0d%9$.0d', 5, 0, 0, 0, 0, 0, 0, 0, 0, 5))
      call assert_equal('123', printf('%1$i', 123))
      call assert_equal('123', printf('%1$D', 123))
      call assert_equal('123', printf('%1$U', 123))
      call assert_equal('173', printf('%1$o', 123))
      call assert_equal('173', printf('%1$O', 123))
      call assert_equal('7b', printf('%1$x', 123))
      call assert_equal('7B', printf('%1$X', 123))
      call assert_equal('Printing 1 at width 1 gives: 1', 1->printf("Printing %1$d at width %1$d gives: %1$*1$d"))
      call assert_equal('Printing 2 at width 2 gives:  2', 2->printf("Printing %1$d at width %1$d gives: %1$*1$d"))
      call assert_equal('Printing 3 at width 3 gives:   3', 3->printf("Printing %1$d at width %1$d gives: %1$*1$d"))
      call assert_equal('Printing 1 at width/precision 1.1 gives: 1', 1->printf("Printing %1$d at width/precision %1$d.%1$d gives: %1$*1$.*1$d"))
      call assert_equal('Printing 2 at width/precision 2.2 gives: 02', 2->printf("Printing %1$d at width/precision %1$d.%1$d gives: %1$*1$.*1$d"))
      call assert_equal('Printing 3 at width/precision 3.3 gives: 003', 3->printf("Printing %1$d at width/precision %1$d.%1$d gives: %1$*1$.*1$d"))

      call assert_equal('123', printf('%1$hd', 123))
      call assert_equal('-123', printf('%1$hd', -123))
      call assert_equal('-1', printf('%1$hd', 0xFFFF))
      call assert_equal('-1', printf('%1$hd', 0x1FFFFF))

      call assert_equal('123', printf('%1$hu', 123))
      call assert_equal('65413', printf('%1$hu', -123))
      call assert_equal('65535', printf('%1$hu', 0xFFFF))
      call assert_equal('65535', printf('%1$hu', 0x1FFFFF))

      call assert_equal('123', printf('%1$ld', 123))
      call assert_equal('-123', printf('%1$ld', -123))
      call assert_equal('65535', printf('%1$ld', 0xFFFF))
      call assert_equal('131071', printf('%1$ld', 0x1FFFF))

      call assert_equal('{', printf('%1$c', 123))
      call assert_equal('abc', printf('%1$s', 'abc'))
      call assert_equal('abc', printf('%1$S', 'abc'))

      call assert_equal('+123', printf('%1$+d', 123))
      call assert_equal('-123', printf('%1$+d', -123))
      call assert_equal('+123', printf('%1$+ d', 123))
      call assert_equal(' 123', printf('%1$ d', 123))
      call assert_equal(' 123', printf('%1$  d', 123))
      call assert_equal('-123', printf('%1$ d', -123))

      call assert_equal('  123', printf('%2$*1$d', 5, 123))
      call assert_equal('123  ', printf('%2$*1$d', -5, 123))
      call assert_equal('00123', printf('%2$.*1$d', 5, 123))
      call assert_equal('  123', printf('%2$ *1$d', 5, 123))
      call assert_equal(' +123', printf('%2$+ *1$d', 5, 123))

      call assert_equal('  123', printf('%1$*2$d', 123, 5))
      call assert_equal('123  ', printf('%1$*2$d', 123, -5))
      call assert_equal('00123', printf('%1$.*2$d', 123, 5))
      call assert_equal('  123', printf('%1$ *2$d', 123, 5))
      call assert_equal(' +123', printf('%1$+ *2$d', 123, 5))

      call assert_equal('foobar', printf('%2$.*1$s',  9, 'foobar'))
      call assert_equal('foo',    printf('%2$.*1$s',  3, 'foobar'))
      call assert_equal('',       printf('%2$.*1$s',  0, 'foobar'))
      call assert_equal('foobar', printf('%2$.*1$s', -1, 'foobar'))

      #" Unrecognized format specifier kept as-is.
      call assert_equal('_123', printf("%_%1$d", 123))

      #" Test alternate forms.
      call assert_equal('0x7b', printf('%1$#x', 123))
      call assert_equal('0X7B', printf('%1$#X', 123))
      call assert_equal('0173', printf('%1$#o', 123))
      call assert_equal('0173', printf('%1$#O', 123))
      call assert_equal('abc', printf('%1$#s', 'abc'))
      call assert_equal('abc', printf('%1$#S', 'abc'))

      call assert_equal('1%', printf('%1$d%%', 1))
      call assert_notequal('', printf('%1$p', "abc"))
      call assert_notequal('', printf('%2$d %1$p %3$s', "abc", 2, "abc"))

      #" Try argument re-use and argument swapping
      call assert_equal('one two one', printf('%1$s %2$s %1$s', "one", "two"))
      call assert_equal('Screen height: 400', printf('%1$s height: %2$d', "Screen", 400))
      call assert_equal('400 is: Screen height', printf('%2$d is: %1$s height', "Screen", 400))

      #" Try out lots of combinations of argument types to skip
      call assert_equal('9 12345 7654321', printf('%2$ld %1$d %3$lu', 12345, 9, 7654321))
      call assert_equal('9 1234567 7654321', printf('%2$d %1$ld %3$lu', 1234567, 9, 7654321))
      call assert_equal('9 1234567 7654321', printf('%2$d %1$lld %3$lu', 1234567, 9, 7654321))
      call assert_equal('9 12345 7654321', printf('%2$ld %1$u %3$lu', 12345, 9, 7654321))
      call assert_equal('9 1234567 7654321', printf('%2$d %1$lu %3$lu', 1234567, 9, 7654321))
      call assert_equal('9 1234567 7654321', printf('%2$d %1$llu %3$lu', 1234567, 9, 7654321))
      call assert_equal('9 1234567 7654321', printf('%2$d %1$llu %3$lu', 1234567, 9, 7654321))
      call assert_equal('9 deadbeef 7654321', printf('%2$d %1$x %3$lu', 0xdeadbeef, 9, 7654321))
      call assert_equal('9 c 7654321', printf('%2$ld %1$c %3$lu', 99, 9, 7654321))
      call assert_equal('9 hi 7654321', printf('%2$ld %1$s %3$lu', "hi", 9, 7654321))
      call assert_equal('9 0.000000e+00 7654321', printf('%2$ld %1$e %3$lu', 0.0, 9, 7654321))
  END
  call CheckLegacyAndVim9Success(lines)

endfunc

func Test_printf_pos_float()
  let lines =<< trim END
      call assert_equal('1.000000', printf('%1$f', 1))
      call assert_equal('1.230000', printf('%1$f', 1.23))
      call assert_equal('1.230000', printf('%1$F', 1.23))
      call assert_equal('9999999.9', printf('%1$g', 9999999.9))
      call assert_equal('9999999.9', printf('%1$G', 9999999.9))
      call assert_equal('1.230000e+00', printf('%1$e', 1.23))
      call assert_equal('1.230000E+00', printf('%1$E', 1.23))
      call assert_equal('1.200000e-02', printf('%1$e', 0.012))
      call assert_equal('-1.200000e-02', printf('%1$e', -0.012))
      call assert_equal('0.33', printf('%1$.2f', 1.0 / 3.0))

      #" When precision is 0, the dot should be omitted.
      call assert_equal('  2', printf('%1$*2$.f', 7.0 / 3.0, 3))
      call assert_equal('  2', printf('%2$*1$.f', 3, 7.0 / 3.0))
      call assert_equal('  2', printf('%1$*2$.g', 7.0 / 3.0, 3))
      call assert_equal('  2', printf('%2$*1$.g', 3, 7.0 / 3.0))
      call assert_equal('  2e+00', printf('%1$*2$.e', 7.0 / 3.0, 7))
      call assert_equal('  2e+00', printf('%2$*1$.e', 7, 7.0 / 3.0))

      #" Float zero can be signed.
      call assert_equal('+0.000000', printf('%1$+f', 0.0))
      call assert_equal('0.000000', printf('%1$f', 1.0 / (1.0 / 0.0)))
      call assert_equal('-0.000000', printf('%1$f', 1.0 / (-1.0 / 0.0)))
      call assert_equal('0.0', printf('%1$s', 1.0 / (1.0 / 0.0)))
      call assert_equal('-0.0', printf('%1$s', 1.0 / (-1.0 / 0.0)))
      call assert_equal('0.0', printf('%1$S', 1.0 / (1.0 / 0.0)))
      call assert_equal('-0.0', printf('%1$S', 1.0 / (-1.0 / 0.0)))

      #" Float infinity can be signed.
      call assert_equal('inf', printf('%1$f', 1.0 / 0.0))
      call assert_equal('-inf', printf('%1$f', -1.0 / 0.0))
      call assert_equal('inf', printf('%1$g', 1.0 / 0.0))
      call assert_equal('-inf', printf('%1$g', -1.0 / 0.0))
      call assert_equal('inf', printf('%1$e', 1.0 / 0.0))
      call assert_equal('-inf', printf('%1$e', -1.0 / 0.0))
      call assert_equal('INF', printf('%1$F', 1.0 / 0.0))
      call assert_equal('-INF', printf('%1$F', -1.0 / 0.0))
      call assert_equal('INF', printf('%1$E', 1.0 / 0.0))
      call assert_equal('-INF', printf('%1$E', -1.0 / 0.0))
      call assert_equal('INF', printf('%1$E', 1.0 / 0.0))
      call assert_equal('-INF', printf('%1$G', -1.0 / 0.0))
      call assert_equal('+inf', printf('%1$+f', 1.0 / 0.0))
      call assert_equal('-inf', printf('%1$+f', -1.0 / 0.0))
      call assert_equal(' inf', printf('%1$ f',  1.0 / 0.0))
      call assert_equal('   inf', printf('%1$*2$f', 1.0 / 0.0, 6))
      call assert_equal('  -inf', printf('%1$*2$f', -1.0 / 0.0, 6))
      call assert_equal('   inf', printf('%1$*2$g', 1.0 / 0.0, 6))
      call assert_equal('  -inf', printf('%1$*2$g', -1.0 / 0.0, 6))
      call assert_equal('  +inf', printf('%1$+*2$f', 1.0 / 0.0, 6))
      call assert_equal('   inf', printf('%1$ *2$f', 1.0 / 0.0, 6))
      call assert_equal('  +inf', printf('%1$+0*2$f', 1.0 / 0.0, 6))
      call assert_equal('inf   ', printf('%1$-*2$f', 1.0 / 0.0, 6))
      call assert_equal('-inf  ', printf('%1$-*2$f', -1.0 / 0.0, 6))
      call assert_equal('+inf  ', printf('%1$-+*2$f', 1.0 / 0.0, 6))
      call assert_equal(' inf  ', printf('%1$- *2$f', 1.0 / 0.0, 6))
      call assert_equal('-INF  ', printf('%1$-*2$F', -1.0 / 0.0, 6))
      call assert_equal('+INF  ', printf('%1$-+*2$F', 1.0 / 0.0, 6))
      call assert_equal(' INF  ', printf('%1$- *2$F', 1.0 / 0.0, 6))
      call assert_equal('INF   ', printf('%1$-*2$G', 1.0 / 0.0, 6))
      call assert_equal('-INF  ', printf('%1$-*2$G', -1.0 / 0.0, 6))
      call assert_equal('INF   ', printf('%1$-*2$E', 1.0 / 0.0, 6))
      call assert_equal('-INF  ', printf('%1$-*2$E', -1.0 / 0.0, 6))
      call assert_equal('   inf', printf('%2$*1$f', 6, 1.0 / 0.0))
      call assert_equal('  -inf', printf('%2$*1$f', 6, -1.0 / 0.0))
      call assert_equal('   inf', printf('%2$*1$g', 6, 1.0 / 0.0))
      call assert_equal('  -inf', printf('%2$*1$g', 6, -1.0 / 0.0))
      call assert_equal('  +inf', printf('%2$+*1$f', 6, 1.0 / 0.0))
      call assert_equal('   inf', printf('%2$ *1$f', 6, 1.0 / 0.0))
      call assert_equal('  +inf', printf('%2$+0*1$f', 6, 1.0 / 0.0))
      call assert_equal('inf   ', printf('%2$-*1$f', 6, 1.0 / 0.0))
      call assert_equal('-inf  ', printf('%2$-*1$f', 6, -1.0 / 0.0))
      call assert_equal('+inf  ', printf('%2$-+*1$f', 6, 1.0 / 0.0))
      call assert_equal(' inf  ', printf('%2$- *1$f', 6, 1.0 / 0.0))
      call assert_equal('-INF  ', printf('%2$-*1$F', 6, -1.0 / 0.0))
      call assert_equal('+INF  ', printf('%2$-+*1$F', 6, 1.0 / 0.0))
      call assert_equal(' INF  ', printf('%2$- *1$F', 6, 1.0 / 0.0))
      call assert_equal('INF   ', printf('%2$-*1$G', 6, 1.0 / 0.0))
      call assert_equal('-INF  ', printf('%2$-*1$G', 6, -1.0 / 0.0))
      call assert_equal('INF   ', printf('%2$-*1$E', 6, 1.0 / 0.0))
      call assert_equal('-INF  ', printf('%2$-*1$E', 6, -1.0 / 0.0))
      call assert_equal("str2float('inf')", printf('%1$s', 1.0 / 0.0))
      call assert_equal("-str2float('inf')", printf('%1$s', -1.0 / 0.0))

      #" Test special case where max precision is truncated at 340.
      call assert_equal('1.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%1$.*2$f', 1.0, 330))
      call assert_equal('1.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%2$.*1$f', 330, 1.0))
      call assert_equal('1.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%1$.*2$f', 1.0, 340))
      call assert_equal('1.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%2$.*1$f', 340, 1.0))
      call assert_equal('1.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%1$.*2$f', 1.0, 350))
      call assert_equal('1.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', printf('%2$.*1$f', 350, 1.0))

      #" Float nan (not a number) has no sign.
      call assert_equal('nan', printf('%1$f', sqrt(-1.0)))
      call assert_equal('nan', printf('%1$f', 0.0 / 0.0))
      call assert_equal('nan', printf('%1$f', -0.0 / 0.0))
      call assert_equal('nan', printf('%1$g', 0.0 / 0.0))
      call assert_equal('nan', printf('%1$e', 0.0 / 0.0))
      call assert_equal('NAN', printf('%1$F', 0.0 / 0.0))
      call assert_equal('NAN', printf('%1$G', 0.0 / 0.0))
      call assert_equal('NAN', printf('%1$E', 0.0 / 0.0))
      call assert_equal('NAN', printf('%1$F', -0.0 / 0.0))
      call assert_equal('NAN', printf('%1$G', -0.0 / 0.0))
      call assert_equal('NAN', printf('%1$E', -0.0 / 0.0))
      call assert_equal('   nan', printf('%1$*2$f', 0.0 / 0.0, 6))
      call assert_equal('   nan', printf('%1$0*2$f', 0.0 / 0.0, 6))
      call assert_equal('nan   ', printf('%1$-*2$f', 0.0 / 0.0, 6))
      call assert_equal('nan   ', printf('%1$- *2$f', 0.0 / 0.0, 6))
      call assert_equal('   nan', printf('%2$*1$f', 6, 0.0 / 0.0))
      call assert_equal('   nan', printf('%2$0*1$f', 6, 0.0 / 0.0))
      call assert_equal('nan   ', printf('%2$-*1$f', 6, 0.0 / 0.0))
      call assert_equal('nan   ', printf('%2$- *1$f', 6, 0.0 / 0.0))
      call assert_equal("str2float('nan')", printf('%1$s', 0.0 / 0.0))
      call assert_equal("str2float('nan')", printf('%1$s', -0.0 / 0.0))
      call assert_equal("str2float('nan')", printf('%1$S', 0.0 / 0.0))
      call assert_equal("str2float('nan')", printf('%1$S', -0.0 / 0.0))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_printf_pos_errors()
  call CheckLegacyAndVim9Failure(['echo printf("%1$d", {})'], 'E728:')
  call CheckLegacyAndVim9Failure(['echo printf("%1$d", [])'], 'E745:')
  call CheckLegacyAndVim9Failure(['echo printf("%1$d", 1, 2)'], 'E767:')
  call CheckLegacyAndVim9Failure(['echo printf("%*d", 1)'], 'E766:')
  call CheckLegacyAndVim9Failure(['echo printf("%1$s")'], 'E1503:')
  call CheckLegacyAndVim9Failure(['echo printf("%1$d", 1.2)'], 'E805:')
  call CheckLegacyAndVim9Failure(['echo printf("%1$f")'], 'E1503:')

  call CheckLegacyAndVim9Failure(['echo printf("%f", "a")'], 'E807:')

  call CheckLegacyAndVim9Failure(["call printf('%1$d%2$d', 1, 3, 4)"], "E767:")

  call CheckLegacyAndVim9Failure(["call printf('%2$d%d', 1, 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%d%2$d', 1, 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%2$*1$d%d', 1, 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%d%2$*1$d', 1, 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%2$.*1$d%d', 1, 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%d%2$.*1$d', 1, 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%1$%')"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%1$')"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%1$_')"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*3$.*d', 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*.*2$d', 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*.*d', 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%*.*1$d', 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%*1$.*d', 3)"], "E1500:")
  call CheckLegacyAndVim9Failure(["call printf('%*1$.*1$d', 3)"], "E1500:")

  call CheckLegacyAndVim9Failure(["call printf('%2$d', 3, 3)"], "E1501:")

  call CheckLegacyAndVim9Failure(["call printf('%2$*1$d %1$ld', 3, 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$s %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$p %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$f %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$lud %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$llud %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$lld %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$s %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$c %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$ld %1$*1$d', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$ld %2$*1$d', 3, 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*1$ld', 3)"], "E1502:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*1$.*1$ld', 3)"], "E1502:")

  call CheckLegacyAndVim9Failure(["call printf('%1$d%2$d', 3)"], "E1503:")

  call CheckLegacyAndVim9Failure(["call printf('%1$d %1$s', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$ld %1$s', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$ud %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$s %1$f', 3.0)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*1$d %1$ld', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$s %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$p %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$f %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$lud %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$llud %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$lld %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$s %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$c %1$d', 3)"], "E1504:")
  call CheckLegacyAndVim9Failure(["call printf('%1$ld %1$d', 3)"], "E1504:")

  call CheckLegacyAndVim9Failure(["call printf('%1$.2$d', 3)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%01$d', 3)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%01$0d', 3)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*2d', 3)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*3.*2$d', 3)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*3$.2$d', 3)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*3$.*2d', 3)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%1$1$.5d', 5)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%1$5.1$d', 5)"], "E1505:")
  call CheckLegacyAndVim9Failure(["call printf('%1$1$.1$d', 5)"], "E1505:")

  call CheckLegacyAndVim9Failure(["call printf('%.123456789$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%.123456789d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789d', 5)"], "E1510:")

  call CheckLegacyAndVim9Failure(["call printf('%123456789$5.5d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$123456789.5d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$5.123456789d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$987654321.5d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$123456789.987654321d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$5.987654321d', 5)"], "E1510:")

  call CheckLegacyAndVim9Failure(["call printf('%123456789$*1$.5d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*123456789$.5d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*1$.123456789d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$*987654321$.5d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*123456789$.987654321d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$*1$.987654321d', 5)"], "E1510:")

  call CheckLegacyAndVim9Failure(["call printf('%123456789$5.*1$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$123456789.*1$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$5.*123456789$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$987654321.*1$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$123456789.*987654321$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$5.*987654321$d', 5)"], "E1510:")

  call CheckLegacyAndVim9Failure(["call printf('%123456789$*1$.*1$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*123456789$.*1$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*1$.*123456789d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$*987654321$.*1$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*123456789$.*987654321$d', 5)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%123456789$*1$.*987654321$d', 5)"], "E1510:")

  call CheckLegacyAndVim9Failure(["call printf('%1$*2$.*1$d', 5, 9999999)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*1$.*2$d', 5, 9999999)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%2$*3$.*1$d', 5, 9999123, 9999321)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%1$*2$.*3$d', 5, 9999123, 9999321)"], "E1510:")
  call CheckLegacyAndVim9Failure(["call printf('%2$*1$.*3$d', 5, 9999123, 9999312)"], "E1510:")

  call CheckLegacyAndVim9Failure(["call printf('%1$*2$d', 5, 9999999)"], "E1510:")
endfunc

func Test_printf_pos_64bit()
  let lines =<< trim END
      call assert_equal("123456789012345", printf('%1$d', 123456789012345))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_printf_pos_spec_s()
  let lines =<< trim END
      #" number
      call assert_equal("1234567890", printf('%1$s', 1234567890))

      #" string
      call assert_equal("abcdefgi", printf('%1$s', "abcdefgi"))

      #" float
      call assert_equal("1.23", printf('%1$s', 1.23))

      #" list
      VAR lvalue = [1, 'two', ['three', 4]]
      call assert_equal(string(lvalue), printf('%1$s', lvalue))

      #" dict
      VAR dvalue = {'key1': 'value1', 'key2': ['list', 'lvalue'], 'key3': {'dict': 'lvalue'}}
      call assert_equal(string(dvalue), printf('%1$s', dvalue))

      #" funcref
      call assert_equal('printf', printf('%1$s', 'printf'->function()))

      #" partial
      call assert_equal(string(function('printf', ['%1$s'])), printf('%1$s', function('printf', ['%1$s'])))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_printf_pos_spec_b()
  let lines =<< trim END
      call assert_equal("0", printf('%1$b', 0))
      call assert_equal("00001100", printf('%1$0*2$b', 12, 8))
      call assert_equal("11111111", printf('%1$0*2$b', 0xff, 8))
      call assert_equal("   1111011", printf('%1$*2$b', 123, 10))
      call assert_equal("0001111011", printf('%1$0*2$b', 123, 10))
      call assert_equal(" 0b1111011", printf('%1$#*2$b', 123, 10))
      call assert_equal("0B01111011", printf('%1$#0*2$B', 123, 10))
      call assert_equal("00001100", printf('%2$0*1$b', 8, 12))
      call assert_equal("11111111", printf('%2$0*1$b', 8, 0xff))
      call assert_equal("   1111011", printf('%2$*1$b', 10, 123))
      call assert_equal("0001111011", printf('%2$0*1$b', 10, 123))
      call assert_equal(" 0b1111011", printf('%2$#*1$b', 10, 123))
      call assert_equal("0B01111011", printf('%2$#0*1$B', 10, 123))
      call assert_equal("1001001100101100000001011010010", printf('%1$b', 1234567890))
      call assert_equal("11100000100100010000110000011011101111101111001", printf('%1$b', 123456789012345))
      call assert_equal("1111111111111111111111111111111111111111111111111111111111111111", printf('%1$b', -1))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
