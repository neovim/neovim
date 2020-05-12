-- Tests for spell checking with 'encoding' set to "utf-8".

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, feed_command, expect = helpers.clear, helpers.feed_command, helpers.expect
local write_file, call = helpers.write_file, helpers.call

local function write_latin1(name, text)
  text = call('iconv', text, 'utf-8', 'latin-1')
  write_file(name, text)
end

describe("spell checking with 'encoding' set to utf-8", function()
  setup(function()
    clear()
    feed_command("syntax off")
    write_latin1('Xtest1.aff',[[
      SET ISO8859-1
      TRY esianrtolcdugmphbyfvkwjkqxz-ëéèêïîäàâöüû'ESIANRTOLCDUGMPHBYFVKWJKQXZ

      FOL  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      LOW  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßÿ

      SOFOFROM abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ¿
      SOFOTO   ebctefghejklnnepkrstevvkesebctefghejklnnepkrstevvkeseeeeeeeceeeeeeeedneeeeeeeeeeepseeeeeeeeceeeeeeeedneeeeeeeeeeep?

      MIDWORD	'-

      KEP =
      RAR ?
      BAD !

      PFX I N 1
      PFX I 0 in .

      PFX O Y 1
      PFX O 0 out .

      SFX S Y 2
      SFX S 0 s [^s]
      SFX S 0 es s

      SFX N N 3
      SFX N 0 en [^n]
      SFX N 0 nen n
      SFX N 0 n .

      REP 3
      REP g ch
      REP ch g
      REP svp s.v.p.

      MAP 9
      MAP aàáâãäå
      MAP eèéêë
      MAP iìíîï
      MAP oòóôõö
      MAP uùúûü
      MAP nñ
      MAP cç
      MAP yÿý
      MAP sß
      ]])
    write_latin1('Xtest1.dic', [[
      123456
      test/NO
      # comment
      wrong
      Comment
      OK
      uk
      put/ISO
      the end
      deol
      déôr
      ]])
    write_latin1('Xtest2.aff', [[
      SET ISO8859-1

      FOL  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      LOW  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßÿ

      PFXPOSTPONE

      MIDWORD	'-

      KEP =
      RAR ?
      BAD !

      PFX I N 1
      PFX I 0 in .

      PFX O Y 1
      PFX O 0 out [a-z]

      SFX S Y 2
      SFX S 0 s [^s]
      SFX S 0 es s

      SFX N N 3
      SFX N 0 en [^n]
      SFX N 0 nen n
      SFX N 0 n .

      REP 3
      REP g ch
      REP ch g
      REP svp s.v.p.

      MAP 9
      MAP aàáâãäå
      MAP eèéêë
      MAP iìíîï
      MAP oòóôõö
      MAP uùúûü
      MAP nñ
      MAP cç
      MAP yÿý
      MAP sß
      ]])
    write_latin1('Xtest3.aff', [[
      SET ISO8859-1

      COMPOUNDMIN 3
      COMPOUNDRULE m*
      NEEDCOMPOUND x
      ]])
    write_latin1('Xtest3.dic', [[
      1234
      foo/m
      bar/mx
      mï/m
      la/mx
      ]])
    write_latin1('Xtest4.aff', [[
      SET ISO8859-1

      FOL  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      LOW  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßÿ

      COMPOUNDRULE m+
      COMPOUNDRULE sm*e
      COMPOUNDRULE sm+
      COMPOUNDMIN 3
      COMPOUNDWORDMAX 3
      COMPOUNDFORBIDFLAG t

      COMPOUNDSYLMAX 5
      SYLLABLE aáeéiíoóöõuúüûy/aa/au/ea/ee/ei/ie/oa/oe/oo/ou/uu/ui

      MAP 9
      MAP aàáâãäå
      MAP eèéêë
      MAP iìíîï
      MAP oòóôõö
      MAP uùúûü
      MAP nñ
      MAP cç
      MAP yÿý
      MAP sß

      NEEDAFFIX x

      PFXPOSTPONE

      MIDWORD '-

      SFX q N 1
      SFX q   0    -ok .

      SFX a Y 2
      SFX a 0 s .
      SFX a 0 ize/t .

      PFX p N 1
      PFX p 0 pre .

      PFX P N 1
      PFX P 0 nou .
      ]])
    write_latin1('Xtest4.dic', [[
      1234
      word/mP
      util/am
      pro/xq
      tomato/m
      bork/mp
      start/s
      end/e
      ]])
    write_latin1('Xtest5.aff', [[
      SET ISO8859-1

      FLAG long

      NEEDAFFIX !!

      COMPOUNDRULE ssmm*ee

      NEEDCOMPOUND xx
      COMPOUNDPERMITFLAG pp

      SFX 13 Y 1
      SFX 13 0 bork .

      SFX a1 Y 1
      SFX a1 0 a1 .

      SFX aé Y 1
      SFX aé 0 aé .

      PFX zz Y 1
      PFX zz 0 pre/pp .

      PFX yy Y 1
      PFX yy 0 nou .
      ]])
    write_latin1('Xtest5.dic', [[
      1234
      foo/a1aé!!
      bar/zz13ee
      start/ss
      end/eeyy
      middle/mmxx
      ]])
    write_latin1('Xtest6.aff', [[
      SET ISO8859-1

      FLAG caplong

      NEEDAFFIX A!

      COMPOUNDRULE sMm*Ee

      NEEDCOMPOUND Xx

      COMPOUNDPERMITFLAG p

      SFX N3 Y 1
      SFX N3 0 bork .

      SFX A1 Y 1
      SFX A1 0 a1 .

      SFX Aé Y 1
      SFX Aé 0 aé .

      PFX Zz Y 1
      PFX Zz 0 pre/p .
      ]])
    write_latin1('Xtest6.dic', [[
      1234
      mee/A1AéA!
      bar/ZzN3Ee
      lead/s
      end/Ee
      middle/MmXx
      ]])
    write_latin1('Xtest7.aff', [[
      SET ISO8859-1

      FOL  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      LOW  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßÿ

      FLAG num

      NEEDAFFIX 9999

      COMPOUNDRULE 2,77*123

      NEEDCOMPOUND 1
      COMPOUNDPERMITFLAG 432

      SFX 61003 Y 1
      SFX 61003 0 meat .

      SFX 391 Y 1
      SFX 391 0 a1 .

      SFX 111 Y 1
      SFX 111 0 aé .

      PFX 17 Y 1
      PFX 17 0 pre/432 .
      ]])
    write_latin1('Xtest7.dic', [[
      1234
      mee/391,111,9999
      bar/17,61003,123
      lead/2
      tail/123
      middle/77,1
      ]])
    write_latin1('Xtest8.aff', [[
      SET ISO8859-1

      NOSPLITSUGS
      ]])
    write_latin1('Xtest8.dic', [[
      1234
      foo
      bar
      faabar
      ]])
    write_latin1('Xtest9.aff', [[
      ]])
    write_latin1('Xtest9.dic', [[
      1234
      foo
      bar
      ]])
    write_latin1('Xtest-sal.aff', [[
      SET ISO8859-1
      TRY esianrtolcdugmphbyfvkwjkqxz-ëéèêïîäàâöüû'ESIANRTOLCDUGMPHBYFVKWJKQXZ

      FOL  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      LOW  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßÿ

      MIDWORD	'-

      KEP =
      RAR ?
      BAD !

      PFX I N 1
      PFX I 0 in .

      PFX O Y 1
      PFX O 0 out .

      SFX S Y 2
      SFX S 0 s [^s]
      SFX S 0 es s

      SFX N N 3
      SFX N 0 en [^n]
      SFX N 0 nen n
      SFX N 0 n .

      REP 3
      REP g ch
      REP ch g
      REP svp s.v.p.

      MAP 9
      MAP aàáâãäå
      MAP eèéêë
      MAP iìíîï
      MAP oòóôõö
      MAP uùúûü
      MAP nñ
      MAP cç
      MAP yÿý
      MAP sß

      SAL AH(AEIOUY)-^         *H
      SAL AR(AEIOUY)-^         *R
      SAL A(HR)^               *
      SAL A^                   *
      SAL AH(AEIOUY)-          H
      SAL AR(AEIOUY)-          R
      SAL A(HR)                _
      SAL À^                   *
      SAL Å^                   *
      SAL BB-                  _
      SAL B                    B
      SAL CQ-                  _
      SAL CIA                  X
      SAL CH                   X
      SAL C(EIY)-              S
      SAL CK                   K
      SAL COUGH^               KF
      SAL CC<                  C
      SAL C                    K
      SAL DG(EIY)              K
      SAL DD-                  _
      SAL D                    T
      SAL É<                   E
      SAL EH(AEIOUY)-^         *H
      SAL ER(AEIOUY)-^         *R
      SAL E(HR)^               *
      SAL ENOUGH^$             *NF
      SAL E^                   *
      SAL EH(AEIOUY)-          H
      SAL ER(AEIOUY)-          R
      SAL E(HR)                _
      SAL FF-                  _
      SAL F                    F
      SAL GN^                  N
      SAL GN$                  N
      SAL GNS$                 NS
      SAL GNED$                N
      SAL GH(AEIOUY)-          K
      SAL GH                   _
      SAL GG9                  K
      SAL G                    K
      SAL H                    H
      SAL IH(AEIOUY)-^         *H
      SAL IR(AEIOUY)-^         *R
      SAL I(HR)^               *
      SAL I^                   *
      SAL ING6                 N
      SAL IH(AEIOUY)-          H
      SAL IR(AEIOUY)-          R
      SAL I(HR)                _
      SAL J                    K
      SAL KN^                  N
      SAL KK-                  _
      SAL K                    K
      SAL LAUGH^               LF
      SAL LL-                  _
      SAL L                    L
      SAL MB$                  M
      SAL MM                   M
      SAL M                    M
      SAL NN-                  _
      SAL N                    N
      SAL OH(AEIOUY)-^         *H
      SAL OR(AEIOUY)-^         *R
      SAL O(HR)^               *
      SAL O^                   *
      SAL OH(AEIOUY)-          H
      SAL OR(AEIOUY)-          R
      SAL O(HR)                _
      SAL PH                   F
      SAL PN^                  N
      SAL PP-                  _
      SAL P                    P
      SAL Q                    K
      SAL RH^                  R
      SAL ROUGH^               RF
      SAL RR-                  _
      SAL R                    R
      SAL SCH(EOU)-            SK
      SAL SC(IEY)-             S
      SAL SH                   X
      SAL SI(AO)-              X
      SAL SS-                  _
      SAL S                    S
      SAL TI(AO)-              X
      SAL TH                   @
      SAL TCH--                _
      SAL TOUGH^               TF
      SAL TT-                  _
      SAL T                    T
      SAL UH(AEIOUY)-^         *H
      SAL UR(AEIOUY)-^         *R
      SAL U(HR)^               *
      SAL U^                   *
      SAL UH(AEIOUY)-          H
      SAL UR(AEIOUY)-          R
      SAL U(HR)                _
      SAL V^                   W
      SAL V                    F
      SAL WR^                  R
      SAL WH^                  W
      SAL W(AEIOU)-            W
      SAL X^                   S
      SAL X                    KS
      SAL Y(AEIOU)-            Y
      SAL ZZ-                  _
      SAL Z                    S
      ]])
    write_file('Xtest.utf-8.add', [[
      /regions=usgbnz
      elequint/2
      elekwint/3
      ]])
  end)

  teardown(function()
    os.remove('Xtest-sal.aff')
    os.remove('Xtest.aff')
    os.remove('Xtest.dic')
    os.remove('Xtest.utf-8.add')
    os.remove('Xtest.utf-8.add.spl')
    os.remove('Xtest.utf-8.spl')
    os.remove('Xtest.utf-8.sug')
    os.remove('Xtest1.aff')
    os.remove('Xtest1.dic')
    os.remove('Xtest2.aff')
    os.remove('Xtest3.aff')
    os.remove('Xtest3.dic')
    os.remove('Xtest4.aff')
    os.remove('Xtest4.dic')
    os.remove('Xtest5.aff')
    os.remove('Xtest5.dic')
    os.remove('Xtest6.aff')
    os.remove('Xtest6.dic')
    os.remove('Xtest7.aff')
    os.remove('Xtest7.dic')
    os.remove('Xtest8.aff')
    os.remove('Xtest8.dic')
    os.remove('Xtest9.aff')
    os.remove('Xtest9.dic')
  end)

  -- Function to test .aff/.dic with list of good and bad words.  This was a
  -- Vim function in the original legacy test.
  local function test_one(aff, dic)
    -- Generate a .spl file from a .dic and .aff file.
    if helpers.iswin() then
      os.execute('copy /y Xtest'..aff..'.aff Xtest.aff')
      os.execute('copy /y Xtest'..dic..'.dic Xtest.dic')
    else
      os.execute('cp -f Xtest'..aff..'.aff Xtest.aff')
      os.execute('cp -f Xtest'..dic..'.dic Xtest.dic')
    end
    source([[
      set spellfile=
      function! SpellDumpNoShow()
        " spelling scores depend on what happens to be drawn on screen
        spelldump
        %yank
        quit
      endfunction
      $put =''
      $put ='test ]]..aff..'-'..dic..[['
      mkspell! Xtest Xtest
      "  Use that spell file.
      set spl=Xtest.utf-8.spl spell
      "  List all valid words.
      call SpellDumpNoShow()
      $put
      $put ='-------'
      "  Find all bad words and suggestions for them.
      1;/^]]..aff..[[good:
      normal 0f:]s
      let prevbad = ''
      while 1
        let [bad, a] = spellbadword()
        if bad == '' || bad == prevbad || bad == 'badend'
          break
        endif
        let prevbad = bad
        let lst = spellsuggest(bad, 3)
        normal mm
        $put =bad
        $put =string(lst)
        normal `m]s
      endwhile
      ]])
  end

  it('part 1-1', function()
    insert([[
      1good: wrong OK puts. Test the end
      bad:  inputs comment ok Ok. test déôl end the
      badend

      test2:
      elequint test elekwint test elekwent asdf
      ]])
    test_one(1, 1)
    feed_command([[$put =soundfold('goobledygoook')]])
    feed_command([[$put =soundfold('kóopërÿnôven')]])
    feed_command([[$put =soundfold('oeverloos gezwets edale')]])
    -- And now with SAL instead of SOFO items; test automatic reloading.
    if helpers.iswin() then
      os.execute('copy /y Xtest-sal.aff Xtest.aff')
    else
      os.execute('cp -f Xtest-sal.aff Xtest.aff')
    end
    feed_command('mkspell! Xtest Xtest')
    feed_command([[$put =soundfold('goobledygoook')]])
    feed_command([[$put =soundfold('kóopërÿnôven')]])
    feed_command([[$put =soundfold('oeverloos gezwets edale')]])
    -- Also use an addition file.
    feed_command('mkspell! Xtest.utf-8.add.spl Xtest.utf-8.add')
    feed_command('set spellfile=Xtest.utf-8.add')
    feed_command('/^test2:')
    feed(']s')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed_command('set spl=Xtest_us.utf-8.spl')
    feed_command('/^test2:')
    feed(']smm')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed('`m]s')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed_command('set spl=Xtest_gb.utf-8.spl')
    feed_command('/^test2:')
    feed(']smm')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed('`m]s')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed_command('set spl=Xtest_nz.utf-8.spl')
    feed_command('/^test2:')
    feed(']smm')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed('`m]s')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed_command('set spl=Xtest_ca.utf-8.spl')
    feed_command('/^test2:')
    feed(']smm')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed('`m]s')
    feed_command('let [str, a] = spellbadword()')
    feed_command('$put =str')
    feed_command('1,/^test 1-1/-1d')
    expect([[
      test 1-1
      # file: Xtest.utf-8.spl
      Comment
      deol
      déôr
      input
      OK
      output
      outputs
      outtest
      put
      puts
      test
      testen
      testn
      the end
      uk
      wrong
      -------
      bad
      ['put', 'uk', 'OK']
      inputs
      ['input', 'puts', 'outputs']
      comment
      ['Comment', 'outtest', 'the end']
      ok
      ['OK', 'uk', 'put']
      Ok
      ['OK', 'Uk', 'Put']
      test
      ['Test', 'testn', 'testen']
      déôl
      ['deol', 'déôr', 'test']
      end
      ['put', 'uk', 'test']
      the
      ['put', 'uk', 'test']
      gebletegek
      kepereneven
      everles gesvets etele
      kbltykk
      kprnfn
      *fls kswts tl
      elekwent
      elequint
      elekwint
      elekwint
      elekwent
      elequint
      elekwent
      elequint
      elekwint]])
  end)

  it('part 2-1', function()
    insert([[
      2good: puts
      bad: inputs comment ok Ok end the. test déôl
      badend
      ]])
    -- Postponed prefixes.
    test_one(2, 1)
    feed_command('1,/^test 2-1/-1d')
    expect([=[
      test 2-1
      # file: Xtest.utf-8.spl
      Comment
      deol
      déôr
      OK
      put
      input
      output
      puts
      outputs
      test
      outtest
      testen
      testn
      the end
      uk
      wrong
      -------
      bad
      ['put', 'uk', 'OK']
      inputs
      ['input', 'puts', 'outputs']
      comment
      ['Comment']
      ok
      ['OK', 'uk', 'put']
      Ok
      ['OK', 'Uk', 'Put']
      end
      ['put', 'uk', 'deol']
      the
      ['put', 'uk', 'test']
      test
      ['Test', 'testn', 'testen']
      déôl
      ['deol', 'déôr', 'test']]=])
  end)

  it('part 3-3', function()
    insert([[
      Test rules for compounding.

      3good: foo mï foobar foofoobar barfoo barbarfoo
      bad: bar la foomï barmï mïfoo mïbar mïmï lala mïla lamï foola labar
      badend
      ]])
    test_one(3, 3)
    feed_command('1,/^test 3-3/-1d')
    expect([=[
      test 3-3
      # file: Xtest.utf-8.spl
      foo
      mï
      -------
      bad
      ['foo', 'mï']
      bar
      ['barfoo', 'foobar', 'foo']
      la
      ['mï', 'foo']
      foomï
      ['foo mï', 'foo', 'foofoo']
      barmï
      ['barfoo', 'mï', 'barbar']
      mïfoo
      ['mï foo', 'foo', 'foofoo']
      mïbar
      ['foobar', 'barbar', 'mï']
      mïmï
      ['mï mï', 'mï']
      lala
      []
      mïla
      ['mï', 'mï mï']
      lamï
      ['mï', 'mï mï']
      foola
      ['foo', 'foobar', 'foofoo']
      labar
      ['barbar', 'foobar']]=])
  end)

  it('part 4-4', function()
    insert([[
      Tests for compounding.

      4good: word util bork prebork start end wordutil wordutils pro-ok
        bork borkbork borkborkbork borkborkborkbork borkborkborkborkbork
        tomato tomatotomato startend startword startwordword startwordend
        startwordwordend startwordwordwordend prebork preborkbork
        preborkborkbork
        nouword
      bad: wordutilize pro borkborkborkborkborkbork tomatotomatotomato
        endstart endend startstart wordend wordstart
        preborkprebork  preborkpreborkbork
        startwordwordwordwordend borkpreborkpreborkbork
        utilsbork  startnouword
      badend
      ]])
    test_one(4, 4)
    feed_command('1,/^test 4-4/-1d')
    expect([=[
      test 4-4
      # file: Xtest.utf-8.spl
      bork
      prebork
      end
      pro-ok
      start
      tomato
      util
      utilize
      utils
      word
      nouword
      -------
      bad
      ['end', 'bork', 'word']
      wordutilize
      ['word utilize', 'wordutils', 'wordutil']
      pro
      ['bork', 'word', 'end']
      borkborkborkborkborkbork
      ['bork borkborkborkborkbork', 'borkbork borkborkborkbork', 'borkborkbork borkborkbork']
      tomatotomatotomato
      ['tomato tomatotomato', 'tomatotomato tomato', 'tomato tomato tomato']
      endstart
      ['end start', 'start']
      endend
      ['end end', 'end']
      startstart
      ['start start']
      wordend
      ['word end', 'word', 'wordword']
      wordstart
      ['word start', 'bork start']
      preborkprebork
      ['prebork prebork', 'preborkbork', 'preborkborkbork']
      preborkpreborkbork
      ['prebork preborkbork', 'preborkborkbork', 'preborkborkborkbork']
      startwordwordwordwordend
      ['startwordwordwordword end', 'startwordwordwordword', 'start wordwordwordword end']
      borkpreborkpreborkbork
      ['bork preborkpreborkbork', 'bork prebork preborkbork', 'bork preborkprebork bork']
      utilsbork
      ['utilbork', 'utils bork', 'util bork']
      startnouword
      ['start nouword', 'startword', 'startborkword']]=])
  end)

  it('part 5-5', function()
    insert([[
      Test affix flags with two characters

      5good: fooa1 fooaé bar prebar barbork prebarbork  startprebar
            start end startend  startmiddleend nouend
      bad: foo fooa2 prabar probarbirk middle startmiddle middleend endstart
            startprobar startnouend
      badend
      ]])
    test_one(5, 5)
    feed_command('1,/^test 5-5/-1d')
    expect([=[
      test 5-5
      # file: Xtest.utf-8.spl
      bar
      barbork
      end
      fooa1
      fooaé
      nouend
      prebar
      prebarbork
      start
      -------
      bad
      ['bar', 'end', 'fooa1']
      foo
      ['fooa1', 'fooaé', 'bar']
      fooa2
      ['fooa1', 'fooaé', 'bar']
      prabar
      ['prebar', 'bar', 'bar bar']
      probarbirk
      ['prebarbork']
      middle
      []
      startmiddle
      ['startmiddleend', 'startmiddlebar']
      middleend
      []
      endstart
      ['end start', 'start']
      startprobar
      ['startprebar', 'start prebar', 'startbar']
      startnouend
      ['start nouend', 'startend']]=])
  end)

  it('part 6-6', function()
    insert([[
      6good: meea1 meeaé bar prebar barbork prebarbork  leadprebar
            lead end leadend  leadmiddleend
      bad: mee meea2 prabar probarbirk middle leadmiddle middleend endlead
            leadprobar
      badend
      ]])
    test_one(6, 6)
    feed_command('1,/^test 6-6/-1d')
    expect([=[
      test 6-6
      # file: Xtest.utf-8.spl
      bar
      barbork
      end
      lead
      meea1
      meeaé
      prebar
      prebarbork
      -------
      bad
      ['bar', 'end', 'lead']
      mee
      ['meea1', 'meeaé', 'bar']
      meea2
      ['meea1', 'meeaé', 'lead']
      prabar
      ['prebar', 'bar', 'leadbar']
      probarbirk
      ['prebarbork']
      middle
      []
      leadmiddle
      ['leadmiddleend', 'leadmiddlebar']
      middleend
      []
      endlead
      ['end lead', 'lead', 'end end']
      leadprobar
      ['leadprebar', 'lead prebar', 'leadbar']]=])
  end)

  it('part 7-7', function()
    insert([[
      7good: meea1 meeaé bar prebar barmeat prebarmeat  leadprebar
            lead tail leadtail  leadmiddletail
      bad: mee meea2 prabar probarmaat middle leadmiddle middletail taillead
            leadprobar
      badend
      ]])
    -- Compound words.
    test_one(7, 7)
    -- Assert buffer contents.
    feed_command('1,/^test 7-7/-1d')
    expect([=[
      test 7-7
      # file: Xtest.utf-8.spl
      bar
      barmeat
      lead
      meea1
      meeaé
      prebar
      prebarmeat
      tail
      -------
      bad
      ['bar', 'lead', 'tail']
      mee
      ['meea1', 'meeaé', 'bar']
      meea2
      ['meea1', 'meeaé', 'lead']
      prabar
      ['prebar', 'bar', 'leadbar']
      probarmaat
      ['prebarmeat']
      middle
      []
      leadmiddle
      ['leadmiddlebar']
      middletail
      []
      taillead
      ['tail lead', 'tail']
      leadprobar
      ['leadprebar', 'lead prebar', 'leadbar']]=])
  end)

  it('part 8-8', function()
    insert([[
      8good: foo bar faabar
      bad: foobar barfoo
      badend
      ]])
    -- NOSPLITSUGS
    test_one(8, 8)
    -- Assert buffer contents.
    feed_command('1,/^test 8-8/-1d')
    expect([=[
      test 8-8
      # file: Xtest.utf-8.spl
      bar
      faabar
      foo
      -------
      bad
      ['bar', 'foo']
      foobar
      ['faabar', 'foo bar', 'bar']
      barfoo
      ['bar foo', 'bar', 'foo']]=])
  end)

  it('part 9-9', function()
    insert([[
      9good: 0b1011 0777 1234 0x01ff
      badend
      ]])
    -- NOSPLITSUGS
    test_one(9, 9)
    -- Assert buffer contents.
    feed_command('1,/^test 9-9/-1d')
    expect([=[
      test 9-9
      # file: Xtest.utf-8.spl
      bar
      foo
      -------]=])
  end)
end)
